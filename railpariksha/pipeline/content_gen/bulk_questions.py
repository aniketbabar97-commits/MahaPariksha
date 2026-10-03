#!/usr/bin/env python3
"""Bulk MCQ generator for RailPariksha's content/bank/*.json files.

Resumable: reads existing bank files, tops each (subject, topic) up to a target
count, batching N questions per LLM call. Dedups by normalized question text.
Flushes to disk after every successful batch so a crash / rate-limit stop never
loses progress -- re-run the same command to continue.

Usage:
    python3 bulk_questions.py --provider groq --model qwen/qwen3.8-27b \
        --max-calls 500 --subjects maths,reasoning,gk

Safe to run multiple instances against the SAME subject now: each save takes an
exclusive flock on the bank file, re-reads the latest on-disk content, dedups
against it, and writes -- so two processes sharing a subject no longer silently
drop each other's work (this used to be a real race; see git history for the
"dedupe science bank" / "dedupe notes race condition" / "eliminate worker
subject-overlap race" commits). Still prefer disjoint --subjects where
possible since it's simpler to reason about and avoids lock contention.
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

# current_affairs is kept small: date-sensitive facts age out fast, so we don't
# want thousands of them going stale. Everything else scales up.
# DEFAULT_TARGET=311 makes the full bank land at exactly 25,000 questions
# (80 non-current_affairs topics x 311 + 8 current_affairs topics x 15).
TARGETS = {"current_affairs": 15}
DEFAULT_TARGET = 311
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
Exactly 4 options each, exactly one correct answer, options must not overlap in meaning.

CRITICAL for q_hi: it must contain actual Hindi (Devanagari) words, never bare numbers/letters/symbols
copied unchanged from q_en. This matters most for number-series, letter-series, and ratio/analogy
questions (e.g. "2, 5, 10, 17, ?" or "3 : 9 :: 4 : ?") -- even though the sequence itself is the same
in both languages, q_hi must still frame it in Hindi, e.g. "श्रृंखला को देखें: 2, 5, 10, 17, ?" or
"अनुपात देखें: 3 : 9 :: 4 : ?", not just the bare sequence."""

