#!/bin/bash

# Claude Code Status Line Script
# Displays current directory, git branch, and model in a formatted status line

# Configuration
USAGE_LOG="/tmp/usage.log"
USAGE_LOCK="/tmp/usage_refresh.lock"
USAGE_SCRIPT="$HOME/.claude/claude_code_capture_usage.py"
REFRESH_INTERVAL=300   # 5 minutes in seconds
LOCK_TIMEOUT=60        # Consider lock stale after 60 seconds
USAGE_CAPTURE_WAIT=3   # Seconds to wait for capture when refreshing usage log

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
dir=$(echo "$input" | jq -r '.cwd')
#dir=$(echo "$input" )
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed')
exceeds_tokens=$(echo "$input" | jq -r '.exceeds_200k_tokens')
workspace_current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
workspace_project_dir=$(echo "$input" | jq -r '.workspace.project_dir')
model_name=$(echo "$input" | jq -r '.model.display_name // "unknown"')
total_cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')


# Check if usage refresh is needed
needs_refresh() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        return 0  # File doesn't exist, needs refresh
    fi

    local current_time=$(date +%s)
    local file_time=$(stat -c %Y "$USAGE_LOG" 2>/dev/null || echo 0)
    local age=$((current_time - file_time))

    if (( age > REFRESH_INTERVAL )); then
        return 0  # File is stale
    fi

    return 1  # File is fresh
}

# Acquire lock atomically (returns 0 on success, 1 on failure)
acquire_lock() {
    # Clean up leftover file lock from old implementation
    if [[ -f "$USAGE_LOCK" ]]; then
        rm -f "$USAGE_LOCK" 2>/dev/null
    fi

    if mkdir "$USAGE_LOCK" 2>/dev/null; then
        return 0  # Lock acquired successfully
    fi

    # Lock exists as directory, check if it's stale
    if [[ -d "$USAGE_LOCK" ]]; then
        local current_time=$(date +%s)
        local lock_time=$(stat -c %Y "$USAGE_LOCK" 2>/dev/null || echo 0)
        local lock_age=$((current_time - lock_time))

        if (( lock_age > LOCK_TIMEOUT )); then
            # Stale lock, try to remove and re-acquire
            rmdir "$USAGE_LOCK" 2>/dev/null
            if mkdir "$USAGE_LOCK" 2>/dev/null; then
                return 0  # Lock acquired after cleanup
            fi
        fi
    fi

    return 1  # Could not acquire lock
}

# Release lock
release_lock() {
    rmdir "$USAGE_LOCK" 2>/dev/null
}

# Trigger background refresh
trigger_refresh() {
    if ! needs_refresh; then
        return  # No refresh needed
    fi

    # Verify script exists and is readable
    if [[ ! -f "$USAGE_SCRIPT" ]]; then
        return  # Script missing, skip refresh
    fi

    # Try to acquire lock atomically
    if ! acquire_lock; then
        return  # Another process is already refreshing
    fi

    local run_synchronously=0
    if [[ ! -f "$USAGE_LOG" ]]; then
        run_synchronously=1
    fi

    refresh_usage() {
        python3 "$USAGE_SCRIPT" --silent --wait "$USAGE_CAPTURE_WAIT" >/dev/null 2>&1
    }

    if (( run_synchronously )); then
        refresh_usage
        release_lock
    else
        (
            refresh_usage
            release_lock
        ) &
        disown
    fi
}

# Get git branch if in a git repository
get_git_branch() {
    if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
        local branch=$(git -C "$dir" branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]]; then
            echo "$branch"
        else
            # Fallback for detached HEAD state
            git -C "$dir" describe --all --exact-match HEAD 2>/dev/null | sed 's/^.*\///' || echo "detached"
        fi
    else
        echo ""
    fi
}

# Format model name with color coding (orange like git branch)
format_model() {
    local model=$1
    echo "\e[38;5;208m$model\e[0m"
}

# Format cost with color coding
format_cost() {
    local cost=$1
    local formatted=$(LC_NUMERIC=C printf "%.2f" "$cost")

    local color="\e[38;5;119m"  # Green: <$1
    if (( $(echo "$cost > 10" | bc -l) )); then
        color="\e[38;5;196m"    # Red: >$10
    elif (( $(echo "$cost > 5" | bc -l) )); then
        color="\e[38;5;208m"    # Orange: $5-10
    elif (( $(echo "$cost > 1" | bc -l) )); then
        color="\e[38;5;220m"    # Yellow: $1-5
    fi

    echo "${color}\$${formatted}\e[0m"
}

