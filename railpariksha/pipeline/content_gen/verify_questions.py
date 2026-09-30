#!/usr/bin/env python3
"""Cross-verification pass over content/bank/*.json: asks an LLM to judge each
existing question for factual correctness, answer-key correctness, and logical
soundness. Does NOT rewrite content_bank/*.json itself -- flags are appended to
pipeline/logs/verify_flags/<subject>.jsonl for a human (or Claude) to review and
fix by hand, the same way the manual smoke-test findings were handled.

Resumable: which question ids have already been checked for a subject is
tracked in pipeline/content_gen/verify_state/<subject>.json (a plain list of
ids), so a restarted run skips what's already been judged instead of re-asking
the same question again.

Usage:
    python3 verify_questions.py --provider groq --model qwen/qwen3.8-27b \
        --max-calls 500 --subjects maths,reasoning
"""
import argparse
import fcntl
import glob
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(__file__))
from _providers import ask  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
STATE_DIR = os.path.join(os.path.dirname(__file__), "verify_state")
FLAGS_DIR = os.path.join(ROOT, "pipeline", "logs", "verify_flags")

PROMPT = """You are fact-checking one multiple-choice question for an Indian Railways (RRB/RPF)
exam-prep app. Subject: "{subject_en}", Topic: "{topic_en}".

Question: {q_en}
Options: {opts}
Marked correct answer: {answer}
Given explanation: {expl}

Check for:
1. Is the marked answer actually correct?
2. Does the question or explanation reference any fabricated/nonexistent law, act, scheme,
   person, statistic, or entity?
3. Is the question logically well-formed -- do the given facts actually and uniquely
   determine the marked answer (no ambiguity, no missing constraint)?
4. Any leaked meta-commentary (e.g. "(hypothetical)", "(often confused)", placeholder text)
   that shouldn't be visible to a student?

Output ONLY a JSON object, no markdown fences, no extra text:
{{"ok": true}} if the question has no such problems, or
{{"ok": false, "problem": "one or two sentence description of the specific issue"}} if it does.
Be conservative: only flag a real, specific problem you're confident about -- do not flag
stylistic preferences or omit flagging out of politeness."""


def load_state(subject):
    path = f"{STATE_DIR}/{subject}.json"
    if os.path.exists(path):
        return set(json.load(open(path, encoding="utf-8")))
    return set()


def save_state(subject, checked):
    os.makedirs(STATE_DIR, exist_ok=True)
    json.dump(sorted(checked), open(f"{STATE_DIR}/{subject}.json", "w", encoding="utf-8"))


def append_flag(subject, entry):
    os.makedirs(FLAGS_DIR, exist_ok=True)
    with open(f"{FLAGS_DIR}/{subject}.jsonl", "a", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        fcntl.flock(f, fcntl.LOCK_UN)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--max-calls", type=int, default=500)
    p.add_argument("--subjects", help="comma-separated subject ids to restrict to")
    p.add_argument("--gemini-key-env", default="GEMINI_API_KEY")
    args = p.parse_args()

    tax = json.load(open(f"{ROOT}/content/taxonomy.json", encoding="utf-8"))
    subj_names = {s["id"]: s["en"] for s in tax["subjects"]}
    topic_names = {s["id"]: {t["id"]: t["en"] for t in s["topics"]} for s in tax["subjects"]}

    only = set(args.subjects.split(",")) if args.subjects else None
    calls = 0
    flagged = 0
    checked_this_run = 0

    for f in sorted(glob.glob(f"{ROOT}/content/bank/*.json")):
        sid = os.path.splitext(os.path.basename(f))[0]
        if only is not None and sid not in only:
            continue
        if calls >= args.max_calls:
            break
        items = json.load(open(f, encoding="utf-8"))
        checked = load_state(sid)
        for q in items:
            if calls >= args.max_calls:
                break
            if q["id"] in checked:
                continue
            opts = "; ".join(f"[{i}] {o}" for i, o in enumerate(q["o_en"]))
            prompt = PROMPT.format(
                subject_en=subj_names.get(sid, sid),
                topic_en=topic_names.get(sid, {}).get(q["t"], q["t"]),
                q_en=q["q_en"], opts=opts, answer=q["o_en"][q["a"]], expl=q["e_en"])
            try:
                kw = {"api_key_env": args.gemini_key_env} if args.provider == "gemini" else {}
                result = ask(args.provider, args.model, prompt, temperature=0.1, **kw)
            except Exception as e:
                print(f"ERROR verifying {q['id']}: {e}", file=sys.stderr, flush=True)
                continue
            calls += 1
            checked.add(q["id"])
            checked_this_run += 1
            if not result.get("ok", True):
                flagged += 1
                append_flag(sid, {"id": q["id"], "t": q["t"], "q_en": q["q_en"],
                                   "problem": result.get("problem", "")})
                print(f"FLAGGED {q['id']}: {result.get('problem', '')}", flush=True)
            if checked_this_run % 5 == 0:
                save_state(sid, checked)
                print(f"progress: {sid} {checked_this_run} checked this run, {flagged} flagged total", flush=True)
            time.sleep(1.5 if args.provider == "groq" else 2.0)
        save_state(sid, checked)
    print(f"done, {checked_this_run} questions checked this run, {flagged} flagged")


if __name__ == "__main__":
    main()