# --- Reasoning is generated with a dedicated prompt (see bulk_questions.py module
# docstring / git history for the root-cause writeup): the generic ANGLES/PROMPT above
# is tuned for *fact-recall* subjects and, applied to "reasoning", kept producing (a)
# trivia/definition items ("What does the law of reflection state?") instead of actual
# puzzles, (b) puzzles whose own stated facts don't uniquely force the marked answer
# (under-constrained seating/direction puzzles, hand-waved explanations), and (c) heavily
# templated near-duplicates across the whole bank (literally the same frame with only the
# digits swapped -- "A, C, F, J, ?", "water image of the number N" x18, "if X*Y=Z and
# A*B=C, what is P*Q" x8). Two independent reviews (a Groq fact-check pass and a human
# review of the whole bank) flagged ~14% of reasoning questions as wrong/non-existent
# answers, far above every other subject -- this prompt plus blind_solve_reasoning()
# below are the fix: construct a genuine, fully-constrained puzzle instance per topic,
# self-verify it has exactly one derivable answer, vary entities so items don't collide
# into the same template, then independently re-solve it blind before accepting it.
REASONING_TOPIC_GUIDE = {
    "series": "A genuine number OR letter series with ONE consistent rule (arithmetic/geometric "
              "difference, alternating pattern, squares/cubes, two interleaved series, etc). Do not "
              "reuse the common textbook examples verbatim (ban: 'A, C, F, J', '2, 5, 10, 17', "
              "'1, 4, 9, 16') -- invent a fresh term set and a fresh rule each time.",
    "coding_decoding": "A letter-shift or word/number coding scheme (e.g. each letter shifted by a "
              "fixed or position-dependent offset, or a word-to-code mapping) applied consistently; "
              "the question gives one or two worked coded examples and asks to decode/encode a NEW word.",
    "classification": "Four items where exactly three share one specific, nameable property and the "
              "4th genuinely lacks it -- not 'three are X-shaped things, one is a different kind of "
              "thing', but a real odd-one-out by a stated rule (same category, pick which breaks it).",
    "blood_relations": "A short, fully-specified family chain (e.g. 'A is B's father. B is C's "
              "sister...') with ENOUGH relations stated to pin down exactly one answer to the "
              "question asked -- not an ambiguous or under-specified chain.",
    "direction_sense": "A person walks a SEQUENCE of legs with explicit directions and distances (or "
              "turns), e.g. 'walks 5km North, turns right, walks 3km...'. Track position/facing "
              "yourself using standard compass turns (right from North = East, etc) before finalizing "
              "the distance/direction asked for.",
    "syllogism": "Exactly 2 premises (standard A/E/I/O form: All/No/Some/Some-not) and 1-2 candidate "
              "conclusions. Apply standard syllogism rules (a conclusion follows only if it is validly "
              "entailed by the premises; use the 'either-or' answer only when the two conclusions are "
              "a genuine complementary I/E pair on the same terms) -- do not mark a conclusion correct "
              "just because it sounds plausible.",
    "alphabet_test": "A position-in-alphabet puzzle (counting from left/right/reverse, Nth letter "
              "after/before another, letter arithmetic). Actually count the positions "
              "(A=1...Z=26) yourself before fixing the answer; do not eyeball it.",
    "mirror_water_image": "An ACTUAL mirror-image or water-image transformation task: a short word, a "
              "clock time, or a simple shape description, asking what it becomes under a LEFT-RIGHT "
              "mirror flip (mirror image) or an UPSIDE-DOWN flip (water image) -- never a question "
              "*about* the definition of mirror/water image (ban phrasing like 'what does the law of "
              "reflection state' or 'which side is reversed in a mirror image' -- that is trivia, not "
              "a puzzle). For clock mirror images use 11:60 minus the time; for water images use 12:00 "
              "minus the time with the hour hand also flipped top-to-bottom; show the arithmetic.",
    "mathematical_operations": "A SYMBOL-SUBSTITUTION code (e.g. '+' means x, '-' means ÷, 'x' means -, "
              "'÷' means +, or similar) applied to a fresh expression -- not literal arithmetic dressed "
              "up as a pattern ('if 8*9=72 and 6*7=42, what is 5*6' is NOT a reasoning question, it's "
              "just multiplication; '*' must carry a genuine, previously-undisclosed substitution rule "
              "the solver has to infer or has just been told).",
    "puzzle_seating": "A linear or circular seating arrangement with ENOUGH constraints (relative "
              "positions, facing direction, who sits where) to pin down ONE unique, fully-determined "
              "arrangement -- work the full arrangement out yourself first, then ask about one person's "
              "position in it. Never leave the arrangement under-constrained (multiple valid "
              "arrangements satisfying the clues) and never put a plain cause-effect or statement "
              "question under this topic -- it must be an actual seating puzzle.",
    "statement_conclusion": "A short statement (fact, or a pair of premises) plus one or two "
              "conclusions; decide strictly by what is logically forced by the statement alone "
              "(not by outside real-world knowledge) whether each conclusion follows, doesn't follow, "
              "or is merely possible.",
    "non_verbal_reasoning": "A describable figural/spatial pattern task (counting shapes, completing a "
              "described figure series, folding/embedded-figure logic described in words) -- describe "
              "the figures precisely enough in words that the puzzle is solvable from the text alone; "
              "never ask a question *about* a reasoning term's definition.",
    "analogy": "A genuine word or letter analogy (A:B :: C:?) where the first pair's relationship "
              "(opposite, part-whole, function, category) is the SAME relationship that must be applied "
              "to produce the 4th term -- invent a fresh pair each time, don't reuse 'ABC:ZYX' or other "
              "stock textbook analogies verbatim.",
}

