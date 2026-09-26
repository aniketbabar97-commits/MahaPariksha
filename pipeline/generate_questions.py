"""Generate MCQs at scale for free: one open-source model drafts, a second,
independent open-source model blind-solves each item to cross-check it.
No Claude/paid tokens touched by default.

Usage:
  python3 pipeline/generate_questions.py --subject marathi --topic sandhi --count 20
  python3 pipeline/generate_questions.py --subject marathi --topic sandhi --count 200 --difficulty 2

How correctness is protected without paying for verification:
  1. Local shape checks (same rules as pipeline/validate.py): 4 distinct non-empty
     options per language, valid answer index, Devanagari present, etc.
  2. Independent cross-check: a SECOND model (different provider/family from the
     drafter, so its mistakes don't correlate with the drafter's) is shown only
     the question and options -- never the claimed answer -- and solves it fresh.
     Only items where the two models agree ship to content/bank/<subject>.json.
  3. Everything else (shape failures, disagreements) is written to
     content/pending_review/<subject>.json instead of being shipped OR silently
     discarded -- it's real drafted content, just not confirmed yet. Run it
     through Claude (pipeline/audit_pending.py, once ANTHROPIC_API_KEY is set)
     when you're ready to spend token budget on the harder cases.

Two agreeing open-source models is a real signal but not proof: they can share
a blind spot from similar training data (see docs/review_log.md for a live
example -- both Groq's draft and a naive check got a sandhi answer wrong the
same way). That's exactly what pending_review + a later Claude audit sample is
for -- this script deliberately does not claim 100% accuracy on its own.

Env:
  DRAFT_PROVIDER (default groq), CHECK_PROVIDER (default gemini) -- see draft_llm.py.
  Both need their own API key (GROQ_API_KEY / GEMINI_API_KEY) set as environment
  secrets, not passed on the command line.
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

import draft_llm

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
DEVANAGARI = re.compile(r"[ऀ-ॿ]")

DRAFT_PROVIDER = os.environ.get("DRAFT_PROVIDER", "groq")
CHECK_PROVIDER = os.environ.get("CHECK_PROVIDER", "gemini")

DRAFT_PROMPT = """You write multiple-choice questions for Marathi-medium aspirants preparing for
Maharashtra government exams (Police Bharti, Talathi, MPSC) and SSC/Railway.

Subject: {subject_en} ({subject_mr})
Topic: {topic_en} ({topic_mr})
Difficulty: {difficulty_label}

Write exactly {n} DISTINCT multiple-choice questions as a raw JSON array. Each item:
{{"q_mr": "...", "q_en": "...", "o_mr": ["...","...","...","..."], "o_en": ["...","...","...","..."],
  "a": 0-3, "e_mr": "2-3 sentence Marathi explanation", "e_en": "2-3 sentence English explanation"}}

Rules:
- Facts must be correct. Do not invent facts, dates, names, sections, or figures.
- Exactly one clearly correct option; vary which index (0-3) is correct across the {n} items.
- All 4 options in o_mr must be genuinely distinct strings from each other (same for o_en).
- Distractors must be plausible, not absurd.
- o_mr and o_en must list the SAME 4 options in the SAME order, one in Marathi one in English.
- Natural, grammatically correct Marathi (not a literal translation from English).
- Do not repeat these already-used question stems: {avoid}

Output ONLY the JSON array, nothing else."""

CHECK_PROMPT = """Answer this multiple-choice question yourself, as a careful exam aspirant would.
Do not assume any of the options is correct just because it's listed first -- work it out.
If more than one option could reasonably be correct, or you are not sure, set confident=false.

Output ONLY this JSON object, nothing else: {{"answer_index": 0-3, "confident": true|false}}

