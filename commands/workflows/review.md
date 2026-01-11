---
allowed-tools: Read, Glob, Grep, Bash, TodoWrite
argument-hint: [review-target]
description: Workflows review: run a focused review and log findings as TodoWrite items.
---

You are invoking **workflows-review** for `$ARGUMENTS` (default: current branch diff).

1) Determine the review target:
   - If a PR URL/number or branch is provided, use that.
   - Otherwise review the current branch diff against main.
2) Collect context: key files changed, tests touched, risky areas.
3) Always run a Codex adversarial review via `/claude-delegator:task` (read-only). If the command isn't available, note it and continue with native review.

Codex task template (fill in, keep concise):
```
/claude-delegator:task
TASK: Adversarial code review for <target>
CONTEXT: <scope summary + key files + known risks>
FOCUS: correctness, security, performance, edge cases, unsafe assumptions
OUTPUT: bullets with severity (P1/P2/P3), file:line when possible, and a short rationale. If none, say "No findings".
CONSTRAINTS: read-only, no refactors, no style nitpicks.
```
4) If the change touches security/perf hotspots (auth/permissions, crypto/secrets, payments, migrations, concurrency, caching, query hot paths, data integrity), run an additional Codex spotlight pass focused on that domain.
5) Run native review passes (correctness, security, performance, maintainability).
6) Dispatch relevant review agents under `agents/review/` in parallel and merge their findings with Codex output (dedupe).
7) For each finding, create a TodoWrite item:
   - content: "[P1|P2|P3] <short finding> — <file/area>"
   - status: pending
8) If there are no findings, state that explicitly.
