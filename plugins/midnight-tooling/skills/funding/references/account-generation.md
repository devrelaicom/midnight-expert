# Test Account Generation

## Overview

The `generate-test-account` MCP tool generates random test accounts for use in DApp development and testing on the local devnet. Accounts can be generated in different formats, optionally funded, and written to a file for later use.

```
/devnet generate-account [--format <type>] [--count <n>] [--fund] [--register-dust] [--output <path>]
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `format` | No | `mnemonic` | Account format: `mnemonic` (24-word BIP39 phrase) or `privateKey` |
| `count` | No | `1` | Number of accounts to generate |
| `fund` | No | `false` | If `true`, transfer NIGHT tokens from the master wallet to each generated account |
| `registerDust` | No | `false` | If `true`, register the DUST token for each generated account |
| `outputFile` | No | — | File path to write the generated accounts in JSON format |

## Format Options

### Mnemonic Format (default)

Generates a 24-word BIP39 mnemonic phrase for each account. This is the standard format for Midnight wallets and is compatible with wallet software and the `fund-mnemonic` command.

```
/devnet generate-account --format mnemonic
```

### Private Key Format

Generates a raw private key for each account. Useful for programmatic access in test scripts where mnemonic derivation overhead is unnecessary.

```
/devnet generate-account --format privateKey
```

## Auto-Funding

When `--fund` is specified, each generated account is automatically funded with NIGHT tokens from the genesis master wallet. This requires the devnet to be running.

```
/devnet generate-account --fund
```

## DUST Registration

When `--register-dust` is specified, the DUST token is registered for each generated account. This is required before an account can receive or use DUST tokens.

```
/devnet generate-account --register-dust
```

The `--register-dust` flag can be combined with `--fund` to create fully operational accounts in a single command.

## Output to File

When `--output <path>` is specified, the generated accounts are written to the given file path in JSON format. This file can later be used with `/devnet fund-file <path>` to re-fund the same accounts after a devnet restart.

```
/devnet generate-account --count 3 --output accounts.json
```

The output file follows the same format expected by `fund-accounts-from-file`:

```json
[
  { "name": "account-1", "mnemonic": "word1 word2 ... word24" },
  { "name": "account-2", "mnemonic": "word1 word2 ... word24" },
  { "name": "account-3", "mnemonic": "word1 word2 ... word24" }
]
```

## Workflow Example

Generate 3 fully funded test accounts with DUST registration and save them to a file for reuse:

```
/devnet generate-account --count 3 --fund --register-dust --output test-accounts.json
```

This single command:

1. Generates 3 random accounts with BIP39 mnemonics
2. Funds each account with NIGHT tokens from the master wallet
3. Registers DUST for each account
4. Writes all account details to `test-accounts.json`

The generated accounts are immediately ready for DApp testing. After a devnet restart with `--remove-volumes` (which resets chain state), re-fund them with:

```
/devnet fund-file test-accounts.json
```

## Common Patterns

| Goal | Command |
|------|---------|
| Generate a single test account | `/devnet generate-account` |
| Generate a funded account ready for testing | `/devnet generate-account --fund --register-dust` |
| Generate multiple accounts for a test suite | `/devnet generate-account --count 5 --fund --register-dust --output test-accounts.json` |
| Re-fund accounts after devnet reset | `/devnet fund-file test-accounts.json` |
| Generate accounts without funding (fund later) | `/devnet generate-account --count 3 --output accounts.json` |
