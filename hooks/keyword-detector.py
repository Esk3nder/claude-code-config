#!/usr/bin/env python3
"""
Keyword Detector Hook for Claude Code
Detects special keywords and injects mode-specific context.
Also writes context flags for PreToolUse hook to read.

Hook Event: UserPromptSubmit
"""

import json
import sys
import re
import time
from pathlib import Path

# State directory for context flags (shared with parallel-dispatch-guide.py)
STATE_DIR = Path.home() / ".claude" / "hooks" / "state"
CONTEXT_FILE = STATE_DIR / "session-context.json"

# =============================================================================
# PATTERN DEFINITIONS
# =============================================================================

# Tier 1: Mode activation patterns (original)
PATTERNS_MODE = {
    "ultrawork": r"\b(ultrawork|ulw|ultra\s*work)\b",
    "delegation": r"\b(multi[-\s]*agent|delegate|delegation|parallelize|parallelise|parallel|sub[-\s]*agent|gpt|codex|delegator)\b",
    "search": r"\b(search|find|locate|where\s+is)\b",
    "analysis": r"\b(analyze|investigate|debug|diagnose)\b",
    "think": r"\b(think\s*(deeply|hard|carefully))\b",
}

# Tier 2: Review triggers (for parallel dispatch)
PATTERNS_REVIEW = {
    "review_code": r"\breview\s+(this\s+)?(code|pr|pull\s*request|diff|changes?)\b",
    "review_plan": r"\breview\s+(this\s+)?(plan|proposal|design)\b",
    "review_security": r"\b(security\s+review|is\s+this\s+secure|threat\s+model|pentest|vulnerabilit)\b",
    "review_performance": r"\b(performance|perf)\s+(review|check|audit)\b",
    "review_architecture": r"\b(architecture|arch)\s+(review|check|audit)\b",
    "review_general": r"\breview\b.*\b(codebase|project|repo)\b",
}

# Tier 3: Exploration triggers
PATTERNS_EXPLORATION = {
    "how_does": r"\bhow\s+does\b.*\b(work|function|behave)\b",
    "where_is": r"\b(where\s+is|which\s+file|find\s+the)\b",
    "what_is": r"\b(what\s+is|what\s+are)\b.*\b(this|these|the)\b",
    "trace": r"\b(trace|follow|track)\b.*\b(flow|path|execution)\b",
}

# Tier 4: Library/external triggers
PATTERNS_LIBRARY = {
    "how_to_use": r"\bhow\s+(do\s+i|to)\s+use\b",
    "best_practice": r"\b(best\s+practice|recommended\s+way|official\s+docs?)\b",
    "library_behavior": r"\bwhy\s+does\b.*\b(behave|work|return)\b",
    "package_manager": r"\b(npm|pip|cargo|gem|nuget|yarn|pnpm|bun)\s+(install|add|package)\b",
}

# Tier 5: GitHub/workflow triggers
PATTERNS_GITHUB = {
    "github_mention": r"\b(@\w+\s+mentioned|gh\s+issue|github\s+issue|#\d{2,})\b",
    "create_pr": r"\b(create|open|make)\s+(a\s+)?(pr|pull\s*request)\b",
    "look_into_pr": r"\b(look\s+into|investigate).*\b(create|make)\s+(a\s+)?pr\b",
}

# Tier 6: Domain-specific triggers
PATTERNS_DOMAIN = {
    "security": r"\b(auth|authentication|authorization|oauth|jwt|session|permission|rbac|secret|credential|password|token|encrypt)\b",
    "performance": r"\b(slow|performance|bottleneck|n\+1|cache|optimize|latency|throughput)\b",
    "migration": r"\b(migration|schema|alter\s+table|add\s+column|backfill)\b",
    "deployment": r"\b(deploy|deployment|ci|cd|pipeline|rollout|feature\s+flag)\b",
    "frontend": r"\b(react|vue|angular|useEffect|useState|component|frontend|ui)\b",
    "api": r"\b(api|endpoint|route|controller|graphql|rest)\b",
}


# =============================================================================
# CONTEXT FLAG WRITING
# =============================================================================


