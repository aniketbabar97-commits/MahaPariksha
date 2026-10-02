#!/usr/bin/env python3
"""Independent fact-check pass: blind-solve each MCQ (question + options only,
no hint of our stored answer) and flag disagreements for human review. Doesn't
edit anything -- writes a JSON report for a human (or a follow-up pass) to act on.

Resumable: --out doubles as a checkpoint. Every question checked (not just
disagreements) is recorded in it as it happens, so a kill/restart (this ran as
a session-start-hook background worker, which restarts on every container
restart with no other persistence) picks back up after the last question
actually checked instead of re-spending the same API quota re-checking
everything from the start.

Usage:
    python3 factcheck.py --provider groq --model qwen/qwen3.8-27b ../content/bank/*.json
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from _providers import ask  # noqa: E402

PROMPT = """You are fact-checking a multiple-choice question for an Indian Railways (RRB/RPF) exam-prep app.
Answer strictly from your own knowledge. Respond with ONLY a JSON object, no markdown fences, no extra text:
{{"answer_index": <0-3>, "confident": <true/false>}}

Q: {q}
0. {o0}
1. {o1}
2. {o2}
3. {o3}"""


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--out", default="disagreements.json")
    p.add_argument("files", nargs="+")
    args = p.parse_args()

    state = {"done_ids": [], "disagreements": []}
    if os.path.exists(args.out):
        try:
            loaded = json.load(open(args.out, encoding="utf-8"))
            if isinstance(loaded, dict) and "done_ids" in loaded:
                state = loaded
        except (json.JSONDecodeError, OSError):
            pass
    done_ids = set(state["done_ids"])
    disagreements = state["disagreements"]

    def save():
        json.dump({"done_ids": sorted(done_ids), "disagreements": disagreements},
                   open(args.out, "w"), ensure_ascii=False, indent=1)

    checked = len(done_ids)
    total = sum(len(json.load(open(f, encoding="utf-8"))) for f in args.files)
    if checked:
        print(f"resuming: {checked}/{total} already checked", flush=True)
    for path in args.files:
        items = json.load(open(path, encoding="utf-8"))
        for q in items:
            if q["id"] in done_ids:
                continue
            prompt = PROMPT.format(q=q["q_en"], o0=q["o_en"][0], o1=q["o_en"][1], o2=q["o_en"][2], o3=q["o_en"][3])
            try:
                result = ask(args.provider, args.model, prompt, temperature=0)
            except Exception as e:
                print(f"ERROR {q['id']}: {e}", file=sys.stderr, flush=True)
                continue
            checked += 1
            print(f"checked {checked}/{total} {q['id']}", flush=True)
            if result.get("answer_index") != q["a"] and result.get("confident", True):
                theirs = result.get("answer_index")
                disagreements.append({
                    "id": q["id"], "file": path, "q": q["q_en"],
                    "ours": q["a"], "ours_text": q["o_en"][q["a"]],
                    "theirs": theirs,
                    "theirs_text": q["o_en"][theirs] if isinstance(theirs, int) and 0 <= theirs <= 3 else None,
                })
            done_ids.add(q["id"])
            save()
            time.sleep(1.2 if args.provider == "groq" else 2.0)

    print(f"\nChecked {checked} questions, {len(disagreements)} disagreements")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
