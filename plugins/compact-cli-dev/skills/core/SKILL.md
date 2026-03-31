---
name: core
description: >-
  This skill should be used when the user asks about CLI scaffold, Oclif CLI,
  CLI template, wallet commands, contract deployment CLI, devnet CLI,
  CLI development, add CLI commands, Midnight CLI patterns, CLI error handling,
  CLI progress feedback, building a command-line interface for Compact contracts,
  scaffolding a new CLI project, or extending the generated CLI with new commands
version: 0.1.0
---

# Compact CLI Development

This skill provides patterns for building Oclif CLIs that interact with Midnight Compact smart contracts on a local devnet. The template scaffolds a complete CLI with wallet management, contract deployment, circuit invocation, state queries, and devnet lifecycle control.

## Quick Command Reference

| Command | Description |
|---------|-------------|
| `wallet:create [name]` | Generate a new wallet with a random seed |
| `wallet:list` | List all stored wallets |
| `wallet:info <name>` | Show wallet address and creation date |
| `wallet:fund <name>` | Airdrop NIGHT from the genesis wallet |
| `dust:register <wallet>` | Register NIGHT UTXOs for DUST generation |
| `dust:status <wallet>` | Check DUST balance and registration status |
| `balance <wallet>` | Show NIGHT and DUST balances |
| `deploy` | Deploy the compiled contract to devnet |
| `join <address>` | Join an existing deployed contract |
| `call <circuit>` | Call a contract circuit (transaction) |
| `query <field>` | Query contract public state (read-only) |
| `devnet:start` | Start local devnet via Docker Compose |
| `devnet:stop` | Stop local devnet containers |
| `devnet:status` | Show devnet service health |

## Project Structure

```
src/
  base-command.ts          Shared base command (--json, error handling, welcome banner)
  lib/
    wallet.ts              HD wallet derivation, WalletFacade, persistence
    providers.ts           6-provider bundle factory
    funding.ts             Genesis airdrop, DUST registration, balance polling
    contract.ts            CompiledContract loading, deploy, join, persistence
    config.ts              Network config (DEVNET_CONFIG), initializeNetwork()
    errors.ts              Error classification and formatting
    progress.ts            Ora spinner helpers, JSON-mode silence
    constants.ts           File paths, seeds, timeouts, fee parameters
  commands/
    wallet/
      create.ts            wallet:create
      list.ts              wallet:list
      info.ts              wallet:info
      fund.ts              wallet:fund
    dust/
      register.ts          dust:register
      status.ts            dust:status
    devnet/
      start.ts             devnet:start
      stop.ts              devnet:stop
      status.ts            devnet:status
    balance.ts             balance
    deploy.ts              deploy
    join.ts                join
    call.ts                call
    query.ts               query
```

## Adding New Commands

Extend `BaseCommand` to inherit `--json` support, error classification, and the welcome banner:

```typescript
import { Args, Flags } from "@oclif/core";
import { BaseCommand } from "../base-command.js";

export default class MyCommand extends BaseCommand {
  static override description = "What this command does";

  static override args = {
    name: Args.string({ description: "Argument description", required: true }),
  };

  static override flags = {
    ...BaseCommand.baseFlags,
    verbose: Flags.boolean({ description: "Show extra output", default: false }),
  };

  async run(): Promise<void> {
    const { args, flags } = await this.parse(MyCommand);

    // Command logic here
    const result = { name: args.name };

    if (!this.jsonEnabled) {
      this.log(`Result: ${args.name}`);
    }

    this.outputResult(result);
  }
}
```

Place the file under `src/commands/` — the directory structure determines the topic. For example, `src/commands/mygroup/action.ts` creates the command `mygroup:action`.

## State Files

| File | Permissions | Contents |
|------|------------|----------|
| `.midnight-expert/wallets.json` | `0o600` | Wallet seeds, addresses, creation dates. Contains secrets — never commit. |
| `.midnight-expert/deployed-contracts.json` | `0o644` | Contract addresses and deployment timestamps. Safe to share. |

Both files are stored relative to the project working directory.

## Reference Docs

| Reference | When to Consult |
|-----------|-----------------|
| `references/oclif-patterns.md` | Understanding command structure, BaseCommand, `--json`, topic grouping |
| `references/wallet-management.md` | HD derivation, WalletFacade, seed format, persistence, key functions |
| `references/provider-setup.md` | The 6-provider bundle, `createProviders()`, network config |
| `references/contract-lifecycle.md` | CompiledContract, deploy, join, calling circuits, querying state |
| `references/error-handling.md` | Error classification, ErrorCode enum, formatError, adding new codes |
