---
name: midnight-indexer:indexer-graphql-api
description: This skill should be used when the user asks about indexer GraphQL, indexer queries, indexer subscriptions, indexer mutations, GraphQL API, contractAction query, block query, wallet connect, shieldedTransactions subscription, unshieldedTransactions, dustLedgerEvents, zswapLedgerEvents, indexer endpoint, api/v4/graphql, indexer network endpoints, or GraphQL query limits. Covers "how to query blocks", "how to subscribe to contract events", "GraphQL schema", and "WebSocket subscription".
version: 0.1.0
---

# Indexer GraphQL API

The Midnight indexer exposes a GraphQL API for querying on-chain state, managing wallet sessions, and subscribing to real-time events.

## Endpoints

| Protocol | Path | Notes |
|----------|------|-------|
| HTTP POST | `/api/v4/graphql` | Query and mutation endpoint |
| WebSocket | `/api/v4/graphql/ws` | Subscription endpoint (protocol: `graphql-transport-ws`) |

The v3 endpoint paths (`/api/v3/graphql` and `/api/v3/graphql/ws`) still work as aliases for backwards compatibility.

**Default port:** 8088

### Query Limits

| Limit | Value |
|-------|-------|
| Max complexity | 200 |
| Max depth | 15 |
| Request body limit | 1 MiB |

> **See also:** `references/error-handling.md` — error responses when limits are exceeded.

## Network Endpoints

| Network | HTTP | WebSocket |
|---------|------|-----------|
| Local/Undeployed | `http://localhost:8088/api/v4/graphql` | `ws://localhost:8088/api/v4/graphql/ws` |
| Preview | `https://indexer.preview.midnight.network/api/v4/graphql` | `wss://indexer.preview.midnight.network/api/v4/graphql/ws` |
| Preprod | `https://indexer.preprod.midnight.network/api/v4/graphql` | `wss://indexer.preprod.midnight.network/api/v4/graphql/ws` |

## Queries

| Query | Parameters | Returns |
|-------|-----------|---------|
| `block(offset?)` | BlockOffset (hash or height), omit for latest | Block with transactions |
| `transactions(offset!)` | TransactionOffset (hash or identifier) | Array of Transaction |
| `contractAction(address!, offset?)` | Contract address + optional block/tx offset | ContractDeploy, ContractCall, or ContractUpdate |
| `dustGenerationStatus(cardanoRewardAddresses!)` | Array of Cardano stake addresses (max 10) | DUST generation status |
| `dParameterHistory` | none | D-parameter records |
| `termsAndConditionsHistory` | none | Terms & Conditions records |
| `spoIdentities` | all optional: `limit: Int`, `offset: Int` (callable with no args) | SPO identity records |
| `spoByPoolId` | Pool ID | SPO details |
| `spoCompositeByPoolId` | Pool ID | Composite SPO data |
| `stakeDistribution` | all optional: `limit: Int`, `offset: Int`, `search: String`, `orderByStakeDesc: Boolean` (callable with no args) | Stake distribution data |

### Example: Query Latest Block

```graphql
query {
  block {
    hash
    height
    timestamp
    transactions {
      hash
      ... on RegularTransaction {
        identifiers
      }
    }
  }
}
```

### Example: Query Contract Action

```graphql
query {
  contractAction(address: "0x...") {
    ... on ContractDeploy {
      address
      state
      transaction {
        hash
      }
    }
    ... on ContractCall {
      address
      entryPoint
      state
      zswapState
      unshieldedBalances {
        tokenType
        amount
      }
    }
  }
}
```

> **See also:** `references/pagination-and-offsets.md` — BlockOffset and TransactionOffset types. `examples/http-requests.md` — full curl examples for queries.

## Mutations

| Mutation | Parameters | Returns | Purpose |
|---------|-----------|---------|---------|
| `connect(viewingKey!, options?)` | Bech32m-encoded viewing key (`ViewingKey` scalar); optional `ConnectOptions { startIndex }` to begin scanning from a transaction index | Session ID (`HexEncoded`) | Establish wallet session for shielded transaction scanning |
| `disconnect(sessionId!)` | Session ID from `connect` | `Unit` (empty) | End wallet session |

### Example: Wallet Connection

```graphql
# Connect wallet
mutation {
  connect(viewingKey: "bech32m_encoded_key_here")
}

# Disconnect wallet
mutation {
  disconnect(sessionId: "session-id-hex")
}
```

> **See also:** `examples/http-requests.md` — curl examples for connect and disconnect mutations. `references/error-handling.md` — invalid session ID errors.

## Subscriptions

The indexer provides 9 subscriptions for real-time event streaming over WebSocket.

