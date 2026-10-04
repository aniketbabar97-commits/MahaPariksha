"""Real explanations for PYQs (the sheets only give the answer, so every PYQ starts with the
generic "Correct answer: X (official answer key)").

Explanations live in explanations/<family>.jsonl, keyed by a hash of the question's English text
and options (so they survive id changes and Hindi repairs), and build_rrb.py re-applies them.

  python3 pipeline/pyq/explain.py export --family rrb_ntpc --out DIR [--batch 50] [--subjects maths,reasoning]
      -> DIR/<family>-<n>.json work batches of questions that have no explanation yet
  python3 pipeline/pyq/explain.py ingest DIR...
      -> validates DIR/*.out.json results, appends the good ones to explanations/
  python3 pipeline/pyq/explain.py status
      -> coverage per family

A solver is asked to work each question out independently and say whether it AGREES with the
official key. If it disagrees (or is unsure) no explanation is stored -- that would be justifying a
possibly wrong answer -- and the item goes to explanations/<family>.flags.jsonl for review.
"""
import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
PYQ = ROOT / "content/pyq"
EX = HERE / "explanations"
DEV = re.compile(r"[ऀ-ॿ]")
GENERIC = re.compile(r"official answer key|आधिकारिक उत्तर कुंजी", re.I)
NORM = re.compile(r"[^0-9a-zऀ-ॿ]+")


def ex_key(item):
    """Stable key: the English question + options when present (Hindi text gets repaired over
    time; English does not), else the Hindi."""
    lang = "en" if "q_en" in item else "hi"
    n = lambda t: NORM.sub("", t.lower().replace("र्", ""))
    raw = "|".join([lang, n(item[f"q_{lang}"])] + sorted(n(o) for o in item[f"o_{lang}"]))
    return hashlib.sha1(raw.encode()).hexdigest()[:16]


def load(family):
    out = {}
    p = EX / f"{family}.jsonl"
    if p.exists():
        for line in p.open(encoding="utf-8"):
            r = json.loads(line)
            out[r["k"]] = r
    return out


def load_flags(family):
    p = EX / f"{family}.flags.jsonl"
    return {json.loads(l)["k"] for l in p.open(encoding="utf-8")} if p.exists() else set()


def export(a):
    items = json.loads((PYQ / f"{a.family}.json").read_text(encoding="utf-8"))
    done, flagged = load(a.family), load_flags(a.family)
    want = set(a.subjects.split(",")) if a.subjects else None
    todo, seen = [], set()
    for it in items:
        k = ex_key(it)
        if k in done or k in flagged or k in seen or (want and it["s"] not in want):
            continue
        seen.add(k)
        lang = "en" if "q_en" in it else "hi"
        todo.append({"k": k, "subject": it["s"], "lang": lang, "q": it[f"q_{lang}"], "o": it[f"o_{lang}"], "key": it["a"]})
    out = Path(a.out)
    out.mkdir(parents=True, exist_ok=True)
    n = 0
    for i in range(0, len(todo), a.batch):
        (out / f"{a.family}-{a.start + i // a.batch:04d}.json").write_text(
            json.dumps(todo[i:i + a.batch], ensure_ascii=False, indent=0), encoding="utf-8")
        n += 1
    print(f"{a.family}: {len(todo)} to explain in {n} batches -> {out}")


def check(src, res):
    """Why a result is unusable, or None."""
    if res.get("agree") not in ("yes", "no", "unsure"):
        return "agree missing"
    if res["agree"] != "yes":
        return None  # handled as a flag, not a failure
    e_en, e_hi = res.get("e_en"), res.get("e_hi")
    if not (isinstance(e_en, str) and isinstance(e_hi, str) and e_en.strip() and e_hi.strip()):
        return "empty"
    if DEV.search(e_en):
        return "Devanagari in English"
    if not DEV.search(e_hi):
        return "no Devanagari in Hindi"
    if GENERIC.search(e_en) or GENERIC.search(e_hi):
        return "generic text"
    if len(e_en) > 900 or len(e_hi) > 1100:
        return "too long"
    if len(e_en) < 15 or len(e_hi) < 15:
        return "too short"
    # A worked solution to a numeric question has to land on the key's number.
    if src["subject"] in ("maths", "reasoning", "je_electrical", "je_mechanical", "je_civil"):
        right = src["o"][src["key"]]
        digits = re.findall(r"\d+(?:\.\d+)?", right)
        if digits and not all(d in e_en for d in digits):
            return "answer number missing"
    return None


def ingest(a):
    EX.mkdir(exist_ok=True)
    stats = Counter()
    for d in a.dirs:
        for res_path in sorted(Path(d).glob("*.out.json")):
            src_path = res_path.with_name(res_path.name.replace(".out.json", ".json"))
            family = src_path.name.rsplit("-", 1)[0]
            src = {s["k"]: s for s in json.loads(src_path.read_text(encoding="utf-8"))}
            try:
                results = json.loads(res_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                stats["bad_file"] += 1
                continue
            done, flagged = load(family), load_flags(family)
            new, flags = [], []
            for r in results:
                s = src.get(r.get("k"))
                if s is None or r["k"] in done or r["k"] in flagged:
                    continue
                why = check(s, r)
                if why:
                    stats[f"rejected: {why}"] += 1
                    continue
                if r["agree"] != "yes":
                    flags.append({"k": r["k"], "subject": s["subject"], "key": s["key"], "agree": r["agree"],
                                  "solver_answer": r.get("solver_answer"), "note": r.get("note", ""), "q": s["q"], "o": s["o"]})
                    stats[f"flagged: {r['agree']}"] += 1
                    continue
                new.append({"k": r["k"], "e_en": r["e_en"].strip(), "e_hi": r["e_hi"].strip()})
            with (EX / f"{family}.jsonl").open("a", encoding="utf-8") as f:
                for r in new:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            with (EX / f"{family}.flags.jsonl").open("a", encoding="utf-8") as f:
                for r in flags:
                    f.write(json.dumps(r, ensure_ascii=False) + "\n")
            stats["accepted"] += len(new)
    print(dict(stats))


def apply_family(family, recs):
    """Set e_en/e_hi on each rec that has a stored explanation. Returns the ids it filled."""
    done = load(family)
    filled = set()
    for r in recs:
        e = done.get(ex_key(r))
        if e:
            r["e_en"], r["e_hi"] = e["e_en"], e["e_hi"]
            filled.add(r["id"])
    return filled


def status(_a):
    for p in sorted(PYQ.glob("*.json")):
        items = json.loads(p.read_text(encoding="utf-8"))
        keys = {ex_key(i) for i in items}
        done, flagged = load(p.stem), load_flags(p.stem)
        print(f"{p.stem}: {len(keys & set(done))}/{len(keys)} explained, {len(keys & flagged)} flagged")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export")
    e.add_argument("--family", required=True)
    e.add_argument("--out", required=True)
    e.add_argument("--batch", type=int, default=50)
    e.add_argument("--start", type=int, default=0, help="first batch number")
    e.add_argument("--subjects", default="")
    i = sub.add_parser("ingest")
    i.add_argument("dirs", nargs="+")
    sub.add_parser("status")
    a = ap.parse_args()
    {"export": export, "ingest": ingest, "status": status}[a.cmd](a)
    sys.exit(0)
