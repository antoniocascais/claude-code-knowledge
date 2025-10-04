#!/usr/bin/env bash

###
# Important note: this script is still a WIP. Needs to be reviewed and tested more extensively.
###

# Only enable strict mode when the script is *executed*, not when it's *sourced*
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
fi

# ---- Config ----
: "${AI_ROOT:=/home/$USER/Documents/ai}"
AI_AGENTS_DIR="$AI_ROOT/agents"
AI_CONTEXT="$AI_ROOT/commands/user/context.md"

# Helper: build a quoted prompt and execute `codex` with it.
_codex_run_with_prompt() {
  local prompt="$1"
  # If the prompt is huge, fall back to stdin (avoids ARG_MAX edge cases).
  if (( ${#prompt} > 100000 )); then
    codex <<EOF
$prompt
EOF
  else
    codex "$prompt"
  fi
}

# Helper: safe read file content (no trailing CRLF surprises)
_read() { cat -- "$1"; }

# Generic launcher that injects a full agent file + optional context + user task
_codex_agent_from_file() {
  local agent_file="$1"; shift
  local user_args="$*"
  local prompt
  prompt="$(printf 'Instructions:\n\n%s\n\nShared Context:\n\n%s\n\nARGUMENTS: %s\n' \
    "$(_read "$agent_file")" \
    "$(_read "$AI_CONTEXT")" \
    "$user_args")"
  _codex_run_with_prompt "$prompt"
}

# ---- Public commands ----

# Use any agent by filename (without .md)
codex-agent () {
  local agent="${1:-}"
  shift || true
  if [[ -z "$agent" ]]; then
    echo "usage: codex-agent <agent-name> [task...]" >&2
    return 2
  fi
  local f="$AI_AGENTS_DIR/$agent.md"
  [[ -f "$f" ]] || { echo "Agent not found: $f" >&2; return 1; }
  _codex_agent_from_file "$f" "$*"
}

# Convenience shortcuts (mirror Claude Code agents)
codex-pr()    { _codex_agent_from_file "$AI_AGENTS_DIR/pr-reviewer.md" "$*"; }
codex-kb()    { _codex_agent_from_file "$AI_AGENTS_DIR/knowledge-base-curator.md" "$*"; }
codex-notes() { _codex_agent_from_file "$AI_AGENTS_DIR/task-notes-cleaner.md" "$*"; }

# Plain manifest run (small prompt; no full agent injection)
codex-brief () {
  local prompt
  prompt="$(printf 'Instructions:\n\n%s\n\nARGUMENTS: %s\n' \
    "$(_read "$AI_ROOT/AGENTS.md")" \
    "$*")"
  _codex_run_with_prompt "$prompt"
}

# --- Add below the other public commands ---

# Show the current user context (no Codex run)
codex-context-print () {
  [[ -f "$AI_CONTEXT" ]] || { echo "Context file not found: $AI_CONTEXT" >&2; return 1; }
  cat -- "$AI_CONTEXT"
}

# Launch Codex with the user context + optional arguments
codex-context () {
  if [[ "${1:-}" == "--print" ]]; then
    codex-context-print
    return
  fi
  [[ -f "$AI_CONTEXT" ]] || { echo "Context file not found: $AI_CONTEXT" >&2; return 1; }

  local user_args="$*"
  local prompt
  prompt="$(printf 'Instructions (User Context):\n\n%s\n\nARGUMENTS: %s\n' \
    "$(_read "$AI_CONTEXT")" \
    "$user_args")"

  _codex_run_with_prompt "$prompt"
}
