# Example: Medium Skill (with references/)

A skill with reference docs, allowed-tools, and arguments.

## Directory Structure

```
api-report-generator/
├── SKILL.md
└── references/
    └── api-patterns.md
```

## Generated SKILL.md

```yaml
---
name: api-report-generator
description: Generates API health reports from endpoint monitoring data. Use when creating API status reports, reviewing endpoint performance, or producing SLA compliance documentation.
allowed-tools: Read Write Glob Grep Bash(curl:*)
argument-hint: [output-format]
---
```

```markdown
# API Report Generator

Generate API health reports from endpoint monitoring data.

## Instructions

### Step 1: Collect Data
Gather endpoint status from the monitoring API.
Use `$ARGUMENTS` for output format (default: markdown). Supported: markdown, html, csv.

### Step 2: Analyze
For each endpoint, calculate:
- Uptime percentage (last 30 days)
- Average response time (p50, p95, p99)
- Error rate by status code

Consult `references/api-patterns.md` for:
- Rate limiting guidance when querying monitoring API
- Pagination patterns for large endpoint lists
- Error code interpretation

### Step 3: Generate Report
Write the report to `./api-report-{date}.{format}`.
Include:
- Executive summary (3-5 lines)
- Per-endpoint detail table
- Flagged endpoints (uptime < 99.9% or p95 > 500ms)

### Step 4: Verify
Confirm the report file was written and summarize findings to the user.

## Common Issues

### Monitoring API rate limited
Back off and retry with exponential delay. See `references/api-patterns.md` for limits.

### Missing endpoints
Some endpoints may not have 30 days of data. Note the gap in the report rather than failing.
```

## Why this works

- `argument-hint` enables quick invocation: `/api-report-generator html`
- `references/api-patterns.md` keeps API-specific docs out of the body (progressive disclosure)
- Explicit reference to reference file with bullet list of what it contains
- Error handling covers realistic failure modes
- Output format is parameterized via `$ARGUMENTS`
