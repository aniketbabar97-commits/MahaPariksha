"""Hindi <-> English translations for single-language PYQs.

Response sheets are published per language, and many questions have no twin in
the other language. Their translations live in translations/<family>.jsonl (one
{"id", "lang", "q", "o"} per line), keyed by the PYQ's content-derived id, so a
rebuild of content/pyq/ re-applies them (build_rrb.py calls apply()).

  python3 pipeline/pyq/translate.py export --family rrb_ntpc --out DIR [--batch 100]
      -> DIR/<family>-<n>.json work batches of untranslated items
  python3 pipeline/pyq/translate.py ingest DIR...
      -> validates DIR/*.out.json results, appends the good ones to translations/
  python3 pipeline/pyq/translate.py apply
      -> writes translations into content/pyq/*.json

Validation (a failed item is simply left for the next round):
  - exactly 4 non-empty, distinct options;
  - target script: English has no Devanagari; Hindi question has Devanagari;
  - every number in the source question and each option is preserved;
  - Latin-script codes/words in a Hindi source (letter series, coded words) are kept.
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PYQ = ROOT / "content/pyq"
TR = HERE / "translations"
DEV = re.compile(r"[ऀ-ॿ]")
NUM = re.compile(r"\d+(?:[.,]\d+)*")


def nums(s):
    return sorted(n.replace(",", "") for n in NUM.findall(s))


def latin_words(s):
    return sorted(w for w in re.findall(r"[A-Za-z]+", s))


def load_tr(family):
    out = {}
    p = TR / f"{family}.jsonl"
    if p.exists():
        for line in p.open(encoding="utf-8"):
            r = json.loads(line)
            out[r["id"]] = r
    return out


def check(src, lang, res):
    """Why a translation result is unusable, or None if it's fine."""
    q, o = res.get("q"), res.get("o")
    if not (isinstance(q, str) and q.strip() and isinstance(o, list) and len(o) == 4
            and all(isinstance(x, str) and x.strip() for x in o)):
        return "shape"
    if len({x.strip() for x in o}) != 4:
        return "dup options"
    if lang == "en" and (DEV.search(q) or any(DEV.search(x) for x in o)):
        return "Devanagari in English"
    if lang == "hi" and not DEV.search(q):
        return "no Devanagari in Hindi"
    # Every number in the source must survive (a translation may add one, e.g.
    # "पैंसठवें संशोधन" -> "65th Amendment", but never drop or alter one).
    if Counter(nums(src["q"])) - Counter(nums(q)):
        return "question numbers changed"
    for a, b in zip(src["o"], o):
        if Counter(nums(a)) - Counter(nums(b)):
            return "option numbers changed"
    # Latin codes inside a Hindi reasoning question (letter series, coded words) must
    # survive verbatim. Elsewhere Latin text is mostly an English gloss in brackets,
    # e.g. "पोतगाह (dockyard)", which a good translation rightly absorbs.
    if lang == "en" and src.get("subject") == "reasoning":
        missing = Counter(latin_words(src["q"])) - Counter(latin_words(q))
        if missing:
            return f"lost Latin text {sorted(missing)[:3]}"
    return None


def export(a):
    items = json.loads((PYQ / f"{a.family}.json").read_text(encoding="utf-8"))
    done = load_tr(a.family)
    todo = []
    for it in items:
        if it["id"] in done or ("q_en" in it and "q_hi" in it):
            continue
        src_lang = "hi" if "q_hi" in it else "en"
        todo.append({"id": it["id"], "from": src_lang, "to": "en" if src_lang == "hi" else "hi",
                     "subject": it["s"], "q": it[f"q_{src_lang}"], "o": it[f"o_{src_lang}"]})
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    n = 0
    for i in range(0, len(todo), a.batch):
        (out / f"{a.family}-{i // a.batch:04d}.json").write_text(
            json.dumps(todo[i:i + a.batch], ensure_ascii=False, indent=0), encoding="utf-8")
        n += 1
    print(f"{a.family}: {len(todo)} to translate in {n} batches -> {out}")


