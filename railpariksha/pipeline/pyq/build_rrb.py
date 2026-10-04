"""Build content/pyq/*.json from downloaded RRB/RPF response sheets.

  python3 pipeline/pyq/build_rrb.py --pdfs /tmp/pyq-pdfs [--extra DIR ...]

1. Extract every sheet (response_sheets.py) -- official question text + official key.
2. Label each paper from the sheet's own header (date, time, subject line), with the
   exam family from catalog.json; shifts are numbered by start time within a day.
3. Pair the Hindi and English sheets of the same paper question-by-question
   (same paper, same Q number, same key, matching numbers in the options), giving
   bilingual items; unpaired items stay single-language.
4. Drop duplicates (the same paper is often hosted twice) and quality failures.
5. Classify subject (section header first, else Naive Bayes within the exam's
   syllabus) and topic (Naive Bayes trained on the app's bank).

Writes one file per exam family: content/pyq/rrb_<family>.json.
"""
import argparse
import hashlib
import json
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from multiprocessing import Pool
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
sys.path.insert(0, str(HERE))
import response_sheets as rs  # noqa: E402
from classify import Classifier  # noqa: E402
from download import name_for  # noqa: E402

DEV = re.compile(r"[ऀ-ॿ]")
TAXONOMY = json.loads((ROOT / "content/taxonomy.json").read_text(encoding="utf-8"))
EXAM_SUBJECTS = {e["id"]: [s["id"] for s in e["subjects"]] for e in TAXONOMY["exams"]}

FAMILY = {  # catalog exam -> (file slug, app exam id whose syllabus bounds the subject guess)
    "RRB NTPC": ("rrb_ntpc", "rrb_ntpc"), "RRB Group D": ("rrb_group_d", "rrb_group_d"),
    "RRB ALP": ("rrb_alp", "rrb_alp"), "RRB Technician": ("rrb_technician", "rrb_technician"),
    "RRB JE": ("rrb_je", "rrb_je"), "RPF Constable": ("rpf_constable", "rpf_constable"),
    "RPF SI": ("rpf_si", "rpf_si"),
}
SECTION_SUBJECT = [
    (r"reasoning|intelligence", "reasoning"), (r"mathemat|arithmetic|numerical", "maths"),
    (r"general science|basic science", "science"), (r"computer", "computer"),
    (r"awareness|current affairs|general knowledge", "gk"),
]
def tech_subjects(label):
    """Subjects a technical (trade/branch) question may belong to, from its paper:
    a JE CBT-2 paper is its branch; ALP/Technician trades are mechanical/electrical."""
    l = label.lower()
    if "civil" in l:
        return ["je_civil"]
    if "mechanical" in l and "electronics" not in l:
        return ["je_mechanical"]
    if re.search(r"electrical|electronics|wiremen|electrician|signal", l):
        return ["je_electrical"]
    if "rrb je" in l:  # other JE branches (chemical, computer, ...) have no subject in the app
        return ["science"]
    return ["je_mechanical", "je_electrical", "science"]


def section_subject(section):
    s = section.lower()
    for pat, subj in SECTION_SUBJECT:
        if re.search(pat, s):
            return subj
    return None


def is_technical(section, header):
    t = (section + " " + header).lower()
    return bool(re.search(r"technical|part-b|stage 2|cbt 2.*(civil|mech|electr)|engineering", t)) and "basic science" not in t


def stage_label(family, header, catalog_stage):
    h = header.lower()
    if family == "RRB NTPC":
        lvl = "Graduate" if "graduate" in h and "under" not in h else ("UG" if re.search(r"under|\bug\b|level 2|level 3", h) else "")
        cbt = "CBT-2" if re.search(r"cbt\s*-?\s*2|stage\s*2", h) else "CBT-1"
        return " ".join(x for x in (lvl, cbt) if x)
    if family == "RRB JE":
        if re.search(r"stage\s*2|cbt\s*-?\s*2", h):
            br = next((b for b in ("Civil", "Mechanical", "Electrical", "Electronics", "Computer", "Chemical")
                       if b.lower() in h), "")
            return f"CBT-2 {br}".strip()
        return "CBT-1"
    if family == "RRB ALP":
        if re.search(r"stage\s*2|cbt\s*-?\s*2", h):
            trade = re.sub(r".*stage\s*2\s*", "", header, flags=re.I).strip()
            return f"CBT-2 {trade}".strip() if trade and len(trade) < 40 else "CBT-2"
        return "CBT-1"
    if family == "RRB Technician":
        g = re.search(r"grade\s*(iii|i)\b", h)
        return f"Grade {g.group(1).upper()}" if g else ""
    return (catalog_stage or "CBT").replace("CBT 1", "CBT").replace("CBT 2", "CBT-2")


