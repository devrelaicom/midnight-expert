# Schema Reference — Midnight Indexer GraphQL API v4

Complete catalog of every type, field, operation, and directive in `schema-v4.graphql` (1518 lines, 68 type definitions + 5 directives). Use this file to verify exact field names, nullability, and argument signatures before writing queries.

**Interface-fragment rule.** Fields that exist only on a concrete type — not on the interface — require an inline fragment. For example, `RegularTransaction.identifiers` and `RegularTransaction.fee` are absent from the `Transaction` interface; you must write `... on RegularTransaction { identifiers fee }` to select them.

For pagination patterns see `references/pagination-and-offsets.md`. For the full `@beta` dust API see `references/dust-beta-api.md`. For type-level narrative descriptions see `references/graphql-types.md`.

---

## Scalars

`schema-v4.graphql:81,295,639,1381,1383,1464`

| Scalar | Description |
|--------|-------------|
| `HexEncoded` | Hex-encoded byte string. Used for hashes, addresses, raw serialized objects. |
| `CardanoRewardAddress` | Bech32-encoded Cardano reward (stake) address (`stake1…` / `stake_test1…`). |
| `DustAddress` | Bech32m-encoded DUST address. Used for DUST generation subscriptions. |
| `UnshieldedAddress` | Bech32m-encoded unshielded (transparent) Midnight address. |
| `ViewingKey` | Viewing key scalar accepted by the `connect` mutation. |
| `Unit` | Void return type; returned by `disconnect`. |

---

## Enum

`schema-v4.graphql:1375`

### TransactionResultStatus

| Value | Meaning |
|-------|---------|
| `SUCCESS` | All transaction phases completed successfully. |
| `PARTIAL_SUCCESS` | Guaranteed phase succeeded; fallible phase failed. `TransactionResult.segments` is populated. |
| `FAILURE` | Transaction failed entirely. |

---

## Root Operations

### Query

30 fields. `schema-v4.graphql:715`

#### Block & Transaction queries

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `block` | `offset: BlockOffset` (nullable) | `Block` (nullable) | Omit offset → latest block. |
| `transactions` | `offset: TransactionOffset!` | `[Transaction!]!` | |
| `contractAction` | `address: HexEncoded!`, `offset: ContractActionOffset` (nullable) | `ContractAction` (nullable) | |
| `zswapMerkleTreeCollapsedUpdate` | `startIndex: Int!`, `endIndex: Int!` | `MerkleTreeCollapsedUpdate!` | Zswap state index range. |

#### DUST queries (`@beta`)

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `dustGenerationStatus` | `cardanoRewardAddresses: [CardanoRewardAddress!]!` | `[DustGenerationStatus!]!` | One result per address. |
| `dustGenerations` | `cardanoRewardAddresses: [CardanoRewardAddress!]!` | `[DustGenerations!]!` | Aggregated per-address generation stats. |
| `dustCommitmentMerkleTreeUpdate` | `startIndex: Int!`, `endIndex: Int!` | `MerkleTreeCollapsedUpdate!` `@beta` | Dust commitment tree range. |
| `dustGenerationMerkleTreeUpdate` | `startIndex: Int!`, `endIndex: Int!` | `MerkleTreeCollapsedUpdate!` `@beta` | Dust generation tree range. |

#### Governance & system queries

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `dParameterHistory` | — | `[DParameterChange!]!` | Full history of D-parameter changes. |
| `termsAndConditionsHistory` | — | `[TermsAndConditionsChange!]!` | Full history of T&C changes. |
| `currentEpochInfo` | — | `EpochInfo` (nullable) | Current epoch number, duration, elapsed. |
| `epochUtilization` | `epoch: Int!` | `Float` (nullable) | Produced/expected block ratio. |
| `committee` | `epoch: Int!` | `[CommitteeMember!]!` | Validator committee for the epoch. |

