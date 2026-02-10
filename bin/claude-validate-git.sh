#!/bin/bash
set -e

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Block force push (including --force-with-lease variants)
if [[ "$command" =~ git[[:space:]]+push[[:space:]]+.*(-f|--force|--force-with-lease|--force-if-includes)([[:space:]]|$) ]]; then
  echo "blocked: force push not allowed — use regular push or ask user" >&2
  exit 2
fi

# Block commit --amend
if [[ "$command" =~ git[[:space:]]+commit[[:space:]]+.*--amend([[:space:]]|$) ]]; then
  echo "blocked: commit --amend not allowed — create a new commit instead" >&2
  exit 2
fi

# Block write operations on main branch
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [[ "$current_branch" == "main" ]]; then
  if [[ "$command" =~ git[[:space:]]+(push|commit|merge|rebase|reset|clean|cherry-pick|am|apply)([[:space:]]|$) ]]; then
    echo "blocked: write operation on main not allowed — create a feature branch first" >&2
    exit 2
  fi
  if [[ "$command" =~ git[[:space:]]+branch[[:space:]]+-D ]]; then
    echo "blocked: branch deletion on main not allowed" >&2
    exit 2
  fi
fi

exit 0
