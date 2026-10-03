#!/usr/bin/env python3
"""Bulk cheat-sheet generator for RailPariksha's content/cheat_sheets/*.json files.

Unlike bulk_questions.py/bulk_flashcards.py (which top up a running count per topic),
a cheat sheet is exactly ONE entry per (subject, topic) -- a short list of formulas/key
facts worth cramming right before the exam. This script only ever fills in topics that
don't have an entry yet; it never touches or re-generates an existing one. Resumable and
flock-safe on flush, same pattern as the other two scripts, so re-running / running
alongside them is safe as long as --subjects stay disjoint.

Every drafted line is blind-verified by a second, independent model before being kept --
--verify-provider/--verify-model are required, not optional; see the comment above
VERIFY_PROMPT for why.

Usage:
    python3 bulk_cheat_sheets.py --provider groq --model qwen/qwen3.8-27b \
        --verify-provider gemini --verify-model gemini-2.5-flash \
        --max-calls 200 --subjects gk,je_civil
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

ITEMS_TARGET = 10

PROMPT = """You are writing a quick-reference cheat sheet for an Indian Railways (RRB/RPF) exam-prep app.
Subject: "{subject_en}" ({subject_hi}). Topic: "{topic_en}" ({topic_hi}).

Write {n} short, sharp, cram-worthy lines for this topic -- formulas, key definitions,
commonly-confused distinctions, important fixed facts/numbers, or quick tricks. Each line
should stand alone (no numbering needed, the app adds that), be memorizable at a glance, and
be something that actually shows up in RRB/RPF-style questions for this topic.
Output ONLY a JSON object, no markdown fences, no extra text:
{{"cat_hi": "short Hindi title for this topic's cheat-sheet card",
  "cat_en": "same title in English",
  "items": [
    {{"hi": "one cram-worthy line in Hindi", "en": "same line in English"}},
    ... {n} items total
]}}

CRITICAL: only state facts, figures, formulas and numbers you are highly confident are correct
and stable. If unsure of an exact number, phrase the line more generally instead of guessing.
Do not invent statistics. Keep each line short -- one formula, fact, or distinction, not a
paragraph.

CRITICAL for the "hi" side: must contain actual Hindi (Devanagari) words, never bare
numbers/symbols/English copied unchanged from the "en" side (formulas/symbols themselves may
of course stay in their usual notation on both sides)."""

# A first cheat-sheet draft (qwen/qwen3.8-27b, tested live) confidently stated several wrong
# "stable" facts -- Lok Sabha strength as "542 elected + 232 nominated", the Budget Session
# as "June to July", the Supreme Court as "31 other judges" -- exactly the kind of error that
# is most damaging here, since these lines are meant to be memorized verbatim. A single
# drafting model cannot be trusted on its own, so every item is blind cross-checked by a
# second, independent model before being kept; items the verifier flags as wrong/unstable
# are dropped rather than the whole entry, same spirit as bulk_questions.py's reasoning
# blind-solve check and ca_daily.py's cross-model check.
VERIFY_PROMPT = """Fact-check these claimed lines for an Indian government-exam cheat sheet (topic:
{topic_en}). For EACH line, decide if it is a well-established, stable, CORRECT fact/formula that
would hold up in a real exam -- not outdated, not a plausible-sounding invention, not a vague
approximation stated as exact.

Lines:
{lines}

