---
description: Manage a local Midnight devnet — start/stop the network, check status and health, view logs, manage wallets, and fund accounts
allowed-tools: AskUserQuestion, mcp__plugin_midnight-tooling_midnight-devnet__start-network, mcp__plugin_midnight-tooling_midnight-devnet__stop-network, mcp__plugin_midnight-tooling_midnight-devnet__restart-network, mcp__plugin_midnight-tooling_midnight-devnet__network-status, mcp__plugin_midnight-tooling_midnight-devnet__health-check, mcp__plugin_midnight-tooling_midnight-devnet__network-logs, mcp__plugin_midnight-tooling_midnight-devnet__get-network-config, mcp__plugin_midnight-tooling_midnight-devnet__get-wallet-balances, mcp__plugin_midnight-tooling_midnight-devnet__fund-account, mcp__plugin_midnight-tooling_midnight-devnet__fund-account-from-mnemonic, mcp__plugin_midnight-tooling_midnight-devnet__fund-accounts-from-file, mcp__plugin_midnight-tooling_midnight-devnet__generate-test-account
argument-hint: <start [--pull] | stop [--remove-volumes] | restart [--pull] [--remove-volumes] | status | health | logs [--service <name>] [--lines <n>] | config | wallet | fund <address> [--amount <n>] | fund-mnemonic <name> <mnemonic> | fund-file <path> | generate-account [--format <type>] [--count <n>] [--fund] [--register-dust] [--output <path>]>
---

Manage a local Midnight devnet. All operations delegate to MCP tools — do not use bash or Docker commands directly.

## Error Handling

If any MCP tool call fails, report the error clearly and suggest:

1. Check that Docker is running and the Docker daemon is accessible.
2. Verify that the `@aaronbassett/midnight-local-devnet` npm package is installed and accessible.
3. See the **troubleshooting** skill for further diagnosis, or run `/doctor` for automated diagnostics.

## Step 1: Parse Subcommand from Arguments

Analyze `$ARGUMENTS` to determine the subcommand and any flags:

| Subcommand | Flags |
|---|---|
| `start` | `--pull` |
| `stop` | `--remove-volumes` |
| `restart` | `--pull`, `--remove-volumes` |
| `status` | (none) |
| `health` | (none) |
| `logs` | `--service <name>`, `--lines <n>` |
| `config` | (none) |
| `wallet` | (none) |
| `fund` | `<address>` (required positional), `--amount <n>` |
| `fund-mnemonic` | `<name>` (required positional), `<mnemonic>` (required positional) |
| `fund-file` | `<path>` (required positional) |
| `generate-account` | `--format <type>`, `--count <n>`, `--fund`, `--register-dust`, `--output <path>` |

If no subcommand is provided or the subcommand is not recognized, jump to **Step 8: Usage Summary**.

## Step 2: Network Lifecycle — start

If the subcommand is `start`:

- Call `mcp__plugin_midnight-tooling_midnight-devnet__start-network`.
- If `--pull` is present, pass `pull: true` to pull the latest Docker images before starting.
- Report the result to the user.

## Step 3: Network Lifecycle — stop

If the subcommand is `stop`:

- If `--remove-volumes` is present, use `AskUserQuestion` to confirm with the user first:
  > "Removing volumes will permanently delete all chain state and wallet data. Are you sure you want to stop the network and remove all volumes? (yes/no)"
  - If the user confirms, call `mcp__plugin_midnight-tooling_midnight-devnet__stop-network` with `removeVolumes: true`.
  - If the user declines, call `mcp__plugin_midnight-tooling_midnight-devnet__stop-network` without `removeVolumes`.
- Otherwise, call `mcp__plugin_midnight-tooling_midnight-devnet__stop-network` without any extra parameters.
- Report the result to the user.

## Step 4: Network Lifecycle — restart

If the subcommand is `restart`:

