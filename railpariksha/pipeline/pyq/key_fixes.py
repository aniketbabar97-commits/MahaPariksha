"""Applies answer-key corrections to the PYQ packs.

explanations/key_fixes.jsonl lists questions whose published key is demonstrably wrong: the
solver, a blind second verifier and two further blind verifiers all derived the same different
answer (arithmetic, counting and logic items, never open facts or seating puzzles that depend on a
left/right convention). Everything else keeps the official key.

  python3 pipeline/pyq/key_fixes.py          # rewrite content/pyq/*.json (idempotent)

Each fix sets the answer index and replaces the generic answer-key line with the working, noting
that the published key differs, so a student who computed the answer is not told they are wrong.
Run it after any rebuild of the packs from the PDFs.
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import explain  # noqa: E402  (ex_key)

PYQ = HERE.parent.parent / "content/pyq"
FIXES = HERE / "explanations/key_fixes.jsonl"


def main():
    by_family = defaultdict(dict)
    for line in FIXES.open(encoding="utf-8"):
        r = json.loads(line)
        by_family[r["family"]][r["k"]] = r
    changed = 0
    for family, fixes in by_family.items():
        path = PYQ / f"{family}.json"
        recs = json.loads(path.read_text(encoding="utf-8"))
        for rec in recs:
            fx = fixes.get(explain.ex_key(rec))
            if not fx:
                continue
            new = fx["new"]
            rec["a"] = new
            en = rec.get("o_en") or rec.get("o_hi")
            hi = rec.get("o_hi") or rec.get("o_en")
            why = fx["why"].strip().rstrip(".")
            rec["e_en"] = (f"Correct answer: {en[new]}. {why}. Note: the published answer key lists a different "
                           "option; working the question out gives this answer.")
            rec["e_hi"] = (f"सही उत्तर: {hi[new]}। ध्यान दें: प्रकाशित उत्तर कुंजी में अलग विकल्प दिया गया है, "
                           "पर प्रश्न हल करने पर यही उत्तर आता है।")
            changed += 1
        path.write_text("[\n" + ",\n".join(json.dumps(r, ensure_ascii=False) for r in recs) + "\n]\n", encoding="utf-8")
    print(f"key fixes applied to {changed} records")


if __name__ == "__main__":
    main()
