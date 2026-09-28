#!/usr/bin/env python3
"""Bulk MCQ generator for RailPariksha's content/bank/*.json files.

Resumable: reads existing bank files, tops each (subject, topic) up to a target
count, batching N questions per LLM call. Dedups by normalized question text.
Flushes to disk after every successful batch so a crash / rate-limit stop never
loses progress -- re-run the same command to continue.

Usage:
    python3 bulk_questions.py --provider groq --model qwen/qwen3.8-27b \
        --max-calls 500 --subjects maths,reasoning,gk

IMPORTANT: when running the Groq and Gemini variants of this script at the same
time, always pass disjoint --subjects lists to each. Both write into the same
content/bank/<subject>.json files with a read-modify-write cycle and no file
locking; running two processes against the *same* subject concurrently is a
race condition that silently drops or duplicates entries (this bit us once --
see git history for the "dedupe science bank" / "dedupe notes race condition"
commits).
"""
import argparse
import json
import os
import random
import re
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from _providers import ask, norm  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# current_affairs is kept small: date-sensitive facts age out fast, so we don't
# want thousands of them going stale. Everything else scales up.
TARGETS = {"current_affairs": 15}
DEFAULT_TARGET = 300
BATCH = 10

ANGLES = [
    "definitions and basic concepts", "numerical/calculation-based problems",
    "important dates, people, and named facts", "comparisons and 'which of the following' style",
    "application-based scenario questions", "common misconceptions / trap options",
    "formula-based direct application", "classification and categorisation",
    "cause-effect and reasoning chains", "exam-frequently-repeated question patterns",
]

PROMPT = """You are writing NEW multiple-choice questions for an Indian Railways (RRB/RPF) exam-prep app.
Subject: "{subject_en}" ({subject_hi}). Topic: "{topic_en}" ({topic_hi}).
Focus this batch on: {angle}.

Write {n} DISTINCT questions, difficulty mix across 1 (easy), 2 (medium), 3 (hard).
Output ONLY a JSON object, no markdown fences, no extra text:
{{"questions": [
  {{
    "q_hi": "question in natural Hindi (Devanagari)", "q_en": "same question in natural English (not literal translation)",
    "o_hi": ["4 options in Hindi"], "o_en": ["4 options in English, same order/meaning as o_hi"],
    "a": <0-3 correct index>,
    "e_hi": "1-3 sentence explanation in Hindi", "e_en": "1-3 sentence explanation in English",
    "d": <1, 2, or 3>
  }}, ... {n} items total
]}}

CRITICAL: only state facts, figures, dates and names you are highly confident are correct and stable.
If unsure of an exact number/date, write a question that doesn't depend on it. Do not invent statistics.
Do not repeat well-known previous exam questions verbatim in a way that could be duplicated; vary phrasing and angle.
Exactly 4 options each, exactly one correct answer, options must not overlap in meaning."""


def valid(q):
    try:
        if not (isinstance(q["q_hi"], str) and isinstance(q["q_en"], str) and q["q_hi"] and q["q_en"]):
            return False
        if not (isinstance(q["o_hi"], list) and len(q["o_hi"]) == 4):
            return False
        if not (isinstance(q["o_en"], list) and len(q["o_en"]) == 4):
            return False
        if not (isinstance(q["a"], int) and 0 <= q["a"] <= 3):
            return False
        if not (isinstance(q["e_hi"], str) and isinstance(q["e_en"], str) and q["e_hi"] and q["e_en"]):
            return False
        if len(set(norm(o) for o in q["o_en"])) != 4:
            return False
        # norm() strips non-ASCII, so it can't check Hindi options (Devanagari would
        # all collapse to ""); a plain exact-string dedup catches genuine duplicates
        # (e.g. "a"/"an" both translating to the same Hindi word) without that bug.
        if len(set(o.strip() for o in q["o_hi"])) != 4:
            return False
        return True
    except (KeyError, TypeError):
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--max-calls", type=int, default=200)
    p.add_argument("--subjects", help="comma-separated subject ids to restrict to (required when running "
                                       "alongside another instance -- see module docstring)")
    p.add_argument("--id-prefix-suffix", default="", help="appended to the generated id's subject prefix, "
                                                            "e.g. 'g' for Gemini runs, to keep ids distinguishable")
    args = p.parse_args()

    tax = json.load(open(f"{ROOT}/content/taxonomy.json", encoding="utf-8"))
    only = set(args.subjects.split(",")) if args.subjects else None
    calls = 0
    added_total = 0

    subjects = [s for s in tax["subjects"] if only is None or s["id"] in only]
    random.shuffle(subjects)

    for s in subjects:
        if calls >= args.max_calls:
            break
        target = TARGETS.get(s["id"], DEFAULT_TARGET)
        path = f"{ROOT}/content/bank/{s['id']}.json"
        items = json.load(open(path, encoding="utf-8")) if os.path.exists(path) else []
        seen_norm = {norm(q["q_en"]) for q in items}
        by_topic = {}
        for q in items:
            by_topic.setdefault(q["t"], []).append(q)
        existing_ids = [int(m.group(1)) for q in items if (m := re.search(r"(\d+)$", q["id"]))]
        next_num = (max(existing_ids) + 1) if existing_ids else 1

        topics = list(s["topics"])
        random.shuffle(topics)
        for t in topics:
            if calls >= args.max_calls:
                break
            count = len(by_topic.get(t["id"], []))
            rounds_here = 0
            while count < target and calls < args.max_calls and rounds_here < 40:
                angle = random.choice(ANGLES)
                prompt = PROMPT.format(subject_en=s["en"], subject_hi=s["hi"], topic_en=t["en"],
                                        topic_hi=t["hi"], angle=angle, n=BATCH)
                try:
                    result = ask(args.provider, args.model, prompt)
                    batch = result.get("questions", [])
                except Exception as e:
                    print(f"ERROR {s['id']}/{t['id']}: {e}", file=sys.stderr, flush=True)
                    calls += 1
                    rounds_here += 1
                    time.sleep(3)
                    continue
                calls += 1
                rounds_here += 1
                new_items = []
                for q in batch:
                    if not valid(q):
                        continue
                    key = norm(q["q_en"])
                    if key in seen_norm:
                        continue
                    seen_norm.add(key)
                    q2 = {"id": f"rp-{s['id'][:3]}-{args.id_prefix_suffix}{next_num:05d}", "s": s["id"], "t": t["id"],
                          "d": q["d"] if q.get("d") in (1, 2, 3) else 2,
                          "q_hi": q["q_hi"], "q_en": q["q_en"], "o_hi": q["o_hi"], "o_en": q["o_en"],
                          "a": q["a"], "e_hi": q["e_hi"], "e_en": q["e_en"]}
                    next_num += 1
                    new_items.append(q2)
                if new_items:
                    items.extend(new_items)
                    by_topic.setdefault(t["id"], []).extend(new_items)
                    count = len(by_topic[t["id"]])
                    added_total += len(new_items)
                    json.dump(items, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
                    print(f"{s['id']}/{t['id']}: +{len(new_items)} (topic now {count}/{target}, "
                          f"call {calls}/{args.max_calls}, total added {added_total})", flush=True)
                time.sleep(1.5 if args.provider == "groq" else 2.0)

    print(f"DONE. calls={calls} added_total={added_total}")


if __name__ == "__main__":
    main()
