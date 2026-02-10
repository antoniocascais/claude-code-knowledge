#!/bin/bash
set -e

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Block direct docker build/run/compose commands
if [[ "$command" =~ ^[[:space:]]*(docker[[:space:]]+(build|run|compose|exec|stop|start|rm|pull|push)|docker-compose) ]]; then
  echo "blocked: don't use docker directly — use 'make build', 'make run', etc." >&2
  exit 2
fi

# Block direct test runner commands
if [[ "$command" =~ ^[[:space:]]*(pytest|python[[:space:]]+-m[[:space:]]+pytest|npm[[:space:]]+test|npx[[:space:]]+vitest) ]]; then
  echo "blocked: don't run tests directly — use 'make test', 'make test-unit', etc." >&2
  exit 2
fi

# Block npm run/npx for build tasks
if [[ "$command" =~ ^[[:space:]]*(npm[[:space:]]+run|npx)[[:space:]]+(build|dev|start|test) ]]; then
  echo "blocked: don't use npm/npx directly — use Makefile targets instead" >&2
  exit 2
fi

exit 0
