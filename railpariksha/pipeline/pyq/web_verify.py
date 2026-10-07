"""Web verification of the recent-affairs PYQs the offline solver could not confirm.

The first explanation pass (explain.py) solved from memory, so 2025-2026 current-affairs questions came back
"unsure" and kept the generic answer-key line. This pass has an agent search the web for each one:

  python3 pipeline/pyq/web_verify.py export DIR [--batch 40] [--family rrb_group_d] [--limit N] [--seed S]
      -> DIR/wv-<n>.json batches of still-unexplained, factual, "unsure" questions (and DIR/instructions.md)
  python3 pipeline/pyq/web_verify.py ingest DIR...
      -> reads DIR/*.out.json; `confirmed` items (a source states the keyed option) get their explanation stored in
         explanations/<family>.jsonl, with the source kept in explanations/web_sources.jsonl; `contradicted` items go
         to explanations/web_contradicted.jsonl for review and keep the official key; `unconfirmed` stay as they were
  python3 pipeline/pyq/web_verify.py apply
      -> writes the stored explanations into content/pyq/*.json

Nothing here changes an answer key.
"""
import argparse
import json
import random
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import explain  # noqa: E402

EX = HERE / "explanations"
PYQ = HERE.parent.parent / "content/pyq"
DEV = re.compile(r"[ऀ-ॿ]")
FACT_SUBJECTS = ("gk", "railway_gk", "current_affairs", "science", "computer")
SKIP_NOTE = re.compile(r"missing|figure|image|diagram|truncat|ambig", re.I)
INSTRUCTIONS = HERE / "web_verify_instructions.md"


def checked():
    """Questions already searched for without a confirmation (unconfirmed or contradicted): not paid for twice."""
    p = EX / "web_unconfirmed.jsonl"
    return {json.loads(l)["k"] for l in p.open(encoding="utf-8")} if p.exists() else set()


def flagged_unsure(family):
    p = EX / f"{family}.flags.jsonl"
    return [json.loads(l) for l in p.open(encoding="utf-8")] if p.exists() else []


def export(a):
    out = Path(a.dir)
    out.mkdir(parents=True, exist_ok=True)
    items = []
    for p in sorted(EX.glob("*.flags.jsonl")):
        fam = p.name.split(".")[0]
        if a.family and fam != a.family:
            continue
        done = explain.load(fam)
        for r in flagged_unsure(fam):
            if r["agree"] == "unsure" and r["subject"] in FACT_SUBJECTS and not SKIP_NOTE.search(r.get("note", "")) \
                    and r["k"] not in done and r["k"] not in checked():
                items.append(r)
    seen, uniq = set(), []
    for r in items:  # one row per question text, even if it sits in several families
        if r["k"] not in seen:
            seen.add(r["k"])
            uniq.append(r)
    random.Random(a.seed).shuffle(uniq)
    if a.limit:
        uniq = uniq[: a.limit]
    for i in range(0, len(uniq), a.batch):
        rows = [{"k": r["k"], "subject": r["subject"], "q": r["q"], "o": r["o"], "key": r["key"]} for r in uniq[i:i + a.batch]]
        (out / f"wv-{a.start + i // a.batch:03d}.json").write_text(json.dumps(rows, ensure_ascii=False, indent=0), encoding="utf-8")
    (out / "instructions.md").write_text(INSTRUCTIONS.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"{len(uniq)} questions in {-(-len(uniq) // a.batch)} batches -> {out}")


def good(r):
    e_en, e_hi = r.get("e_en"), r.get("e_hi")
    return (isinstance(e_en, str) and isinstance(e_hi, str) and 15 <= len(e_en) <= 900 and 15 <= len(e_hi) <= 1100
            and not DEV.search(e_en) and bool(DEV.search(e_hi))
            and not explain.GENERIC.search(e_en) and not explain.GENERIC.search(e_hi)
            and bool((r.get("source") or "").strip()))


def ingest(a):
    stats = Counter()
    fams_of = defaultdict(list)
    for p in sorted(EX.glob("*.flags.jsonl")):
        fam = p.name.split(".")[0]
        for r in flagged_unsure(fam):
            if r["agree"] == "unsure":
                fams_of[r["k"]].append(fam)
    for d in a.dirs:
        for res_path in sorted(Path(d).glob("*.out.json")):
            try:
                results = json.loads(res_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                stats["bad_file"] += 1
                continue
            src_path = res_path.with_name(res_path.name.replace(".out.json", ".json"))
            src = {s["k"]: s for s in json.loads(src_path.read_text(encoding="utf-8"))} if src_path.exists() else {}
            for r in results:
                k, verdict = r.get("k"), r.get("verdict")
                if k not in fams_of or k not in src:
                    stats["unknown_k"] += 1
                    continue
                if verdict == "confirmed":
                    if not good(r):
                        stats["rejected: explanation checks"] += 1
                        continue
                    for fam in fams_of[k]:
                        if k in explain.load(fam):
                            continue
                        with (EX / f"{fam}.jsonl").open("a", encoding="utf-8") as f:
                            f.write(json.dumps({"k": k, "e_en": r["e_en"].strip(), "e_hi": r["e_hi"].strip()}, ensure_ascii=False) + "\n")
                    with (EX / "web_sources.jsonl").open("a", encoding="utf-8") as f:
                        f.write(json.dumps({"k": k, "source": r["source"], "found": r.get("found", "")}, ensure_ascii=False) + "\n")
                    stats["confirmed"] += 1
                elif verdict == "contradicted":
                    s = src[k]
                    with (EX / "web_contradicted.jsonl").open("a", encoding="utf-8") as f:
                        f.write(json.dumps({"k": k, "q": s["q"], "key_text": s["o"][s["key"]], "source": r.get("source", ""),
                                            "found": r.get("found", "")}, ensure_ascii=False) + "\n")
                    stats["contradicted (key kept)"] += 1
                else:
                    stats["unconfirmed"] += 1
                if verdict != "confirmed":
                    with (EX / "web_unconfirmed.jsonl").open("a", encoding="utf-8") as f:
                        f.write(json.dumps({"k": k, "verdict": verdict, "found": r.get("found", "")}, ensure_ascii=False) + "\n")
    print(dict(stats))


def apply(_a):
    total = 0
    for p in sorted(PYQ.glob("*.json")):
        recs = json.loads(p.read_text(encoding="utf-8"))
        filled = explain.apply_family(p.stem, recs)
        total += len(filled)
        p.write_text("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False) for r in recs) + "\n]\n", encoding="utf-8")
    print(f"explanations present on {total} records")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("export")
    e.add_argument("dir")
    e.add_argument("--batch", type=int, default=40)
    e.add_argument("--family", default="")
    e.add_argument("--limit", type=int, default=0)
    e.add_argument("--seed", type=int, default=1)
    e.add_argument("--start", type=int, default=0)
    i = sub.add_parser("ingest")
    i.add_argument("dirs", nargs="+")
    sub.add_parser("apply")
    a = ap.parse_args()
    {"export": export, "ingest": ingest, "apply": apply}[a.cmd](a)
