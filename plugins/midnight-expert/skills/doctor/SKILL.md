---
name: midnight-expert:doctor
description: This skill should be used when the user asks to "check my setup", "run diagnostics", "doctor", "health check", "verify my installation", "are my plugins working", "check plugin status", "what's broken", "fix my setup", "debug my environment", "check dependencies", "environment check", "troubleshoot setup", or invokes /midnight-expert:doctor. Provides comprehensive health reporting for the midnight-expert ecosystem — plugin installation, MCP servers, external tools, cross-plugin references, and NPM registry.
version: 0.1.0
---

# Expert Doctor

Comprehensive diagnostic and health report for the midnight-expert ecosystem.

## Usage

- `/midnight-expert:doctor` — run diagnostics interactively, offer fixes one at a time
- `/midnight-expert:doctor --auto-fix` — install missing dependencies silently, prompt only for upgrades and preference choices

## Step 1: Launch & Ask (concurrent)

Launch **all 5 diagnostic agents in background** AND ask the user a question — in a **single message** with 6 tool calls (5 Agent + 1 AskUserQuestion).

Each agent has `subagent_type: "general-purpose"` and `run_in_background: true`. Each agent must run its bash command and return **only** the raw output lines. Do not include markdown fences or any other text in the agent prompt beyond the instruction.

### Agent 1 — Plugin Health

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-plugins.sh"
> ```

### Agent 2 — MCP Servers

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-mcp-servers.sh"
> ```

### Agent 3 — External Tools

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-ext-tools.sh"
> ```

### Agent 4 — Cross-Plugin References

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-cross-refs.sh"
> ```

### Agent 5 — NPM Registry

> Run the following command and return only the output. No other text.
>
> ```
> bash "${CLAUDE_SKILL_DIR}/scripts/check-npm.sh"
> ```

### AskUserQuestion

> Would you also like to check Midnight Tooling status? (Compact CLI, compiler, devnet, proof server)

## Step 2: Handle Response

- If the user says **yes**: invoke the `midnight-tooling:doctor` skill (via Skill tool) and wait for it and all 5 background agents to complete.
- If the user says **no**: wait for the 5 background agents to complete.

## Step 2.5: Handle Agent Failures

If any background agent fails (returns an error instead of structured output), include a single row in the corresponding report section:

```
| <section-name> | FAIL | Agent error: <error message> |
```

Do not skip the section — partial results are better than silence.

## Step 3: Present Health Report

Parse all agent output. Each script outputs lines in the format:

```
CHECK_NAME | STATUS | DETAIL
```

Map each STATUS to a badge:
- `pass` → `PASS`
- `warn` → `WARN`
- `critical` → `FAIL`
- `info` → `INFO`

Present a single formatted report. Omit any section where all checks pass and there is an `ALL_*_PASS` summary line — only show sections with issues or mixed results. If ALL sections pass, show a brief "all clear" summary.

```
## Midnight Expert — Health Report

### Midnight Tooling (only if user opted in)
(include the delegated report from midnight-tooling:doctor)

### Plugins
| Check | Status | Details |
|-------|--------|---------|
| plugin-name | STATUS | details... |

### MCP Servers
| Check | Status | Details |
|-------|--------|---------|
| server-name | STATUS | details... |

### External Tools
| Check | Status | Details |
|-------|--------|---------|
| tool-name | STATUS | details... |

### Cross-Plugin References
| Check | Status | Details |
|-------|--------|---------|
| source → target:ref | STATUS | details... |

### NPM Registry
| Check | Status | Details |
|-------|--------|---------|
| check-name | STATUS | details... |
```

Do **not** show any intermediate bash output to the user. The report above is the only user-facing output.

## Step 4: Offer Fixes

Read `references/fix-table.md` for the fix recipes.

For each FAIL or WARN item in the report, determine the appropriate fix from the fix-table. Use the `platform` info line from check-ext-tools.sh to select macOS vs Linux commands.

**If `$ARGUMENTS` contains `--auto-fix`:**
- Apply auto-fixable items silently (installs, enables, MCP adds via `claude mcp add`)
- Always prompt before upgrading outdated tools — show current vs latest version
- Always prompt for MCP server scope (global vs local `.mcp.json`)
- Log each action taken

**If no `--auto-fix`:**
- Present each fix one at a time using AskUserQuestion with confirm/skip options
- Group related fixes when possible (e.g., "3 plugins need installing — install all?")

## Step 5: Verify & Summary

After applying any fixes, re-run **only the scripts whose checks had issues** to confirm resolution. Do not re-run passing scripts.

Present a final summary:

```
### Summary
- FAIL: N
- WARN: N
- PASS: N
- INFO: N

[If issues were fixed] Fixed N issue(s) this session.
[If remaining issues] N issue(s) require manual intervention.
[If all green] Midnight Expert ecosystem is healthy and ready for development.
```

## Additional Resources

### Scripts
- `${CLAUDE_SKILL_DIR}/scripts/check-plugins.sh` — Plugin installation and version checks
- `${CLAUDE_SKILL_DIR}/scripts/check-mcp-servers.sh` — MCP server configuration and connectivity
- `${CLAUDE_SKILL_DIR}/scripts/check-ext-tools.sh` — External CLI tool availability and versions
- `${CLAUDE_SKILL_DIR}/scripts/check-cross-refs.sh` — Cross-plugin skill/agent reference validation
- `${CLAUDE_SKILL_DIR}/scripts/check-npm.sh` — NPM registry and @midnight-ntwrk scope checks

### References
- `references/fix-table.md` — Fix recipes for all issue types with platform-specific commands
