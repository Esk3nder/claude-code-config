#!/usr/bin/env python3
"""Parallel Dispatch Guide - PreToolUse Hook. Auto-dispatches parallel agents when sequential exploration detected."""
import json, sys, time, re
from pathlib import Path

STATE_DIR = Path.home() / ".claude" / "hooks" / "state"
STATE_FILE, CONTEXT_FILE = STATE_DIR / "parallel-dispatch.json", STATE_DIR / "session-context.json"
EXPLORATION_TOOLS = {"Read", "Grep", "Glob"}
READ_ONLY_BASH = re.compile(r'^(ls|find|git\s+(status|log|diff|show|branch)|cat|head|tail|wc|tree|file)\b')
MIN_SCORE, WINDOW_SEC, MAX_AGENTS = 2, 60, 5

def load_state() -> dict:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if STATE_FILE.exists():
        try:
            data = json.loads(STATE_FILE.read_text())
            if time.time() - data.get("last_update_ts", 0) <= 1800: return data
        except: pass
    return {"exploration_count": 0, "first_exploration_ts": None, "agents_dispatched": False, "dispatched_agents": [], "last_update_ts": time.time()}

def save_state(state: dict) -> None:
    state["last_update_ts"] = time.time()
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def load_context_flags() -> dict:
    if CONTEXT_FILE.exists():
        try:
            data = json.loads(CONTEXT_FILE.read_text())
            if time.time() - data.get("timestamp", 0) < 300: return data
        except: pass
    return {}

def should_intercept(tool_name: str, tool_input: dict) -> bool:
    if tool_name in EXPLORATION_TOOLS: return True
    return tool_name == "Bash" and bool(READ_ONLY_BASH.match(tool_input.get("command", "").strip()))

def calculate_score(state: dict, ctx: dict) -> int:
    score = sum([ctx.get("review_security", False) * 3, ctx.get("review_performance", False) * 3, ctx.get("review_architecture", False) * 3, ctx.get("review_mode", False) * 2, ctx.get("multi_module", False) * 3, ctx.get("exploration_mode", False) * 2, ctx.get("library_context", False) * 2])
    first_ts = state.get("first_exploration_ts")
    if first_ts and (time.time() - first_ts) < WINDOW_SEC:
        count = state.get("exploration_count", 0)
        score += 2 if count >= 3 else (1 if count >= 2 else 0)
    return score

def determine_agents(ctx: dict) -> list:
    agents = []
    if ctx.get("review_security"): agents.append("security-sentinel")
    if ctx.get("review_performance"): agents.append("performance-oracle")
    if ctx.get("review_architecture"): agents.append("architecture-strategist")
    if ctx.get("review_mode") and not agents: agents.extend(["code-simplicity", "pattern-recognition"])
    if ctx.get("exploration_mode"): agents.append("codebase-search")
    if ctx.get("library_context"): agents.append("open-source-librarian")
    return list(dict.fromkeys(agents))[:MAX_AGENTS]

def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    if not should_intercept(data.get("tool_name", ""), data.get("tool_input", {})): sys.exit(0)
    state, ctx = load_state(), load_context_flags()
    if state.get("agents_dispatched"): sys.exit(0)
    now = time.time()
    first_ts = state.get("first_exploration_ts")
    if first_ts is None or (now - first_ts) > WINDOW_SEC:
        state["first_exploration_ts"], state["exploration_count"] = now, 0
    state["exploration_count"] = state.get("exploration_count", 0) + 1
    save_state(state)
    if calculate_score(state, ctx) >= MIN_SCORE:
        agents = determine_agents(ctx)
        if agents:
            state["agents_dispatched"], state["dispatched_agents"] = True, agents
            save_state(state)
            msg = f"[PARALLEL AGENTS AUTO-DISPATCHED]\n\nDispatching: {', '.join(agents)}\n\nRunning in background. Use TaskOutput to collect results."
            print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "autoDispatch": agents, "dispatchMode": "background", "systemMessage": msg}}))
    sys.exit(0)

if __name__ == "__main__":
    main()
