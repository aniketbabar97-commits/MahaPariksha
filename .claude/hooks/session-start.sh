#!/bin/bash
# RailPariksha session-start hook (pure bash, no LLM call -- fires on every
# SessionStart event, including "resume" after a mid-conversation restart).
#
# Bulk content generation is DONE: every subject hit its per-topic target
# (311/topic generally, 15/topic for current_affairs), 25,078 questions
# total against the 25,000 goal, confirmed via a full sweep across all
# content/bank/*.json files. The worker-relaunch logic that used to live
# here has been retired -- there is nothing left to regenerate. Only the
# auto-checkpoint-commit behavior remains, in case some other process still
# touches content/bank mid-session.
set -uo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REPO=/home/user/MahaPariksha/railpariksha
[ -d "$REPO" ] || exit 0
cd "$REPO" || exit 0

if [ -n "$(git status --porcelain -- content/bank content/notes pipeline/content_gen/verify_state 2>/dev/null)" ]; then
  git add content/bank content/notes pipeline/content_gen/verify_state 2>/dev/null
  git commit -q -m "Auto checkpoint (session-start hook): content-growth after restart" 2>/dev/null || true
fi

exit 0