def write_context_flags(prompt: str) -> None:
    """Write context flags for PreToolUse hook to read."""
    prompt_lower = prompt.lower()

    flags = {
        # Review context
        "review_mode": bool(re.search(r"\breview\b", prompt_lower)),
        "review_security": bool(
            re.search(PATTERNS_REVIEW["review_security"], prompt_lower, re.I)
        ),
        "review_performance": bool(
            re.search(PATTERNS_REVIEW["review_performance"], prompt_lower, re.I)
        ),
        "review_architecture": bool(
            re.search(PATTERNS_REVIEW["review_architecture"], prompt_lower, re.I)
            or re.search(r"\b(architecture|tradeoffs?|design)\b", prompt_lower)
        ),
        # Exploration context
        "exploration_mode": bool(
            re.search(PATTERNS_EXPLORATION["how_does"], prompt_lower, re.I)
            or re.search(PATTERNS_EXPLORATION["where_is"], prompt_lower, re.I)
            or re.search(PATTERNS_EXPLORATION["trace"], prompt_lower, re.I)
        ),
        # Library context
        "library_context": bool(
            re.search(PATTERNS_LIBRARY["how_to_use"], prompt_lower, re.I)
            or re.search(PATTERNS_LIBRARY["best_practice"], prompt_lower, re.I)
            or re.search(PATTERNS_LIBRARY["package_manager"], prompt_lower, re.I)
        ),
        # Multi-module context
        "multi_module": bool(
            re.search(
                r"\b(module|component|service|layer|package)s?\b", prompt_lower
            )
            or len(re.findall(r"\b(and|,)\b", prompt_lower)) >= 2
        ),
        # Domain flags
        "security_context": bool(
            re.search(PATTERNS_DOMAIN["security"], prompt_lower)
        ),
        "performance_context": bool(
            re.search(PATTERNS_DOMAIN["performance"], prompt_lower)
        ),
        # Timestamp for freshness check
        "timestamp": time.time(),
    }

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    CONTEXT_FILE.write_text(json.dumps(flags, indent=2))


# =============================================================================
# MODE CONTEXTS (injected to Claude)
# =============================================================================

CONTEXT_ULTRAWORK = """
[ULTRAWORK MODE ACTIVATED]

Execute with maximum capability:

1. **Parallel Execution**: Launch multiple agents/tools simultaneously
2. **Comprehensive Planning**: Create detailed todo list BEFORE starting
3. **Thorough Verification**: Run diagnostics on all changed files
4. **No Premature Stopping**: Continue until ALL tasks complete
5. **Evidence-Based**: Verify each change works correctly

Workflow:
- Use Task tool to delegate to specialized agents (explore, oracle)
- Launch independent searches in parallel
- Create todos for complex multi-step work
- Mark todos complete only after verification
"""

CONTEXT_DELEGATION = """
[DELEGATION MODE]

Prefer native workflows and built-in subagents; use Codex for adversarial review.

Guidance:
1. If the user explicitly wants parallel work, use `dispatching-parallel-agents`.
2. If the plan has >6 tasks or "parallel/agents/workstreams" is explicit, use `subagent-driven-development`.
3. For reviews, ensure a Codex adversarial pass runs via `/claude-delegator/task`.
4. Keep scopes independent; avoid overlapping files.
5. Write mini-briefs with goal, files, deliverable, verification, timebox.
6. Codex expert prompts live under `~/.claude/prompts/delegator/` (see `config/delegator/experts.json`).

Suggested entry points:
- /workflows/plan <slug> (if plan needed)
- /workflows/work (execute tasks)
- /workflows/review (Codex + native review agents)
"""

CONTEXT_SEARCH = """
[SEARCH MODE ACTIVATED]

Maximize search thoroughness:

1. **Parallel Searches**: Launch multiple search operations simultaneously
2. **Multiple Angles**: Search by name, content, pattern, and structure
3. **Cross-Reference**: Verify findings across multiple sources
4. **Exhaustive**: Don't stop at first result - find ALL matches

Tools to use in parallel:
- Grep for text patterns
- Glob for file patterns
- LSP for symbol definitions/references
- Git for history when relevant

Report:
- All matching files with absolute paths
- Relevance explanation for each match
- Confidence level in completeness
"""

CONTEXT_ANALYSIS = """
[ANALYSIS MODE ACTIVATED]

Deep investigation protocol:

1. **Gather Evidence**: Read all relevant files before forming conclusions
2. **Multi-Phase Analysis**:
   - Phase 1: Surface-level scan
   - Phase 2: Deep dive into suspicious areas
   - Phase 3: Cross-reference and validate
3. **Consult Experts**: Use oracle agent for complex reasoning
4. **Document Findings**: Systematic, evidence-based conclusions

For debugging:
- Check recent changes (git log, git blame)
- Trace data flow through the system
- Identify edge cases and error paths
- Propose hypothesis and test it
"""

