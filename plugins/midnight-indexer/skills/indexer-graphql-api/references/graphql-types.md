# GraphQL Types

Key types returned by the indexer GraphQL API.

## Block

Represents a block on the Midnight blockchain.

| Field | Type | Description |
|-------|------|-------------|
| `hash` | HexEncoded | Block hash (hex-encoded) |
| `height` | Int | Block height (sequential index) |
| `protocolVersion` | Int | Protocol version |
| `timestamp` | Int | Block creation time as a UNIX timestamp (seconds) |
| `author` | HexEncoded | Hex-encoded block author (nullable) |
| `parent` | Block | Parent block (nullable) |
| `transactions` | [Transaction!]! | Transactions included in this block |

## Transaction (Interface)

Implemented by `RegularTransaction` and `SystemTransaction`. Shared fields:

| Field | Type | Description |
|-------|------|-------------|
| `id` | Int | Indexer-internal transaction ID (BIGSERIAL) |
| `hash` | HexEncoded | Transaction hash (hex-encoded) |
| `protocolVersion` | Int | Protocol version |
| `raw` | HexEncoded | Hex-encoded serialized transaction content |
| `block` | Block | Parent block |
| `contractActions` | [ContractAction!]! | Contract operations performed by this transaction |
| `unshieldedCreatedOutputs` | [UnshieldedUtxo!]! | Unshielded UTXOs created |
| `unshieldedSpentOutputs` | [UnshieldedUtxo!]! | Unshielded UTXOs spent |

`RegularTransaction` additionally exposes `transactionResult: TransactionResult!`, `identifiers: [HexEncoded!]!` (note: plural array), `zswapMerkleTreeRoot`, `zswapStartIndex`/`zswapEndIndex`, and `fee: String!` (SPECK, the atomic unit of DUST). The legacy `merkleTreeRoot`/`startIndex`/`endIndex` and `fees: TransactionFees!` fields are deprecated.

## TransactionResult

Object describing the outcome of applying a transaction to the ledger state.

| Field | Type | Description |
|-------|------|-------------|
| `status` | TransactionResultStatus | Overall outcome (enum below) |
| `segments` | [Segment!] | Per-segment success flags (present for partial success) |

`TransactionResultStatus` enum values:

| Value | Meaning |
|-------|---------|
| `SUCCESS` | All transaction phases completed successfully |
| `PARTIAL_SUCCESS` | Guaranteed phase succeeded, fallible phase failed |
| `FAILURE` | Transaction failed entirely |

`Segment` has `id: Int!` and `success: Boolean!`.

## TransactionFees (deprecated)

Returned by the deprecated `fees` field. Prefer the top-level `fee: String!` field on a transaction.

| Field | Type | Description |
|-------|------|-------------|
| `paidFees` | String | Actual fees paid for this transaction (SPECK) |
| `estimatedFees` | String | Fees estimated before submission (deprecated; use `paidFees`) |

## ContractBalance

Token balance held by a contract, returned in `unshieldedBalances`.

| Field | Type | Description |
|-------|------|-------------|
| `tokenType` | HexEncoded | Hex-encoded token type identifier |
| `amount` | String | Balance amount as a string (supports values up to 16 bytes) |

## RelevantTransaction

One variant of the `ShieldedTransactionsEvent` union returned by the `shieldedTransactions` subscription. A transaction relevant to the subscribing wallet, plus an optional collapsed Merkle tree update.

| Field | Type | Description |
|-------|------|-------------|
| `transaction` | RegularTransaction | The relevant transaction data |
| `zswapCollapsedUpdate` | MerkleTreeCollapsedUpdate | Optional collapsed zswap Merkle tree update bridging an index gap |

## ShieldedTransactionsProgress

The other variant of `ShieldedTransactionsEvent`. Reports the indexer's shielded indexing progress.

| Field | Type | Description |
|-------|------|-------------|
| `highestZswapEndIndex` | Int | Highest zswap end index across all transactions (known chain state) |
| `highestCheckedZswapEndIndex` | Int | Highest zswap end index checked for relevance for this wallet |
| `highestRelevantZswapEndIndex` | Int | Highest zswap end index of relevant transactions for this wallet |

## UnshieldedTransaction

One variant of the `UnshieldedTransactionsEvent` union returned by the `unshieldedTransactions` subscription.

| Field | Type | Description |
|-------|------|-------------|
| `transaction` | Transaction | The unshielded transaction data |
| `createdUtxos` | [UnshieldedUtxo!]! | UTXOs created in the transaction (possibly empty) |
| `spentUtxos` | [UnshieldedUtxo!]! | UTXOs spent in the transaction (possibly empty) |

The other variant, `UnshieldedTransactionsProgress`, has a single field `highestTransactionId: Int!`.

## ContractAction (Interface)

All contract action variants share these base fields:

| Field | Type | Description |
|-------|------|-------------|
| `address` | HexEncoded | Contract address |
| `state` | HexEncoded | Contract state after the action |
| `zswapState` | HexEncoded | Zswap state after the action |
| `transaction` | Transaction | Parent transaction |
| `unshieldedBalances` | [ContractBalance!]! | Unshielded token balances after the action |

### ContractDeploy

Initial deployment of a contract. Has base fields only.

### ContractCall

Invocation of a contract entry point.

| Field | Type | Description |
|-------|------|-------------|
| `entryPoint` | String | Name of the called entry point |

### ContractUpdate

Update to a deployed contract. Has base fields only.
