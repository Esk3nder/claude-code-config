#!/usr/bin/env python3
"""
Behavioral tests for keyword-detector.py pattern matching.
Tests that all documented patterns actually trigger the expected contexts.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "hooks"))

# Import patterns directly from source
from importlib.util import spec_from_loader, module_from_spec
from importlib.machinery import SourceFileLoader

REPO_ROOT = Path(__file__).parent.parent
_loader = SourceFileLoader("kd", str(REPO_ROOT / "hooks" / "keyword-detector.py"))
_spec = spec_from_loader("kd", _loader)
_kd = module_from_spec(_spec)
_loader.exec_module(_kd)

PATTERNS_MODE = _kd.PATTERNS_MODE
PATTERNS_REVIEW = _kd.PATTERNS_REVIEW
PATTERNS_EXPLORATION = _kd.PATTERNS_EXPLORATION
PATTERNS_LIBRARY = _kd.PATTERNS_LIBRARY
PATTERNS_GITHUB = _kd.PATTERNS_GITHUB
PATTERNS_DOMAIN = _kd.PATTERNS_DOMAIN
PATTERNS_SKILLS = _kd.PATTERNS_SKILLS

FAILURES = []

def fail(msg: str):
    FAILURES.append(msg)
    print(f"FAIL: {msg}")

def passed(msg: str):
    print(f"PASS: {msg}")


# =============================================================================
# TEST CASES
# =============================================================================


def check_pattern(pattern_name: str, pattern: str, test_cases: list, should_match: bool = True):
    """Test that a pattern matches or doesn't match the given test cases."""
    for test in test_cases:
        matched = bool(re.search(pattern, test.lower(), re.I))
        expected = "match" if should_match else "no-match"
        actual = "match" if matched else "no-match"

        if matched == should_match:
            passed(f"{pattern_name}: '{test[:40]}...' → {actual}")
        else:
            fail(f"{pattern_name}: '{test[:40]}...' → expected {expected}, got {actual}")


def test_mode_patterns():
    """Test Tier 1: Mode activation patterns."""
    print("\n--- Tier 1: Mode Patterns ---")

    check_pattern("ultrawork", PATTERNS_MODE["ultrawork"], [
        "ultrawork on this feature",
        "ulw mode please",
        "ultra work session",
    ])

    check_pattern("delegation", PATTERNS_MODE["delegation"], [
        "use multi-agent approach",
        "delegate this to subagents",
        "parallelize the work",
        "use codex for review",
    ])

    check_pattern("search", PATTERNS_MODE["search"], [
        "search for auth functions",
        "find the login handler",
        "where is the config file",
    ])

    check_pattern("analysis", PATTERNS_MODE["analysis"], [
        "analyze this code",
        "investigate the bug",
        "debug the issue",
        "diagnose the problem",
    ])

    check_pattern("think", PATTERNS_MODE["think"], [
        "think deeply about this",
        "think hard about the solution",
        "think carefully before implementing",
    ])


def test_review_patterns():
    """Test Tier 2: Review patterns."""
    print("\n--- Tier 2: Review Patterns ---")

    check_pattern("review_code", PATTERNS_REVIEW["review_code"], [
        "review this code",
        "review the PR",
        "review my changes",
        "review this pull request",
    ])

    check_pattern("review_security", PATTERNS_REVIEW["review_security"], [
        "security review needed",
        "is this secure?",
        "do a threat model",
        "check for vulnerabilities",
    ])

    check_pattern("review_security_alt", PATTERNS_REVIEW["review_security_alt"], [
        "review this codebase for security issues",
        "review for security, performance, and architecture",
    ])

    check_pattern("review_performance", PATTERNS_REVIEW["review_performance"], [
        "performance review please",
        "perf check this",
        "do a perf audit",
    ])

    check_pattern("review_performance_alt", PATTERNS_REVIEW["review_performance_alt"], [
        "review this for performance issues",
        "review for security, performance, and architecture",
    ])

    check_pattern("review_architecture", PATTERNS_REVIEW["review_architecture"], [
        "architecture review needed",
        "arch check this design",
        "do an arch audit",
    ])

    check_pattern("review_architecture_alt", PATTERNS_REVIEW["review_architecture_alt"], [
        "review this for architecture issues",
        "review for security, performance, and architecture",
    ])

    check_pattern("review_general", PATTERNS_REVIEW["review_general"], [
        "review this codebase",
        "review the project",
        "review this repo for issues",
    ])


def test_exploration_patterns():
    """Test Tier 3: Exploration patterns."""
    print("\n--- Tier 3: Exploration Patterns ---")

    check_pattern("how_does", PATTERNS_EXPLORATION["how_does"], [
        "how does the auth system work",
        "how does this function behave",
        "how does the cache work",
    ])

    check_pattern("where_is", PATTERNS_EXPLORATION["where_is"], [
        "where is the config file",
        "which file has the router",
        "find the database module",
    ])

    check_pattern("trace", PATTERNS_EXPLORATION["trace"], [
        "trace the data flow",
        "follow the execution path",
        "track the request flow",
    ])


def test_library_patterns():
    """Test Tier 4: Library patterns."""
    print("\n--- Tier 4: Library Patterns ---")

    check_pattern("how_to_use", PATTERNS_LIBRARY["how_to_use"], [
        "how do I use zod",
        "how to use prisma",
    ])

    check_pattern("best_practice", PATTERNS_LIBRARY["best_practice"], [
        "best practice for auth",
        "recommended way to handle",
        "official docs for react",
    ])

    check_pattern("library_mention", PATTERNS_LIBRARY["library_mention"], [
        "using react hooks",
        "vue composition api",
        "express middleware",
        "prisma schema",
        "tailwind classes",
        "zustand store",
    ])

    check_pattern("package_manager", PATTERNS_LIBRARY["package_manager"], [
        "npm install axios",
        "pip install django",
        "cargo add serde",
        "bun add zod",
    ])


