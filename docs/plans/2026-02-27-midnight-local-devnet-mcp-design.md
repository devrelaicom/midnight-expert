# Midnight Local Devnet MCP Server — Design Document

**Date:** 2026-02-27
**Status:** Approved
**Author:** Aaron Bassett (with Claude)

## Summary

Build a standalone MCP server + CLI tool for managing a local Midnight development network. Replaces the interactive-only approach from [hbulgarini/midnight-local-network](https://github.com/hbulgarini/midnight-local-network/) with a fresh codebase that exposes both a CLI and MCP tool interface over the same core logic.

The server manages Docker Compose orchestration (node, indexer, proof-server), genesis wallet initialization, NIGHT token funding, DUST registration, and test account generation.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Architecture | Fresh codebase, original as spec | Clean tool API design without legacy coupling |
| Repository | Separate standalone repo | Independent lifecycle; manages Docker infrastructure |
| Docker management | `docker compose` CLI via `child_process` | Simpler than testcontainers, users can also run compose manually |
| Wallet operations | Full wallet SDK integration | Complete local dev environment manager |
| MCP transport | stdio | Standard for Claude Code integration |
| CLI framework | commander | Lightweight, well-known |

## Project Structure

```
midnight-local-devnet/
├── src/
│   ├── index.ts              # MCP server entry point (stdio)
│   ├── cli.ts                # CLI entry point
│   ├── core/
│   │   ├── docker.ts         # Docker Compose lifecycle (up/down/ps/logs)
│   │   ├── wallet.ts         # Wallet SDK operations (init, balances, close)
│   │   ├── funding.ts        # Token transfers, DUST registration
│   │   ├── config.ts         # Network config (ports, endpoints, network ID)
│   │   └── types.ts          # Shared types/interfaces
│   ├── mcp/
│   │   ├── server.ts         # MCP server setup, tool registration
│   │   ├── tools/
│   │   │   ├── network.ts    # start-network, stop-network, restart-network, network-status
│   │   │   ├── wallet.ts     # init-wallet, wallet-balances
│   │   │   ├── funding.ts    # fund-account, fund-accounts-from-file
│   │   │   ├── accounts.ts   # generate-test-account
│   │   │   └── health.ts     # health-check, get-network-config
│   │   └── resources/
│   │       └── config.ts     # MCP resources: devnet://config, devnet://status
│   └── cli/
│       ├── commands/         # CLI command handlers
│       └── interactive.ts    # Interactive menu mode
├── docker/
│   └── standalone.yml        # Docker Compose file
├── package.json
├── tsconfig.json
└── README.md
```

### Layering

- `src/core/` — transport-agnostic business logic. No MCP or CLI imports.
- `src/mcp/` — wires core functions to MCP tool definitions.
- `src/cli/` — wires core functions to CLI commands.

## MCP Tools

### Network Lifecycle

| Tool | Params | Returns | Description |
|---|---|---|---|
| `start-network` | `pull?: boolean` | Service URLs, container IDs | `docker compose up -d`, waits for health checks, inits master wallet, registers DUST. |
| `stop-network` | `removeVolumes?: boolean` | Success/failure | Closes wallets, `docker compose down` (or `down -v`). |
| `restart-network` | `pull?: boolean`, `removeVolumes?: boolean` | Service URLs, container IDs | Stop then start. `removeVolumes` gives clean-slate restart. |
| `network-status` | — | Per-service status, ports, uptime | Parses `docker compose ps`. |
| `network-logs` | `service?: "node" \| "indexer" \| "proof-server"`, `lines?: number` | Log text | Tails compose logs. Defaults to all services, last 50 lines. |

### Wallet Operations

| Tool | Params | Returns | Description |
|---|---|---|---|
| `init-master-wallet` | — | Wallet address, balances | Init genesis wallet from hardcoded seed. Register DUST. Auto-called by `start-network`. |
| `get-wallet-balances` | — | NIGHT (unshielded, shielded), DUST | Current master wallet balances. |

### Funding

| Tool | Params | Returns | Description |
|---|---|---|---|
| `fund-account` | `address: string`, `amount?: bigint` | Tx hash, funded amount | Transfer NIGHT to Bech32 address. Default 50,000 NIGHT. |
| `fund-account-from-mnemonic` | `name: string`, `mnemonic: string` | Address, funded amount, DUST status | Derive wallet, transfer NIGHT, register DUST. |
| `fund-accounts-from-file` | `filePath: string` | Array of funded accounts | Batch fund from accounts.json. |

### Account Generation

| Tool | Params | Returns | Description |
|---|---|---|---|
| `generate-test-account` | `format: "mnemonic" \| "privateKey"`, `count?: number`, `fund?: boolean`, `registerDust?: boolean`, `outputFile?: string` | Array of `{ name, mnemonic?, privateKey?, address }` | Generate random accounts. `outputFile` writes accounts.json-compatible format. Auto-names: "Account 1", "Account 2", etc. |

### Health & Config

| Tool | Params | Returns | Description |
|---|---|---|---|
| `health-check` | — | Per-service health | Hits actual endpoints: node `/health`, proof-server `/version`. |
| `get-network-config` | — | All endpoint URLs, network ID, image versions | Full connection config for DApps. |

### MCP Resources

| Resource URI | Description |
|---|---|
| `devnet://config` | Current network configuration (endpoints, network ID) |
| `devnet://status` | Live network status (services, health, uptime) |

## CLI Interface

Two modes: one-shot commands (for scripting) and interactive mode (like the original).

```bash
# Network
midnight-devnet start [--pull]
midnight-devnet stop [--remove-volumes]
midnight-devnet restart [--pull] [--remove-volumes]
midnight-devnet status
midnight-devnet logs [--service node|indexer|proof-server] [--lines 50]
midnight-devnet health

# Wallet & Funding
midnight-devnet fund <address> [--amount 50000]
midnight-devnet fund-file <path-to-accounts.json>
midnight-devnet balances

# Account Generation
midnight-devnet generate-accounts [--count 3] [--format mnemonic|privateKey] [--output accounts.json] [--fund] [--register-dust]

# Interactive mode
midnight-devnet            # no args = interactive
midnight-devnet interactive
```

Binary name `midnight-devnet` set via `package.json` `bin` field.

## State Management

```typescript
interface NetworkState {
  status: "stopped" | "starting" | "running" | "stopping";
  masterWallet: WalletContext | null;
  config: NetworkConfig;
}
```

- `start-network`: stopped -> starting -> running
- `stop-network`: running -> stopping -> stopped, nullifies masterWallet
- Master wallet auto-initialized when network starts
- Tools requiring running network return clear error if status !== "running"

## Error Handling

| Scenario | Behavior |
|---|---|
| Docker not running | "Docker is not running. Please start Docker Desktop." |
| Port conflict | Error with conflicting port + suggestion to `stop-network --removeVolumes` |
| Wallet sync timeout | Retry 3x with exponential backoff, then error with troubleshooting |
| Funding fails (insufficient balance) | Error showing current balance vs requested amount |
| Tool called while network stopped | "Network is not running. Call start-network first." |
| Docker Compose file not found | Error with path resolution info |

## Dependencies

| Dependency | Purpose |
|---|---|
| `@modelcontextprotocol/sdk` | MCP server framework |
| `@midnight-ntwrk/wallet-sdk-*` | Wallet operations |
| `@midnight-ntwrk/ledger-v7` | Ledger types |
| `@midnight-ntwrk/midnight-js-network-id` | Network ID configuration |
| `@scure/bip39` | BIP39 mnemonic generation |
| `commander` | CLI argument parsing |
| `zod` | Input validation for MCP tool params |
| `pino` / `pino-pretty` | Logging |
| `ws` | WebSocket for wallet SDK |

No testcontainers. Docker Compose managed via `child_process.execFile`.

## Docker Services

From `standalone.yml` (same as original):

| Service | Image | Port | Health Check |
|---|---|---|---|
| midnight-node | `midnightntwrk/midnight-node:0.20.0` | 9944 | `curl http://localhost:9944/health` |
| indexer | `midnightntwrk/indexer-standalone:3.0.0` | 8088 | `/var/run/indexer-standalone/running` |
| proof-server | `midnightntwrk/proof-server:7.0.0` | 6300 | `curl http://localhost:6300/version` |

Network ID: `undeployed`, node preset: `dev`.

## Reference

- Original repo: https://github.com/hbulgarini/midnight-local-network/
- Midnight wallet SDK packages: `@midnight-ntwrk/wallet-sdk-*`
- MCP SDK: `@modelcontextprotocol/sdk`
- Genesis master wallet seed: `0x0000000000000000000000000000000000000000000000000000000000000001`
- NIGHT amount per funding: 50,000 NIGHT (50,000 * 10^6 smallest unit)
