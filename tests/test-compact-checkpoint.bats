#!/usr/bin/env bats
# Tests for the compaction-survival pair:
#   claude-precompact-checkpoint.sh  PreCompact(auto)     — snapshots state
#   claude-compact-reinject.sh       SessionStart(compact) — replays it into context
# Both resolve the checkpoint under $TMPDIR, which is what makes them testable.

CHECKPOINT="$BATS_TEST_DIRNAME/../bin/claude-precompact-checkpoint.sh"
REINJECT="$BATS_TEST_DIRNAME/../bin/claude-compact-reinject.sh"

setup() {
  TEST_DIR=$(mktemp -d)
  export TMPDIR="$TEST_DIR"
  SID="sess-xyz789"
  STATE="$TEST_DIR/claude-state-${SID}.md"

  REPO="$TEST_DIR/repo"
  mkdir -p "$REPO"
  git -C "$REPO" init -q -b main .
  git -C "$REPO" config user.email t@t.t
  git -C "$REPO" config user.name t
  printf 'one\n' > "$REPO/tracked.md"
  git -C "$REPO" add tracked.md
  git -C "$REPO" commit -qm init
}

teardown() {
  rm -rf "$TEST_DIR"
}

run_checkpoint() {
  local cwd="${1-$REPO}" sid="${2-$SID}" json
  json=$(jq -nc --arg c "$cwd" --arg sid "$sid" '{session_id:$sid,cwd:$c,trigger:"auto"}')
  run bash -c "printf '%s' '$json' | $CHECKPOINT"
}

run_reinject() {
  local sid="${1-$SID}" json
  json=$(jq -nc --arg sid "$sid" '{session_id:$sid,source:"compact"}')
  run bash -c "printf '%s' '$json' | $REINJECT"
}

# --- claude-precompact-checkpoint.sh ---

@test "checkpoint writes the state file" {
  run_checkpoint
  [ "$status" -eq 0 ]
  [ -f "$STATE" ]
}

@test "checkpoint is owner-only — /tmp is world-readable" {
  run_checkpoint
  [ "$(stat -c %a "$STATE")" = "600" ]
}

@test "checkpoint records cwd and trigger" {
  run_checkpoint
  grep -q "cwd: $REPO" "$STATE"
  grep -q "trigger: auto" "$STATE"
}

@test "checkpoint records the branch" {
  run_checkpoint
  grep -q "## branch" "$STATE"
  grep -qx "main" "$STATE"
}

@test "checkpoint records uncommitted work" {
  printf 'two\n' >> "$REPO/tracked.md"
  printf 'new\n' > "$REPO/untracked.md"
  run_checkpoint
  grep -q "tracked.md" "$STATE"
  grep -q "untracked.md" "$STATE"
}

@test "checkpoint survives a non-git cwd" {
  mkdir -p "$TEST_DIR/plain"
  run_checkpoint "$TEST_DIR/plain"
  [ "$status" -eq 0 ]
  [ -f "$STATE" ]
  grep -q "cwd: $TEST_DIR/plain" "$STATE"
  ! grep -q "## branch" "$STATE"
}

@test "checkpoint survives a missing cwd field" {
  run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"trigger\":\"auto\"}' | $CHECKPOINT"
  [ "$status" -eq 0 ]
  grep -q "cwd: unknown" "$STATE"
}

@test "checkpoint survives a cwd that does not exist" {
  run_checkpoint "$TEST_DIR/gone"
  [ "$status" -eq 0 ]
  [ -f "$STATE" ]
}

@test "checkpoint keys the file by session" {
  run_checkpoint "$REPO" "other-session"
  [ -f "$TEST_DIR/claude-state-other-session.md" ]
  [ ! -f "$STATE" ]
}

@test "a second checkpoint replaces the first, it does not append" {
  run_checkpoint
  first=$(grep -c "# Compaction checkpoint" "$STATE")
  run_checkpoint
  second=$(grep -c "# Compaction checkpoint" "$STATE")
  [ "$first" -eq 1 ]
  [ "$second" -eq 1 ]
}

# --- claude-compact-reinject.sh ---

@test "reinject replays the checkpoint" {
  run_checkpoint
  run_reinject
  [ "$status" -eq 0 ]
  [[ "$output" == *"Compaction checkpoint"* ]]
  [[ "$output" == *"cwd: $REPO"* ]]
}

@test "reinject frames the checkpoint as authoritative over the summary" {
  run_checkpoint
  run_reinject
  [[ "$output" == *"ground truth"* ]]
}

@test "reinject stays silent when no checkpoint exists" {
  run_reinject
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "reinject does not read another session's checkpoint" {
  run_checkpoint "$REPO" "other-session"
  run_reinject
  [ -z "$output" ]
}

@test "reinject does not crash on a missing session_id" {
  run bash -c "printf '%s' '{\"source\":\"compact\"}' | $REINJECT"
  [ "$status" -eq 0 ]
}

@test "reinject does not crash on an empty checkpoint" {
  : > "$STATE"
  run_reinject
  [ "$status" -eq 0 ]
}