Q: {q}
0. {o0}
1. {o1}
2. {o2}
3. {o3}"""


def load_json(path: Path) -> list:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else []


def shape_errors(d: dict) -> list:
    errs = []
    for lang in ("mr", "en"):
        key = f"o_{lang}"
        opts = d.get(key)
        if not (isinstance(opts, list) and len(opts) == 4 and all(isinstance(o, str) and o.strip() for o in opts)):
            errs.append(f"{key} must be 4 non-empty strings")
        elif len({o.strip() for o in opts}) != 4:
            errs.append(f"{key} has duplicate options")
        for f in ("q", "e"):
            if not (isinstance(d.get(f"{f}_{lang}"), str) and d[f"{f}_{lang}"].strip()):
                errs.append(f"{f}_{lang} empty")
    if not isinstance(d.get("a"), int) or not 0 <= d["a"] <= 3:
        errs.append("a must be an int 0..3")
    if d.get("q_mr") and not DEVANAGARI.search(d["q_mr"]):
        errs.append("q_mr has no Devanagari")
    return errs


def draft_batch(subject_en, subject_mr, topic_en, topic_mr, n, difficulty_label, avoid_stems) -> list:
    prompt = DRAFT_PROMPT.format(
        subject_en=subject_en, subject_mr=subject_mr, topic_en=topic_en, topic_mr=topic_mr,
        n=n, difficulty_label=difficulty_label, avoid="; ".join(avoid_stems[:30]) or "(none yet)",
    )
    return draft_llm.call_json(DRAFT_PROVIDER, prompt, model_env="DRAFT_MODEL")


def cross_check(d: dict) -> tuple[bool, str]:
    prompt = CHECK_PROMPT.format(q=d["q_en"], o0=d["o_en"][0], o1=d["o_en"][1], o2=d["o_en"][2], o3=d["o_en"][3])
    try:
        result = draft_llm.call_json(CHECK_PROVIDER, prompt, model_env="CHECK_MODEL", max_tokens=200)
    except Exception as e:
        return False, f"cross-check call failed: {e}"
    if not isinstance(result, dict) or "answer_index" not in result:
        return False, "cross-check returned unexpected shape"
    if not result.get("confident", False):
        return False, "cross-check not confident"
    if result["answer_index"] != d["a"]:
        return False, f"cross-check disagreed (drafted a={d['a']}, checked={result['answer_index']})"
    return True, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject", required=True)
    ap.add_argument("--topic", required=True)
    ap.add_argument("--count", type=int, default=20)
    ap.add_argument("--difficulty", type=int, choices=[1, 2, 3], default=1)
    ap.add_argument("--batch-size", type=int, default=15)
    args = ap.parse_args()

    if not draft_llm.is_configured(DRAFT_PROVIDER):
        sys.exit(f"draft provider '{DRAFT_PROVIDER}' not configured -- set its API key as an environment secret")
    if not draft_llm.is_configured(CHECK_PROVIDER):
        sys.exit(f"check provider '{CHECK_PROVIDER}' not configured -- set its API key as an environment secret")

    taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    subj = next((s for s in taxonomy["subjects"] if s["id"] == args.subject), None)
    if not subj:
        sys.exit(f"unknown subject: {args.subject}")
    topic = next((t for t in subj["topics"] if t["id"] == args.topic), None)
    if not topic:
        sys.exit(f"unknown topic: {args.topic} in subject {args.subject}")
    difficulty_label = {1: "easy", 2: "medium", 3: "hard"}[args.difficulty]

    bank_path = CONTENT / "bank" / f"{args.subject}.json"
    bank = load_json(bank_path)
    pending_path = CONTENT / "pending_review" / f"{args.subject}.json"
    pending = load_json(pending_path)

    existing_stems = [q["q_en"] for q in bank if q["s"] == args.subject and q["t"] == args.topic]
    seen = {q["q_en"].strip().lower() for q in bank} | {p["draft"]["q_en"].strip().lower() for p in pending}
    next_n = max([int(q["id"].split("-")[-1]) for q in bank if q["s"] == args.subject] or [0]) + 1

    kept, parked, attempts = 0, 0, 0
    while kept < args.count and attempts < args.count * 3:
        n = min(args.batch_size, args.count - kept)
        try:
            drafts = draft_batch(subj["en"], subj["mr"], topic["en"], topic["mr"], n,
                                  difficulty_label, existing_stems + [q["q_en"] for q in bank[-30:]])
        except Exception as e:
            print(f"draft batch failed: {e}", file=sys.stderr)
            attempts += n
            continue
        for d in drafts:
            attempts += 1
            if not isinstance(d, dict) or d.get("q_en", "").strip().lower() in seen:
                continue
            errs = shape_errors(d)
            if errs:
                pending.append({"reason": "shape: " + "; ".join(errs), "draft": d})
                seen.add(d.get("q_en", "").strip().lower())
                parked += 1
                continue
            ok, reason = cross_check(d)
            seen.add(d["q_en"].strip().lower())
            if not ok:
                print(f"parked ({reason}): {d['q_en'][:70]}", file=sys.stderr)
                pending.append({"reason": reason, "draft": d})
                parked += 1
                continue
            bank.append({
                "id": f"{args.subject}-{next_n:03d}", "s": args.subject, "t": args.topic, "d": args.difficulty,
                "q_mr": d["q_mr"], "q_en": d["q_en"], "o_mr": d["o_mr"], "o_en": d["o_en"], "a": d["a"],
                "e_mr": d["e_mr"], "e_en": d["e_en"],
            })
            next_n += 1
            kept += 1
            if kept >= args.count:
                break

    bank_path.write_text(json.dumps(bank, ensure_ascii=False, indent=1), encoding="utf-8")
    pending_path.parent.mkdir(parents=True, exist_ok=True)
    pending_path.write_text(json.dumps(pending, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"kept {kept}/{args.count} (both models agreed) -> {bank_path}")
    print(f"parked {parked} (shape issue or disagreement, needs a later audit) -> {pending_path}")
    return 0 if kept else 1


if __name__ == "__main__":
    sys.exit(main())
