#!/bin/bash
set -e

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Block git -C when targeting current dir or a parent within the same repo
if [[ "$command" =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
  git_path="${BASH_REMATCH[1]}"
  resolved_git_path=$(realpath -m "$git_path" 2>/dev/null || echo "$git_path")
  resolved_cwd=$(realpath -m "$(pwd)" 2>/dev/null || pwd)

  if [[ "$resolved_git_path" == "$resolved_cwd" ]]; then
    echo "blocked: git -C '$git_path' is redundant — already in that directory" >&2
    exit 2
  fi

  # Target is an ancestor of cwd — block if same repo (git walks up automatically)
  if [[ "$resolved_cwd" == "$resolved_git_path"/* ]]; then
    cwd_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    target_root=$(git -C "$resolved_git_path" rev-parse --show-toplevel 2>/dev/null || echo "")
    if [[ -n "$cwd_root" && "$cwd_root" == "$target_root" ]]; then
      echo "blocked: git -C '$git_path' unnecessary — already inside that repo, cd there or run without -C" >&2
      exit 2
    fi
  fi
fi

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