CONTEXT_THINK = """
[EXTENDED THINKING MODE]

Take time for thorough reasoning:

1. **Step Back**: Consider the broader context and implications
2. **Multiple Perspectives**: Evaluate different approaches
3. **Trade-off Analysis**: Document pros/cons of each option
4. **Risk Assessment**: Identify potential issues before implementing
5. **Validation Plan**: How will we verify success?

Before acting:
- State your understanding of the problem
- List assumptions being made
- Outline the approach with rationale
- Identify potential failure modes
"""

CONTEXT_REVIEW = """
[REVIEW MODE - PARALLEL DISPATCH]

This is a review request. Dispatch specialized review agents in parallel:

For security concerns:
  Task(subagent_type="general-purpose", prompt="security review...", run_in_background=true)

For performance concerns:
  Task(subagent_type="general-purpose", prompt="performance review...", run_in_background=true)

For architecture concerns:
  Task(subagent_type="general-purpose", prompt="architecture review...", run_in_background=true)

Per CLAUDE.md: "codebase-search/open-source-librarian = Grep, not consultants. Fire liberally."

Available review agents in agents/review/:
- security-sentinel (auth, injection, secrets)
- performance-oracle (hot paths, scaling)
- architecture-strategist (boundaries, coupling)
- code-simplicity, pattern-recognition (always include)
"""

CONTEXT_EXPLORATION = """
[EXPLORATION MODE - PARALLEL AGENTS]

This is an exploration request. Fire codebase-search agents in parallel:

Task(subagent_type="Explore", prompt="Find X in the codebase", run_in_background=true)
Task(subagent_type="Explore", prompt="Find Y implementations", run_in_background=true)
Task(subagent_type="Explore", prompt="Trace Z flow", run_in_background=true)

Per CLAUDE.md Phase 2A:
- codebase-search = Grep, not consultant
- Fire liberally, always in background
- Launch 3+ parallel queries for thorough exploration
"""

CONTEXT_LIBRARY = """
[LIBRARY REFERENCE MODE]

External library/documentation lookup detected. Fire open-source-librarian:

Task(subagent_type="general-purpose", prompt="Find official docs and best practices for...", run_in_background=true)

The open-source-librarian agent searches:
- Official documentation
- GitHub examples
- OSS implementations
- Best practices and quirks
"""


# =============================================================================
# MAIN
# =============================================================================


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    prompt = input_data.get("prompt", "")
    prompt_lower = prompt.lower()

    # Always write context flags for PreToolUse hook
    write_context_flags(prompt)

    additional_context = None

    # Priority 1: Mode activation (original patterns)
    if re.search(PATTERNS_MODE["ultrawork"], prompt_lower):
        additional_context = CONTEXT_ULTRAWORK

    elif re.search(PATTERNS_MODE["delegation"], prompt_lower):
        additional_context = CONTEXT_DELEGATION

    # Priority 2: Review patterns (NEW)
    elif re.search(PATTERNS_REVIEW["review_security"], prompt_lower, re.I):
        additional_context = CONTEXT_REVIEW

    elif re.search(PATTERNS_REVIEW["review_general"], prompt_lower, re.I):
        additional_context = CONTEXT_REVIEW

    elif re.search(PATTERNS_REVIEW["review_code"], prompt_lower, re.I):
        additional_context = CONTEXT_REVIEW

    # Priority 3: Library patterns (NEW)
    elif re.search(PATTERNS_LIBRARY["how_to_use"], prompt_lower, re.I):
        additional_context = CONTEXT_LIBRARY

    elif re.search(PATTERNS_LIBRARY["best_practice"], prompt_lower, re.I):
        additional_context = CONTEXT_LIBRARY

    # Priority 4: Exploration patterns (NEW)
    elif re.search(PATTERNS_EXPLORATION["how_does"], prompt_lower, re.I):
        additional_context = CONTEXT_EXPLORATION

    # Priority 5: Original patterns
    elif re.search(PATTERNS_MODE["search"], prompt_lower):
        additional_context = CONTEXT_SEARCH

    elif re.search(PATTERNS_MODE["analysis"], prompt_lower):
        additional_context = CONTEXT_ANALYSIS

    elif re.search(PATTERNS_MODE["think"], prompt_lower):
        additional_context = CONTEXT_THINK

    if additional_context:
        output = {
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": additional_context.strip(),
            }
        }
        print(json.dumps(output))

    sys.exit(0)


if __name__ == "__main__":
    main()
