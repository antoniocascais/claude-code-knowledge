#!/usr/bin/env bash
# PostToolUse(Write|Edit): flag that THIS session wrote today's daily log, so the
# PreCompact(manual) guard lets /compact through.
#
# Keyed on the file that landed, not on the skill being dispatched. A user-typed
# /daily-log expands inline as prompt text and never produces a Skill tool call,
# so matching on dispatch caught only the runs Claude initiated and silently
# missed every one the user started. Watching the write also means a run that
# dies before producing a log no longer unlocks compaction.
set -euo pipefail

umask 077

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // "unknown"')
path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

# Only today's log counts: /note-taking rewrites older logs when it promotes
# flagged items, and that must not pass for having logged this session.
today=$(date +%F)
case "$path" in
  */daily_log/"$today".md) touch "${TMPDIR:-/tmp}/daily-log-done.${sid}" ;;
esac

exit 0