| Subscription | Parameters | Emits |
|-------------|-----------|-------|
| `blocks(offset?)` | Optional `BlockOffset` (hash or height) start block | Block objects |
| `contractActions(address!, offset?)` | Contract address + optional `BlockOffset` start | ContractDeploy, ContractCall, or ContractUpdate |
| `shieldedTransactions(sessionId!, index?)` | Session ID from `connect` mutation, optional `Int` index | `ShieldedTransactionsEvent` union (RelevantTransaction or ShieldedTransactionsProgress) |
| `unshieldedTransactions(address!, transactionId?)` | `UnshieldedAddress` (Bech32m), optional `Int` transactionId | `UnshieldedTransactionsEvent` union (UnshieldedTransaction or UnshieldedTransactionsProgress) |
| `dustLedgerEvents(id?)` | Optional `Int` event id to resume from | DUST ledger events |
| `zswapLedgerEvents(id?)` | Optional `Int` event id to resume from | Zswap ledger events |
| `dustGenerations(dustAddress!, startIndex!, endIndex!)` | DUST address (`DustAddress` scalar) + inclusive `[startIndex, endIndex]` index range | `DustGenerationsEvent` union (generation entries, collapsed Merkle updates, dtime updates) |
| `dustNullifierTransactions(nullifierLeBytesPrefixes!, fromBlock?, toBlock?)` | DUST nullifier prefixes (`[HexEncoded!]!`) + optional block range | DustNullifierTransaction (tx/block references) |
| `shieldedNullifierTransactions(nullifierPrefixes!, fromBlock?, toBlock?)` | Shielded (zswap) nullifier prefixes + optional block range | ShieldedNullifierTransaction (tx/block references) |

> **Note:** the two nullifier subscriptions deliberately use different prefix-arg names — `dustNullifierTransactions` takes `nullifierLeBytesPrefixes`, while `shieldedNullifierTransactions` takes `nullifierPrefixes`.

> **`dustGenerations` index range:** `[startIndex, endIndex]` is **inclusive** at the subscription level. Note the off-by-one against the natural source value `Block.dustGenerationEndIndex`, which is **exclusive** — to cover up to a block's end, pass `endIndex: dustGenerationEndIndex - 1`.

### Example: Subscribe to Blocks

```graphql
subscription {
  blocks {
    hash
    height
    timestamp
    transactions {
      hash
    }
  }
}
```

### Example: Subscribe to Shielded Transactions

`shieldedTransactions` emits a `ShieldedTransactionsEvent` union — either a `RelevantTransaction` (a relevant transaction plus an optional collapsed Merkle tree update) or a `ShieldedTransactionsProgress` (indexing progress). Use inline fragments to handle both:

```graphql
subscription {
  shieldedTransactions(sessionId: "session-id-hex") {
    ... on RelevantTransaction {
      transaction {
        hash
        identifiers
      }
      zswapCollapsedUpdate {
        startIndex
        endIndex
        update
      }
    }
    ... on ShieldedTransactionsProgress {
      highestZswapEndIndex
      highestCheckedZswapEndIndex
      highestRelevantZswapEndIndex
    }
  }
}
```

### Example: Subscribe to Contract Actions

```graphql
subscription {
  contractActions(address: "0x...") {
    ... on ContractCall {
      entryPoint
      state
      transaction {
        hash
      }
    }
  }
}
```

> **See also:** `references/pagination-and-offsets.md` — offset-based resumption for each subscription. `examples/websocket-subscriptions.md` — TypeScript examples using graphql-ws.

## Key Types

### ContractAction Interface

All contract actions share these fields:

| Field | Type | Description |
|-------|------|-------------|
| `address` | HexEncoded | Contract address |
| `state` | HexEncoded | Contract state after action |
| `zswapState` | HexEncoded | Zswap state after action |
| `transaction` | Transaction | Parent transaction |
| `unshieldedBalances` | [ContractBalance!]! | Unshielded token balances (`tokenType`, `amount`) |

### ContractAction Variants

| Variant | Additional Fields |
|---------|-------------------|
| `ContractDeploy` | (base fields only) |
| `ContractCall` | `entryPoint: String!` |
| `ContractUpdate` | (base fields only) |

### TransactionResult

`TransactionResult` is an object with a `status` enum and, for partial success, per-segment results.

| Field | Type | Description |
|-------|------|-------------|
| `status` | TransactionResultStatus | Overall outcome (see enum below) |
| `segments` | [Segment!] | Per-segment success flags. **Null unless `status` is `PARTIAL_SUCCESS`** — null-check before iterating |

`TransactionResultStatus` enum values:

| Value | Meaning |
|-------|---------|
| `SUCCESS` | All transaction phases completed successfully |
| `PARTIAL_SUCCESS` | Guaranteed phase succeeded, fallible phase failed |
| `FAILURE` | Transaction failed entirely |

### Transaction fees

The current fee field on a transaction is `fee: String!` (SPECK, the atomic unit of DUST). The older `fees: TransactionFees!` object (with `paidFees`/`estimatedFees`) is deprecated in favour of `fee`; within `TransactionFees`, `estimatedFees` is itself deprecated in favour of `paidFees`.

> **See also:** `references/graphql-types.md` — complete type definitions including Block, Transaction, ContractBalance, RelevantTransaction, and UnshieldedTransaction.

## Cross-References

- `midnight-indexer:indexer-architecture` — Deployment modes and configuration
- `midnight-indexer:indexer-data-model` — What gets indexed and database schema
- `midnight-dapp-dev:midnight-sdk` — DApp provider configuration using indexer endpoints
