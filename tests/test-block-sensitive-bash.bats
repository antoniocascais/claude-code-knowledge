#!/usr/bin/env bats
# Tests for claude-block-sensitive-bash.sh hook

HOOK="$BATS_TEST_DIRNAME/../bin/claude-block-sensitive-bash.sh"

setup() {
  export TEST_DIR=$(mktemp -d)
  export ORIG_DIR="$PWD"
  cd "$TEST_DIR"
  git init -q .
  git config user.email t@t.t
  git config user.name t

  printf 'CLAUDE.md\n.claude/settings.local.json\nbuild/\nterraform.tfstate\n' > .gitignore
  touch CLAUDE.md .env .env.example notes.md tokenizer.py secret-manager.go
  mkdir -p .claude build
  touch .claude/settings.local.json build/out.js
  touch terraform.tfstate prod.pem .gh-token

  export CLAUDE_PROJECT_DIR="$TEST_DIR"
}

teardown() {
  cd "$ORIG_DIR"
  rm -rf "$TEST_DIR"
}

run_hook() {
  local json
  json=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1")
  run bash -c "echo '$json' | $HOOK"
}

# --- rules 1-3: .env handling (unchanged behaviour, regression guard) ---

@test "blocks bare .env read" {
  run_hook "cat .env"
  [ "$status" -eq 2 ]
}

@test "blocks .env inside a string literal" {
  run_hook "python3 -c \\\"open('.env')\\\""
  [ "$status" -eq 2 ]
}

@test "allows .env.example" {
  run_hook "cat .env.example"
  [ "$status" -eq 0 ]
}

# --- 4a: secret-name patterns, independent of gitignore ---

@test "blocks tfstate that is NOT gitignored" {
  printf 'CLAUDE.md\n' > .gitignore   # tfstate no longer ignored
  run_hook "cat terraform.tfstate"
  [ "$status" -eq 2 ]
  [[ "$output" == *"secret-file pattern"* ]]
}

@test "blocks .pem outside the project dir" {
  run_hook "cat /home/someone/prod.pem"
  [ "$status" -eq 2 ]
}

@test "blocks ssh key that does not exist locally" {
  run_hook "scp host:~/.ssh/id_rsa ."
  [ "$status" -eq 2 ]
}

@test "blocks .gh-token explicitly, not by gitignore accident" {
  printf '\n' > .gitignore
  run_hook "cat .gh-token"
  [ "$status" -eq 2 ]
  [[ "$output" == *"secret-file pattern"* ]]
}

@test "blocks kubeconfig by basename" {
  run_hook "kubectl --kubeconfig /etc/rancher/kubeconfig get pods"
  [ "$status" -eq 2 ]
}

@test "blocks .kube/config by path" {
  run_hook "cat ~/.kube/config"
  [ "$status" -eq 2 ]
}

# --- 4a: suffix anchoring must not overmatch ---

@test "allows tokenizer.py (not *_token)" {
  run_hook "python3 tokenizer.py"
  [ "$status" -eq 0 ]
}

@test "allows secret-manager.go (not *.secret)" {
  run_hook "go run secret-manager.go"
  [ "$status" -eq 0 ]
}

@test "allows id_rsa.pub" {
  run_hook "cat /home/someone/.ssh/id_rsa.pub"
  [ "$status" -eq 0 ]
}

# --- 4b: benign gitignored files now readable ---

@test "allows gitignored CLAUDE.md" {
  run_hook "stat -c%s CLAUDE.md"
  [ "$status" -eq 0 ]
}

@test "allows gitignored settings.local.json" {
  run_hook "jq empty .claude/settings.local.json"
  [ "$status" -eq 0 ]
}

@test "allows .gitignore itself" {
  run_hook "cat .gitignore"
  [ "$status" -eq 0 ]
}

@test "secret name beats benign extension" {
  touch secrets.yaml
  run_hook "cat secrets.yaml"
  [ "$status" -eq 2 ]
}

# --- 4b: gitignored non-benign files still blocked ---

@test "blocks gitignored build artifact" {
  run_hook "cat build/out.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"gitignored"* ]]
}

@test "allows tracked file" {
  run_hook "cat notes.md"
  [ "$status" -eq 0 ]
}

# --- rules 1-2 regression ---

@test "blocks rm" {
  run_hook "rm notes.md"
  [ "$status" -eq 2 ]
}

@test "blocks cp to /tmp" {
  run_hook "cp notes.md /tmp/x"
  [ "$status" -eq 2 ]
}

@test "allows plain command with no paths" {
  run_hook "echo hello"
  [ "$status" -eq 0 ]
}
