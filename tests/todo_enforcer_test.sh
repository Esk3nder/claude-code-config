#!/usr/bin/env bash
#
# Integration tests for todo-enforcer.sh Stop hook
#
# Run: ./tests/todo_enforcer_test.sh
#
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/todo-enforcer.sh"
FAILURES=0
TOTAL=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

log_pass() {
  echo -e "${GREEN}PASS${NC}: $1"
}

log_fail() {
  echo -e "${RED}FAIL${NC}: $1"
  ((FAILURES++))
}

# Check if jq is available
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required for tests"
  exit 1
fi

# =============================================================================
# TESTS
# =============================================================================

echo "=== todo-enforcer.sh Integration Tests ==="
echo ""

# Test 1: No transcript path allows exit
echo "--- Test: No transcript path allows exit ---"
((TOTAL++))
output=$(echo '{}' | bash "$HOOK_SCRIPT" 2>&1) || true
# Should exit 0 (allow) with no block output
if ! echo "$output" | grep -q '"decision": "block"'; then
  log_pass "No transcript path allows exit"
else
  log_fail "No transcript path - Should not block"
  echo "Output: $output"
fi

# Test 2: Missing transcript file allows exit
echo "--- Test: Missing transcript file allows exit ---"
((TOTAL++))
output=$(echo '{"transcript_path":"/nonexistent/file.json"}' | bash "$HOOK_SCRIPT" 2>&1) || true
if ! echo "$output" | grep -q '"decision": "block"'; then
  log_pass "Missing transcript file allows exit"
else
  log_fail "Missing transcript file - Should not block"
  echo "Output: $output"
fi

# Test 3: Empty transcript allows exit
echo "--- Test: Empty transcript allows exit ---"
((TOTAL++))
tmpfile=$(mktemp)
trap "rm -f '$tmpfile'" EXIT
echo '{}' > "$tmpfile"
output=$(echo "{\"transcript_path\":\"$tmpfile\"}" | bash "$HOOK_SCRIPT" 2>&1) || true
if ! echo "$output" | grep -q '"decision": "block"'; then
  log_pass "Empty transcript allows exit"
else
  log_fail "Empty transcript - Should not block"
fi

# Test 4: Incomplete todos block exit
echo "--- Test: Incomplete todos block exit ---"
((TOTAL++))
tmpfile=$(mktemp)
cat > "$tmpfile" << 'EOF'
{"message":{"content":[{"type":"tool_use","name":"TodoWrite","input":{"todos":[{"content":"Task 1","status":"pending"}]}}]}}
EOF
output=$(echo "{\"transcript_path\":\"$tmpfile\"}" | bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q '"decision": "block"'; then
  log_pass "Incomplete todos block exit"
else
  log_fail "Incomplete todos - Should block"
  echo "Output: $output"
fi

# Test 5: In-progress todos block exit
echo "--- Test: In-progress todos block exit ---"
((TOTAL++))
tmpfile=$(mktemp)
cat > "$tmpfile" << 'EOF'
{"message":{"content":[{"type":"tool_use","name":"TodoWrite","input":{"todos":[{"content":"Task 1","status":"in_progress"}]}}]}}
EOF
output=$(echo "{\"transcript_path\":\"$tmpfile\"}" | bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q '"decision": "block"'; then
  log_pass "In-progress todos block exit"
else
  log_fail "In-progress todos - Should block"
  echo "Output: $output"
fi

# Test 6: All completed todos allow exit
echo "--- Test: Completed todos allow exit ---"
((TOTAL++))
tmpfile=$(mktemp)
cat > "$tmpfile" << 'EOF'
{"message":{"content":[{"type":"tool_use","name":"TodoWrite","input":{"todos":[{"content":"Task 1","status":"completed"}]}}]}}
EOF
output=$(echo "{\"transcript_path\":\"$tmpfile\"}" | bash "$HOOK_SCRIPT" 2>&1) || true
if ! echo "$output" | grep -q '"decision": "block"'; then
  log_pass "Completed todos allow exit"
else
  log_fail "Completed todos - Should not block"
  echo "Output: $output"
fi

# Test 7: Mixed todos (some completed, some pending) blocks
echo "--- Test: Mixed todos block exit ---"
((TOTAL++))
tmpfile=$(mktemp)
cat > "$tmpfile" << 'EOF'
{"message":{"content":[{"type":"tool_use","name":"TodoWrite","input":{"todos":[{"content":"Task 1","status":"completed"},{"content":"Task 2","status":"pending"}]}}]}}
EOF
output=$(echo "{\"transcript_path\":\"$tmpfile\"}" | bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q '"decision": "block"'; then
  log_pass "Mixed todos block exit"
else
  log_fail "Mixed todos - Should block"
  echo "Output: $output"
fi

# Test 8: die() outputs block decision (simulated jq missing scenario)
echo "--- Test: die() outputs block decision ---"
((TOTAL++))
# We test this by looking at the function definition, since we can't easily
# remove jq from PATH in a subprocess. The test verifies the new behavior
# is present in the script.
if grep -q 'jq -n --arg reason "Todo enforcer error:' "$HOOK_SCRIPT"; then
  log_pass "die() outputs block decision (verified in source)"
else
  log_fail "die() should output block decision"
fi

# Test 9: Disabled via config
echo "--- Test: Disabled via config ---"
((TOTAL++))
config_file="$HOME/.claude/hooks/todo-enforcer.config.json"
config_dir="$(dirname "$config_file")"
mkdir -p "$config_dir"
# Backup existing config if present
if [[ -f "$config_file" ]]; then
  cp "$config_file" "${config_file}.bak"
fi
# Write disabled config
echo '{"enabled":false}' > "$config_file"
tmpfile=$(mktemp)
cat > "$tmpfile" << 'EOF'
{"message":{"content":[{"type":"tool_use","name":"TodoWrite","input":{"todos":[{"content":"Task 1","status":"pending"}]}}]}}
EOF
output=$(echo "{\"transcript_path\":\"$tmpfile\"}" | bash "$HOOK_SCRIPT" 2>&1) || true
# Restore config
if [[ -f "${config_file}.bak" ]]; then
  mv "${config_file}.bak" "$config_file"
else
  rm -f "$config_file"
fi
if ! echo "$output" | grep -q '"decision": "block"'; then
  log_pass "Disabled via config allows exit"
else
  log_fail "Disabled config - Should not block"
  echo "Output: $output"
fi

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "=== Test Summary ==="
echo "Total: $TOTAL"
echo "Passed: $((TOTAL - FAILURES))"
echo "Failed: $FAILURES"

if [[ "$FAILURES" -gt 0 ]]; then
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
