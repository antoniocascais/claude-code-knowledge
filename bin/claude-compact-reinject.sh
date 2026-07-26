#!/usr/bin/env bash
# SessionStart(compact): stdout is added to context right after compaction.
# Re-inject the pre-compact checkpoint so state survives the lossy summary.
set -euo pipefail

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
f="/tmp/claude-state-${sid}.md"

if [ -f "$f" ]; then
  echo "Recovered pre-compaction checkpoint below (treat as ground truth over the summary):"
  echo
  cat "$f"
fi

exit 0
