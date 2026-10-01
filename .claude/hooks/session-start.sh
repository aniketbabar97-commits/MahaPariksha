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
  # gpt-oss-20b was unreliable here (broad JSON-validation 400s across
  # topics/angles on the generation prompt, unlike the short verification
  # prompt it handles fine) -- qwen/qwen3.8-27b confirmed working instead.
  nohup python3 bulk_questions.py --provider groq --model qwen/qwen3.8-27b --max-calls 3000 \
    --subjects reasoning --id-prefix-suffix o > "$LOGS/reasoning.log" 2>&1 &
  disown
fi

if ! running "bulk_questions.py.*science,je_mechanical"; then
  # maths hit its 311/topic target on all 15 topics and exited cleanly, so
  # this slot (GEMINI_API_KEY, gemini-3.1-flash-lite) was redeployed to the
  # two subjects furthest behind target instead of sitting idle.
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY --max-calls 3000 \
    --subjects science,je_mechanical --id-prefix-suffix h > "$LOGS/science_jemech.log" 2>&1 &
  disown
fi

if ! running "bulk_questions.py.*je_civil,english"; then
  # Split off from the original 4-subject je_gaps worker (je_mechanical,
  # je_civil,science,english sharing one key/process) into two 2-subject
  # workers on separate keys, so all 4 gap subjects get parallel throughput
  # instead of round-robining one call at a time.
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY2 --max-calls 3000 \
    --subjects je_civil,english --id-prefix-suffix f > "$LOGS/jecivil_english.log" 2>&1 &
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
