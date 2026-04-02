# MCP Tools Reference

All 25 tools exposed by the `midnight-wallet-mcp` MCP server (from `midnight-wallet-cli` npm package v0.2.5).

---

## Wallet Management

### `midnight_wallet_generate`

Create a new named wallet and set it as the active wallet. Generates a fresh BIP-39 mnemonic (256-bit entropy, 24 words) and derives addresses for all three networks from the resulting seed.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | yes | Wallet name. Used as the filename: `~/.midnight/wallets/<name>.json`. |
| `network` | string | no | Default network for the wallet. Enum: `undeployed`, `preprod`, `preview`. Defaults to `undeployed`. |
| `seed` | string | no | 64-character hex seed to restore an existing wallet instead of generating a new one. |
| `mnemonic` | string | no | 24-word BIP-39 mnemonic to restore from. Mutually exclusive with `seed`. |
| `force` | boolean | no | Overwrite an existing wallet file with the same name. |

**Returns:** Wallet name, addresses for all networks, and the BIP-39 mnemonic (only shown at creation time).

---

### `midnight_wallet_list`

List all wallets stored in `~/.midnight/wallets/`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

**Returns:** Array of wallet names with their addresses for each network. Marks the currently active wallet.

---

### `midnight_wallet_use`

Set the active wallet by name. Subsequent tool calls that accept an optional `wallet` parameter will use this wallet when omitted.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | yes | Name of the wallet to activate. Must exist in `~/.midnight/wallets/`. |

**Returns:** Confirmation that the active wallet was updated.

---

### `midnight_wallet_info`

Display details about a named wallet without revealing private keys or seed material.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | no | Wallet name. Defaults to the currently active wallet. |

**Returns:** Wallet name, creation timestamp, and addresses for each network. Never returns seed or mnemonic.

---

### `midnight_wallet_remove`

Permanently delete a wallet file. Irreversible — ensure the mnemonic is backed up before using.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `name` | string | yes | Name of the wallet to remove. |

**Returns:** Confirmation of deletion.

---

## Account Info

### `midnight_info`

Display the active wallet's address and metadata. Safe to call — does not expose seed or mnemonic.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | no | Path to a specific wallet file. Defaults to the active wallet. |

**Returns:** Wallet address on the active network, wallet name, and creation date.

---

### `midnight_balance`

Check the unshielded NIGHT balance for a wallet or address by querying the indexer via GraphQL.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `address` | string | no | Bech32m wallet address to query. If omitted, uses the active wallet's address on the active network. |
| `wallet` | string | no | Wallet name or path override. |
| `network` | string | no | Network to query. Enum: `undeployed`, `preprod`, `preview`. |
| `indexer-ws` | string | no | Custom indexer WebSocket URL (e.g., `ws://localhost:8088`). Overrides config. |

**Returns:** Balance in NIGHT (6 decimal places). Example: `"balance": "42.000000"`.

---

### `midnight_address`

Derive an unshielded address from a raw seed at a given key index without creating a wallet file.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `seed` | string | yes | 64-character hex seed. |
| `network` | string | no | Target network. Enum: `undeployed`, `preprod`, `preview`. Defaults to `undeployed`. |
| `index` | integer | no | Key index in the HD derivation path. Defaults to `0`. |

**Returns:** Derived bech32m address for the specified network and index.

---

### `midnight_genesis_address`

Return the genesis wallet address for a given network. The genesis wallet (seed `0x000...001`) is the funding source for `midnight_airdrop` on the undeployed network.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `network` | string | no | Network. Enum: `undeployed`, `preprod`, `preview`. Defaults to `undeployed`. |

**Returns:** Bech32m genesis wallet address for the specified network.

---

### `midnight_inspect_cost`

Display the current block resource limits and cost parameters from the ledger. Useful for understanding proof-related constraints.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

**Returns:** Block cost limits object (max transaction size, max proof size, fee schedule).

---

## Transactions

### `midnight_airdrop`

Transfer NIGHT tokens from the genesis wallet to the active wallet. Only works on the `undeployed` (local devnet) network.

> **Warning:** This tool will fail on `preprod` or `preview` networks. Use the testnet faucets instead:
> - Preprod: https://faucet.preprod.midnight.network/
> - Preview: https://faucet.preview.midnight.network/

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `amount` | string | yes | Amount of NIGHT to airdrop (supports decimals, e.g., `"100"`, `"1.5"`). |
| `wallet` | string | no | Wallet name override. Defaults to the active wallet. |
| `network` | string | no | Must be `undeployed` (or omitted). |
| `proof-server` | string | no | Custom proof server URL override. |
| `node` | string | no | Custom node URL override. |
| `indexer-ws` | string | no | Custom indexer WebSocket URL override. |

**Returns:** Transaction hash and updated balance.

---

### `midnight_transfer`

Send NIGHT tokens from the active wallet to a recipient address. Requires the sending wallet to have dust registered.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `to` | string | yes | Recipient bech32m address. |
| `amount` | string | yes | Amount of NIGHT to send (supports decimals). |
| `wallet` | string | no | Sender wallet name or path override. Defaults to the active wallet. |
| `network` | string | no | Network override. Enum: `undeployed`, `preprod`, `preview`. |
| `proof-server` | string | no | Custom proof server URL. |
| `node` | string | no | Custom node RPC URL. |
| `indexer-ws` | string | no | Custom indexer WebSocket URL. |

**Returns:** Transaction hash and updated balance. Fails with `DUST_REQUIRED` if dust is not registered.

---

## Dust

### `midnight_dust_register`

