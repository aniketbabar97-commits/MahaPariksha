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
    if lang == "en":  # Latin codes inside a Hindi question must survive verbatim
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


def apply_family(family, items):
    """Fill the missing language of each item from translations/. Marks it with
    "tr" (the translated language) so the app can label machine-made text."""
    tr = load_tr(family)
    n = 0
    for it in items:
        r = tr.get(it["id"])
        if not r or f"q_{r['lang']}" in it:
            continue
        lang = r["lang"]
        it[f"q_{lang}"], it[f"o_{lang}"] = r["q"], r["o"]
        ans = r["o"][it["a"]]
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
    a = ap.parse_args()
    {"export": export, "ingest": ingest, "apply": apply}[a.cmd](a)
    sys.exit(0)
