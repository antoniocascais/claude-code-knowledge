#!/bin/bash
# Claude Code hook: Block access to .env files and gitignored files
# Used with PreToolUse matcher: Read|Edit|Write|Glob|Grep
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')

# Extract file path based on tool type
case "$tool_name" in
  Read|Write|Edit)
    file_path=$(echo "$tool_input" | jq -r '.file_path // empty')
    ;;
  Glob|Grep)
    file_path=$(echo "$tool_input" | jq -r '.path // empty')
    ;;
  *)
    exit 0
    ;;
esac

# Skip if no file path
[[ -z "$file_path" ]] && exit 0

# Resolve to absolute path if relative
if [[ "$file_path" != /* ]]; then
  file_path="$CLAUDE_PROJECT_DIR/$file_path"
fi

# 1. Block .env files (allow .example templates)
basename_file=$(basename "$file_path")
if [[ "$basename_file" == .env || "$basename_file" == .env.* ]]; then
  # Allow .env.example, .env.sample, .env.template patterns
  if [[ "$basename_file" =~ \.(example|sample|template)$ ]]; then
    : # Allow these safe templates
  else
    echo "🚫 Access denied: .env files are protected" >&2
    exit 2
  fi
fi

# 2. Block files in .gitignore (only if in a git repo)
if git -C "$CLAUDE_PROJECT_DIR" rev-parse --git-dir &>/dev/null; then
  if git -C "$CLAUDE_PROJECT_DIR" check-ignore -q "$file_path" 2>/dev/null; then
    echo "🚫 Access denied: '$file_path' is in .gitignore" >&2
    exit 2
  fi
fi

exit 0
