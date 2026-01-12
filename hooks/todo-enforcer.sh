#!/usr/bin/env bash
set -euo pipefail
CONFIG_FILE="$HOME/.claude/hooks/todo-enforcer.config.json"
DEBUG_LOG="$HOME/.claude/hooks/todo-enforcer.log"
MAX_BLOCKS=10

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${2:-INFO}] $1" >> "$DEBUG_LOG" 2>/dev/null || true; }
allow_exit() { [[ -n "${1:-}" ]] && log "Allowing: $1"; exit 0; }

command -v jq &>/dev/null || { log "jq required" "ERROR"; exit 0; }
[[ -f ".claude/ralph-loop.local.md" ]] && exit 0

load_cfg() { [[ -f "$CONFIG_FILE" ]] && cat "$CONFIG_FILE" 2>/dev/null || echo '{"enabled":true,"block_count":0}'; }
save_cfg() { echo "$1" > "$CONFIG_FILE" 2>/dev/null || true; }

HOOK_INPUT=$(cat)
log "Hook started"
CONFIG=$(load_cfg)
[[ "$(echo "$CONFIG" | jq -r '.enabled // true')" != "true" ]] && allow_exit "Disabled"

read -r SID TPATH ACTIVE < <(echo "$HOOK_INPUT" | jq -r '[.session_id // "unknown", .transcript_path // "", .stop_hook_active // false] | @tsv')
log "Session: $SID | active: $ACTIVE"

[[ "$ACTIVE" == "true" && "$(echo "$CONFIG" | jq -r '.last_block_session // ""')" == "$SID" ]] && { CONFIG=$(echo "$CONFIG" | jq '.block_count = 0'); save_cfg "$CONFIG"; }
[[ -z "$TPATH" || ! -f "$TPATH" ]] && allow_exit "No transcript"

TODOS=$(jq -s '[.[] | .message.content[]? | select(.type == "tool_use" and .name == "TodoWrite") | .input.todos] | last // empty' "$TPATH" 2>/dev/null || echo "")
[[ -z "$TODOS" || "$TODOS" == "null" ]] && { CONFIG=$(echo "$CONFIG" | jq '.block_count = 0'); save_cfg "$CONFIG"; allow_exit "No todos"; }

read -r PEND PROG < <(echo "$TODOS" | jq -r '[[.[] | select(.status == "pending")] | length, [.[] | select(.status == "in_progress")] | length] | @tsv')
INC=$((PEND + PROG))
log "Pending: $PEND, In progress: $PROG"
[[ "$INC" -eq 0 ]] && { CONFIG=$(echo "$CONFIG" | jq '.block_count = 0'); save_cfg "$CONFIG"; allow_exit "All done"; }

read -r BC LS < <(echo "$CONFIG" | jq -r '[.block_count // 0, .last_block_session // ""] | @tsv')
[[ "$LS" == "$SID" ]] && BC=$((BC + 1)) || BC=1
[[ "$BC" -ge "$MAX_BLOCKS" ]] && { log "Safety valve" "WARN"; CONFIG=$(echo "$CONFIG" | jq '.block_count = 0'); save_cfg "$CONFIG"; allow_exit "Safety valve"; }

CONFIG=$(echo "$CONFIG" | jq --arg s "$SID" --argjson c "$BC" '.block_count = $c | .last_block_session = $s')
save_cfg "$CONFIG"
log "Blocking (count: $BC): $INC incomplete"

TASKS=$(echo "$TODOS" | jq -r '([.[] | select(.status == "in_progress") | "  → [in progress] \(.content)"] + [.[] | select(.status == "pending") | "  ○ [pending] \(.content)"]) | join("\n")')
jq -n --arg r "You have $INC incomplete todo(s):
$TASKS

Complete these tasks before stopping." '{"decision": "block", "reason": $r}'
exit 0