def ingest(a):
    TR.mkdir(exist_ok=True)
    stats = Counter()
    for d in a.dirs:
        for res_path in sorted(Path(d).glob("*.out.json")):
            src_path = res_path.with_name(res_path.name.replace(".out.json", ".json"))
            family = src_path.name.rsplit("-", 1)[0]
            src = {s["id"]: s for s in json.loads(src_path.read_text(encoding="utf-8"))}
            try:
                results = json.loads(res_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                stats["bad_file"] += 1
                continue
            done = load_tr(family)
            new = []
            for r in results:
                s = src.get(r.get("id"))
                if s is None or r["id"] in done:
                    continue
                why = check(s, s["to"], r)
                if why:
                    stats[f"rejected: {why}"] += 1
                    continue
                new.append({"id": r["id"], "lang": s["to"], "q": r["q"].strip(), "o": [x.strip() for x in r["o"]]})
                done[r["id"]] = new[-1]
            with (TR / f"{family}.jsonl").open("a", encoding="utf-8") as f:
                for r in new:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            stats["accepted"] += len(new)
    print(dict(stats))


def content_key(item, clean=lambda t: t):
    """Source language + normalised content: stable across extraction fixes that only
    change formatting (superscripts, stripped watermarks) or a paper's label (shift
    numbers), so translations keyed by an item's old id can follow it to its new id.
    The paper is left out on purpose; the build already dedupes questions per family."""
    import unicodedata
    lang = "hi" if "q_hi" in item and item.get("tr") != "hi" else "en"
    # "र्" is dropped so text repaired by hindi_fix still matches its unrepaired twin.
    n = lambda t: re.sub(r"[^0-9a-z\u0900-\u097F]+", "", unicodedata.normalize("NFKC", clean(t)).lower().replace("र्", ""))
    return "|".join(["", lang, n(item[f"q_{lang}"])] + sorted(n(o) for o in item[f"o_{lang}"]))


def migrate(family, old_items, new_items, clean=lambda t: t):
    """Re-key translations from old item ids to the ids of the same questions after a rebuild."""
    tr = load_tr(family)
    if not tr:
        return 0
    new_by_key = {content_key(i): i["id"] for i in new_items}
    # Fallback for fixes that change digits in the stem (e.g. a stray question-number
    # digit removed): paper + language + options + the stem's letters only. Used
    # only when it identifies exactly one question on both sides.
    def loose(item, cl=lambda t: t):
        k = content_key(item, cl).split("|")
        return "|".join([k[0], k[1], re.sub(r"\d", "", k[2])] + k[3:])
    from collections import Counter as _C
    nl = _C(loose(i) for i in new_items)
    new_by_loose = {loose(i): i["id"] for i in new_items if nl[loose(i)] == 1}
    moved, out = 0, {}
    for old in old_items:
        r = tr.get(old["id"])
        if r is None:
            continue
        nid = new_by_key.get(content_key(old, clean)) or new_by_loose.get(loose(old, clean))
        if nid and nid != old["id"]:
            r = {**r, "id": nid}
            moved += 1
        out[r["id"]] = r
    for k, r in tr.items():  # translations of items not in old_items stay as they are
        out.setdefault(k, r)
    (TR / f"{family}.jsonl").write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in out.values()),
                                        encoding="utf-8")
    return moved