#### SPO identity queries

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `spoCount` | — | `Int` (nullable) | Total count of SPOs. |
| `spoIdentities` | `limit: Int`, `offset: Int` | `[SpoIdentity!]!` | Paginated list. |
| `spoIdentityByPoolId` | `poolIdHex: String!` | `SpoIdentity` (nullable) | Lookup by Cardano pool ID. |
| `spoByPoolId` | `poolIdHex: String!` | `Spo` (nullable) | Identity + metadata. |
| `spoList` | `limit: Int`, `offset: Int`, `search: String` | `[Spo!]!` | |
| `spoCompositeByPoolId` | `poolIdHex: String!` | `SpoComposite` (nullable) | Identity + metadata + performance. |

#### Pool metadata queries

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `poolMetadata` | `poolIdHex: String!` | `PoolMetadata` (nullable) | Single pool. |
| `poolMetadataList` | `limit: Int`, `offset: Int`, `withNameOnly: Boolean` | `[PoolMetadata!]!` | |

#### SPO performance queries

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `stakePoolOperators` | `limit: Int` | `[String!]!` | Pool IDs ordered by performance. |
| `spoPerformanceLatest` | `limit: Int`, `offset: Int` | `[EpochPerf!]!` | Latest epoch performance entries. |
| `spoPerformanceBySpoSk` | `spoSkHex: String!`, `limit: Int`, `offset: Int` | `[EpochPerf!]!` | Performance history for one SPO key. |
| `epochPerformance` | `epoch: Int!`, `limit: Int`, `offset: Int` | `[EpochPerf!]!` | All SPOs for a specific epoch. |
| `stakeDistribution` | `limit: Int`, `offset: Int`, `search: String`, `orderByStakeDesc: Boolean` | `[StakeShare!]!` | Stake distribution with search and ordering. |

#### Registration series queries

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `registeredTotalsSeries` | `fromEpoch: Int!`, `toEpoch: Int!` | `[RegisteredTotals!]!` | Cumulative registration totals over epoch range. |
| `registeredSpoSeries` | `fromEpoch: Int!`, `toEpoch: Int!` | `[RegisteredStat!]!` | Registration stats per epoch. |
| `registeredPresence` | `fromEpoch: Int!`, `toEpoch: Int!` | `[PresenceEvent!]!` | Raw presence events per epoch range. |
| `registeredFirstValidEpochs` | `uptoEpoch: Int` (nullable) | `[FirstValidEpoch!]!` | First valid epoch per SPO identity. |

---

### Mutation

2 fields. `schema-v4.graphql:663`

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `connect` | `viewingKey: ViewingKey!`, `options: ConnectOptions` (nullable) | `HexEncoded!` | Returns session ID. |
| `disconnect` | `sessionId: HexEncoded!` | `Unit!` | Terminates a session. |

---

### Subscription

**9 subscriptions.** `schema-v4.graphql:1169`

> Note the different nullifier argument names: `dustNullifierTransactions` uses `nullifierLeBytesPrefixes` (LE-byte prefixes); `shieldedNullifierTransactions` uses `nullifierPrefixes`.

| Field | Arguments | Return type | Notes |
|-------|-----------|-------------|-------|
| `blocks` | `offset: BlockOffset` (nullable) | `Block!` | Omit offset → start from latest block. |
| `contractActions` | `address: HexEncoded!`, `offset: BlockOffset` (nullable) | `ContractAction!` | All contract actions at a given address. |
| `dustGenerations` | `dustAddress: DustAddress!`, `startIndex: Int!`, `endIndex: Int!` | `DustGenerationsEvent!` `@beta` | Generation entries interleaved with collapsed Merkle updates and dtime updates. Pass `dustGenerationEndIndex - 1` as `endIndex`. |
| `dustLedgerEvents` | `id: Int` (nullable) | `DustLedgerEvent!` | Omit `id` → start from the very beginning. |
| `dustNullifierTransactions` | `nullifierLeBytesPrefixes: [HexEncoded!]!`, `fromBlock: Int` (nullable), `toBlock: Int` (nullable) | `DustNullifierTransaction!` | Matches LE-form dust nullifiers. Terminates after `toBlock` if set. |
| `shieldedNullifierTransactions` | `nullifierPrefixes: [HexEncoded!]!`, `fromBlock: Int` (nullable), `toBlock: Int` (nullable) | `ShieldedNullifierTransaction!` | Matches zswap nullifiers. Terminates after `toBlock` if set. |
| `shieldedTransactions` | `sessionId: HexEncoded!`, `index: Int` (nullable) | `ShieldedTransactionsEvent!` | Relevant shielded transactions for a connected wallet. Omit `index` → start from 0. |
| `unshieldedTransactions` | `address: UnshieldedAddress!`, `transactionId: Int` (nullable) | `UnshieldedTransactionsEvent!` | Omit `transactionId` → start from 0. |
| `zswapLedgerEvents` | `id: Int` (nullable) | `ZswapLedgerEvent!` | Omit `id` → start from the very beginning. |

