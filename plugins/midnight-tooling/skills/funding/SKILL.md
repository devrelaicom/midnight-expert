---
name: funding
description: This skill should be used when the user asks about funding accounts on the Midnight devnet, including "fund account", "fund address", "NIGHT tokens", "DUST tokens", "test accounts", "genesis wallet", "master wallet", "wallet balance", "mnemonic", "Bech32 address", "accounts.json", "batch funding", "generate test account", "generate accounts", "fund from mnemonic", "fund-account", "fund-account-from-mnemonic", "fund-accounts-from-file", "generate-test-account", or managing wallet balances and token distribution on a local devnet.
---

# Midnight Devnet Funding and Account Management

Fund accounts with NIGHT and DUST tokens on a local Midnight devnet. Generate test accounts for DApp development and testing.

## Prerequisites

The local devnet must be running before any funding operations can be performed. Start it with `/devnet start`.

Funding operations require the **genesis master wallet**, which is initialized automatically when the devnet starts. If the devnet is not running, all funding and wallet operations will fail.

## Quick Command Reference

| Command | Purpose |
|---------|---------|
| `/devnet wallet` | Show genesis master wallet NIGHT and DUST balances |
| `/devnet fund <address>` | Fund a Bech32 address with NIGHT tokens |
| `/devnet fund <address> --amount <n>` | Fund with a specific amount of NIGHT |
| `/devnet fund-mnemonic <name> <mnemonic>` | Derive wallet from mnemonic, fund NIGHT, and register DUST |
| `/devnet fund-file <path>` | Batch fund multiple accounts from an accounts.json file |
| `/devnet generate-account` | Generate a random test account |
| `/devnet generate-account --count <n> --fund --register-dust` | Generate multiple funded accounts with DUST |

## Terminology

| Term | What It Is |
|------|-----------|
| **Genesis master wallet** | Pre-funded wallet initialized automatically on devnet start; source of all funding operations |
| **NIGHT** | Native token on the Midnight network; used for transaction fees and transfers |
| **DUST** | Secondary token on the Midnight network; requires explicit registration before it can be received or used |
| **Bech32 address** | The address format used by Midnight (e.g., `midnight1...`); required when funding by address |
| **BIP39 mnemonic** | A 24-word recovery phrase used to derive a Midnight wallet |
| **accounts.json** | A JSON file listing accounts (name + mnemonic) for batch funding operations |

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Funding fails with "network not running" | Devnet is not started | Run `/devnet start` first |
| Insufficient master wallet balance | Master wallet funds depleted from repeated funding | Restart devnet with `/devnet restart --remove-volumes` for a clean slate |
| Invalid address format | Address is not a valid Bech32 Midnight address | Verify the address starts with the correct Midnight prefix and is properly encoded |
| DUST operations fail | DUST token not registered for the target account | Use `fund-mnemonic` or `generate-account --register-dust` which handle DUST registration automatically |
| Mnemonic rejected | Mnemonic is not a valid 24-word BIP39 phrase | Verify the mnemonic is exactly 24 words from the BIP39 word list |

## Reference Files

Consult these for detailed procedures:

| Reference | Content | When to Read |
|-----------|---------|-------------|
| **`references/wallet-and-funding.md`** | Genesis master wallet, checking balances, funding by address, funding by mnemonic, batch funding, accounts.json format | Funding accounts or checking wallet state |
| **`references/account-generation.md`** | Generating test accounts, mnemonic vs private key format, auto-funding, DUST registration, output files | Creating test accounts for DApp development |
