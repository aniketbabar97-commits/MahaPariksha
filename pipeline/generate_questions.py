"""Generate MCQs at scale: open-source model drafts, Claude verifies.

This is the cost-optimized version of the content pipeline: bulk drafting (the
highest token-volume step) runs on a cheap/free open-source model (see
draft_llm.py, default Groq), while both verification passes -- the ones that
actually catch wrong answer keys and ambiguous questions -- stay on Claude.

Usage:
  python3 pipeline/generate_questions.py --subject marathi --topic sandhi --count 20
  python3 pipeline/generate_questions.py --subject marathi --topic sandhi --count 20 --difficulty 2

Env:
  ANTHROPIC_API_KEY   required (verification always runs on Claude)
  DRAFT_PROVIDER / DRAFT_MODEL / <PROVIDER>_API_KEY   see draft_llm.py
    If no open-source provider is configured, drafting falls back to Claude
    (same model as verification) so the script still works end to end.

Only items that pass BOTH verification passes are appended to
content/bank/<subject>.json. Everything else is dropped with a reason printed
to stderr -- nothing "flagged" ships silently.
"""
import argparse
import json
import os
import sys
from pathlib import Path
from typing import List

import anthropic
from pydantic import BaseModel, Field

import draft_llm

ROOT = Path(__file__).resolve().parent.parent
CONTENT = ROOT / "content"
VERIFY_MODEL = os.environ.get("BHARARI_MODEL", "claude-sonnet-5")


class Draft(BaseModel):
    q_mr: str
    q_en: str
    o_mr: List[str]
    o_en: List[str]
    a: int = Field(description="0-based index of the correct option")
    e_mr: str
    e_en: str


class BlindSolve(BaseModel):
    answer_index: int
    confident: bool


class Critique(BaseModel):
    ok: bool
    reason: str = ""


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
- Distractors must be plausible, not absurd.
- o_mr and o_en must list the SAME 4 options in the SAME order, one in Marathi one in English.
- Natural, grammatically correct Marathi (not a literal translation from English).
- Do not repeat these already-used question stems: {avoid}

Output ONLY the JSON array, nothing else."""

BLIND_SOLVE_PROMPT = """Answer this MCQ using only general knowledge, as a careful exam aspirant would.
If more than one option could reasonably be correct, or the question is ambiguous, set confident=false.

Q: {q}
0. {o0}
1. {o1}
2. {o2}
3. {o3}"""

CRITIQUE_PROMPT = """You are fact-checking one MCQ before it ships to real exam aspirants. Check:
1. Is the claimed correct answer actually correct?
2. Is the Marathi natural and grammatically correct (not a stiff literal translation)?
3. Is the explanation accurate and not misleading?
4. Are all 4 options genuinely distinct (no near-duplicates)?

If everything checks out, ok=true. Otherwise ok=false with a one-line reason.

