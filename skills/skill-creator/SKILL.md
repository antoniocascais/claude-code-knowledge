---
name: skill-creator
description: Creates new Claude Code skills with proper structure and best practices. Use when user wants to create a skill, update an existing skill, add a new command, scaffold a workflow, define skill hooks, or asks "how do I make a skill".
allowed-tools: Read Write Glob Grep AskUserQuestion
argument-hint: [use-case-description]
---

# Skill Creator

Creates Claude Code skills following official best practices.

## Core Principles

### Only Add What Claude Doesn't Have
Claude is already smart. Only include domain-specific context it lacks:
- API quirks, library gotchas, edge cases
- Your org's conventions and patterns
- Domain knowledge not in training data

### Degrees of Freedom
Match instruction specificity to task fragility:

| Level | When | Example |
|-------|------|---------|
| **High freedom** | Multiple valid approaches | Code review (heuristics, not rigid steps) |
| **Medium freedom** | Preferred pattern exists | Reports (customizable scripts) |
| **Low freedom** | Fragile operations | DB migrations (exact commands, no deviation) |

### Progressive Disclosure
Context loads in 3 levels:
1. **Metadata** (~100 tokens) - name + description, always in context
2. **SKILL.md body** (<5000 tokens recommended) - loaded when skill triggers
3. **Resources** (unlimited) - scripts/, references/, assets/ loaded as needed

## Workflow

### Step 1: Gather Requirements

Use AskUserQuestion to collect:

1. **Skill name** - lowercase, hyphens only, ≤64 chars
   - Good: `pdf-processor`, `code-reviewer`, `deploy-helper`
   - Bad: `PDF_Processor`, `my cool skill`

2. **Description** - what it does + when to use it (≤1024 chars)
   - Third person ("Processes...", "Generates...")
   - Include ALL trigger keywords in description (primary discovery mechanism)
   - Example: "Processes PDF files to extract text and tables. Use when working with PDFs, extracting document content, or converting PDF to markdown."

3. **Allowed tools** (optional) - restrict capabilities
   - Space-delimited: `Read Glob Grep`
   - YAML list (cleaner for many tools):
     ```yaml
     allowed-tools:
       - Read
       - Write
       - Bash(git:*)
     ```
   - Bash patterns: `Bash(git:*)`, `Bash(git diff:*)`
   - Unrestricted: omit field entirely

4. **Complexity** - determines resource structure
   - Simple: SKILL.md only
   - Medium: + references/ for docs
   - Complex: + scripts/ for automation, assets/ for templates and static files

5. **Execution context** (optional)
   - Needs isolated context? → `context: fork`
   - Specific agent type? → `agent: Explore` / `Plan`
   - Model override? → `model: haiku` / `sonnet` / `opus`

