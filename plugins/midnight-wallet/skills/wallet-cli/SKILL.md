---
name: midnight-wallet:wallet-cli
description: >-
  This skill should be used when the user asks about the Midnight wallet CLI,
  midnight wallet, wallet balance, NIGHT tokens, DUST tokens, transferring
  NIGHT, funding accounts, test wallets, wallet setup, dust registration,
  airdrop on devnet, genesis address, wallet generation, BIP-39 mnemonics,
  midnight-wallet-cli, midnight-wallet-mcp, MCP wallet tools, wallet addresses,
  checking balances, or troubleshooting wallet operation errors and exit codes
---

# Midnight Wallet CLI

This skill covers the `midnight-wallet-cli` MCP tools for wallet management on the Midnight blockchain.

## Terminology

| Term | Meaning |
|------|---------|
| **NIGHT** | Native token. 6 decimal places. Used for transfers between wallets. |
| **DUST** | Fee token. 15 decimal places. Requires explicit registration before it can be used to pay transaction fees. |
| **Genesis wallet** | Pre-funded wallet on devnet with seed `0x00...01`. The source of funds for `midnight_airdrop`. |
| **Wallet aliases** | `#name` syntax that resolves to wallet addresses via alias files. Allows referring to wallets by nickname instead of full address. |
| **Undeployed** | The network ID for local devnet. Airdrop only works on this network. |

## Common Workflows

### Set up test wallets

> `/midnight-wallet:setup-test-wallets alice bob charlie`

Generates 3 wallets, airdrops NIGHT from the genesis wallet, registers dust for each, and saves aliases so they can be referenced by name.

### Transfer between test wallets

> Transfer 10 NIGHT from #alice to #bob

Agent resolves `#alice` and `#bob` nicknames from the alias file, then calls `midnight_transfer` with the resolved addresses.

### Fund an existing address

> `/midnight-wallet:setup-test-wallets myapp mn_addr_undeployed1...`

Saves the alias `myapp` pointing to the given address, airdrops NIGHT, and registers dust.

### Check all wallet statuses

> How are my test wallets doing?

Agent reads the alias file, then calls `midnight_balance` and `midnight_dust_status` for each wallet.

### Restore wallet from mnemonic

> `/midnight-wallet:fund-mnemonic alice "word1 word2 ... word24"`

Derives the wallet from the BIP-39 mnemonic, then hands off to `/midnight-wallet:setup-test-wallets` with the derived address.

## Wallet Nicknames

The `#name` syntax in user messages resolves to wallet addresses via alias files. Load the `midnight-wallet:wallet-aliases` skill for the script, alias file format, and search order.

To resolve a nickname: run `wallet-aliases.sh get <name> --network <active-network>`. If exit code 1 (not found), suggest running `/midnight-wallet:setup-test-wallets` to create and register the wallet.

## Quick MCP Tool Reference

| Tool | Description |
|------|-------------|
| `midnight_wallet_generate` | Create a named wallet with a new BIP-39 mnemonic |
| `midnight_wallet_list` | List all wallets stored in `~/.midnight/wallets/` |
| `midnight_wallet_use` | Set the active wallet by name |
| `midnight_wallet_info` | Show wallet details (address, name — no seed/mnemonic) |
| `midnight_wallet_remove` | Remove a named wallet |
| `midnight_generate` | Generate a wallet (deprecated — use `midnight_wallet_generate`) |
| `midnight_info` | Show active wallet info without secrets |
| `midnight_balance` | Check NIGHT balance for a wallet address |
| `midnight_address` | Derive an address from a seed for a given network |
| `midnight_genesis_address` | Show the genesis wallet address on the active network |
| `midnight_inspect_cost` | Show block cost limits for the active network |
| `midnight_airdrop` | Fund a wallet from the genesis wallet (undeployed network only) |
| `midnight_transfer` | Send NIGHT tokens from the active wallet to a recipient address |
| `midnight_dust_register` | Register UTXOs for dust generation (required before transfers) |
| `midnight_dust_status` | Check whether dust is registered for a wallet address |
| `midnight_config_get` | Read a wallet CLI config value |
| `midnight_config_set` | Write a wallet CLI config value |
| `midnight_config_unset` | Remove a wallet CLI config value |
| `midnight_cache_clear` | Clear wallet state cache |
| `midnight_localnet_up` | DO NOT USE — use `/midnight-tooling:devnet start` instead |
| `midnight_localnet_stop` | DO NOT USE — use `/midnight-tooling:devnet stop` instead |
| `midnight_localnet_down` | DO NOT USE — use `/midnight-tooling:devnet stop` instead |
| `midnight_localnet_status` | Show local network service status (safe read-only check) |
| `midnight_localnet_clean` | DO NOT USE without explicit user confirmation |

The `midnight_localnet_*` tools (except `midnight_localnet_status`) conflict with the `midnight-tooling` plugin's devnet skill. Do not use them to manage the local network — use `/midnight-tooling:devnet start`, `/midnight-tooling:devnet stop`, etc. instead.

## Reference Files

| Reference | Content |
|-----------|---------|
| **`references/mcp-tools.md`** | Full MCP tool schemas and examples |
| **`references/wallet-management.md`** | Wallet generate, list, use, remove, info |
| **`references/transactions.md`** | Balance, transfer, airdrop, dust |
| **`references/devnet-integration.md`** | How wallet-cli works with the devnet skill |
| **`references/troubleshooting.md`** | Error codes, exit codes, common failures |
