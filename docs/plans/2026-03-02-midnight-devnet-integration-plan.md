# Midnight Devnet Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update the midnight-tooling plugin to use the midnight-devnet MCP server for local development network management, replacing manual Docker proof-server management.

**Architecture:** Add the midnight-devnet MCP server to the plugin's `.mcp.json`. Replace `/run-proof-server` with a single `/devnet` command that delegates all operations to MCP tools. Add devnet and funding skills, broaden the proof-server skill, and update the doctor command to use MCP-based diagnostics.

**Tech Stack:** Claude Code plugin (markdown commands/skills), MCP tools (`@aaronbassett/midnight-local-devnet`), Midnight MCP server (documentation search)

---

### Task 1: Add midnight-devnet MCP server to plugin configuration

**Files:**
- Modify: `plugins/midnight-tooling/.mcp.json`

**Step 1: Update .mcp.json**

Replace the entire file content with:

```json
{
  "octocode": {
    "command": "npx",
    "args": [
      "octocode-mcp@latest"
    ]
  },
  "midnight-devnet": {
    "command": "npx",
    "args": [
      "-y",
      "-p",
      "@aaronbassett/midnight-local-devnet",
      "midnight-devnet-mcp"
    ]
  }
}
```

**Step 2: Commit**

```bash
git add plugins/midnight-tooling/.mcp.json
git commit -m "feat(midnight-tooling): add midnight-devnet MCP server to plugin config"
```

---

### Task 2: Create the `/devnet` command

**Files:**
- Create: `plugins/midnight-tooling/commands/devnet.md`

**Step 1: Write the command file**

Create `plugins/midnight-tooling/commands/devnet.md` with the following content. The command:

- Has frontmatter with `description`, `allowed-tools` (listing `AskUserQuestion` and all 12 `mcp__plugin_midnight-tooling_midnight-devnet__*` tools), and `argument-hint`
- Parses `$ARGUMENTS` to determine the subcommand
- Delegates entirely to MCP tools — no bash or Docker commands

The subcommands are:

| Subcommand | MCP Tool | Key Behavior |
|---|---|---|
| `start [--pull]` | `start-network` | Pass `pull: true` if `--pull` present |
| `stop [--remove-volumes]` | `stop-network` | If `--remove-volumes`, confirm with user via AskUserQuestion first, then pass `removeVolumes: true` |
| `restart [--pull] [--remove-volumes]` | `restart-network` | If `--remove-volumes`, confirm with user first |
| `status` | `network-status` | Display per-service status |
| `health` | `health-check` | Display health of all services |
| `logs [--service <name>] [--lines <n>]` | `network-logs` | Pass `service` and `lines` params if provided |
| `config` | `get-network-config` | Display endpoint URLs, network ID, image versions |
| `wallet` | `get-wallet-balances` | Display genesis wallet NIGHT and DUST balances |
| `fund <address> [--amount <n>]` | `fund-account` | Pass `address` (required) and `amount` if provided |
| `fund-mnemonic <name> <mnemonic>` | `fund-account-from-mnemonic` | Pass `name` and `mnemonic` (both required) |
| `fund-file <path>` | `fund-accounts-from-file` | Pass `filePath` (required) |
| `generate-account [--format <type>] [--count <n>] [--fund] [--register-dust] [--output <path>]` | `generate-test-account` | Pass `format` (required, default `mnemonic`), and optional `count`, `fund`, `registerDust`, `outputFile` |

No subcommand or unrecognized → display usage summary listing all subcommands.

Structure the command markdown similarly to the existing `run-proof-server.md` — step-based with a parsing step first, then a section per subcommand group.

**Step 2: Commit**

```bash
git add plugins/midnight-tooling/commands/devnet.md
git commit -m "feat(midnight-tooling): add /devnet command with full network lifecycle and account management"
```

---

### Task 3: Delete the `/run-proof-server` command

