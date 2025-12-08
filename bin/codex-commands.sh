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
    codex <<__CODEX_PROMPT__
$prompt
__CODEX_PROMPT__
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

# Helper: display usage for codex-security
_codex_security_usage() {
  cat >&2 <<'EOF'
Usage: codex-security [SCOPE] [OPTIONS]

SCOPE: diff | staged | all | commit:<SHA> (default: all)

OPTIONS:
  --file FILE        Output file for security report (required with --silent)
  --model MODEL      AI model to use
  --sandbox MODE     Sandbox mode (e.g., workspace-write)
  --silent           Suppress terminal output (requires --file)

Example:
  codex-security staged --file review.md --model gpt-5-codex --sandbox workspace-write --silent
  codex-security commit:abc1234 --file commit-review.md
EOF
}

# Launch security review with optional scope parameter and codex flags
codex-security () {
  local security_cmd="$AI_ROOT/commands/git/security_review.md"
  [[ -f "$security_cmd" ]] || { echo "Security review command not found: $security_cmd" >&2; return 1; }

  # Parse arguments
  local scope="all"
  local output_file=""
  local silent=false
  local codex_args=()

  # First arg is scope if it matches diff/staged/all or commit:<SHA>
  if [[ "${1:-}" =~ ^(diff|staged|all)$ ]]; then
    scope="$1"
    shift
  elif [[ "${1:-}" =~ ^commit:[0-9a-fA-F]{7,40}$ ]]; then
    # Validate commit SHA format and existence
    local commit_sha="${1#commit:}"
    if ! git rev-parse --quiet --verify "$commit_sha^{commit}" >/dev/null 2>&1; then
      echo "Error: Invalid or non-existent commit SHA: $commit_sha" >&2
      _codex_security_usage
      return 1
    fi
    scope="$1"
    shift
  fi

  # Parse remaining arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --file requires a filename argument" >&2
          _codex_security_usage
          return 1
        fi
        output_file="$2"
        shift 2
        ;;
      --model)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --model requires a model name argument" >&2
          _codex_security_usage
          return 1
        fi
        codex_args+=(--model "$2")
        shift 2
        ;;
      --sandbox)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          echo "Error: --sandbox requires a mode argument" >&2
          _codex_security_usage
          return 1
        fi
        codex_args+=(--sandbox "$2")
        shift 2
        ;;
      --silent)
        silent=true
        shift
        ;;
      *)
        # Pass through other flags to codex
        codex_args+=("$1")
        shift
        ;;
    esac
  done

  # Validate --silent requires --file
  if [[ "$silent" == true && -z "$output_file" ]]; then
    echo "Error: --silent requires --file to be set (otherwise output is lost)" >&2
    _codex_security_usage
    return 1
  fi

  # Validate output file is within repository
  if [[ -n "$output_file" ]]; then
    # Check if file is a symlink (security: prevent escaping repository via symlinks)
    if [[ -L "$output_file" ]]; then
      echo "Error: --file '$output_file' is a symlink (refusing to follow symlinks for security)" >&2
      _codex_security_usage
      return 1
    fi

    # Check if file already exists
    if [[ -f "$output_file" ]]; then
      echo "Error: --file '$output_file' already exists (refusing to overwrite)" >&2
      _codex_security_usage
      return 1
    fi

    local repo_root
    if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      # Resolve to absolute path
      local file_abs
      if [[ "$output_file" = /* ]]; then
        file_abs="$output_file"
      else
        file_abs="$PWD/$output_file"
      fi

      # Normalize path (resolve .., ., etc)
      local file_dir
      file_dir="$(cd "$(dirname "$file_abs")" 2>/dev/null && pwd)" || file_dir="$PWD"
      file_abs="$file_dir/$(basename "$file_abs")"

      # Check if outside repo
      case "$file_abs" in
        "$repo_root"/*)
          # Within repo, OK
          ;;
        *)
          echo "Error: --file '$output_file' resolves to '$file_abs'" >&2
          echo "       which is outside repository root '$repo_root'" >&2
          return 1
          ;;
      esac
    fi
  fi

  # Build prompt arguments
  local prompt_args="$scope"
  if [[ -n "$output_file" ]]; then
    prompt_args="$prompt_args. Write the final security review report to $output_file"
  fi

  # Build prompt
  local prompt
  prompt="$(printf 'Instructions (Security Review):\n\n%s\n\nARGUMENTS: %s\n' \
    "$(_read "$security_cmd")" \
    "$prompt_args")"

  # Execute with extra codex arguments in non-interactive mode
  if [[ "$silent" == true ]]; then
    # Redirect both stdout and stderr when silent mode is enabled
    if (( ${#prompt} > 100000 )); then
      codex exec "${codex_args[@]}" &> /dev/null <<__CODEX_PROMPT__
$prompt
__CODEX_PROMPT__
    else
      codex exec "${codex_args[@]}" "$prompt" &> /dev/null
    fi
  else
    if (( ${#prompt} > 100000 )); then
      codex exec "${codex_args[@]}" <<__CODEX_PROMPT__
$prompt
__CODEX_PROMPT__
    else
      codex exec "${codex_args[@]}" "$prompt"
    fi
  fi
}