REASONING_PROMPT = """You are writing NEW logical-reasoning puzzle questions for an Indian Railways
(RRB/RPF) exam-prep app -- the "{topic_en}" ({topic_hi}) topic of the Reasoning subject.

What this topic actually means here: {topic_guide}

Write {n} DISTINCT puzzle questions, difficulty mix across 1 (easy), 2 (medium), 3 (hard), matching the
real difficulty and phrasing conventions of RRB NTPC / Group D / RPF reasoning sections (not a trivia
quiz about the topic's name, and not a school textbook example copied verbatim).

MANDATORY self-check before you output each item (do this silently, step by step, for every single
question -- this is the single most important instruction in this prompt):
1. Actually construct the puzzle's facts/constraints first.
2. Actually SOLVE it yourself from those facts alone, showing the derivation to yourself.
3. Confirm that exactly ONE of your 4 options is forced by the facts, and the other 3 are genuinely
   wrong under the same facts (not just "worse-sounding" -- an option that could also be true under
   some reading of the facts means the puzzle is broken; rewrite the facts until only one answer survives).
4. Only then write e_hi/e_en as the worked derivation you just did -- the explanation must show the
   actual steps (positions counted, directions tracked, premises applied), never a one-line assertion.
If step 3 ever fails, discard that attempt and build a different, better-constrained puzzle instead of
forcing an answer.

Anti-duplication (the existing bank already has heavy near-duplicate templates -- do NOT add more):
vary the people/letters/numbers/entities substantially across these {n} items AND avoid the specific
stock clichés named in the topic guidance above. Two items in this batch must not share the same
sentence frame with only digits/names swapped.

Output ONLY a JSON object, no markdown fences, no extra text:
{{"questions": [
  {{
    "q_hi": "question in natural Hindi (Devanagari)", "q_en": "same question in natural English (not literal translation)",
    "o_hi": ["4 options in Hindi"], "o_en": ["4 options in English, same order/meaning as o_hi"],
    "a": <0-3 correct index>,
    "e_hi": "worked step-by-step explanation in Hindi", "e_en": "worked step-by-step explanation in English",
    "d": <1, 2, or 3>
  }}, ... {n} items total
]}}

Exactly 4 options each, exactly one correct answer, options must not overlap in meaning.
CRITICAL for q_hi: it must contain actual Hindi (Devanagari) framing words, never bare numbers/letters
copied unchanged from q_en -- e.g. "श्रृंखला को देखें: 2, 5, 10, 17, ?", not just the bare sequence."""

SOLVE_PROMPT = """Solve this reasoning puzzle yourself from scratch, step by step. Do not assume any
answer is already correct -- derive it independently from only the facts given below.

Q: {q}
Options:
{opts}

If the facts given do not clearly and uniquely force exactly one option, set "confident" to false.
Output ONLY a JSON object, no markdown fences, no extra text:
{{"answer_index": <0-3>, "confident": true or false}}"""


OTHER_PROVIDER = {"groq": "gemini", "gemini": "groq"}
DEFAULT_VERIFY_MODEL = {"groq": "openai/gpt-oss-120b", "gemini": "gemini-2.5-flash"}


def blind_solve_reasoning(provider, model, q, **kw):
    """Independently re-derive a drafted reasoning question's answer from only its question
    + options (no explanation, no marked answer shown) -- the same blind-solve pattern
    ca_daily.py uses for current-affairs. Returns True only if the solver (ideally a
    DIFFERENT provider than the one that drafted the item, so one model's mistake can't
    just confirm itself) independently lands on the same option, confidently."""
    opts = "\n".join(f"{i}. {o}" for i, o in enumerate(q["o_en"]))
    prompt = SOLVE_PROMPT.format(q=q["q_en"], opts=opts)
    try:
        result = ask(provider, model, prompt, temperature=0.1, **kw)
        return bool(result.get("confident")) and result.get("answer_index") == q["a"]
    except Exception as e:
        print(f"  verify ERROR on {q.get('id', q['q_en'][:40])}: {e}", file=sys.stderr, flush=True)
        return False  # fail closed: an unverifiable item is dropped, not kept


