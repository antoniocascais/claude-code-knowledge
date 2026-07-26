#!/usr/bin/env bash
# PreCompact(manual): block a manual /compact unless THIS session ran /daily-log
# since its last compaction. Per-session flag (keyed by session_id) — so a sibling
# session logging the same project does NOT satisfy this session's guard.
set -euo pipefail

sid=$(cat | jq -r '.session_id // "unknown"')
flag="${TMPDIR:-/tmp}/daily-log-done.${sid}"

if [ -f "$flag" ]; then
  rm -f "$flag"   # consume: the next manual compact needs a fresh /daily-log
  exit 0          # allow compaction
fi

printf '{"decision":"block","reason":"No /daily-log recorded in this session since the last compaction. Run /daily-log first, then /compact again."}'
exit 0
