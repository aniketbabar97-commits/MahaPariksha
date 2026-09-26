"""Flag likely-duplicate questions across the bank by exact-normalized English stem.

Not a hard gate in CI (comprehension/CSAT passages legitimately share an intro
line), so this stays a separate report: run it after any content wave and
review the pairs by eye. Usage: python pipeline/check_duplicates.py
"""
import glob
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def normalize(text: str) -> str:
    return re.sub(r"[^a-z0-9]", "", text.lower())


def main():
    seen = defaultdict(list)
    for path in sorted(glob.glob(str(ROOT / "content/bank/*.json"))):
        for q in json.loads(Path(path).read_text(encoding="utf-8")):
            key = normalize(q["q_en"])
            seen[key].append((q["id"], Path(path).name))

    groups = {k: v for k, v in seen.items() if len(v) > 1}
    for key, items in groups.items():
        print(" == ".join(f"{i}({f})" for i, f in items))
    print(f"\n{len(groups)} exact-stem duplicate groups out of {sum(len(v) for v in seen.values())} questions")
    return 0


if __name__ == "__main__":
    sys.exit(main())
