# Delegation Prompt Format

Use this 7-section structure for all Codex delegations. Include enough context for a stateless expert to act without follow-up.

```
1. TASK: [One sentence. Atomic and specific]

2. EXPECTED OUTCOME: [What success looks like]

3. CONTEXT:
   - Current state: [what exists now]
   - Relevant code: [file paths or snippets]
   - Background: [why this matters]

4. CONSTRAINTS:
   - Technical: [versions, dependencies]
   - Patterns: [conventions to follow]
   - Limitations: [what cannot change]

5. MUST DO:
   - [Requirement 1]
   - [Requirement 2]

6. MUST NOT DO:
   - [Forbidden action 1]
   - [Forbidden action 2]

7. OUTPUT FORMAT:
   - [Advisory or Implementation format from the expert prompt]
```

## Reminders
- Always include **MODE** (Advisory or Implementation).
- Always include file paths when referencing code.
- If asking for implementation, require a list of modified files + verification.
