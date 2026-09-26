"""Generate the whole question bank in parallel, one worker thread per subject.

Why parallel-by-subject specifically: generate_topic() read-modify-writes
content/bank/<subject>.json and content/pending_review/<subject>.json for
whichever subject it's given. Two threads writing the SAME subject's file at
once would race and could silently drop questions. Two threads writing
DIFFERENT subjects' files never touch each other, so subject-level
parallelism is safe with no locking needed; within a subject, its topics are
still generated one at a time, in order.

These are network-bound API calls (drafting + cross-checking), so threads
(not processes) are the right tool -- Python's GIL doesn't matter here.

Usage:
  python3 pipeline/generate_all.py --per-topic 100
  python3 pipeline/generate_all.py --per-topic 50 --subjects marathi,maths,reasoning
  python3 pipeline/generate_all.py --per-topic 100 --parallel 8

--per-topic is a TARGET ceiling: existing questions for that subject/topic
count toward it, so a subject that's already well-stocked tops up rather than
overshoots. Run pipeline/validate.py, check_duplicates.py and build_bundle.py
after this finishes, same as after a single generate_questions.py run.
"""
import argparse
import json
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import generate_questions as gq

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"

_print_lock = threading.Lock()


def log(msg):
    with _print_lock:
        print(msg, flush=True)


def run_subject(subj, topics, per_topic, difficulty, batch_size):
    subject_id = subj["id"]
    bank_path = CONTENT / "bank" / f"{subject_id}.json"
    bank = gq.load_json(bank_path)
    have_by_topic = {}
    for q in bank:
        if q["s"] == subject_id:
            have_by_topic[q["t"]] = have_by_topic.get(q["t"], 0) + 1

    total_kept, total_parked = 0, 0
    for topic in topics:
        have = have_by_topic.get(topic["id"], 0)
        want = max(0, per_topic - have)
        if want == 0:
            log(f"[{subject_id}/{topic['id']}] already has {have}/{per_topic}, skipping")
            continue
        t0 = time.time()
        try:
            kept, parked = gq.generate_topic(subject_id, topic["id"], want, difficulty, batch_size, log=log)
        except Exception as e:
            log(f"[{subject_id}/{topic['id']}] FAILED: {e}")
            continue
        total_kept += kept
        total_parked += parked
        log(f"[{subject_id}/{topic['id']}] +{kept} kept, +{parked} parked ({time.time()-t0:.0f}s)")
    return subject_id, total_kept, total_parked


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--per-topic", type=int, default=100, help="target question count per topic (existing count toward it)")
    ap.add_argument("--difficulty", type=int, choices=[1, 2, 3], default=1)
    ap.add_argument("--batch-size", type=int, default=15)
    ap.add_argument("--subjects", default="", help="comma-separated subject ids; default: all")
    ap.add_argument("--parallel", type=int, default=6, help="max subjects generated concurrently")
    args = ap.parse_args()

    try:
        gq.check_providers()
    except RuntimeError as e:
        sys.exit(str(e))

    taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    subjects = taxonomy["subjects"]
    if args.subjects:
        wanted = set(args.subjects.split(","))
        subjects = [s for s in subjects if s["id"] in wanted]
        missing = wanted - {s["id"] for s in subjects}
        if missing:
            sys.exit(f"unknown subject(s): {sorted(missing)}")

    log(f"generating {len(subjects)} subjects, {args.per_topic}/topic target, {args.parallel} in parallel...")
    t0 = time.time()
    results = []
    with ThreadPoolExecutor(max_workers=args.parallel) as pool:
        futures = {
            pool.submit(run_subject, s, s["topics"], args.per_topic, args.difficulty, args.batch_size): s["id"]
            for s in subjects
        }
        for fut in as_completed(futures):
            subject_id = futures[fut]
            try:
                results.append(fut.result())
            except Exception as e:
                log(f"[{subject_id}] worker crashed: {e}")

    total_kept = sum(r[1] for r in results)
    total_parked = sum(r[2] for r in results)
    log(f"\ndone in {time.time()-t0:.0f}s: +{total_kept} kept across {len(results)} subjects, +{total_parked} parked for later audit")
    log("next: python3 pipeline/validate.py && python3 pipeline/check_duplicates.py && python3 pipeline/build_bundle.py")


if __name__ == "__main__":
    main()
