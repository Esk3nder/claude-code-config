# Agent Capability Matrix

Quick reference for all available agents, their capabilities, and when to use them.

## Overview

Agents are specialized subprocesses invoked via the `Task` tool. They have constrained toolsets, specific models, and focused responsibilities.

## Agent Capabilities

### Core Agents

| Agent | Model | Can Write | Has Skill Tool | Use When | Cost |
|-------|-------|-----------|----------------|----------|------|
| **codebase-search** | haiku | ❌ | ✅ | Find files, locate implementations, discover patterns | $ |
| **open-source-librarian** | sonnet | ❌ | ✅ | External docs, OSS examples, library research | $$ |
| **oracle** | opus | ❌ | Task tool | Architecture decisions, debugging after 3+ failures, adversarial review | $$$$ |
| **tech-docs-writer** | sonnet | ✅ | ❌ | Generate README, API docs, guides | $$ |
| **media-interpreter** | sonnet | ❌ | ✅ | Analyze images, diagrams, screenshots | $$ |

### Review Agents

All review agents:
- Model: **haiku** (cheap, fast)
- Tools: **Read, Glob, Grep, Bash** (read-only)
- Output: **Standardized findings format** (see below)

| Agent | Focus Area | Invoke When |
|-------|------------|-------------|
| **security-sentinel** | Auth, injection, secrets, crypto | Security-sensitive changes |
| **architecture-strategist** | Boundaries, coupling, maintainability | System design changes |
| **performance-oracle** | Hot paths, scaling, resource usage | Performance-critical code |
| **code-simplicity** | Complexity reduction, clarity | Complex logic added |
| **pattern-recognition** | Anti-patterns, consistency | Codebase-wide refactors |
| **data-integrity-guardian** | Correctness, constraints, consistency | Data model changes |
| **data-migration-expert** | Migration safety, reversibility | Database migrations |
| **deployment-verification** | Configs, flags, operational readiness | Deploy/config changes |
| **typescript** | Type safety, TS best practices | `.ts`, `.tsx` files |
| **python** | Idioms, typing, runtime correctness | `.py` files |
| **rails** | Rails conventions, performance | `.rb` files, Gemfile |
| **dhh-rails** | Convention over configuration | Conventional Rails apps |
| **frontend-races** | Async race conditions, state bugs | React/frontend async code |
| **agent-native** | Prompt safety, determinism | Agent/prompt files |

## Tool Access Matrix

| Agent | Read | Write | Bash | Grep | Glob | LSP | Skill | Task | MCP |
|-------|------|-------|------|------|------|-----|-------|------|-----|
| codebase-search | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| open-source-librarian | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| oracle | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| tech-docs-writer | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| media-interpreter | ✅ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ |
| **All review agents** | ✅ | ❌ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

**Legend**:
- **Skill**: Can invoke other skills/workflows
- **Task**: Can spawn other agents
- **MCP**: Has access to MCP server tools

## Output Formats

### Review Agents (Standardized)

All agents under `agents/review/` use this format:

```
Findings:
- [P1] <critical issue> — <file:line> — <rationale>
- [P2] <important issue> — <file:line> — <rationale>
- [P3] <nice-to-have> — <file:line> — <rationale>
```

If no issues found:
```
No findings.
```

**Priority levels**:
- **P1**: Critical - blocks merge, must fix
- **P2**: Important - should fix before merge
- **P3**: Nice-to-have - optional improvement

### codebase-search (Structured XML)

```xml
<analysis>
**Literal Request**: [what they asked]
**Actual Need**: [underlying goal]
**Success Looks Like**: [actionable result]
</analysis>

<results>
<files>
- /absolute/path/to/file1.ts — [why relevant]
- /absolute/path/to/file2.ts — [why relevant]
</files>

<answer>
[Direct answer addressing actual need]
</answer>

<next_steps>
[What to do with this information]
</next_steps>
</results>
```

### oracle (Structured XML)

**Architecture Advisory**:
```xml
<analysis>
**Context**: [current state]
**Decision**: [choice to make]
**Stakes**: [consequences]
</analysis>

<options>
**Option A**: [description, pros, cons, risks]
**Option B**: [description, pros, cons, risks]
</options>

<recommendation>
**Choose**: [option] because [reasoning]
**Mitigations**: [how to address drawbacks]
</recommendation>
```

