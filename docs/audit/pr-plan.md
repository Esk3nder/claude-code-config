# PR Plan

**Generated**: 2026-01-11

## Overview

This document provides an ordered remediation plan for P0 and P1 issues identified in the audit, with optional P2 improvements.

## PR Strategy

| Priority | PRs | Focus |
|----------|-----|-------|
| P0 | 2 | Critical fixes (install.sh, command injection) |
| P1 | 2 | Security hardening, CI setup |
| P2 | 1 | Robustness improvements |

## PR 1: Create install.sh (P0)

**Branch**: `fix/add-install-script`

**Goal**: Implement the documented install.sh script that README references.

### Changes

#### New File: install.sh
```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

echo "Installing claude-code-config to $CLAUDE_DIR..."

# Create directories
mkdir -p "$CLAUDE_DIR"/{skills,agents,commands,hooks,rules,prompts,config}
mkdir -p "$CLAUDE_DIR/hooks/workflows"
mkdir -p "$CLAUDE_DIR/commands/workflows"
mkdir -p "$CLAUDE_DIR/commands/claude-delegator"
mkdir -p "$CLAUDE_DIR/rules/delegator"
mkdir -p "$CLAUDE_DIR/prompts/delegator"
mkdir -p "$CLAUDE_DIR/config/delegator"
mkdir -p "$CLAUDE_DIR/agents/review"

# Copy files
cp -r "$SCRIPT_DIR/skills/"* "$CLAUDE_DIR/skills/"
cp -r "$SCRIPT_DIR/agents/"* "$CLAUDE_DIR/agents/"
cp -r "$SCRIPT_DIR/commands/"* "$CLAUDE_DIR/commands/"
cp -r "$SCRIPT_DIR/hooks/"* "$CLAUDE_DIR/hooks/"
cp -r "$SCRIPT_DIR/rules/"* "$CLAUDE_DIR/rules/"
cp -r "$SCRIPT_DIR/prompts/"* "$CLAUDE_DIR/prompts/"
cp -r "$SCRIPT_DIR/config/"* "$CLAUDE_DIR/config/"
cp "$SCRIPT_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"

# Set executable permissions on hooks
chmod +x "$CLAUDE_DIR/hooks/"*.py 2>/dev/null || true
chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true
chmod +x "$CLAUDE_DIR/hooks/workflows/"*.sh 2>/dev/null || true

# Merge settings.json
SETTINGS_FILE="$CLAUDE_DIR/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
  echo ""
  echo "WARNING: $SETTINGS_FILE exists."
  echo "Please manually merge the hook configuration from INSTALL.md"
  echo "See: INSTALL.md lines 105-122"
else
  cat > "$SETTINGS_FILE" << 'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "./hooks/keyword-detector.py" }] }
    ],
    "PostToolUse": [
      { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "./hooks/check-comments.py" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "./hooks/workflows/require-green-tests.sh" }] },
      { "hooks": [{ "type": "command", "command": "./hooks/todo-enforcer.sh" }] }
    ]
  }
}
EOF
  echo "Created $SETTINGS_FILE with hook configuration"
fi

echo ""
echo "Installation complete!"
echo "Restart Claude Code for changes to take effect."
```

### Verification
```bash
./install.sh
test -f ~/.claude/hooks/keyword-detector.py && echo "OK"
test -x ~/.claude/hooks/keyword-detector.py && echo "Executable OK"
```

---

## PR 2: Fix Command Injection in require-green-tests.sh (P0)

**Branch**: `fix/command-injection-security`

**Goal**: Prevent arbitrary command execution via WORKFLOWS_TEST_CMD.

### Changes

#### Edit: hooks/workflows/require-green-tests.sh

**Before** (lines 10-18):
```bash
pick_test_cmd() {
  if [[ -n "${WORKFLOWS_TEST_CMD-}" ]]; then
    echo "$WORKFLOWS_TEST_CMD"
    return
  fi
  if [[ -n "${SUPERPOWERS_TEST_CMD-}" ]]; then
    echo "$SUPERPOWERS_TEST_CMD"
    return
  fi
```

**After**:
```bash
# Allowlist of safe test commands
SAFE_TEST_CMDS=(
  "npm test"
  "pnpm test"
  "yarn test"
  "bun test"
  "pytest"
  "go test ./..."
  "cargo test"
  "mix test"
  "bundle exec rspec"
  "make test"
)

validate_test_cmd() {
  local cmd="$1"
  for safe in "${SAFE_TEST_CMDS[@]}"; do
    if [[ "$cmd" == "$safe"* ]]; then
      return 0
    fi
  done
  return 1
}

pick_test_cmd() {
  if [[ -n "${WORKFLOWS_TEST_CMD-}" ]]; then
    if validate_test_cmd "$WORKFLOWS_TEST_CMD"; then
      echo "$WORKFLOWS_TEST_CMD"
      return
    else
      echo "WARNING: WORKFLOWS_TEST_CMD '$WORKFLOWS_TEST_CMD' not in allowlist, using auto-detection" >&2
    fi
  fi
  if [[ -n "${SUPERPOWERS_TEST_CMD-}" ]]; then
    if validate_test_cmd "$SUPERPOWERS_TEST_CMD"; then
      echo "$SUPERPOWERS_TEST_CMD"
      return
    else
      echo "WARNING: SUPERPOWERS_TEST_CMD not in allowlist, using auto-detection" >&2
    fi
  fi
```