def parse_date(s):
    for f in ("%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y"):
        try:
            return datetime.strptime(s.strip(), f)
        except (ValueError, AttributeError):
            pass
    return None


def catalog_date(r, fname):
    """Fallback paper date from the catalog entry ('17 Jan 2019') or its title/file name
    ('...-19-12-2025-S2', '...Held-On-18-Jan-2019...')."""
    cands = [r.get("date") or "", r.get("title") or ""] if r else []
    cands.append(fname)
    for c in cands:
        c = c.replace("_", "-")
        for pat, fmt in ((r"(\d{1,2})[-. ](\d{1,2})[-. ](20\d\d)", "%d-%m-%Y"),
                         (r"(\d{1,2})(?:st|nd|rd|th)?[- ]([A-Za-z]{3,9})[- ,]*(20\d\d)", None)):
            m = re.search(pat, c)
            if not m:
                continue
            try:
                if fmt:
                    return datetime.strptime("-".join(m.groups()), fmt)
                mon = m.group(2)[:3].title()
                return datetime.strptime(f"{m.group(1)} {mon} {m.group(3)}", "%d %b %Y")
            except ValueError:
                continue
    return None


TOK = re.compile(r"[0-9]+(?:\.[0-9]+)?|[a-z]{2,}")


def opt_tokens(o):
    return tuple(TOK.findall(o.lower()))


def pair_signature(q):
    """Language-independent fingerprint: the numbers/Latin words in each option (order-free,
    since option order is shuffled per candidate) plus the numbers in the stem."""
    opts = tuple(sorted(opt_tokens(o) for o in q["o"]))
    if any(not t for t in opts) or sum(len(t) for t in opts) < 4:
        return None
    return opts, tuple(sorted(re.findall(r"\d+(?:\.\d+)?", q["q"])))


BAD = re.compile(r"Question ID|Chosen Option|Option \d ID|\bQ\.\d+\b|Status\s*:")
FIGURE_WORDS = re.compile(r"given (figure|image|diagram|picture)|following (figure|image|diagram)|"
                          r"(दी गई|निम्न) (आकृति|चित्र)|shown below|figure given", re.I)


# A channel promo some re-hosted sheets stamp into the text ("Join Telegram Railway
# News Room - Complete Railway Exams Updates", sometimes truncated). Real mentions
# of Telegram (e.g. "Telegram and Safari") don't match: the promo always names the room.
PROMO = re.compile(r"\s*(?:Join\s*)?(?:Telegram\s*)?Railway\s*News\s*Ro+ms?\b(?:\s*-?\s*Complete\s+Railway\s+Exams?\s+Updates)?",
                   re.I)


# A page-header field the sheets print beside some questions; it leaks into option text.
HEADER_LEAK = re.compile(r"\s*Question\s+Type\s*:\s*\w+|\s*\bPage\s*\d{1,3}\b|\s*\b20\d\d/\d\d/\d\d-\d\d:\d\d:\d\d\b"
                         r"|\s*\bQ\s*\.\s*\d(?:\s*\d)*\s+A\b.*",  # the next question's header + options, glued on
                         re.I | re.S)


def scrub(t):
    return HEADER_LEAK.sub("", PROMO.sub("", t)).strip()


def strip_promo(q):
    q["q"] = scrub(q["q"])
    q["o"] = [scrub(o) for o in q["o"]]
    return q


