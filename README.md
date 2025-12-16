# claude-code-knowledge

A comprehensive knowledge management system for Claude Code with intelligent note-taking, knowledge base curation, and automated maintenance workflows.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/antoniocascais/claude-code-knowledge.git
cd claude-code-knowledge
```

### 2. Run the Setup Script

The setup script will generate your personal configuration files from the `.example` templates directly inside the Claude directory you specify:

```bash
./bin/setup.sh /path/to/your/claude/folder
```

**Examples:**
```bash
# Standard location
./bin/setup.sh /home/user/Documents/claude

# Custom location
./bin/setup.sh ~/my-claude-setup

# Any arbitrary path
./bin/setup.sh /my/special/path/claude
```

**What it does:**
- Reads all `.example` template files in the repository
- Normalizes the destination path so relative and `~` inputs work everywhere
- Replaces `/path/to/claude` with your provided path
- Replaces `$HOME/.claude` with your actual home directory
- Creates/updates the following files inside your Claude directory:
  - `<CLAUDE_PATH>/CLAUDE.md` - Main configuration
  - `<CLAUDE_PATH>/commands/review-notes.md` - Task notes maintenance command
  - `<CLAUDE_PATH>/commands/review-knowledge.md` - Knowledge base review command
  - `<CLAUDE_PATH>/commands/user/context.md` - Context loading command
  - `<CLAUDE_PATH>/skills/note-taking/SKILL.md` - Note-taking and knowledge management skill
- Copies every file from the repository's `agents/` directory into `<CLAUDE_PATH>/agents/`
- Ensures the required subfolders exist before writing each file
- Prompts for confirmation before overwriting any existing destination file
- Offers to create symlinks into `~/.claude` (or another directory you choose), asking before replacing anything already there

### 3. Create Required Directories

The setup script does not create your working data directories (only the configuration files). Create them once:

```bash
# Replace with your path from step 2
mkdir -p /path/to/your/claude/folder/tasks_notes
mkdir -p /path/to/your/claude/folder/knowledge_base
```

### 4. Configure Claude Code

If you opted into symlink creation during setup, this step is already complete. Otherwise, link your generated files into Claude Code manually:

```bash
# Create symlinks from ~/.claude to your Claude folder
ln -s /path/to/your/claude/folder/CLAUDE.md ~/.claude/CLAUDE.md
ln -s /path/to/your/claude/folder/agents ~/.claude/agents
ln -s /path/to/your/claude/folder/commands ~/.claude/commands
ln -s /path/to/your/claude/folder/skills ~/.claude/skills
```

**Example:**
```bash
# If you ran setup with /home/user/Documents/claude
ln -s /home/user/Documents/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -s /home/user/Documents/claude/agents ~/.claude/agents
ln -s /home/user/Documents/claude/commands ~/.claude/commands
ln -s /home/user/Documents/claude/skills ~/.claude/skills
```

**Benefits of symlinks:**
- Changes to the repository are immediately available to Claude Code
- Easy to track changes with git
- No need to copy files manually after updates

Refer to [Claude Code documentation](https://docs.claude.com/en/docs/claude-code/overview) for more information on custom commands and agents.
