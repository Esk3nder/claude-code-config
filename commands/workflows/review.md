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
3) Always run a Codex adversarial review via `/claude-delegator/task` (read-only). If the command isn't available, note it and continue with native review.

Codex task template (fill in, keep concise):
```
/claude-delegator/task
1. TASK: Adversarial code review for <target>
2. EXPECTED OUTCOME: Issues list with severity and a verdict (APPROVE/REQUEST CHANGES/REJECT)
3. CONTEXT:
   - Current state: <scope summary + key files + known risks>
   - Relevant code: <paths or snippets>
   - Background: <why this review matters>
4. CONSTRAINTS:
   - Technical: read-only
   - Patterns: no refactors, no style nitpicks
   - Limitations: do not change unrelated code
5. MUST DO:
   - Prioritize correctness, security, performance
   - Include file:line when possible
6. MUST NOT DO:
   - Suggest stylistic changes
   - Invent missing context
7. OUTPUT FORMAT:
   - Summary, Findings (P1/P2/P3), Verdict
MODE: Advisory
```
4) If the change touches security/perf hotspots (auth/permissions, crypto/secrets, payments, migrations, concurrency, caching, query hot paths, data integrity), run an additional Codex spotlight pass focused on that domain.
5) Run native review passes (correctness, security, performance, maintainability).
6) Dispatch relevant review agents under `agents/review/` in parallel and merge their findings with Codex output (dedupe).
7) For each finding, create a TodoWrite item:
   - content: "[P1|P2|P3] <short finding> — <file/area>"
   - status: pending
8) If there are no findings, state that explicitly.
