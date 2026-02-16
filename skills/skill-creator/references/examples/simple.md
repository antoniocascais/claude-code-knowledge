# Example: Simple Skill (SKILL.md only)

A skill with side effects, restricted tools, no resources.

## Generated SKILL.md

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

## Why this works

- `disable-model-invocation: true` — sends real notifications, user controls timing
- `allowed-tools` restricted to `Read` + `Bash(curl:*)` — can't write files or run arbitrary commands
- Troubleshooting included — common failure modes addressed inline
- Description includes trigger phrases: "testing alerting", "webhook delivery", "notification routing"
