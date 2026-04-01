# Expert Doctor — Design Spec

## Overview

The `expert` plugin is a meta-plugin for the midnight-expert marketplace. Its first skill, `expert:doctor`, provides comprehensive diagnostic and health reporting for the entire midnight-expert ecosystem — plugin installation, MCP server connectivity, external CLI tools, cross-plugin references, and NPM registry access.

It delegates Midnight toolchain checks (Compact CLI, compiler, devnet, proof server) to the existing `midnight-tooling:doctor` command, only when the user opts in.

## Plugin Structure

```
plugins/expert/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── doctor/
│       ├── SKILL.md
│       ├── scripts/
│       │   ├── check-plugins.sh
│       │   ├── check-mcp-servers.sh
│       │   ├── check-ext-tools.sh
│       │   ├── check-cross-refs.sh
│       │   └── check-npm.sh
│       └── references/
│           └── fix-table.md
└── README.md
```

Scripts live inside the skill directory and are referenced via `${CLAUDE_SKILL_DIR}/scripts/...`. No dependency on `midnight-plugin-utils` or the `find-claude-plugin-root` hack.

## Scope

### Published Plugins Checked (from marketplace.json)

1. compact-core
2. compact-examples
3. core-concepts
4. midnight-plugin-utils (pending deprecation — remove from this list when deleted)
5. midnight-tooling
6. midnight-verify
7. midnight-cq
8. midnight-wallet
9. midnight-fact-check

### MCP Servers Checked

| Server | Source | Used By |
|--------|--------|---------|
| `midnight` | `npx -y github:devrelaicom/midnight-mcp` | compact-core, midnight-mcp |
| `octocode` | octocode-mcp | midnight-tooling, midnight-verify, midnight-fact-check |
| `midnight-devnet` | `@aaronbassett/midnight-local-devnet` | midnight-tooling |
| `midnight-wallet` | `midnight-wallet-cli@latest` | midnight-wallet |

### External CLI Tools Checked

| Tool | Criticality | Used By |
|------|------------|---------|
| `node` / `npm` / `npx` | Core | Nearly all plugins |
| `git` | Important | midnight-verify |
| `gh` (GitHub CLI) | Important | midnight-tooling |
| `docker` | Important | midnight-tooling, proof-server, midnight-cq |
| `python3` | Important | midnight-tooling (doctor scripts) |
| `curl` | Important | midnight-tooling |
| `tsc` | Core | midnight-verify, midnight-cq |
| `jq` | Optional | compact-core, midnight-tooling (fallback exists) |

### Cross-Plugin References Validated

Internal (midnight-expert plugins referencing each other):
- compact-core → midnight-tooling (compact-cli, troubleshooting, doctor)
- midnight-verify → compact-core (8 skills), midnight-tooling (compact-cli, devnet, install-cli)
- midnight-fact-check → midnight-verify (7 agents)
- midnight-tooling → (self-contained after midnight-plugin-utils removal)
- midnight-cq → compact-core, midnight-tooling, dapp-development

External (references to plugins outside midnight-expert):
- compact-core → devs:code-review, devs:typescript-core, devs:security-core
- midnight-verify → devs:deps-maintenance

External marketplace: `aaronbassett/agent-foundry` (provides the `devs` plugin).

### NPM Registry Checks

- Registry reachability (`npm ping`)
- `@midnight-ntwrk` scope accessibility (canary: `@midnight-ntwrk/compact-runtime`)

## Orchestration Flow

### Step 1: Launch & Ask (concurrent)

In a single action:
- Launch 5 diagnostic agents **in background**:
  - Agent 1 — Plugin Health (`check-plugins.sh`)
  - Agent 2 — MCP Servers (`check-mcp-servers.sh`)
  - Agent 3 — External Tools (`check-ext-tools.sh`)
  - Agent 4 — Cross-Plugin References (`check-cross-refs.sh`)
  - Agent 5 — NPM Registry (`check-npm.sh`)
