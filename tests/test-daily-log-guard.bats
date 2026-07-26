#!/usr/bin/env bats
# Tests for the /daily-log-before-/compact pair:
#   claude-mark-daily-log.sh              PostToolUse(Write|Edit) — drops the flag
#   claude-precompact-daily-log-guard.sh  PreCompact(manual) — reads and consumes it
# Both resolve the flag under $TMPDIR, which is what makes them testable in isolation.

MARK="$BATS_TEST_DIRNAME/../bin/claude-mark-daily-log.sh"
GUARD="$BATS_TEST_DIRNAME/../bin/claude-precompact-daily-log-guard.sh"

setup() {
  TEST_DIR=$(mktemp -d)
  export TMPDIR="$TEST_DIR"
  SID="sess-abc123"
  FLAG="$TEST_DIR/daily-log-done.${SID}"
  TODAY=$(date +%F)
  NOTES="/home/someone/notes/tasks_notes/personal_projects/ai/daily_log"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# $1 = file_path, $2 = tool name (default Write), $3 = session id
run_mark() {
  local path="$1" tool="${2:-Write}" sid="${3:-$SID}" json
  json=$(jq -nc --arg p "$path" --arg t "$tool" --arg sid "$sid" \
    '{session_id:$sid,tool_name:$t,tool_input:{file_path:$p}}')
  run bash -c "printf '%s' '$json' | $MARK"
}

run_guard() {
  local sid="${1-$SID}" json
  json=$(jq -nc --arg sid "$sid" '{session_id:$sid,trigger:"manual"}')
  run bash -c "printf '%s' '$json' | $GUARD"
}

# --- claude-mark-daily-log.sh ---

@test "mark writes the flag when today's log is created with Write" {
  run_mark "$NOTES/$TODAY.md"
  [ "$status" -eq 0 ]
  [ -f "$FLAG" ]
}

@test "mark writes the flag when today's log is appended with Edit" {
  run_mark "$NOTES/$TODAY.md" "Edit"
  [ "$status" -eq 0 ]
  [ -f "$FLAG" ]
}

# The path that made the old Skill-matcher version fail: a user-typed /daily-log
# expands as prompt text and never produces a Skill tool call, but it still
# writes the log through Write or Edit.
@test "mark does not care how the skill was invoked, only that the log landed" {
  run_mark "$NOTES/$TODAY.md" "Edit"
  [ -f "$FLAG" ]
}

@test "editing an older log does not satisfy the guard" {
  run_mark "$NOTES/2026-01-01.md" "Edit"
  [ "$status" -eq 0 ]
  [ ! -f "$FLAG" ]
}

@test "promoting flagged items in yesterday's log does not count as logging today" {
  run_mark "$NOTES/$(date -d yesterday +%F).md" "Edit"
  [ ! -f "$FLAG" ]
}

@test "mark ignores a file outside any daily_log directory" {
  run_mark "/home/someone/notes/tasks_notes/personal_projects/ai/notes.md"
  [ "$status" -eq 0 ]
  [ ! -f "$FLAG" ]
}

@test "mark ignores a today-dated file that is not in daily_log" {
  run_mark "/home/someone/reports/$TODAY.md"
  [ ! -f "$FLAG" ]
}

@test "mark ignores a daily_log path with a trailing suffix" {
  run_mark "$NOTES/$TODAY.md.bak"
  [ ! -f "$FLAG" ]
}

@test "mark survives a payload with no file_path" {
  run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"tool_name\":\"Write\",\"tool_input\":{}}' | $MARK"
  [ "$status" -eq 0 ]
  [ ! -f "$FLAG" ]
}

@test "flag is owner-only — /tmp is world-readable" {
  run_mark "$NOTES/$TODAY.md"
  [ "$(stat -c %a "$FLAG")" = "600" ]
}

@test "mark keys the flag by session, not globally" {
  run_mark "$NOTES/$TODAY.md" "Write" "other-session"
  [ -f "$TEST_DIR/daily-log-done.other-session" ]
  [ ! -f "$FLAG" ]
}

# --- claude-precompact-daily-log-guard.sh ---

# Exit 2 is what actually blocks compaction. A JSON {"decision":"block"} is
# ignored on a non-zero exit, and its `reason` has no documented route to the
# user for PreCompact — only the exit-2 stderr message does.
@test "guard blocks with exit 2 when this session has not logged" {
  run_guard
  [ "$status" -eq 2 ]
}

@test "guard tells the user why it blocked, and how to proceed" {
  run_guard
  [[ "$output" == *"/daily-log"* ]]
  [[ "$output" == *"/compact"* ]]
}

@test "guard prints its reason on stderr, where /compact surfaces it" {
  run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"trigger\":\"manual\"}' | $GUARD 2>/dev/null"
  [ -z "$output" ]
}

@test "guard emits no JSON — it would be ignored on exit 2" {
  run_guard
  run bash -c "printf '%s' '$output' | jq -e . >/dev/null 2>&1"
  [ "$status" -ne 0 ]
}

@test "guard allows when the flag exists" {
  touch "$FLAG"
  run_guard
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "guard consumes the flag so the next compact needs a fresh log" {
  touch "$FLAG"
  run_guard
  [ ! -f "$FLAG" ]
}

@test "guard blocks again on the second compact of the same session" {
  touch "$FLAG"
  run_guard
  [ "$status" -eq 0 ]
  run_guard
  [ "$status" -eq 2 ]
}

@test "a sibling session's log does not satisfy this session's guard" {
  touch "$TEST_DIR/daily-log-done.other-session"
  run_guard
  [ "$status" -eq 2 ]
  [ -f "$TEST_DIR/daily-log-done.other-session" ]
}

@test "guard does not crash on a missing session_id" {
  run bash -c "printf '%s' '{\"trigger\":\"manual\"}' | $GUARD"
  [ "$status" -eq 2 ]
}

# --- the pair, end to end ---

@test "mark then guard allows; guard alone blocks" {
  run_mark "$NOTES/$TODAY.md"
  run_guard
  [ "$status" -eq 0 ]
  run_guard
  [ "$status" -eq 2 ]
}