---

## Interfaces

### Transaction

`schema-v4.graphql:1322`

Implemented by `RegularTransaction` and `SystemTransaction`.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `Int!` | Indexer-internal BIGSERIAL. Use as resumption cursor. |
| `hash` | `HexEncoded!` | 32-byte transaction hash. |
| `protocolVersion` | `Int!` | |
| `raw` | `HexEncoded!` | Hex-encoded serialized transaction content. |
| `block` | `Block!` | Parent block. |
| `contractActions` | `[ContractAction!]!` | Contract operations in this transaction. |
| `unshieldedCreatedOutputs` | `[UnshieldedUtxo!]!` | Unshielded UTXOs created. |
| `unshieldedSpentOutputs` | `[UnshieldedUtxo!]!` | Unshielded UTXOs consumed. |
| `zswapLedgerEvents` | `[ZswapLedgerEvent!]!` | Zswap ledger events. |
| `dustLedgerEvents` | `[DustLedgerEvent!]!` | Dust ledger events. |

Fields on `RegularTransaction` only (absent from the interface — use `... on RegularTransaction`):
`transactionResult`, `identifiers`, `zswapMerkleTreeRoot`, `zswapStartIndex`, `zswapEndIndex`, `fee`, `fees` (deprecated), dust index fields (`@beta`), and deprecated aliases.

### ContractAction

`schema-v4.graphql:131`

Implemented by `ContractDeploy`, `ContractCall`, and `ContractUpdate`.

| Field | Type | Notes |
|-------|------|-------|
| `address` | `HexEncoded!` | Contract address. |
| `state` | `HexEncoded!` | Serialized contract state after the action. |
| `zswapState` | `HexEncoded!` | Serialized zswap state after the action. |
| `transaction` | `Transaction!` | Parent transaction. |
| `unshieldedBalances` | `[ContractBalance!]!` | Unshielded token balances held by the contract. |

Fields on concrete types only (use inline fragment):
- `ContractCall.entryPoint` and `ContractCall.deploy` require `... on ContractCall`.

### DustLedgerEvent

`schema-v4.graphql:500`

Implemented by `DustGenerationDtimeUpdate`, `DustInitialUtxo`, `DustSpendProcessed`, and `ParamChange`.

| Field | Type | Notes |
|-------|------|-------|
| `id` | `Int!` | Indexer-internal event ID. |
| `raw` | `HexEncoded!` | Serialized event payload. |
| `maxId` | `Int!` | Highest event ID at time of delivery. |
| `protocolVersion` | `Int!` | |

`DustInitialUtxo` additionally exposes `output: DustOutput!` (use `... on DustInitialUtxo`).

---

## Object Types

### Block

`schema-v4.graphql:4`

