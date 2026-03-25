---
description: Comprehensive diagnostic and health report for the Compact CLI installation, compiler versions, PATH configuration, custom directory setup, proof server status, and plugin dependencies
allowed-tools: Bash, Task, AskUserQuestion, mcp__plugin_midnight-tooling_octocode__githubViewRepoStructure, mcp__plugin_midnight-tooling_octocode__githubGetFileContent, mcp__plugin_midnight-tooling_midnight-devnet__network-status, mcp__plugin_midnight-tooling_midnight-devnet__health-check, mcp__plugin_midnight-tooling_midnight-devnet__get-network-config
argument-hint: "[--auto-fix]"
---

Run comprehensive diagnostics on the Compact CLI installation and proof server, then present a detailed health report.

## Terminology Reminder

- **Compact CLI** (`compact`): The management tool. Version: `compact --version`
- **Compact compiler** (`compactc.bin`): The compiler managed by the CLI. Version: `compact compile --version`
- These are separate binaries with independent versions.

## Step 1: Gather Diagnostics (parallel)

Launch **all four** Task agents simultaneously in a single message (so they run in parallel). Each agent has `subagent_type: "general-purpose"`. Each agent must run its bash commands silently and return **only** structured lines in the format:

```
CHECK_NAME | STATUS | DETAIL
```

Where STATUS is one of: `pass`, `warn`, `critical`, `info`

### Agent 1 — Compact CLI

Prompt the agent with:

> First invoke the `midnight-plugin-utils:find-claude-plugin-root` skill to create `/tmp/cpr.py`. Then run the following bash commands and report results. Do NOT output anything except lines in the exact format `CHECK_NAME | STATUS | DETAIL`. Do not include markdown fences or any other text.
>
> Commands to run:
> 1. `PLUGIN_ROOT=$(python3 /tmp/cpr.py midnight-tooling)`
> 2. `SCRIPTS_ROOT="$PLUGIN_ROOT/scripts/doctor"`
> 3. `bash "$SCRIPTS_ROOT/compact-cli.sh"`

### Agent 2 — Environment Configuration

Prompt the agent with:

> First invoke the `midnight-plugin-utils:find-claude-plugin-root` skill to create `/tmp/cpr.py`. Then run the following bash commands and report results. Do NOT output anything except lines in the exact format `CHECK_NAME | STATUS | DETAIL`. Do not include markdown fences or any other text.
>
> Commands to run:
> 1. `PLUGIN_ROOT=$(python3 /tmp/cpr.py midnight-tooling)`
> 2. `SCRIPTS_ROOT="$PLUGIN_ROOT/scripts/doctor"`
> 3. `bash "$SCRIPTS_ROOT/env.sh"`

### Agent 3 — Docker & Devnet

This agent uses a hybrid bash + MCP approach. Bash commands check Docker prerequisites and container status (resilient — no MCP dependency). The `health-check` MCP tool checks live service health with response times. If MCP tools fail, report that health checks could not be performed.

Prompt the agent with:

> Run the following checks and report results. Do NOT output anything except lines in the exact format `CHECK_NAME | STATUS | DETAIL`. Do not include markdown fences or any other text.
>
> **Part A — Docker prerequisites (bash):**
>
> 1. Check Docker is installed: `docker --version 2>&1`
>    - If succeeds → `Docker installed | pass | installed` and `Docker version | info | <version output>`
>    - If fails → `Docker installed | critical | not installed` — skip all remaining checks
>
> 2. Check Docker daemon is running: `docker info >/dev/null 2>&1`
>    - If succeeds → `Docker daemon | pass | running`
>    - If fails → `Docker daemon | critical | not running` — skip container and health checks
>
> **Part B — Container status (bash):**
>
> 3. List devnet containers: `docker ps -a --filter "name=midnight-" --format "{{.Names}}\t{{.Status}}"`
>    - For each of the three expected containers (node, indexer, proof server), check if a matching container name is present and whether its status starts with "Up":
>      - Running → `Node container | pass | running` (same for Indexer, Proof server)
>      - Stopped → `Node container | warn | stopped`
>      - Not found → `Node container | warn | not found`
>
> **Part C — Service health (MCP):**
>
> 4. Call the `mcp__plugin_midnight-tooling_midnight-devnet__health-check` tool to get service health with response times.
>    - For each service (node, indexer, proof server), report:
>      - Healthy → `Node health | pass | healthy`
>      - Unhealthy/not responding → `Node health | warn | not responding`
>    - If the MCP tool call fails entirely, emit warnings for all three:
>      - `Node health | warn | MCP unavailable`
>      - `Indexer health | warn | MCP unavailable`
>      - `Proof server health | warn | MCP unavailable`

