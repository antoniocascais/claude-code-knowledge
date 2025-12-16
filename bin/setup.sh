#!/bin/bash
set -e

resolve_path() {
    local input="$1"
    if [ -z "$input" ]; then
        return 1
    fi

    local path
    case "$input" in
        /*)
            path="$input"
            ;;
        ~*)
            if [ -n "$HOME" ]; then
                path="${input/#\~/$HOME}"
            else
                echo "Error: HOME is not set" >&2
                return 1
            fi
            ;;
        *)
            path="$(pwd)/$input"
            ;;
    esac

    local IFS='/'
    read -r -a parts <<< "$path"

    local -a stack=()
    local part
    for part in "${parts[@]}"; do
        case "$part" in
            ""|"." )
                continue
                ;;
            ".." )
                if [ ${#stack[@]} -gt 0 ]; then
                    unset "stack[${#stack[@]}-1]"
                fi
                ;;
            * )
                stack+=("$part")
                ;;
        esac
    done

    local resolved=""
    for part in "${stack[@]}"; do
        resolved="$resolved/$part"
    done

    if [ -z "$resolved" ]; then
        resolved="/"
    fi

    printf '%s\n' "$resolved"
}

prompt_yes_no() {
    local message="$1"
    local default_choice="$2"
    if [ -z "$default_choice" ]; then
        default_choice="n"
    fi
    local prompt_suffix=" (y/n, default: $default_choice)"

    while true; do
        local response
        if ! read -r -p "$message$prompt_suffix " response < /dev/tty; then
            echo
            response="$default_choice"
        else
            echo
        fi

        if [ -z "$response" ]; then
            response="$default_choice"
        fi

        case "$response" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

setup_symlinks() {
    echo ""
    if ! prompt_yes_no "Would you like to create symlinks from your Claude folder into ~/.claude now?" "n"; then
        echo "Skipping symlink creation."
        return
    fi

    local default_target="$HOME/.claude"
    read -p "Enter the directory where symlinks should be created [$default_target]: " target_input
    echo
    if [ -z "$target_input" ]; then
        target_input="$default_target"
    fi

    local target_dir
    if ! target_dir="$(resolve_path "$target_input")"; then
        echo "Error: Unable to resolve symlink target directory: $target_input"
        return
    fi

    echo "Symlinks will be created in: $target_dir"
    if [ ! -d "$target_dir" ]; then
        if prompt_yes_no "Directory $target_dir does not exist. Create it?" "y"; then
            mkdir -p "$target_dir"
            echo "Created $target_dir"
        else
            echo "Cannot proceed without the target directory. Skipping symlink creation."
            return
        fi
    fi

    create_link() {
        local source="$1"
        local destination="$2"

        if [ ! -e "$source" ] && [ ! -L "$source" ]; then
            echo "Warning: Source $source not found. Skipping."
            return
        fi

        if [ -e "$destination" ] || [ -L "$destination" ]; then
            if prompt_yes_no "Destination $destination exists. Replace it?" "n"; then
                rm -rf "$destination"
                echo "Removed existing $destination"
            else
                echo "Leaving existing $destination in place."
                return
            fi
        fi

        mkdir -p "$(dirname "$destination")"
        ln -s "$source" "$destination"
        echo "↪ Linked $destination -> $source"
    }

    create_link "$CLAUDE_PATH/CLAUDE.md" "$target_dir/CLAUDE.md"
    create_link "$CLAUDE_PATH/commands" "$target_dir/commands"
    create_link "$CLAUDE_PATH/agents" "$target_dir/agents"
    create_link "$CLAUDE_PATH/skills" "$target_dir/skills"

    echo ""
    echo "Symlink setup complete!"
}

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

CLAUDE_PATH_INPUT="$1"
# Resolve to absolute path using portable shell logic
if ! CLAUDE_PATH="$(resolve_path "$CLAUDE_PATH_INPUT")"; then
    echo "Error: Unable to resolve destination path: $CLAUDE_PATH_INPUT"
    exit 1
fi
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
    "skills/note-taking/SKILL.md"
)

for file in "${FILES[@]}"; do
    example_file="${file}.example"
    target_file="${CLAUDE_PATH}/${file}"

    if [ ! -f "$example_file" ]; then
        echo "Warning: $example_file not found, skipping..."
        continue
    fi
    target_dir="$(dirname "$target_file")"
    mkdir -p "$target_dir"

    # Check if target file already exists
    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        if ! prompt_yes_no "File $target_file already exists. Overwrite?" "n"; then
            echo "Skipping $target_file"
            continue
        fi
    fi

    # Create target file with replacements
    sed -e "s|/path/to/claude|$CLAUDE_PATH|g" \
        -e "s|\$HOME/.claude|$HOME_EXPANDED/.claude|g" \
        "$example_file" > "$target_file"

    echo "✓ Created $target_file"
done

AGENTS_SOURCE_DIR="agents"
AGENTS_TARGET_DIR="${CLAUDE_PATH}/agents"

if [ -d "$AGENTS_SOURCE_DIR" ]; then
    echo ""
    echo "Syncing agents to $AGENTS_TARGET_DIR"
    while IFS= read -r -d '' agent_file; do
        relative_path="${agent_file#"$AGENTS_SOURCE_DIR"/}"
        target_path="${AGENTS_TARGET_DIR}/${relative_path}"
        target_parent="$(dirname "$target_path")"
        mkdir -p "$target_parent"

        if [ "$(resolve_path "$agent_file")" = "$(resolve_path "$target_path")" ]; then
            echo "Skipping $target_path (source and destination are the same file)"
            continue
        fi

        if [ -e "$target_path" ] || [ -L "$target_path" ]; then
            if ! prompt_yes_no "File $target_path already exists. Overwrite?" "n"; then
                echo "Skipping $target_path"
                continue
            fi
        fi

        cp "$agent_file" "$target_path"
        echo "✓ Copied $target_path"
    done < <(find "$AGENTS_SOURCE_DIR" -type f -print0)
else
    echo ""
    echo "Warning: agents directory not found, skipping agent sync."
fi

setup_symlinks

echo ""
echo "Setup complete! Your configuration files are ready."
echo ""
echo "Next steps:"
echo "1. Review the generated files in $CLAUDE_PATH to ensure paths are correct"
echo "2. Customize these files to reflect your workflows and preferences"