**Root Cause Analysis**:
```xml
<investigation>
**Symptoms**: [observations]
**Attempts So Far**: [what failed]
**Assumptions**: [what's being taken for granted]
</investigation>

<hypotheses>
1. **[Hypothesis]**: [test, likelihood]
2. **[Hypothesis]**: [test, likelihood]
</hypotheses>

<next_steps>
1. [most promising step]
2. [fallback]
</next_steps>
```

### open-source-librarian (Unspecified)

⚠️ **No explicit output format** - outputs conversational findings with links.

### tech-docs-writer (Unspecified)

⚠️ **No explicit output format** - generates markdown documentation directly.

### media-interpreter (Unspecified)

⚠️ **No explicit output format** - provides narrative analysis of images.

---

**Note**: A detailed plan for standardizing all agent output formats is available in `plans/20260112-output-format-standardization.md`.

## Agent Selection Guide

### Decision Tree

```
Need to find code?
  ├─ In THIS codebase → codebase-search (haiku, $)
  └─ In OTHER repos/docs → open-source-librarian (sonnet, $$)

Need architectural advice?
  ├─ Simple decision → Ask main thread
  └─ High-stakes/complex → oracle (opus, $$$$)

Need code review?
  ├─ Security → security-sentinel
  ├─ Performance → performance-oracle
  ├─ Architecture → architecture-strategist
  ├─ TypeScript → typescript
  ├─ Python → python
  └─ General → code-simplicity + pattern-recognition

Need documentation?
  └─ tech-docs-writer (sonnet, $$)

Failed 3+ times?
  └─ oracle (opus, $$$$)
```

### Cost Optimization

| Scenario | Don't Use | Use Instead |
|----------|-----------|-------------|
| Simple file search | oracle ($$$) | codebase-search ($) |
| Known security issue | oracle ($$$) | security-sentinel ($) |
| TypeScript type error | oracle ($$$) | typescript ($) |
| First debugging attempt | oracle ($$$) | Direct tools + grep |

## Agent Composition Patterns

### Allowed Compositions

✅ **oracle → codebase-search**: Oracle delegates exploration to cheaper agent
✅ **Skills → Review agents**: `/workflows/review` launches multiple review agents in parallel
✅ **codebase-search → Skill**: Agent can invoke skills for follow-up workflows

### Anti-Patterns

❌ **Review agent → Skill**: Review agents should be leaves, not routers
❌ **Agent → Same agent**: No recursion
❌ **opus → opus**: Don't spawn expensive agents from expensive agents

## Guard Rails

### Circular Dependency Prevention

Agents with `Skill` tool access (codebase-search, open-source-librarian, media-interpreter) MUST NOT invoke skills that could invoke them back.

**Safe invocations**:
- codebase-search → /workflows/compound ✅ (write-only skill)
- open-source-librarian → /workflows/compound ✅ (write-only skill)

**Unsafe invocations**:
- codebase-search → /workflows/review ❌ (could spawn codebase-search again)
- Any agent → UsingWorkflows ❌ (routing skill, creates loops)

### Depth Limits

- Maximum agent nesting depth: **2 levels**
- Example: Main thread → oracle → codebase-search → STOP

## Quick Reference Commands

```bash
# List all agents
ls ~/.claude/agents/*.md ~/.claude/agents/review/*.md

# Check agent's tools
grep '^tools:' ~/.claude/agents/oracle.md

# Check agent's model
grep '^model:' ~/.claude/agents/codebase-search.md

# View agent's full definition
cat ~/.claude/agents/security-sentinel.md
```

## Extending the Agent System

### Adding a New Agent

1. Create file: `~/.claude/agents/my-agent.md`
2. Include frontmatter:
   ```yaml
   name: my-agent
   description: |
     When to use this agent
   tools: Read, Grep, Bash
   model: haiku
   color: blue
   ```
3. Define behavior and output format
4. Add to this capability matrix
5. Update relevant skills to invoke it

### Best Practices

- **Single responsibility**: Each agent should do ONE thing well
- **Explicit output format**: Always document expected output structure
- **Cost-aware**: Use cheapest model that works (haiku > sonnet > opus)
- **Tool minimalism**: Only request tools you actually need
- **Read-only default**: Only grant write access if absolutely necessary

---

**Last Updated**: 2026-01-12
**Version**: 1.0.0
