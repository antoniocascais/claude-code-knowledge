#!/usr/bin/env bash
# PostToolUse(Skill): drop a per-session flag when the daily-log skill is invoked,
# so the PreCompact(manual) guard can confirm THIS session logged.
# User-typed /daily-log routes through the Skill tool, so this (not
# UserPromptExpansion) is the event that fires.
set -euo pipefail

umask 077

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // empty')

if [ "$skill" = "daily-log" ]; then
  touch "${TMPDIR:-/tmp}/daily-log-done.${sid}"
fi

exit 0
