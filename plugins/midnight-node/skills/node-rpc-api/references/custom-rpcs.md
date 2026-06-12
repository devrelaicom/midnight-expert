# Custom RPC Methods Reference

The Midnight node exposes **16 custom (non-Substrate) RPC methods** across four namespaces. All are served over WebSocket on port 9944 alongside the standard Substrate methods. This document covers parameters, return types, and access constraints for each method. Executable call examples live in `examples/custom-rpc-calls.md`. Substrate methods are documented in `references/substrate-rpcs.md`.

Source: `docs/openrpc.json` at tag `node-1.0.0`; confirmed against Rust RPC implementations.

---

## `midnight_` Namespace

Five methods that expose the Midnight ZK ledger state.

| Method | Params | Returns | Required unsafe? |
|--------|--------|---------|-----------------|
| `midnight_contractState` | `contract_address` (req), `at` (opt) | `String` (hex) | No |
| `midnight_zswapStateRoot` | `at` (opt) | `Vec<u8>` (byte array) | No |
| `midnight_ledgerStateRoot` | `at` (opt) | `Vec<u8>` (byte array) | No |
| `midnight_apiVersions` | none | `Array<integer>` (currently `[2]`) | No |
| `midnight_ledgerVersion` | `at` (opt) | `String` | No |

The `at` parameter in this namespace is always type `BlockHash` — a `0x`-prefixed, 64-hex-char string (`^0x[0-9a-fA-F]{64}$`). When omitted, the best block is used.

### `midnight_contractState`

Returns the current state of a deployed Compact contract, identified by its hex-encoded address. Both the input address and returned state are hex-encoded strings.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `contract_address` | `string` | Yes | Hex-encoded contract address |
| `at` | `BlockHash` | No | Block hash to query (defaults to best block) |

**Returns:** `string` — hex-encoded contract state. (`openrpc.json` `midnight_contractState` result schema; `pallets/midnight/rpc/src/lib.rs:49` trait signature `-> Result<String, ...>`)

**Errors:** `StateRpcError`

```json
{"jsonrpc":"2.0","id":1,"method":"midnight_contractState","params":["0x<contract_address>"]}
```

### `midnight_zswapStateRoot`

Returns the Merkle root of the zswap (shielded transaction) state tree as a raw byte array.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `at` | `BlockHash` | No | Block hash to query (defaults to best block) |

**Returns:** `Array<integer[0–255]>` — Merkle root bytes. (`openrpc.json` `midnight_zswapStateRoot` result schema: `{type:"array",items:{type:"integer",minimum:0,maximum:255}}`)

**Errors:** `StateRpcError`

```json
{"jsonrpc":"2.0","id":1,"method":"midnight_zswapStateRoot","params":[]}
```

### `midnight_ledgerStateRoot`

Returns the Merkle root of the overall ledger state as a raw byte array.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `at` | `BlockHash` | No | Block hash to query (defaults to best block) |

**Returns:** `Array<integer[0–255]>` — Merkle root bytes. (`openrpc.json` `midnight_ledgerStateRoot` result schema: identical array schema to `zswapStateRoot`)

**Errors:** `StateRpcError`

```json
{"jsonrpc":"2.0","id":1,"method":"midnight_ledgerStateRoot","params":[]}
```

### `midnight_apiVersions`

Returns the RPC API version(s) supported by this node. At node 1.0.0 this always returns `[2]`. This is the RPC protocol version, distinct from the Substrate runtime API version.

**Parameters:** none

**Returns:** `Array<integer>` — supported version numbers. (`pallets/midnight/rpc/src/lib.rs:31`: `pub const API_VERSIONS: [u32; 1] = [2]`; `openrpc.json` description: "currently contains a single element ([2])")

```json
{"jsonrpc":"2.0","id":1,"method":"midnight_apiVersions","params":[]}
// → [2]
```

### `midnight_ledgerVersion`

Returns the ledger implementation version as a string decoded from the runtime's byte representation.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `at` | `BlockHash` | No | Block hash to query (defaults to best block) |

**Returns:** `string` — ledger version string. (`pallets/midnight/rpc/src/lib.rs:74`: `fn get_ledger_version(...) -> Result<String, BlockRpcError>`; line 362: `String::from_utf8_lossy(&ledger_version).to_string()`)

