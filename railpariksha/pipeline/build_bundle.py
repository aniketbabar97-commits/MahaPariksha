"""Merge validated content into the single pack the app ships with.

Usage: python pipeline/build_bundle.py [--out PATH]
Output defaults to app/assets/content/bundle.json. The version is a UTC timestamp,
so a downloaded pack with a newer version replaces the bundled one on devices.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate import resolve_exam_strategy  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"


def load_dir(name):
    items = []
    for p in sorted((CONTENT / name).glob("*.json")):
        items.extend(json.loads(p.read_text(encoding="utf-8")))
    return items


RAIL_EXAMS = ("RRB", "RPF")

# Options that point at each other ("All of the above", "Both A and B") or at a letter must
# keep their order, as must numeric options already listed in order.
RELATIONAL = re.compile(r"(?i)\b(above|these|both|neither|all of|none of|option|statements?)\b|"
                        r"उपरोक्त|ऊपर|सभी|कोई नहीं|दोनों|विकल्प|कथन|\b[A-D]\b\s*(?:and|और|,)\s*\b[A-D]\b|\([a-dA-D1-4]\)")


def _number(o):
    try:
        return float(re.sub(r"[,\s]", "", o))
    except ValueError:
        return None


def balance_answer_positions(q):
    """The hand/AI-written bank puts the right answer in A or B far too often (71%), which a
    student can learn. Move the correct option to a position drawn from the question's id
    (stable across builds), keeping the distractors in their original order. PYQs keep the
    paper's own order. Returns True when the question was changed."""
    if q.get("pyq") or q["id"].startswith("pyq"):
        return False
    opts = {l: q[f"o_{l}"] for l in ("hi", "en") if f"o_{l}" in q}
    texts = [t for o in opts.values() for t in o] + [q.get("e_en", ""), q.get("e_hi", "")]
    if any(RELATIONAL.search(t) for t in texts):
        return False
    for o in opts.values():
        nums = [_number(t) for t in o]
        if None not in nums and (nums == sorted(nums) or nums == sorted(nums, reverse=True)):
            return False
    a, target = q["a"], int(hashlib.md5(q["id"].encode()).hexdigest(), 16) % 4
    if a == target:
        return False
    for l, o in opts.items():
        rest = o[:a] + o[a + 1:]
        q[f"o_{l}"] = rest[:target] + [o[a]] + rest[target:]
    q["a"] = target
    return True


def build_pyq_pack(out_dir):
    """Previous-year questions ship as their own asset pack, separate from the main
    bundle: index.json lists every exam/year set (with per-paper and per-subject
    counts), and each set is its own file the app loads only when it's opened --
    so ~80k PYQs cost nothing at startup or in the main content pack."""
    import re
    from collections import Counter, defaultdict
    questions = load_dir("pyq")
    sets = defaultdict(list)
    for q in questions:
        # Labels look like "RRB Group D CBT-1 · 19 Dec 2025 · Shift 2" (exam/stage, date, shift).
        head = q["pyq"].split(" · ")[0]
        year = re.search(r"(20\d\d)", q["pyq"].split(" · ")[1] if " · " in q["pyq"] else q["pyq"]).group(1)
        sets[(head, int(year))].append(q)
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.json"):
        old.unlink()
    index = []
    for (exam, year), qs in sorted(sets.items(), key=lambda kv: (not kv[0][0].startswith(RAIL_EXAMS), kv[0][0], -kv[0][1])):
        file = f"{re.sub(r'[^a-z0-9]+', '_', exam.lower())}_{year}.json"
        (out_dir / file).write_text(json.dumps(qs, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        papers = Counter(q["pyq"] for q in qs)
        index.append({"exam": exam, "year": year, "rail": exam.startswith(RAIL_EXAMS), "file": file, "n": len(qs),
                      "subjects": dict(Counter(q["s"] for q in qs)),
                      "papers": [{"label": k, "n": v} for k, v in sorted(papers.items())]})
    (out_dir / "index.json").write_text(json.dumps({"sets": index}, ensure_ascii=False, separators=(",", ":")),
                                        encoding="utf-8")
    size = sum(p.stat().st_size for p in out_dir.glob("*.json")) // 1024
    print(f"wrote {out_dir}: {len(questions)} PYQs in {len(index)} sets, {size} KB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "app/assets/content/bundle.json"))
    ap.add_argument("--pyq-out", default=str(ROOT / "app/assets/pyq"),
                    help="where to write the PYQ pack ('' to skip, e.g. for the downloadable content pack)")
    args = ap.parse_args()

    if subprocess.run([sys.executable, str(ROOT / "pipeline/validate.py")]).returncode != 0:
        sys.exit("validation failed; bundle not built")

    taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    exam_strategy = resolve_exam_strategy(
        json.loads((CONTENT / "exam_strategy.json").read_text(encoding="utf-8"))
    )
    gk_booster_path = CONTENT / "gk_booster.json"
    gk_booster = json.loads(gk_booster_path.read_text(encoding="utf-8")) if gk_booster_path.exists() else None
    questions = load_dir("bank")
    moved = sum(balance_answer_positions(q) for q in questions)
    print(f"answer positions rebalanced on {moved} questions")
    for q in questions:
        # Source links stay in the repo, not on devices, for the bulk of the bank (keeps
        # the pack small, and most content has no use for one in the app). Exception:
        # dated, auto-drafted current-affairs items keep theirs -- the Current Affairs
        # digest shows a "read the source" link per item, and there are only ever a
        # handful of these at a time.
        if not q.get("date"):
            q.pop("src", None)
    bundle = {
        "version": int(datetime.now(timezone.utc).strftime("%Y%m%d%H%M")),
        "taxonomy": taxonomy,
        "questions": questions,
        "flashcards": load_dir("flashcards"),
        "motivation": load_dir("motivation"),
        "notes": load_dir("notes"),
        "exam_strategy": exam_strategy,
        "cheat_sheets": load_dir("cheat_sheets"),
    }
    if gk_booster is not None:
        bundle["gk_booster"] = gk_booster
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(bundle, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {out} v{bundle['version']}: {len(questions)} questions, "
          f"{len(bundle['flashcards'])} flashcards, {len(bundle['motivation'])} motivation, "
          f"{len(bundle['cheat_sheets'])} cheat sheets, "
          f"{out.stat().st_size // 1024} KB")
    if args.pyq_out:
        build_pyq_pack(Path(args.pyq_out))


if __name__ == "__main__":
    main()
