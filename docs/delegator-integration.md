# claude-delegator Integration

This config vendors claude-delegator rules/prompts/commands and maps Codex experts to native review agents.

## What You Get
- Codex MCP wiring (setup/uninstall commands)
- Delegation rules + triggers
- Custom expert prompts aligned with this repo's review style
- Mapping between Codex experts and native review agents

## Setup
1) Run `/claude-delegator/setup`
2) Restart Claude Code
3) Ensure Codex is authenticated: `codex login`

## Usage
- `/claude-delegator/task` to delegate a task to a Codex expert

## Expert Mapping
See `config/delegator/experts.json` for the canonical map.

Quick reference:
- Architect -> `agents/review/architecture-strategist.md`
- Plan Reviewer -> `skills/writing-plans` + `skills/planning-with-files`
- Scope Analyst -> `commands/interview.md`
- Code Reviewer -> `agents/review/code-simplicity.md`, `agents/review/pattern-recognition.md`
- Security Analyst -> `agents/review/security-sentinel.md`

## Prompt Location
Custom prompts are installed to:
- `~/.claude/prompts/delegator/*.md`

Rules expect those paths when delegating.

## Triggers
Delegation triggers live in:
- `rules/delegator/triggers.md`
- `rules/delegator/orchestration.md`

Use explicit phrasing like "ask Codex to review this" to force delegation.

## Notes
- Delegation is stateless; include full context in each prompt.
- Advisory mode defaults to `read-only` sandbox.
- Implementation mode uses `workspace-write` sandbox.
