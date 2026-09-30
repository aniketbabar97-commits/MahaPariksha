#!/usr/bin/env python3
"""Cross-verification pass over content/bank/*.json: bundles a batch of questions into
ONE prompt per call and asks an LLM to judge each for factual correctness, answer-key
correctness, and logical soundness. Does NOT rewrite content/bank/*.json itself -- flags
are appended to pipeline/logs/verify_flags/<subject>.jsonl for a human (or Claude) to
review and fix by hand, the same way the manual smoke-test findings were handled.

Batching (not one-call-per-question) matters a lot under free-tier rate limits: a
provider that caps requests/day (not just tokens/minute) effectively multiplies its
daily verification throughput by the batch size, since one call now judges many
questions instead of one.

Resumable: which question ids have already been checked for a subject is tracked in
pipeline/content_gen/verify_state/<subject>.json (a plain list of ids), so a restarted
run skips what's already been judged instead of re-asking the same question again.

Usage:
    python3 verify_questions.py --provider groq --model qwen/qwen3.8-27b \
        --max-calls 500 --batch-size 20 --subjects maths,reasoning
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

BATCH_PROMPT = """You are fact-checking a batch of {n} multiple-choice questions for an Indian
Railways (RRB/RPF) exam-prep app. Subject: "{subject_en}".

For EACH question, check:
1. Is the marked answer actually correct?
2. Does the question or explanation reference any fabricated/nonexistent law, act, scheme,
   person, statistic, or entity?
3. Is the question logically well-formed -- do the given facts actually and uniquely
   determine the marked answer (no ambiguity, no missing constraint)?
4. Any leaked meta-commentary (e.g. "(hypothetical)", "(often confused)", placeholder text)
   that shouldn't be visible to a student?

Questions:
{items}

Output ONLY a JSON object, no markdown fences, no extra text:
{{"results": [{{"id": "<question id>", "ok": true}}, {{"id": "<question id>", "ok": false,
"problem": "one sentence describing the specific issue"}}, ...]}}
One result object per question, in any order, using the exact id given. Be conservative:
only flag a real, specific problem you're confident about -- do not flag stylistic
preferences or omit flagging out of politeness."""


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


def format_item(q, topic_names_for_subject):
    opts = "; ".join(f"[{i}] {o}" for i, o in enumerate(q["o_en"]))
    topic = topic_names_for_subject.get(q["t"], q["t"])
    return (f'- id: "{q["id"]}" | topic: {topic}\n'
            f'  Q: {q["q_en"]}\n  Options: {opts}\n  Marked answer: {q["o_en"][q["a"]]}\n'
            f'  Explanation: {q["e_en"]}')


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--max-calls", type=int, default=100)
    p.add_argument("--batch-size", type=int, default=20,
                    help="questions bundled into a single verification call")
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
        pending = [q for q in items if q["id"] not in checked]
        t_names = topic_names.get(sid, {})

        for batch in chunks(pending, args.batch_size):
            if calls >= args.max_calls:
                break
            by_id = {q["id"]: q for q in batch}
            items_text = "\n".join(format_item(q, t_names) for q in batch)
            prompt = BATCH_PROMPT.format(n=len(batch), subject_en=subj_names.get(sid, sid), items=items_text)
            try:
                kw = {"api_key_env": args.gemini_key_env} if args.provider == "gemini" else {}
                result = ask(args.provider, args.model, prompt, temperature=0.1, **kw)
            except Exception as e:
                print(f"ERROR verifying batch ({sid}, {len(batch)} qs): {e}", file=sys.stderr, flush=True)
                time.sleep(3)
                continue
            calls += 1
            results = result.get("results", [])
            seen_ids = set()
            for r in results:
                qid = r.get("id")
                if qid not in by_id or qid in seen_ids:
                    continue  # ignore hallucinated/duplicate ids not in this batch
                seen_ids.add(qid)
                checked.add(qid)
                checked_this_run += 1
                if not r.get("ok", True):
                    flagged += 1
                    q = by_id[qid]
                    append_flag(sid, {"id": qid, "t": q["t"], "q_en": q["q_en"],
                                       "problem": r.get("problem", "")})
                    print(f"FLAGGED {qid}: {r.get('problem', '')}", flush=True)
            missing = set(by_id) - seen_ids
            if missing:
                print(f"WARNING: model returned no verdict for {len(missing)}/{len(batch)} "
                      f"questions in this batch, re-queued for next run: {sorted(missing)[:5]}...",
                      file=sys.stderr, flush=True)
            save_state(sid, checked)
            print(f"progress: {sid} batch of {len(batch)} ({len(seen_ids)} judged), "
                  f"{checked_this_run} checked this run, {flagged} flagged total", flush=True)
            time.sleep(1.5 if args.provider == "groq" else 2.0)
    print(f"done, {checked_this_run} questions checked this run, {flagged} flagged")


if __name__ == "__main__":
    main()
