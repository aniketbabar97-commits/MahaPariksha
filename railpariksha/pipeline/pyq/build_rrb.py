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
TECH_SUBJECTS = ["je_mechanical", "je_electrical", "je_civil", "science"]


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


def quality_ok(q):
    stem, opts = q["q"], q["o"]
    if len(stem) < 12 or BAD.search(stem) or any(BAD.search(o) for o in opts):
        return False
    if FIGURE_WORDS.search(stem) or any(len(o) > 300 for o in opts) or len(stem) > 1500:
        return False
    return True


def norm_key(text, opts):
    n = lambda s: re.sub(r"[^a-z0-9ऀ-ॿ]+", "", s.lower())
    return n(text) + "|" + "|".join(sorted(n(o) for o in opts))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdfs", required=True)
    ap.add_argument("--extra", nargs="*", default=[], help="more PDF dirs (family guessed from file name)")
    a = ap.parse_args()

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
    seen_hash = set()
    for i, (p, fam, cstage) in enumerate(files):
        h = hashlib.sha1(p.read_bytes()).hexdigest()
        if h in seen_hash:
            stats["dup_file"] += 1
            continue
        seen_hash.add(h)
        try:
            info, qs, st = rs.extract(str(p))
            qs, _ = rs.figure_scan(str(p), qs)
        except Exception as e:
            print(f"ERR {p.name}: {e}", file=sys.stderr)
            stats["err_file"] += 1
            continue
        d = parse_date(info["date"]) or catalog_date(catalog.get(p.name), p.name)
        if not qs or d is None:
            stats["no_text_or_date" if not qs else "no_date"] += 1
            continue
        stats["papers_ok"] += 1
        papers.append({"family": fam, "stage": stage_label(fam, info["subject"], cstage), "header": info["subject"],
                       "date": d, "time": info["time"], "qs": [q for q in qs if quality_ok(q)], "file": p.name})
        stats["q_extracted"] += len(qs)
        if (i + 1) % 100 == 0:
            print(f"  extracted {i + 1}/{len(files)}", flush=True)

    # Shift numbers: order of start times among that exam's papers on that day.
    starts = defaultdict(set)
    for pp in papers:
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
    used_ids = set()
    for it in unique:
        slug, exam_id = FAMILY[it["family"]]
        subj = section_subject(it["section"])
        allowed = EXAM_SUBJECTS[exam_id]
        if subj == "gk":  # "General Awareness" sections mix GK, science, current affairs, railways
            subj, allowed = None, ["gk", "science", "current_affairs", "railway_gk", "computer"]
        if subj is None and is_technical(it["section"], it["pyq"]):
            allowed = TECH_SUBJECTS
        q = {"q_en": it.get("q_en"), "q_hi": it.get("q_hi"), "o_en": it.get("o_en"), "o_hi": it.get("o_hi")}
        s, t = clf.classify(q, subjects=[x for x in allowed if x in clf.topic] or None, subject=subj)
        a = it["a"]
        rec = {"id": "", "s": s, "t": t, "d": 2}
        if "q_hi" in it:
            rec.update(q_hi=it["q_hi"], o_hi=it["o_hi"])
        if "q_en" in it:
            rec.update(q_en=it["q_en"], o_en=it["o_en"])
        rec["a"] = a
        if "q_en" in it:
            rec["e_en"] = f"Correct answer: {it['o_en'][a]} (official answer key)."
        if "q_hi" in it:
            rec["e_hi"] = f"सही उत्तर: {it['o_hi'][a]} (आधिकारिक उत्तर कुंजी)।"
        rec["pyq"] = it["pyq"]
        # Content-derived, so ids stay stable across re-runs.
        base = "pyq-" + hashlib.sha1(f"{it['pyq']}|{it['lang']}|{norm_key(it.get('q_en') or it['q_hi'], it.get('o_en') or it['o_hi'])}".encode()).hexdigest()[:12]
        rec["id"] = base
        k = 2
        while rec["id"] in used_ids:
            rec["id"], k = f"{base}-{k}", k + 1
        used_ids.add(rec["id"])
        out[slug].append(rec)
        stats[f"lang_{it['lang']}"] += 1

    dest = ROOT / "content/pyq"
    dest.mkdir(exist_ok=True)
    for slug, recs in sorted(out.items()):
        recs.sort(key=lambda r: (r["pyq"], r["id"]))
        (dest / f"{slug}.json").write_text("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False) for r in recs) + "\n]\n",
                                           encoding="utf-8")
        print(f"{slug}: {len(recs)} questions, {len({r['pyq'] for r in recs})} papers")
    ids = [r["id"] for recs in out.values() for r in recs]
    assert len(ids) == len(set(ids)), "duplicate ids"
    print(dict(stats))


if __name__ == "__main__":
    main()
