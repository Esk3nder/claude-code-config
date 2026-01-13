#!/usr/bin/env bash
#
# Require Clean Types - Claude Code Stop Hook
# Blocks exit when type checking fails.
#
# SPDX-License-Identifier: MIT
#
# Environment variables:
#   WORKFLOWS_TYPE_CMD      - Override type check command (must be in allowlist)
#   WORKFLOWS_SKIP_TYPES    - Set to "true" to skip type checks
#   WORKFLOWS_TYPE_TIMEOUT  - Timeout in seconds (default: 180)

set -euo pipefail

umask 077

# Timeout configuration (default: 180 seconds = 3 minutes)
WORKFLOWS_TYPE_TIMEOUT="${WORKFLOWS_TYPE_TIMEOUT:-180}"

# Opt-out flag - skip type checking entirely if set to "true"
if [[ "${WORKFLOWS_SKIP_TYPES:-false}" == "true" ]]; then
  echo "Stop hook: type checking skipped via WORKFLOWS_SKIP_TYPES=true"
  exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="$REPO_ROOT/.claude/.state"
STATE_FILE="$STATE_DIR/last_types.env"
mkdir -p "$STATE_DIR"

# Allowlist of safe type check commands
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

is_allowed_type_cmd() {
  local cmd="$1"
  local -a tokens=()
  read -r -a tokens <<<"$cmd"

  ((${#tokens[@]} >= 1)) || return 1

  case "${tokens[0]}" in
    npm)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" =~ ^(typecheck|type-check|tsc|types)$ ]] && return 0
      ;;
    pnpm)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" =~ ^(typecheck|type-check|tsc|types)$ ]] && return 0
      [[ "${tokens[1]-}" == "tsc" ]] && return 0
      ;;
    yarn)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" =~ ^(typecheck|type-check|tsc|types)$ ]] && return 0
      [[ "${tokens[1]-}" == "tsc" ]] && return 0
      ;;
    bun)
      [[ "${tokens[1]-}" == "run" && "${tokens[2]-}" =~ ^(typecheck|type-check|tsc|types)$ ]] && return 0
      ;;
    npx)
      [[ "${tokens[1]-}" =~ ^(tsc|typescript|mypy|pyright)$ ]] && return 0
      ;;
    tsc)
      return 0
      ;;
    python | python3)
      [[ "${tokens[1]-}" == "-m" && "${tokens[2]-}" =~ ^(mypy|pyright)$ ]] && return 0
      ;;
    mypy | pyright)
      return 0
      ;;
    go)
      [[ "${tokens[1]-}" == "build" ]] && return 0
      ;;
    cargo)
      [[ "${tokens[1]-}" == "check" ]] && return 0
      ;;
    make | just)
      [[ "${tokens[1]-}" =~ ^(typecheck|type-check|types)$ ]] && return 0
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

  if ! is_allowed_type_cmd "$value"; then
    echo "Stop hook: rejecting $name (not a recognized type check command); using auto-detection." >&2
    return 1
  fi

  echo "$value"
  return 0
}

pick_type_cmd() {
  local cmd=""
  if cmd="$(validated_override_cmd "WORKFLOWS_TYPE_CMD" "${WORKFLOWS_TYPE_CMD-}")"; then
    echo "$cmd"
    return
  fi

  # TypeScript
  if [[ -f "$REPO_ROOT/tsconfig.json" ]]; then
    if [[ -f "$REPO_ROOT/pnpm-lock.yaml" ]]; then
      echo "pnpm tsc --noEmit"
    elif [[ -f "$REPO_ROOT/yarn.lock" ]]; then
      echo "yarn tsc --noEmit"
    elif [[ -f "$REPO_ROOT/package-lock.json" || -f "$REPO_ROOT/package.json" ]]; then
      echo "npx tsc --noEmit"
    else
      echo "tsc --noEmit"
    fi
    return
  fi

  # Python - mypy
  if [[ -f "$REPO_ROOT/pyproject.toml" ]] && grep -q "mypy" "$REPO_ROOT/pyproject.toml" 2>/dev/null; then
    echo "mypy ."
    return
  fi

  # Python - pyright
  if [[ -f "$REPO_ROOT/pyrightconfig.json" ]] || \
     ([[ -f "$REPO_ROOT/pyproject.toml" ]] && grep -q "pyright" "$REPO_ROOT/pyproject.toml" 2>/dev/null); then
    echo "pyright"
    return
  fi

  # Rust - cargo check (type checking built into compilation)
  if [[ -f "$REPO_ROOT/Cargo.toml" ]]; then
    echo "cargo check"
    return
  fi

  # Go - go build (type checking built into compilation)
  if [[ -f "$REPO_ROOT/go.mod" ]]; then
    echo "go build ./..."
    return
  fi

  # No type checking infrastructure detected
  echo "skip"
}

TYPE_CMD=$(pick_type_cmd)
if [[ "$TYPE_CMD" == "skip" ]]; then
  echo "Stop hook: no type checking infrastructure detected; skipping."
  exit 0
fi

echo "Stop hook: running type check command: $TYPE_CMD"

OUTPUT_FILE="$(mktemp "$STATE_DIR/type-output.XXXXXX")"
cleanup() { rm -f "$OUTPUT_FILE"; }
trap cleanup EXIT

# Determine timeout command (GNU coreutils on Linux, gtimeout on macOS via Homebrew)
TIMEOUT_CMD=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
fi

# Run type check with optional timeout
set +e
if [[ -n "$TIMEOUT_CMD" ]]; then
  cd "$REPO_ROOT" && "$TIMEOUT_CMD" "$WORKFLOWS_TYPE_TIMEOUT" bash -lc "$TYPE_CMD" >"$OUTPUT_FILE" 2>&1
  STATUS=$?
else
  cd "$REPO_ROOT" && bash -lc "$TYPE_CMD" >"$OUTPUT_FILE" 2>&1
  STATUS=$?
fi
set -e

# Handle timeout (exit code 124)
if [[ $STATUS -eq 124 ]]; then
  cat "$OUTPUT_FILE"
  echo "Stop hook: type check timed out after ${WORKFLOWS_TYPE_TIMEOUT}s; blocking completion." >&2
  exit 1
fi

if [[ $STATUS -eq 0 ]]; then
  cat "$OUTPUT_FILE"
  echo "Stop hook: types clean; allowing completion."
  exit 0
else
  cat "$OUTPUT_FILE"
  echo "Stop hook: type check failed (exit $STATUS); blocking completion." >&2
  exit $STATUS
fi
