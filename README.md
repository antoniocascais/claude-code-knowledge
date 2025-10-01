# claude-code-knowledge

A comprehensive knowledge management system for Claude Code with intelligent note-taking, knowledge base curation, and automated maintenance workflows.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/antoniocascais/claude-code-knowledge.git
cd claude-code-knowledge
```

### 2. Run the Setup Script

The setup script will create your personal configuration files from the `.example` templates:

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
- Reads all `.example` template files
- Replaces `/path/to/claude` with your provided path
- Replaces `$HOME/.claude` with your actual home directory
- Creates the actual configuration files:
  - `CLAUDE.md` - Main note-taking system configuration
  - `commands/review-notes.md` - Task notes maintenance command
  - `commands/review-knowledge.md` - Knowledge base review command
  - `commands/user/context.md` - Context loading command
- Prompts for confirmation before overwriting existing files

### 3. Create Required Directories

```bash
# Replace with your path from step 2
mkdir -p /path/to/your/claude/folder/tasks_notes
mkdir -p /path/to/your/claude/folder/knowledge_base
```

### 4. Configure Claude Code

The setup script creates files that need to be imported by Claude Code. The recommended approach is to use symlinks:

```bash
# Create symlinks from ~/.claude to your repository
ln -s /path/to/claude-code-knowledge/CLAUDE.md ~/.claude/CLAUDE.md
ln -s /path/to/claude-code-knowledge/agents ~/.claude/agents
ln -s /path/to/claude-code-knowledge/commands ~/.claude/commands
```

**Example:**
```bash
# If you cloned to ~/Documents/claude-code-knowledge
ln -s ~/Documents/claude-code-knowledge/CLAUDE.md ~/.claude/CLAUDE.md
ln -s ~/Documents/claude-code-knowledge/agents ~/.claude/agents
ln -s ~/Documents/claude-code-knowledge/commands ~/.claude/commands
```

**Benefits of symlinks:**
- Changes to the repository are immediately available to Claude Code
- Easy to track changes with git
- No need to copy files manually after updates

Refer to [Claude Code documentation](https://docs.claude.com/en/docs/claude-code/overview) for more information on custom commands and agents.
