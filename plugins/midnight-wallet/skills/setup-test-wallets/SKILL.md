---
name: midnight-wallet:setup-test-wallets
description: >-
  This skill should be used when the user asks to set up test wallets, create
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

## Required MCP Tools

| Tool | Purpose |
|------|---------|
| `midnight_config_get` | Read config values — use `midnight_config_get key:network-id` to determine the active network |
| `midnight_wallet_generate` | Create a new wallet, returns name and address |
| `midnight_airdrop` | Send NIGHT tokens from genesis wallet (undeployed network only) |
| `midnight_dust_register` | Register UTXOs so the wallet can pay transaction fees |

## Network Detection

Before funding, determine the active network by calling `midnight_config_get` with `key: "network-id"`. The returned value determines the funding method.

## Flow for Each Wallet

1. **Resolve name/address** — if a name is given but no alias exists, generate a new wallet via `midnight_wallet_generate`. If an address is given, run a reverse lookup to find an existing alias, or assign a random name.
2. **Fund** — funding method depends on the active network:

   | Network | Method |
   |---------|--------|
   | `undeployed` | Call `midnight_airdrop` to send NIGHT from the genesis wallet |
   | `preprod` | Direct the user to https://faucet.preprod.midnight.network/ — do not call airdrop |
   | `preview` | Direct the user to https://faucet.preview.midnight.network/ — do not call airdrop |

3. **Register dust** — call `midnight_dust_register` to register UTXOs so the wallet can pay transaction fees.
4. **Save alias** — load the `midnight-wallet:wallet-aliases` skill and run `wallet-aliases.sh set <name> --network <active-network> --address <addr>` to persist the name → address mapping.

## Error Handling

| Step | Failure | Action |
|------|---------|--------|
| Wallet generation | `midnight_wallet_generate` returns error | Report the error and stop processing this wallet. Continue with remaining wallets in batch mode. |
| Airdrop | `midnight_airdrop` fails | Report the error. The wallet is created but unfunded — suggest the user retry or fund manually. |
| Dust registration | `midnight_dust_register` fails | Report the error. The wallet has NIGHT but cannot pay fees yet — suggest retrying after a brief wait. |
| Alias save | `wallet-aliases.sh set` fails | Report the error. The wallet is functional but not saved as an alias — suggest saving manually. |

## Alias Management

All alias operations (get, set, reverse, list, remove, random-name) are provided by the `midnight-wallet:wallet-aliases` skill. Load that skill for the script location, usage reference, and alias file format.

When no name is supplied, generate a random name with `wallet-aliases.sh random-name` (see the wallet-aliases skill for details).
