---
name: web-sandbox
description: Runs web searches and page fetches inside an isolated Docker container instead of on the host, so browsing untrusted pages can't touch your machine and every query/URL is logged. Use when the user wants to search the web, research a topic online, fetch or read web pages, or asks for sandboxed, isolated, or contained web access. Requires a one-time build; reuses your existing host Claude login (mounted read-only). The container runs the official Claude Code CLI headless on Sonnet.
allowed-tools:
  - Bash(make:*)
  - Read
---

# web-sandbox

Web search/fetch runs inside a throwaway Docker container running the official
Claude Code CLI headless. The host never fetches untrusted pages — a prompt
injection in a fetched page is trapped in the container and destroyed on
`make stop`. Each search's full transcript (queries + fetched URLs + prompts)
is teed to `logs/`.

Run all commands from this skill's directory (where this `SKILL.md` and the
`Makefile` live). Run `make` targets directly — do not pipe them.

**Always drive this through `make`, never raw `docker`.** Raw `docker build`/
`run`/`exec`/`rm` are deny-listed in settings and can't be approved. The
Makefile wraps every docker call, so the permission matcher sees `make <target>`
(allowed) instead of the denied docker command underneath. This is by design —
`make` is the only supported entrypoint.

## One-time setup
1. `make build` — build the image.
2. Be logged in on the host (`claude` → `/login` if not). `make start` mounts
   your existing `~/.claude/.credentials.json` read-only into the container —
   no token or `.env` step, and no rebuild when the token rotates.

## Per-session lifecycle
- `make start` — boot the sandbox (runs as a daemon).
- `make status` — check if it's up.
- `make stop` — tear it down when web work is done.

## Searching
When the user wants something searched or fetched, DO NOT use the host
WebSearch/WebFetch tools. Instead run:

```
make search Q="the search query or question"
```

It prints the answer to stdout — use that in the reply. The container decides
which pages to fetch, and those fetches happen in the container, not the host.
Override the model with `MODEL=opus` if needed.

If a search reports the sandbox isn't running, run `make start` first — but if
the user hasn't opted into starting containers this session, ask before doing so.

## Audit
- `make audit` — print the search queries and fetched URLs from the latest search.
- Full transcripts live in `logs/search-<timestamp>.jsonl`.

## Notes
- WebSearch is server-side (Anthropic runs it); only WebFetch's page GETs leave
  the container. The `logs/` transcript captures both queries and fetched URLs,
  which is more complete than a network tap could be.
- The sandbox is restricted to WebSearch + WebFetch; Bash and file tools are
  denied so it can't fetch around the audit or reach anything else.
