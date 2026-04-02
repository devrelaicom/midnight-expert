---
name: midnight-wallet:setup-test-wallets
description: >-
  This skill should be used when the user asks to setup test wallets, create
  test accounts, generate test wallets, create alice bob charlie wallets,
  fund test accounts, set up development wallets, or needs to create and
  fund wallets for local Midnight development and testing
---

# Setup Test Wallets

Orchestrated skill for creating, funding, and registering test wallets on the Midnight devnet. For each wallet requested, this skill generates the wallet, airdrops NIGHT tokens, registers dust, and saves an alias — all in one flow.

## Input Handling

| Input | Behavior |
| ----- | -------- |
| (nothing) | Random name from wordlist, generate new wallet, fund, register dust, save alias |
| `alice` | Check alias file → if found, use existing address; if not, generate new wallet as "alice" |
| `mn_addr_undeployed1...` | Reverse lookup → if alias found, use that name; if not, assign random name |
| `alice mn_addr_undeployed1...` | Use as-is, save alias "alice" → address |
| `alice bob charlie` | Process each name (batch mode) |

## Flow for Each Wallet

1. **Resolve name/address** — if a name is given but no alias exists, generate a new wallet via `midnight_wallet_generate`. If an address is given, run a reverse lookup to find an existing alias, or assign a random name.
2. **Fund via airdrop** — call `midnight_airdrop` to send NIGHT tokens from the genesis wallet. This step only applies on the `undeployed` (local devnet) network. For `preprod`, direct the user to https://faucet.preprod.midnight.network/; for `preview`, use https://faucet.preview.midnight.network/ — skip the airdrop and note the faucet URLs.
3. **Register dust** — call `midnight_dust_register` to register UTXOs so the wallet can pay transaction fees.
4. **Save alias** — call `${CLAUDE_SKILL_DIR}/scripts/wallet-aliases.sh set <name> --network <active-network> --address <addr>` to persist the name → address mapping.

> **WARNING:** Wallet aliases store public addresses only, not private keys or seeds. The test wallets themselves (in `~/.midnight/wallets/`) contain seeds. This system is for local development and testing only. Never use test wallets for real funds.

## Script Reference

Alias management is handled by `${CLAUDE_SKILL_DIR}/scripts/wallet-aliases.sh`. Brief usage summary:

```
wallet-aliases.sh get <name> [--network <net>] [--file <path>]
wallet-aliases.sh set <name> --network <net> --address <addr> [--file <path>] [--global]
wallet-aliases.sh reverse <address> [--file <path>]
wallet-aliases.sh list [--file <path>]
wallet-aliases.sh remove <name> [--file <path>]
wallet-aliases.sh random-name
```

- `get` — resolve a name to an address (searches project-local then global alias file)
- `set` — write a name → address mapping
- `reverse` — look up the alias name for a given address
- `list` — show all saved aliases
- `remove` — delete an alias entry
- `random-name` — generate a collision-checked random name

## Random Name Format

When no name is supplied, a random name is generated in `adjective-noun` format (e.g. `swift-falcon`, `bright-coral`). Use `wallet-aliases.sh random-name` to generate a name that does not already exist in the alias file.
