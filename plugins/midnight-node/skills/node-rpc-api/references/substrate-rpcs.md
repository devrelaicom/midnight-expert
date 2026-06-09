# Standard Substrate RPCs

The Midnight node (v1.0.0) exposes 52 standard upstream Polkadot-SDK RPC methods across seven modules: `system`, `author`, `chain`, `state`, `grandpa`, `mmr`, and `beefy`. These are unmodified Substrate methods; authoritative parameter schemas live in `docs/openrpc.json` at tag `node-1.0.0`. For Midnight-specific methods (`midnight_*`, `systemParameters_*`, `sidechain_*`, `network_*`) see [references/custom-rpcs.md](custom-rpcs.md).

Methods marked **unsafe** require the `--rpc-methods=Unsafe` node flag. Subscription methods return a subscription ID and push notifications over the active WebSocket; cancel with the corresponding `*_unsubscribe*` method.

---

## system (16 methods)

| Method | Purpose | Key params |
|--------|---------|------------|
| `system_name` | Node implementation name (e.g. `midnight`) | — |
| `system_version` | Node implementation version string | — |
| `system_chain` | Chain name from the chain spec | — |
| `system_chainType` | Chain type: `Development`, `Local`, `Live`, or `Custom` | — |
| `system_properties` | Chain properties — token symbol, decimals, SS58 prefix | — |
| `system_health` | Node health: peer count, syncing flag, should-have-peers flag | — |
| `system_localPeerId` | Local node's libp2p peer ID | — |
| `system_localListenAddresses` | Local node's listening multiaddresses | — |
| `system_peers` | Connected peer list — peer ID, roles, best block | — |
| `system_nodeRoles` | Roles this node is running (`Full`, `Authority`, `LightClient`) | — |
| `system_syncState` | Sync progress: `startingBlock`, `currentBlock`, `highestBlock` | — |
| `system_reservedPeers` | List configured reserved peers | — |
| `system_addReservedPeer` | Add a reserved peer by multiaddress **[unsafe]** | `peer: String` (multiaddr) |
| `system_removeReservedPeer` | Remove a reserved peer by peer ID **[unsafe]** | `peerId: String` |
| `system_accountNextIndex` | Account nonce (next valid transaction index) | `account: AccountId` |
| `system_dryRun` | Dry-run a signed extrinsic and return dispatch result **[unsafe]** | `extrinsic: Bytes`, `at?: BlockHash` |

---

## author (8 methods)

| Method | Purpose | Key params |
|--------|---------|------------|
| `author_submitExtrinsic` | Submit a hex-encoded signed extrinsic to the transaction pool | `extrinsic: Bytes` |
| `author_submitAndWatchExtrinsic` | Submit extrinsic and subscribe to its status changes (subscription) | `extrinsic: Bytes` |
| `author_pendingExtrinsics` | Return all pending extrinsics in the pool | — |
| `author_removeExtrinsic` | Remove extrinsics from the pool by hash or bytes | `bytesOrHash: Vec<ExtrinsicOrHash>` |
| `author_hasKey` | Check whether a key exists in the node keystore | `publicKey: Bytes`, `keyType: String` |
| `author_hasSessionKeys` | Check whether the provided session keys are in the keystore | `sessionKeys: Bytes` |
| `author_insertKey` | Insert a key into the node keystore **[unsafe]** | `keyType: String`, `suri: String`, `publicKey: Bytes` |
| `author_rotateKeys` | Generate new session keys and store them in the keystore **[unsafe]** | — |

---

## chain (7 methods)

| Method | Purpose | Key params |
|--------|---------|------------|
| `chain_getHeader` | Block header by hash; latest if omitted | `hash?: BlockHash` |
| `chain_getBlock` | Full block (header + extrinsics) by hash; latest if omitted | `hash?: BlockHash` |
| `chain_getBlockHash` | Block hash by block number; latest if omitted | `blockNumber?: BlockNumber` |
| `chain_getFinalizedHead` | Hash of the latest GRANDPA-finalized block | — |
| `chain_subscribeNewHeads` | Subscribe — pushes header each time the best chain tip advances (subscription) | — |
| `chain_subscribeFinalizedHeads` | Subscribe — pushes header each time a block is finalized (subscription) | — |
| `chain_subscribeAllHeads` | Subscribe — pushes every header regardless of finality (subscription) | — |

---

## state (14 methods)

