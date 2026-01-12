#!/usr/bin/env python3
"""Comment Checker Hook - Analyzes code changes for excessive comments."""
import json, sys, re, os
from pathlib import Path

MAX_COMMENT_RATIO = 0.25
CODE_EXTENSIONS = {'.ts', '.tsx', '.js', '.jsx', '.py', '.go', '.rs', '.java', '.cpp', '.c', '.sol'}
VALID_PATTERNS = [
    r'^\s*#\s*#?\s*(given|when|then|and|but)\b', r'^\s*//\s*#?\s*(given|when|then|and|but)\b',
    r'^\s*"""', r"^\s*'''", r'^\s*/\*\*', r'^\s*\*\s*@', r'^\s*#!',
    r'^\s*//\s*@ts-', r'^\s*//\s*eslint-', r'^\s*#\s*type:', r'^\s*#\s*noqa', r'^\s*#\s*pragma',
    r'^\s*//\s*TODO:', r'^\s*//\s*FIXME:', r'^\s*#\s*TODO:', r'^\s*#\s*FIXME:',
    r'^\s*///\s*', r'^\s*///', r'^\s*@dev', r'^\s*@param', r'^\s*@return', r'^\s*@notice',
]

def safe_json_parse(raw: str) -> dict:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        fixed, in_string, escape_next = [], False, False
        for char in raw:
            if escape_next:
                fixed.append(char); escape_next = False
            elif char == '\\':
                fixed.append(char); escape_next = True
            elif char == '"':
                fixed.append(char); in_string = not in_string
            elif in_string and ord(char) < 32:
                fixed.append({'\\n': '\\n', '\r': '\\r', '\t': '\\t'}.get(char, f'\\u{ord(char):04x}'))
            else:
                fixed.append(char)
        return json.loads(''.join(fixed))

def is_valid_comment(line: str) -> bool:
    return any(re.match(p, line, re.IGNORECASE) for p in VALID_PATTERNS)

def is_comment_line(line: str, ext: str) -> bool:
    s = line.strip()
    if not s: return False
    if ext == '.py': return s.startswith('#')
    if ext in {'.ts', '.tsx', '.js', '.jsx', '.java', '.go', '.rs', '.cpp', '.c', '.sol'}:
        return s.startswith('//') or s.startswith('/*') or s.startswith('*')
    return False

def analyze_content(content: str, file_path: str) -> dict:
    ext = Path(file_path).suffix.lower()
    if ext not in CODE_EXTENSIONS: return {"skip": True}
    lines = content.split('\n')
    total = len([l for l in lines if l.strip()])
    if total == 0: return {"skip": True}
    flagged = [(i, l.strip()) for i, l in enumerate(lines, 1) if is_comment_line(l, ext) and not is_valid_comment(l)]
    ratio = len([l for l in lines if is_comment_line(l, ext)]) / total
    return {"skip": False, "total_lines": total, "comment_lines": len(flagged), "flagged_comments": flagged, "comment_ratio": ratio, "excessive": ratio > MAX_COMMENT_RATIO and len(flagged) > 0}

def main():
    debug_log = os.path.expanduser("~/.claude/hooks/debug.log")
    try:
        raw = sys.stdin.read()
        with open(debug_log, "a") as f: f.write(f"\n=== check-comments.py ===\nInput: {raw[:2000]}\n")
        data = safe_json_parse(raw)
    except Exception as e:
        with open(debug_log, "a") as f: f.write(f"Error: {e}\n")
        sys.exit(0)
    tool_name, tool_input = data.get("tool_name", ""), data.get("tool_input", {})
    file_path = tool_input.get("file_path") or tool_input.get("filePath") or tool_input.get("path", "")
    content = ""
    if tool_name == "Write": content = tool_input.get("content", "")
    elif tool_name in ("Edit", "MultiEdit") and file_path and Path(file_path).exists():
        try: content = Path(file_path).read_text()
        except: pass
    if not file_path or not content: sys.exit(0)
    result = analyze_content(content, file_path)
    if result.get("skip") or not result.get("excessive"): sys.exit(0)
    lines = [f"\n---\n**Comment Check Warning**: {result['comment_ratio']:.0%} of lines are comments\n\nFlagged comments:"]
    for ln, c in result['flagged_comments'][:5]: lines.append(f"  Line {ln}: `{c[:60]}{'...' if len(c) > 60 else ''}`")
    if len(result['flagged_comments']) > 5: lines.append(f"  ... and {len(result['flagged_comments']) - 5} more")
    lines.extend(["\n**Recommendation**: Code should be self-documenting.\n---"])
    print(json.dumps({"hookSpecificOutput": {"additionalContext": "\n".join(lines)}}))
    sys.exit(0)

if __name__ == "__main__":
    main()