**Files:**
- Delete: `plugins/midnight-tooling/commands/run-proof-server.md`

**Step 1: Remove the file**

```bash
rm plugins/midnight-tooling/commands/run-proof-server.md
```

**Step 2: Commit**

```bash
git add plugins/midnight-tooling/commands/run-proof-server.md
git commit -m "feat(midnight-tooling): remove /run-proof-server command, replaced by /devnet"
```

---

### Task 4: Create the devnet skill

**Files:**
- Create: `plugins/midnight-tooling/skills/devnet/SKILL.md`
- Create: `plugins/midnight-tooling/skills/devnet/references/network-lifecycle.md`
- Create: `plugins/midnight-tooling/skills/devnet/references/docker-setup.md`

**Step 1: Create the SKILL.md**

Create `plugins/midnight-tooling/skills/devnet/SKILL.md` with:

- Frontmatter following the same pattern as existing skills (e.g., `compact-cli/SKILL.md`):
  - `name: devnet`
  - `description:` trigger keywords including: "start the devnet", "stop the devnet", "restart the network", "local development network", "midnight node", "midnight indexer", "network status", "network health", "devnet config", "network endpoints", "port 9944", "port 8088", "port 6300", "Docker Compose", "devnet not starting", "local blockchain"

- Body content covering:
  - **Terminology table**: devnet (the 3-service network), node (blockchain node on port 9944), indexer (GraphQL on port 8088), proof server (ZK proofs on port 6300)
  - **Prerequisites**: Docker Desktop installed and running, adequate resources (4 GB+ RAM)
  - **Quick command reference**: `/devnet start`, `/devnet stop`, `/devnet status`, `/devnet health`, `/devnet logs`, `/devnet config`
  - **Services table**: node (9944), indexer (8088), proof server (6300) with container names
  - **Common issues table**: Docker not running, port conflicts, services failing to start
  - **Reference files table**: pointing to the two reference files

**Step 2: Create references/network-lifecycle.md**

Content covering:
- Starting the network: what `start-network` does (pulls images, starts 3 containers via Docker Compose, initializes genesis master wallet, registers DUST token)
- Stopping: `stop-network` closes wallets and stops containers; `removeVolumes` for clean slate
- Restarting: `restart-network` with options
- Status vs health: `network-status` checks Docker container state (fast), `health-check` hits HTTP endpoints (thorough)
- Getting config: `get-network-config` returns endpoint URLs, network ID (`undeployed` for local dev), and Docker image versions
- Network endpoints table:
  - Node RPC: `http://127.0.0.1:9944`
  - Indexer GraphQL: `http://127.0.0.1:8088/api/v3/graphql`
  - Indexer WebSocket: `ws://127.0.0.1:8088/api/v3/graphql/ws`
  - Proof Server: `http://127.0.0.1:6300`
  - Network ID: `undeployed`
- Clean slate vs preserve state: when to use `--remove-volumes` (e.g., resetting chain state, starting fresh)

**Step 3: Create references/docker-setup.md**

Migrate content from `plugins/midnight-tooling/skills/proof-server/references/docker-setup.md` but update for the 3-service devnet context:
- Docker Desktop installation (macOS, Linux, Windows) — keep existing platform-specific guidance
- Resource requirements: update to reflect 3 services running (node + indexer + proof-server), recommend 4 GB+ RAM
- Verifying Docker is ready — same sequence
- Troubleshooting Docker daemon — same content
- Port conflicts — update to mention all 3 ports (9944, 8088, 6300)
- Remove proof-server-specific Docker run commands (the devnet MCP server handles this)

**Step 4: Commit**

```bash
git add plugins/midnight-tooling/skills/devnet/
git commit -m "feat(midnight-tooling): add devnet skill with network lifecycle and docker setup references"
```

---

### Task 5: Create the funding skill

