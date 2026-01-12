# Gap & Missing Features Ledger

**Generated**: 2026-01-11

## Summary by Severity

| Severity | Count | Description |
|----------|-------|-------------|
| P0 | 0 | Critical: security vulnerability |
| P1 | 1 | High: TOCTOU race in test cache |
| P2 | 11 | Medium: Info disclosure, robustness, maintenance, UX, routing |
| P3 | 1 | Low: Security footgun (Codex bypass) |

## P0 - Critical Issues

### GAP-001: install.sh Does Not Exist
- **Status**: RESOLVED
- **Evidence**:
  - `install.sh` exists at repo root
  - `tests/structure_test.sh` asserts `install.sh` exists

### GAP-002: Command Injection via WORKFLOWS_TEST_CMD
- **Status**: RESOLVED
- **Evidence**: hooks/workflows/require-green-tests.sh now validates `WORKFLOWS_TEST_CMD`/`SUPERPOWERS_TEST_CMD` (rejects unsafe characters + non-test commands) and shells out via a safely-quoted `bash -lc` command

## P1 - High Priority Issues

### GAP-003: Code Execution via State File Sourcing
- **Status**: RESOLVED
- **Evidence**: hooks/workflows/require-green-tests.sh no longer `source`s the state file; it parses expected keys and validates values

### GAP-004: TOCTOU Race in Test Cache
- **Type**: Security footgun / Reliability gap
- **Severity**: P1
- **Evidence**: hooks/workflows/require-green-tests.sh caches `PREV_STATUS`, `PREV_CMD_HASH`, and `PREV_MTIME` and compares `PREV_MTIME` to the newest tracked file mtime; there is no locking around the cache check/update
- **Impact**: Tests may be skipped when the working tree changes between cache check and cache write
- **Minimal Fix**: Add file lock or atomic cache update
- **Verification**: Manual race condition test

### GAP-005: No Automated Installation Verification
- **Status**: RESOLVED
- **Evidence**: `.github/workflows/ci.yml` now runs `structure_test.sh` and `schema_test.py` on push/PR to main

## P2 - Medium Priority Issues

### GAP-006: Information Disclosure in Logs
- **Type**: Security footgun
- **Severity**: P2
- **Evidence**: hooks/workflows/require-green-tests.sh prints test output to console (now truncated by default via `WORKFLOWS_TEST_MAX_OUTPUT_LINES`, default 200)
- **Impact**: Test output may contain secrets, API keys, or sensitive data
- **Minimal Fix**: Filter sensitive patterns and/or default to less verbose output (opt-in to full output)
- **Verification**: Review logged output for sensitive data patterns

### GAP-007: Temp File Permissions
- **Type**: Security footgun
- **Severity**: P2
- **Status**: RESOLVED
- **Evidence**: hooks/workflows/require-green-tests.sh sets `umask 077` before creating state/output files

### GAP-008: API Key Examples in Docs
- **Type**: Security footgun
- **Severity**: P2
- **Status**: RESOLVED / NOT APPLICABLE
- **Evidence**: config/delegator/mcp-servers.example.json does not include API keys (Codex CLI auth uses `codex login`)

### GAP-009: Missing Dependency Checks
- **Type**: Reliability gap
- **Severity**: P2
- **Evidence**:
  - todo-enforcer.sh checks for `jq` but only logs to `~/.claude/hooks/todo-enforcer.log` and exits 0 (no user-facing warning)
  - Python hooks rely on `python3` at runtime; manual install path does not include a preflight check
- **Impact**: Silent failures if dependencies missing
- **Minimal Fix**: Add dependency checks at script start
- **Verification**:
  ```bash
  # Hide jq temporarily and confirm the missing-dependency path is surfaced (or at least logged)
  PATH="/usr/bin:/bin" ./hooks/todo-enforcer.sh || true
  tail -n 20 ~/.claude/hooks/todo-enforcer.log || true
  ```