Register the active wallet's UTXOs for dust token generation. Dust tokens are required to pay transaction fees on the Midnight network. Must be called before `midnight_transfer`.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | no | Wallet name override. |
| `network` | string | no | Network override. |
| `proof-server` | string | no | Custom proof server URL. |
| `node` | string | no | Custom node URL. |
| `indexer-ws` | string | no | Custom indexer WebSocket URL. |
| `no-cache` | boolean | no | Bypass wallet state cache and re-sync from the indexer. |

**Returns:** Registration transaction hash and dust status.

---

### `midnight_dust_status`

Check whether dust is registered for the active wallet on the current network.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | no | Wallet name override. |
| `network` | string | no | Network override. |
| `proof-server` | string | no | Custom proof server URL. |
| `node` | string | no | Custom node URL. |
| `indexer-ws` | string | no | Custom indexer WebSocket URL. |
| `no-cache` | boolean | no | Bypass cache. |

**Returns:** Boolean registration status and current dust balance (15 decimal places).

---

## Configuration

### `midnight_config_get`

Retrieve a persistent configuration value.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | string | yes | Config key. Valid values: `network`, `proof-server`, `node`, `indexer-ws`, `wallet`. |

**Returns:** Current value for the key, or empty if not set.

---

### `midnight_config_set`

Set a persistent configuration value. Persists across sessions.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | string | yes | Config key. Valid values: `network`, `proof-server`, `node`, `indexer-ws`, `wallet`. |
| `value` | string | yes | Value to store. For URL keys (`proof-server`, `node`, `indexer-ws`), must be a valid URL. For `network`, must be `undeployed`, `preprod`, or `preview`. |

**Returns:** Confirmation of the stored value.

---

### `midnight_config_unset`

Remove a configuration value, restoring default auto-detection behavior.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `key` | string | yes | Config key to remove. |

**Returns:** Confirmation of removal.

---

### `midnight_cache_clear`

Delete the cached wallet synchronization state. Forces the next operation to re-sync from the indexer. Use this when balance or UTXO state appears stale.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `wallet` | string | no | Wallet name to clear cache for. Defaults to active wallet. |
| `network` | string | no | Network to clear cache for. |

**Returns:** Confirmation of cache deletion.

---

## Deprecated

### `midnight_generate`

> **Deprecated.** Use `midnight_wallet_generate` instead. This tool does not assign a name and does not support the wallet management commands (`midnight_wallet_list`, `midnight_wallet_use`, etc.).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `network` | string | no | Network. Enum: `undeployed`, `preprod`, `preview`. |
| `seed` | string | no | 64-character hex seed. |
| `mnemonic` | string | no | 24-word BIP-39 mnemonic. |
| `output` | string | no | Custom output file path. |
| `force` | boolean | no | Overwrite existing file. |

**Returns:** Generated wallet details. Does not set the active wallet.

---

## Local Network (DO NOT USE)

> **Warning:** The tools in this section conflict with the `midnight-tooling` plugin's devnet skill. The wallet-cli manages containers with names `node`, `indexer`, and `proof-server`, while the devnet skill uses `midnight-node`, `midnight-indexer`, and `midnight-proof-server` — different container names but the same ports. Running both results in port conflicts and an unstable environment.
>
> **Do not use `midnight_localnet_up`, `midnight_localnet_stop`, `midnight_localnet_down`, or `midnight_localnet_clean` when the devnet is managed by `/midnight-tooling:devnet`.** Only `midnight_localnet_status` is safe to call as a read-only health check.

### `midnight_localnet_up`

**DO NOT USE.** Start local development network containers. Use `/midnight-tooling:devnet start` from the `midnight-tooling` plugin instead.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

---

### `midnight_localnet_stop`

**DO NOT USE.** Stop running containers while preserving state. Use `/midnight-tooling:devnet stop` from the `midnight-tooling` plugin instead.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

---

### `midnight_localnet_down`

**DO NOT USE.** Remove containers and volumes. Use `/midnight-tooling:devnet stop` from the `midnight-tooling` plugin instead.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

---

### `midnight_localnet_status`

Display local network service status. Safe to use as a read-only check regardless of which tool started the devnet.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

**Returns:** Status of each service (node, indexer, proof-server) — running, stopped, or not found.

---

### `midnight_localnet_logs`

Stream service logs from running containers.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

**Returns:** Log output from containers. Safe to call for debugging, but do not use `midnight_localnet_up/stop/down/clean` when the devnet is managed by `/midnight-tooling:devnet`.

---

### `midnight_localnet_clean`

**DO NOT USE without explicit user confirmation.** Removes conflicting Docker containers by name. This can remove containers started by the `midnight-tooling` devnet skill.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| _(none)_ | — | — | — |

---

## Tool Count

The server exposes 25 tools total:

- Wallet Management: 5 (`midnight_wallet_generate`, `midnight_wallet_list`, `midnight_wallet_use`, `midnight_wallet_info`, `midnight_wallet_remove`)
- Account Info: 5 (`midnight_info`, `midnight_balance`, `midnight_address`, `midnight_genesis_address`, `midnight_inspect_cost`)
- Transactions: 2 (`midnight_airdrop`, `midnight_transfer`)
- Dust: 2 (`midnight_dust_register`, `midnight_dust_status`)
- Configuration: 4 (`midnight_config_get`, `midnight_config_set`, `midnight_config_unset`, `midnight_cache_clear`)
- Deprecated: 1 (`midnight_generate`)
- Local Network: 6 (`midnight_localnet_up`, `midnight_localnet_stop`, `midnight_localnet_down`, `midnight_localnet_status`, `midnight_localnet_logs`, `midnight_localnet_clean`)
