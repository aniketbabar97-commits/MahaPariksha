#!/usr/bin/env python3
"""Independent fact-check pass: blind-solve each MCQ (question + options only,
no hint of our stored answer) and flag disagreements for human review. Doesn't
edit anything -- writes a JSON report for a human (or a follow-up pass) to act on.

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

    disagreements = []
    checked = 0
    total = sum(len(json.load(open(f, encoding="utf-8"))) for f in args.files)
    for path in args.files:
        items = json.load(open(path, encoding="utf-8"))
        for q in items:
            checked += 1
            prompt = PROMPT.format(q=q["q_en"], o0=q["o_en"][0], o1=q["o_en"][1], o2=q["o_en"][2], o3=q["o_en"][3])
            try:
                result = ask(args.provider, args.model, prompt, temperature=0)
            except Exception as e:
                print(f"ERROR {q['id']}: {e}", file=sys.stderr, flush=True)
                continue
            print(f"checked {checked}/{total} {q['id']}", flush=True)
            if result.get("answer_index") != q["a"] and result.get("confident", True):
                theirs = result.get("answer_index")
                disagreements.append({
                    "id": q["id"], "file": path, "q": q["q_en"],
                    "ours": q["a"], "ours_text": q["o_en"][q["a"]],
                    "theirs": theirs,
                    "theirs_text": q["o_en"][theirs] if isinstance(theirs, int) and 0 <= theirs <= 3 else None,
                })
            time.sleep(1.2 if args.provider == "groq" else 2.0)

    print(f"\nChecked {checked} questions, {len(disagreements)} disagreements")
    json.dump(disagreements, open(args.out, "w"), ensure_ascii=False, indent=1)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