### Verification
```bash
# Should warn and fall back to auto-detection
WORKFLOWS_TEST_CMD="rm -rf /" ./hooks/workflows/require-green-tests.sh
# Should use command
WORKFLOWS_TEST_CMD="npm test" ./hooks/workflows/require-green-tests.sh
```

---

## PR 3: Fix State File Sourcing Vulnerability (P1)

**Branch**: `fix/state-file-security`

**Goal**: Parse state file safely without bash source.

### Changes

#### Edit: hooks/workflows/require-green-tests.sh

**Before** (around line 55):
```bash
if [[ -f "$STATE_FILE" ]]; then
  source "$STATE_FILE"
```

**After**:
```bash
if [[ -f "$STATE_FILE" ]]; then
  # Safely parse key=value without sourcing
  while IFS='=' read -r key value; do
    # Only allow expected variables, strip quotes
    case "$key" in
      LAST_SHA) LAST_SHA="${value//\"/}" ;;
      LAST_RESULT) LAST_RESULT="${value//\"/}" ;;
    esac
  done < "$STATE_FILE"
```

### Verification
```bash
echo 'echo PWNED' > .claude/.state/last_tests.env
./hooks/workflows/require-green-tests.sh
# Should NOT print "PWNED"
```

---

## PR 4: Add CI Validation Workflow (P1)

**Branch**: `feat/add-ci-validation`

**Goal**: Automated validation on every PR.

### Changes

#### New File: .github/workflows/validate.yml
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
        run: sudo apt-get install -y jq

      - name: Validate JSON
        run: |
          for f in config/delegator/*.json; do
            jq empty "$f" || exit 1
          done

      - name: Validate shell scripts
        run: |
          for f in hooks/*.sh hooks/workflows/*.sh; do
            bash -n "$f" || exit 1
          done

      - name: Validate Python scripts
        run: |
          for f in hooks/*.py; do
            python3 -m py_compile "$f" || exit 1
          done

      - name: Validate component counts
        run: |
          test $(find skills -name "SKILL.md" | wc -l) -eq 16
          test $(find agents -name "*.md" | wc -l) -eq 19
          test $(find hooks -type f \( -name "*.sh" -o -name "*.py" \) | wc -l) -eq 4
          test $(find rules -name "*.md" | wc -l) -eq 8
          test $(find commands -name "*.md" | wc -l) -eq 9
```

#### New Files: scripts/ci/*.sh
(As defined in test-plan.md)

### Verification
```bash
./scripts/ci/validate-all.sh
```

---

## PR 5: Robustness Improvements (P2)

**Branch**: `improve/robustness`

**Goal**: Add dependency checks, improve error messages.

### Changes

1. **Add dependency check to todo-enforcer.sh**:
```bash
# At script start
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required but not installed" >&2
  exit 1
fi
```

2. **Add dependency check to Python hooks**:
```python
# At script start
import sys
if sys.version_info < (3, 8):
    print("ERROR: Python 3.8+ required", file=sys.stderr)
    sys.exit(1)
```

3. **Set secure permissions on state files**:
```bash
# In require-green-tests.sh, when creating state
umask 077
echo "LAST_SHA=\"$CURRENT_SHA\"" > "$STATE_FILE"
echo "LAST_RESULT=\"$RESULT\"" >> "$STATE_FILE"
```

---

## Commit Order

```
PR 1: fix/add-install-script
├── Add install.sh
└── Verify: ./install.sh works

PR 2: fix/command-injection-security
├── Add SAFE_TEST_CMDS allowlist
├── Add validate_test_cmd function
└── Verify: injection blocked

PR 3: fix/state-file-security
├── Replace source with safe parsing
└── Verify: code injection blocked

PR 4: feat/add-ci-validation
├── Add .github/workflows/validate.yml
├── Add scripts/ci/*.sh
└── Verify: CI passes

PR 5: improve/robustness
├── Add dependency checks
├── Set secure file permissions
└── Verify: graceful errors
```

## Success Criteria

| PR | Success When |
|----|--------------|
| 1 | `./install.sh && test -x ~/.claude/hooks/keyword-detector.py` |
| 2 | Malicious WORKFLOWS_TEST_CMD is rejected |
| 3 | Malicious state file does not execute code |
| 4 | GitHub Actions workflow passes |
| 5 | Missing `jq` shows clear error message |

## Final Confidence

- **Confidence**: 0.85
- **Top Uncertainties**:
  1. Claude Code runtime behavior for skill activation (cannot test without running Claude Code)
  2. Exact settings.json merge behavior when user has existing config
  3. Cross-platform compatibility of install.sh (tested on macOS/Linux only)

**Files/commands to resolve uncertainties**:
1. Test skill activation in live Claude Code session
2. Test install.sh with existing ~/.claude/settings.json
3. Test on Windows with Git Bash or WSL
