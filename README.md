# claude-code-toolkit

My Claude Code configs — grab what you need.

## What's Inside

### Skills
| Skill | Description |
|-------|-------------|
| `git-commit` | Analyzes staged changes, proposes commit structure (single/multiple), generates messages |
| `skill-forge` | Scaffolds new skills following official spec |
| `pr-review` | Code review for diffs, commits, branches, PRs |
| `note-taking` | Task notes + knowledge base management (includes daily log promotion) |
| `daily-log` | Per-project daily session log — mid-level summaries with notes.md promotion flags |
| `planner` | Task capture and organization |
| `codemap` | Generate codebase maps with architecture diagrams (WIP - still testing) |
| `workflow-review` | Reviews CC sessions via [BM25 cross-session search](https://eric-tramel.github.io/blog/2026-02-07-searchable-agent-memory/) and proposes workflow improvements (CLAUDE.md updates, new skills, underused features) |
| `codex` | AI peer review via OpenAI Codex CLI — Claude consults Codex for code review, architecture decisions, and trade-off validation |
| `ctask` | Local task tracker — manages tasks, dependencies, comments, labels via SQLite |
| `quiz` | Conversation quiz generator — tests understanding of what was discussed |
| `c7` | Fetches up-to-date library docs from Context7, saves to /tmp/context7/ |
| `voice-mode` | TTS transport layer using [Pocket TTS](https://github.com/kyutai-labs/pocket-tts) — speaks all responses, composable with other skills |
| `clarice` | Mock interview coach — runs realistic sessions (behavioral, technical, system design, challenge walkthrough) with weighted scoring, critical-miss detection, and detailed gap reports |

### Commands
| Command | Description |
|---------|-------------|
| `git/security_review` | Security review of repository code |
| `myskill` | Skill discovery and execution |
| `review-notes` | Task notes maintenance |
| `review-knowledge` | Knowledge base review |
| `user/context` | Load context from topic folders |
| `pr-respond` | Responds to PR review comments from screenshots |

### Agents
| Agent | Description |
|-------|-------------|
| `knowledge-base-curator` | Enhances knowledge base entries |
| `task-notes-cleaner` | Cleans outdated context from task notes |

### Hooks & Utilities
- `bin/claude-block-sensitive-bash.sh` — Block sensitive bash commands
- `bin/claude-block-sensitive-files.sh` — Block sensitive file access
- `bin/claude_code_statusline.sh` — Statusline integration

### Config Template
`CLAUDE.md.example` — Personal instructions template with:
- ast-grep examples for code navigation
- Git commit style guidelines
- Code comment philosophy
- Communication protocols

## Setup

### 1. Clone

```bash
git clone https://github.com/antoniocascais/claude-code-toolkit.git
cd claude-code-toolkit
```

### 2. Run Setup

```bash
./bin/setup.sh --notes-folder /path/to/your/notes/folder
```

This processes `.example` templates, replacing paths with your config:

```bash
# Examples
./bin/setup.sh --notes-folder ~/Documents/claude
./bin/setup.sh --notes-folder ~/Documents/claude --config-path ~/my-claude-config
```

**Creates:**
- `<CONFIG_PATH>/CLAUDE.md`
- `<CONFIG_PATH>/commands/` — review-notes, review-knowledge, context
- `<CONFIG_PATH>/skills/` — daily-log, note-taking, planner
- `<CONFIG_PATH>/agents/` — all agents

**Note:** The note-taking skill's `UserPromptSubmit` hook hardcodes `$HOME/.claude/` as the script path. If using a custom `--config-path`, update the hook command in `<CONFIG_PATH>/skills/note-taking/SKILL.md` manually.

### 3. Create Data Directories

```bash
mkdir -p /path/to/your/notes/folder/tasks_notes
mkdir -p /path/to/your/notes/folder/knowledge_base
```

### 4. Link to Claude Code (if needed)

If you used a custom `--config-path`:

```bash
ln -s /path/to/your/config/folder/CLAUDE.md ~/.claude/CLAUDE.md
ln -s /path/to/your/config/folder/agents ~/.claude/agents
ln -s /path/to/your/config/folder/commands ~/.claude/commands
ln -s /path/to/your/config/folder/skills ~/.claude/skills
```

## Skill-Specific Setup

### codex (AI Peer Review)

Uses [OpenAI Codex CLI](https://github.com/openai/codex) as a second opinion for code review and technical decisions. Claude consults Codex, they can disagree and argue (up to 3 rounds), then you get a summary of what they agreed/disagreed on.

**Invocation:** `/codex` or `/codex-review`

**Auto-trigger (WIP):** Skill is designed to auto-consult Codex before presenting alternatives or completing significant work, but this isn't reliable yet. Use explicit invocation for now.

**Setup:**
```bash
npm install -g @openai/codex
```

**Example output:**
```
After discussion, updated findings:

| Issue                       | Status                                                | Action             |
|-----------------------------|-------------------------------------------------------|--------------------|
| jq parse error on assignment| Downgraded to low - email-triage.sh validates JSON first | Optional hardening |
| ollama pull retries         | Valid - need until clause                             | Fix required       |
| test-json-parse invalid JSON| False positive - doesn't exit                         | No fix needed      |
| // empty drops false        | NEW BUG - test fails at line 42                       | Fix required       |

Codex found a real bug: jq -r ".$field // empty" treats false as falsy and returns empty string.
```

### ctask (Local Task Tracker)

Requires a `ctask` bash wrapper script on your `$PATH`. The wrapper is a thin CLI over a local SQLite database — it handles task CRUD, comments, dependencies, and labels.

**Setup:**
```bash
ln -s "$(pwd)/skills/ctask/bin/ctask" ~/bin/ctask   # or anywhere on $PATH
```

Override the database location with `CTASK_DB` env var (default: `~/Documents/claude/tasks.db`). Database auto-initializes on first use.

**Requirements:** `sqlite3`

### voice-mode (TTS Responses)

Speaks all Claude responses aloud using [Pocket TTS](https://github.com/kyutai-labs/pocket-tts) running in Docker.

**Invocation:** `/voice-mode` or `/voice-mode jean` (to pick a voice)

**Setup:**
```bash
# 1. Clone and start Pocket TTS
git clone https://github.com/kyutai-labs/pocket-tts.git
cd pocket-tts && docker compose up -d

# 2. Install mpv (audio playback)
# Arch/Manjaro: pacman -S mpv
# Ubuntu/Debian: apt install mpv
# macOS: brew install mpv
```

**Environment variables (all optional):**
- `POCKET_TTS_PORT` — server port
- `POCKET_TTS_VOICE` — voice name
- `POCKET_TTS_SPEED` — playback speed

**Available voices:** alba, marius, javert, jean, fantine, cosette, eponine, azelma

**Requirements:** Docker, mpv, curl

### clarice (Mock Interview Prep)

Simulates realistic mock interviews tailored to your CV and target role. Supports behavioral, technical, system design, and challenge walkthrough formats. Generates a scored report with gap analysis and actionable prep advice.

**Invocation:** `/clarice`

**Usage:** Place files in the working directory before invoking:
- **CV/Resume** (required): filename starting with `cv` or `resume` (e.g., `cv.pdf`, `resume-2026.md`)
- **Job Description** (required): filename starting with `jd` or `job` (e.g., `jd.md`, `job-senior-sre.txt`)
- **Context** (optional): `*context*.md` — company notes, interview stage, focus areas, known gaps

Supported formats: `.md`, `.txt`, `.pdf`, `.docx`

**Output:** Two files per session — `clarice-{SESSION_ID}-context.md` (confirmed interview context) and `clarice-{SESSION_ID}-report.md` (scored assessment with strengths, concerns, and prep checklist). Tracks progress across sessions.

### workflow-review

No setup required. Uses BM25 search over `~/.claude/projects/` transcripts — runs on-demand via `/workflow-review`.

**Dependencies:** `uv` (for inline script deps)

## License

AGPL-3.0
