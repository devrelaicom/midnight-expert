# Wallet and Funding Operations

## Genesis Master Wallet

The genesis master wallet is initialized automatically when the devnet starts via `/devnet start` (which calls the `start-network` MCP tool). It is pre-loaded with a large supply of both NIGHT tokens and DUST tokens, serving as the source for all funding operations on the local devnet.

To check the current master wallet balances:

```
/devnet wallet
```

This calls the `get-wallet-balances` MCP tool and returns:

| Balance Field | Description |
|---------------|-------------|
| **Unshielded NIGHT** | NIGHT tokens in the public (unshielded) balance |
| **Shielded NIGHT** | NIGHT tokens in the private (shielded) balance |
| **DUST** | DUST token balance |
| **Total** | Combined balance summary |

Monitor the master wallet balance when performing many funding operations. If the balance is depleted, restart the devnet with a clean slate: `/devnet restart --remove-volumes`.

## Funding by Address

The `fund-account` MCP tool transfers NIGHT tokens to a specific Bech32 address.

```
/devnet fund <address>
/devnet fund <address> --amount <n>
```

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `address` | Yes | — | Bech32-encoded Midnight address to fund |
| `amount` | No | 50,000 NIGHT | Amount of NIGHT to transfer (specified in smallest units) |

This operation only transfers NIGHT tokens. It does not register or transfer DUST. If the recipient needs DUST, use `fund-mnemonic` instead, which handles DUST registration as part of the funding flow.

## Funding by Mnemonic

The `fund-account-from-mnemonic` MCP tool performs a complete account setup in a single call:

1. Derives the wallet address from a 24-word BIP39 mnemonic
2. Transfers NIGHT tokens to the derived address
3. Registers the DUST token for the account

```
/devnet fund-mnemonic <name> <mnemonic>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `name` | Yes | A label for the account (e.g., "alice", "test-user-1") |
| `mnemonic` | Yes | A 24-word BIP39 mnemonic phrase |

This is the recommended approach for setting up a fully functional test account, as it handles both NIGHT funding and DUST registration in one operation.

## Batch Funding

The `fund-accounts-from-file` MCP tool reads an `accounts.json` file and funds each account listed in it. Each account receives 50,000 NIGHT and has DUST registered.

```
/devnet fund-file <path>
```

| Parameter | Required | Description |
|-----------|----------|-------------|
| `path` | Yes | Path to an `accounts.json` file |

### accounts.json Format

The file must be a JSON array of objects, each with a `name` and `mnemonic` field:

```json
[
  { "name": "alice", "mnemonic": "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20 word21 word22 word23 word24" },
  { "name": "bob", "mnemonic": "word1 word2 word3 word4 word5 word6 word7 word8 word9 word10 word11 word12 word13 word14 word15 word16 word17 word18 word19 word20 word21 word22 word23 word24" }
]
```

Each entry is processed sequentially: the wallet is derived from the mnemonic, funded with 50,000 NIGHT, and DUST is registered.

This file can be generated automatically using the `generate-test-account` tool with the `--output` flag. See `references/account-generation.md` for details.

## Funding Workflow Summary

| Scenario | Command | What Happens |
|----------|---------|-------------|
| Fund a known address with NIGHT only | `/devnet fund <address>` | Transfers 50,000 NIGHT (or custom amount) to the address |
| Fully set up a single account | `/devnet fund-mnemonic <name> <mnemonic>` | Derives address, transfers NIGHT, registers DUST |
| Set up multiple accounts at once | `/devnet fund-file <path>` | Reads accounts.json, funds each with NIGHT, registers DUST |
| Check available funds | `/devnet wallet` | Shows master wallet balances |
