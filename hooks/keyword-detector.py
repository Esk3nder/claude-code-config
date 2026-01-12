#!/usr/bin/env python3
"""Keyword Detector Hook - Detects keywords and injects mode-specific context."""
import json, sys, re, time
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "hooks" / "state"
CONTEXT_FILE = STATE_DIR / "session-context.json"

PATTERNS_MODE = {
    "ultrawork": r"\b(ultrawork|ulw|ultra\s*work)\b",
    "delegation": r"\b(multi[-\s]*agent|delegate|delegation|parallelize|parallelise|parallel|sub[-\s]*agent|gpt|codex|delegator)\b",
    "search": r"\b(search|find|locate|where\s+is)\b",
    "analysis": r"\b(analyze|investigate|debug|diagnose)\b",
    "think": r"\b(think\s*(deeply|hard|carefully))\b",
}
PATTERNS_REVIEW = {
    "review_code": r"\breview\s+(\w+\s+)?(code|pr|pull\s*request|diff|changes?)\b",
    "review_plan": r"\breview\s+(this\s+)?(plan|proposal|design)\b",
    "review_security": r"\b(security\s+review|is\s+this\s+secure|threat\s+model|pentest|vulnerabilit(y|ies)?)\b",
    "review_security_alt": r"\breview\b.*\bsecurity\b",
    "review_performance": r"\b(performance|perf)\s+(review|check|audit)\b",
    "review_performance_alt": r"\breview\b.*\b(performance|perf)\b",
    "review_architecture": r"\b(architecture|arch)\s+(review|check|audit)\b",
    "review_architecture_alt": r"\breview\b.*\b(architecture|arch)\b",
    "review_general": r"\breview\b.*\b(codebase|project|repo)\b",
}
PATTERNS_EXPLORATION = {
    "how_does": r"\bhow\s+does\b.*\b(work|function|behave)\b",
    "where_is": r"\b(where\s+is|which\s+file|find\s+the)\b",
    "what_is": r"\b(what\s+is|what\s+are)\b.*\b(this|these|the)\b",
    "trace": r"\b(trace|follow|track)\b.*\b(flow|path|execution)\b",
}
PATTERNS_LIBRARY = {
    "how_to_use": r"\bhow\s+(do\s+i|to)\s+use\b",
    "best_practice": r"\b(best\s+practice|recommended\s+way|official\s+docs?)\b",
    "library_behavior": r"\bwhy\s+does\b.*\b(behave|work|return)\b",
    "package_manager": r"\b(npm|pip|cargo|gem|nuget|yarn|pnpm|bun)\s+(install|add|package)\b",
    "library_mention": r"\b(react|vue|angular|svelte|next\.?js|nuxt|express|fastify|django|flask|rails|spring|laravel|prisma|drizzle|typeorm|sequelize|mongoose|redis|postgres|mongodb|graphql|trpc|zod|yup|joi|lodash|underscore|axios|fetch|tanstack|zustand|redux|mobx|tailwind|styled-components|emotion|chakra|shadcn|radix)\b",
}
PATTERNS_GITHUB = {
    "github_mention": r"(@\w+\s+mentioned|gh\s+issue|github\s+issue|issue\s+#\d+|#\d{2,})",
    "create_pr": r"\b(create|open|make)\s+(a\s+)?(pr|pull\s*request)\b",
    "look_into_pr": r"\b(look\s+into|investigate).*\b(create|make)\s+(a\s+)?pr\b",
}
PATTERNS_DOMAIN = {
    "security": r"\b(auth|authentication|authorization|oauth|jwt|session|permission|rbac|secret|credentials?|password|token|encrypt)\b",
    "performance": r"\b(slow|performance|bottleneck|n\+1|cach(e|ing)|optimize|latency|throughput)\b",
    "migration": r"\b(migration|schema|alter\s+table|add\s+column|backfill)\b",
    "deployment": r"\b(deploy|deployment|ci|cd|pipeline|rollout|feature\s+flag)\b",
    "frontend": r"\b(react|vue|angular|useEffect|useState|component|frontend|ui)\b",
    "api": r"\b(api|endpoint|route|controller|graphql|rest)\b",
}
PATTERNS_SKILLS = {
    "debugging": r"\b(error|exception|traceback|stack\s*trace|failed|failing|broken|crash|bug|not\s+working|doesn.t\s+work)\b",
    "tdd": r"\b(add\s+(a\s+)?(test|spec)|write\s+test|test\s+first|red.green.refactor|tdd)\b",
    "planning": r"\b(plan|roadmap|multi.step|complex\s+task|project\s+plan|implementation\s+plan)\b",
    "compound": r"\b(that\s+worked|it.s\s+fixed|problem\s+solved|issue\s+resolved|working\s+now)\b",
    "brainstorm": r"\b(brainstorm|options|approaches|alternatives|design\s+decision|trade.?offs?|pros\s+and\s+cons)\b",
    "verification": r"\b(done|finished|completed|ready\s+to\s+(ship|merge|deploy))\b",
}