| Field | Type | Notes |
|-------|------|-------|
| `hash` | `HexEncoded!` | Block hash. |
| `height` | `Int!` | Block height. |
| `protocolVersion` | `Int!` | |
| `timestamp` | `Int!` | Raw Substrate moment value in **milliseconds** (not seconds). |
| `author` | `HexEncoded` | Nullable — absent for genesis/synthetic blocks. |
| `zswapMerkleTreeRoot` | `HexEncoded!` | Zswap commitment tree root at this block. |
| `ledgerParameters` | `HexEncoded!` | Serialized ledger parameters in effect. |
| `zswapEndIndex` | `Int!` | Exclusive next-free index into the zswap tree. |
| `parent` | `Block` | Nullable parent block. |
| `transactions` | `[Transaction!]!` | Transactions in this block. |
| `systemParameters` | `SystemParameters!` | Governance parameters at this height. |
| `dustCommitmentEndIndex` | `Int!` `@beta` | Exclusive next-free dust commitment tree index. |
| `dustGenerationEndIndex` | `Int!` `@beta` | Exclusive next-free dust generation tree index. |
| `dustCommitmentMerkleTreeRoot` | `HexEncoded` | Nullable — latest indexed dust commitment root. |
| `dustGenerationMerkleTreeRoot` | `HexEncoded` | Nullable — latest indexed dust generation root. |

### RegularTransaction

`schema-v4.graphql:863`

Implements `Transaction`. Contains all interface fields plus:

| Field | Type | Notes |
|-------|------|-------|
| `transactionResult` | `TransactionResult!` | Outcome of applying this transaction. |
| `identifiers` | `[HexEncoded!]!` | Serialized transaction identifiers (array, not scalar). |
| `zswapMerkleTreeRoot` | `HexEncoded!` | Zswap tree root after this transaction. |
| `zswapStartIndex` | `Int!` | Start index into the zswap state (inclusive). |
| `zswapEndIndex` | `Int!` | End index into the zswap state (exclusive). |
| `fee` | `String!` | Fee paid in SPECK (atomic DUST unit). |
| `fees` | `TransactionFees!` | `@deprecated` — use `fee` instead. |
| `merkleTreeRoot` | `HexEncoded!` | `@deprecated` — use `zswapMerkleTreeRoot`. |
| `startIndex` | `Int!` | `@deprecated` — use `zswapStartIndex`. |
| `endIndex` | `Int!` | `@deprecated` — use `zswapEndIndex`. |
| `dustCommitmentStartIndex` | `Int!` `@beta` | Dust commitment tree start index. |
| `dustCommitmentEndIndex` | `Int!` `@beta` | Dust commitment tree end index. |
| `dustGenerationStartIndex` | `Int!` `@beta` | Dust generation tree start index. |
| `dustGenerationEndIndex` | `Int!` `@beta` | Dust generation tree end index. |

**Deprecation chain for fees:** `fees: TransactionFees!` is deprecated in favor of `fee: String!`. Within `TransactionFees`, `estimatedFees` is deprecated in favor of `paidFees`.

### SystemTransaction

`schema-v4.graphql:1236`

Implements `Transaction`. Contains only the interface fields — no `transactionResult`, no `fee`, no `identifiers`.

### TransactionResult

`schema-v4.graphql:1367`

| Field | Type | Notes |
|-------|------|-------|
| `status` | `TransactionResultStatus!` | Outcome enum. |
| `segments` | `[Segment!]` | Nullable; only populated when status is `PARTIAL_SUCCESS`. |

### Segment

`schema-v4.graphql:987`

| Field | Type |
|-------|------|
| `id` | `Int!` |
| `success` | `Boolean!` |

### TransactionFees (deprecated)

`schema-v4.graphql:1338`

Returned by deprecated `RegularTransaction.fees`. Prefer `RegularTransaction.fee: String!`.

| Field | Type | Notes |
|-------|------|-------|
| `paidFees` | `String!` | Actual fees paid, in SPECK. |
| `estimatedFees` | `String!` | `@deprecated` — use `paidFees`. |

---

### ContractDeploy

`schema-v4.graphql:206`

Implements `ContractAction`. Contains only the interface fields.

### ContractCall

`schema-v4.graphql:172`

Implements `ContractAction`. Contains interface fields plus:

| Field | Type | Notes |
|-------|------|-------|
| `entryPoint` | `String!` | Name of the called entry point. Non-null. |
| `deploy` | `ContractDeploy!` | The originating deploy this call references. Non-null. |

### ContractUpdate

`schema-v4.graphql:232`

Implements `ContractAction`. Contains only the interface fields.

### ContractBalance

`schema-v4.graphql:158`

