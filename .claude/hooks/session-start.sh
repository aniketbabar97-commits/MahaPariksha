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
# NOTES generation is now in progress for the 27 (subject, topic) pairs that
# don't have one yet: gk (2), computer (4), english (3), and all 18 JE
# engineering topics (mechanical/civil/electrical, 6 each). Unlike
# bulk_questions.py, notes.py doesn't self-relaunch on restart, so this hook
# does it for them -- per the standing rule: every background worker gets a
# relaunch entry here so it survives a container restart.
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

if ! running "notes.py.*gk,computer,english"; then
  nohup python3 notes.py --provider groq --model openai/gpt-oss-120b --limit 20 \
    --subjects gk,computer,english > "$LOGS/notes1.log" 2>&1 &
  disown
fi

if ! running "notes.py.*je_mechanical"; then
  nohup python3 notes.py --provider gemini --model gemini-flash-lite-latest --gemini-key-env GEMINI_API_KEY --limit 10 \
    --subjects je_mechanical > "$LOGS/notes2.log" 2>&1 &
  disown
fi

if ! running "notes.py.*je_civil,je_electrical"; then
  nohup python3 notes.py --provider gemini --model gemini-flash-lite-latest --gemini-key-env GEMINI_API_KEY2 --limit 16 \
    --subjects je_civil,je_electrical > "$LOGS/notes3.log" 2>&1 &
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
