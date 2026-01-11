# Model Selection (Codex Experts)

Use Codex experts for complex reasoning, review, or high-risk changes.

## Expert Directory
| Expert | Specialty | Best For |
|---|---|---|
| Architect | System design | Architecture, tradeoffs, complex debugging |
| Plan Reviewer | Plan validation | Reviewing plans before execution |
| Scope Analyst | Requirements analysis | Ambiguity detection, pre-planning |
| Code Reviewer | Code quality | Bug finding, maintainability, review |
| Security Analyst | Security | Threat modeling, hardening, auth changes |

## Modes
- Advisory -> `sandbox: read-only` (analysis, review, recommendations)
- Implementation -> `sandbox: workspace-write` (explicitly asked to change code)

## Use Codex When
- the decision is architectural or high impact
- failure risk is high (security, data integrity, migrations)
- the plan is unclear or may be incomplete
- you need a second-pass adversarial review

## Do NOT Use Codex When
- trivial edits
- first attempt at simple fixes
- pure research or documentation lookups
