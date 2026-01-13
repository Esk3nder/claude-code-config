#!/usr/bin/env bash
#
# Integration tests for require-green-tests.sh Stop hook
#
# Run: ./tests/require_green_tests_test.sh
#
# SPDX-License-Identifier: MIT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/workflows/require-green-tests.sh"
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

run_test() {
  local name="$1"
  local setup_fn="$2"
  local expected_exit="${3:-0}"
  local expected_output="${4:-}"

  ((TOTAL++))
  echo "--- Test: $name ---"

  # Create temp directory for test
  local test_dir
  test_dir="$(mktemp -d)"
  trap "rm -rf '$test_dir'" RETURN

  # Setup the test
  cd "$test_dir"
  $setup_fn "$test_dir"

  # Run the hook
  local output
  local exit_code=0
  output=$(REPO_ROOT="$test_dir" bash "$HOOK_SCRIPT" 2>&1) || exit_code=$?

  # Check exit code
  if [[ "$exit_code" -ne "$expected_exit" ]]; then
    log_fail "$name - Expected exit code $expected_exit, got $exit_code"
    echo "Output: $output"
    return
  fi

  # Check output if specified
  if [[ -n "$expected_output" ]] && ! echo "$output" | grep -q "$expected_output"; then
    log_fail "$name - Expected output to contain: $expected_output"
    echo "Actual output: $output"
    return
  fi

  log_pass "$name"
}

# =============================================================================
# TEST SETUP FUNCTIONS
# =============================================================================

setup_no_test_infra() {
  local dir="$1"
  # No package.json, no lock files, nothing
  mkdir -p "$dir"
}

setup_green_tests() {
  local dir="$1"
  cat > "$dir/package.json" << 'EOF'
{"scripts":{"test":"exit 0"}}
EOF
  touch "$dir/package-lock.json"
}

setup_red_tests() {
  local dir="$1"
  cat > "$dir/package.json" << 'EOF'
{"scripts":{"test":"echo 'Test failed!' && exit 1"}}
EOF
  touch "$dir/package-lock.json"
}

setup_for_cache_test_initial() {
  local dir="$1"
  cat > "$dir/package.json" << 'EOF'
{"scripts":{"test":"exit 0"}}
EOF
  touch "$dir/package-lock.json"
  # Initialize git for mtime tracking
  git init -q "$dir"
  git -C "$dir" add .
  git -C "$dir" commit -q -m "initial"
}

setup_pnpm_project() {
  local dir="$1"
  cat > "$dir/package.json" << 'EOF'
{"scripts":{"test":"exit 0"}}
EOF
  touch "$dir/pnpm-lock.yaml"
}

setup_yarn_project() {
  local dir="$1"
  cat > "$dir/package.json" << 'EOF'
{"scripts":{"test":"exit 0"}}
EOF
  touch "$dir/yarn.lock"
}

# =============================================================================
# RUN TESTS
# =============================================================================

echo "=== require-green-tests.sh Integration Tests ==="
echo ""

# Test 1: No test infrastructure should skip
run_test "No test infrastructure skips" \
  setup_no_test_infra \
  0 \
  "no test infrastructure detected"

# Test 2: Green tests should pass
run_test "Green tests pass" \
  setup_green_tests \
  0 \
  "tests green"

# Test 3: Red tests should block
run_test "Red tests block" \
  setup_red_tests \
  1 \
  "tests failed"

# Test 4: pnpm project detection
run_test "pnpm project detected" \
  setup_pnpm_project \
  0 \
  "pnpm test"

# Test 5: yarn project detection
run_test "yarn project detected" \
  setup_yarn_project \
  0 \
  "yarn test"

# Test 6: Opt-out via environment variable
echo "--- Test: Opt-out via WORKFLOWS_SKIP_TESTS ---"
((TOTAL++))
test_dir="$(mktemp -d)"
trap "rm -rf '$test_dir'" EXIT
setup_red_tests "$test_dir"
output=$(WORKFLOWS_SKIP_TESTS=true REPO_ROOT="$test_dir" bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q "tests skipped via WORKFLOWS_SKIP_TESTS=true"; then
  log_pass "Opt-out via WORKFLOWS_SKIP_TESTS"
else
  log_fail "Opt-out via WORKFLOWS_SKIP_TESTS - Expected skip message"
fi

# Test 7: Safe override validation (valid command)
echo "--- Test: Valid override command ---"
((TOTAL++))
test_dir="$(mktemp -d)"
setup_green_tests "$test_dir"
output=$(WORKFLOWS_TEST_CMD="npm test" REPO_ROOT="$test_dir" bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q "npm test"; then
  log_pass "Valid override command accepted"
else
  log_fail "Valid override command - Expected command to be used"
fi

# Test 8: Safe override validation (invalid command rejected)
echo "--- Test: Invalid override command rejected ---"
((TOTAL++))
test_dir="$(mktemp -d)"
setup_green_tests "$test_dir"
output=$(WORKFLOWS_TEST_CMD="rm -rf /" REPO_ROOT="$test_dir" bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q "rejecting.*not a recognized test command"; then
  log_pass "Invalid override command rejected"
else
  log_fail "Invalid override command - Expected rejection message"
  echo "Output: $output"
fi

# Test 9: Unsafe characters in override rejected
echo "--- Test: Unsafe characters rejected ---"
((TOTAL++))
test_dir="$(mktemp -d)"
setup_green_tests "$test_dir"
output=$(WORKFLOWS_TEST_CMD='npm test; rm -rf /' REPO_ROOT="$test_dir" bash "$HOOK_SCRIPT" 2>&1) || true
if echo "$output" | grep -q "rejecting.*unsafe characters"; then
  log_pass "Unsafe characters rejected"
else
  log_fail "Unsafe characters - Expected rejection message"
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
