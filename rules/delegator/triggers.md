# Delegation Triggers

Check for these triggers on every request. If a trigger matches, delegate to the appropriate Codex expert.

## Explicit Requests (highest priority)
- "ask GPT", "ask Codex", "consult GPT", "Codex review"
- "review this plan" -> Plan Reviewer
- "review this code" / "review this PR" -> Code Reviewer
- "security review" / "is this secure" / "threat model" -> Security Analyst
- "analyze scope" / "clarify scope" / "what am I missing" -> Scope Analyst
- "architecture" / "tradeoffs" / "design" -> Architect

## Semantic Triggers
### Architecture & Design -> Architect
- system design decisions
- tradeoff analysis
- multi-service or cross-boundary changes
- 2+ failed fix attempts

### Plan Validation -> Plan Reviewer
- before executing multi-step work
- user asks for plan completeness or validation

### Requirements Analysis -> Scope Analyst
- ambiguous requests
- multiple plausible interpretations
- unclear success criteria

### Code Review -> Code Reviewer
- review requests
- pre-merge or post-implementation checks
- correctness/perf concerns

### Security -> Security Analyst
- authn/authz changes
- PII/credentials handling
- new public endpoints
- data exposure risk

## Default Rule
If no trigger matches, handle the task directly.