- If `--remove-volumes` is present, use `AskUserQuestion` to confirm with the user first:
  > "Removing volumes will permanently delete all chain state and wallet data. Are you sure you want to restart the network and remove all volumes? (yes/no)"
  - If the user declines, proceed without `removeVolumes`.
- Call `mcp__plugin_midnight-tooling_midnight-devnet__restart-network`, passing:
  - `pull: true` if `--pull` is present.
  - `removeVolumes: true` if `--remove-volumes` is present and the user confirmed.
- Report the result to the user.

## Step 5: Network Observability — status, health, logs, config

**status**: Call `mcp__plugin_midnight-tooling_midnight-devnet__network-status`. Display the per-service status of all devnet services.

**health**: Call `mcp__plugin_midnight-tooling_midnight-devnet__health-check`. Display the health status of all services.

**logs**: Call `mcp__plugin_midnight-tooling_midnight-devnet__network-logs`, passing:
- `service` if `--service <name>` is provided.
- `lines` if `--lines <n>` is provided.

Display the returned logs.

**config**: Call `mcp__plugin_midnight-tooling_midnight-devnet__get-network-config`. Display the endpoint URLs, network ID, and image versions.

## Step 6: Wallet and Balances

**wallet**: Call `mcp__plugin_midnight-tooling_midnight-devnet__get-wallet-balances`. Display the genesis wallet NIGHT and DUST balances.

## Step 7: Account Funding and Generation

**fund**: Requires a positional `<address>` argument. If not provided, report an error and show usage: `/devnet fund <address> [--amount <n>]`.
- Call `mcp__plugin_midnight-tooling_midnight-devnet__fund-account`, passing:
  - `address` (required).
  - `amount` if `--amount <n>` is provided.
- Report the result to the user.

**fund-mnemonic**: Requires two positional arguments: `<name>` and `<mnemonic>`. If either is missing, report an error and show usage: `/devnet fund-mnemonic <name> <mnemonic>`.
- Call `mcp__plugin_midnight-tooling_midnight-devnet__fund-account-from-mnemonic`, passing:
  - `name` (required).
  - `mnemonic` (required).
- Report the result to the user.

**fund-file**: Requires a positional `<path>` argument. If not provided, report an error and show usage: `/devnet fund-file <path>`.
- Call `mcp__plugin_midnight-tooling_midnight-devnet__fund-accounts-from-file`, passing:
  - `filePath` (required).
- Report the result to the user.

**generate-account**: Call `mcp__plugin_midnight-tooling_midnight-devnet__generate-test-account`, passing:
- `format` — use the value from `--format <type>` if provided, otherwise default to `mnemonic`.
- `count` if `--count <n>` is provided.
- `fund: true` if `--fund` is present.
- `registerDust: true` if `--register-dust` is present.
- `outputFile` if `--output <path>` is provided.

Report the generated account details to the user.

## Step 8: Usage Summary

If no subcommand was provided or the subcommand is not recognized, display a usage summary:

```
/devnet — Manage a local Midnight devnet

Network lifecycle:
  start [--pull]                        Start the devnet (pull latest images with --pull)
  stop [--remove-volumes]               Stop the devnet (remove chain data with --remove-volumes)
  restart [--pull] [--remove-volumes]   Restart the devnet

Observability:
  status                                Show per-service status
  health                                Run health checks on all services
  logs [--service <name>] [--lines <n>] View service logs
  config                                Show endpoint URLs, network ID, and image versions

Wallet & accounts:
  wallet                                Show genesis wallet NIGHT and DUST balances
  fund <address> [--amount <n>]         Fund an address with NIGHT tokens
  fund-mnemonic <name> <mnemonic>       Derive address from mnemonic, then fund
  fund-file <path>                      Fund multiple accounts from a JSON file
  generate-account [--format <type>]    Generate test account(s)
    [--count <n>] [--fund]
    [--register-dust] [--output <path>]
```
