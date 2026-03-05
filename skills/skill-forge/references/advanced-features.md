# Advanced Features Reference

## Table of Contents

- [Isolated Execution](#isolated-execution)
- [String Substitution Variables](#string-substitution-variables)
- [Dynamic Context Injection](#dynamic-context-injection)
- [Enforcing Phase Gates](#enforcing-phase-gates)

## Isolated Execution

Use `context: fork` for skills that need isolated sub-agent context:

```yaml
---
name: code-analyzer
context: fork
agent: Explore
---
```

When forked:
- Skill runs in separate context with no conversation history
- Skill content becomes the subagent's task prompt
- `agent` field determines execution environment (Explore, Plan, general-purpose, or custom)
- Results returned to main context

**Important**: `context: fork` only makes sense for skills with explicit actionable tasks. If the skill is just guidelines, the subagent receives guidelines but no task.

## String Substitution Variables

Available variables for dynamic values in SKILL.md:

| Variable | Description | Example Use |
|----------|-------------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking | `/skill-name arg1 arg2` -> body receives both |
| `$ARGUMENTS[N]` / `$N` | Specific argument by 0-based index | `$0` = first arg, `$1` = second |
| `${CLAUDE_SESSION_ID}` | Current session UUID | Audit logs, session-specific temp dirs |

If `$ARGUMENTS` is not present in the content, arguments are appended as `ARGUMENTS: <value>`.

**Example -- positional arguments:**

```yaml
---
name: migrate-component
description: Migrate a component between frameworks
argument-hint: [component] [from-framework] [to-framework]
---

Migrate the $0 component from $1 to $2.
Preserve all existing behavior and tests.
```

**Example -- session isolation:**

```markdown
Store artifacts in `/tmp/claude-${CLAUDE_SESSION_ID}/` for session isolation.
```

## Dynamic Context Injection

The exclamation-backtick syntax runs shell commands BEFORE skill content is sent to Claude. Output replaces the placeholder -- this is preprocessing, not something Claude executes.

Use cases: injecting live git state, PR data, environment info, API responses, or config before Claude processes the skill content.

## Enforcing Phase Gates

Claude tends to rush ahead. To force hard stops between phases, use `AskUserQuestion` as a gate:

```markdown
## Phase 1: Gather Input

**STOP. Use AskUserQuestion before proceeding.**

[phase instructions...]

**Do NOT proceed to Phase 2 until user responds.**

## Phase 2: Confirm Understanding

**STOP. Use AskUserQuestion to confirm before execution.**

[present what you understood, then ask confirmation...]

**Do NOT proceed to Phase 3 until user confirms.**
```

Key elements:
- Bold **STOP** directive at phase start
- Explicit instruction to use `AskUserQuestion`
- Clear "do NOT proceed until..." at phase end
