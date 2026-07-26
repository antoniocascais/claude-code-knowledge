#!/usr/bin/env bash
# PreCompact(manual): block a manual /compact unless THIS session ran /daily-log
# since its last compaction. Per-session flag (keyed by session_id) — so a sibling
# session logging the same project does NOT satisfy this session's guard.
#
# Deliberately manual-only. Blocking an auto-compaction that fired to recover
# from a context-limit error surfaces the API error and fails the request, so a
# gate on `auto` would turn a full context window into a dead session.
#
# Blocks via exit 2 rather than {"decision":"block"}: for a manual /compact the
# stderr message is the documented path to the user's screen, and a gate that
# refuses without saying why is indistinguishable from a broken one. Exit 2 also
# means any JSON here would be ignored, so the two cannot be combined.
set -euo pipefail

sid=$(cat | jq -r '.session_id // "unknown"')
flag="${TMPDIR:-/tmp}/daily-log-done.${sid}"

if [ -f "$flag" ]; then
  rm -f "$flag"   # consume: the next manual compact needs a fresh /daily-log
  exit 0          # allow compaction
fi

echo "No /daily-log recorded in this session since the last compaction. Run /daily-log first, then /compact again." >&2
exit 2
