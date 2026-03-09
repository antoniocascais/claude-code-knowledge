#!/usr/bin/env bats
# Tests for claude-block-absolute-paths.sh hook

HOOK="$BATS_TEST_DIRNAME/../bin/claude-block-absolute-paths.sh"

setup() {
  export TEST_DIR=$(mktemp -d)
  mkdir -p "$TEST_DIR/subdir/nested"
  touch "$TEST_DIR/script.py"
  touch "$TEST_DIR/subdir/app.js"
  touch "$TEST_DIR/subdir/nested/deep.sh"
  export ORIG_DIR="$PWD"
  cd "$TEST_DIR"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
}

run_hook() {
  local cmd="$1"
  run bash -c 'echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}}" | '"$HOOK" -- "$cmd"
}

# Use a wrapper that properly passes the command through
run_hook() {
  local cmd="$1"
  local json
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$cmd")
  run bash -c "echo '$json' | $HOOK"
}

# --- SHOULD BLOCK ---

@test "blocks absolute path to file in CWD" {
  run_hook "python3 $TEST_DIR/script.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"use relative path"* ]]
}

@test "blocks absolute path to file in subdirectory" {
  run_hook "node $TEST_DIR/subdir/app.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"use relative path"* ]]
  [[ "$output" == *"subdir/app.js"* ]]
}

@test "blocks absolute path to deeply nested file" {
  run_hook "bash $TEST_DIR/subdir/nested/deep.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"subdir/nested/deep.sh"* ]]
}

@test "blocks when path appears mid-command with args" {
  run_hook "python3 $TEST_DIR/script.py --verbose --output foo"
  [ "$status" -eq 2 ]
}

@test "blocks absolute path with CLAUDE_PROJECT_DIR set" {
  export CLAUDE_PROJECT_DIR="$TEST_DIR"
  cd /tmp
  run_hook "cat $TEST_DIR/script.py"
  [ "$status" -eq 2 ]
  unset CLAUDE_PROJECT_DIR
}

@test "blocks home-relative path (~/) when it resolves inside CWD" {
  if [[ "$TEST_DIR" == "$HOME"/* ]]; then
    local rel="${TEST_DIR#$HOME/}"
    run_hook "python3 ~/$rel/script.py"
    [ "$status" -eq 2 ]
  else
    skip "TEST_DIR not under HOME"
  fi
}

# --- SHOULD ALLOW ---

@test "allows system paths like /usr/bin" {
  run_hook "/usr/bin/python3 script.py"
  [ "$status" -eq 0 ]
}

@test "allows /etc paths" {
  run_hook "cat /etc/hostname"
  [ "$status" -eq 0 ]
}

@test "allows /var paths" {
  run_hook "tail -f /var/log/syslog"
  [ "$status" -eq 0 ]
}

@test "allows /opt paths" {
  run_hook "/opt/tools/lint.sh"
  [ "$status" -eq 0 ]
}

@test "allows relative paths" {
  run_hook "python3 ./script.py"
  [ "$status" -eq 0 ]
}

@test "allows relative paths without dot prefix" {
  run_hook "python3 subdir/app.js"
  [ "$status" -eq 0 ]
}

@test "allows commands with no file paths" {
  run_hook "echo hello world"
  [ "$status" -eq 0 ]
}

@test "allows absolute path outside project dir" {
  run_hook "cat /home/otheruser/some/file.txt"
  [ "$status" -eq 0 ]
}

@test "allows empty command" {
  local json='{"tool_name":"Bash","tool_input":{"command":""}}'
  run bash -c "echo '$json' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "allows commands with only flags" {
  run_hook "git status --short"
  [ "$status" -eq 0 ]
}

# --- EDGE CASES ---

@test "blocks local path even when mixed with system paths" {
  run_hook "/usr/bin/python3 $TEST_DIR/script.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"script.py"* ]]
}

@test "blocks path matching CWD exactly" {
  run_hook "ls $TEST_DIR"
  [ "$status" -eq 2 ]
}

# --- RELATIVE PATH NORMALIZATION ---

@test "suggested relative path always starts with ./" {
  run_hook "python3 $TEST_DIR/script.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"'./script.py'"* ]]
}

@test "suggested relative path for subdirectory starts with ./" {
  run_hook "python3 $TEST_DIR/subdir/app.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"'./subdir/app.js'"* ]]
}

@test "suggested relative path for nested file starts with ./" {
  run_hook "bash $TEST_DIR/subdir/nested/deep.sh"
  [ "$status" -eq 2 ]
  [[ "$output" == *"'./subdir/nested/deep.sh'"* ]]
}

@test "suggested relative path for dotfile dir starts with ./" {
  mkdir -p "$TEST_DIR/.hidden/scripts"
  touch "$TEST_DIR/.hidden/scripts/run.py"
  run_hook "python3 $TEST_DIR/.hidden/scripts/run.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"'./.hidden/scripts/run.py'"* ]]
}

@test "suggested relative path for CWD itself is './'" {
  run_hook "ls $TEST_DIR"
  [ "$status" -eq 2 ]
  [[ "$output" == *"'./'"* ]] || [[ "$output" == *"'.'"* ]]
}
