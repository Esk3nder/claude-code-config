# Gap & Missing Features Ledger

**Generated**: 2026-01-11

## Summary by Severity

| Severity | Count | Description |
|----------|-------|-------------|
| P0 | 2 | Critical: Security vulnerability, broken install |
| P1 | 3 | High: Security issues, missing automation |
| P2 | 5 | Medium: Info disclosure, robustness, UX |

## P0 - Critical Issues

### GAP-001: install.sh Does Not Exist
- **Type**: Broken wiring / False claim
- **Severity**: P0
- **Evidence**:
  - README.md line 5-8 references `./install.sh`
  - INSTALL.md line 5-8 references `./install.sh`
  - `find . -name "install.sh"` returns empty
- **Impact**: Users cannot use documented quick install method; immediate failure on clone
- **Minimal Fix**: Create install.sh that:
  1. Copies files to ~/.claude/
  2. Sets executable permissions on hooks
  3. Merges hook wiring into settings.json
- **Verification**:
  ```bash
  ./install.sh && test -f ~/.claude/hooks/keyword-detector.py
  ```

### GAP-002: Command Injection via WORKFLOWS_TEST_CMD
- **Type**: Security footgun
- **Severity**: P0
- **Evidence**: hooks/workflows/require-green-tests.sh lines 10-15, 50
  ```bash
  if [[ -n "${WORKFLOWS_TEST_CMD-}" ]]; then
    echo "$WORKFLOWS_TEST_CMD"  # Unvalidated
    return
  fi
  # ...
  OUTPUT=$(cd "$REPO_ROOT" && bash -lc "$TEST_CMD" 2>&1)  # Injection point
  ```
- **Impact**: Malicious .env file or environment can execute arbitrary commands
- **Minimal Fix**:
  1. Validate WORKFLOWS_TEST_CMD against allowlist of safe commands
  2. Or: remove env var override, only use lockfile detection
- **Verification**:
  ```bash
  WORKFLOWS_TEST_CMD="rm -rf /tmp/test; echo pwned" ./hooks/workflows/require-green-tests.sh
  # Should reject invalid command
  ```

## P1 - High Priority Issues

### GAP-003: Code Execution via State File Sourcing
- **Type**: Security footgun
- **Severity**: P1
- **Evidence**: hooks/workflows/require-green-tests.sh line 55
  ```bash
  source "$STATE_FILE"  # Sources .claude/.state/last_tests.env
  ```
- **Impact**: If attacker can write to .claude/.state/, arbitrary code execution
- **Minimal Fix**:
  1. Parse state file as key=value without sourcing
  2. Or: validate file contents before sourcing
- **Verification**:
  ```bash
  echo 'echo PWNED' > .claude/.state/last_tests.env
  ./hooks/workflows/require-green-tests.sh
  # Should not print PWNED
  ```

### GAP-004: TOCTOU Race in Test Cache
- **Type**: Security footgun / Reliability gap
- **Severity**: P1
- **Evidence**: hooks/workflows/require-green-tests.sh lines 60-70
  - Checks `LAST_SHA` against current SHA
  - Gap between check and test execution
- **Impact**: Test results can be poisoned; passing tests cached for failing code
- **Minimal Fix**: Add file lock or atomic cache update
- **Verification**: Manual race condition test

### GAP-005: No Automated Installation Verification
- **Type**: Verification gap
- **Severity**: P1
- **Evidence**: No CI workflow, no test script for installation
- **Impact**: Installation can silently fail; no regression detection
- **Minimal Fix**: Add scripts/verify-install.sh that checks:
  1. All files exist in ~/.claude/
  2. Hook scripts are executable
  3. settings.json has hook wiring
- **Verification**:
  ```bash
  ./scripts/verify-install.sh && echo "Install OK"
  ```

## P2 - Medium Priority Issues

### GAP-006: Information Disclosure in Logs
- **Type**: Security footgun
- **Severity**: P2
- **Evidence**: hooks/workflows/require-green-tests.sh line 65
  ```bash
  echo "$OUTPUT"  # Full test output to console
  ```