**Errors:** `BlockRpcError`

```json
{"jsonrpc":"2.0","id":1,"method":"midnight_ledgerVersion","params":[]}
// → "8" (or similar version string)
```

---

## `systemParameters_` Namespace

Three methods that expose on-chain governance parameters managed by `pallet_system_parameters`. For D-parameter and Ariadne semantics see `midnight-node:node-governance`.

| Method | Params | Returns | Required unsafe? |
|--------|--------|---------|-----------------|
| `systemParameters_getTermsAndConditions` | `at` (opt) | `TermsAndConditionsRpcResponse \| null` | No |
| `systemParameters_getDParameter` | `at` (opt) | `DParameterRpcResponse` | No |
| `systemParameters_getAriadneParameters` | `epoch_number` (req), `d_parameter_at` (opt) | `AriadneParametersRpcResponse` | No |

### `systemParameters_getTermsAndConditions`

Returns the hash and URL of the current terms and conditions, or `null` if not set.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `at` | `BlockHash` | No | Block hash to query (defaults to best block) |

**Returns:** `TermsAndConditionsRpcResponse | null`

```json
{
  "hash": "0x<sha256-hex-32-bytes>",
  "url": "https://..."
}
```

(`openrpc.json` `TermsAndConditionsRpcResponse` schema: required fields `hash` (string) and `url` (string))

**Errors:** `SystemParametersRpcError`

### `systemParameters_getDParameter`

Returns the current D-parameter — the counts of permissioned and registered validator candidates.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `at` | `BlockHash` | No | Block hash to query (defaults to best block) |

**Returns:** `DParameterRpcResponse`

```json
{
  "numPermissionedCandidates": 5,
  "numRegisteredCandidates": 12
}
```

(`openrpc.json` `DParameterRpcResponse` schema: required `numPermissionedCandidates` and `numRegisteredCandidates`, both `integer` / `uint16`)

**Errors:** `SystemParametersRpcError`

### `systemParameters_getAriadneParameters`

Returns Ariadne parameters — permissioned candidates and candidate registrations from Cardano, combined with the D-parameter sourced from `pallet-system-parameters` on-chain storage. Preferred over the deprecated `sidechain_getAriadneParameters`.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `epoch_number` | `integer (≥ 0)` | Yes | Mainchain epoch number to query candidates for |
| `d_parameter_at` | `BlockHash` | No | Block hash to source the D-parameter from (defaults to best block) |

(`pallets/system-parameters/rpc/src/lib.rs:158–162`: `#[method(name = "systemParameters_getAriadneParameters")]` / `epoch_number: McEpochNumber` / `d_parameter_at: Option<BlockHash>`)

**Returns:** `AriadneParametersRpcResponse`

```json
{
  "dParameter": {
    "numPermissionedCandidates": 5,
    "numRegisteredCandidates": 12
  },
  "permissionedCandidates": [...],
  "candidateRegistrations": {...}
}
```

The `permissionedCandidates` field is `Array | null` — `null` indicates no list was set on the mainchain. The `candidateRegistrations` field is a free-form JSON map (uses `serde_json::Value`; corresponds to `GetRegistrationsResponseMap` from partner-chains).

**Errors:** `SystemParametersRpcError`

---

## `network_` Namespace

Three methods for inspecting and managing peer reputation. All three require `--rpc-methods=unsafe` — they call `check_if_safe()` before executing (`node/src/peer_info_rpc.rs:106,155,202`). Only `network_unbanPeer` is tagged `x-unsafe` in the OpenRPC document; however the `check_if_safe` guard applies to all three.

| Method | Params | Returns | Required unsafe? |
|--------|--------|---------|-----------------|
| `network_peerReputations` | none | `Array<PeerReputationInfo>` | Yes |
| `network_peerReputation` | `peer_id` (req) | `PeerReputationInfo` | Yes |
| `network_unbanPeer` | `peer_id` (req) | `null` | Yes (`x-unsafe`) |

### `PeerReputationInfo` shape

```json
{
  "peerId": "12D3KooW...",
  "roles": "FULL",
  "bestHash": "0x...",
  "bestNumber": 12345,
  "reputation": -1024,
  "isBanned": false
}
```