### Agent 4 — Plugin Dependencies

This agent checks for tools required by the midnight-tooling plugin commands. These are **not** core Midnight dev environment requirements — they only affect whether certain plugin commands can function.

Prompt the agent with:

> First invoke the `midnight-plugin-utils:find-claude-plugin-root` skill to create `/tmp/cpr.py`. Then run the following bash commands. ONLY output lines for checks that FAIL. If a check passes, output NOTHING for it. Use the exact format `CHECK_NAME | STATUS | DETAIL`. Do not include markdown fences or any other text.
>
> Commands to run:
> 1. `PLUGIN_ROOT=$(python3 /tmp/cpr.py midnight-tooling)`
> 2. `SCRIPTS_ROOT="$PLUGIN_ROOT/scripts/doctor"`
> 3. `bash "$SCRIPTS_ROOT/plugin-deps.sh"`

## Step 2: Present Health Report

Parse the structured lines returned from all four agents. Map each STATUS to an emoji:

- `pass` → 🟢 PASS
- `warn` → 🟠 WARN
- `critical` → 🔴 FAIL
- `info` → 🔵 INFO

Present a single formatted report:

```
## Midnight Development Environment — Health Report 🩺

### ⚙️ Compact CLI
| Check | Status | Details |
|-------|--------|---------|
| CLI binary found | 🟢 PASS / 🔴 FAIL | ... |
| CLI version | 🔵 INFO | ... |
| Compiler version | 🔵 INFO / 🔴 FAIL | ... |
| Installed versions | 🔵 INFO | ... |
| Compiler update | 🟢 PASS / 🟠 WARN | ... |
| CLI update | 🟢 PASS / 🟠 WARN | ... |
| Formatter | 🟢 PASS / 🟠 WARN | ... |

### 💻 Environment
| Check | Status | Details |
|-------|--------|---------|
| COMPACT_DIRECTORY | 🔵 INFO / 🟠 WARN | ... |
| COMPACT_DIRECTORY exists | 🟢 PASS / 🔴 FAIL | ... (only if COMPACT_DIRECTORY was set) |
| PATH configured | 🟢 PASS / 🟠 WARN | ... |

### 🌐 Devnet
| Check | Status | Details |
|-------|--------|---------|
| Docker installed | 🟢 PASS / 🔴 FAIL | ... |
| Docker version | 🔵 INFO | ... |
| Docker daemon | 🟢 PASS / 🔴 FAIL | ... |
| Node container | 🟢 PASS / 🟠 WARN | ... |
| Indexer container | 🟢 PASS / 🟠 WARN | ... |
| Proof server container | 🟢 PASS / 🟠 WARN | ... |
| Node health | 🟢 PASS / 🟠 WARN | ... |
| Indexer health | 🟢 PASS / 🟠 WARN | ... |
| Proof server health | 🟢 PASS / 🟠 WARN | ... |
```

### Plugin Dependencies section

If Agent 4 returned **only** `ALL_PASS`, **omit this section entirely** — do not show it in the report. Only include it when there are issues:

```
### 🔌 Plugin Dependencies

> These are not required for Midnight development but are needed by some
> midnight-tooling plugin commands. Missing dependencies will be noted
> with the affected commands.

| Check | Status | Details |
|-------|--------|---------|
| ... only rows with 🟠 WARN status from Agent 4 ... |
```

Do **not** show any intermediate bash output to the user. The report above is the only user-facing output from steps 1 and 2.

## Step 3: Offer Fixes

For each 🔴 FAIL or 🟠 WARN item, present the fix to the user.

If `$ARGUMENTS` contains `--auto-fix`, apply fixes automatically. Otherwise, use AskUserQuestion to confirm each fix.