Returned in `ContractAction.unshieldedBalances`.

| Field | Type | Notes |
|-------|------|-------|
| `tokenType` | `HexEncoded!` | Hex-encoded token type identifier. |
| `amount` | `String!` | Balance as string (supports up to 16-byte / u128 values). Note: named `amount`, not `value`. |

---

### UnshieldedUtxo

`schema-v4.graphql:1421`

| Field | Type | Notes |
|-------|------|-------|
| `owner` | `UnshieldedAddress!` | Bech32m-encoded owner address. |
| `tokenType` | `HexEncoded!` | Serialized token type. |
| `value` | `String!` | Quantity as string (u128). Note: named `value`, not `amount`. |
| `intentHash` | `HexEncoded!` | Intent hash that produced/consumed this UTXO. |
| `outputIndex` | `Int!` | Index within the creating transaction. |
| `ctime` | `Int` | Nullable creation time in seconds. |
| `initialNonce` | `HexEncoded!` | Initial nonce for DUST generation tracking. |
| `registeredForDustGeneration` | `Boolean!` | Whether this UTXO is registered for DUST generation. |
| `createdAtTransaction` | `Transaction!` | Transaction that created this UTXO. |
| `spentAtTransaction` | `Transaction` | Nullable — transaction that spent this UTXO. |

---

### RelevantTransaction

`schema-v4.graphql:966`

One variant of `ShieldedTransactionsEvent`.

| Field | Type | Notes |
|-------|------|-------|
| `transaction` | `RegularTransaction!` | The relevant transaction (concrete type, not the interface). |
| `zswapCollapsedUpdate` | `MerkleTreeCollapsedUpdate` | Nullable — gap-filling collapsed update. |
| `collapsedMerkleTree` | `CollapsedMerkleTree` | `@deprecated` — use `zswapCollapsedUpdate`. |

### ShieldedTransactionsProgress

`schema-v4.graphql:1036`

One variant of `ShieldedTransactionsEvent`.

| Field | Type | Notes |
|-------|------|-------|
| `highestZswapEndIndex` | `Int!` | Highest zswap end index across all known transactions. |
| `highestCheckedZswapEndIndex` | `Int!` | Highest index checked for relevance for this wallet. |
| `highestRelevantZswapEndIndex` | `Int!` | Highest index of relevant transactions for this wallet. |
| `highestEndIndex` | `Int!` | `@deprecated` — use `highestZswapEndIndex`. |
| `highestCheckedEndIndex` | `Int!` | `@deprecated` — use `highestCheckedZswapEndIndex`. |
| `highestRelevantEndIndex` | `Int!` | `@deprecated` — use `highestRelevantZswapEndIndex`. |

### UnshieldedTransaction

`schema-v4.graphql:1388`

One variant of `UnshieldedTransactionsEvent`.

| Field | Type | Notes |
|-------|------|-------|
| `transaction` | `Transaction!` | The underlying transaction. |
| `createdUtxos` | `[UnshieldedUtxo!]!` | UTXOs created (possibly empty). |
| `spentUtxos` | `[UnshieldedUtxo!]!` | UTXOs spent (possibly empty). |

### UnshieldedTransactionsProgress

`schema-v4.graphql:1411`

| Field | Type | Notes |
|-------|------|-------|
| `highestTransactionId` | `Int!` | Highest transaction ID of all known transactions for this address. |

---

### MerkleTreeCollapsedUpdate

`schema-v4.graphql:644`

Returned by `Query.zswapMerkleTreeCollapsedUpdate`, `Query.dustCommitmentMerkleTreeUpdate`, `Query.dustGenerationMerkleTreeUpdate`, and embedded in `RelevantTransaction`, `DustGenerationsItem`, `DustGenerationsProgress`.

| Field | Type |
|-------|------|
| `startIndex` | `Int!` |
| `endIndex` | `Int!` |
| `update` | `HexEncoded!` |
| `protocolVersion` | `Int!` |

### CollapsedMerkleTree (deprecated)

`schema-v4.graphql:86`

