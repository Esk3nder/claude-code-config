# Test Plan

**Generated**: 2026-01-11

## Overview

This document defines an audit harness for the claude-code-config repository. Since this is primarily a configuration repository (not application code), tests focus on:
1. Structural integrity (files exist, valid syntax)
2. Wiring completeness (all references resolve)
3. Hook executability (scripts can run)
4. Claim verification (counts match, paths valid)

## Test Harness Location

```
scripts/
├── ci/
│   ├── validate-all.sh          # Master script, runs all checks
│   ├── validate-json.sh         # JSON syntax validation
│   ├── validate-hooks.sh        # Hook script validation
│   ├── validate-wiring.sh       # Reference/wiring checks
│   ├── validate-counts.sh       # Component count verification
│   └── validate-install.sh      # Installation simulation
└── test/
    └── hook-unit-tests.bats     # BATS unit tests for hooks
```

## Validation Scripts

### 1. validate-json.sh
**Purpose**: Verify all JSON files are syntactically valid

```bash
#!/bin/bash
set -euo pipefail

FAILED=0
for f in config/delegator/*.json; do
  if ! jq empty "$f" 2>/dev/null; then
    echo "FAIL: Invalid JSON in $f"
    FAILED=1
  else
    echo "OK: $f"
  fi
done

exit $FAILED
```

**What Fails**: Invalid JSON syntax in config files

### 2. validate-hooks.sh
**Purpose**: Verify hook scripts are valid and executable

```bash
#!/bin/bash
set -euo pipefail

FAILED=0

# Check shell scripts
for f in hooks/*.sh hooks/workflows/*.sh; do
  if [[ -f "$f" ]]; then
    if ! bash -n "$f" 2>/dev/null; then
      echo "FAIL: Shell syntax error in $f"
      FAILED=1
    else
      echo "OK: $f (syntax)"
    fi

    if ! head -1 "$f" | grep -q '^#!'; then
      echo "FAIL: Missing shebang in $f"
      FAILED=1
    fi
  fi
done

# Check Python scripts
for f in hooks/*.py; do
  if [[ -f "$f" ]]; then
    if ! python3 -m py_compile "$f" 2>/dev/null; then
      echo "FAIL: Python syntax error in $f"
      FAILED=1
    else
      echo "OK: $f (syntax)"
    fi
  fi
done

exit $FAILED
```

**What Fails**: Syntax errors in hook scripts, missing shebangs

### 3. validate-wiring.sh
**Purpose**: Verify all references in docs point to existing files

```bash
#!/bin/bash
set -euo pipefail

FAILED=0

# Extract all file paths from INSTALL.md and verify they exist
grep -oE 'main/[^ ]+' INSTALL.md | sed 's|main/||' | while read -r path; do
  if [[ ! -f "$path" ]]; then
    echo "FAIL: INSTALL.md references non-existent file: $path"
    FAILED=1
  fi
done

# Verify experts.json references valid prompts
jq -r '.[] | .prompt' config/delegator/experts.json | while read -r prompt; do
  if [[ ! -f "prompts/delegator/$prompt" ]]; then
    echo "FAIL: experts.json references non-existent prompt: $prompt"
    FAILED=1
  fi
done

# Verify all skills have SKILL.md
for dir in skills/*/; do
  if [[ ! -f "${dir}SKILL.md" ]]; then
    echo "FAIL: Skill directory missing SKILL.md: $dir"
    FAILED=1
  fi
done

exit $FAILED
```

**What Fails**: Broken references, missing SKILL.md files

### 4. validate-counts.sh
**Purpose**: Verify documented counts match actual counts