A peer is considered banned when `reputation < BANNED_THRESHOLD` (defined as `71 * (i32::MIN / 100)` in `node/src/peer_info_rpc.rs:32`).

### `network_peerReputations`

Returns reputation info for all currently connected peers.

**Parameters:** none

**Returns:** `Array<PeerReputationInfo>` — one entry per connected peer. (`openrpc.json` `network_peerReputations` result schema)

```json
{"jsonrpc":"2.0","id":1,"method":"network_peerReputations","params":[]}
```

### `network_peerReputation`

Returns reputation info for a single peer identified by its base58-encoded peer ID.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `peer_id` | `string` | Yes | Base58-encoded libp2p peer ID |

**Returns:** `PeerReputationInfo` — returns an error if the peer is not found. (`openrpc.json` `network_peerReputation`)

```json
{"jsonrpc":"2.0","id":1,"method":"network_peerReputation","params":["12D3KooW..."]}
```

### `network_unbanPeer`

Unbans a peer by issuing a maximum-value reputation boost, lifting it above the ban threshold. Requires `--rpc-methods=unsafe`.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `peer_id` | `string` | Yes | Base58-encoded libp2p peer ID to unban |

**Returns:** `null` on success. (`openrpc.json` `network_unbanPeer` result schema `{type:"null"}`; `x-unsafe: true`)

```json
{"jsonrpc":"2.0","id":1,"method":"network_unbanPeer","params":["12D3KooW..."]}
```

---

## `sidechain_` Namespace

Five methods for the Cardano partner chain integration. `sidechain_getAriadneParameters` is deprecated.

| Method | Params | Returns | Deprecated? |
|--------|--------|---------|-------------|
| `sidechain_getParams` | none | `{genesis_utxo: UtxoId}` | No |
| `sidechain_getStatus` | none | `GetStatusResponse` | No |
| `sidechain_getEpochCommittee` | `epoch_number` (req) | `GetCommitteeResponse` | No |
| `sidechain_getRegistrations` | `mc_epoch_number` (req), `mc_public_key` (req) | `Array<CandidateRegistrationEntry>` | No |
| `sidechain_getAriadneParameters` | `epoch_number` (req) | `AriadneParametersRpcResponse` | **Yes** |

### `sidechain_getParams`

Returns the genesis UTXO that uniquely identifies this partner chain instance.

**Parameters:** none

**Returns:**

```json
{
  "genesis_utxo": "<hex_tx_hash_64chars>#<output_index>"
}
```

`UtxoId` pattern: `^[0-9a-fA-F]{64}#[0-9]+$`. (`openrpc.json` `sidechain_getParams` result schema)

### `sidechain_getStatus`

Returns current epoch and slot information for both the partner chain and Cardano mainchain.

**Parameters:** none

**Returns:** `GetStatusResponse`

```json
{
  "sidechain": {
    "epoch": 42,
    "nextEpochTimestamp": 1700000000000
  },
  "mainchain": {
    "epoch": 480,
    "slot": 23456789,
    "nextEpochTimestamp": 1700086400000
  }
}
```

Timestamps are milliseconds since the Unix epoch. (`openrpc.json` `GetStatusResponse` schema)

**Errors:** `GetStatusRpcError`

### `sidechain_getEpochCommittee`

Returns the ordered list of validators selected for a given sidechain epoch.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `epoch_number` | `integer (≥ 0)` | Yes | Sidechain epoch number |

**Returns:** `GetCommitteeResponse`

```json
{
  "sidechainEpoch": 42,
  "committee": [
    {"sidechainPubKey": "0x..."},
    {"sidechainPubKey": "0x..."}
  ]
}
```

(`openrpc.json` `GetCommitteeResponse` schema; `partner-chains/toolkit/committee-selection/rpc/src/lib.rs:19`: `fn get_epoch_committee(&self, epoch_number: u64)`)

### `sidechain_getRegistrations`

Returns Stake Pool Operator (SPO) registration records for committee candidacy, filtered by mainchain epoch and stake-pool public key. Returns the last active valid registration followed by all newer invalid registrations for the given epoch and key.

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `mc_epoch_number` | `integer (≥ 0)` | Yes | Mainchain (Cardano) epoch number |
| `mc_public_key` | `string` | Yes | Stake pool public key (hex-encoded) |