# Format duration display
format_duration() {
    local ms=$1

    if (( ms < 1000 )); then
        echo "${ms}ms"
    elif (( ms < 60000 )); then
        local seconds=$(awk "BEGIN {printf \"%.1f\", $ms / 1000}")
        echo "${seconds}s"
    else
        local minutes=$((ms / 60000))
        local remaining_ms=$((ms % 60000))
        local remaining_seconds=$(awk "BEGIN {printf \"%.0f\", $remaining_ms / 1000}")
        echo "${minutes}m ${remaining_seconds}s"
    fi
}

# Format lines added/removed display
format_lines() {
    local added=$1
    local removed=$2

    if [[ "$added" == "null" ]]; then added=0; fi
    if [[ "$removed" == "null" ]]; then removed=0; fi

    if [[ $added -eq 0 && $removed -eq 0 ]]; then
        echo ""
    else
        echo "\e[38;5;113m+${added}\e[0m/\e[38;5;196m-${removed}\e[0m lines"
    fi
}

# Format token warning display
format_token_warning() {
    local exceeds=$1

    if [[ "$exceeds" == "true" ]]; then
        echo " \e[38;5;196m⚠️200k\e[0m"
    else
        echo ""
    fi
}

# Format context window usage
#
# Claude Code reserves a 22.5% "autocompact buffer" for compaction operations.
# This means compaction triggers at ~77.5% raw usage (77.5 + 22.5 = 100%).
# We show RAW usage percentage but color-code based on proximity to compaction:
#   - Green (0-40%):  plenty of room (effective 0-62%)
#   - Yellow (41-55%): getting full (effective 63-77%)
#   - Red (56%+):     compaction imminent (effective 78%+)
format_ctx_usage() {
    local used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
    local window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

    [[ "$window_size" -eq 0 ]] && return

    local total_k=$((window_size / 1000))
    local used_k=$((window_size * used_pct / 100000))

    # Color based on proximity to compaction (buffer-aware thresholds)
    local color="\e[38;5;119m"  # Green
    if (( used_pct > 55 )); then
        color="\e[38;5;196m"    # Red
    elif (( used_pct > 40 )); then
        color="\e[38;5;220m"    # Yellow
    fi

    echo "\e[38;5;246mctx:\e[0m ${color}${used_k}k/${total_k}k (${used_pct}%)\e[0m"
}

# Detect dependency errors recorded in the usage log
get_usage_error() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo ""
        return
    fi

    local first_line
    first_line=$(head -n 1 "$USAGE_LOG" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

    if [[ "$first_line" == ERROR:* ]]; then
        echo "${first_line#ERROR: }"
    fi
}

# Normalize reset time string (fix spaces stripped by ANSI removal)
# "ResetsFeb12,12pm(Europe/Berlin)" -> "Feb 12, 12pm"
normalize_reset_string() {
    local raw="$1"
    raw=$(echo "$raw" | sed 's/^[[:space:]]*Resets *//')
    raw=$(echo "$raw" | sed 's/[[:space:]]*(.*$//')
    # Re-insert spaces: "Feb12,12pm" -> "Feb 12, 12pm"
    raw=$(echo "$raw" | sed 's/\([A-Za-z]\)\([0-9]\)/\1 \2/g; s/,\([^ ]\)/, \1/g')
    echo "$raw"
}

# Extract the session section from the usage log.
# All TUI sections may be concatenated on one line — this isolates the session
# portion (from "Current session" to just before "Current week").
extract_session_section() {
    if [[ ! -f "$USAGE_LOG" ]]; then return; fi
    grep -m 1 -o "Current session.*" "$USAGE_LOG" | \
        sed -E 's/[Cc]urrent ?[Ww]eek.*//'
}

# Extract the week (all models) section from the usage log.
# Strips everything before "Current week (all models)" and after the next section.
# Newer TUI splits the header, bar/percentage, and reset across separate lines,
# so pull a few trailing lines and squash to one before the section trims.
extract_week_section() {
    if [[ ! -f "$USAGE_LOG" ]]; then return; fi
    grep -m 1 -A 3 -Ei "current ?week ?\(?all ?models\)?" "$USAGE_LOG" | \
        tr '\n' ' ' | \
        sed -E 's/.*[Cc]urrent ?[Ww]eek ?\(?[Aa]ll ?[Mm]odels\)?//' | \
        sed -E 's/[Cc]urrent ?[Ww]eek ?\(?[Ss]onnet.*//' | \
        sed -E 's/[Ee]xtra ?[Uu]sage.*//'
}

