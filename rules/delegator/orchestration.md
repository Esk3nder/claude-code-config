# Delegator Orchestration

Use Codex experts via MCP for high-stakes reasoning, reviews, and ambiguous scope. Delegation is **stateless** - include all relevant context every time.

## Available Tool
- `mcp__codex__codex` - delegate to a Codex expert (stateless)

## Expert Prompt Files (customized)
Read the expert prompt before every delegation:
- Architect: `~/.claude/prompts/delegator/architect.md`
- Plan Reviewer: `~/.claude/prompts/delegator/plan-reviewer.md`
- Scope Analyst: `~/.claude/prompts/delegator/scope-analyst.md`
- Code Reviewer: `~/.claude/prompts/delegator/code-reviewer.md`
- Security Analyst: `~/.claude/prompts/delegator/security-analyst.md`

## Mapping to Native Review Agents (when doing /workflows/review)
- Architect -> `agents/review/architecture-strategist.md`
- Code Reviewer -> `agents/review/code-simplicity.md`, `agents/review/pattern-recognition.md`
- Security Analyst -> `agents/review/security-sentinel.md`
- Plan Reviewer -> `skills/writing-plans` + `skills/planning-with-files`
- Scope Analyst -> `commands/interview.md`

## Delegation Flow
1) Identify the best expert for the task.
2) Read the expert's prompt file.
3) Choose mode:
   - Advisory -> `sandbox: read-only`
   - Implementation -> `sandbox: workspace-write`
4) Build a 7-section delegation prompt (see `rules/delegator/delegation-format.md`).
5) Call `mcp__codex__codex` with:
   - `prompt`: your 7-section prompt
   - `developer-instructions`: full contents of the expert prompt
   - `sandbox` and `cwd`
6) Synthesize the response. Do not paste raw output.

## Retry Policy (Implementation)
If implementation fails verification, retry with full error context. Each retry is a new call with:
- original task
- what was tried
- exact error output
- files changed

## When NOT to Delegate
- trivial edits
- first attempt at simple fixes
- research tasks (use native tools)
- purely stylistic changes