6. **Invocation control** (optional)
   - User-only trigger (side effects like deploy, commit)? → `disable-model-invocation: true`
   - Claude-only (background knowledge, not actionable as command)? → `user-invocable: false`
   - See [Invocation Control](#invocation-control) for the interaction matrix

7. **Arguments** (optional)
   - Does the skill accept arguments? → use `$ARGUMENTS` in body
   - Autocomplete hint? → `argument-hint: [issue-number]`

8. **Hooks** (optional) - lifecycle automation
   - Validation after writes?
   - Logging before tool use?
   - See `references/hooks.md` for patterns

### Step 2: Validate Name

```
- Only lowercase letters, numbers, hyphens
- No leading/trailing hyphens, no consecutive hyphens
- ≤64 characters
- Not reserved: anthropic, claude
- Must match parent directory name
```

### Step 3: Generate Skill

**Default location**: `~/.claude/skills/{skill-name}/`

**Note**: `.claude/commands/` files still work and support the same frontmatter, but skills are preferred. If a skill and command share the same name, the skill takes precedence.

Create `SKILL.md` with:

```yaml
---
name: {skill-name}
description: {description}
allowed-tools: {tools}                # optional: space-delimited or YAML list
context: fork                         # optional: isolated execution
agent: {agent-type}                   # optional: Explore, Plan, general-purpose
model: {model}                        # optional: haiku, sonnet, opus
disable-model-invocation: true        # optional: user-only invocation
user-invocable: false                 # optional: Claude-only invocation
argument-hint: {hint}                 # optional: autocomplete hint
hooks: {}                             # optional: see references/hooks.md
---
```

Generate skill body matching the degree of freedom needed. Use imperative/infinitive form for instructions.

### Step 4: Post-Creation

```
✅ Skill created at: ~/.claude/skills/{skill-name}/
✅ Skill is immediately available (hot-reload enabled)
```

### Step 5: Iterate (User)

Inform user of the iteration loop:
1. Test skill on real tasks
2. Note where Claude struggles or produces poor output
3. Return to refine SKILL.md or add references/scripts
4. Repeat until quality is consistent

## Invocation Control

Two fields control who can invoke a skill and how it loads into context:

| Frontmatter | User can invoke | Claude can invoke | Context loading |
|-------------|----------------|-------------------|-----------------|
| (default) | Yes | Yes | Description always in context, body loads when invoked |
| `disable-model-invocation: true` | Yes | No | Description NOT in context, body loads when user invokes |
| `user-invocable: false` | No | Yes | Description always in context, body loads when invoked |

**When to use `disable-model-invocation: true`:**
- Skills with side effects: deploy, commit, send messages, delete resources
- Skills where timing matters: user wants to control when it runs

**When to use `user-invocable: false`:**
- Background knowledge that isn't actionable as a command
- Context skills like `legacy-system-context` — Claude should know it, but `/legacy-system-context` isn't a meaningful user action

## Workflow Patterns

**Sequential**: Step 1 → 2 → 3 (most skills)
**Conditional**: Decision trees based on input type or user choice (see `webapp-testing/`)
**Multi-phase**: Plan → validate → execute → verify (for destructive operations)

### Enforcing Phase Gates

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

## Resource Types

| Type | Purpose | Context Loading |
|------|---------|-----------------|
| `scripts/` | Executables for deterministic tasks | Run as black-box, don't read into context |
| `references/` | Documentation, API specs | Loaded on-demand when needed |
| `assets/` | Templates, images, fonts, static files | Used in output, not loaded into context |

## Anti-Patterns

- No README.md, CHANGELOG.md, INSTALLATION_GUIDE.md — only include what Claude needs to execute
- No "When to Use This Skill" in body — triggers come from description; body loads AFTER triggering
- No duplicated info between SKILL.md and references/ — pick one location
- No deeply nested references — keep one level deep from SKILL.md
- No time-sensitive information (dates, version-specific instructions that will rot)
- No hardcoded absolute paths

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

## Skill Hooks

Skills can define lifecycle hooks scoped to their execution. See `references/hooks.md` for full documentation.

Quick example:
```yaml
hooks:
  PostToolUse:
    - matcher: Write
      hooks:
        - type: command
          command: "jq -r '.tool_input.file_path' | xargs -I{} ./validate.sh \"{}\""
```

## String Substitution Variables

Available variables for dynamic values in SKILL.md:

| Variable | Description | Example Use |
|----------|-------------|-------------|
| `$ARGUMENTS` | All arguments passed when invoking | `/skill-name arg1 arg2` → body receives both |
| `$ARGUMENTS[N]` / `$N` | Specific argument by 0-based index | `$0` = first arg, `$1` = second |
| `${CLAUDE_SESSION_ID}` | Current session UUID | Audit logs, session-specific temp dirs |

If `$ARGUMENTS` is not present in the content, arguments are appended as `ARGUMENTS: <value>`.

**Example — positional arguments:**

```yaml
---
name: migrate-component
description: Migrate a component between frameworks
argument-hint: [component] [from-framework] [to-framework]
---

Migrate the $0 component from $1 to $2.
Preserve all existing behavior and tests.
```

**Example — session isolation:**

```markdown
Store artifacts in `/tmp/claude-${CLAUDE_SESSION_ID}/` for session isolation.
```

## Dynamic Context Injection

The exclamation-backtick syntax runs shell commands BEFORE skill content is sent to Claude. Output replaces the placeholder — this is preprocessing, not something Claude executes.

Use cases: injecting live git state, PR data, environment info, API responses, or config before Claude processes the skill content.

## Quick Reference

For the condensed field spec, directory structure, and description budget, see `references/spec-reference.md`.

## Example Output

A generated simple skill should look like this:

```yaml
---
name: test-notification-sender
description: Sends test notifications to configured channels. Use when testing alerting pipelines, verifying webhook delivery, or debugging notification routing.
allowed-tools: Read Bash(curl:*)
disable-model-invocation: true
---
```

```markdown
# Test Notification Sender

Send test notifications to verify alerting pipelines.

## Instructions

### Step 1: Identify Target
Use AskUserQuestion to confirm:
- Channel type (Slack, PagerDuty, email, webhook)
- Environment (staging/production)

### Step 2: Send Test
Run the appropriate curl command for the channel type.
Include a timestamp and session identifier in the payload.

### Step 3: Verify Delivery
Confirm the notification was received. If it fails:
- Check webhook URL is reachable
- Verify auth token is valid
- Check channel/routing configuration

## Common Issues

### Slack returns 403
Token scope missing. Needs `chat:write` and `incoming-webhook`.

### PagerDuty dedup
Test events with same dedup_key merge. Use unique keys per test.
```

Note: `disable-model-invocation: true` because this skill has side effects (sends real notifications).

For more examples, clone the official repo: `git clone https://github.com/anthropics/skills.git /tmp/claude-skills-examples`

## Troubleshooting

### Skill name collision
Before creating, check if a skill already exists: `ls ~/.claude/skills/{name}/`. If it does, ask the user whether to update or choose a different name.

### YAML parse errors
Common causes:
- Description contains unquoted colons — wrap in quotes: `description: "Deploy helper: automates releases"`
- Missing `---` delimiters (need both opening and closing)
- Indentation mismatch in YAML lists

### Skill not triggering after creation
The description is the primary discovery mechanism. Check:
- Does it include trigger phrases users would actually say?
- Is it too generic? ("Helps with projects" won't trigger)
- Is it too narrow? Missing synonyms or paraphrases

## Best Practices Checklist

Before finalizing:

- [ ] Description is third person with ALL trigger keywords
- [ ] Description includes both what + when (trigger scenarios)
- [ ] SKILL.md under 500 lines (split to references/ if needed)
- [ ] Degree of freedom matches task fragility
- [ ] No hardcoded paths or time-sensitive info
- [ ] No "When to Use" section in body (triggers belong in description)
- [ ] Consistent terminology throughout
- [ ] Reference files >100 lines have TOC
- [ ] References one level deep (no nesting)
- [ ] Scripts are black-box (documented inputs/outputs, not read into context)
- [ ] Skills with side effects use `disable-model-invocation: true`
