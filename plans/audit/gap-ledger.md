# Gap Ledger

**Last Updated:** 2026-01-13 (Pass 4)

## Summary

| Severity | Open | Resolved | Total |
|----------|------|----------|-------|
| P0 (Critical) | 0 | 0 | 0 |
| P1 (High) | 1 | 4 | 5 |
| P2 (Medium) | 3 | 4 | 7 |
| P3 (Low) | 0 | 1 | 1 |

---

## P1 - High Priority

### GAP-001: keyword-detector only suggests, does not enforce
**Status:** RESOLVED (Pass 3)
**Resolution:** PreToolUse hook (`parallel-dispatch-guide.py`) now reads context flags set by keyword-detector and auto-dispatches agents when score >= 3.

**How it works:**
1. UserPromptSubmit: keyword-detector writes flags to `~/.claude/hooks/state/session-context.json`
2. PreToolUse: parallel-dispatch-guide reads flags, calculates score, dispatches agents
3. Score thresholds: review_security=3, review_performance=3, exploration_mode=2, etc.
4. Agents dispatched in background mode automatically

**Evidence:**
- `hooks/keyword-detector.py:100-168` - writes context flags
- `hooks/parallel-dispatch-guide.py:82-93` - reads context flags
- `hooks/parallel-dispatch-guide.py:237-245` - auto-dispatch logic

**Remaining concern:** Model can still ignore suggestions, but enforcement is now partial via PreToolUse

---

### GAP-004: TOCTOU race in require-green-tests.sh cache
**Status:** OPEN
**Risk:** Cache check (mtime comparison) can pass while file is being modified
**Evidence:** `hooks/workflows/require-green-tests.sh:195-198`
```bash
if [[ "$PREV_STATUS" == "green" && -n "$CMD_HASH" && "$PREV_CMD_HASH" == "$CMD_HASH" && "$PREV_MTIME" -ge "$LATEST_MTIME" ]]; then
```
**Failing Test Idea:**
```bash
# Race condition test
touch test.ts && sleep 0.1 && echo "pass" > .state
# Immediately modify test.ts while cache says "green"
echo "fail" >> test.ts
./require-green-tests.sh  # Should run tests, but may use cache
```
**Fix:** Add file hash comparison, not just mtime

---

### GAP-009: Missing dependency check for jq
**Status:** RESOLVED (Pass 4)
**Resolution:** `die()` function in todo-enforcer.sh now outputs a proper block decision JSON instead of silently exiting with code 0.

**Evidence:**
- `hooks/todo-enforcer.sh:24-38` - die() now outputs `{"decision": "block", "reason": "..."}` using printf fallback when jq is unavailable
- Integration test added: `tests/todo_enforcer_test.sh`

---

## P2 - Medium Priority

### GAP-006: Information disclosure in debug logs
**Status:** RESOLVED (Pass 4)
**Resolution:** All Python hooks now include `rotate_debug_log()` function that truncates log files at 10MB.

**Evidence:**
- `hooks/keyword-detector.py:40-52` - rotate_debug_log() keeps last 1MB when file exceeds 10MB
- `hooks/parallel-dispatch-guide.py:41-53` - same implementation
- `hooks/check-comments.py:34-46` - same implementation
- All hooks call cleanup functions at startup in main()

---

### GAP-013: Unclear skill activation semantics
**Status:** OPEN
**Risk:** Skills activate via implicit context matching, not explicit registration
**Evidence:** Skills have `USE WHEN` clauses in description but no code enforces them
**Failing Test Idea:** N/A (design documentation needed)
**Fix:** Document skill activation mechanism clearly

---

### GAP-015: Review agent dispatch documentation mismatch
**Status:** RESOLVED (Pass 2)
**Resolution:** Routing IS conditional per file type - see `commands/workflows/review.md:18-31`
**Evidence:** Agent Routing Table in review.md shows file-type based selection

---

### GAP-016: No explicit routing for resume/incremental work
**Status:** OPEN
**Risk:** `/workflows/resume` mentioned but not implemented as command
**Evidence:** File `commands/workflows/resume.md` exists but not in graph routing
**Failing Test Idea:**
```bash
# Verify resume command exists and routes correctly
claude /workflows/resume
# Should load and continue previous plan
```
**Fix:** Add resume command to graph and verify implementation

---

