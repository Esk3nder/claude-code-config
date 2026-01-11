---
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
argument-hint: [model]
description: Configure Codex MCP server and verify delegator rules/prompts
timeout: 60000
---

# Setup (claude-delegator)

Configure Codex (GPT) as specialized expert subagents via MCP, and install delegator rules/prompts.

## Step 1: Check Codex CLI

```bash
which codex 2>/dev/null && codex --version 2>&1 | head -1 || echo "CODEX_MISSING"
```

### If Missing
Tell user:
```
Codex CLI not found.

Install with: npm install -g @openai/codex
Then authenticate: codex login

After installation, re-run /claude-delegator/setup
```

**STOP here if Codex is not installed.**

## Step 2: Read Current Settings

```bash
cat ~/.claude/settings.json 2>/dev/null || echo "{}"
```

## Step 3: Configure MCP Server

Merge into `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "codex": {
      "type": "stdio",
      "command": "codex",
      "args": ["-m", "gpt-5.2-codex", "mcp-server"]
    }
  }
}
```

Notes:
- Use `gpt-5.2-codex` explicitly for the latest model.
- Merge with existing settings; do not overwrite.

## Step 4: Verify Delegator Rules + Prompts

```bash
mkdir -p ~/.claude/rules/delegator ~/.claude/prompts/delegator

RULES_COUNT=$(ls ~/.claude/rules/delegator/*.md 2>/dev/null | wc -l | tr -d ' ')
PROMPTS_COUNT=$(ls ~/.claude/prompts/delegator/*.md 2>/dev/null | wc -l | tr -d ' ')

if [[ "$RULES_COUNT" == "0" || "$PROMPTS_COUNT" == "0" ]]; then
  echo \"Delegator files missing. Reinstall this config or re-run the manual install prompt.\"
fi
```

## Step 5: Verify Installation

```bash
# Check 1: Codex CLI version
codex --version 2>&1 | head -1

# Check 2: MCP server configured
cat ~/.claude/settings.json | jq -r '.mcpServers.codex.args | join(" ")' 2>/dev/null

# Check 3: Rules installed
ls ~/.claude/rules/delegator/*.md 2>/dev/null | wc -l

# Check 4: Prompts installed
ls ~/.claude/prompts/delegator/*.md 2>/dev/null | wc -l

# Check 5: Auth status
codex login status 2>&1 | head -1 || echo "Run 'codex login' to authenticate"
```

## Step 6: Report Status

```
claude-delegator Status
----------------------------------------
Codex CLI:     [version from check 1]
Model:         gpt-5.2-codex (or NOT CONFIGURED)
MCP Config:    ~/.claude/settings.json (or MISSING)
Rules:         [N] files in ~/.claude/rules/delegator/
Prompts:       [N] files in ~/.claude/prompts/delegator/
Auth:          [status from check 5]
----------------------------------------
```

If any check fails, report the specific issue and how to fix it.

## Step 7: Next Steps

```
Setup complete!

Next steps:
1. Restart Claude Code to load MCP server
2. Authenticate: Run `codex login` in terminal (if not already done)

Experts available:
- Architect (design/tradeoffs)
- Plan Reviewer (plan completeness)
- Scope Analyst (requirements ambiguity)
- Code Reviewer (bugs/maintainability)
- Security Analyst (vuln review/hardening)
```