# Some candidates take the CBT in a regional language; the app is Hindi/English only.
REGIONAL = re.compile(r"[\u0980-\u0DFF\u0600-\u06FF]")  # Bengali..Malayalam, Urdu
# Marathi shares Hindi's script, so it's recognised by words Hindi doesn't use.
MARATHI = re.compile(r"(?<![\u0900-\u097F])(आहे|आहेत|खालीलपैकी|कोणता|कोणती|कोणते|आणि|नाही|म्हणून|यांच्या|"
                     r"दिलेल्या|कोणत्या|करण्यासाठी|असलेल्या)(?![\u0900-\u097F])")
# Questions about a chart whose image isn't in the text layer can't be answered.
CHART = re.compile(r"pie[- ]?chart|bar[- ]?graph|line[- ]?graph|histogram|पाई[- ]?चार्ट|दंड[- ]?आरेख|बार[- ]?ग्राफ|"
                   r"रेखा[- ]?(ग्राफ|आलेख)", re.I)


def is_marathi_sheet(qs):
    dev = [q for q in qs if DEV.search(q["q"])]
    if len(dev) < 5:
        return False
    hits = sum(bool(MARATHI.search(q["q"] + " " + " ".join(q["o"]))) for q in dev)
    return hits / len(dev) >= 0.3


def quality_ok(q):
    if REGIONAL.search(q["q"] + " ".join(q["o"])) or CHART.search(q["q"]):
        return False
    if len(MARATHI.findall(q["q"] + " " + " ".join(q["o"]))) >= 2:  # a stray Marathi item
        return False
    # Empty "( )" slots are formulas/images the text layer lost; the stem is incomplete.
    if re.search(r"\(\s*\)", q["q"]) or any(re.fullmatch(r"\(?\s*\)?", o.strip()) for o in q["o"]):
        return False
    stem, opts = q["q"], q["o"]
    if len(stem) < 12 or BAD.search(stem) or any(BAD.search(o) for o in opts):
        return False
    if FIGURE_WORDS.search(stem) or any(len(o) > 300 for o in opts) or len(stem) > 1500:
        return False
    return True


def norm_key(text, opts):
    n = lambda s: re.sub(r"[^a-z0-9ऀ-ॿ]+", "", s.lower())
    return n(text) + "|" + "|".join(sorted(n(o) for o in opts))


CACHE = Path("/tmp/pyq-extract-cache")


def extract_one(path):
    """Extract one sheet, cached by file content hash (re-runs skip the slow PDF pass)."""
    import pickle
    h = hashlib.sha1(Path(path).read_bytes()).hexdigest()
    cf = CACHE / f"{h}-{rs.VERSION}.pkl"
    if cf.exists():
        return pickle.loads(cf.read_bytes())
    res = _extract(path)
    CACHE.mkdir(exist_ok=True)
    cf.write_bytes(pickle.dumps(res))
    return res


