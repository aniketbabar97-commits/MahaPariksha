#!/usr/bin/env python3
"""Bulk flashcard generator for RailPariksha's content/flashcards/*.json files.

Resumable: reads existing flashcard files, tops each (subject, topic) up to a
target count. Flushes to disk after every successful batch so a crash /
rate-limit stop never loses progress -- re-run the same command to continue.
Mirrors bulk_questions.py's flock-safe flush() so multiple instances can run
against the same subject without racing each other.

Usage:
    python3 bulk_flashcards.py --provider groq --model qwen/qwen3.8-27b \
        --max-calls 200 --subjects english,je_mechanical
"""
import argparse
import fcntl
import json
import os
import random
import re
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from _providers import ask, norm  # noqa: E402

DEVANAGARI = re.compile(r"[ऀ-ॿ]")

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# A flashcard is one key fact for quick spaced-repetition review, not a full
# question bank -- a much shallower per-topic target than bulk_questions.py's.
DEFAULT_TARGET = 6
BATCH = 6

PROMPT = """You are writing NEW spaced-repetition flashcards for an Indian Railways (RRB/RPF) exam-prep app.
Subject: "{subject_en}" ({subject_hi}). Topic: "{topic_en}" ({topic_hi}).

Write {n} DISTINCT flashcards, each a single sharp key fact, formula, definition, or commonly-confused
distinction worth memorizing for this topic -- not a full question with multiple options.
Output ONLY a JSON object, no markdown fences, no extra text:
{{"cards": [
  {{"f_hi": "front of card in Hindi (a short question/prompt)", "f_en": "same front in English",
    "b_hi": "back of card in Hindi (the concise answer/fact)", "b_en": "same back in English"}},
  ... {n} items total
]}}

CRITICAL: only state facts, figures, dates and formulas you are highly confident are correct and
stable. If unsure of an exact number/date, phrase the card more generally instead of guessing.
Do not invent statistics. Keep fronts short (a phrase or short question) and backs concise (one
fact, formula, or short sentence) -- these are quick-glance review cards, not paragraphs.

CRITICAL for f_hi/b_hi: must contain actual Hindi (Devanagari) words, never bare numbers/symbols
copied unchanged from the English side."""


def flush(path, new_items):
    with open(path, "r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        current = json.load(f)
        seen_ids = {c["id"] for c in current}
        seen_f = {norm(c["f_en"]) for c in current}
        to_add = [c for c in new_items if c["id"] not in seen_ids and norm(c["f_en"]) not in seen_f]
        current.extend(to_add)
        f.seek(0)
        f.truncate()
        json.dump(current, f, ensure_ascii=False, indent=1)
        fcntl.flock(f, fcntl.LOCK_UN)
    return len(to_add)


def valid(c, subject_id=None):
    try:
        for k in ("f_hi", "f_en", "b_hi", "b_en"):
            if not (isinstance(c[k], str) and c[k].strip()):
                return False
        if subject_id != "english" and not DEVANAGARI.search(c["f_hi"]):
            return False
        if subject_id != "english" and not DEVANAGARI.search(c["b_hi"]):
            return False
        return True
    except (KeyError, TypeError):
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--max-calls", type=int, default=200)
    p.add_argument("--subjects", help="comma-separated subject ids to restrict to")
    p.add_argument("--topics", help="comma-separated topic ids to further restrict to")
    p.add_argument("--target", type=int, default=DEFAULT_TARGET)
    p.add_argument("--gemini-key-env", default="GEMINI_API_KEY")
    args = p.parse_args()

    tax = json.load(open(f"{ROOT}/content/taxonomy.json", encoding="utf-8"))
    only = set(args.subjects.split(",")) if args.subjects else None
    only_topics = set(args.topics.split(",")) if args.topics else None
    calls = 0
    added_total = 0

    subjects = [s for s in tax["subjects"] if only is None or s["id"] in only]
    random.shuffle(subjects)

    for s in subjects:
        if calls >= args.max_calls:
            break
        path = f"{ROOT}/content/flashcards/{s['id']}.json"
        if not os.path.exists(path):
            json.dump([], open(path, "w", encoding="utf-8"))
        items = json.load(open(path, encoding="utf-8"))
        seen_norm = {norm(c["f_en"]) for c in items}
        by_topic = {}
        for c in items:
            by_topic.setdefault(c["t"], []).append(c)
        existing_nums = [int(m.group(1)) for c in items if (m := re.search(r"(\d+)$", c["id"]))]
        next_num = (max(existing_nums) + 1) if existing_nums else 1

        topics = [t for t in s["topics"] if only_topics is None or t["id"] in only_topics]
        random.shuffle(topics)
        for t in topics:
            if calls >= args.max_calls:
                break
            count = len(by_topic.get(t["id"], []))
            rounds_here = 0
            while count < args.target and calls < args.max_calls and rounds_here < 10:
                prompt = PROMPT.format(subject_en=s["en"], subject_hi=s["hi"], topic_en=t["en"],
                                        topic_hi=t["hi"], n=BATCH)
                try:
                    kw = {"api_key_env": args.gemini_key_env} if args.provider == "gemini" else {}
                    result = ask(args.provider, args.model, prompt, **kw)
                    batch = result.get("cards", [])
                except Exception as e:
                    print(f"ERROR {s['id']}/{t['id']}: {e}", file=sys.stderr, flush=True)
                    calls += 1
                    rounds_here += 1
                    time.sleep(3)
                    continue
                calls += 1
                rounds_here += 1
                new_items = []
                for c in batch:
                    if not valid(c, s["id"]):
                        continue
                    key = norm(c["f_en"])
                    if key in seen_norm:
                        continue
                    seen_norm.add(key)
                    c2 = {"id": f"fc-{s['id']}-{next_num:04d}", "s": s["id"], "t": t["id"],
                          "f_hi": c["f_hi"], "f_en": c["f_en"], "b_hi": c["b_hi"], "b_en": c["b_en"]}
                    next_num += 1
                    new_items.append(c2)
                if new_items:
                    landed = flush(path, new_items)
                    by_topic.setdefault(t["id"], []).extend(new_items)
                    count = len(by_topic[t["id"]])
                    added_total += landed
                    print(f"{s['id']}/{t['id']}: +{landed} (topic now {count}/{args.target}, "
                          f"call {calls}/{args.max_calls}, total added {added_total})", flush=True)
                time.sleep(1.5 if args.provider == "groq" else 2.0)

    print(f"DONE. calls={calls} added_total={added_total}")


if __name__ == "__main__":
    main()
