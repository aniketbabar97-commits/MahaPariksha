#!/bin/bash
# RailPariksha session-start hook (pure bash, no LLM call -- fires on every
# SessionStart event, including "resume" after a mid-conversation restart).
#
# Bulk QUESTION generation is DONE: every subject hit its per-topic target
# (311/topic generally, 15/topic for current_affairs), 25,078 questions
# total against the 25,000 goal. That worker-relaunch logic has been
# retired -- there is nothing left to regenerate there.
#
# FLASHCARD generation is DONE: every subject hit its 20/topic target
# (1,766 cards across 10 subjects -- current_affairs excluded, see
# bulk_flashcards.py's commit message for why). That worker-relaunch logic
# has been retired too.
#
# NOTES generation is DONE: all 88 (subject, topic) pairs now have a note.
# That worker-relaunch logic has been retired too.
#
# TIPS & TRICKS backfill is DONE. That worker-relaunch logic has been
# retired too.
#
# The original FACT-CHECK pass (factcheck.py, writing to pipeline/reports/
# _fc_groq*.json, relaunched by this hook up to 2026-10-03) is RETIRED --
# it had no resume/checkpoint, so a restart re-ran it from question 1 every
# time, and it was superseded same-day by a resumable rewrite. Relaunching
# the old script was silently wasting API calls while producing nothing new;
# that logic is gone now.
#
# The CURRENT fact-check pass is verify_questions.py (checkpointed per
# subject in pipeline/content_gen/verify_state/<subject>.json -- a restart
# resumes from the last checked id instead of starting over) plus
# verify_static_facts.py for content/gk_booster.json and the cheat sheets
# (small enough that it has no checkpoint; a restart just reruns it, which
# is cheap). Flags are appended to pipeline/logs/verify_flags/*.jsonl and
# NEVER auto-applied -- a human (or Claude, instructed to verify personally,
# never trusting the flag text alone) reviews each one before editing
# content/bank/*.json. Split across 3 workers so it finishes faster than one
# sequential pass; each one is restricted via --subjects to whichever
# subjects are not yet ~done, re-checked at the top of every restart so this
# list stays current instead of drifting stale like the old one did:
#   - maths, computer, current_affairs, current_affairs_auto, science are
#     essentially 100% checked already -- left out of every worker below on
#     purpose, re-running them would just burn quota for no new flags.
#   - gk is ~96% checked, reasoning ~72% -- included below to finish them.
#   - english, railway_gk, je_civil, je_electrical, je_mechanical were each
#     only ~3-5% checked as of 2026-10-03 -- the real bulk of what's left.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO=/home/user/MahaPariksha/railpariksha
LOGS="$REPO/pipeline/logs"
GEN="$REPO/pipeline/content_gen"
mkdir -p "$LOGS"

[ -d "$REPO" ] || exit 0
cd "$GEN" || exit 0

running() { pgrep -f "$1" >/dev/null 2>&1; }

if ! running "verify_questions.py.*--subjects reasoning"; then
  nohup python3 verify_questions.py --provider groq --model openai/gpt-oss-safeguard-20b \
    --subjects reasoning \
    > "$LOGS/verify_reasoning.log" 2>&1 &
  disown
fi

if ! running "verify_questions.py.*je_civil,je_electrical,je_mechanical"; then
  nohup python3 verify_questions.py --provider gemini --model gemini-flash-lite-latest --gemini-key-env GEMINI_API_KEY \
    --subjects je_civil,je_electrical,je_mechanical \
    > "$LOGS/verify_je.log" 2>&1 &
  disown
fi

if ! running "verify_questions.py.*english,railway_gk,gk"; then
  nohup python3 verify_questions.py --provider gemini --model gemini-flash-lite-latest --gemini-key-env GEMINI_API_KEY2 \
    --subjects english,railway_gk,gk \
    > "$LOGS/verify_eng_rgk_gk.log" 2>&1 &
  disown
fi

if ! running "verify_static_facts.py"; then
  nohup python3 verify_static_facts.py --provider gemini --model gemini-flash-lite-latest --gemini-key-env GEMINI_API_KEY \
    > "$LOGS/verify_static_facts.log" 2>&1 &
  disown
fi

# Commit any content the workers wrote before the restart, so a second restart
# right after this one doesn't lose it. Never touches GitHub (no push).
cd "$REPO" || exit 0
if [ -n "$(git status --porcelain -- content/bank content/notes content/flashcards pipeline/content_gen/verify_state 2>/dev/null)" ]; then
  git add content/bank content/notes content/flashcards pipeline/content_gen/verify_state 2>/dev/null
  git commit -q -m "Auto checkpoint (session-start hook): content-growth after restart" 2>/dev/null || true
fi

exit 0