def _extract(path):
    try:
        info, qs, _ = rs.extract(path)
        qs, _ = rs.figure_scan(path, qs)
        return info, qs
    except Exception as e:  # one corrupt PDF must not stop the batch
        print(f"ERR {path}: {e}", file=sys.stderr)
        return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdfs", required=True)
    ap.add_argument("--extra", nargs="*", default=[], help="more PDF dirs (family guessed from file name)")
    ap.add_argument("--min-margin", type=float, default=0.15,
                    help="min per-token topic-score gap for an item to be copied into the bank")
    ap.add_argument("--bank-cap", type=int, default=150, help="max bilingual PYQs per topic copied into the bank")
    a = ap.parse_args()
    bank_cap, min_margin = a.bank_cap, a.min_margin

    catalog = {name_for(r["url"]): r for r in json.loads((HERE / "catalog.json").read_text(encoding="utf-8"))}
    files = []
    for p in sorted(Path(a.pdfs).glob("*.pdf")):
        r = catalog.get(p.name)
        if r and r["exam"] in FAMILY:
            files.append((p, r["exam"], r.get("stage")))
    for d in a.extra:
        for p in sorted(Path(d).rglob("*.pdf")):
            n = p.name.lower()
            fam = ("RRB Group D" if "group" in n else "RRB NTPC" if "ntpc" in n else "RRB ALP" if "alp" in n else
                   "RRB Technician" if "tech" in n else "RPF Constable" if "constable" in n else
                   "RPF SI" if "rpf" in n else "RRB JE" if "je" in n else None)
            if fam:
                files.append((p, fam, None))

    stats = Counter()
    papers = []  # one per sheet
    # Skip byte-identical files (the same sheet is often hosted under two names).
    seen_hash, unique_files = set(), []
    for f in files:
        h = hashlib.sha1(f[0].read_bytes()).hexdigest()
        if h in seen_hash:
            stats["dup_file"] += 1
        else:
            seen_hash.add(h)
            unique_files.append(f)
    with Pool() as pool:
        results = pool.map(extract_one, [str(f[0]) for f in unique_files], chunksize=4)
    for (p, fam, cstage), res in zip(unique_files, results):
        if res is None:
            stats["err_file"] += 1
            continue
        info, qs = res
        d = parse_date(info["date"]) or catalog_date(catalog.get(p.name), p.name)
        if not qs or d is None:
            stats["no_text" if not qs else "no_date"] += 1
            continue
        if is_marathi_sheet(qs):
            stats["marathi_sheet"] += 1
            continue
        stats["papers_ok"] += 1
        stats["q_extracted"] += len(qs)
        papers.append({"family": fam, "stage": stage_label(fam, info["subject"], cstage), "header": info["subject"],
                       "date": d, "time": info["time"], "qs": [q for q in (strip_promo(x) for x in qs) if quality_ok(q)],
                       "file": p.name})

    # Some sheets print no test date/time (the date then comes from the catalog). Give
    # such a sheet the time of the same-day paper it shares questions with, so it joins
    # that shift instead of posing as a shift of its own; with no clear match it stays
    # untimed and gets no shift number.
    sigs = [{s for s in map(pair_signature, pp["qs"]) if s} for pp in papers]
    stats["untimed"] = sum(1 for pp in papers if not pp["time"])
    for i, pp in enumerate(papers):
        if pp["time"] or not sigs[i]:
            continue
        cands = [(len(sigs[i] & sigs[j]), j) for j, o in enumerate(papers)
                 if o["time"] and o["family"] == pp["family"] and o["date"] == pp["date"]]
        best = max(cands, default=(0, None))
        if best[0] >= max(5, len(sigs[i]) // 10):
            pp["time"], pp["stage"] = papers[best[1]]["time"], papers[best[1]]["stage"]
            stats["untimed_matched"] += 1

    # Shift numbers: order of start times among that exam's papers on that day.
    starts = defaultdict(set)
    for pp in papers:
        if pp["time"]:
            starts[(pp["family"], pp["date"])].add(pp["time"])

    def start_key(t):
        try:
            return datetime.strptime(t.split("-")[0].strip(), "%I:%M %p")
        except ValueError:
            return datetime.max

    for pp in papers:
        order = sorted(starts[(pp["family"], pp["date"])], key=start_key)
        shift = order.index(pp["time"]) + 1 if pp["time"] in order and len(order) > 1 else None
        date = f"{pp['date'].day} {pp['date'].strftime('%b %Y')}"
        pp["label"] = " · ".join(x for x in (f"{pp['family']} {pp['stage']}".strip(), date,
                                              f"Shift {shift}" if shift else "") if x)

    # Pair Hindi + English sheets of the same paper.
    by_paper = defaultdict(list)
    for pp in papers:
        by_paper[(pp["family"], pp["date"], pp["time"], pp["stage"])].append(pp)
    items = []
    for key, sheets in by_paper.items():
        label = sheets[0]["label"]
        all_q = [q for sh in sheets for q in sh["qs"]]
        en = [q for q in all_q if not DEV.search(q["q"])]
        hi = [q for q in all_q if DEV.search(q["q"])]
        # Each candidate's sheet shuffles question AND option order, so Hindi and
        # English versions are matched on content, never on question number.
        idx = defaultdict(list)
        for q in en:
            sg = pair_signature(q)
            if sg:
                idx[sg].append(q)
        pairs = {}
        for h in hi:
            sg = pair_signature(h)
            c = idx.get(sg, []) if sg else []
            if len(c) == 1 and opt_tokens(c[0]["o"][c[0]["a"]]) == opt_tokens(h["o"][h["a"]]):
                pairs[id(h)] = c[0]
        used_en = set()
        for h in hi:
            e = pairs.get(id(h))
            if e is not None and id(e) not in used_en:
                used_en.add(id(e))
                # Re-order the Hindi options to the English order.
                by_tok = {opt_tokens(o): o for o in h["o"]}
                o_hi = [by_tok.get(opt_tokens(o)) for o in e["o"]]
                if None in o_hi or len(set(o_hi)) != 4:
                    o_hi = None
                if o_hi:
                    items.append({"n": e["n"], "lang": "both", "section": e["section"] or h["section"], "q_en": e["q"],
                                  "o_en": e["o"], "q_hi": h["q"], "o_hi": o_hi, "a": e["a"], "pyq": label, "family": key[0]})
                    stats["paired"] += 1
                    continue
            items.append({"n": h["n"], "lang": "hi", "section": h["section"], "q_hi": h["q"], "o_hi": h["o"], "a": h["a"],
                          "pyq": label, "family": key[0]})
        for e in en:
            if id(e) not in used_en:
                items.append({"n": e["n"], "lang": "en", "section": e["section"], "q_en": e["q"], "o_en": e["o"],
                              "a": e["a"], "pyq": label, "family": key[0]})

    # De-duplicate across papers (the same sheet is often hosted under two names).
    seen, unique = set(), []
    for it in sorted(items, key=lambda x: ("q_en" in x) + ("q_hi" in x), reverse=True):
        k = norm_key(it.get("q_en") or it["q_hi"], it.get("o_en") or it["o_hi"])
        if k in seen:
            stats["dup_question"] += 1
            continue
        seen.add(k)
        unique.append(it)

    clf = Classifier.from_bank()
    out = defaultdict(list)
    used_ids, bank_excluded = set(), set()
    for it in unique:
        slug, exam_id = FAMILY[it["family"]]
        subj = section_subject(it["section"])
        allowed = EXAM_SUBJECTS[exam_id]
        if subj == "gk":  # "General Awareness" sections mix GK, science, current affairs, railways
            subj, allowed = None, ["gk", "science", "current_affairs", "railway_gk", "computer"]
        no_bank = False
        if subj is None and is_technical(it["section"], it["pyq"]):
            allowed = tech_subjects(it["pyq"])
            # A branch the app has no subject for: PYQ section only, never the bank.
            no_bank = allowed == ["science"]
        q = {"q_en": it.get("q_en"), "q_hi": it.get("q_hi"), "o_en": it.get("o_en"), "o_hi": it.get("o_hi")}
        s, t, margin = clf.classify(q, subjects=[x for x in allowed if x in clf.topic] or None, subject=subj,
                                    with_margin=True)
        ans = it["a"]
        rec = {"id": "", "s": s, "t": t, "d": 2}
        if "q_hi" in it:
            rec.update(q_hi=it["q_hi"], o_hi=it["o_hi"])
        if "q_en" in it:
            rec.update(q_en=it["q_en"], o_en=it["o_en"])
        rec["a"] = ans
        if "q_en" in it:
            rec["e_en"] = f"Correct answer: {it['o_en'][ans]} (official answer key)."
        if "q_hi" in it:
            rec["e_hi"] = f"सही उत्तर: {it['o_hi'][ans]} (आधिकारिक उत्तर कुंजी)।"
        rec["pyq"] = it["pyq"]
        # Content-derived, so ids stay stable across re-runs.
        base = "pyq-" + hashlib.sha1(f"{it['pyq']}|{it['lang']}|{norm_key(it.get('q_en') or it['q_hi'], it.get('o_en') or it['o_hi'])}".encode()).hexdigest()[:12]
        rec["id"] = base
        k = 2
        while rec["id"] in used_ids:
            rec["id"], k = f"{base}-{k}", k + 1
        used_ids.add(rec["id"])
        out[slug].append(rec)
        # The bank serves topic-wise practice, so it only takes confidently-tagged items.
        if no_bank or margin < min_margin:
            bank_excluded.add(rec["id"])
        stats[f"lang_{it['lang']}"] += 1

    # Re-apply stored Hindi<->English translations (keyed by id), so rebuilding never drops them.
    from translate import apply_family, migrate
    for slug, recs in out.items():
        old_path = ROOT / "content/pyq" / f"{slug}.json"
        if old_path.exists():
            stats[f"tr_migrated_{slug}"] = migrate(slug, json.loads(old_path.read_text(encoding="utf-8")), recs,
                                                   clean=scrub)
        stats[f"translated_{slug}"] = apply_family(slug, recs, clean=scrub)
    # A question whose options are plain words can't be paired by content, so its Hindi and English
    # halves arrive as two items and each gets translated into the other language: the same question
    # twice. Once translations are in, drop the repeats (keeping the copy with the original English).
    def final_key(r):
        return (re.sub(r"\W+", "", r["q_en"].lower()) + "|" +
                "|".join(sorted(re.sub(r"\W+", "", o.lower()) for o in r["o_en"])))
    for slug, recs in out.items():
        keep, seen = [], set()
        for r in sorted(recs, key=lambda r: (r.get("tr") != "hi", r["pyq"], r["id"])):
            if "q_en" in r:
                k = final_key(r)
                if k in seen:
                    stats["dup_after_translation"] += 1
                    continue
                seen.add(k)
            keep.append(r)
        recs[:] = keep

    # Repair words that lost their reph in the sheets' fonts (after ids/translations, which key on the raw text).
    import hindi_fix
    fixes = hindi_fix.build_map(t for recs in out.values() for r in recs if "q_hi" in r and r.get("tr") != "hi"
                                for t in [r["q_hi"], *r["o_hi"]])
    for recs in out.values():
        for r in recs:
            if "q_hi" in r and r.get("tr") != "hi":
                r["q_hi"], r["o_hi"] = hindi_fix.fix(r["q_hi"], fixes), [hindi_fix.fix(o, fixes) for o in r["o_hi"]]
                r["e_hi"] = f"सही उत्तर: {r['o_hi'][r['a']]} (आधिकारिक उत्तर कुंजी)।"
    stats["hindi_words_repaired"] = len(fixes)
    dest = ROOT / "content/pyq"
    dest.mkdir(exist_ok=True)
    for slug, recs in sorted(out.items()):
        recs.sort(key=lambda r: (r["pyq"], r["id"]))
        (dest / f"{slug}.json").write_text("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False) for r in recs) + "\n]\n",
                                           encoding="utf-8")
        print(f"{slug}: {len(recs)} questions, {len({r['pyq'] for r in recs})} papers")
    ids = [r["id"] for recs in out.values() for r in recs]
    assert len(ids) == len(set(ids)), "duplicate ids"

    # Question-bank copy: bilingual items only (bank practice works in both languages),
    # newest papers first, capped per topic so the always-loaded bundle stays light.
    def paper_date(r):
        try:
            return datetime.strptime(r["pyq"].split(" · ")[1], "%d %b %Y")
        except (IndexError, ValueError):
            return datetime.min
    per_topic = defaultdict(list)
    for recs in out.values():
        for r in recs:
            if "q_en" in r and "q_hi" in r and r["id"] not in bank_excluded:
                per_topic[(r["s"], r["t"])].append(r)
    bank = []
    for key, recs in sorted(per_topic.items()):
        recs.sort(key=paper_date, reverse=True)
        bank += [{**r, "id": "pyqb-" + r["id"][4:]} for r in recs[:bank_cap]]
    bank.sort(key=lambda r: (r["s"], r["t"], r["id"]))
    (ROOT / "content/bank/pyq_rrb.json").write_text(
        "[\n" + ",\n".join(json.dumps(r, ensure_ascii=False) for r in bank) + "\n]\n", encoding="utf-8")
    print(f"bank: {len(bank)} bilingual PYQs across {len(per_topic)} topics -> content/bank/pyq_rrb.json")
    print(dict(stats))


if __name__ == "__main__":
    main()