**Files:**
- Create: `plugins/midnight-tooling/skills/funding/SKILL.md`
- Create: `plugins/midnight-tooling/skills/funding/references/wallet-and-funding.md`
- Create: `plugins/midnight-tooling/skills/funding/references/account-generation.md`

**Step 1: Create the SKILL.md**

Create `plugins/midnight-tooling/skills/funding/SKILL.md` with:

- Frontmatter:
  - `name: funding`
  - `description:` trigger keywords including: "fund account", "fund address", "NIGHT tokens", "DUST tokens", "test accounts", "genesis wallet", "master wallet", "wallet balance", "mnemonic", "Bech32 address", "accounts.json", "batch funding", "generate test account", "generate accounts", "fund from mnemonic"

- Body content:
  - **Prerequisites**: Local devnet must be running (`/devnet start`) — funding operations require the genesis master wallet which is initialized on network start
  - **Quick command reference**: `/devnet wallet`, `/devnet fund <address>`, `/devnet fund-mnemonic <name> <mnemonic>`, `/devnet fund-file <path>`, `/devnet generate-account`
  - **Terminology table**: genesis master wallet (pre-funded wallet initialized on devnet start), NIGHT (native token), DUST (secondary token requiring registration), Bech32 address (Midnight address format)
  - **Common issues table**: devnet not running, insufficient master wallet balance, invalid address format
  - **Reference files table**

**Step 2: Create references/wallet-and-funding.md**

Content covering:
- Genesis master wallet: initialized automatically on `start-network`, pre-loaded with NIGHT tokens and DUST tokens
- Checking balances: `get-wallet-balances` returns unshielded NIGHT, shielded NIGHT, DUST, and total
- Funding by address: `fund-account` transfers NIGHT to a Bech32 address (default: 50,000 NIGHT). Amount is specified in smallest units
- Funding by mnemonic: `fund-account-from-mnemonic` derives wallet from 24-word BIP39 mnemonic, transfers NIGHT, and registers DUST — full account setup in one call
- Batch funding: `fund-accounts-from-file` reads an `accounts.json` file, funds each account with 50,000 NIGHT and registers DUST
- accounts.json format example:
  ```json
  [
    { "name": "alice", "mnemonic": "word1 word2 ... word24" },
    { "name": "bob", "mnemonic": "word1 word2 ... word24" }
  ]
  ```

**Step 3: Create references/account-generation.md**

Content covering:
- `generate-test-account` tool: generates random test accounts
- Format options: `mnemonic` (24-word BIP39) or `privateKey`
- Count: generate multiple accounts at once (default: 1)
- Optional auto-funding: `fund: true` transfers NIGHT from master wallet
- Optional DUST registration: `registerDust: true`
- Output to file: `outputFile` writes accounts.json for later use or batch funding
- Workflow example: generate 3 funded accounts with DUST → use in DApp testing

**Step 4: Commit**

```bash
git add plugins/midnight-tooling/skills/funding/
git commit -m "feat(midnight-tooling): add funding skill with wallet, funding, and account generation references"
```

---

### Task 6: Update the proof-server skill to be general-purpose

**Files:**
- Modify: `plugins/midnight-tooling/skills/proof-server/SKILL.md`
- Modify: `plugins/midnight-tooling/skills/proof-server/references/docker-setup.md`

**Step 1: Update SKILL.md**

Rewrite the skill to be about proof servers in general, not just local Docker management. Keep the same frontmatter `name: proof-server` but update the `description` to clarify it covers proof servers in any context.

Key changes to the body:

1. **Opening paragraph**: Change from "runs as a Docker container exposing port 6300 and is required for local development" to describe the proof server's role generally (generates ZK proofs for Midnight transactions, can be local or remote)

2. **Add "Local Development" section** near the top:
   > For local development, use the devnet which manages a proof server alongside a node and indexer. Run `/devnet start` to start the full local network. See the `devnet` skill for details.
   >
   > The rest of this skill covers working with proof servers directly — useful when connecting to testnet/mainnet or running a standalone instance.