def reingest(a):
    """Re-validate translations that were rejected against a question's OLD text,
    against the same question after an extraction fix (e.g. a stray digit removed).
    Old items come from a saved copy of content/pyq (--old); each is matched to its
    rebuilt twin by the loose content key (unique matches only)."""
    sys.path.insert(0, str(HERE))
    from build_rrb import scrub
    stats = Counter()
    for d in a.dirs:
        d = Path(d)
        family = d.name
        old = {i["id"]: i for i in json.loads((Path(a.old) / f"{family}.json").read_text(encoding="utf-8"))}
        new_items = json.loads((PYQ / f"{family}.json").read_text(encoding="utf-8"))
        def loose(item, cl=lambda t: t):
            k = content_key(item, cl).split("|")
            return "|".join([k[0], k[1], re.sub(r"\d", "", k[2])] + k[3:])
        nl = Counter(loose(i) for i in new_items)
        by_loose = {loose(i): i for i in new_items if nl[loose(i)] == 1}
        done = load_tr(family)
        new = []
        for res_path in sorted(d.glob("*.out.json")):
            src_path = res_path.with_name(res_path.name.replace(".out.json", ".json"))
            src = {s["id"]: s for s in json.loads(src_path.read_text(encoding="utf-8"))}
            try:
                results = json.loads(res_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue
            for r in results:
                s0 = src.get(r.get("id"))
                if s0 is None or r["id"] not in old:
                    continue
                twin = by_loose.get(loose(old[r["id"]], scrub))
                if twin is None or twin["id"] in done:
                    stats["no_twin"] += 1
                    continue
                lang_from = s0["from"]
                if f"q_{lang_from}" not in twin:
                    stats["no_twin"] += 1
                    continue
                s1 = {"q": twin[f"q_{lang_from}"], "o": twin[f"o_{lang_from}"], "subject": twin["s"]}
                why = check(s1, s0["to"], r)
                if why:
                    stats[f"still rejected: {why}"] += 1
                    continue
                rec = {"id": twin["id"], "lang": s0["to"], "q": r["q"].strip(), "o": [x.strip() for x in r["o"]]}
                done[twin["id"]] = rec
                new.append(rec)
        with (TR / f"{family}.jsonl").open("a", encoding="utf-8") as f:
            for rec in new:
                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
        stats[f"accepted_{family}"] += len(new)
    print(dict(stats))


OPT_TOK = re.compile(r"[a-z]+|\d+(?:\.\d+)?")


def align_options(src, tgt):
    """`tgt` re-ordered to match `src` by the numbers/Latin words each option carries, or None
    when those don't identify every option one-to-one."""
    ts = [tuple(OPT_TOK.findall(o.lower())) for o in src]
    tt = [tuple(OPT_TOK.findall(o.lower())) for o in tgt]
    if not all(ts) or len(set(ts)) != len(ts) or sorted(ts) != sorted(tt):
        return None
    by_tok = dict(zip(tt, tgt))
    return [by_tok[t] for t in ts]


def apply_family(family, items, clean=lambda t: t, stats=None):
    """Fill the missing language of each item from translations/. Marks it with
    "tr" (the translated language) so the app can label machine-made text.

    An item marked "shuffled" exists on other sheets with its options in another order, and its
    translation may follow that other order (ids are order-free). Its translated options are
    re-ordered by their numbers/Latin words; when that can't be done the translation is left out,
    since a mismatched order would show the wrong option as the official answer."""
    tr = load_tr(family)
    n = 0
    for it in items:
        r = tr.get(it["id"])
        if not r or f"q_{r['lang']}" in it:
            continue
        lang = r["lang"]
        opts = [clean(o) for o in r["o"]]
        if it.get("shuffled"):
            src = "hi" if lang == "en" else "en"
            aligned = align_options(it[f"o_{src}"], opts)
            if aligned is None:
                if stats is not None:
                    stats[f"tr_unaligned_{family}"] += 1
                continue
            if stats is not None and aligned != opts:
                stats[f"tr_reordered_{family}"] += 1
            opts = aligned
        it[f"q_{lang}"], it[f"o_{lang}"] = clean(r["q"]), opts
        ans = it[f"o_{lang}"][it["a"]]  # the cleaned option text
        it[f"e_{lang}"] = (f"Correct answer: {ans} (official answer key)." if lang == "en"
                           else f"सही उत्तर: {ans} (आधिकारिक उत्तर कुंजी)।")
        it["tr"] = lang
        n += 1
    return n


def apply(_a):
    for p in sorted(PYQ.glob("*.json")):
        items = json.loads(p.read_text(encoding="utf-8"))
        n = apply_family(p.stem, items)
        if n:
            p.write_text("[\n" + ",\n".join(json.dumps(i, ensure_ascii=False) for i in items) + "\n]\n", encoding="utf-8")
        print(f"{p.stem}: applied {n}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export")
    e.add_argument("--family", required=True)
    e.add_argument("--out", required=True)
    e.add_argument("--batch", type=int, default=100)
    i = sub.add_parser("ingest")
    i.add_argument("dirs", nargs="+")
    sub.add_parser("apply")
    r = sub.add_parser("reingest")
    r.add_argument("--old", required=True, help="saved copy of content/pyq from before the rebuild")
    r.add_argument("dirs", nargs="+", help="batch dirs, named after their family")
    a = ap.parse_args()
    {"export": export, "ingest": ingest, "apply": apply, "reingest": reingest}[a.cmd](a)
    sys.exit(0)