```bash
#!/bin/bash
set -euo pipefail

FAILED=0

# Skills
SKILL_COUNT=$(find skills -name "SKILL.md" | wc -l | tr -d ' ')
if [[ "$SKILL_COUNT" -ne 16 ]]; then
  echo "FAIL: Expected 16 skills, found $SKILL_COUNT"
  FAILED=1
else
  echo "OK: Skills count ($SKILL_COUNT)"
fi

# Agents
AGENT_COUNT=$(find agents -name "*.md" | wc -l | tr -d ' ')
if [[ "$AGENT_COUNT" -ne 19 ]]; then
  echo "FAIL: Expected 19 agents, found $AGENT_COUNT"
  FAILED=1
else
  echo "OK: Agents count ($AGENT_COUNT)"
fi

# Hooks
HOOK_COUNT=$(find hooks -type f \( -name "*.sh" -o -name "*.py" \) | wc -l | tr -d ' ')
if [[ "$HOOK_COUNT" -ne 4 ]]; then
  echo "FAIL: Expected 4 hooks, found $HOOK_COUNT"
  FAILED=1
else
  echo "OK: Hooks count ($HOOK_COUNT)"
fi

# Rules
RULE_COUNT=$(find rules -name "*.md" | wc -l | tr -d ' ')
if [[ "$RULE_COUNT" -ne 8 ]]; then
  echo "FAIL: Expected 8 rules, found $RULE_COUNT"
  FAILED=1
else
  echo "OK: Rules count ($RULE_COUNT)"
fi

# Commands
CMD_COUNT=$(find commands -name "*.md" | wc -l | tr -d ' ')
if [[ "$CMD_COUNT" -ne 9 ]]; then
  echo "FAIL: Expected 9 commands, found $CMD_COUNT"
  FAILED=1
else
  echo "OK: Commands count ($CMD_COUNT)"
fi

# Prompts
PROMPT_COUNT=$(find prompts -name "*.md" | wc -l | tr -d ' ')
if [[ "$PROMPT_COUNT" -ne 5 ]]; then
  echo "FAIL: Expected 5 prompts, found $PROMPT_COUNT"
  FAILED=1
else
  echo "OK: Prompts count ($PROMPT_COUNT)"
fi

exit $FAILED
```

**What Fails**: Component counts don't match documentation

### 5. validate-install.sh
**Purpose**: Simulate installation and verify result

```bash
#!/bin/bash
set -euo pipefail

TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

export HOME="$TEST_DIR"
mkdir -p "$TEST_DIR/.claude"

# Simulate install (copy files)
cp -r skills "$TEST_DIR/.claude/"
cp -r agents "$TEST_DIR/.claude/"
cp -r commands "$TEST_DIR/.claude/"
cp -r hooks "$TEST_DIR/.claude/"
cp -r rules "$TEST_DIR/.claude/"
cp -r prompts "$TEST_DIR/.claude/"
cp -r config "$TEST_DIR/.claude/"
cp CLAUDE.md "$TEST_DIR/.claude/"

# Set permissions
chmod +x "$TEST_DIR/.claude/hooks/"*.py
chmod +x "$TEST_DIR/.claude/hooks/"*.sh
chmod +x "$TEST_DIR/.claude/hooks/workflows/"*.sh

# Verify
FAILED=0

if [[ ! -x "$TEST_DIR/.claude/hooks/keyword-detector.py" ]]; then
  echo "FAIL: keyword-detector.py not executable"
  FAILED=1
fi

if [[ ! -f "$TEST_DIR/.claude/skills/planning-with-files/SKILL.md" ]]; then
  echo "FAIL: skills not copied correctly"
  FAILED=1
fi

if [[ "$FAILED" -eq 0 ]]; then
  echo "OK: Installation simulation passed"
fi

exit $FAILED
```

**What Fails**: Installation process breaks

### 6. validate-all.sh (Master Script)
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=0

echo "=== JSON Validation ==="
"$SCRIPT_DIR/validate-json.sh" || FAILED=1

echo ""
echo "=== Hook Validation ==="
"$SCRIPT_DIR/validate-hooks.sh" || FAILED=1

echo ""
echo "=== Wiring Validation ==="
"$SCRIPT_DIR/validate-wiring.sh" || FAILED=1