- **Impact**: Test output may contain secrets, API keys, or sensitive data
- **Minimal Fix**: Truncate output or filter sensitive patterns
- **Verification**: Review logged output for sensitive data patterns

### GAP-007: Temp File Permissions
- **Type**: Security footgun
- **Severity**: P2
- **Evidence**: State file created without explicit permissions
- **Impact**: Other users on shared system may read/write state
- **Minimal Fix**: `umask 077` before creating state files
- **Verification**: `ls -la .claude/.state/` should show 600 permissions

### GAP-008: API Key Examples in Docs
- **Type**: Security footgun
- **Severity**: P2
- **Evidence**: config/delegator/mcp-servers.example.json may show API key format
- **Impact**: Users might commit real keys if they modify example
- **Minimal Fix**: Use obviously fake keys like `sk-REPLACE_ME_NEVER_COMMIT`
- **Verification**: Grep for API key patterns

### GAP-009: Missing Dependency Checks
- **Type**: Reliability gap
- **Severity**: P2
- **Evidence**:
  - todo-enforcer.sh requires `jq` but doesn't check
  - Python hooks require `python3` but don't check
- **Impact**: Silent failures if dependencies missing
- **Minimal Fix**: Add dependency checks at script start
- **Verification**:
  ```bash
  # Remove jq temporarily
  PATH=/usr/bin ./hooks/todo-enforcer.sh
  # Should show clear error about missing jq
  ```

### GAP-010: No Schema Validation for Config
- **Type**: Maintenance gap
- **Severity**: P2
- **Evidence**: No JSON schema for config/delegator/*.json files
- **Impact**: Invalid config not caught until runtime
- **Minimal Fix**: Add JSON schemas and validation script
- **Verification**:
  ```bash
  ./scripts/validate-config.sh
  ```

## Routing/Hook Gaps

### GAP-011: No Hook Firing on Abort
- **Type**: Hook gap
- **Severity**: P2
- **Evidence**: User Ctrl+C triggers Stop hooks normally
- **Impact**: Actually NOT a gap - Stop hooks fire on all exits including abort
- **Status**: Verified working as expected

### GAP-012: No Preflight Hook
- **Type**: Feature gap
- **Severity**: P2
- **Evidence**: No PreToolUse hook type available
- **Impact**: Cannot validate/intercept tool calls before execution
- **Note**: This is a Claude Code platform limitation, not repo gap
- **Status**: Not actionable in this repo

## UX Gaps

### GAP-013: Unclear Skill Activation Semantics
- **Type**: UX gap
- **Severity**: P2
- **Evidence**: Skills activate via model context matching (implicit)
- **Impact**: Users can't predict what triggers what skill
- **Minimal Fix**: Add activation examples to each SKILL.md
- **Verification**: Manual testing of activation triggers

### GAP-014: No Progress Feedback During Test Run
- **Type**: UX gap
- **Severity**: P2
- **Evidence**: require-green-tests.sh runs tests synchronously with no progress
- **Impact**: Long test runs appear hung
- **Minimal Fix**: Add spinner or progress output
- **Verification**: Run with slow test suite, observe output

## Gap Matrix

| Gap ID | Type | Severity | Fix Complexity | Automated Verification |
|--------|------|----------|----------------|------------------------|
| GAP-001 | Broken wiring | P0 | Medium | Yes |
| GAP-002 | Security | P0 | Low | Yes |
| GAP-003 | Security | P1 | Low | Yes |
| GAP-004 | Security | P1 | Medium | Manual |
| GAP-005 | Verification | P1 | Medium | Yes |
| GAP-006 | Security | P2 | Low | Manual |
| GAP-007 | Security | P2 | Low | Yes |
| GAP-008 | Security | P2 | Low | Yes |
| GAP-009 | Reliability | P2 | Low | Yes |
| GAP-010 | Maintenance | P2 | Medium | Yes |
| GAP-013 | UX | P2 | Low | Manual |
| GAP-014 | UX | P2 | Low | Manual |
