#!/bin/bash

# Claude Code Status Line Script
# Displays current directory, git branch, and model in a formatted status line

# Configuration
USAGE_LOG="/tmp/usage.log"
USAGE_LOCK="/tmp/usage_refresh.lock"
USAGE_SCRIPT="$HOME/.claude/claude_code_capture_usage.py"
REFRESH_INTERVAL=300  # 5 minutes in seconds
LOCK_TIMEOUT=60       # Consider lock stale after 60 seconds

# Read JSON input from stdin
input=$(cat)

# Extract values from JSON
dir=$(echo "$input" | jq -r '.cwd')
#dir=$(echo "$input" )
model=$(echo "$input" | jq -r '.model.display_name')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd')
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms')
api_duration_ms=$(echo "$input" | jq -r '.cost.total_api_duration_ms')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed')
exceeds_tokens=$(echo "$input" | jq -r '.exceeds_200k_tokens')
workspace_current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
workspace_project_dir=$(echo "$input" | jq -r '.workspace.project_dir')

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

    # Spawn background process
    (
        python3 "$USAGE_SCRIPT" --silent --wait 1 >/dev/null 2>&1
        release_lock
    ) &
    disown
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

# Format cost display
format_cost() {
    local cost_val=$1
    # Use awk for reliable floating-point arithmetic and rounding
    local formatted=$(awk "BEGIN { 
        cost = $cost_val;
        if (cost == 0) 
            printf \"\$0\";
        else 
            printf \"\$%.2f\", cost;
    }")
    echo "$formatted"
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

# Format combined duration display (session + api)
format_combined_duration() {
    local session_ms=$1
    local api_ms=$2

    local session=$(format_duration "$session_ms")
    local api=$(format_duration "$api_ms")

    echo "(session: $session | api: $api)"
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

# Get color based on cost
get_cost_color() {
    local cost_val=$1
    # Use awk for reliable floating-point comparisons, return numeric code
    local color_num=$(awk "BEGIN { 
        cost = $cost_val;
        if (cost <= 3) 
            print \"119\";
        else if (cost <= 7) 
            print \"220\";
        else 
            print \"196\";
    }")
    echo "\e[38;5;${color_num}m"
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

# Parse usage log for session percentage
parse_session_usage() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo ""
        return
    fi

    local session_line=$(grep -A 1 "Current session" "$USAGE_LOG" | tail -1)
    local percentage=$(echo "$session_line" | grep -o '[0-9]\+%' | head -1 | tr -d '%')
    echo "${percentage:-0}"
}

# Parse usage log for session reset time
parse_session_reset() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo ""
        return
    fi

    local reset_line=$(grep -A 2 "Current session" "$USAGE_LOG" | grep "Resets" | head -1)
    local reset_info=$(echo "$reset_line" | sed 's/^[[:space:]]*Resets //' | sed 's/ (.*$//')
    echo "$reset_info"
}

# Parse usage log for week percentage
parse_week_usage() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo ""
        return
    fi

    local week_line=$(grep -A 1 "Current week (all models)" "$USAGE_LOG" | tail -1)
    local percentage=$(echo "$week_line" | grep -o '[0-9]\+%' | head -1 | tr -d '%')
    echo "${percentage:-0}"
}

# Parse usage log for week reset time
parse_week_reset() {
    if [[ ! -f "$USAGE_LOG" ]]; then
        echo ""
        return
    fi

    local reset_line=$(grep -A 2 "Current week (all models)" "$USAGE_LOG" | grep "Resets" | head -1)
    local reset_info=$(echo "$reset_line" | sed 's/^[[:space:]]*Resets //' | sed 's/ (.*$//')
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

# Format directory display with project/current labels
format_directory() {
    local current=$1
    local project=$2

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
formatted_cost=$(format_cost "$cost")
formatted_duration=$(format_combined_duration "$duration_ms" "$api_duration_ms")
formatted_lines=$(format_lines "$lines_added" "$lines_removed")
token_warning=$(format_token_warning "$exceeds_tokens")
cost_color=$(get_cost_color "$cost")
formatted_dir=$(format_directory "$workspace_current_dir" "$workspace_project_dir")
formatted_usage=$(format_usage_display)

# Format and display the status line with colors
if [[ -n "$git_branch" ]]; then
    # With git branch: dir │ branch │ model │ cost duration lines token_warning usage
    if [[ -n "$formatted_lines" ]]; then
        echo -e "\e[38;5;240m┌─\e[0m $formatted_dir \e[38;5;240m│\e[0m \e[38;5;208m$git_branch\e[0m \e[38;5;240m│\e[0m \e[38;5;222m$model\e[0m \e[38;5;240m│\e[0m $cost_color$formatted_cost $formatted_duration\e[0m \e[38;5;240m│\e[0m $formatted_lines$token_warning$formatted_usage \e[38;5;240m─┘\e[0m"
    else
        echo -e "\e[38;5;240m┌─\e[0m $formatted_dir \e[38;5;240m│\e[0m \e[38;5;208m$git_branch\e[0m \e[38;5;240m│\e[0m \e[38;5;222m$model\e[0m \e[38;5;240m│\e[0m $cost_color$formatted_cost $formatted_duration\e[0m$token_warning$formatted_usage \e[38;5;240m─┘\e[0m"
    fi
else
    # Without git branch: dir │ model │ cost duration lines token_warning usage
    if [[ -n "$formatted_lines" ]]; then
        echo -e "\e[38;5;240m┌─\e[0m $formatted_dir \e[38;5;240m│\e[0m \e[38;5;222m$model\e[0m \e[38;5;240m│\e[0m $cost_color$formatted_cost $formatted_duration\e[0m \e[38;5;240m│\e[0m $formatted_lines$token_warning$formatted_usage \e[38;5;240m─┘\e[0m"
    else
        echo -e "\e[38;5;240m┌─\e[0m $formatted_dir \e[38;5;240m│\e[0m \e[38;5;222m$model\e[0m \e[38;5;240m│\e[0m $cost_color$formatted_cost $formatted_duration\e[0m$token_warning$formatted_usage \e[38;5;240m─┘\e[0m"
    fi
fi
