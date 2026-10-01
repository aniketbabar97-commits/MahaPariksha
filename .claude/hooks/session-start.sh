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

if ! running "bulk_questions.py.*topics mathematical_operations"; then
  # science, je_mechanical, je_civil and english (previously on these two
  # Gemini-key slots) all hit 311/topic on every topic and exited cleanly.
  # reasoning is now the only subject with a real gap -- bulk_questions.py's
  # flush() uses flock + re-read-before-merge, so it's safe to run multiple
  # concurrent writers against the same reasoning.json (confirmed by
  # reading the script before relying on it). Redeployed both freed slots
  # onto reasoning's weakest topics, split in half, running alongside the
  # original Groq reasoning worker below -- 3-way parallel on the one
  # subject that actually needs it instead of 2 idle-after-finishing slots.
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY --max-calls 3000 \
    --subjects reasoning --topics mathematical_operations,statement_conclusion,analogy,syllogism,puzzle_seating,mirror_water_image \
    --id-prefix-suffix i > "$LOGS/reasoning2.log" 2>&1 &
  disown
fi

if ! running "bulk_questions.py.*topics non_verbal_reasoning"; then
  nohup python3 bulk_questions.py --provider gemini --model gemini-3.1-flash-lite --gemini-key-env GEMINI_API_KEY2 --max-calls 3000 \
    --subjects reasoning --topics non_verbal_reasoning,blood_relations,coding_decoding,series,direction_sense,alphabet_test \
    --id-prefix-suffix j > "$LOGS/reasoning3.log" 2>&1 &
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
