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
# FACT-CHECK pass is now in progress: factcheck.py blind-solves all 25,078
# stored questions with an independent model and writes disagreements for
# human review (it never edits the bank files itself, so running several
# instances against disjoint files concurrently is safe). Split 3-way across
# 3 different Groq models (each meters its own daily quota separately) so it
# finishes in hours, not a single ~8h sequential pass:
#   qwen/qwen3.8-27b  -> maths, gk, current_affairs (_fc_groq.json)
#   gpt-oss-120b      -> reasoning, railway_gk, science (_fc_groq2.json)
#   gpt-oss-20b       -> je_civil, je_mechanical, je_electrical, english,
#                        computer (_fc_groq3.json)
# Both Gemini keys were tried first but BOTH turned out to be capped at a
# hard 20 requests/day across every model tested (2.5-flash and 3.8-flash
# alike) -- confirmed via actual 429 RESOURCE_EXHAUSTED responses on both
# keys -- nowhere near enough for ~8,000 calls each, so abandoned entirely
# in favor of Groq's much larger per-model daily token quotas.
# Output goes to pipeline/reports/, NEVER content/bank/ -- build_bundle.py
# globs every file in content/bank/ into the app's content bundle, so a
# disagreements report dropped in there would corrupt the shipped bundle.
# factcheck.py has no resume/checkpoint -- a restart re-runs each worker's
# files from question 1, so this relaunch costs some repeated API calls, but
# is still correct (it only ever reports disagreements, never mutates state).
# None of these self-relaunch on restart, so this hook does it -- per the
# standing rule: every background worker gets a relaunch entry here so it
# survives a container restart.
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

BANK="$REPO/content/bank"
REPORTS="$REPO/pipeline/reports"
mkdir -p "$REPORTS"

if ! running "factcheck.py.*_fc_groq.json"; then
  nohup python3 factcheck.py --provider groq --model qwen/qwen3.8-27b \
    --out "$REPORTS/_fc_groq.json" \
    "$BANK/maths.json" "$BANK/gk.json" "$BANK/current_affairs.json" \
    > "$LOGS/factcheck_groq.log" 2>&1 &
  disown
fi

if ! running "factcheck.py.*_fc_groq2.json"; then
  nohup python3 factcheck.py --provider groq --model openai/gpt-oss-120b \
    --out "$REPORTS/_fc_groq2.json" \
    "$BANK/reasoning.json" "$BANK/railway_gk.json" "$BANK/science.json" \
    > "$LOGS/factcheck_groq2.log" 2>&1 &
  disown
fi

if ! running "factcheck.py.*_fc_groq3.json"; then
  nohup python3 factcheck.py --provider groq --model openai/gpt-oss-20b \
    --out "$REPORTS/_fc_groq3.json" \
    "$BANK/je_civil.json" "$BANK/je_mechanical.json" "$BANK/je_electrical.json" \
    "$BANK/english.json" "$BANK/computer.json" \
    > "$LOGS/factcheck_groq3.log" 2>&1 &
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