(`partner-chains/toolkit/committee-selection/rpc/src/lib.rs:22–29`: `#[method(name = "getRegistrations")]` / `mc_epoch_number: McEpochNumber` / `#[argument(rename = "mc_public_key")] stake_pool_public_key: StakePoolPublicKey`)

**Returns:** `Array<CandidateRegistrationEntry>` — fields include `sidechainPubKey`, `sidechainAccountId` (SS58), `mainchainPubKey`, `crossChainPubKey`, `utxo` (UtxoId), `isValid` (boolean), and optional `invalidReasons`. (`openrpc.json` `CandidateRegistrationEntry` schema)

```json
{"jsonrpc":"2.0","id":1,"method":"sidechain_getRegistrations","params":[480,"0x<stake_pool_hex_pubkey>"]}
```

### `sidechain_getAriadneParameters` ⚠ Deprecated

**Deprecated** — use `systemParameters_getAriadneParameters` instead. This method sources the D-parameter from Cardano rather than from `pallet-system-parameters` on-chain storage, which is less reliable. (`openrpc.json` `sidechain_getAriadneParameters` `"deprecated": true`; `node/src/openrpc.rs:402`)

**Parameters**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `epoch_number` | `integer (≥ 0)` | Yes | Mainchain epoch number |

**Returns:** `AriadneParametersRpcResponse` — identical schema to `systemParameters_getAriadneParameters`. (`partner-chains/toolkit/committee-selection/rpc/src/lib.rs:33–36`)

---

## Error Components

| Error | Used by |
|-------|---------|
| `StateRpcError` | `midnight_contractState`, `midnight_zswapStateRoot`, `midnight_ledgerStateRoot` |
| `BlockRpcError` | `midnight_ledgerVersion` |
| `SystemParametersRpcError` | `systemParameters_*` |
| `GetStatusRpcError` | `sidechain_getStatus` |

Error schemas are defined in `docs/openrpc.json` `components.errors`. For the full taxonomy of node error codes see `midnight-status-codes:status-codes`.

---

## Quick Reference: All 16 Methods

| # | Method | Req params | Opt params | Return type |
|---|--------|-----------|------------|-------------|
| 1 | `midnight_contractState` | `contract_address` | `at` | `string` (hex) |
| 2 | `midnight_zswapStateRoot` | — | `at` | `Vec<u8>` |
| 3 | `midnight_ledgerStateRoot` | — | `at` | `Vec<u8>` |
| 4 | `midnight_apiVersions` | — | — | `Array<integer>` → `[2]` |
| 5 | `midnight_ledgerVersion` | — | `at` | `string` |
| 6 | `systemParameters_getTermsAndConditions` | — | `at` | `TermsAndConditionsRpcResponse \| null` |
| 7 | `systemParameters_getDParameter` | — | `at` | `DParameterRpcResponse` |
| 8 | `systemParameters_getAriadneParameters` | `epoch_number` | `d_parameter_at` | `AriadneParametersRpcResponse` |
| 9 | `network_peerReputations` | — | — | `Array<PeerReputationInfo>` |
| 10 | `network_peerReputation` | `peer_id` | — | `PeerReputationInfo` |
| 11 | `network_unbanPeer` | `peer_id` | — | `null` |
| 12 | `sidechain_getParams` | — | — | `{genesis_utxo}` |
| 13 | `sidechain_getStatus` | — | — | `GetStatusResponse` |
| 14 | `sidechain_getEpochCommittee` | `epoch_number` | — | `GetCommitteeResponse` |
| 15 | `sidechain_getRegistrations` | `mc_epoch_number`, `mc_public_key` | — | `Array<CandidateRegistrationEntry>` |
| 16 | `sidechain_getAriadneParameters` ⚠ | `epoch_number` | — | `AriadneParametersRpcResponse` |

---

## Cross-references

- `references/substrate-rpcs.md` — the 52 standard Substrate methods also served on port 9944
- `examples/custom-rpc-calls.md` — executable wscat/curl call examples for every method in this reference
- `midnight-node:node-governance` — D-parameter and Ariadne parameter semantics in depth
- `midnight-status-codes:status-codes` — full Midnight ecosystem error code reference
