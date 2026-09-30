#!/bin/bash
# Restarts RailPariksha's background content-gen/verification workers if a
# container restart killed them (pure bash, no LLM call -- fires on every
# SessionStart event, including "resume" after a mid-conversation restart).
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

if ! running "bulk_questions.py.*je_mechanical,je_civil"; then
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY2 \
    --subjects je_mechanical,je_civil \
    --topics strength_of_materials,manufacturing_processes,engineering_mechanics,structural_analysis,soil_mechanics_foundation,transportation_engineering,environmental_engineering \
    --max-calls 3000 --id-prefix-suffix f > "$LOGS/je_gaps.log" 2>&1 &
  disown
fi

if ! running "verify_questions.py.*groq"; then
  nohup python3 verify_questions.py --provider groq --model openai/gpt-oss-20b --batch-size 8 \
    --subjects science,gk,railway_gk,je_mechanical,je_civil --max-calls 500 > "$LOGS/verify_a.log" 2>&1 &
  disown
fi

if ! running "verify_questions.py.*gemini"; then
  nohup python3 verify_questions.py --provider gemini --model gemini-3.8-flash --gemini-key-env GEMINI_API_KEY2 --batch-size 20 \
    --subjects maths,current_affairs,computer,english,je_electrical,reasoning --max-calls 500 > "$LOGS/verify_b.log" 2>&1 &
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
