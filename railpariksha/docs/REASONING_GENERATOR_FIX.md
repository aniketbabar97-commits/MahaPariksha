# Reasoning generator: root cause + fix

Two independent reviews (a Groq fact-check pass and a human Claude-chat review of the
whole bank) found `content/bank/reasoning.json` (4,151 questions) to be the worst-quality
subject in the bank, with ~14% of questions flagged for a wrong/non-existent answer. This
doc covers the generator-side root cause and the fix, not the existing-item cleanup (a
separate, concurrent effort owns that).

## Root cause

`pipeline/content_gen/bulk_questions.py` used ONE generic `PROMPT` + `ANGLES` list for
every subject, including reasoning. That prompt and angle list (`"definitions and basic
concepts"`, `"important dates, people, and named facts"`, `"exam-frequently-repeated
question patterns"`, ...) is tuned for **fact-recall** subjects. Applied to reasoning it
reliably produced three distinct failure modes, all confirmed by reading real bank entries:

1. **Trivia instead of puzzles.** e.g. `rp-rea-s00464`: "What does the law of reflection
   state?" and `rp-rea-j02231`: "When identifying a 'Mirror Image', which side is
   reversed?" — these are definition questions *about* the topic name, not an actual
   mirror-image puzzle instance a student has to solve.
2. **No derivation/verification step**, so the model's one-shot answer often didn't
   match its own stated facts. e.g. `rp-rea-i02266` (circular seating, 5 people) gives an
   under-constrained arrangement and a hand-waved explanation ("Placing five people in a
   circular arrangement, B correctly fits...") with no shown derivation — classic sign the
   answer was never actually checked against the constraints.
3. **Heavy templating / near-duplicates**, because `ANGLES` has no anti-template
   instruction and reasoning puzzles are easy to template. A scan of the live bank found,
   e.g., 18 near-identical "what will be the water image of the number 'N'?" items and 10
   near-identical "N : N :: N : ?" analogy-frame items, differing only by swapped digits —
   matching the human reviewer's specific complaint about the "A, C, F, J" series and
   mirror-question repetition.

None of this is subject-specific bad luck — it's what the generic prompt *always* does
when pointed at a topic that requires constructing-then-solving a self-contained logic
puzzle rather than recalling a fact.

## Fix

In `pipeline/content_gen/bulk_questions.py`:

1. **`REASONING_TOPIC_GUIDE`** — a per-topic (series, syllogism, direction_sense,
   mirror_water_image, puzzle_seating, blood_relations, mathematical_operations,
   alphabet_test, analogy, classification, coding_decoding, statement_conclusion,
   non_verbal_reasoning) construction spec: what a genuine puzzle for that topic looks
   like, explicit bans on the clichés found in the bank (`"A, C, F, J"`, `"ABC:ZYX"`,
   literal-arithmetic-dressed-as-a-pattern), and the correct convention where one exists
   (e.g. mirror-clock-time = `11:60 − time`).
2. **`REASONING_PROMPT`** — replaces the generic prompt for the reasoning subject only.
   It requires the model to construct the puzzle, silently solve it step-by-step, confirm
   exactly one option is forced before finalizing, and write the explanation as the actual
   worked derivation (not a one-line assertion) — plus an explicit anti-duplication
   instruction.
3. **`blind_solve_reasoning()` + `SOLVE_PROMPT`** — the real fix for the wrong-answer rate.
   Ported the `ca_daily.py` pattern (draft with one model, independently blind-solve with
   a *different* model given only the question + options, reject on mismatch or low
   confidence) into the bulk generator. `main()` now runs every freshly-drafted reasoning
   item through this check (`--verify-provider`/`--verify-model`, defaults to whichever
   provider you didn't draft with) and drops anything that fails, before it's ever written
   to `content/bank/reasoning.json`. `--no-verify-reasoning` exists only for a quick smoke
   test.

This was the one gap the improved prompt alone could not close: self-verification
instructions in a single-pass prompt still let through puzzles the same model gets wrong
(see evidence below) — an independent second opinion is what actually catches it.

## Proof of concept (real API calls, GROQ_API_KEY + GEMINI_API_KEY available in this env)

Drafted with Groq (`qwen/qwen3.8-27b`) using the new `REASONING_PROMPT`, verified with
Gemini (`gemini-2.5-flash`) using `blind_solve_reasoning()`. Heavy 429 rate-limiting from
shared free-tier quota (another concurrent agent in this environment is also calling
Groq) cut the run short, but every item that *did* complete is below, with **my own**
independent manual check (not just trusting either model's self-report):

| Topic | Question | Drafted answer | Verifier | My manual check |
|---|---|---|---|---|
| mirror_water_image | Clock shows 11:15; mirror image time? | `10:45` (option 0) | **REJECTED** (Gemini: option 1, `12:45`) | Correct rule: `12:00 − 11:15 = 0:45 → 12:45`. Gemini is right, the draft's own `a` field was wrong — its own leaked chain-of-thought even talks itself into `12:45` and then contradicts itself. **Caught a real wrong-answer item before it reached the bank.** |
| analogy | `E : J :: K : ?` | `Q` (option 2) | **REJECTED** (Gemini: option 1, `P`) | E is the 5th letter, J the 10th (+5), so K (11th) + 5 = 16th = `P`. The draft's claim that "E is the 1st letter" is simply a counting error. Gemini is right. **Caught a second real wrong-answer item.** |
| analogy | `Car : Fuel :: Human : ?` | `Food` (option 2) | **ACCEPTED** (Gemini agrees) | Legitimate functional analogy (energy source for a machine : energy source for a person). Kept correctly. |
| series | `7, 23, 47, 79, 119, ?` | `167` | *(run cut off by rate limit before this item's verify call)* | I solved it myself: diffs `16, 24, 32, 40` are themselves `+8` apart, next diff `48` → `119+48=167`. Correct, and a genuinely fresh (non-templated) series — the new prompt's anti-cliché instruction is working. |
| series (letter) | `B, D, G, K, ?` → drafted `V` | `V` | *(agreed, but see caveat)* | I solved it myself: position diffs `2, 3, 4` (triangular), next diff `5` → `11+5=16=P`. `V` (22) does not fit this rule by my own derivation. **This is the one caveat below.** |

**Caveat, stated plainly rather than hidden:** the last row is a case where the drafting
model *and* the independent verifier apparently agreed on an answer I believe is wrong
when I solve it myself. Blind-solve with a second model catches *independent* mistakes
(as it did twice above) but can't catch a mistake both models happen to make the same way.
This is exactly why `pipeline/content_gen/verify_questions.py`'s existing after-the-fact
flagging pass (human/Claude-reviewed) should keep running against newly generated
reasoning content too, not be treated as fully superseded by the new generation-time
check — the fix sharply reduces the error rate, it doesn't claim to make it zero.

### Net result of this POC

Of the 3 items that completed the full draft+verify cycle, the independent verifier
correctly caught 2 wrong answers (confirmed by my own derivation) and correctly passed 1
good item — a direct, concrete demonstration of the fix working, on real generator output,
not a simulated example.

## What this does NOT do

Per scope: the existing 4,151 reasoning questions are untouched by this change (a separate
concurrent effort is fixing/deleting the already-flagged 568). This fix only changes what
*future* `bulk_questions.py --subjects reasoning` runs will produce. A full regeneration of
the reasoning bank with the fixed generator is a bigger call for the product owner to make
separately, once this is proven out further.