Deprecated predecessor to `MerkleTreeCollapsedUpdate`. Identical shape. Returned by deprecated `RelevantTransaction.collapsedMerkleTree`. Use `MerkleTreeCollapsedUpdate` instead.

---

### ZswapLedgerEvent

`schema-v4.graphql:1469`

| Field | Type | Notes |
|-------|------|-------|
| `id` | `Int!` | Event ID. |
| `raw` | `HexEncoded!` | Serialized event. |
| `maxId` | `Int!` | Highest known event ID at delivery time. |
| `protocolVersion` | `Int!` | |

### DustLedgerEvent concrete types

`schema-v4.graphql:297,474,589,674`

All implement the `DustLedgerEvent` interface (fields: `id: Int!`, `raw: HexEncoded!`, `maxId: Int!`, `protocolVersion: Int!`).

| Type | Extra fields |
|------|-------------|
| `DustInitialUtxo` | `output: DustOutput!` (use `... on DustInitialUtxo`) |
| `DustGenerationDtimeUpdate` | None beyond interface. |
| `DustSpendProcessed` | None beyond interface. |
| `ParamChange` | None beyond interface. |

### DustOutput

`schema-v4.graphql:544`

| Field | Type |
|-------|------|
| `nonce` | `HexEncoded!` |

---

### DUST generation types (`@beta`)

> These types are part of the in-flight dust generation API. Expect breaking changes. Deep treatment is deferred to `references/dust-beta-api.md`.

`schema-v4.graphql:320,417,463,356,398,554,510,1001`

| Type | Key fields | Notes |
|------|-----------|-------|
| `DustGenerationsItem` `@beta` | `commitmentMtIndex: Int!`, `generationMtIndex: Int!`, `owner: HexEncoded!`, `value: String!`, `initialValue: String!`, `backingNight: HexEncoded!`, `ctime: Int!`, `transactionId: Int!`, `transactionHash: HexEncoded!`, `collapsedMerkleTree: MerkleTreeCollapsedUpdate` | Committed generation entry. |
| `DustGenerationDtimeUpdateItem` `@beta` | `generationMtIndex: Int!`, `owner: HexEncoded!`, `nightUtxoHash: HexEncoded!`, `newDtime: Int!`, `transactionId: Int!`, `transactionHash: HexEncoded!`, `treeInsertionPath: HexEncoded!` | Emitted when backing NIGHT UTXO is spent. |
| `DustGenerationsProgress` `@beta` | `highestIndex: Int!`, `collapsedMerkleTree: MerkleTreeCollapsedUpdate` | Final progress indicator with optional collapsed update. |
| `DustGenerationStatus` | `cardanoRewardAddress: CardanoRewardAddress!`, `dustAddress: DustAddress` (nullable), `registered: Boolean!`, `nightBalance: String!`, `generationRate: String!`, `maxCapacity: String!`, `currentCapacity: String!`, `utxoTxHash: HexEncoded` (nullable), `utxoOutputIndex: Int` (nullable) | Returned by `Query.dustGenerationStatus`. |
| `DustGenerations` | `cardanoRewardAddress: CardanoRewardAddress!`, `registrations: [DustRegistration!]!` | Returned by `Query.dustGenerations`. |
| `DustRegistration` | `dustAddress: DustAddress!`, `valid: Boolean!`, `nightBalance: String!`, `generationRate: String!`, `maxCapacity: String!`, `currentCapacity: String!`, `utxoTxHash: HexEncoded` (nullable), `utxoOutputIndex: Int` (nullable) | Active registration with generation stats. |
| `DustNullifierTransaction` | `nullifierLeBytes: HexEncoded!` `@beta`, `commitmentLeBytes: HexEncoded!` `@beta`, `transactionId: Int!`, `transactionHash: HexEncoded!`, `blockHeight: Int!`, `blockHash: HexEncoded!`, `transaction: Transaction!` `@beta` | Returned by `dustNullifierTransactions` subscription. |
| `ShieldedNullifierTransaction` | `transactionId: Int!`, `transactionHash: HexEncoded!`, `blockHash: HexEncoded!`, `blockHeight: Int!`, `nullifier: HexEncoded!`, `transaction: Transaction!` `@beta` | Returned by `shieldedNullifierTransactions` subscription. |