# Parse usage log for session percentage
parse_session_usage() {
    local section
    section=$(extract_session_section)

    local percentage=""
    if [[ -n "$section" ]]; then
        percentage=$(echo "$section" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
    fi

    echo "${percentage:-0}"
}

# Parse usage log for session reset time
parse_session_reset() {
    local section
    section=$(extract_session_section)

    if [[ -n "$section" ]]; then
        local reset_time
        reset_time=$(echo "$section" | grep -oE '[0-9]+:?[0-9]*[ap]m' | head -1)
        if [[ -n "$reset_time" ]]; then
            echo "$reset_time"
            return
        fi
    fi

    # Fallback: check for "Resets" on next lines
    if [[ -f "$USAGE_LOG" ]]; then
        local reset_line
        reset_line=$(grep -A 2 "Current session" "$USAGE_LOG" | grep -i "Reset" | head -1)
        if [[ -n "$reset_line" ]]; then
            normalize_reset_string "$reset_line"
        fi
    fi
}

# Parse usage log for week percentage
parse_week_usage() {
    local section
    section=$(extract_week_section)

    local percentage=""
    if [[ -n "$section" ]]; then
        percentage=$(echo "$section" | grep -oE '[0-9]+%' | head -1 | tr -d '%')
    fi

    if [[ -z "$percentage" && -f "$USAGE_LOG" ]]; then
        local week_line
        week_line=$(grep -m 1 "Week:" "$USAGE_LOG")
        if [[ -n "$week_line" ]]; then
            percentage=$(echo "$week_line" | sed -n 's/.*Week:[^0-9]*\([0-9][0-9]*\)%.*/\1/p')
        fi
    fi

    echo "${percentage:-0}"
}

# Parse usage log for week reset time
parse_week_reset() {
    local section
    section=$(extract_week_section)
    local reset_info=""

    if [[ -n "$section" ]]; then
        local after_resets
        after_resets=$(echo "$section" | sed -n 's/.*[Rr]eset[s]\{0,1\} *//p')
        if [[ -n "$after_resets" ]]; then
            reset_info=$(normalize_reset_string "$after_resets")
        fi
    fi

    if [[ -z "$reset_info" && -f "$USAGE_LOG" ]]; then
        local week_line
        week_line=$(grep -m 1 "Week:" "$USAGE_LOG")

        if [[ -n "$week_line" ]]; then
            local after_arrow
            after_arrow=$(echo "$week_line" | awk -F "↻" 'NF>1 {print $2}')
            if [[ -n "$after_arrow" ]]; then
                after_arrow=${after_arrow%%│*}
                after_arrow=${after_arrow%%┘*}
                after_arrow=$(echo "$after_arrow" | sed 's/^[[:space:]]*//;s/[[:space:]─]*$//')
                reset_info="$after_arrow"
            fi
        fi
    fi

    echo "$reset_info"
}

# Calculate how long ago the usage log was updated
get_usage_age() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo "never"
        return
    fi

    local current_time=$(date +%s)
    local file_time=$(stat -c %Y "$USAGE_LOG" 2>/dev/null || echo 0)
    local age=$((current_time - file_time))

    if (( age < 60 )); then
        echo "${age}s"
    elif (( age < 3600 )); then
        local minutes=$((age / 60))
        echo "${minutes}m"
    elif (( age < 86400 )); then
        local hours=$((age / 3600))
        echo "${hours}h"
    else
        local days=$((age / 86400))
        echo "${days}d"
    fi
}

# Add ordinal suffix to day number
add_ordinal() {
    local num=$1
    case $num in
        1|21|31) echo "${num}st" ;;
        2|22) echo "${num}nd" ;;
        3|23) echo "${num}rd" ;;
        *) echo "${num}th" ;;
    esac
}

