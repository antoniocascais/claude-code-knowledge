#!/bin/bash
# Claude Code hook: Block bash commands referencing .env or gitignored files
# Used with PreToolUse matcher: Bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ -z "$command" ]] && exit 0

# Block rm commands — user should remove files themselves
if echo "$command" | grep -qE '(^|[;&|]\s*)rm\s'; then
  echo "🚫 Blocked: Claude cannot delete files. Please run this yourself:" >&2
  echo "" >&2
  echo "  $command" >&2
  exit 2
fi

# Block cp/mv to /tmp — prevents bypassing file protections
if echo "$command" | grep -qE '(cp|mv)\s+.*\s+/tmp'; then
  echo "🚫 Blocked: cannot copy/move files to /tmp" >&2
  exit 2
fi

# Block .env patterns (allow .example/.sample/.template)
# Match: .env, .env.local, .env.production, etc.
# Allow: .env.example, .env.sample, .env.template

# Helper to check if .env reference is allowed template
is_allowed_env() {
  echo "$1" | grep -qE '\.(example|sample|template)(['"'"'"\s]|$)'
}

# 1. Direct .env references (shell commands like cat .env)
if echo "$command" | grep -qE '\.env(\s|$|/)'; then
  echo "🚫 Access denied: bash command references .env file" >&2
  exit 2
fi
if echo "$command" | grep -qE '\.env\.[a-zA-Z0-9_-]+'; then
  if ! is_allowed_env "$command"; then
    echo "🚫 Access denied: bash command references .env file" >&2
    exit 2
  fi
fi

# 2. .env inside string literals (catches python/ruby/node/perl interpreters)
# Matches: open('.env'), open(".env"), Path('/foo/.env'), etc.
if echo "$command" | grep -qE "['\"][^'\"]*\.env[^'\"]*['\"]"; then
  # Extract the matched string to check if it's an allowed template
  matched=$(echo "$command" | grep -oE "['\"][^'\"]*\.env[^'\"]*['\"]" | head -1)
  if ! is_allowed_env "$matched"; then
    echo "🚫 Access denied: bash command references .env file in string literal" >&2
    exit 2
  fi
fi

# 3. Block glob patterns that could expand to .env
# Catches: .e*, .*nv, .[e]nv, *env, etc.
shopt -s nullglob
while IFS= read -r word; do
  # Skip if no glob characters
  [[ "$word" != *[\*\?\[]* ]] && continue

  # Skip if doesn't look like a path
  [[ "$word" != */* ]] && [[ "$word" != .* ]] && continue

  # Expand glob and check each result
  for expanded in $word; do
    basename_exp=$(basename "$expanded")
    if [[ "$basename_exp" == .env || "$basename_exp" == .env.* ]]; then
      if [[ ! "$basename_exp" =~ \.(example|sample|template)$ ]]; then
        echo "🚫 Access denied: glob '$word' expands to .env file" >&2
        exit 2
      fi
    fi
  done
done < <(echo "$command" | grep -oE '\S+')
shopt -u nullglob

# A heredoc body is data, not arguments — a commit message that mentions
# terraform.tfstate is prose. Exception: fed to an interpreter the body IS
# code, so it stays in scope.
scannable_text() {
  local interp='(^|[;&|[:space:]])(python3?|perl|ruby|node|bash|sh|zsh|awk)[^<]*<<'
  local heredoc='<<-?[[:space:]]*("|'\'')?[A-Za-z_]'

  if [[ "$command" =~ $interp ]] || [[ ! "$command" =~ $heredoc ]]; then
    printf '%s' "$command"
  else
    printf '%s' "${command%%<<*}"
  fi
}

# String literals are emitted as tokens too — interpreters embed paths in
# quotes, where whitespace splitting leaves `prod.pem").read())`.
extract_tokens() {
  local text
  text=$(scannable_text)
  {
    echo "$text" | grep -oE '\S+' || true
    echo "$text" | grep -oE "['\"][^'\"]+['\"]" | tr -d "'\"" || true
  } | grep -vE '^(-|$)' || true
}

# 4a. Secret-file name patterns.
# Deliberately independent of gitignore: a repo that forgot to ignore its
# tfstate is the case most worth catching, and there is no existence check —
# `scp host:~/.ssh/id_rsa .` has no local file to stat.
# Suffix-anchored on purpose: *token*/*secret* would eat tokenizer.py and
# secret-manager.go.
is_secret_name() {
  case "$1" in
    *.pem|*.key|*.p12|*.pfx|*.jks|*.keystore)       return 0 ;;
    id_rsa|id_dsa|id_ecdsa|id_ed25519)              return 0 ;;
    .netrc|_netrc|.npmrc|.pypirc|.htpasswd)         return 0 ;;
    credentials|credentials.json|.credentials.json) return 0 ;;
    .gh-token|*.token|*_token|*-token)              return 0 ;;
    secrets.yaml|secrets.yml|secrets.json|.secrets|*.secret) return 0 ;;
    *.tfstate|*.tfstate.*|*.tfvars)                 return 0 ;;
    kubeconfig|.dockercfg)                          return 0 ;;
    service-account*.json)                          return 0 ;;
  esac
  return 1
}

# Gitignored for tidiness, not secrecy. Checked after 4a, so secrets.md still
# blocks. Cost of omitting this: every read of CLAUDE.md/SKILL.md burns a turn.
is_benign_name() {
  case "$1" in
    *.md|*.md.example)                       return 0 ;;
    settings.json|settings.local.json)       return 0 ;;
    .gitignore|.gitattributes|.editorconfig) return 0 ;;
  esac
  return 1
}

for tok in $(extract_tokens); do
  base=$(basename "$tok")
  if is_secret_name "$base" || [[ "$tok" == *.kube/config ]] || [[ "$tok" == *.docker/config.json ]]; then
    echo "🚫 Access denied: '$tok' matches a secret-file pattern" >&2
    exit 2
  fi
done

# 4b. Gitignored-file sweep — the broad net for secrets with no name signal
# (tfstate, kubeconfig, .env under another name).
if git -C "$CLAUDE_PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
  for potential_file in $(extract_tokens | grep -E '(\.|/)'); do
    base=$(basename "$potential_file")
    is_benign_name "$base" && continue

    if [[ "$potential_file" != /* ]]; then
      full_path="$CLAUDE_PROJECT_DIR/$potential_file"
    else
      full_path="$potential_file"
    fi

    if [[ -e "$full_path" ]] && git -C "$CLAUDE_PROJECT_DIR" check-ignore -q "$full_path" 2>/dev/null; then
      echo "🚫 Access denied: bash command references gitignored file '$potential_file'" >&2
      exit 2
    fi
  done
fi

exit 0