---

### Governance & system types

`schema-v4.graphql:258,272,1222,1282,1296`

| Type | Fields |
|------|--------|
| `SystemParameters` | `dParameter: DParameter!`, `termsAndConditions: TermsAndConditions` (nullable) |
| `DParameter` | `numPermissionedCandidates: Int!`, `numRegisteredCandidates: Int!` |
| `DParameterChange` | `blockHeight: Int!`, `blockHash: HexEncoded!`, `timestamp: Int!`, `numPermissionedCandidates: Int!`, `numRegisteredCandidates: Int!` |
| `TermsAndConditions` | `hash: HexEncoded!`, `url: String!` |
| `TermsAndConditionsChange` | `blockHeight: Int!`, `blockHash: HexEncoded!`, `timestamp: Int!`, `hash: HexEncoded!`, `url: String!` |

### SPO & epoch types

`schema-v4.graphql:108,611,620,634,696,708,842,854,863` (type definitions), `schema-v4.graphql:1082,1096,1105,1118`

| Type | Key fields |
|------|-----------|
| `SpoIdentity` | `poolIdHex: String!`, `mainchainPubkeyHex: String!`, `sidechainPubkeyHex: String!`, `auraPubkeyHex: String` (nullable), `validatorClass: String!` |
| `Spo` | `poolIdHex: String!`, `validatorClass: String!`, `sidechainPubkeyHex: String!`, `auraPubkeyHex: String` (nullable), `name/ticker/homepageUrl/logoUrl: String` (all nullable) |
| `SpoComposite` | `identity: SpoIdentity` (nullable), `metadata: PoolMetadata` (nullable), `performance: [EpochPerf!]!` |
| `PoolMetadata` | `poolIdHex: String!`, `hexId/name/ticker/homepageUrl/logoUrl: String` (all nullable) |
| `StakeShare` | `poolIdHex: String!`, `name/ticker/homepageUrl/logoUrl: String` (nullable), `liveStake/activeStake/declaredPledge/livePledge: String` (nullable), `liveDelegators: Int` (nullable), `liveSaturation/stakeShare: Float` (nullable) |
| `EpochPerf` | `epochNo: Int!`, `spoSkHex: String!`, `produced: Int!`, `expected: Int!`, `identityLabel/stakeSnapshot/poolIdHex/validatorClass: String` (nullable) |
| `EpochInfo` | `epochNo: Int!`, `durationSeconds: Int!`, `elapsedSeconds: Int!` |
| `CommitteeMember` | `epochNo: Int!`, `position: Int!`, `sidechainPubkeyHex: String!`, `expectedSlots: Int!`, `auraPubkeyHex/poolIdHex/spoSkHex: String` (nullable) |
| `PresenceEvent` | `epochNo: Int!`, `idKey: String!`, `source: String!`, `status: String` (nullable) |
| `RegisteredStat` | `epochNo: Int!`, `federatedValidCount: Int!`, `federatedInvalidCount: Int!`, `registeredValidCount: Int!`, `registeredInvalidCount: Int!`, `dparam: Float` (nullable) |
| `RegisteredTotals` | `epochNo: Int!`, `totalRegistered: Int!`, `newlyRegistered: Int!` |
| `FirstValidEpoch` | `idKey: String!`, `firstValidEpoch: Int!` |

---

## Unions

`schema-v4.graphql:412,1031,1406`

| Union | Members |
|-------|---------|
| `DustGenerationsEvent` | `DustGenerationsItem` \| `DustGenerationsProgress` \| `DustGenerationDtimeUpdateItem` |
| `ShieldedTransactionsEvent` | `RelevantTransaction` \| `ShieldedTransactionsProgress` |
| `UnshieldedTransactionsEvent` | `UnshieldedTransaction` \| `UnshieldedTransactionsProgress` |

---

## Input Types

All four inputs use `@oneOf` or are plain objects. `schema-v4.graphql:70,121,142,1352`

