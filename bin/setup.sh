#!/bin/bash
set -e

# Claude Code Knowledge Setup Script
# Initializes personal configuration files from .example templates

if [ $# -eq 0 ]; then
    echo "Error: Please provide the path to your claude folder"
    echo "Usage: $0 /path/to/your/claude/folder"
    echo ""
    echo "Example:"
    echo "  $0 /home/user/Documents/claude"
    echo "  $0 ~/my-claude-setup"
    exit 1
fi

CLAUDE_PATH="$1"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Expand $HOME for .claude path replacement
HOME_EXPANDED="$HOME"

echo "Setting up Claude Code configuration..."
echo "Claude folder: $CLAUDE_PATH"
echo "Repository root: $REPO_ROOT"
echo ""

FILES=(
    "CLAUDE.md"
    "commands/review-notes.md"
    "commands/review-knowledge.md"
    "commands/user/context.md"
)

for file in "${FILES[@]}"; do
    example_file="${file}.example"

    if [ ! -f "$example_file" ]; then
        echo "Warning: $example_file not found, skipping..."
        continue
    fi

    # Check if target file already exists
    if [ -f "$file" ]; then
        read -p "File $file already exists. Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping $file"
            continue
        fi
    fi

    # Create target file with replacements
    sed -e "s|/path/to/claude|$CLAUDE_PATH|g" \
        -e "s|\$HOME/.claude|$HOME_EXPANDED/.claude|g" \
        "$example_file" > "$file"

    echo "✓ Created $file"
done

echo ""
echo "Setup complete! Your configuration files are ready."
echo ""
echo "Next steps:"
echo "1. Review the generated files to ensure paths are correct"
echo "2. Create your task notes directory: mkdir -p $CLAUDE_PATH/tasks_notes"
echo "3. Create your knowledge base directory: mkdir -p $CLAUDE_PATH/knowledge_base"