### GAP-010: No Schema Validation for Config
- **Type**: Maintenance gap
- **Severity**: P2
- **Evidence**: No formal JSON schema for config/delegator/*.json files (basic validation exists in tests/schema_test.py)
- **Impact**: Invalid config not caught until runtime
- **Minimal Fix**: Add JSON schemas and validation script
- **Verification**:
  ```bash
  python3 tests/schema_test.py
  ```

## Routing/Hook Gaps

### GAP-011: No Hook Firing on Abort
- **Type**: Hook gap
- **Severity**: P2
- **Evidence**: User Ctrl+C triggers Stop hooks normally
- **Impact**: Actually NOT a gap - Stop hooks fire on all exits including abort
- **Status**: Verified working as expected

### GAP-012: No Preflight Hook
- **Status**: RESOLVED
- **Evidence**: PreToolUse hook implemented in `hooks/parallel-dispatch-guide.py`
- **Resolution**: Claude Code DOES support PreToolUse hooks. Created auto-dispatch hook that intercepts Read/Grep/Glob/Bash and dispatches parallel agents when review/exploration context is detected.

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

## Routing Gaps (Pass 1)

### GAP-015: Review Agent Dispatch is All-or-Nothing
- **Type**: Routing gap
- **Severity**: P2
- **Evidence**: /workflows/review dispatches all review agents in parallel
- **Impact**: Slow/redundant reviews for simple changes; no filtering by file type
- **Minimal Fix**: Add file-type filtering or user-selectable agent subset
- **Verification**: Review dispatch logic in commands/workflows/review.md

### GAP-016: No Explicit Routing for Incremental Work
- **Type**: Routing gap
- **Severity**: P2
- **Evidence**: No "resume plan" or "continue from task N" command
- **Impact**: If session drops mid-task, user must manually re-invoke /workflows/work
- **Minimal Fix**: Add /workflows/resume command or plan state persistence
- **Verification**: Test session recovery after interruption

### GAP-017: Inconsistent Tool Allowlists Across Commands
- **Type**: Routing gap
- **Severity**: P2
- **Evidence**: Commands have different tool sets; no unified policy
- **Impact**: Confusion about what's possible per command
- **Minimal Fix**: Document tool policy per command; consider unified base set
- **Verification**: Review coverage-matrix.md Command → Allowed Tools Matrix

### GAP-018: Unbounded Debug Logging
- **Type**: Reliability gap
- **Severity**: P2
- **Evidence**: hooks/check-comments.py appends to ~/.claude/hooks/debug.log indefinitely
- **Impact**: Log file can grow without bound, consuming disk space
- **Minimal Fix**: Add log rotation or size limit
- **Verification**: Check log file size after extended use

### GAP-019: No Documentation of Hook Ordering Guarantees
- **Type**: Documentation gap
- **Severity**: P2
- **Evidence**: Stop hooks run in parallel but ordering not documented
- **Impact**: Users may assume sequential execution
- **Minimal Fix**: Document parallel execution in system-map.md
- **Verification**: Verify settings.json.example comments

### GAP-020: Codex MCP Tool Bypass
- **Type**: Security footgun
- **Severity**: P3
- **Evidence**: mcp__codex__codex is callable directly, bypassing 7-section prompt structure
- **Impact**: Users can delegate with arbitrary prompts, inconsistent with delegation-format.md
- **Minimal Fix**: Document intended usage; consider wrapper validation
- **Verification**: Review commands/claude-delegator/task.md enforcement

## Gap Matrix

| Gap ID | Type | Severity | Fix Complexity | Automated Verification |
|--------|------|----------|----------------|------------------------|
| GAP-001 | Broken wiring | RESOLVED | Medium | Yes |
| GAP-002 | Security | RESOLVED | Low | Yes |
| GAP-003 | Security | RESOLVED | Low | Yes |
| GAP-004 | Security | P1 | Medium | Manual |
| GAP-005 | Verification | RESOLVED | Medium | Yes |
| GAP-006 | Security | P2 | Low | Manual |
| GAP-007 | Security | RESOLVED | Low | Yes |
| GAP-008 | Security | RESOLVED | Low | Yes |
| GAP-009 | Reliability | P2 | Low | Yes |
| GAP-010 | Maintenance | P2 | Medium | Yes |
| GAP-013 | UX | P2 | Low | Manual |
| GAP-014 | UX | P2 | Low | Manual |
| GAP-015 | Routing | P2 | Medium | Manual |
| GAP-016 | Routing | P2 | Medium | Manual |
| GAP-017 | Routing | P2 | Low | Manual |
| GAP-018 | Reliability | P2 | Low | Yes |
| GAP-019 | Documentation | P2 | Low | Manual |
| GAP-020 | Security | P3 | Low | Manual |
