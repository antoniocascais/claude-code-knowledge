#!/bin/bash
# Claude Code hook: Block absolute paths in Bash commands when a relative path would work
# If a path resolves within CWD or CLAUDE_PROJECT_DIR, force relative path usage
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
command=$(echo "$input" | jq -r '.tool_input.command // empty')

[[ -z "$command" ]] && exit 0

cwd=$(pwd)
project_dir="${CLAUDE_PROJECT_DIR:-$cwd}"

# Extract all absolute paths from the command
# Matches paths starting with / or ~ that look like file paths
while IFS= read -r abs_path; do
  [[ -z "$abs_path" ]] && continue

  # Expand ~ to $HOME
  expanded="${abs_path/#\~/$HOME}"

  # Skip standard system paths — these are never "local"
  case "$expanded" in
    /usr/*|/bin/*|/sbin/*|/etc/*|/dev/*|/proc/*|/sys/*|/var/*|/opt/*|/lib/*|/run/*) continue ;;
  esac

  # Resolve to canonical path
  resolved=$(realpath -m "$expanded" 2>/dev/null || echo "$expanded")
  resolved_cwd=$(realpath -m "$cwd" 2>/dev/null || echo "$cwd")
  resolved_project=$(realpath -m "$project_dir" 2>/dev/null || echo "$project_dir")

  # Check if path is within CWD or project dir
  rel_path=""
  if [[ "$resolved" == "$resolved_cwd"/* ]]; then
    rel_path="${resolved#$resolved_cwd/}"
  elif [[ "$resolved" == "$resolved_project"/* ]]; then
    rel_path="${resolved#$resolved_project/}"
  elif [[ "$resolved" == "$resolved_cwd" || "$resolved" == "$resolved_project" ]]; then
    rel_path="."
  fi

  if [[ -n "$rel_path" ]]; then
    # Normalize: avoid "./." for CWD-exact match
    suggestion="./$rel_path"
    [[ "$rel_path" == "." ]] && suggestion="./"
    echo "blocked: use relative path '$suggestion' instead of '$abs_path'" >&2
    exit 2
  fi
done < <(echo "$command" | grep -oE '(~|/)[/a-zA-Z0-9._-]+' | sort -u)

exit 0
