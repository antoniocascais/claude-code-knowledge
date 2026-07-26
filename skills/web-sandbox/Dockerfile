# Sandboxed web-search runner: official Claude Code CLI, headless, non-root.
FROM node:22-alpine

RUN apk upgrade --no-cache \
 && apk add --no-cache ca-certificates

RUN npm install -g @anthropic-ai/claude-code

# bypassPermissions / --dangerously-skip-permissions refuse to run as root.
# The base image's `node` user is uid 1000, matching a typical host uid, so the
# read-only-mounted host credentials file (mode 0600, owned by the host user) is
# readable inside the container.
USER node
ENV HOME=/home/node
WORKDIR /home/node

# Pre-create ~/.claude owned by node so the runtime-mounted credentials file
# lands in a dir the sandbox user owns and Claude can write config alongside it.
# settings.json is defense-in-depth: even if a future edit re-adds
# --permission-mode bypassPermissions to `make search`, disableBypassPermissionsMode
# locks it out (managed deny-mode settings can't be overridden by CLI args), and the
# deny list + fail-closed defaultMode keep orchestration tools off. --model always
# overrides the baked model (User-scope setting sits below CLI args in precedence).
RUN mkdir -p /home/node/.claude \
 && printf '%s\n' \
'{' \
'  "model": "sonnet",' \
'  "permissions": {' \
'    "defaultMode": "dontAsk",' \
'    "allow": ["WebSearch", "WebFetch"],' \
'    "deny": ["Bash", "Read", "Write", "Edit", "MultiEdit", "NotebookEdit",' \
'             "Glob", "Grep", "TodoWrite", "Skill", "Workflow", "Agent", "Task",' \
'             "SendMessage", "ToolSearch", "ScheduleWakeup", "RemoteTrigger",' \
'             "CronCreate", "CronList", "CronDelete",' \
'             "TaskCreate", "TaskGet", "TaskList", "TaskUpdate", "TaskStop"],' \
'    "disableBypassPermissionsMode": "disable"' \
'  },' \
'  "disableBundledSkills": true,' \
'  "disableWorkflows": true' \
'}' > /home/node/.claude/settings.json

# Belt-and-suspenders env kills for the orchestration surface (independent of settings).
ENV CLAUDE_CODE_DISABLE_CRON=1 \
    CLAUDE_CODE_DISABLE_WORKFLOWS=1 \
    CLAUDE_CODE_DISABLE_BUNDLED_SKILLS=1 \
    CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1 \
    CLAUDE_AGENT_SDK_DISABLE_BUILTIN_AGENTS=1

# Daemon: stay alive for `docker exec` searches until `make stop`.
# tail -f (not `sleep infinity`) for busybox portability on Alpine.
CMD ["tail", "-f", "/dev/null"]
