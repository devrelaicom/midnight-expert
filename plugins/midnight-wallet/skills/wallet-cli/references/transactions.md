# Transactions Reference

Covers balance checking, token transfers, airdrops, dust registration, and error handling for the `midnight-wallet-cli` MCP tools.

---

## Token Denominations

| Token | Decimal Places | Description |
|-------|---------------|-------------|
| **NIGHT** | 6 | Native token used for transfers. `1 NIGHT = 1,000,000 base units`. |
| **DUST** | 15 | Fee token required to pay transaction fees. Generated from registered UTXOs. `1 DUST = 1,000,000,000,000,000 base units`. |

All tool parameters and return values express amounts in whole token units (not base units). For example, `"amount": "10"` means 10 NIGHT, not 10 base units.

---

## JSON Output Mode

All wallet-cli tools return structured output by default when called via the MCP server. When using the CLI directly, append `--json` to any command to get machine-readable output:

```bash
midnight balance --json
midnight transfer mn_addr_undeployed1... 10 --json
```

The MCP server always uses JSON mode internally.

---

## Balance Checking

**Tool:** `midnight_balance`

Balance is fetched by subscribing to a GraphQL endpoint on the indexer WebSocket. The tool waits for the indexer to return the current UTXO set, then sums unshielded NIGHT balances.

```json
{
  "address": "mn_addr_undeployed1abc...",
  "network": "undeployed"
}
```

If `address` is omitted, the active wallet's address on the active network is used.

**Example response:**
```json
{
  "address": "mn_addr_undeployed1abc...",
  "balance": "42.000000",
  "network": "undeployed"
}
```

Custom indexer endpoint (for non-standard devnet setups):
```json
{
  "address": "mn_addr_undeployed1abc...",
  "indexer-ws": "ws://localhost:8088"
}
```

---

## Transfers

**Tool:** `midnight_transfer`

Sends NIGHT tokens from the active wallet to a recipient address.

### Prerequisites

1. The sending wallet must have a non-zero NIGHT balance.
2. The sending wallet must have dust registered (`midnight_dust_register` must have been called at least once).

### Transfer call

```json
{
  "to": "mn_addr_undeployed1xyz...",
  "amount": "10",
  "network": "undeployed"
}
```

Fractional amounts are supported:
```json
{
  "to": "mn_addr_undeployed1xyz...",
  "amount": "0.5"
}
```

### Endpoint overrides

```json
{
  "to": "mn_addr_undeployed1xyz...",
  "amount": "10",
  "proof-server": "http://localhost:6300",
  "node": "http://localhost:9944",
  "indexer-ws": "ws://localhost:8088"
}
```

### What happens internally

1. Wallet-cli queries the indexer for the current UTXO set.
2. Selects UTXOs sufficient to cover the transfer amount.
3. Constructs and proves the transaction (calls the proof server).
4. Submits the transaction to the node RPC.
5. Waits for the transaction to be included in a block.

This process requires a running proof server and can take 10–60 seconds depending on proof generation time.

---

## Airdrop

**Tool:** `midnight_airdrop`

Transfers NIGHT from the genesis wallet to the active (or specified) wallet. Only works on the `undeployed` (local devnet) network.

```json
{
  "amount": "100",
  "network": "undeployed"
}
```

The genesis wallet has seed `0x0000000000000000000000000000000000000000000000000000000000000001` and is pre-funded with a large NIGHT balance on the undeployed network.

> **Testnet faucets (for preprod/preview):**
> - Preprod: https://faucet.preprod.midnight.network/
> - Preview: https://faucet.preview.midnight.network/
>
> `midnight_airdrop` will fail with `NETWORK_ERROR` or `TX_REJECTED` on testnet because the genesis wallet has no funds there.

---

## Dust Registration and Status

### What is Dust?

Dust is a separate fee token on Midnight. Unlike NIGHT (which is transferred between users), dust is generated from a wallet's own NIGHT UTXOs through a registration process. Once registered, the wallet's UTXOs produce dust automatically as needed to pay fees.

Dust must be registered **before any transfer** can be made. Dust registration is a one-time operation per wallet per network (unless the wallet is cleared or UTXOs are consumed).

### Register Dust

**Tool:** `midnight_dust_register`

```json
{
  "network": "undeployed"
}
```

This submits a registration transaction to the network. It requires a running proof server and may take 10–60 seconds.

### Check Dust Status

**Tool:** `midnight_dust_status`

```json
{
  "network": "undeployed"
}
```

**Example response:**
```json
{
  "registered": true,
  "dustBalance": "0.000000000000001",
  "network": "undeployed"
}
```

If `registered` is `false`, run `midnight_dust_register` before attempting any transfer.

### Force Cache Bypass

Both dust tools accept a `no-cache` boolean to bypass the wallet state cache and re-sync from the indexer:

```json
{
  "no-cache": true
}
```

Use this if the cached state appears stale (e.g., after a devnet restart or after a STALE_UTXO error).

---

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| `INVALID_ARGS` | Invalid arguments | A required parameter is missing or has an invalid value. |
| `WALLET_NOT_FOUND` | Wallet not found | The specified wallet name does not exist in `~/.midnight/wallets/`. |
| `NETWORK_ERROR` | Network error | Cannot reach the node, indexer, or proof server. Check that the devnet is running. |
| `INSUFFICIENT_BALANCE` | Insufficient balance | The wallet does not have enough NIGHT to cover the transfer amount. |
| `TX_REJECTED` | Transaction rejected | The node rejected the transaction. May indicate a protocol error or stale UTXO. |
| `STALE_UTXO` | Stale UTXO | A UTXO was spent between selection and submission (concurrent transactions). |
| `PROOF_TIMEOUT` | Proof timeout | The proof server did not respond within the expected time. |
| `DUST_REQUIRED` | Dust required | Dust is not registered for this wallet. Run `midnight_dust_register` first. |
| `CANCELLED` | Cancelled | The operation was cancelled by the user or timed out. |

---

## Troubleshooting Transactions

| Symptom | Cause | Fix |
|---------|-------|-----|
| `DUST_REQUIRED` | Dust not registered | Call `midnight_dust_register` before `midnight_transfer`. |
| `STALE_UTXO` | Concurrent transaction consumed a UTXO before submission | Wait 5–10 seconds, then retry. Use `"no-cache": true` on the next call. |
| `PROOF_TIMEOUT` | Proof server too slow or not responding | Check proof server with `/midnight-tooling:devnet health`. Restart with `/midnight-tooling:devnet restart` if needed. |
| `INSUFFICIENT_BALANCE` | Not enough NIGHT | Call `midnight_airdrop` to top up (undeployed only), or receive a transfer. |
| `TX_REJECTED` on airdrop | Using airdrop on preprod/preview | Use testnet faucet instead. |
| `NETWORK_ERROR` on transfer | Devnet not running | Run `/midnight-tooling:devnet start` and wait for all services to be healthy. |
| Balance shows 0 after airdrop | Indexer not yet synced | Wait a few seconds and call `midnight_balance` again. |
| Dust status shows registered but transfer fails with `DUST_REQUIRED` | Cache is stale | Call `midnight_cache_clear`, then retry. |
