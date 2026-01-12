---
name: ManagingPlans
description: Create and maintain persistent markdown plans for complex tasks. USE WHEN tasks span multiple steps OR files OR need structured approach OR user mentions planning.
---

# ManagingPlans

Create and maintain structured plans in `plans/{slug}.md`.

## Workflow Routing

| Workflow | Trigger | File |
|----------|---------|------|
| **CreatePlan** | "plan", "break down", "steps", "start planning" | Inline |
| **UpdatePlan** | "update plan", "mark done", "continue plan" | Inline |

## Creating Plans

1. Create `plans/{slug}.md` in the working directory.
   - Ensure `plans/` exists
   - Derive `{slug}` from the goal (lowercase, hyphen-separated, 3–6 words)
   - Prefix with `YYYYMMDD-`
2. Capture: goal (1 line), constraints, and success criteria.
3. List 4–8 tasks max, each with: action, target files, and verification/check.
4. Mark status boxes `[ ]` initially; keep tasks small and ordered.
5. Add a verification block (tests, linters, manual checks) to run before finishing.

## Maintaining Plans

- **Read before deciding** - refresh goals in attention window
- **Update after each phase** - mark [x] and change status
- **Capture research** in `notes.md` alongside plan
- **Document solutions** in `plans/solutions/` when problems solved

## The 3-File Pattern

- `plans/{slug}.md` - Task plan with checkboxes
- `notes.md` - Research and findings
- `plans/solutions/` - Captured solutions

## Examples

**Example 1: Feature planning**
```
User: "Plan the user authentication feature"
→ Invokes ManagingPlans
→ Creates plans/20260112-user-auth.md
→ Lists 5 tasks with verification steps
```

**Example 2: Complex investigation**
```
User: "Investigate and fix the performance issue"
→ Creates plan with investigation steps
→ Captures findings in notes.md
→ Updates plan as phases complete
```