Q (mr): {q_mr}
Q (en): {q_en}
Options (en): {opts}
Claimed answer: {answer}
Explanation (en): {e_en}"""


def load_bank(subject: str) -> list:
    path = CONTENT / "bank" / f"{subject}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else []


def draft_batch(client, subject_en, subject_mr, topic_en, topic_mr, n, difficulty_label, avoid_stems) -> List[Draft]:
    prompt = DRAFT_PROMPT.format(
        subject_en=subject_en, subject_mr=subject_mr, topic_en=topic_en, topic_mr=topic_mr,
        n=n, difficulty_label=difficulty_label, avoid="; ".join(avoid_stems[:30]) or "(none yet)",
    )
    provider = draft_llm.active_provider()
    if provider:
        print(f"drafting {n} via open-source provider '{provider}'...", file=sys.stderr)
        raw = draft_llm.draft_json(prompt)
        return [Draft(**item) for item in raw]
    print("no open-source draft provider configured; drafting with Claude instead", file=sys.stderr)
    r = client.messages.parse(
        model=VERIFY_MODEL, max_tokens=8000,
        messages=[{"role": "user", "content": prompt}],
        output_format=type("Drafts", (BaseModel,), {"__annotations__": {"items": List[Draft]}}),
    )
    return r.parsed_output.items


def verify(client, d: Draft) -> tuple[bool, str]:
    solve = client.messages.parse(
        model=VERIFY_MODEL, max_tokens=1000,
        messages=[{"role": "user", "content": BLIND_SOLVE_PROMPT.format(
            q=d.q_en, o0=d.o_en[0], o1=d.o_en[1], o2=d.o_en[2], o3=d.o_en[3])}],
        output_format=BlindSolve,
    ).parsed_output
    if not solve.confident or solve.answer_index != d.a:
        return False, f"blind solve mismatch (claimed {d.a}, solved {solve.answer_index}, confident={solve.confident})"
    critique = client.messages.parse(
        model=VERIFY_MODEL, max_tokens=1000,
        messages=[{"role": "user", "content": CRITIQUE_PROMPT.format(
            q_mr=d.q_mr, q_en=d.q_en, opts=d.o_en, answer=d.o_en[d.a], e_en=d.e_en)}],
        output_format=Critique,
    ).parsed_output
    if not critique.ok:
        return False, f"critique failed: {critique.reason}"
    return True, ""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--subject", required=True)
    ap.add_argument("--topic", required=True)
    ap.add_argument("--count", type=int, default=20)
    ap.add_argument("--difficulty", type=int, choices=[1, 2, 3], default=1)
    ap.add_argument("--batch-size", type=int, default=15)
    args = ap.parse_args()

    taxonomy = json.loads((CONTENT / "taxonomy.json").read_text(encoding="utf-8"))
    subj = next((s for s in taxonomy["subjects"] if s["id"] == args.subject), None)
    if not subj:
        sys.exit(f"unknown subject: {args.subject}")
    topic = next((t for t in subj["topics"] if t["id"] == args.topic), None)
    if not topic:
        sys.exit(f"unknown topic: {args.topic} in subject {args.subject}")
    difficulty_label = {1: "easy", 2: "medium", 3: "hard"}[args.difficulty]

    bank = load_bank(args.subject)
    existing_stems = [q["q_en"] for q in bank if q["s"] == args.subject and q["t"] == args.topic]
    seen = {q["q_en"].strip().lower() for q in bank}
    next_n = max([int(q["id"].split("-")[-1]) for q in bank if q["s"] == args.subject] or [0]) + 1

    client = anthropic.Anthropic()
    kept = []
    attempts = 0
    while len(kept) < args.count and attempts < args.count * 3:
        n = min(args.batch_size, args.count - len(kept))
        try:
            drafts = draft_batch(client, subj["en"], subj["mr"], topic["en"], topic["mr"], n,
                                  difficulty_label, existing_stems + [k.q_en for k in kept])
        except Exception as e:
            print(f"draft batch failed: {e}", file=sys.stderr)
            attempts += n
            continue
        for d in drafts:
            attempts += 1
            if d.q_en.strip().lower() in seen:
                print(f"skip (duplicate stem): {d.q_en[:70]}", file=sys.stderr)
                continue
            if not (len(d.o_mr) == 4 and len(d.o_en) == 4 and 0 <= d.a <= 3):
                print(f"skip (bad shape): {d.q_en[:70]}", file=sys.stderr)
                continue
            ok, reason = verify(client, d)
            if not ok:
                print(f"rejected ({reason}): {d.q_en[:70]}", file=sys.stderr)
                continue
            seen.add(d.q_en.strip().lower())
            kept.append(d)
            bank.append({
                "id": f"{args.subject}-{next_n:03d}", "s": args.subject, "t": args.topic, "d": args.difficulty,
                "q_mr": d.q_mr, "q_en": d.q_en, "o_mr": d.o_mr, "o_en": d.o_en, "a": d.a,
                "e_mr": d.e_mr, "e_en": d.e_en,
            })
            next_n += 1
            if len(kept) >= args.count:
                break

    path = CONTENT / "bank" / f"{args.subject}.json"
    path.write_text(json.dumps(bank, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"kept {len(kept)}/{args.count} requested (from {attempts} drafted+checked) -> {path}")
    return 0 if kept else 1


if __name__ == "__main__":
    sys.exit(main())