3. **Add "Looking Up Environment Endpoints" section**:
   > Current proof server addresses for testnet and mainnet are published in the Midnight documentation. To look up the latest endpoints:
   >
   > Use the Midnight MCP server's documentation search tools to search for the `relnotes/overview` page in the `midnightntwrk/midnight-docs` repository:
   >
   > ```
   > githubGetFileContent(
   >   owner: "midnightntwrk",
   >   repo: "midnight-docs",
   >   path: "docs/relnotes/overview.mdx",
   >   fullContent: true
   > )
   > ```
   >
   > This page contains the current network environment details including proof server URLs, node endpoints, and indexer endpoints for all active environments.

4. **Keep all existing content**: Image version selection, Docker run commands, API endpoints, common issues — these remain relevant for standalone usage

5. **Update the reference files table**: Add a note that `references/docker-setup.md` covers standalone Docker setup, and point to the devnet skill for local development setup

**Step 2: Update references/docker-setup.md**

Add a note at the top:

> **For local development:** Use `/devnet start` instead of running the proof server standalone. The devnet manages a proof server alongside node and indexer services. See the `devnet` skill for Docker setup in the devnet context.
>
> This guide covers running a standalone proof server Docker container, which is useful when connecting to remote environments (testnet/mainnet) or for isolated testing.

Rest of the file stays the same.

**Step 3: Commit**

```bash
git add plugins/midnight-tooling/skills/proof-server/
git commit -m "feat(midnight-tooling): broaden proof-server skill to general usage, add devnet pointers and endpoint lookup"
```

---

### Task 7: Update the troubleshooting skill

**Files:**
- Modify: `plugins/midnight-tooling/skills/troubleshooting/SKILL.md`
- Modify: `plugins/midnight-tooling/skills/troubleshooting/references/proof-server-issues.md`
- Create: `plugins/midnight-tooling/skills/troubleshooting/references/devnet-issues.md`

**Step 1: Update SKILL.md**

Add devnet-related keywords to the `description` frontmatter: "devnet not starting", "node not running", "indexer not syncing", "network start failed", "wallet initialization failed", "funding failed", "devnet health check failing".

Add a row to the diagnostic routing table:

```
| Devnet, local network, node, indexer, network start, wallet init, funding | `references/devnet-issues.md` |
```

Update the proof server routing row to mention that proof-server-in-devnet issues should also check `references/devnet-issues.md`.

Add cross-skill dependency note:
- **`references/devnet-issues.md`** depends on the **devnet** skill and its references for network lifecycle details.

**Step 2: Update references/proof-server-issues.md**

Add a section at the top after the title:

> ## Proof Server in Devnet Context
>
> If the proof server is running as part of the local devnet (started via `/devnet start`), it is one of three services managed together. Issues may be caused by the node or indexer rather than the proof server itself.
>
> - Check all services: use `/devnet status` and `/devnet health`
> - Check logs for the specific service: `/devnet logs --service proof-server`
> - For network-level issues (all services failing), see `references/devnet-issues.md`
>
> The troubleshooting steps below apply to both standalone and devnet proof servers.

**Step 3: Create references/devnet-issues.md**

Create `plugins/midnight-tooling/skills/troubleshooting/references/devnet-issues.md` covering:

- **Network fails to start**: Docker not running, port conflicts (9944, 8088, 6300), insufficient resources
- **Partial startup**: One or more services fail while others start — check per-service logs via `/devnet logs --service <name>`
- **Wallet initialization fails**: Network must be fully healthy before wallet init; check node and indexer health first
- **Funding failures**: Devnet not running, master wallet not initialized, insufficient balance, invalid Bech32 address
- **Indexer sync issues**: Indexer depends on node — if node is unhealthy, indexer cannot sync
- **Clean slate recovery**: When state is corrupted, use `/devnet stop --remove-volumes` then `/devnet start` for a fresh start
- **If issues persist**: search GitHub issues in midnightntwrk org, check release notes

