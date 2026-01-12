# Agent Output Format Standardization

## Problem Statement

Agents currently use inconsistent output formats, making it difficult to:
1. Parse agent responses programmatically
2. Compose agents (one agent's output → another agent's input)
3. Aggregate findings from multiple agents
4. Understand what to expect from each agent

## Current State

### ✅ Review Agents (Already Standardized)

All 15 review agents use the same format:

```
Findings:
- [P1] <issue> — <file:line> — <rationale>
- [P2] <issue> — <file:line> — <rationale>
- [P3] <issue> — <file:line> — <rationale>
```

**Why this works**:
- Easy to parse (regex: `\[P[123]\]`)
- Consistent structure across all review agents
- Skills can aggregate findings trivially

### ❌ Core Agents (Inconsistent)

| Agent | Format | Parse Difficulty |
|-------|--------|------------------|
| codebase-search | XML (`<results><files>...<answer>...`) | Medium (XML parsing) |
| oracle | XML (`<analysis><options><recommendation>`) | Medium (XML parsing, multiple schemas) |
| open-source-librarian | Unspecified (conversational) | Hard (unstructured) |
| tech-docs-writer | Unspecified (markdown) | Hard (unstructured) |
| media-interpreter | Unspecified (narrative) | Hard (unstructured) |

## Impact

### Example: Aggregating Multiple Agent Outputs

**Scenario**: `/workflows/review` needs to collect findings from:
- security-sentinel (review agent)
- codebase-search (for context)
- oracle (for architectural analysis)

**Current code (hypothetical)**:
```typescript
// Parse review agent (easy)
const reviewFindings = response1.match(/\[P[123]\] .+ — .+/g);

// Parse codebase-search (medium)
const filesMatch = response2.match(/<files>([\s\S]*?)<\/files>/);
const files = filesMatch ? parseFileList(filesMatch[1]) : [];

// Parse oracle (hard - which schema?)
if (response3.includes('<recommendation>')) {
  // Architecture advisory mode
  const rec = response3.match(/<recommendation>([\s\S]*?)<\/recommendation>/);
} else if (response3.includes('<hypotheses>')) {
  // Root cause analysis mode
  const hyp = response3.match(/<hypotheses>([\s\S]*?)<\/hypotheses>/);
}

// Merge findings (complex logic per format)
```

**Problem**: Each agent needs custom parsing logic.

## Proposed Solution

### Option A: Unified XML Schema (Recommended)

Extend review agent format to all agents with a base schema:

```xml
<agent_response agent="agent-name" version="1.0">
  <!-- REQUIRED: All agents must include this -->
  <summary>
    [One-sentence summary of what was done]
  </summary>

  <!-- OPTIONAL: For agents that find issues -->
  <findings>
    <finding priority="P1" location="file.ts:123">
      <issue>Brief issue description</issue>
      <rationale>Why this matters</rationale>
      <suggestion>How to fix (optional)</suggestion>
    </finding>
  </findings>

  <!-- OPTIONAL: For agents that return data/results -->
  <results>
    <files>
      <file path="/absolute/path">Relevance reason</file>
    </files>
    <answer>Direct answer to query</answer>
  </results>

  <!-- OPTIONAL: Agent-specific extensions -->
  <agent_specific>
    [Agent can add domain-specific XML here]
  </agent_specific>
</agent_response>
```

**Benefits**:
- Single XML parser handles all agents
- Backwards compatible (review agents just add wrapper)
- Extensible (agent-specific data in `<agent_specific>`)
- Strongly typed (XML schema validation possible)

**Drawbacks**:
- More verbose than current format
- Requires updating all agent definitions

### Option B: JSON Schema

```json
{
  "agent": "agent-name",
  "version": "1.0",
  "summary": "What was done",
  "findings": [
    {
      "priority": "P1",
      "issue": "Brief description",
      "location": "file.ts:123",
      "rationale": "Why this matters"
    }
  ],
  "results": {
    "files": ["/path/to/file1", "/path/to/file2"],
    "answer": "Direct answer"
  },
  "agent_specific": {}
}
```

**Benefits**:
- Easy to parse (native JSON)
- Language-agnostic
- Schema validation via JSON Schema

**Drawbacks**:
- More verbose than markdown format
- Requires strict JSON formatting (no trailing commas, etc.)
- Harder to read in raw form

### Option C: Markdown with YAML Frontmatter (Lightweight)

```markdown
---
agent: agent-name
version: 1.0
---

## Summary
[One sentence]

## Findings
- [P1] <issue> — <location> — <rationale>
- [P2] <issue> — <location> — <rationale>

## Results
### Files
- /absolute/path — relevance

### Answer
[Direct answer]

## Agent-Specific
[Custom markdown sections]
```

**Benefits**:
- Human-readable
- Easy to write (markdown is forgiving)
- YAML frontmatter for metadata

**Drawbacks**:
- Requires both YAML and markdown parsers
- Markdown parsing is ambiguous (multiple valid structures)

## Recommendation

**Use Option A (Unified XML Schema)** for these reasons:

1. **Already in use**: codebase-search and oracle use XML
2. **Strongly typed**: Can validate with XML schema
3. **Extensible**: Agent-specific data in separate section
4. **Parser reuse**: One XML parser handles all agents

## Migration Plan

### Phase 1: Add Wrappers (Backwards Compatible)

Review agents keep current format but add XML wrapper:

