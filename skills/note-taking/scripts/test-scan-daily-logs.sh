#!/bin/bash
# Tests for scan-daily-logs.sh
# Uses temp directories to simulate task_notes structures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$SCRIPT_DIR/scan-daily-logs.sh"
PASS=0
FAIL=0

setup() {
    TMPDIR=$(mktemp -d)
    export TASKS_NOTES="$TMPDIR"
}

teardown() {
    rm -rf "$TMPDIR"
}

run_script() {
    echo '{}' | bash "$SCRIPT" 2>&1
}

assert_contains() {
    local output="$1" expected="$2" label="$3"
    if echo "$output" | grep -qF "$expected"; then
        PASS=$((PASS + 1))
        echo "  PASS: $label"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $label"
        echo "    expected to contain: $expected"
        echo "    got: $output"
    fi
}

assert_not_contains() {
    local output="$1" expected="$2" label="$3"
    if echo "$output" | grep -qF "$expected"; then
        FAIL=$((FAIL + 1))
        echo "  FAIL: $label"
        echo "    should NOT contain: $expected"
        echo "    got: $output"
    else
        PASS=$((PASS + 1))
        echo "  PASS: $label"
    fi
}

assert_empty() {
    local output="$1" label="$2"
    if [[ -z "$output" ]]; then
        PASS=$((PASS + 1))
        echo "  PASS: $label"
    else
        FAIL=$((FAIL + 1))
        echo "  FAIL: $label"
        echo "    expected empty output, got: $output"
    fi
}

# --- Tests ---

echo "Test 1: Top-level project daily_log"
setup
mkdir -p "$TMPDIR/myproject/daily_log"
echo '- **→ notes.md**: some insight' > "$TMPDIR/myproject/daily_log/2026-01-15.md"
output=$(run_script)
assert_contains "$output" "myproject:" "project name shown"
assert_contains "$output" "1 flagged item)" "singular item count"
assert_contains "$output" "=== Daily log promotion scan ===" "header present"
teardown

echo "Test 2: Nested project (personal_projects/foo)"
setup
mkdir -p "$TMPDIR/personal_projects/foo/daily_log"
echo '- **→ notes.md**: insight one
- **→ notes.md**: insight two' > "$TMPDIR/personal_projects/foo/daily_log/2026-02-10.md"
output=$(run_script)
assert_contains "$output" "personal_projects/foo:" "nested project name"
assert_contains "$output" "2 flagged items)" "plural item count"
teardown

echo "Test 3: Deeply nested project (a/b/c)"
setup
mkdir -p "$TMPDIR/a/b/c/daily_log"
echo '- **→ notes.md**: deep insight' > "$TMPDIR/a/b/c/daily_log/2026-03-01.md"
output=$(run_script)
assert_contains "$output" "a/b/c:" "deeply nested project name"
teardown

echo "Test 4: Processed file is skipped"
setup
mkdir -p "$TMPDIR/proj/daily_log"
printf -- '- **→ notes.md**: old insight\n<!-- notes-processed: 2026-01-16T10:00 -->\n' > "$TMPDIR/proj/daily_log/2026-01-15.md"
output=$(run_script)
assert_empty "$output" "no output for processed-only files"
teardown

echo "Test 5: Mix of processed and unprocessed"
setup
mkdir -p "$TMPDIR/proj/daily_log"
printf -- '- **→ notes.md**: old\n<!-- notes-processed: 2026-01-16 -->\n' > "$TMPDIR/proj/daily_log/2026-01-15.md"
echo '- **→ notes.md**: new insight' > "$TMPDIR/proj/daily_log/2026-01-20.md"
output=$(run_script)
assert_not_contains "$output" "2026-01-15" "processed file excluded"
assert_contains "$output" "2026-01-20" "unprocessed file included"
teardown

echo "Test 6: Today's file always included even if processed"
setup
mkdir -p "$TMPDIR/proj/daily_log"
today=$(date +%Y-%m-%d)
printf -- '- **→ notes.md**: today insight\n<!-- notes-processed: 2026-01-01 -->\n' > "$TMPDIR/proj/daily_log/$today.md"
output=$(run_script)
assert_contains "$output" "[today]" "today tag present"
assert_contains "$output" "1 flagged item)" "today file counted"
teardown

echo "Test 7: File with zero flagged items still shows"
setup
mkdir -p "$TMPDIR/proj/daily_log"
echo '- regular log entry, no promotion markers' > "$TMPDIR/proj/daily_log/2026-02-01.md"
output=$(run_script)
assert_contains "$output" "0 flagged items)" "zero count shown"
teardown

echo "Test 8: Promoted items (✓ promoted) not counted as flagged"
setup
mkdir -p "$TMPDIR/proj/daily_log"
echo '- **✓ promoted**: already done
- **→ notes.md**: still pending' > "$TMPDIR/proj/daily_log/2026-02-05.md"
output=$(run_script)
assert_contains "$output" "1 flagged item)" "only unpromoted counted"
teardown

echo "Test 9: Empty TASKS_NOTES dir produces no output"
setup
output=$(run_script)
assert_empty "$output" "empty dir = no output"
teardown

echo "Test 10: Multiple projects sorted"
setup
mkdir -p "$TMPDIR/zebra/daily_log" "$TMPDIR/alpha/daily_log"
echo '- **→ notes.md**: z' > "$TMPDIR/zebra/daily_log/2026-01-01.md"
echo '- **→ notes.md**: a' > "$TMPDIR/alpha/daily_log/2026-01-01.md"
output=$(run_script)
alpha_pos=$(echo "$output" | grep -n "alpha:" | head -1 | cut -d: -f1)
zebra_pos=$(echo "$output" | grep -n "zebra:" | head -1 | cut -d: -f1)
if [[ "$alpha_pos" -lt "$zebra_pos" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: projects sorted alphabetically"
else
    FAIL=$((FAIL + 1))
    echo "  FAIL: projects not sorted (alpha@$alpha_pos, zebra@$zebra_pos)"
fi
teardown

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
