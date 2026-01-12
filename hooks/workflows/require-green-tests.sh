#!/usr/bin/env bash
set -euo pipefail
umask 077
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE_DIR="$REPO_ROOT/.claude/.state"
STATE_FILE="$STATE_DIR/last_tests.env"
mkdir -p "$STATE_DIR"

is_safe() { [[ ! "$1" =~ [$'\n\r\t'] && ! "$1" =~ [\;\&\|\<\>\$\`\\\'\"\(\)\{\}\[\]\*\?\#\!] ]]; }

is_test_cmd() {
    local -a t; read -r -a t <<<"$1"; ((${#t[@]} >= 1)) || return 1
    case "${t[0]}" in
        npm|pnpm|yarn) [[ "${t[1]-}" == "test" || ("${t[1]-}" == "run" && "${t[2]-}" == test*) ]] ;;
        bun) [[ "${t[1]-}" == "test" ]] ;;
        pytest) return 0 ;;
        python|python3) [[ "${t[1]-}" == "-m" && "${t[2]-}" == "pytest" ]] ;;
        go|cargo|mix) [[ "${t[1]-}" == "test" ]] ;;
        bundle) [[ "${t[1]-}" == "exec" && "${t[2]-}" == "rspec" ]] ;;
        make|just) [[ "${t[1]-}" == test* ]] ;;
        *) return 1 ;;
    esac
}

validated_cmd() {
    [[ -n "${2-}" ]] || return 1
    is_safe "$2" && is_test_cmd "$2" && echo "$2" || { echo "Stop hook: rejecting $1" >&2; return 1; }
}

pick_cmd() {
    local c; c="$(validated_cmd "WORKFLOWS_TEST_CMD" "${WORKFLOWS_TEST_CMD-}")" && { echo "$c"; return; }
    c="$(validated_cmd "SUPERPOWERS_TEST_CMD" "${SUPERPOWERS_TEST_CMD-}")" && { echo "$c"; return; }
    [[ -f "$REPO_ROOT/pnpm-lock.yaml" ]] && { echo "pnpm test"; return; }
    [[ -f "$REPO_ROOT/yarn.lock" ]] && { echo "yarn test"; return; }
    [[ -f "$REPO_ROOT/package-lock.json" || -f "$REPO_ROOT/npm-shrinkwrap.json" ]] && { echo "npm test"; return; }
    [[ -f "$REPO_ROOT/package.json" ]] && { echo "npm test"; return; }
    echo "skip"
}

newest_mtime() {
    git -C "$REPO_ROOT" rev-parse --is-inside-work-tree &>/dev/null || { echo "0"; return; }
    local n; n=$([[ "$(uname -s)" == "Darwin" ]] && git -C "$REPO_ROOT" ls-files -z 2>/dev/null | xargs -0 stat -f "%m" 2>/dev/null | sort -n | tail -1 || git -C "$REPO_ROOT" ls-files -z 2>/dev/null | xargs -0 stat -c "%Y" 2>/dev/null | sort -n | tail -1)
    echo "${n:-0}"
}

sha256() { command -v shasum &>/dev/null && printf '%s' "$1" | shasum -a 256 | awk '{print $1}' || printf '%s' "$1" | sha256sum | awk '{print $1}'; }

load_state() {
    PREV_STATUS="" PREV_CMD_HASH="" PREV_MTIME=0
    [[ -f "$STATE_FILE" ]] || return 0
    while IFS='=' read -r k v; do
        case "$k" in PREV_STATUS) PREV_STATUS="$v" ;; PREV_CMD_HASH) PREV_CMD_HASH="$v" ;; PREV_MTIME) PREV_MTIME="$v" ;; esac
    done < "$STATE_FILE"
    [[ "$PREV_STATUS" == "green" ]] || PREV_STATUS=""
    [[ "$PREV_MTIME" =~ ^[0-9]+$ ]] || PREV_MTIME=0
    [[ "$PREV_CMD_HASH" =~ ^[0-9a-fA-F]{64}$ ]] || PREV_CMD_HASH=""
}

write_green() {
    local tmp; tmp="$(mktemp "$STATE_DIR/last_tests.env.tmp.XXXXXX")"
    { date -u +"ran_at=%Y-%m-%dT%H:%M:%SZ"; echo "PREV_STATUS=green"; [[ -n "$1" ]] && echo "PREV_CMD_HASH=$1"; echo "PREV_MTIME=$2"; } >"$tmp"
    mv "$tmp" "$STATE_FILE"
}

print_output() {
    local max="${WORKFLOWS_TEST_MAX_OUTPUT_LINES:-200}" total
    total=$(wc -l <"$1" | tr -d ' ')
    [[ "$total" -gt "$max" ]] && { echo "Stop hook: truncated (last $max of $total lines)."; tail -n "$max" "$1"; } || cat "$1"
}

TEST_CMD=$(pick_cmd)
[[ "$TEST_CMD" == "skip" ]] && { echo "Stop hook: no test infrastructure; skipping."; exit 0; }
MTIME=$(newest_mtime)
CMD_HASH="$(sha256 "$TEST_CMD" 2>/dev/null || echo "")"
load_state

[[ "$PREV_STATUS" == "green" && -n "$CMD_HASH" && "$PREV_CMD_HASH" == "$CMD_HASH" && "$PREV_MTIME" -ge "$MTIME" ]] && { echo "Stop hook: tests already green."; exit 0; }

echo "Stop hook: running: $TEST_CMD"
OUT="$(mktemp "$STATE_DIR/test-output.XXXXXX")"; trap "rm -f '$OUT'" EXIT
set +e; cd "$REPO_ROOT" && bash -lc "$(printf '%q ' $TEST_CMD)" >"$OUT" 2>&1; STATUS=$?; set -e
print_output "$OUT"
[[ $STATUS -eq 0 ]] && { write_green "$CMD_HASH" "$MTIME"; echo "Stop hook: tests green."; exit 0; } || { echo "Stop hook: tests failed (exit $STATUS)." >&2; exit $STATUS; }