```xml
<agent_response agent="security-sentinel" version="1.0">
  <summary>Security review completed - 2 issues found</summary>
  <findings>
Findings:
- [P1] SQL injection risk — api/users.ts:45 — User input not sanitized
- [P2] Weak password policy — auth/validators.ts:12 — Minimum length is 6
  </findings>
</agent_response>
```

**Impact**: Zero (wrapper is optional, parsers ignore it)

### Phase 2: Standardize Non-Review Agents

Update codebase-search, oracle, open-source-librarian to use base schema:

**Before (codebase-search)**:
```xml
<results>
<files>
- /path/to/file.ts — [reason]
</files>
<answer>
Direct answer
</answer>
</results>
```

**After (codebase-search)**:
```xml
<agent_response agent="codebase-search" version="1.0">
  <summary>Found 3 relevant files for auth implementation</summary>
  <results>
    <files>
      <file path="/src/auth/service.ts">Main auth service</file>
      <file path="/src/auth/middleware.ts">JWT validation</file>
    </files>
    <answer>Authentication is implemented in src/auth/ with JWT tokens</answer>
  </results>
</agent_response>
```

### Phase 3: Update Skills to Use Unified Parser

Skills that aggregate agent outputs (like `/workflows/review`) switch to unified XML parser:

```typescript
function parseAgentResponse(xml: string): AgentResponse {
  const doc = parseXML(xml);
  return {
    agent: doc.getAttribute('agent'),
    summary: doc.querySelector('summary')?.textContent,
    findings: doc.querySelectorAll('finding').map(parseFinding),
    results: parseResults(doc.querySelector('results')),
    agentSpecific: doc.querySelector('agent_specific')
  };
}
```

## Implementation Checklist

### For Each Agent

- [ ] Add `<agent_response>` wrapper with `agent` and `version` attributes
- [ ] Add `<summary>` section (one sentence)
- [ ] Wrap existing output in appropriate section (`<findings>` or `<results>`)
- [ ] Document output format in agent's `.md` file
- [ ] Add example output to agent documentation
- [ ] Test with existing skills that invoke the agent

### For Skills That Consume Agent Output

- [ ] Identify all places where agent output is parsed
- [ ] Replace custom parsers with unified `parseAgentResponse()`
- [ ] Add error handling for malformed responses
- [ ] Test with both old and new formats (during transition)

## Example: Before/After

### Before: Inconsistent Formats

**security-sentinel output**:
```
Findings:
- [P1] SQL injection — api.ts:45 — No sanitization
```

**codebase-search output**:
```xml
<results>
<files>- /src/api.ts — Contains SQL queries</files>
<answer>SQL queries are in api.ts</answer>
</results>
```

**oracle output**:
```xml
<recommendation>
**Choose**: Parameterized queries because prevents injection
</recommendation>
```

**Aggregation code**:
```typescript
// Custom parser for each agent
const findings1 = parseReviewAgent(response1);
const files = parseCodebaseSearch(response2);
const recommendation = parseOracle(response3);
// Complex merging logic...
```

### After: Unified Format

**security-sentinel output**:
```xml
<agent_response agent="security-sentinel" version="1.0">
  <summary>Found 1 critical security issue</summary>
  <findings>
    <finding priority="P1" location="api.ts:45">
      <issue>SQL injection risk</issue>
      <rationale>User input not sanitized</rationale>
    </finding>
  </findings>
</agent_response>
```

**codebase-search output**:
```xml
<agent_response agent="codebase-search" version="1.0">
  <summary>Located SQL queries in 1 file</summary>
  <results>
    <files>
      <file path="/src/api.ts">Contains SQL queries</file>
    </files>
    <answer>SQL queries are in api.ts</answer>
  </results>
</agent_response>
```

**oracle output**:
```xml
<agent_response agent="oracle" version="1.0">
  <summary>Recommending parameterized queries</summary>
  <agent_specific type="architecture-advisory">
    <recommendation>
      <choice>Parameterized queries</choice>
      <reasoning>Prevents SQL injection</reasoning>
    </recommendation>
  </agent_specific>
</agent_response>
```

**Aggregation code**:
```typescript
// Single parser for all agents
const responses = [response1, response2, response3].map(parseAgentResponse);

// Merge trivially
const allFindings = responses.flatMap(r => r.findings || []);
const allFiles = responses.flatMap(r => r.results?.files || []);
const recommendations = responses.filter(r => r.agentSpecific?.recommendation);
```

## Open Questions

1. **Versioning**: How to handle breaking changes to schema?
   - Proposal: Use `version` attribute, maintain backwards compatibility for 1 major version

2. **Error reporting**: Should agents wrap errors in same format?
   - Proposal: Yes, add `<error>` section for failures

3. **Performance**: Does XML parsing add significant overhead?
   - Proposal: Benchmark, but likely negligible (responses are small)

4. **Human readability**: Is XML too verbose for casual inspection?
   - Proposal: Add "compact mode" renderer that shows just summary + findings

## Next Steps

1. **Validate proposal** with team/users
2. **Create XML schema** (.xsd file for validation)
3. **Update 3 agents** as proof-of-concept (security-sentinel, codebase-search, oracle)
4. **Update /workflows/review** to use unified parser
5. **Roll out** to remaining agents
6. **Document** in main README

---

**Status**: DRAFT - Awaiting feedback
**Author**: Architecture review process
**Date**: 2026-01-12
