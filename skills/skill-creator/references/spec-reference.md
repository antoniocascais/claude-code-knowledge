# Skill Spec Quick Reference

Condensed field reference for quick lookup. For full context and examples, see the main SKILL.md.

## Required Frontmatter

- `name`: lowercase, hyphens, ≤64 chars, must match directory name
- `description`: what + when (triggers), third person, ≤1024 chars

## Optional Frontmatter (base spec — portable)

- `allowed-tools`: pre-approved tools (space-delimited or YAML list) [experimental]
- `license`: e.g., "MIT"
- `compatibility`: environment requirements, ≤500 chars
- `metadata`: arbitrary key-value mapping

## Optional Frontmatter (Claude Code extensions)

- `disable-model-invocation`: `true` to prevent Claude auto-invocation (default: `false`)
- `user-invocable`: `false` to hide from slash command menu (default: `true`)
- `argument-hint`: autocomplete hint for expected arguments
- `model`: model override (e.g., `haiku`, `sonnet`, `opus`)
- `context`: `fork` for isolated sub-agent execution
- `agent`: agent type when forked (e.g., `Explore`, `Plan`, `general-purpose`)
- `hooks`: skill-specific lifecycle hooks (see `hooks.md`)

## Body Guidelines

- Keep under 500 lines
- Use progressive disclosure: split to references/ when approaching limit
- No time-sensitive information
- Consistent terminology
- Use imperative/infinitive form for instructions

## Directory Structure

```
skill-name/
├── SKILL.md           # Required entry point
├── scripts/           # Executables (run, don't read)
├── references/        # Docs loaded as needed
└── assets/            # Templates, images, fonts, static files
```

## Reference Files

- Keep one level deep from SKILL.md (no nested references)
- Files >100 lines should include a TOC at the top

## Description Budget

Skill descriptions are loaded into context at startup. Budget is 2% of context window (fallback: 16K chars). If many skills exist, some may be excluded — check with `/context`.
