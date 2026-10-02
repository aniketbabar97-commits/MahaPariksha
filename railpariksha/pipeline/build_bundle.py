"""Merge validated content into the single pack the app ships with.

Usage: python pipeline/build_bundle.py [--out PATH]
Output defaults to app/assets/content/bundle.json. The version is a UTC timestamp,
so a downloaded pack with a newer version replaces the bundled one on devices.
"""
import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"


def load_dir(name):
    items = []
    for p in sorted((CONTENT / name).glob("*.json")):
        items.extend(json.loads(p.read_text(encoding="utf-8")))
    return items


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "app/assets/content/bundle.json"))
    args = ap.parse_args()

    if subprocess.run([sys.executable, str(ROOT / "pipeline/validate.py")]).returncode != 0:
        sys.exit("validation failed; bundle not built")

    taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    questions = load_dir("bank")
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
    }
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(bundle, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {out} v{bundle['version']}: {len(questions)} questions, "
          f"{len(bundle['flashcards'])} flashcards, {len(bundle['motivation'])} motivation, "
          f"{out.stat().st_size // 1024} KB")


if __name__ == "__main__":
    main()
