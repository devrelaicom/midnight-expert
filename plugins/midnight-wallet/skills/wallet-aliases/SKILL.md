---
name: midnight-wallet:wallet-aliases
description: >-
  This skill should be used when resolving wallet nicknames, managing wallet
  alias files, looking up addresses by name, reverse-looking up names by
  address, saving wallet aliases, listing saved wallets, or generating
  random wallet names. Covers the #name syntax, alias file locations,
  search order, and the wallet-aliases.sh script interface.
version: 0.1.0
---

# Wallet Aliases

Wallet aliases map human-readable nicknames to Midnight wallet addresses. The `#name` syntax in user messages resolves to addresses via alias files.

## Alias Files

| File | Scope | Priority |
|------|-------|----------|
| `.claude/midnight-wallet/wallets.local.json` | Project-local | Checked first |
| `~/.claude/midnight-wallet/wallets.json` | Global | Fallback |

Both files use the same JSON format:

```json
{
  "_warning": "Test wallet addresses only. Do NOT store secrets here.",
  "wallets": {
    "alice": {
      "undeployed": "mn_addr_undeployed1...",
      "preprod": "mn_addr_preprod1..."
    }
  }
}
```

> **WARNING:** Wallet aliases store public addresses only, not private keys or seeds. The test wallets themselves (in `~/.midnight/wallets/`) contain seeds. This system is for local development and testing only. Never use test wallets for real funds.

## Script Reference

The script is located at `${CLAUDE_SKILL_DIR}/scripts/wallet-aliases.sh`.

```
wallet-aliases.sh get <name> [--network <net>] [--file <path>]
wallet-aliases.sh set <name> --network <net> --address <addr> [--file <path>] [--global]
wallet-aliases.sh reverse <address> [--file <path>]
wallet-aliases.sh list [--file <path>]
wallet-aliases.sh remove <name> [--file <path>]
wallet-aliases.sh path [--global]
wallet-aliases.sh random-name [--file <path>]
```

| Command | Description | Exit codes |
|---------|-------------|------------|
| `get` | Resolve a name to an address (searches project-local then global) | 0=found, 1=not found |
| `set` | Write a name-to-address mapping | 0=success |
| `reverse` | Look up the alias name for a given address | 0=found, 1=not found |
| `list` | Show all saved aliases (merged from both files) | 0=success |
| `remove` | Delete an alias entry | 0=success, 1=not found |
| `path` | Print the alias file path (local by default, `--global` for global) | 0=success |
| `random-name` | Generate a collision-checked random name in `adjective-noun` format | 0=success |

## Resolving Nicknames

When a user message contains `#name`:

1. Load the `midnight-wallet:wallet-aliases` skill to access the script
2. Run `wallet-aliases.sh get <name> --network <active-network>`
3. If exit code 0, use the returned address
4. If exit code 1, the nickname is not found — suggest running `/midnight-wallet:setup-test-wallets` to create and register the wallet

## Random Name Format

When no name is supplied, generate one with `wallet-aliases.sh random-name`. Names use `adjective-noun` format (e.g., `swift-falcon`, `bright-coral`). The script checks existing aliases to avoid collisions.
