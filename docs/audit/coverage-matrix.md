# Coverage Matrix

**Generated**: 2026-01-11 | Pass 1

## Legend

- **Trigger**: User action or event that initiates the flow
- **Route**: Dispatch mechanism that selects the handler
- **Module**: Skill/Agent/Command that handles the request
- **Lifecycle Stages**: Hooks that fire during the flow
- **Test Coverage**: Automated verification status

## Input → Routing → Module Matrix

| # | Trigger | Route | Module | Pre-Hook | Post-Hook | Stop-Hook | Test |
|---|---------|-------|--------|----------|-----------|-----------|------|
| 1 | Natural language "plan" | keyword-detector | skill:planning-with-files | keyword-detector.py | - | tests + todos | - |
| 2 | Natural language "debug" | keyword-detector | skill:systematic-debugging | keyword-detector.py | - | tests + todos | - |
| 3 | Natural language "test" | keyword-detector | skill:test-driven-development | keyword-detector.py | - | tests + todos | - |
| 4 | Natural language "parallel" | keyword-detector | skill:subagent-driven-development | keyword-detector.py | - | tests + todos | - |
| 5 | Natural language "verify" | keyword-detector | skill:verification-before-completion | keyword-detector.py | - | tests + todos | - |
| 6 | Natural language "review" | keyword-detector | skill:requesting-code-review | keyword-detector.py | - | tests + todos | - |
| 7 | Natural language "done/finish" | keyword-detector | skill:finishing-a-development-branch | keyword-detector.py | - | tests + todos | - |
| 8 | `/interview [topic]` | command-router | cmd:interview | keyword-detector.py | - | tests + todos | - |
| 9 | `/workflows/brainstorm [topic]` | command-router | cmd:workflows-brainstorm | keyword-detector.py | - | tests + todos | - |
| 10 | `/workflows/plan [file]` | command-router | cmd:workflows-plan | keyword-detector.py | check-comments.py (on Write) | tests + todos | - |
| 11 | `/workflows/work [file]` | command-router | cmd:workflows-work | keyword-detector.py | check-comments.py (on Edit) | tests + todos | - |
| 12 | `/workflows/review [target]` | command-router | cmd:workflows-review | keyword-detector.py | - | tests + todos | - |
| 13 | `/workflows/compound` | command-router | cmd:workflows-compound | keyword-detector.py | check-comments.py (on Write) | tests + todos | - |
| 14 | `/claude-delegator/setup` | command-router | cmd:delegator-setup | keyword-detector.py | - | tests + todos | - |
| 15 | `/claude-delegator/task [task]` | command-router | cmd:delegator-task | keyword-detector.py | - | tests + todos | - |
| 16 | `/claude-delegator/uninstall` | command-router | cmd:delegator-uninstall | keyword-detector.py | - | tests + todos | - |
| 17 | Write/Edit tool use | tool-use-event | hook:check-comments | - | check-comments.py | - | - |
| 18 | Session stop | stop-event | hook:require-green-tests | - | - | require-green-tests.sh | structure_test.sh |
| 19 | Session stop | stop-event | hook:todo-enforcer | - | - | todo-enforcer.sh | - |

## Command → Allowed Tools Matrix

| Command | Read | Glob | Grep | Write | Edit | Bash | TodoWrite | AskUserQuestion | mcp__codex__codex |
|---------|------|------|------|-------|------|------|-----------|-----------------|-------------------|
| /interview | ✓ | ✓ | ✓ | ✓ | ✓ | - | - | ✓ | - |
| /workflows/brainstorm | ✓ | ✓ | ✓ | - | - | - | - | ✓ | - |
| /workflows/plan | ✓ | ✓ | ✓ | ✓ | ✓ | - | - | - | - |
| /workflows/work | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - | - | - |
| /workflows/review | ✓ | ✓ | ✓ | - | - | ✓ | ✓ | - | - |
| /workflows/compound | ✓ | ✓ | ✓ | ✓ | ✓ | - | - | - | - |
| /claude-delegator/task | ✓ | - | - | - | - | ✓ | - | ✓ | ✓ |

## Review Agent Dispatch Matrix

| Agent | Always | Security Files | Perf Hotspot | Arch Change | Migration | Deploy | TS/TSX | Python | Rails | Frontend |
|-------|--------|----------------|--------------|-------------|-----------|--------|--------|--------|-------|----------|
| security-sentinel | - | ✓ | - | - | - | - | - | - | - | - |
| performance-oracle | - | - | ✓ | - | - | - | - | - | - | - |
| architecture-strategist | - | - | - | ✓ | - | - | - | - | - | - |
| data-migration-expert | - | - | - | - | ✓ | - | - | - | - | - |
| deployment-verification | - | - | - | - | - | ✓ | - | - | - | - |
| code-simplicity | ✓ | - | - | - | - | - | - | - | - | - |
| data-integrity-guardian | - | - | - | - | ✓ | - | - | - | - | - |
| pattern-recognition | ✓ | - | - | - | - | - | - | - | - | - |
| agent-native | - | - | - | - | - | - | - | - | - | - |
| typescript | - | - | - | - | - | - | ✓ | - | - | - |
| python | - | - | - | - | - | - | - | ✓ | - | - |
| rails | - | - | - | - | - | - | - | - | ✓ | - |
| dhh-rails | - | - | - | - | - | - | - | - | ✓ | - |
| frontend-races | - | - | - | - | - | - | - | - | - | ✓ |

## Expert Delegation Trigger Matrix

| Expert | Explicit Keyword | Semantic Trigger | Auto-Route Condition |
|--------|------------------|------------------|----------------------|
| architect | "architecture", "tradeoffs", "design" | System design decision | 2+ failed fix attempts |
| plan-reviewer | "review plan" | Before multi-step work | User requests plan check |
| scope-analyst | "analyze scope", "clarify scope" | Ambiguous request | Multiple interpretations |
| code-reviewer | "review code", "review PR" | Review request | Pre-merge check |
| security-analyst | "security review" | Auth/authz changes | PII handling, new endpoints |

## Lifecycle Stage Matrix

| Stage | Event | Handler | Blocking | Bypass Condition |
|-------|-------|---------|----------|------------------|
| Pre-Prompt | UserPromptSubmit | keyword-detector.py | No | No keywords match |
| Post-Tool | PostToolUse (Write/Edit) | check-comments.py | No | Comment ratio ≤ 25% |
| Pre-Exit | Stop | require-green-tests.sh | Yes | No test framework detected |
| Pre-Exit | Stop | todo-enforcer.sh | Yes | 10 consecutive blocks (safety valve) |

## Uncovered Rows

| # | Gap | Missing Coverage | Priority |
|---|-----|------------------|----------|
| 1 | No test for keyword-detector keyword completeness | Manual verification only | P2 |
| 2 | No test for review agent conditional dispatch | Dispatch logic not verified | P2 |
| 3 | No test for Codex unavailability fallback | Silent failure possible | P2 |
| 4 | No test for skill activation semantics | Model-dependent, untestable | N/A |
| 5 | No test for hook ordering | Parallel execution assumed | P3 |
| 6 | No test for check-comments.py log rotation | Unbounded growth | P3 |

## Test File Coverage

| Test File | Covers | Type |
|-----------|--------|------|
| tests/structure_test.sh | File existence, permissions | Structure |
| tests/schema_test.py | JSON schema validation | Schema |
| - | Hook behavior | Missing |
| - | Command routing | Missing |
| - | Agent dispatch | Missing |
| - | Expert selection | Missing |