Respond with ONLY a JSON object: {{"verdicts": [true/false, ... one per line, same order]}}"""


def verify_items(verify_provider, verify_model, verify_kw, topic_en, items):
    lines = "\n".join(f"{i}. {it['en']}" for i, it in enumerate(items))
    prompt = VERIFY_PROMPT.format(topic_en=topic_en, lines=lines)
    result = ask(verify_provider, verify_model, prompt, **verify_kw)
    verdicts = result.get("verdicts", [])
    if len(verdicts) != len(items):
        return []
    return [it for it, ok in zip(items, verdicts) if ok is True]


def flush(path, new_entry):
    with open(path, "r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        current = json.load(f)
        have = {(c["s"], c["t"]) for c in current}
        landed = 0
        if (new_entry["s"], new_entry["t"]) not in have:
            current.append(new_entry)
            landed = 1
        f.seek(0)
        f.truncate()
        json.dump(current, f, ensure_ascii=False, indent=1)
        fcntl.flock(f, fcntl.LOCK_UN)
    return landed


def valid(result, subject_id):
    try:
        if not (isinstance(result.get("cat_hi"), str) and result["cat_hi"].strip()):
            return False
        if not (isinstance(result.get("cat_en"), str) and result["cat_en"].strip()):
            return False
        items = result.get("items", [])
        if not (isinstance(items, list) and 1 <= len(items) <= 30):
            return False
        for it in items:
            if not (isinstance(it.get("hi"), str) and it["hi"].strip()):
                return False
            if not (isinstance(it.get("en"), str) and it["en"].strip()):
                return False
            if subject_id != "english" and not DEVANAGARI.search(it["hi"]):
                return False
        return True
    except (AttributeError, TypeError):
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--max-calls", type=int, default=100)
    p.add_argument("--subjects", help="comma-separated subject ids to restrict to")
    p.add_argument("--topics", help="comma-separated topic ids to further restrict to")
    p.add_argument("--gemini-key-env", default="GEMINI_API_KEY")
    p.add_argument("--verify-provider", required=True, choices=["groq", "gemini"],
                    help="independent second model that blind-checks every drafted line; "
                         "required, not optional -- see the comment above VERIFY_PROMPT")
    p.add_argument("--verify-model", required=True)
    p.add_argument("--verify-gemini-key-env", default="GEMINI_API_KEY")
    p.add_argument("--min-items", type=int, default=5,
                    help="minimum lines that must survive verification to keep the entry at all")
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
        path = f"{ROOT}/content/cheat_sheets/{s['id']}.json"
        if not os.path.exists(path):
            json.dump([], open(path, "w", encoding="utf-8"))
        items = json.load(open(path, encoding="utf-8"))
        have_topics = {c["t"] for c in items}

        topics = [t for t in s["topics"] if t["id"] not in have_topics
                  and (only_topics is None or t["id"] in only_topics)]
        random.shuffle(topics)
        for t in topics:
            if calls >= args.max_calls:
                break
            prompt = PROMPT.format(subject_en=s["en"], subject_hi=s["hi"], topic_en=t["en"],
                                    topic_hi=t["hi"], n=ITEMS_TARGET)
            try:
                kw = {"api_key_env": args.gemini_key_env} if args.provider == "gemini" else {}
                result = ask(args.provider, args.model, prompt, **kw)
            except Exception as e:
                print(f"ERROR {s['id']}/{t['id']}: {e}", file=sys.stderr, flush=True)
                calls += 1
                time.sleep(3)
                continue
            calls += 1
            if not valid(result, s["id"]):
                print(f"SKIP {s['id']}/{t['id']}: malformed result", file=sys.stderr, flush=True)
                time.sleep(1.5 if args.provider == "groq" else 2.0)
                continue
            time.sleep(1.5 if args.provider == "groq" else 2.0)

            verify_kw = {"api_key_env": args.verify_gemini_key_env} if args.verify_provider == "gemini" else {}
            try:
                kept = verify_items(args.verify_provider, args.verify_model, verify_kw, t["en"], result["items"])
            except Exception as e:
                print(f"SKIP {s['id']}/{t['id']}: verify failed: {e}", file=sys.stderr, flush=True)
                calls += 1
                time.sleep(3)
                continue
            calls += 1
            dropped = len(result["items"]) - len(kept)
            if len(kept) < args.min_items:
                print(f"SKIP {s['id']}/{t['id']}: only {len(kept)}/{len(result['items'])} lines "
                      f"survived fact-check (need {args.min_items})", file=sys.stderr, flush=True)
                time.sleep(1.5 if args.verify_provider == "groq" else 2.0)
                continue

            entry = {"id": f"cs-{s['id']}-{t['id']}", "s": s["id"], "t": t["id"],
                      "cat_hi": result["cat_hi"], "cat_en": result["cat_en"],
                      "items_hi": [it["hi"] for it in kept],
                      "items_en": [it["en"] for it in kept]}
            landed = flush(path, entry)
            added_total += landed
            if landed:
                print(f"{s['id']}/{t['id']}: added {len(kept)} lines ({dropped} dropped by fact-check) "
                      f"(call {calls}/{args.max_calls}, total added {added_total})", flush=True)
            time.sleep(1.5 if args.verify_provider == "groq" else 2.0)

    print(f"DONE. calls={calls} added_total={added_total}")


if __name__ == "__main__":
    main()
