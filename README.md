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
| `workflow-review` | Reviews CC sessions via [BM25 cross-session search](https://eric-tramel.github.io/blog/2026-02-07-searchable-agent-memory/) and proposes workflow improvements (CLAUDE.md updates, new skills, underused features) |
| `ctask` | Local task tracker — manages tasks, dependencies, comments, labels via SQLite |
| `quiz` | Conversation quiz generator — tests understanding of what was discussed |
| `stop-slop` | Removes AI writing tells from prose — vendored from [hardikpandya/stop-slop](https://github.com/hardikpandya/stop-slop) (MIT) |
| `clarice` | Mock interview coach — runs realistic sessions (behavioral, technical, system design, challenge walkthrough) with weighted scoring, critical-miss detection, and detailed gap reports |
| `fable` | Dispatches a task to the `fable` subagent with a prompt shaped the way Claude Fable 5 wants to be prompted |
| `prompt-fable` | Drafts a copy-pasteable Fable 5 prompt without dispatching anything — for use elsewhere (web app, another session) |
| `test-quality` | Unit test generation and review — boundary/error-path coverage, mutation testing, weak-assertion detection |
| `latex-presentation` | LaTeX Beamer decks — theme selection, font pairing, TikZ diagrams, overlays (user-invoked only) |

### Commands
| Command | Description |
|---------|-------------|
| `git/security_review` | Security review of repository code |
| `myskill` | Skill discovery and execution |
| `review-notes` | Task notes maintenance |
| `review-knowledge` | Knowledge base review |
| `user/context` | Load context from topic folders |
| `pr-respond` | Responds to PR review comments from screenshots |
| `foss-app-review` | Security review of the diff between two versions of a FOSS Android app |

### Agents
| Agent | Description |
|-------|-------------|
| `knowledge-base-curator` | Enhances knowledge base entries |
| `task-notes-cleaner` | Cleans outdated context from task notes |
| `fable` | Claude Fable 5 agent for the hardest, longest-horizon work — multi-hour implementations, deep debugging, whole-repo review |

### Output Styles
- `output-styles/kitty-safe.md` — Drops blockquotes and italics, which render unreadably in Kitty

### Hooks & Utilities

`PreToolUse` guards (wire up in `settings.json`):
- `bin/claude-block-sensitive-files.sh` — Blocks Read/Edit/Write/Glob/Grep on secret-looking paths
- `bin/claude-block-sensitive-bash.sh` — Blocks bash commands touching secret files (suffix-anchored name patterns + gitignore sweep with a benign-name allowlist)
- `bin/claude-validate-git.sh` — Catches unsafe git operations (e.g. committing straight to `main`)
- `bin/claude-validate-build.sh` — Validates build/test invocations
- `bin/claude-block-absolute-paths.sh` — Forces relative paths so `Bash(git log:*)`-style permission rules stay grantable

Statusline & telemetry:
- `bin/claude_code_statusline.sh` — Statusline integration
- `bin/claude_code_capture_usage.py` — Token usage capture for the statusline
- `bin/claude_code_capture_context.py` — Context-window capture for the statusline

### Config Template
`CLAUDE.md.example` — Personal instructions template with:
- Code navigation tool preferences
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

**Renders** these `.example` templates into `<CONFIG_PATH>`, substituting your notes path:
- `CLAUDE.md`
- `commands/` — review-notes, review-knowledge, user/context
- `skills/` — daily-log, note-taking (incl. `scripts/scan-daily-logs.sh`), planner

Everything else — the remaining skills, commands, and agents — is used straight from the repo checkout. Agents are also synced into `<CONFIG_PATH>/agents/`.

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
ln -s /path/to/your/config/folder/output-styles ~/.claude/output-styles
ln -s /path/to/your/config/folder/bin/claude_code_statusline.sh ~/.claude/statusline.sh
ln -s /path/to/your/config/folder/bin/claude_code_capture_usage.py ~/.claude/claude_code_capture_usage.py
```

`setup.sh` offers to create these symlinks for you. It also offers to link `settings.json` — worth skipping if your config folder is a git repo you push, since every permission tweak then becomes a commit.

## Skill-Specific Setup

### ctask (Local Task Tracker)

Requires a `ctask` bash wrapper script on your `$PATH`. The wrapper is a thin CLI over a local SQLite database — it handles task CRUD, comments, dependencies, and labels.

**Setup:**
```bash
ln -s "$(pwd)/skills/ctask/bin/ctask" ~/bin/ctask   # or anywhere on $PATH
```

Override the database location with `CTASK_DB` env var (default: `~/Documents/claude/tasks.db`). Database auto-initializes on first use.

**Requirements:** `sqlite3`

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
