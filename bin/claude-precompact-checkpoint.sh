#!/usr/bin/env bash
# PreCompact(auto): snapshot durable state before auto-compaction summarizes it away,
# so SessionStart(compact) can re-inject ground truth over the lossy summary.
set -euo pipefail

# The checkpoint records cwd, branch, and changed paths into a world-readable
# /tmp. Owner-only, since a shared host would otherwise expose them.
umask 077

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
trigger=$(printf '%s' "$input" | jq -r '.trigger // "auto"')
out="${TMPDIR:-/tmp}/claude-state-${sid}.md"

{
  echo "# Compaction checkpoint"
  echo "- when: $(date -Iseconds)"
  echo "- trigger: ${trigger}"
  echo "- cwd: ${cwd:-unknown}"
  if [ -n "${cwd:-}" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo
    echo "## branch"
    git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true
    echo
    echo "## git status --short"
    git -C "$cwd" status --short 2>/dev/null || true
    echo
    echo "## diff --stat HEAD"
    git -C "$cwd" diff --stat HEAD 2>/dev/null || true
  fi
} > "$out" 2>/dev/null || true

exit 0
