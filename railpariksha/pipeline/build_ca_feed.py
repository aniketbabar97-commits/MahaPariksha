"""Builds content/ca_feed.json: the last two weeks of dated current-affairs questions, in exactly the
shape build_bundle.py puts them in the app bundle.

The app fetches this small file (tens of KB, not the ~38 MB pack) on launch and merges any question it
doesn't already have, so the Current Affairs digest stays current between app releases. The daily
workflow regenerates it next to bank/current_affairs_auto.json, so merging the daily PR publishes it.

  python pipeline/build_ca_feed.py            # write content/ca_feed.json
  python pipeline/build_ca_feed.py --check    # exit 1 when the committed file is out of date
"""
import argparse
import json
import sys
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_bundle import balance_answer_positions, pretty  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "content/bank/current_affairs_auto.json"
OUT = ROOT / "content/ca_feed.json"
KEEP_DAYS = 14


def build():
    items = [q for q in json.loads(SRC.read_text(encoding="utf-8")) if q.get("date")]
    if not items:
        return {"version": 0, "questions": []}
    newest = max(date.fromisoformat(q["date"]) for q in items)
    keep = [q for q in items if date.fromisoformat(q["date"]) > newest - timedelta(days=KEEP_DAYS)]
    for q in keep:
        balance_answer_positions(q)  # same treatment as the bundle, so ids/answers match it
    keep.sort(key=lambda q: (q["date"], q["id"]))
    # Grows whenever a day or an item is added, so the app can tell a newer feed from an older one.
    version = int(newest.strftime("%Y%m%d")) * 1000 + len(keep)
    return {"version": version, "questions": pretty(keep)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    text = json.dumps(build(), ensure_ascii=False, separators=(",", ":")) + "\n"
    if args.check:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            sys.exit("content/ca_feed.json is out of date: run python pipeline/build_ca_feed.py")
        return
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT}: {len(json.loads(text)['questions'])} questions, {len(text) // 1024} KB")


if __name__ == "__main__":
    main()