| Method | Purpose | Key params |
|--------|---------|------------|
| `state_getStorage` | Read a raw storage value by hex key | `key: StorageKey`, `at?: BlockHash` |
| `state_getStorageHash` | Hash of a raw storage value | `key: StorageKey`, `at?: BlockHash` |
| `state_getStorageSize` | Size in bytes of a raw storage value | `key: StorageKey`, `at?: BlockHash` |
| `state_getKeys` | List all storage keys with a given prefix (deprecated — use `state_getKeysPaged`) | `prefix: StorageKey`, `at?: BlockHash` |
| `state_getKeysPaged` | Paginated storage key listing with optional start key | `prefix: StorageKey`, `count: u32`, `startKey?: StorageKey`, `at?: BlockHash` |
| `state_getMetadata` | SCALE-encoded runtime metadata blob | `at?: BlockHash` |
| `state_getRuntimeVersion` | Runtime version: spec name, spec version, impl version, API list | `at?: BlockHash` |
| `state_call` | Execute a runtime API method and return the SCALE-encoded result | `method: String`, `data: Bytes`, `at?: BlockHash` |
| `state_queryStorage` | Query multiple storage keys over a block range | `keys: Vec<StorageKey>`, `block: BlockHash`, `hash?: BlockHash` |
| `state_queryStorageAt` | Query multiple storage keys at a single block | `keys: Vec<StorageKey>`, `at?: BlockHash` |
| `state_getReadProof` | Generate a Merkle read proof for a set of storage keys | `keys: Vec<StorageKey>`, `at?: BlockHash` |
| `state_subscribeRuntimeVersion` | Subscribe — pushes runtime version when it changes on-chain (subscription) | — |
| `state_subscribeStorage` | Subscribe — pushes storage change sets for the given keys (subscription) | `keys?: Vec<StorageKey>` |
| `state_traceBlock` | Trace all storage accesses and extrinsic execution for a block **[unsafe]** | `block: BlockHash`, `targets?: String`, `storageKeys?: String`, `methods?: String` |

---

## grandpa (3 methods)

| Method | Purpose | Key params |
|--------|---------|------------|
| `grandpa_roundState` | Current GRANDPA round state: prevotes, precommits, round number | — |
| `grandpa_proveFinality` | Generate a finality proof (authority signatures) for a block | `blockNumber: BlockNumber` |
| `grandpa_subscribeJustifications` | Subscribe — pushes GRANDPA justifications as blocks are finalized (subscription) | — |

---

## mmr (2 methods)

Merkle Mountain Range proofs are used by the BEEFY light-client protocol for efficient cross-chain verification.

| Method | Purpose | Key params |
|--------|---------|------------|
| `mmr_root` | MMR root hash at a given block | `at?: BlockHash` |
| `mmr_generateProof` | Generate an MMR membership proof for one or more blocks | `blockNumbers: Vec<BlockNumber>`, `bestKnownBlockNumber?: BlockNumber`, `at?: BlockHash` |

---

## beefy (2 methods)

BEEFY (Bridge Efficiency Enabling Finality Yielder) provides compact finality proofs used by light clients and bridges.

| Method | Purpose | Key params |
|--------|---------|------------|
| `beefy_getFinalizedHead` | Hash of the latest BEEFY-finalized block | — |
| `beefy_subscribeJustifications` | Subscribe — pushes BEEFY justifications as blocks are BEEFY-finalized (subscription) | — |

---

## Notes

- **Source:** all 52 method names and summaries are sourced directly from `docs/openrpc.json` at tag `node-1.0.0`. Parameter names follow the upstream Polkadot-SDK conventions; the openrpc.json defers parameter schemas to the upstream reference at `https://paritytech.github.io/polkadot-sdk/master/sc_rpc/index.html`.
- **Unsafe methods** — `system_addReservedPeer`, `system_removeReservedPeer`, `system_dryRun`, `author_insertKey`, `author_rotateKeys`, `state_traceBlock` — are tagged `x-unsafe: true` in `openrpc.json` and require `--rpc-methods=Unsafe`.
- **Deprecated:** `state_getKeys` is superseded by `state_getKeysPaged` for all new integrations.

## Cross-references

- [references/custom-rpcs.md](custom-rpcs.md) — the 16 Midnight-specific methods (`midnight_*`, `systemParameters_*`, `sidechain_*`, `network_*`)
- `midnight-node:node-rpc-api` — parent skill: connection, discovery (`rpc.discover`), subscription usage examples
- `midnight-indexer:indexer-graphql-api` — higher-level GraphQL API for querying indexed chain data
- `midnight-dapp-dev:midnight-sdk` — DApp provider configuration using node RPC endpoints