**Step 4: Commit**

```bash
git add plugins/midnight-tooling/skills/troubleshooting/
git commit -m "feat(midnight-tooling): add devnet troubleshooting and update proof-server issues for devnet context"
```

---

### Task 8: Update the doctor command to use MCP-based diagnostics

**Files:**
- Modify: `plugins/midnight-tooling/commands/doctor.md`
- Delete: `plugins/midnight-tooling/scripts/doctor/proof-server.sh`

**Step 1: Update commands/doctor.md**

In the `allowed-tools` frontmatter, add the midnight-devnet MCP tools needed for diagnostics:
```
allowed-tools: Bash, Task, AskUserQuestion, mcp__plugin_midnight-tooling_octocode__githubViewRepoStructure, mcp__plugin_midnight-tooling_octocode__githubGetFileContent, mcp__plugin_midnight-tooling_midnight-devnet__network-status, mcp__plugin_midnight-tooling_midnight-devnet__health-check, mcp__plugin_midnight-tooling_midnight-devnet__get-network-config
```

Replace **Agent 3 — Docker & Proof Server** with **Agent 3 — Docker & Devnet**. Instead of running `proof-server.sh` via bash, the agent now:

1. Checks Docker installation and daemon via bash (keep these — they're prerequisites):
   ```bash
   docker --version 2>&1
   docker info >/dev/null 2>&1
   ```

2. Calls `network-status` MCP tool to get per-service container status (node, indexer, proof-server)

3. Calls `health-check` MCP tool to get service health with response times

4. Formats results in the same `CHECK_NAME | STATUS | DETAIL` format:
   - `Docker installed | pass/critical | ...`
   - `Docker version | info | ...`
   - `Docker daemon | pass/critical | ...`
   - `Node container | pass/warn | running/stopped/not found`
   - `Indexer container | pass/warn | running/stopped/not found`
   - `Proof server container | pass/warn | running/stopped/not found`
   - `Node health | pass/warn | healthy/not responding`
   - `Indexer health | pass/warn | healthy/not responding`
   - `Proof server health | pass/warn | healthy/not responding`

Update the report template in Step 2 to rename the section from "Proof Server" to "Devnet" and show all 3 services:

```
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

Update the fix table in Step 3:
- Change "Proof server not running" fix from `/midnight-tooling:run-proof-server` to `/midnight-tooling:devnet start`
- Add fixes for node and indexer not running: `/midnight-tooling:devnet start`
- Add fix for stale containers: `/midnight-tooling:devnet stop --remove-volumes` then `/midnight-tooling:devnet start`

**Step 2: Delete proof-server.sh**

```bash
rm plugins/midnight-tooling/scripts/doctor/proof-server.sh
```

**Step 3: Commit**

```bash
git add plugins/midnight-tooling/commands/doctor.md plugins/midnight-tooling/scripts/doctor/proof-server.sh
git commit -m "feat(midnight-tooling): update /doctor to use devnet MCP tools for diagnostics"
```

---

### Task 9: Update plugin manifest

**Files:**
- Modify: `plugins/midnight-tooling/.claude-plugin/plugin.json`

**Step 1: Update plugin.json**

- Change `"version"` from `"0.1.0"` to `"0.2.0"`
- Update `"description"` to mention the local devnet: `"Installs, configures, and manages the Midnight Network development toolchain — Compact CLI, compiler version switching, local devnet (node, indexer, proof server), account funding, diagnostics, and release notes for all Midnight components."`
- Update `"keywords"` array: keep existing keywords, add `"devnet"`, `"local-network"`, `"node"`, `"indexer"`, `"funding"`, `"wallet"`, `"accounts"`

**Step 2: Commit**

```bash
git add plugins/midnight-tooling/.claude-plugin/plugin.json
git commit -m "feat(midnight-tooling): bump to v0.2.0, update description and keywords for devnet"
```
