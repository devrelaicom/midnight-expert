# Midnight Devnet Integration Design

**Date:** 2026-03-02
**Scope:** Update midnight-tooling plugin to use the midnight-devnet MCP server

## Context

The midnight-tooling plugin currently manages the proof server via direct Docker commands in bash scripts. The new `@aaronbassett/midnight-local-devnet` MCP server provides a complete local development network (node + indexer + proof-server) with wallet management, account funding, and health monitoring — all exposed as MCP tools.

This design integrates the devnet MCP server into the plugin, replacing manual Docker management with MCP tool delegation.

**Out of scope:** Status line script updates.

## MCP Configuration

Add the midnight-devnet server to `.mcp.json` alongside the existing octocode server:

```json
{
  "octocode": { "command": "npx", "args": ["octocode-mcp@latest"] },
  "midnight-devnet": {
    "command": "npx",
    "args": ["-y", "-p", "@aaronbassett/midnight-local-devnet", "midnight-devnet-mcp"]
  }
}
```

## New Command: `/devnet`

Replaces `/run-proof-server`. A single command at `commands/devnet.md` that handles the full devnet lifecycle, wallet, and account operations via subcommands.

### Subcommands

| Subcommand | MCP Tools Used | Description |
|---|---|---|
| `start [--pull]` | `start-network` | Start the devnet, optionally pull latest images |
| `stop [--remove-volumes]` | `stop-network` | Stop the devnet, optionally clean slate |
| `restart [--pull] [--remove-volumes]` | `restart-network` | Restart with options |
| `status` | `network-status` | Show per-service container status |
| `health` | `health-check` | Hit all service health endpoints |
| `logs [--service <name>] [--lines <n>]` | `network-logs` | Tail service logs |
| `config` | `get-network-config` | Show endpoint URLs, network ID, image versions |
| `wallet` | `get-wallet-balances` | Show genesis master wallet balances |
| `fund <address> [--amount <n>]` | `fund-account` | Fund a Bech32 address |
| `fund-mnemonic <name> <mnemonic>` | `fund-account-from-mnemonic` | Full account setup from mnemonic |
| `fund-file <path>` | `fund-accounts-from-file` | Batch fund from accounts.json |
| `generate-account [--format <type>] [--count <n>] [--fund] [--register-dust] [--output <path>]` | `generate-test-account` | Generate test accounts |

No subcommand or unrecognized subcommand shows usage summary. The command delegates entirely to MCP tools — no direct Docker or bash logic. Allowed tools: `AskUserQuestion` (for confirmations like `--remove-volumes`) plus all `midnight-devnet` MCP tools.

## Skills

### New: `skills/devnet/`

Covers the local devnet lifecycle and all 3 services.

**Triggers:** start/stop devnet, local network, node/indexer/proof-server containers, port 9944/8088/6300, network health, Docker Compose, devnet config.

**References:**
- `references/network-lifecycle.md` — start/stop/restart, what the 3 services are, ports, container names, clean slate vs preserve state
- `references/docker-setup.md` — Docker prereqs for the devnet, resource requirements, daemon troubleshooting (migrated from proof-server skill, updated for 3-service context)

### New: `skills/funding/`

Covers wallet and account operations.

**Triggers:** fund account, NIGHT tokens, DUST tokens, test accounts, genesis wallet, mnemonic, Bech32 address, accounts.json, batch funding.

**References:**
- `references/wallet-and-funding.md` — master wallet concept, funding individual accounts, mnemonic-based funding, batch funding, default amounts
- `references/account-generation.md` — generating test accounts, mnemonic vs private key format, output files, optional auto-funding and DUST registration

### Updated: `skills/proof-server/`

Broadened from "local proof server management" to "working with proof servers in general."

**Changes:**
- What a proof server does (ZK proof generation for Midnight transactions)
- API endpoints (`/health`, `/version`, `/ready`, `/proof-versions`) — work on any proof server
- Resource requirements, health monitoring, troubleshooting
- **Local development section:** points to the devnet — `/devnet start` manages a proof server alongside node + indexer, use this for local dev
- **Standalone usage:** retained Docker run guidance for proof servers outside devnet (e.g., testnet/mainnet)
- **Looking up environment endpoints:** instructions to use the Midnight MCP server's documentation search tools to look up current testnet/mainnet proof server URLs from the `relnotes/overview` page

**Reference updates:**
- `references/docker-setup.md` — generalize, add devnet vs standalone guidance

### Updated: `skills/troubleshooting/`

- Add `references/devnet-issues.md` — network startup failures, wallet initialization issues, indexer sync problems, funding failures
- Update `references/proof-server-issues.md` — add devnet context (proof-server is 1 of 3 services)
- Update `SKILL.md` routing table — add devnet symptom → reference routing

## Doctor Command Updates

Replace the proof-server bash diagnostic agent with an MCP-based agent.

**Remove:** `scripts/doctor/proof-server.sh`

**Updated agent in `commands/doctor.md`:** Uses midnight-devnet MCP tools:
- `network-status` — per-service container status
- `health-check` — service health endpoints
- `get-network-config` — image versions

Formats output in the same `CHECK_NAME | STATUS | DETAIL` structure for consistent report aggregation.

| Check | Pass | Warn | Fail |
|---|---|---|---|
| Docker installed | Has Docker | — | Missing |
| Docker running | Daemon up | — | Daemon down |
| Node container | Running | Stopped | Missing |
| Indexer container | Running | Stopped | Missing |
| Proof server container | Running | Stopped | Missing |
| Node health | Healthy | — | Unhealthy/unreachable |
| Indexer health | Healthy | — | Unhealthy/unreachable |
| Proof server health | Healthy | — | Unhealthy/unreachable |

Other 3 scripts unchanged: `compact-cli.sh`, `env.sh`, `plugin-deps.sh`.

## Removals

| File | Reason |
|---|---|
| `commands/run-proof-server.md` | Replaced by `/devnet` command |
| `scripts/doctor/proof-server.sh` | Replaced by MCP-based diagnostic in `/doctor` |

## Plugin Manifest

- Version bump: `0.1.0` → `0.2.0`
- Update keywords: add `devnet`, `local-network`, `node`, `indexer`, `funding`, `wallet`, `accounts`

## Full File Change Summary

| Action | File |
|---|---|
| Edit | `.mcp.json` |
| Edit | `.claude-plugin/plugin.json` |
| Edit | `commands/doctor.md` |
| Edit | `skills/proof-server/SKILL.md` |
| Edit | `skills/proof-server/references/docker-setup.md` |
| Edit | `skills/troubleshooting/SKILL.md` |
| Edit | `skills/troubleshooting/references/proof-server-issues.md` |
| Delete | `commands/run-proof-server.md` |
| Delete | `scripts/doctor/proof-server.sh` |
| Create | `commands/devnet.md` |
| Create | `skills/devnet/SKILL.md` |
| Create | `skills/devnet/references/network-lifecycle.md` |
| Create | `skills/devnet/references/docker-setup.md` |
| Create | `skills/funding/SKILL.md` |
| Create | `skills/funding/references/wallet-and-funding.md` |
| Create | `skills/funding/references/account-generation.md` |
| Create | `skills/troubleshooting/references/devnet-issues.md` |