echo ""
echo "=== Count Validation ==="
"$SCRIPT_DIR/validate-counts.sh" || FAILED=1

echo ""
echo "=== Install Simulation ==="
"$SCRIPT_DIR/validate-install.sh" || FAILED=1

echo ""
if [[ "$FAILED" -eq 0 ]]; then
  echo "✓ All validations passed"
else
  echo "✗ Some validations failed"
fi

exit $FAILED
```

## Unit Tests (BATS)

### hooks-unit-tests.bats
```bash
#!/usr/bin/env bats

setup() {
  export TEST_DIR=$(mktemp -d)
  export REPO_ROOT="$TEST_DIR/repo"
  mkdir -p "$REPO_ROOT"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "todo-enforcer: allows exit when no todos" {
  # Create mock jq response (no incomplete todos)
  cat > "$TEST_DIR/mock_jq" << 'EOF'
#!/bin/bash
echo "[]"
EOF
  chmod +x "$TEST_DIR/mock_jq"

  PATH="$TEST_DIR:$PATH" run bash hooks/todo-enforcer.sh
  [ "$status" -eq 0 ]
}

@test "todo-enforcer: blocks when incomplete todos exist" {
  cat > "$TEST_DIR/mock_jq" << 'EOF'
#!/bin/bash
echo '[{"content": "Fix bug", "status": "pending"}]'
EOF
  chmod +x "$TEST_DIR/mock_jq"

  PATH="$TEST_DIR:$PATH" run bash hooks/todo-enforcer.sh
  [ "$status" -ne 0 ]
}

@test "keyword-detector: detects ultrawork keyword" {
  echo '{"content": "Use ultrawork mode"}' | run python3 hooks/keyword-detector.py
  [ "$status" -eq 0 ]
  [[ "$output" == *"ultrawork"* ]]
}

@test "check-comments: accepts low comment ratio" {
  # Mock tool output with 10% comments
  echo '{"tool": "Write", "output": "function foo() { return 1; }"}' | \
    run python3 hooks/check-comments.py
  [ "$status" -eq 0 ]
}
```

## CI Integration

### GitHub Actions Workflow (.github/workflows/validate.yml)
```yaml
name: Validate

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y jq

      - name: Run validations
        run: |
          chmod +x scripts/ci/*.sh
          ./scripts/ci/validate-all.sh

      - name: Run BATS tests
        run: |
          npm install -g bats
          bats scripts/test/*.bats
```

## Regression Tests

### What to Test on Every PR

| Test | Catches |
|------|---------|
| validate-json.sh | JSON syntax errors |
| validate-hooks.sh | Script syntax errors |
| validate-wiring.sh | Broken references |
| validate-counts.sh | Missing/extra components |
| validate-install.sh | Installation regressions |

### Manual Tests for P0/P1 Fixes

| Fix | Manual Verification |
|-----|---------------------|
| install.sh creation | `./install.sh && ls ~/.claude/hooks/` |
| Command injection fix | `WORKFLOWS_TEST_CMD="rm -rf /; echo pwned" ./hooks/workflows/require-green-tests.sh` |
| State sourcing fix | `echo 'echo PWNED' > .claude/.state/last_tests.env && ./hooks/workflows/require-green-tests.sh` |

## Test Coverage Matrix

| Component | Syntax | Existence | Wiring | Count | Behavior |
|-----------|--------|-----------|--------|-------|----------|
| Skills | - | ✓ | ✓ | ✓ | Manual |
| Agents | - | ✓ | ✓ | ✓ | Manual |
| Commands | - | ✓ | ✓ | ✓ | Manual |
| Hooks | ✓ | ✓ | ✓ | ✓ | BATS |
| Rules | - | ✓ | ✓ | ✓ | Manual |
| Prompts | - | ✓ | ✓ | ✓ | Manual |
| Config | ✓ | ✓ | ✓ | ✓ | - |
