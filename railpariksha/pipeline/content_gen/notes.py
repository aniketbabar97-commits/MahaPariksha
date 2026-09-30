#!/usr/bin/env python3
"""Draft topic notes (summary + facts + mind-map) for RailPariksha's
content/notes/*.json files, for every (subject, topic) that doesn't have one
yet. Matches the exact schema pipeline/validate.py's check_note() enforces.

Usage:
    python3 notes.py --provider groq --model qwen/qwen3.8-27b \
        --limit 20 --subjects maths,reasoning

Same warning as bulk_questions.py: always pass disjoint --subjects to
concurrently-running instances, or you'll race on the same notes file.
"""
import argparse
import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from _providers import ask  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

SCHEMA_PROMPT = """You are writing a revision note for an Indian Railways (RRB/RPF) exam-prep app, subject
"{subject_en}" ({subject_hi}), topic "{topic_en}" ({topic_hi}).

Output ONLY a JSON object, no markdown fences, no extra text, with this exact shape:
{{
  "summary_hi": "5-8 sentence paragraph in natural, correct, exam-register Hindi (Devanagari) covering the core concept",
  "summary_en": "the same content in natural English, not a literal translation",
  "facts_hi": ["8 to 12 short punchy revision facts in Hindi"],
  "facts_en": ["the same facts in English, same order, same count as facts_hi"],
  "tips_hi": ["3 to 6 memory tricks / shortcuts / common-trap warnings in Hindi, exam-taker-focused"],
  "tips_en": ["the same tips in English, same order, same count as tips_hi"],
  "map": {{
    "hi": "root label in Hindi", "en": "root label in English",
    "children": [
      {{"hi": "branch 1 hi", "en": "branch 1 en", "children": [{{"hi": "leaf hi", "en": "leaf en"}}, ...]}},
      ...3 to 5 branches, most with 1-3 leaf children...
    ]
  }}
}}

CRITICAL: only include facts, figures and claims you are highly confident are correct and stable
(formulas, definitions, established rules, well-documented history). If you are not sure of a specific
number or name, phrase that point more generally instead of guessing. Do not invent statistics.

For tips_hi/tips_en specifically: these are practical exam-hall aids, distinct from facts_hi/facts_en.
Good examples: a mnemonic for remembering an ordered list, a shortcut calculation method, a commonly
confused pair of terms/options examiners like to swap as a trap, or a "always check X before answering"
habit. Bad examples: restating a fact from facts_hi/facts_en, or a generic non-actionable tip like
"study regularly"."""


TIPS_PROMPT = """You are adding "tips & tricks" to an existing revision note for an Indian Railways
(RRB/RPF) exam-prep app, subject "{subject_en}" ({subject_hi}), topic "{topic_en}" ({topic_hi}).

Here is the note's existing content for context (do not repeat these as tips):
Summary: {summary_en}
Facts: {facts_en}

Output ONLY a JSON object, no markdown fences, no extra text:
{{"tips_hi": ["3 to 6 memory tricks / shortcuts / common-trap warnings in Hindi, exam-taker-focused"],
  "tips_en": ["the same tips in English, same order, same count as tips_hi"]}}

Good tips: a mnemonic for remembering an ordered list, a shortcut calculation method, a commonly
confused pair of terms/options examiners like to swap as a trap, or a "always check X before
answering" habit. Bad tips: restating a fact already listed above, or a generic non-actionable tip
like "study regularly". Only state tips you are highly confident are accurate -- do not invent
statistics or rules."""


def augment_tips(provider, model, subjects_filter):
    """Backfill tips_hi/tips_en into existing notes that predate that field
    (written before this schema addition)."""
    tax = json.load(open(f"{ROOT}/content/taxonomy.json", encoding="utf-8"))
    subj_names = {s["id"]: (s["hi"], s["en"]) for s in tax["subjects"]}
    topic_names = {s["id"]: {t["id"]: (t["hi"], t["en"]) for t in s["topics"]} for s in tax["subjects"]}

    only = set(subjects_filter.split(",")) if subjects_filter else None
    updated = 0
    for f in sorted(glob.glob(f"{ROOT}/content/notes/*.json")):
        sid = os.path.splitext(os.path.basename(f))[0]
        if only is not None and sid not in only:
            continue
        notes = json.load(open(f, encoding="utf-8"))
        changed = False
        for n in notes:
            if n.get("tips_hi"):
                continue
            s_hi, s_en = subj_names.get(n["s"], (n["s"], n["s"]))
            t_hi, t_en = topic_names.get(n["s"], {}).get(n["t"], (n["t"], n["t"]))
            prompt = TIPS_PROMPT.format(
                subject_en=s_en, subject_hi=s_hi, topic_en=t_en, topic_hi=t_hi,
                summary_en=n.get("summary_en", ""), facts_en="; ".join(n.get("facts_en", [])))
            try:
                tips = ask(provider, model, prompt, temperature=0.3)
                n["tips_hi"] = tips["tips_hi"]
                n["tips_en"] = tips["tips_en"]
            except Exception as e:
                print(f"ERROR tips for {n['id']}: {e}", file=sys.stderr, flush=True)
                continue
            changed = True
            updated += 1
            print(f"tips added {updated}: {n['id']}", flush=True)
            time.sleep(1.5 if provider == "groq" else 2.0)
        if changed:
            json.dump(notes, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"done, {updated} notes got tips backfilled")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--limit", type=int, default=60)
    p.add_argument("--subjects", help="comma-separated subject ids to restrict to")
    p.add_argument("--augment-tips", action="store_true",
                    help="backfill tips_hi/tips_en into existing notes that predate that field, "
                         "instead of drafting new notes")
    args = p.parse_args()

    if args.augment_tips:
        augment_tips(args.provider, args.model, args.subjects)
        return

    tax = json.load(open(f"{ROOT}/content/taxonomy.json", encoding="utf-8"))
    have = set()
    for f in glob.glob(f"{ROOT}/content/notes/*.json"):
        for n in json.load(open(f, encoding="utf-8")):
            have.add((n["s"], n["t"]))

    only = set(args.subjects.split(",")) if args.subjects else None
    written = 0
    for s in tax["subjects"]:
        if only is not None and s["id"] not in only:
            continue
        by_subject = []
        existing_path = f"{ROOT}/content/notes/{s['id']}.json"
        if os.path.exists(existing_path):
            by_subject = json.load(open(existing_path, encoding="utf-8"))
        for t in s["topics"]:
            if (s["id"], t["id"]) in have:
                continue
            if written >= args.limit:
                break
            prompt = SCHEMA_PROMPT.format(subject_en=s["en"], subject_hi=s["hi"], topic_en=t["en"], topic_hi=t["hi"])
            try:
                note = ask(args.provider, args.model, prompt, temperature=0.3)
                note["id"] = f"note-{s['id']}-{t['id']}"
                note["s"] = s["id"]
                note["t"] = t["id"]
            except Exception as e:
                print(f"ERROR {s['id']}/{t['id']}: {e}", file=sys.stderr, flush=True)
                continue
            by_subject.append(note)
            written += 1
            print(f"drafted {written}/{args.limit}: {s['id']}/{t['id']}", flush=True)
            json.dump(by_subject, open(existing_path, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
            time.sleep(1.5 if args.provider == "groq" else 2.0)
        if written >= args.limit:
            break
    print(f"done, {written} notes drafted")


if __name__ == "__main__":
    main()
