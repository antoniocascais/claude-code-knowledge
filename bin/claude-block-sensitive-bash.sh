#!/bin/bash
# Claude Code hook: Block bash commands referencing .env or gitignored files
# Used with PreToolUse matcher: Bash
set -euo pipefail

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ -z "$command" ]] && exit 0

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

# 4. Extract file arguments and check against gitignore
# This is heuristic - catches common patterns like:
#   cat file.txt, less file.txt, head file.txt, grep pattern file.txt
# Won't catch everything but covers common cases

extract_files() {
  # Extract words that look like file paths (contain / or .)
  echo "$command" | grep -oE '\S+' | grep -E '(\.|/)' | grep -vE '^-'
}

if git -C "$CLAUDE_PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
  for potential_file in $(extract_files); do
    # Skip if looks like a flag or option
    [[ "$potential_file" == -* ]] && continue

    # Resolve path
    if [[ "$potential_file" != /* ]]; then
      full_path="$CLAUDE_PROJECT_DIR/$potential_file"
    else
      full_path="$potential_file"
    fi

    # Check if file exists and is gitignored
    if [[ -e "$full_path" ]] && git -C "$CLAUDE_PROJECT_DIR" check-ignore -q "$full_path" 2>/dev/null; then
      echo "🚫 Access denied: bash command references gitignored file '$potential_file'" >&2
      exit 2
    fi
  done
fi

exit 0