def write_context_flags(prompt: str) -> None:
    p = prompt.lower()
    flags = {
        "review_mode": bool(re.search(r"\breview\b", p)),
        "review_security": bool(re.search(PATTERNS_REVIEW["review_security"], p, re.I) or re.search(PATTERNS_REVIEW["review_security_alt"], p, re.I)),
        "review_performance": bool(re.search(PATTERNS_REVIEW["review_performance"], p, re.I) or re.search(PATTERNS_REVIEW["review_performance_alt"], p, re.I)),
        "review_architecture": bool(re.search(PATTERNS_REVIEW["review_architecture"], p, re.I) or re.search(PATTERNS_REVIEW["review_architecture_alt"], p, re.I) or re.search(r"\b(architecture|tradeoffs?|design)\b", p)),
        "exploration_mode": bool(re.search(PATTERNS_EXPLORATION["how_does"], p, re.I) or re.search(PATTERNS_EXPLORATION["where_is"], p, re.I) or re.search(PATTERNS_EXPLORATION["trace"], p, re.I)),
        "library_context": bool(re.search(PATTERNS_LIBRARY["how_to_use"], p, re.I) or re.search(PATTERNS_LIBRARY["best_practice"], p, re.I) or re.search(PATTERNS_LIBRARY["package_manager"], p, re.I)),
        "multi_module": bool(re.search(r"\b(module|component|service|layer|package)s?\b", p) or len(re.findall(r"\b(and|,)\b", p)) >= 2),
        "security_context": bool(re.search(PATTERNS_DOMAIN["security"], p)),
        "performance_context": bool(re.search(PATTERNS_DOMAIN["performance"], p)),
        "github_work": bool(re.search(PATTERNS_GITHUB["github_mention"], p, re.I) or re.search(PATTERNS_GITHUB["look_into_pr"], p, re.I)),
        "library_mentioned": bool(re.search(PATTERNS_LIBRARY["library_mention"], p, re.I) or re.search(PATTERNS_LIBRARY["package_manager"], p, re.I)),
        "debugging_context": bool(re.search(PATTERNS_SKILLS["debugging"], p, re.I)),
        "compound_context": bool(re.search(PATTERNS_SKILLS["compound"], p, re.I)),
        "brainstorm_context": bool(re.search(PATTERNS_SKILLS["brainstorm"], p, re.I)),
        "timestamp": time.time(),
    }
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    CONTEXT_FILE.write_text(json.dumps(flags, indent=2))

CONTEXT_ULTRAWORK = """[ULTRAWORK MODE ACTIVATED]

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
- Mark todos complete only after verification"""

CONTEXT_DELEGATION = """[DELEGATION MODE]

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
- /workflows/review (Codex + native review agents)"""

CONTEXT_SEARCH = """[SEARCH MODE ACTIVATED]

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
- Confidence level in completeness"""

CONTEXT_ANALYSIS = """[ANALYSIS MODE ACTIVATED]

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
- Propose hypothesis and test it"""

CONTEXT_THINK = """[EXTENDED THINKING MODE]

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
- Identify potential failure modes"""

CONTEXT_REVIEW = """[REVIEW MODE - PARALLEL DISPATCH]

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
- code-simplicity, pattern-recognition (always include)"""

CONTEXT_EXPLORATION = """[EXPLORATION MODE - PARALLEL AGENTS]

This is an exploration request. Fire codebase-search agents in parallel:

Task(subagent_type="Explore", prompt="Find X in the codebase", run_in_background=true)
Task(subagent_type="Explore", prompt="Find Y implementations", run_in_background=true)
Task(subagent_type="Explore", prompt="Trace Z flow", run_in_background=true)

Per CLAUDE.md Phase 2A:
- codebase-search = Grep, not consultant
- Fire liberally, always in background
- Launch 3+ parallel queries for thorough exploration"""

CONTEXT_LIBRARY = """[LIBRARY REFERENCE MODE]

External library/documentation lookup detected. Fire open-source-librarian:

Task(subagent_type="general-purpose", prompt="Find official docs and best practices for...", run_in_background=true)

The open-source-librarian agent searches:
- Official documentation
- GitHub examples
- OSS implementations
- Best practices and quirks"""

