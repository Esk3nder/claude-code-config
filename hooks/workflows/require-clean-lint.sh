#!/usr/bin/env bash
#
# Require Clean Lint - Claude Code Stop Hook
# Blocks exit when lint checks fail.
#
# SPDX-License-Identifier: MIT
#
# Environment variables:
#   WORKFLOWS_LINT_CMD      - Override lint command (must be in allowlist)
#   WORKFLOWS_SKIP_LINT     - Set to "true" to skip lint checks
#   WORKFLOWS_LINT_TIMEOUT  - Timeout in seconds (default: 120)

set -euo pipefail

umask 077

# Timeout configuration (default: 120 seconds = 2 minutes)
WORKFLOWS_LINT_TIMEOUT="${WORKFLOWS_LINT_TIMEOUT:-120}"

# Opt-out flag - skip lint entirely if set to "true"
if [[ "${WORKFLOWS_SKIP_LINT:-false}" == "true" ]]; then
  echo "Stop hook: lint skipped via WORKFLOWS_SKIP_LINT=true"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="$REPO_ROOT/.claude/.state"
STATE_FILE="$STATE_DIR/last_lint.env"
mkdir -p "$STATE_DIR"

# Allowlist of safe lint commands
is_safe_override_value() {
  local value="$1"

  # Reject shell metacharacters / expansions / quoting / globs / control chars.
  if [[ "$value" == *$'\n'* || "$value" == *$'\r'* || "$value" == *$'\t'* ]]; then
    return 1
  fi
  if [[ "$value" =~ [\;\&\|\<\>\$\`\\\'\"\(\)\{\}\[\]\*\?\#\!] ]]; then
    return 1
  fi

  return 0
}

is_allowed_lint_cmd() {
  local cmd="$1"
  local -a tokens=()
  read -r -a tokens <<<"$cmd"

  ((${#tokens[@]} >= 1)) || return 1

  case "${tokens[0]}" in
    npm)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" == lint* ]] && return 0
      ;;
    pnpm)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" == lint* ]] && return 0
      [[ "${tokens[1]-}" == "lint" ]] && return 0
      ;;
    yarn)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" == lint* ]] && return 0
      [[ "${tokens[1]-}" == "lint" ]] && return 0
      ;;
    bun)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" == lint* ]] && return 0
      ;;
    npx)
      [[ "${tokens[1]-}" =~ ^(eslint|biome|prettier)$ ]] && return 0
      ;;
    eslint | biome | prettier | stylelint)
      return 0
      ;;
    python | python3)
      [[ "${tokens[1]-}" == "-m" && "${tokens[2]-}" =~ ^(ruff|flake8|pylint|black)$ ]] && return 0
      ;;
    ruff | flake8 | pylint | black)
      return 0
      ;;
    go)
      [[ "${tokens[1]-}" == "vet" || "${tokens[1]-}" == "fmt" ]] && return 0
      ;;
    cargo)
      [[ "${tokens[1]-}" == "clippy" || "${tokens[1]-}" == "fmt" ]] && return 0
      ;;
    make | just)
      [[ "${tokens[1]-}" == lint* ]] && return 0
      ;;
  esac

  return 1
}

validated_override_cmd() {
  local name="$1"
  local value="${2-}"
  [[ -n "$value" ]] || return 1

  if ! is_safe_override_value "$value"; then
    echo "Stop hook: rejecting $name (unsafe characters); using auto-detection." >&2
    return 1
  fi

  if ! is_allowed_lint_cmd "$value"; then
    echo "Stop hook: rejecting $name (not a recognized lint command); using auto-detection." >&2
    return 1
  fi

  echo "$value"
  return 0
}

pick_lint_cmd() {
  local cmd=""
  if cmd="$(validated_override_cmd "WORKFLOWS_LINT_CMD" "${WORKFLOWS_LINT_CMD-}")"; then
    echo "$cmd"
    return
  fi

  # Auto-detect based on project configuration
  # Biome
  if [[ -f "$REPO_ROOT/biome.json" || -f "$REPO_ROOT/biome.jsonc" ]]; then
    echo "npx biome check ."
    return
  fi

  # ESLint (various config formats)
  if [[ -f "$REPO_ROOT/eslint.config.js" || -f "$REPO_ROOT/eslint.config.mjs" || \
        -f "$REPO_ROOT/.eslintrc.js" || -f "$REPO_ROOT/.eslintrc.json" || \
        -f "$REPO_ROOT/.eslintrc.yml" || -f "$REPO_ROOT/.eslintrc" ]]; then
    if [[ -f "$REPO_ROOT/pnpm-lock.yaml" ]]; then
      echo "pnpm run lint"
    elif [[ -f "$REPO_ROOT/yarn.lock" ]]; then
      echo "yarn lint"
    elif [[ -f "$REPO_ROOT/package-lock.json" || -f "$REPO_ROOT/package.json" ]]; then
      echo "npm run lint"
    else
      echo "npx eslint ."
    fi
    return
  fi

  # Python - Ruff
  if [[ -f "$REPO_ROOT/pyproject.toml" ]] && grep -q "ruff" "$REPO_ROOT/pyproject.toml" 2>/dev/null; then
    echo "ruff check ."
    return
  fi

  # Python - Flake8
  if [[ -f "$REPO_ROOT/.flake8" ]] || \
     ([[ -f "$REPO_ROOT/setup.cfg" ]] && grep -q "flake8" "$REPO_ROOT/setup.cfg" 2>/dev/null); then
    echo "flake8"
    return
  fi

  # Rust - Clippy
  if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
    echo "cargo clippy -- -D warnings"
    return
  fi

  # Go - vet
  if [[ -f "$REPO_ROOT/go.mod" ]]; then
    echo "go vet ./..."
    return
  fi

  # No lint infrastructure detected
  echo "skip"
}

LINT_CMD=$(pick_lint_cmd)
if [[ "$LINT_CMD" == "skip" ]]; then
  echo "Stop hook: no lint infrastructure detected; skipping."
  exit 0
fi

echo "Stop hook: running lint command: $LINT_CMD"

OUTPUT_FILE="$(mktemp "$STATE_DIR/lint-output.XXXXXX")"
cleanup() { rm -f "$OUTPUT_FILE"; }
trap cleanup EXIT

# Determine timeout command (GNU coreutils on Linux, gtimeout on macOS via Homebrew)
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
fi

# Run lint with optional timeout
set +e
if [[ -n "$TIMEOUT_CMD" ]]; then
  cd "$REPO_ROOT" && "$TIMEOUT_CMD" "$WORKFLOWS_LINT_TIMEOUT" bash -lc "$LINT_CMD" >"$OUTPUT_FILE" 2>&1
  STATUS=$?
else
  cd "$REPO_ROOT" && bash -lc "$LINT_CMD" >"$OUTPUT_FILE" 2>&1
  STATUS=$?
fi
set -e

# Handle timeout (exit code 124)
if [[ $STATUS -eq 124 ]]; then
  cat "$OUTPUT_FILE"
  echo "Stop hook: lint timed out after ${WORKFLOWS_LINT_TIMEOUT}s; blocking completion." >&2
  exit 1
fi

if [[ $STATUS -eq 0 ]]; then
  cat "$OUTPUT_FILE"
  echo "Stop hook: lint clean; allowing completion."
  exit 0
else
  cat "$OUTPUT_FILE"
  echo "Stop hook: lint failed (exit $STATUS); blocking completion." >&2
  exit $STATUS
fi
