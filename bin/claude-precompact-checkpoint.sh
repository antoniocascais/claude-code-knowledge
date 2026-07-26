#!/usr/bin/env bash
# PreCompact: snapshot durable state before compaction summarizes it away,
# so SessionStart(compact) can re-inject ground truth over the lossy summary.
#
# Registered without a matcher, so it covers manual /compact as well as auto.
# SessionStart's `compact` matcher fires on both, so snapshotting only `auto`
# left the re-injector replaying an older checkpoint after every manual one.
#
# Never blocks: only exit code 2 does that, and blocking a context-limit
# auto-compaction surfaces the underlying API error and fails the request.
set -euo pipefail

# The checkpoint records cwd, branch, and changed paths into a world-readable
# /tmp. Owner-only, since a shared host would otherwise expose them.
umask 077

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
trigger=$(printf '%s' "$input" | jq -r '.trigger // "auto"')
out="${TMPDIR:-/tmp}/claude-state-${sid}.md"

# Injected hook output is truncated past 10k chars, so a big working tree would
# push the branch line — the part worth recovering — into a file Claude then has
# to go read. Cap the unbounded sections instead.
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
    git -C "$cwd" status --short 2>/dev/null | head -60 || true
    echo
    echo "## diff --stat HEAD"
    git -C "$cwd" diff --stat HEAD 2>/dev/null | head -60 || true
  fi
} > "$out" 2>/dev/null || true

exit 0