# Format reset time with ordinal suffix
format_reset_time() {
    local reset_str=$1

    if [[ -z "$reset_str" ]]; then
        echo ""
        return
    fi

    # Parse "Oct 8, 10:59pm" format
    if [[ "$reset_str" =~ ^([A-Za-z]+)[[:space:]]+([0-9]+),[[:space:]]+(.+)$ ]]; then
        local month="${BASH_REMATCH[1]}"
        local day="${BASH_REMATCH[2]}"
        local time="${BASH_REMATCH[3]}"
        local day_with_suffix=$(add_ordinal "$day")
        echo "${day_with_suffix} ${month}. ${time}"
    else
        # Fallback: just return the original string
        echo "$reset_str"
    fi
}

# Format usage display
format_usage_display() {
    local usage_error=$(get_usage_error)

    if [[ -n "$usage_error" ]]; then
        local display=""
        display+=" \e[38;5;240m│\e[0m"
        display+=" \e[38;5;246mUsage:\e[0m \e[38;5;196m⚠ ${usage_error}\e[0m"
        echo -e "$display"
        return
    fi

    local session_pct=$(parse_session_usage)
    local session_reset=$(parse_session_reset)
    local week_pct=$(parse_week_usage)
    local week_reset=$(parse_week_reset)
    local age=$(get_usage_age)

    # Only hide if data is truly missing (empty string), not if it's 0%
    if [[ -z "$session_pct" ]] && [[ -z "$week_pct" ]]; then
        # No usage data available
        echo ""
        return
    fi

    # Default to 0 if empty
    session_pct=${session_pct:-0}
    week_pct=${week_pct:-0}

    # Color based on usage percentage
    # Green: 0-30%, Yellow: 30.01-50%, Orange: 50.01-80%, Red: > 80%
    local session_color="\e[38;5;119m"  # Green (default)
    if (( session_pct > 80 )); then
        session_color="\e[38;5;196m"  # Red
    elif (( session_pct > 50 )); then
        session_color="\e[38;5;208m"  # Orange
    elif (( session_pct > 30 )); then
        session_color="\e[38;5;220m"  # Yellow
    fi

    local week_color="\e[38;5;119m"  # Green (default)
    if (( week_pct > 80 )); then
        week_color="\e[38;5;196m"  # Red
    elif (( week_pct > 50 )); then
        week_color="\e[38;5;208m"  # Orange
    elif (( week_pct > 30 )); then
        week_color="\e[38;5;220m"  # Yellow
    fi

    # Format reset times with ordinal suffix
    local session_reset_formatted=$(format_reset_time "$session_reset")
    local week_reset_formatted=$(format_reset_time "$week_reset")

    # Build the display string
    local display=""
    display+=" \e[38;5;240m│\e[0m"
    display+=" \e[38;5;246mSession:\e[0m ${session_color}${session_pct}%\e[0m"
    if [[ -n "$session_reset_formatted" ]]; then
        display+=" \e[38;5;240m(\e[0m\e[38;5;245m↻ ${session_reset_formatted}\e[0m\e[38;5;240m)\e[0m"
    fi
    display+=" \e[38;5;240m│\e[0m"
    display+=" \e[38;5;246mWeek:\e[0m ${week_color}${week_pct}%\e[0m"
    if [[ -n "$week_reset_formatted" ]]; then
        display+=" \e[38;5;240m(\e[0m\e[38;5;245m↻ ${week_reset_formatted}\e[0m\e[38;5;240m)\e[0m"
    fi
    display+=" \e[38;5;240m│\e[0m"
    display+=" \e[38;5;240m↻ ${age}\e[0m"

    echo -e "$display"
}