def flush(path, new_items):
    """Merge new_items into path under an exclusive lock, re-reading the latest
    on-disk content first -- safe even when another process is writing the same
    file concurrently. Returns how many of new_items actually landed (after
    dedup against whatever the other process already saved)."""
    with open(path, "r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        f.seek(0)
        current = json.load(f)
        seen_ids = {q["id"] for q in current}
        seen_q = {norm(q["q_en"]) for q in current}
        to_add = [q for q in new_items if q["id"] not in seen_ids and norm(q["q_en"]) not in seen_q]
        current.extend(to_add)
        f.seek(0)
        f.truncate()
        json.dump(current, f, ensure_ascii=False, indent=1)
        fcntl.flock(f, fcntl.LOCK_UN)
    return len(to_add)


def valid(q, subject_id=None):
    try:
        if not (isinstance(q["q_hi"], str) and isinstance(q["q_en"], str) and q["q_hi"] and q["q_en"]):
            return False
        if subject_id != "english" and not DEVANAGARI.search(q["q_hi"]):
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


def subject_codes(tax):
    """Map each subject id to a short, GLOBALLY-unique id-prefix code. Plain s['id'][:3]
    isn't safe on its own -- e.g. je_mechanical/je_civil/je_electrical all truncate to
    'je_', and validate.py checks id uniqueness across ALL bank files, not per-file, so
    a naive truncation silently produces colliding ids across different subjects (this
    bit us once; see git history for the "fix je_* id collision" commit). Starts every
    code at 3 chars and extends any that collide until they're all distinct."""
    codes = {}
    for s in tax["subjects"]:
        n = 3
        code = s["id"][:n]
        while code in codes.values():
            n += 1
            code = s["id"][:n]
        codes[s["id"]] = code
    return codes


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--provider", required=True, choices=["groq", "gemini"])
    p.add_argument("--model", required=True)
    p.add_argument("--max-calls", type=int, default=200)
    p.add_argument("--subjects", help="comma-separated subject ids to restrict to (required when running "
                                       "alongside another instance -- see module docstring)")
    p.add_argument("--topics", help="comma-separated topic ids to further restrict to, e.g. to fill in "
                                     "specific zero-coverage topics within --subjects without also "
                                     "re-topping-up topics that already have content")
    p.add_argument("--id-prefix-suffix", default="", help="appended to the generated id's subject prefix, "
                                                            "e.g. 'g' for Gemini runs, to keep ids distinguishable")
    p.add_argument("--gemini-key-env", default="GEMINI_API_KEY", help="env var holding the Gemini API key to use "
                                                                       "(e.g. GEMINI_API_KEY2 for a second key, so "
                                                                       "two Gemini workers don't share one quota)")
    p.add_argument("--no-verify-reasoning", action="store_true",
                    help="skip the independent blind-solve check on reasoning items (default: on). "
                         "Only disable for a quick smoke test -- this check is the fix for the ~14%% "
                         "wrong-answer rate the two review passes found in the reasoning bank.")
    p.add_argument("--verify-provider", choices=["groq", "gemini"],
                    help="provider used to independently re-solve each drafted reasoning item "
                         "(default: the OTHER provider from --provider, so a single model's mistake "
                         "can't just confirm itself)")
    p.add_argument("--verify-model", help="model for --verify-provider (default: a sane per-provider default)")
    args = p.parse_args()
    verify_provider = args.verify_provider or OTHER_PROVIDER[args.provider]
    verify_model = args.verify_model or DEFAULT_VERIFY_MODEL[verify_provider]
    verify_kw = {"api_key_env": args.gemini_key_env} if verify_provider == "gemini" else {}

    tax = json.load(open(f"{ROOT}/content/taxonomy.json", encoding="utf-8"))
    codes = subject_codes(tax)
    only = set(args.subjects.split(",")) if args.subjects else None
    only_topics = set(args.topics.split(",")) if args.topics else None
    calls = 0
    added_total = 0

    subjects = [s for s in tax["subjects"] if only is None or s["id"] in only]
    random.shuffle(subjects)

    for s in subjects:
        if calls >= args.max_calls:
            break
        target = TARGETS.get(s["id"], DEFAULT_TARGET)
        path = f"{ROOT}/content/bank/{s['id']}.json"
        if not os.path.exists(path):
            json.dump([], open(path, "w", encoding="utf-8"))
        items = json.load(open(path, encoding="utf-8"))
        seen_norm = {norm(q["q_en"]) for q in items}
        by_topic = {}
        for q in items:
            by_topic.setdefault(q["t"], []).append(q)
        existing_ids = [int(m.group(1)) for q in items if (m := re.search(r"(\d+)$", q["id"]))]
        next_num = (max(existing_ids) + 1) if existing_ids else 1

        topics = [t for t in s["topics"] if only_topics is None or t["id"] in only_topics]
        random.shuffle(topics)
        for t in topics:
            if calls >= args.max_calls:
                break
            count = len(by_topic.get(t["id"], []))
            rounds_here = 0
            while count < target and calls < args.max_calls and rounds_here < 40:
                if s["id"] == "reasoning":
                    guide = REASONING_TOPIC_GUIDE.get(
                        t["id"], "A genuine logical-reasoning puzzle for this topic, not a trivia "
                                  "question about the topic's definition.")
                    prompt = REASONING_PROMPT.format(topic_en=t["en"], topic_hi=t["hi"],
                                                      topic_guide=guide, n=BATCH)
                else:
                    angle = random.choice(ANGLES)
                    prompt = PROMPT.format(subject_en=s["en"], subject_hi=s["hi"], topic_en=t["en"],
                                            topic_hi=t["hi"], angle=angle, n=BATCH)
                try:
                    kw = {"api_key_env": args.gemini_key_env} if args.provider == "gemini" else {}
                    result = ask(args.provider, args.model, prompt, **kw)
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
                    if not valid(q, s["id"]):
                        continue
                    key = norm(q["q_en"])
                    if key in seen_norm:
                        continue
                    seen_norm.add(key)
                    q2 = {"id": f"rp-{codes[s['id']]}-{args.id_prefix_suffix}{next_num:05d}", "s": s["id"], "t": t["id"],
                          "d": q["d"] if q.get("d") in (1, 2, 3) else 2,
                          "q_hi": q["q_hi"], "q_en": q["q_en"], "o_hi": q["o_hi"], "o_en": q["o_en"],
                          "a": q["a"], "e_hi": q["e_hi"], "e_en": q["e_en"]}
                    next_num += 1
                    new_items.append(q2)
                if new_items and s["id"] == "reasoning" and not args.no_verify_reasoning:
                    verified = []
                    for q2 in new_items:
                        if blind_solve_reasoning(verify_provider, verify_model, q2, **verify_kw):
                            verified.append(q2)
                        else:
                            print(f"  dropped (blind-solve mismatch): {q2['q_en'][:80]}", flush=True)
                        time.sleep(1.5 if verify_provider == "groq" else 2.0)
                    new_items = verified
                if new_items:
                    landed = flush(path, new_items)
                    by_topic.setdefault(t["id"], []).extend(new_items)
                    count = len(by_topic[t["id"]])
                    added_total += landed
                    print(f"{s['id']}/{t['id']}: +{landed} (topic now {count}/{target}, "
                          f"call {calls}/{args.max_calls}, total added {added_total})", flush=True)
                time.sleep(1.5 if args.provider == "groq" else 2.0)

    print(f"DONE. calls={calls} added_total={added_total}")


if __name__ == "__main__":
    main()
