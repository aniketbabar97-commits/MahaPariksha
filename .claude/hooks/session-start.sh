#!/bin/bash
# Restarts RailPariksha's background content-gen workers if a container
# restart killed them (pure bash, no LLM call -- fires on every SessionStart
# event, including "resume" after a mid-conversation restart).
#
# Currently configured for full generation mode (verification paused) per
# explicit user direction to prioritize closing the ~8,200-question gap to
# the 24,015 target before the Sunday target. Revert to the 3-way
# generation+verification split (see git history before this comment) once
# the gap is closed.
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

if ! running "bulk_questions.py.*--subjects reasoning "; then
  nohup python3 bulk_questions.py --provider groq --model openai/gpt-oss-20b --max-calls 3000 \
    --subjects reasoning --id-prefix-suffix o > "$LOGS/reasoning.log" 2>&1 &
  disown
fi

if ! running "bulk_questions.py.*--subjects maths "; then
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.8-flash --gemini-key-env GEMINI_API_KEY --max-calls 3000 \
    --subjects maths --id-prefix-suffix g > "$LOGS/maths.log" 2>&1 &
  disown
fi

if ! running "bulk_questions.py.*je_mechanical,je_civil,science,english"; then
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY2 --max-calls 3000 \
    --subjects je_mechanical,je_civil,science,english --id-prefix-suffix f > "$LOGS/je_gaps.log" 2>&1 &
  disown
fi

# Commit any content the workers wrote before the restart, so a second restart
# right after this one doesn't lose it. Never touches GitHub (no push).
cd "$REPO" || exit 0
if [ -n "$(git status --porcelain -- content/bank content/notes pipeline/content_gen/verify_state 2>/dev/null)" ]; then
  git add content/bank content/notes pipeline/content_gen/verify_state 2>/dev/null
  git commit -q -m "Auto checkpoint (session-start hook): content-growth after restart" 2>/dev/null || true
fi

exit 0
