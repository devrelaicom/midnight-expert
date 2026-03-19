# GraphQL Types

Key types returned by the indexer GraphQL API.

## Block

Represents a block on the Midnight blockchain.

| Field | Type | Description |
|-------|------|-------------|
| `hash` | String | Block hash (hex-encoded) |
| `height` | Int | Block height (sequential index) |
| `timestamp` | String | Block creation timestamp (ISO 8601) |
| `transactions` | [Transaction] | Transactions included in this block |

## Transaction

Represents a transaction within a block.

| Field | Type | Description |
|-------|------|-------------|
| `hash` | String | Transaction hash (hex-encoded) |
| `identifier` | String | Application-assigned transaction identifier |
| `result` | TransactionResult | Execution outcome |
| `fees` | TransactionFees | Fee information |
| `contractActions` | [ContractAction] | Contract operations performed by this transaction |

## TransactionResult

Enum indicating the outcome of a transaction.

| Value | Meaning |
|-------|---------|
| `SUCCESS` | All transaction phases completed successfully |
| `PARTIAL_SUCCESS` | Guaranteed phase succeeded, fallible phase failed |
| `FAILURE` | Transaction failed entirely |

## TransactionFees

Fee details for a transaction.

| Field | Type | Description |
|-------|------|-------------|
| `paidFees` | String | Actual fees paid for this transaction |
| `estimatedFees` | String | Fees estimated before submission |

## TokenBalance

Token balance associated with a contract action.

| Field | Type | Description |
|-------|------|-------------|
| `tokenType` | String | Token type identifier |
| `value` | String | Token balance value |

## RelevantTransaction

Returned by the `shieldedTransactions` subscription. Wraps a transaction with sync progress information.

| Field | Type | Description |
|-------|------|-------------|
| `transaction` | Transaction | The relevant transaction data |
| `progress` | SyncProgress | Current scanning progress through the chain |

## UnshieldedTransaction

Returned by the `unshieldedTransactions` subscription. Wraps a transaction with address context.

| Field | Type | Description |
|-------|------|-------------|
| `transaction` | Transaction | The unshielded transaction data |
| `address` | String | The unshielded address involved |
| `progress` | SyncProgress | Current scanning progress through the chain |

## SyncProgress

Tracks how far the indexer has progressed through chain scanning, used by subscription responses to indicate completion status.

| Field | Type | Description |
|-------|------|-------------|
| `current` | Int | Number of blocks/items processed so far |
| `total` | Int | Total number of blocks/items to process |

When `current` equals `total`, the subscription has caught up with the chain head and will emit new events in real time.

## ContractAction (Interface)

All contract action variants share these base fields:

| Field | Type | Description |
|-------|------|-------------|
| `address` | String | Contract address |
| `state` | String | Contract state after the action |
| `zswapState` | String | Zswap state after the action |
| `transaction` | Transaction | Parent transaction |
| `unshieldedBalances` | [TokenBalance] | Unshielded token balances after the action |

### ContractDeploy

Initial deployment of a contract. Has base fields only.

### ContractCall

Invocation of a contract entry point.

| Field | Type | Description |
|-------|------|-------------|
| `entryPoint` | String | Name of the called entry point |

### ContractUpdate

Update to a deployed contract. Has base fields only.
