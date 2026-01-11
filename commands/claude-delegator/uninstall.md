---
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
description: Uninstall claude-delegator (remove MCP config and rules/prompts)
timeout: 30000
---

# Uninstall (claude-delegator)

Remove Codex MCP configuration and delegator rules/prompts.

## Confirm Removal

**Question**: "Remove Codex MCP configuration and delegator rules/prompts?"
**Options**:
- "Yes, uninstall"
- "No, cancel"

If cancelled, stop here.

## Remove MCP Configuration

Read `~/.claude/settings.json`, delete `mcpServers.codex` entry, write back.

## Remove Installed Rules + Prompts

```bash
rm -rf ~/.claude/rules/delegator/
rm -rf ~/.claude/prompts/delegator/
```

## Confirm Completion

```
OK: Removed 'codex' from MCP servers
OK: Removed rules from ~/.claude/rules/delegator/
OK: Removed prompts from ~/.claude/prompts/delegator/

To reinstall: /claude-delegator/setup
```