- Ask the user: "Would you also like to check Midnight Tooling status? (Compact CLI, compiler, devnet, proof server)"

### Step 2: Handle Response

- If **yes**: invoke `midnight-tooling:doctor` and wait for all 6 results.
- If **no**: wait for the 5 background agents to complete.

### Step 3: Present Health Report

Parse all agent output (each outputs `CHECK_NAME | STATUS | DETAIL` lines). Map STATUS to emoji:
- `pass` → PASS
- `warn` → WARN
- `critical` → FAIL
- `info` → INFO

Present a single unified report:

```
## Midnight Expert — Health Report

### Midnight Tooling (if opted in)
(delegated report from midnight-tooling:doctor)

### Plugins
| Check | Status | Details |
(installation, enabled state, versions for all 9 marketplace plugins)

### MCP Servers
| Check | Status | Details |
(configuration and connectivity for all 4 servers)

### External Tools
| Check | Status | Details |
(availability, installed version, latest available version)

### Cross-Plugin References
| Check | Status | Details |
(skill/agent references that resolve or don't, with plugin versions)

### NPM Registry
| Check | Status | Details |
(registry reachability, @midnight-ntwrk scope access)
```

### Step 4: Offer Fixes

For each FAIL or WARN item, present the fix from the fix-table reference.

- Default: prompt one at a time with confirm/skip.
- With `--auto-fix`: apply auto-fixable items silently, prompt for the rest.

### Step 5: Verify & Summary

Re-run only affected checks to confirm fixes. Present final summary with counts.

## Script Output Format

All scripts output structured lines:

```
CHECK_NAME | STATUS | DETAIL
```

Where STATUS is one of: `pass`, `warn`, `critical`, `info`.

### check-plugins.sh