### GAP-017: Inconsistent tool allowlists across commands
**Status:** OPEN
**Risk:** Some commands have `Task` in allowedTools, others don't
**Evidence:**
- `/workflows/review` has `Task` (line 2)
- `/workflows/plan` does NOT have `Task`
**Failing Test Idea:**
```python
# Compare tool allowlists for consistency
plan_tools = extract_allowed_tools("commands/workflows/plan.md")
review_tools = extract_allowed_tools("commands/workflows/review.md")
# Both should have Task for subagent dispatch
```
**Fix:** Audit and standardize tool allowlists

---

### GAP-018: Unbounded debug logging
**Status:** RESOLVED (Pass 4)
**Resolution:** See GAP-006 - all hooks now include log rotation at 10MB limit.
**See also:** GAP-006

---

### GAP-019: No documentation of hook ordering guarantees
**Status:** RESOLVED (Pass 4)
**Resolution:** README.md Hooks section now documents:
- Stop hooks execute sequentially in settings.json order
- Default order: tests → lint → types → todos
- Each hook can block independently

**Evidence:**
- `README.md:360-367` - Stop Hook Ordering documentation
- `settings.json.example:35-68` - Stop hooks in defined order

---

### GAP-020: Codex MCP tool can bypass 7-section structure
**Status:** OPEN
**Risk:** Direct `mcp__codex__codex` calls don't enforce delegation format rules
**Evidence:** `commands/claude-delegator/task.md` defines format but tool doesn't validate
**Failing Test Idea:**
```python
# Call codex tool with malformed prompt
result = mcp__codex__codex(prompt="just do something")
# Should reject or warn about missing sections
```
**Fix:** Add validation in task.md prompt or wrapper

---

## P3 - Low Priority

### GAP-012: No PreToolUse hook for parallel agent auto-dispatch
**Status:** RESOLVED (Pass 3)
**Resolution:** `hooks/parallel-dispatch-guide.py` implemented as PreToolUse hook.

**Implementation details:**
- Matcher: `Read|Grep|Glob|Bash`
- Reads context flags from keyword-detector
- Score-based dispatch (MIN_SCORE_TO_DISPATCH = 3)
- Tracks exploration count in session window (60 seconds)
- Dispatches max 5 agents per session
- Agents: security-sentinel, performance-oracle, architecture-strategist, code-simplicity, pattern-recognition, codebase-search, open-source-librarian

**Evidence:**
- `hooks/parallel-dispatch-guide.py` (251 lines)
- `settings.json.example:13-22` - PreToolUse configuration

---

### GAP-021: autoDispatch is not a valid Claude Code API field
**Status:** RESOLVED (Pass 4)
**Resolution:** parallel-dispatch-guide.py now uses only valid PreToolUse API fields.

The previous implementation used `autoDispatch`, `dispatchMode`, and `systemMessage` fields which are NOT supported by Claude Code. These have been removed.

**Valid PreToolUse fields (per Claude Code docs):**
- `permissionDecision`: "allow" | "deny" | "ask"
- `permissionDecisionReason`: string
- `modifiedToolInput`: modified tool input (v2.0.10+)

**Evidence:**
- `hooks/parallel-dispatch-guide.py:176-205` - now uses only permissionDecision and permissionDecisionReason
- Advisory text provided via permissionDecisionReason field
- README.md updated with note about advisory-only nature

---

### GAP-022: No timeout in require-green-tests.sh
**Status:** RESOLVED (Pass 4)
**Resolution:** Added timeout and opt-out functionality to require-green-tests.sh.

**Features added:**
- `WORKFLOWS_TEST_TIMEOUT` env var (default: 300 seconds)
- `WORKFLOWS_SKIP_TESTS=true` opt-out flag
- Uses GNU `timeout` or macOS `gtimeout` when available
- Handles timeout exit code 124 properly

**Evidence:**
- `hooks/workflows/require-green-tests.sh:6-13` - timeout and opt-out configuration
- `hooks/workflows/require-green-tests.sh:254-278` - timeout wrapper implementation
- Integration tests added: `tests/require_green_tests_test.sh`

---

## Audit Trail

| Pass | Date | Gaps Added | Gaps Resolved |
|------|------|------------|---------------|
| 1 | 2026-01-11 | GAP-004, 006, 009, 013, 015-020 | - |
| 2 | 2026-01-12 | GAP-001, 012 | GAP-015 |
| 3 | 2026-01-12 | - | GAP-001, GAP-012 |
| 4 | 2026-01-13 | GAP-021, GAP-022 | GAP-006, GAP-009, GAP-018, GAP-019, GAP-021, GAP-022 |