def test_github_patterns():
    """Test Tier 5: GitHub patterns."""
    print("\n--- Tier 5: GitHub Patterns ---")

    check_pattern("github_mention", PATTERNS_GITHUB["github_mention"], [
        "@user mentioned this",
        "gh issue #123",
        "github issue discussion",
        "issue #45 needs fixing",
    ])

    check_pattern("create_pr", PATTERNS_GITHUB["create_pr"], [
        "create a PR",
        "open a pull request",
        "make a pr for this",
    ])

    check_pattern("look_into_pr", PATTERNS_GITHUB["look_into_pr"], [
        "look into this and create a pr",
        "investigate the issue and make a PR",
    ])


def test_domain_patterns():
    """Test Tier 6: Domain patterns."""
    print("\n--- Tier 6: Domain Patterns ---")

    check_pattern("security", PATTERNS_DOMAIN["security"], [
        "authentication flow",
        "oauth integration",
        "jwt token handling",
        "check credentials",
    ])

    check_pattern("performance", PATTERNS_DOMAIN["performance"], [
        "slow query",
        "performance issue",
        "n+1 problem",
        "add caching",
    ])


def test_skill_patterns():
    """Test Tier 7: Skill activation patterns."""
    print("\n--- Tier 7: Skill Patterns ---")

    check_pattern("debugging", PATTERNS_SKILLS["debugging"], [
        "getting an error",
        "exception thrown",
        "stack trace shows",
        "test is failing",
        "broken build",
        "doesn't work anymore",
    ])

    check_pattern("tdd", PATTERNS_SKILLS["tdd"], [
        "add a test for this",
        "write test first",
        "red green refactor",
        "following tdd",
    ])

    check_pattern("planning", PATTERNS_SKILLS["planning"], [
        "create a plan",
        "build a roadmap",
        "multi-step task",
        "implementation plan needed",
    ])

    check_pattern("compound", PATTERNS_SKILLS["compound"], [
        "that worked!",
        "it's fixed now",
        "problem solved",
        "issue resolved",
        "working now",
    ])

    check_pattern("brainstorm", PATTERNS_SKILLS["brainstorm"], [
        "let's brainstorm",
        "what are my options",
        "explore approaches",
        "design decision needed",
        "trade-offs to consider",
    ])


def test_negative_cases():
    """Test that patterns don't over-match."""
    print("\n--- Negative Cases (should NOT match) ---")

    # ultrawork shouldn't match "work"
    check_pattern("ultrawork-negative", PATTERNS_MODE["ultrawork"], [
        "let's work on this",
        "this will work",
    ], should_match=False)

    # think shouldn't match plain "think"
    check_pattern("think-negative", PATTERNS_MODE["think"], [
        "I think this is wrong",
        "what do you think",
    ], should_match=False)

    # review_code shouldn't match "view"
    check_pattern("review_code-negative", PATTERNS_REVIEW["review_code"], [
        "view the file",
        "preview the changes",
    ], should_match=False)


def test_context_output_structure():
    """Test that keyword-detector.py produces valid output structure."""
    print("\n--- Output Structure ---")

    # Mock test - verify the hook script exists and is executable
    hook_path = REPO_ROOT / "hooks" / "keyword-detector.py"

    if not hook_path.exists():
        fail("hooks/keyword-detector.py does not exist")
        return

    if not hook_path.stat().st_mode & 0o111:
        fail("hooks/keyword-detector.py is not executable")
    else:
        passed("hooks/keyword-detector.py exists and is executable")

    # Verify it has the required output structure
    content = hook_path.read_text()

    if "hookSpecificOutput" not in content:
        fail("Missing hookSpecificOutput in output structure")
    else:
        passed("Hook uses hookSpecificOutput format")

    if "additionalContext" not in content:
        fail("Missing additionalContext in output")
    else:
        passed("Hook includes additionalContext")

    if "write_context_flags" not in content:
        fail("Missing context flag writing function")
    else:
        passed("Hook writes context flags for PreToolUse")


def test_pattern_count():
    """Verify we have the expected number of patterns across all tiers."""
    print("\n--- Pattern Count ---")

    total_patterns = (
        len(PATTERNS_MODE)
        + len(PATTERNS_REVIEW)
        + len(PATTERNS_EXPLORATION)
        + len(PATTERNS_LIBRARY)
        + len(PATTERNS_GITHUB)
        + len(PATTERNS_DOMAIN)
        + len(PATTERNS_SKILLS)
    )

    # We documented 28 patterns in the PR
    expected_min = 28

    if total_patterns >= expected_min:
        passed(f"Pattern count: {total_patterns} (expected >= {expected_min})")
    else:
        fail(f"Pattern count: {total_patterns} (expected >= {expected_min})")


def main():
    print("=== Keyword Detector Behavioral Tests ===")

    test_mode_patterns()
    test_review_patterns()
    test_exploration_patterns()
    test_library_patterns()
    test_github_patterns()
    test_domain_patterns()
    test_skill_patterns()
    test_negative_cases()
    test_context_output_structure()
    test_pattern_count()

    print("\n=== Summary ===")
    if FAILURES:
        print(f"FAILED: {len(FAILURES)} assertions")
        for f in FAILURES[:10]:
            print(f"  - {f}")
        if len(FAILURES) > 10:
            print(f"  ... and {len(FAILURES) - 10} more")
        return 1
    else:
        print("ALL PASSED")
        return 0


if __name__ == "__main__":
    sys.exit(main())