### Breaking Change Check for Version Updates

Before applying any fix that updates a version (CLI update, compiler update), check the release notes for breaking changes between the current and target versions:

1. **Determine current and target versions** from the diagnostic output (e.g., CLI 0.2.0 → 0.4.0, or compiler 0.28.0 → 0.29.0)

2. **Map the component to its release notes directory**:
   - CLI update → `compact-tools` (Compact developer tools)
   - Compiler update → `compact` (Compact compiler)

3. **Fetch the version file listing** using `githubViewRepoStructure`:
   ```
   owner: midnightntwrk
   repo: midnight-docs
   path: docs/relnotes/{component}
   depth: 1
   ```

4. **Identify intermediate versions**: Find all version files where the version is greater than the current version and less than or equal to the target version. Extract versions from filenames by stripping the component prefix and `.mdx` extension, then replacing dashes with dots.

5. **Fetch those version files** and search for breaking change sections. Use `githubGetFileContent` with `matchString="Breaking"` and `matchStringContextLines=20` to efficiently extract just the breaking change content. Batch up to 3 files per call.

6. **If breaking changes are found**, present them as a warning before offering the fix:

   ```
   ⚠️ Breaking changes detected between {current} and {target}:

   **{component} {version}:**
   - {breaking change summary}

   **{component} {version}:**
   - {breaking change summary}
   ```

   Then ask the user whether to proceed with the update despite the breaking changes.

7. **If no breaking changes are found**, proceed with the fix normally.

8. **If the release notes cannot be fetched** (e.g., network error, MCP server unavailable), note this and proceed with the fix — do not block the update.

**Fix table:**

| Issue | Fix |
|-------|-----|
| CLI not found | Provide install command: `curl --proto '=https' --tlsv1.2 -LsSf https://github.com/midnightntwrk/compact/releases/latest/download/compact-installer.sh \| sh` |
| PATH not configured | Add `export PATH="$HOME/.compact/bin:$PATH"` to shell profile |
| No compiler installed | Run `compact update` (check breaking changes first) |
| CLI update available | Run `compact self update` (check breaking changes first) |
| Compiler update available | Run `compact update` (check breaking changes first) |
| COMPACT_DIRECTORY not set but .compact/ exists | Run `/midnight-tooling:install-cli install for this project` |
| COMPACT_DIRECTORY set but directory missing | Create the directory or correct the env var |
| Docker not installed | Direct user to [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/) |
| Docker not running | Instruct user to start Docker Desktop |
| Proof server not running | Run `/midnight-tooling:devnet start` to start the devnet (includes node, indexer, and proof server) |
| Node not running | Run `/midnight-tooling:devnet start` to start the devnet |
| Indexer not running | Run `/midnight-tooling:devnet start` to start the devnet |
| Stale devnet containers | Run `/midnight-tooling:devnet stop --remove-volumes` then `/midnight-tooling:devnet start` |
| Formatter not available | Run `compact update` to install latest tooling (check breaking changes first) |
| curl not installed | Direct user to install curl via their system package manager (e.g. `brew install curl` on macOS, `apt install curl` on Debian/Ubuntu) |
| Node.js not installed | Direct user to [https://nodejs.org/](https://nodejs.org/) or recommend `brew install node` / `nvm install --lts` |
| npx not found | Typically installed with Node.js — recommend reinstalling Node.js |
| GitHub CLI not installed | Direct user to [https://cli.github.com/](https://cli.github.com/) or recommend `brew install gh` |
| GitHub CLI not authenticated | Run `gh auth login` and follow the interactive prompts |
| octocode MCP server not connected | Verify the midnight-tooling plugin is installed (`/plugins` to list), check that Node.js and npx are available, and restart Claude Code to reconnect MCP servers |

## Step 4: Verify Fixes & Summary

After applying any fixes, re-run only the affected checks to confirm resolution.

Present a final summary:

```
### Summary
- 🔴 FAIL: N
- 🟠 WARN: N
- 🟢 PASS: N
- 🔵 INFO: N

[If issues were fixed] Fixed N issue(s) this session.
[If remaining issues] N issue(s) require manual intervention.
[If all green] Installation is healthy and ready for development.
```
