#!/bin/bash
# RailPariksha session-start hook (pure bash, no LLM call -- fires on every
# SessionStart event, including "resume" after a mid-conversation restart).
#
# Bulk QUESTION generation is DONE: every subject hit its per-topic target
# (311/topic generally, 15/topic for current_affairs), 25,078 questions
# total against the 25,000 goal. That worker-relaunch logic has been
# retired -- there is nothing left to regenerate there.
#
# FLASHCARD generation is now in progress (target 20/topic, ~1,760 cards
# across 10 subjects -- current_affairs excluded, see bulk_flashcards.py's
# commit message for why). Unlike the old bulk_questions.py workers, these
# don't self-relaunch on restart, so this hook does it for them.
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

if ! running "bulk_flashcards.py.*maths,reasoning,science"; then
  nohup python3 bulk_flashcards.py --provider groq --model qwen/qwen3.8-27b --max-calls 600 --target 20 \
    --subjects maths,reasoning,science > "$LOGS/fc1.log" 2>&1 &
  disown
fi

if ! running "bulk_flashcards.py.*gk,railway_gk,computer"; then
  nohup python3 bulk_flashcards.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY --max-calls 600 --target 20 \
    --subjects gk,railway_gk,computer > "$LOGS/fc2.log" 2>&1 &
  disown
fi

if ! running "bulk_flashcards.py.*english,je_mechanical"; then
  nohup python3 bulk_flashcards.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY2 --max-calls 600 --target 20 \
    --subjects english,je_mechanical,je_civil,je_electrical > "$LOGS/fc3.log" 2>&1 &
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