CONTEXT_GITHUB_WORK = """[GITHUB WORK REQUEST]

This is a GitHub work request. Full implementation cycle expected:

1. **Investigate**: Understand the issue/request fully
2. **Plan**: Create todos for implementation steps
3. **Implement**: Make the necessary changes
4. **Verify**: Run tests, ensure quality
5. **Create PR**: Open a pull request with proper description

This is NOT just research. Deliver working code and a PR.

Per CLAUDE.md Phase 0:
- GitHub mention (@mention in issue/PR) = WORK REQUEST
- "Look into" + "create PR" = Full implementation cycle"""

CONTEXT_MULTI_MODULE = """[MULTI-MODULE CONTEXT]

Multiple modules/components detected. Fire codebase-search agents in parallel:

Task(subagent_type="Explore", prompt="Find module A implementation...", run_in_background=true)
Task(subagent_type="Explore", prompt="Find module B patterns...", run_in_background=true)

Per CLAUDE.md Key Triggers:
- 2+ modules involved → fire codebase-search background

Cross-reference findings before proceeding. Look for:
- Shared interfaces between modules
- Common patterns and conventions
- Integration points"""

CONTEXT_DEBUGGING = """[SYSTEMATIC DEBUGGING MODE]

Error/failure detected. Use systematic-debugging skill:

1. **Reproduce**: Confirm the error is reproducible
2. **Narrow**: Isolate the failing component
3. **Hypothesize**: Form a theory about the root cause
4. **Test**: Verify the hypothesis
5. **Fix**: Apply minimal fix for root cause

DO NOT:
- Shotgun debug (random changes)
- Fix symptoms instead of causes
- Skip reproduction step

After 3 consecutive failures → STOP, REVERT, CONSULT oracle"""

CONTEXT_COMPOUND = """[COMPOUND LEARNING MODE]

Success detected! Capture this solution for future reuse:

Consider documenting in docs/solutions/:
- What problem was solved
- What approach worked
- Key insights or gotchas

This helps avoid re-solving the same problem later."""

CONTEXT_BRAINSTORM = """[BRAINSTORMING MODE]

Design decision or unclear request detected. Use brainstorming skill:

1. Restate goal and constraints (2-3 bullets)
2. List 5-7 distinct options (mix conservative and bold)
3. Note pros, cons, risks for each
4. Pick recommendation with rationale
5. Identify open questions before building

Ask clarifying questions if multiple interpretations exist with 2x+ effort difference."""

PRIORITY_RULES = [
    (PATTERNS_MODE["ultrawork"], CONTEXT_ULTRAWORK, False),
    (PATTERNS_MODE["delegation"], CONTEXT_DELEGATION, False),
    (PATTERNS_REVIEW["review_security"], CONTEXT_REVIEW, True),
    (PATTERNS_REVIEW["review_general"], CONTEXT_REVIEW, True),
    (PATTERNS_REVIEW["review_code"], CONTEXT_REVIEW, True),
    (PATTERNS_GITHUB["look_into_pr"], CONTEXT_GITHUB_WORK, True),
    (PATTERNS_GITHUB["github_mention"], CONTEXT_GITHUB_WORK, True),
    (PATTERNS_LIBRARY["library_mention"], CONTEXT_LIBRARY, True),
    (PATTERNS_LIBRARY["how_to_use"], CONTEXT_LIBRARY, True),
    (PATTERNS_LIBRARY["best_practice"], CONTEXT_LIBRARY, True),
    (PATTERNS_EXPLORATION["how_does"], CONTEXT_EXPLORATION, True),
    (PATTERNS_SKILLS["debugging"], CONTEXT_DEBUGGING, True),
    (PATTERNS_SKILLS["compound"], CONTEXT_COMPOUND, True),
    (PATTERNS_SKILLS["brainstorm"], CONTEXT_BRAINSTORM, True),
    (PATTERNS_MODE["search"], CONTEXT_SEARCH, False),
    (PATTERNS_MODE["analysis"], CONTEXT_ANALYSIS, False),
    (PATTERNS_MODE["think"], CONTEXT_THINK, False),
]

def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    prompt = input_data.get("prompt", "")
    prompt_lower = prompt.lower()
    write_context_flags(prompt)
    additional_context = None
    for pattern, context, case_insensitive in PRIORITY_RULES:
        flags = re.I if case_insensitive else 0
        if re.search(pattern, prompt_lower, flags):
            additional_context = context
            break
    if additional_context is None and re.search(r"\b(module|component|service|layer)s?\b", prompt_lower) and len(re.findall(r"\b(and|,)\b", prompt_lower)) >= 2:
        additional_context = CONTEXT_MULTI_MODULE
    if additional_context:
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": additional_context.strip()}}))
    sys.exit(0)

if __name__ == "__main__":
    main()
