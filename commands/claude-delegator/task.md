---
allowed-tools: Read, AskUserQuestion, Bash, mcp__codex__codex
argument-hint: [task]
description: Delegate a task to a Codex expert using custom prompts
---

You are invoking **claude-delegator task**. Route the request to the correct Codex expert and synthesize the result.

If `$ARGUMENTS` is empty, ask the user for a task description and any relevant files or context.

## Steps
1) Identify expert (Architect / Plan Reviewer / Scope Analyst / Code Reviewer / Security Analyst).
2) Read the expert prompt from `~/.claude/prompts/delegator/<expert>.md`.
3) Choose mode:
   - Advisory -> `sandbox: read-only`
   - Implementation -> `sandbox: workspace-write`
4) Build a 7-section prompt (see `rules/delegator/delegation-format.md`). If the user already provided a structured prompt, reuse it.
5) Call `mcp__codex__codex` with:
   - `prompt`
   - `developer-instructions` (expert prompt file contents)
   - `sandbox`
   - `cwd`
6) Synthesize the response; do not paste raw output verbatim.

If the prompt file is missing, tell the user to run `/claude-delegator/setup` first.
