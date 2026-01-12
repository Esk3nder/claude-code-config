# Plans Directory

This directory contains **internal planning and design documents** for the claude-code-config project.

## Purpose

Plans document **how we're building** the system:
- Feature planning and task breakdowns
- Design decisions and architectural choices
- Work backlogs and roadmaps
- Audit results and analysis
- Implementation strategies

## Structure

```
plans/
├── README.md                               # This file
├── backlog.md                              # Work backlog and priorities
├── metrics-schema.md                       # Measurement and tracking design
├── 20260112-output-format-standardization.md  # Active: Standardizing agent outputs
├── audit/                                  # Analysis and audits
│   ├── claims-ledger.md                   # Feature claim verification
│   ├── coverage-matrix.md                 # Component coverage tracking
│   ├── gap-ledger.md                      # Identified gaps
│   ├── system-map.md                      # System architecture map
│   └── ...
└── solutions/                              # Solved problems (using Compound workflow)
    └── (categorized solution documents)
```

## File Naming Convention

### Active Plans
Use date prefix + descriptive slug:
```
YYYYMMDD-feature-name.md
YYYYMMDD-design-decision.md
```

**Example**: `20260112-output-format-standardization.md`

### Permanent Planning Docs
Use descriptive names without dates:
```
backlog.md
metrics-schema.md
roadmap.md
```

## What Goes Here vs. docs/

| Content Type | Location | Example |
|--------------|----------|---------|
| **Planning/Design** | `plans/` | Architecture decisions, backlogs, audits |
| **User Documentation** | `docs/` | Setup guides, integration docs, test plans |

**Rule of thumb**: If it's **for the team building** the system → `plans/`. If it's **for users** of the system → `docs/`.

## Workflow Integration

Plans integrate with the `ManagingPlans` skill:

1. **Creating a plan**:
   ```
   User: "Plan the feature implementation"
   → ManagingPlans creates plans/YYYYMMDD-feature-name.md
   ```

2. **Executing a plan**:
   ```
   User: "Work on the plan"
   → ExecutingPlans reads plans/YYYYMMDD-feature-name.md
   → Updates checkboxes as tasks complete
   ```

3. **Documenting solutions**:
   ```
   → Compound skill captures solved problems
   → Writes to plans/solutions/category/problem-name.md
   ```

## Active Plans

| Plan | Status | Description |
|------|--------|-------------|
| `20260112-output-format-standardization.md` | 🚧 In Progress | Standardizing agent output formats |
| `backlog.md` | 📋 Ongoing | Master backlog of work items |

## Completed Plans

Completed plans stay in this directory as historical record. They show the evolution of decisions and implementations.

## Contributing

When starting new work:
1. Create a plan file: `plans/YYYYMMDD-your-feature.md`
2. Use the plan structure from `ManagingPlans` skill
3. Update the plan as work progresses
4. When complete, commit both the plan and the implementation

---

**Last Updated**: 2026-01-12