Reads `~/.claude/plugins/installed_plugins.json` and `~/.claude/settings.json` to check the 9 published plugins. For each:
- Is the plugin installed?
- Is it enabled?
- What version? (reads plugin's `.claude-plugin/plugin.json`)

### check-mcp-servers.sh

Runs `claude mcp list` and checks for each of the 4 MCP servers:
- Is it configured?
- Connection test where feasible.

### check-ext-tools.sh

For each tool:
- Is it in `$PATH`? (`command -v`)
- What version is installed? (`--version`)
- What is the latest available version? (live queries: npm registry for node, GitHub API for gh, Docker Hub API for docker, etc.)
- Special: `gh` also checks auth status (`gh auth status`)
- Special: `docker` also checks daemon running (`docker info`)

### check-cross-refs.sh

For each midnight-expert plugin:
- Scans for cross-plugin references (patterns like `plugin:skill`, `plugin:agent`)
- Verifies the referenced plugin is installed
- Verifies the specific skill directory exists (`skills/<name>/SKILL.md`)
- Reads the referenced plugin's `plugin.json` for version

For external plugins (devs:*):
- Checks `aaronbassett/agent-foundry` marketplace is installed
- Checks the `devs` plugin is installed
- Verifies specific skill/agent directories exist

### check-npm.sh

- `npm ping` for registry reachability
- `npm view @midnight-ntwrk/compact-runtime version` for scope accessibility

## Fix Table

### Plugin Issues

| Issue | Fix |
|-------|-----|
| Marketplace not installed | `claude plugin install-marketplace <url>` (midnight-expert: `devrelaicom/midnight-expert`, devs: `aaronbassett/agent-foundry`) |
| Plugin not installed | Ensure marketplace installed, then `claude plugin install <name>` |
| Plugin not enabled | `claude plugin enable <name>` |
| Plugin outdated | `claude plugin update <name>` |

### MCP Server Issues

| Issue | Fix |
|-------|-----|
| Not configured | Provide complete `claude mcp add <name> -- <command> <args>` command. Ask user: "Would you prefer to add this to the local project only? I can write it to `.mcp.json` instead." |
| Configured but not responding | Advise restarting Claude Code |

### External Tool Issues — Install

| Tool | Fix |
|------|-----|
| node | `nvm install --lts` (direct to github.com/nvm-sh/nvm if nvm not installed) |
| npm/npx | Comes with node — reinstall via nvm |
| git | macOS: `brew install git` / Linux: `apt install git` |
| gh | macOS: `brew install gh` / Linux: direct to cli.github.com |
| gh auth | `gh auth login` |
| docker | Direct to docker.com/products/docker-desktop |
| docker daemon | macOS: Start Docker Desktop / Linux: `sudo systemctl start docker` |
| python3 | Install uv first (`curl -LsSf https://astral.sh/uv/install.sh \| sh`), then `uv python install` |
| curl | macOS: `brew install curl` / Linux: `apt install curl` |
| jq | macOS: `brew install jq` / Linux: `apt install jq` (note: optional) |
| tsc | `npm install -g typescript` |

### External Tool Issues — Outdated

| Tool | Update |
|------|--------|
| node | `nvm install --lts && nvm use --lts` |
| git | macOS: `brew upgrade git` / Linux: `apt upgrade git` |
| gh | macOS: `brew upgrade gh` / Linux: `gh upgrade` |
| docker | Update Docker Desktop / Linux: follow docker docs |
| python3 | `uv python install <latest>` |
| tsc | `npm update -g typescript` |

### Cross-Plugin Reference Issues

| Issue | Fix |
|-------|-----|
| Marketplace not installed | Install marketplace first |
| Referenced plugin not installed | Install from correct marketplace |
| Referenced skill/agent missing | Report version mismatch — advise updating the plugin |

### NPM Issues

| Issue | Fix |
|-------|-----|
| Registry unreachable | Check network, proxy settings |
| @midnight-ntwrk scope inaccessible | Check npm config — no custom registry needed for @midnight-ntwrk |

## Auto-Fix Behavior (`--auto-fix`)

### Applied silently
- Installing missing marketplaces and plugins
- Enabling disabled plugins
- Adding MCP servers via `claude mcp add`
- Installing missing CLI tools (nvm install, brew install, uv python install, npm install -g)
- Initiating gh auth login (still interactive)

### Reports but always prompts
- Upgrading outdated CLI tools — report current vs latest version, require confirmation

### Never auto-fixed
- Adding MCP server to local `.mcp.json` vs global (user preference needed)
- Docker Desktop installation (manual download)
- Docker daemon start on macOS (requires Docker Desktop UI)
- Network/proxy configuration issues
- Anything that modifies project files

Each auto-fix action is logged in the output so the user sees what was done.

## Version Check Sources

All version checks are live — no hardcoded minimums:

| Tool | Latest Version Source |
|------|---------------------|
| node | npm registry / nvm ls-remote |
| git | GitHub API (git/git releases) |
| gh | GitHub API (cli/cli releases) |
| docker | Docker Hub API or `docker version --format` |
| python3 | python.org API or uv |
| tsc | npm registry (typescript package) |
| jq | GitHub API (jqlang/jq releases) |
| curl | GitHub API (curl/curl releases) |

## Design Decisions

1. **Delegate to midnight-tooling:doctor** for toolchain checks rather than duplicating — keeps a single source of truth for CLI/compiler/devnet diagnostics.
2. **Opt-in for tooling checks** — the tooling doctor is heavier and the user may only care about plugin health.
3. **Scripts in skill directory** — uses `${CLAUDE_SKILL_DIR}` which works in .md files, unlike `${CLAUDE_PLUGIN_ROOT}`.
4. **No dependency on midnight-plugin-utils** — that plugin is being deprecated.
5. **Scope to marketplace.json** — only check published plugins, not in-development ones.
6. **Skill-level cross-ref validation** — verify specific skills/agents exist, not just that the parent plugin is installed, and report plugin versions.
7. **Live version checks** — query actual latest versions rather than hardcoded minimums.
8. **Conservative auto-fix** — install silently, but always prompt before upgrading.
