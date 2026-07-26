#!/usr/bin/env bats
# Tests for the /daily-log-before-/compact pair:
#   claude-mark-daily-log.sh          PostToolUse(Skill) — drops the flag
#   claude-precompact-daily-log-guard.sh  PreCompact(manual) — reads and consumes it
# Both resolve the flag under $TMPDIR, which is what makes them testable in isolation.

MARK="$BATS_TEST_DIRNAME/../bin/claude-mark-daily-log.sh"
GUARD="$BATS_TEST_DIRNAME/../bin/claude-precompact-daily-log-guard.sh"

setup() {
  TEST_DIR=$(mktemp -d)
  export TMPDIR="$TEST_DIR"
  SID="sess-abc123"
  FLAG="$TEST_DIR/daily-log-done.${SID}"
}

teardown() {
  rm -rf "$TEST_DIR"
}

run_mark() {
  local skill="$1" sid="${2:-$SID}" json
  json=$(jq -nc --arg s "$skill" --arg sid "$sid" '{session_id:$sid,tool_name:"Skill",tool_input:{skill:$s}}')
  run bash -c "printf '%s' '$json' | $MARK"
}

run_guard() {
  local sid="${1-$SID}" json
  json=$(jq -nc --arg sid "$sid" '{session_id:$sid,trigger:"manual"}')
  run bash -c "printf '%s' '$json' | $GUARD"
}

# --- claude-mark-daily-log.sh ---

@test "mark writes the flag for the daily-log skill" {
  run_mark "daily-log"
  [ "$status" -eq 0 ]
  [ -f "$FLAG" ]
}

@test "mark ignores any other skill" {
  run_mark "note-taking"
  [ "$status" -eq 0 ]
  [ ! -f "$FLAG" ]
}

@test "mark survives a Skill payload with no skill field" {
  run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"tool_name\":\"Skill\",\"tool_input\":{}}' | $MARK"
  [ "$status" -eq 0 ]
  [ ! -f "$FLAG" ]
}

@test "flag is owner-only — /tmp is world-readable" {
  run_mark "daily-log"
  [ "$(stat -c %a "$FLAG")" = "600" ]
}

@test "mark keys the flag by session, not globally" {
  run_mark "daily-log" "other-session"
  [ -f "$TEST_DIR/daily-log-done.other-session" ]
  [ ! -f "$FLAG" ]
}

# --- claude-precompact-daily-log-guard.sh ---

@test "guard blocks when this session has not logged" {
  run_guard
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
  [ -n "$(printf '%s' "$output" | jq -r .reason)" ]
}

@test "guard emits nothing but the decision object" {
  run_guard
  run bash -c "printf '%s' '$output' | jq -e 'keys == [\"decision\",\"reason\"]'"
  [ "$status" -eq 0 ]
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
  [ -z "$output" ]
  run_guard
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
}

@test "a sibling session's log does not satisfy this session's guard" {
  touch "$TEST_DIR/daily-log-done.other-session"
  run_guard
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
  [ -f "$TEST_DIR/daily-log-done.other-session" ]
}

@test "guard does not crash on a missing session_id" {
  run bash -c "printf '%s' '{\"trigger\":\"manual\"}' | $GUARD"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
}

# --- the pair, end to end ---

@test "mark then guard allows; guard alone blocks" {
  run_mark "daily-log"
  run_guard
  [ -z "$output" ]
  run_guard
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
}