### BlockOffset `@oneOf`

`schema-v4.graphql:70`

Exactly one field must be provided.

| Field | Type |
|-------|------|
| `hash` | `HexEncoded` |
| `height` | `Int` |

### TransactionOffset `@oneOf`

`schema-v4.graphql:1352`

Exactly one field must be provided.

| Field | Type | Notes |
|-------|------|-------|
| `hash` | `HexEncoded` | Hex-encoded transaction hash. |
| `identifier` | `HexEncoded` | Hex-encoded transaction identifier. |

### ContractActionOffset `@oneOf`

`schema-v4.graphql:142`

Exactly one field must be provided.

| Field | Type | Notes |
|-------|------|-------|
| `blockOffset` | `BlockOffset` | Either a block hash or height. |
| `transactionOffset` | `TransactionOffset` | Either a transaction hash or identifier. |

### ConnectOptions

`schema-v4.graphql:121`

Plain input object (no `@oneOf`).

| Field | Type | Notes |
|-------|------|-------|
| `startIndex` | `Int` | Nullable. Transaction index to start scanning from (inclusive). |

---

## Directives

`schema-v4.graphql:1496–1512`

| Directive | Locations | Meaning |
|-----------|-----------|---------|
| `@beta` | `FIELD_DEFINITION`, `OBJECT` | In-flight / unstable. Expect breaking changes without notice. Currently applied to the dust-generation API surface pending redesign. |
| `@deprecated(reason)` | `FIELD_DEFINITION`, `ARGUMENT_DEFINITION`, `INPUT_FIELD_DEFINITION`, `ENUM_VALUE` | Field or value is superseded. `reason` defaults to `"No longer supported"`. |
| `@oneOf` | `INPUT_OBJECT` | Exactly one field of the input object must be provided. Applied to `BlockOffset`, `TransactionOffset`, `ContractActionOffset`. |
| `@include(if: Boolean!)` | `FIELD`, `FRAGMENT_SPREAD`, `INLINE_FRAGMENT` | Standard — include when `if` is true. |
| `@skip(if: Boolean!)` | `FIELD`, `FRAGMENT_SPREAD`, `INLINE_FRAGMENT` | Standard — skip when `if` is true. |

---

## Deprecation Summary

| Deprecated field | Preferred replacement |
|------------------|-----------------------|
| `RegularTransaction.merkleTreeRoot` | `RegularTransaction.zswapMerkleTreeRoot` |
| `RegularTransaction.startIndex` | `RegularTransaction.zswapStartIndex` |
| `RegularTransaction.endIndex` | `RegularTransaction.zswapEndIndex` |
| `RegularTransaction.fees` | `RegularTransaction.fee` (returns `String!` in SPECK) |
| `TransactionFees.estimatedFees` | `TransactionFees.paidFees` |
| `RelevantTransaction.collapsedMerkleTree` | `RelevantTransaction.zswapCollapsedUpdate` |
| `ShieldedTransactionsProgress.highestEndIndex` | `ShieldedTransactionsProgress.highestZswapEndIndex` |
| `ShieldedTransactionsProgress.highestCheckedEndIndex` | `ShieldedTransactionsProgress.highestCheckedZswapEndIndex` |
| `ShieldedTransactionsProgress.highestRelevantEndIndex` | `ShieldedTransactionsProgress.highestRelevantZswapEndIndex` |

---

## Cross-references

- `references/graphql-types.md` — narrative descriptions of core types (Block, Transaction, ContractAction, UnshieldedUtxo, RelevantTransaction, UnshieldedTransaction).
- `references/pagination-and-offsets.md` — how to use `BlockOffset`, `TransactionOffset`, `ContractActionOffset`, and resumption cursor patterns.
- `references/dust-beta-api.md` — deep treatment of the `@beta` dust generation API surface (`DustGenerationsItem`, `DustGenerationsProgress`, `DustGenerationDtimeUpdateItem`, and the `dustGenerations` subscription).
- `midnight-indexer:indexer-graphql-api` — the parent skill; contains usage patterns and subscription examples.