# Smart path truncation: max 3 components, ~ for home, .. when truncated
truncate_path() {
    local p="${1/#$HOME/\~}"
    local trimmed="${p#/}"
    local parts=() IFS='/'
    read -ra parts <<< "$trimmed"
    local n=${#parts[@]}
    if (( n > 3 )); then
        echo "../${parts[*]: -3}" | tr ' ' '/'
    else
        echo "$p"
    fi
}

# Format directory display with project/current labels
format_directory() {
    local current=$(truncate_path "$1")
    local project=$(truncate_path "$2")

    if [[ "$current" == "$project" ]]; then
        # Same directory: show only project
        echo "\e[38;5;117mproject:\e[0m \e[38;5;117m$project\e[0m"
    else
        # Different directories: show both
        echo "\e[38;5;117mproject:\e[0m \e[38;5;117m$project\e[0m \e[38;5;240m│\e[0m \e[38;5;87mcurrent:\e[0m \e[38;5;87m$current\e[0m"
    fi
}

# Trigger background refresh if needed
trigger_refresh

git_branch=$(get_git_branch)
formatted_session_duration=$(format_duration "$duration_ms")
formatted_lines=$(format_lines "$lines_added" "$lines_removed")
token_warning=$(format_token_warning "$exceeds_tokens")
formatted_model=$(format_model "$model_name")
formatted_cost=$(format_cost "$total_cost")
formatted_ctx_usage=$(format_ctx_usage)
formatted_dir=$(format_directory "$workspace_current_dir" "$workspace_project_dir")
formatted_usage=$(format_usage_display)

# Get terminal width for adaptive layout
# Prefer tmux pane width (accurate in splits) over tput cols (may return full terminal width)
if [[ -n "$TMUX" ]]; then
    term_width=$(tmux display-message -p '#{pane_width}' 2>/dev/null || tput cols 2>/dev/null || echo 120)
else
    term_width=$(tput cols 2>/dev/null || echo 120)
fi
# Small margin for Claude Code's built-in borders/padding only
# (right-side indicators handled by greedy builder stopping before overflow)
(( term_width = term_width > 16 ? term_width - 10 : term_width ))

# Calculate visible character count (strip ANSI escape sequences)
component_width() {
    local stripped
    stripped=$(echo -ne "$1" | sed 's/\x1b\[[0-9;]*m//g')
    echo ${#stripped}
}

sep=" \e[38;5;240m│\e[0m "
SEP_W=3  # visible width of " │ "
PREFIX="\e[38;5;240m┌─\e[0m "
PREFIX_W=3  # visible width of "┌─ "

# Pre-compute visible widths of each component (one subshell each)
comp_model="$formatted_model $formatted_cost"
comp_ctx="$formatted_ctx_usage"
comp_duration="\e[38;5;246m$formatted_session_duration\e[0m"
comp_lines="$formatted_lines"
comp_dir="$formatted_dir"

w_model=$(component_width "$comp_model")
w_ctx=$(component_width "$comp_ctx")
w_duration=$(component_width "$comp_duration")
w_dir=$(component_width "$comp_dir")

# Only compute branch width if in a git repo
if [[ -n "$git_branch" ]]; then
    comp_branch="\e[38;5;208m$git_branch\e[0m"
    w_branch=$(component_width "$comp_branch")
else
    comp_branch=""
    w_branch=0
fi

# Only compute lines width if there are changes
if [[ -n "$formatted_lines" ]]; then
    w_lines=$(component_width "$comp_lines")
else
    w_lines=0
fi

# Greedy line 1 builder: add components in priority order, stop when next won't fit
# Priority: model+cost, ctx, branch, duration, lines, directory
line1="$PREFIX$comp_model"
running_w=$(( PREFIX_W + w_model ))

# Try adding a component if it fits
try_add() {
    local comp="$1" w="$2"
    [[ -z "$comp" || "$w" -eq 0 ]] && return 1
    if (( running_w + SEP_W + w <= term_width )); then
        line1+="${sep}${comp}"
        (( running_w += SEP_W + w ))
        return 0
    fi
    return 1
}

try_add "$comp_ctx"      "$w_ctx"
try_add "$comp_branch"   "$w_branch"
try_add "$comp_duration" "$w_duration"
try_add "$comp_lines"    "$w_lines"
try_add "$comp_dir"      "$w_dir"

# If model+cost alone overflows, fall back to short model name
# (skips lines/dir — lowest priority components)
if (( running_w > term_width )); then
    local short_model_name comp_model_short w_model_short
    short_model_name=$(echo "$model_name" | sed 's/ ([^)]*context)//')
    comp_model_short="$(format_model "$short_model_name") $formatted_cost"
    w_model_short=$(component_width "$comp_model_short")
    line1="$PREFIX$comp_model_short"
    running_w=$(( PREFIX_W + w_model_short ))
    try_add "$comp_ctx"      "$w_ctx"
    try_add "$comp_branch"   "$w_branch"
    try_add "$comp_duration" "$w_duration"
fi

# Line 2: Session/week usage (supplementary — survives if line 1 fits)
line2="\e[38;5;240m└─\e[0m"
line2+="$token_warning$formatted_usage \e[38;5;240m─┘\e[0m"

echo -e "$line1"
echo -e "$line2"
