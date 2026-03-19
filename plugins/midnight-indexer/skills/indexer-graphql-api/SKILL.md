---
name: indexer-graphql-api
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
| `spoIdentities` | none | SPO identity records |
| `spoByPoolId` | Pool ID | SPO details |
| `spoCompositeByPoolId` | Pool ID | Composite SPO data |
| `stakeDistribution` | none | Stake distribution data |

### Example: Query Latest Block

```graphql
query {
  block {
    hash
    height
    timestamp
    transactions {
      hash
      identifier
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
        value
      }
    }
  }
}
```

> **See also:** `references/pagination-and-offsets.md` — BlockOffset and TransactionOffset types. `examples/http-requests.md` — full curl examples for queries.

## Mutations

| Mutation | Parameters | Returns | Purpose |
|---------|-----------|---------|---------|
| `connect(viewingKey!)` | Bech32m or hex-encoded viewing key | Session ID | Establish wallet session for shielded transaction scanning |
| `disconnect(sessionId!)` | Session ID from `connect` | Confirmation | End wallet session |

### Example: Wallet Connection

```graphql
# Connect wallet
mutation {
  connect(viewingKey: "bech32m_encoded_key_here")
}

# Disconnect wallet
mutation {
  disconnect(sessionId: "session-uuid-here")
}
```

> **See also:** `examples/http-requests.md` — curl examples for connect and disconnect mutations. `references/error-handling.md` — invalid session ID errors.

## Subscriptions

The indexer provides 6 subscriptions for real-time event streaming over WebSocket.

| Subscription | Parameters | Emits |
|-------------|-----------|-------|
| `blocks(offset?)` | Start block (hash or height) | Block objects |
| `contractActions(address!, offset?)` | Contract address + optional start offset | ContractDeploy, ContractCall, or ContractUpdate |
| `shieldedTransactions(sessionId!, index?)` | Session ID from `connect` mutation | RelevantTransaction + sync progress |
| `unshieldedTransactions(address!, transactionId?)` | Bech32m address, optional resume point | UnshieldedTransaction + sync progress |
| `dustLedgerEvents(id?)` | Optional event ID to resume from | DUST ledger events |
| `zswapLedgerEvents(id?)` | Optional event ID to resume from | Zswap ledger events |

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

```graphql
subscription {
  shieldedTransactions(sessionId: "session-uuid") {
    transaction {
      hash
      identifier
    }
    progress {
      current
      total
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
| `address` | String | Contract address |
| `state` | String | Contract state after action |
| `zswapState` | String | Zswap state after action |
| `transaction` | Transaction | Parent transaction |
| `unshieldedBalances` | [TokenBalance] | Unshielded token balances |

### ContractAction Variants

| Variant | Additional Fields |
|---------|-------------------|
| `ContractDeploy` | (base fields only) |
| `ContractCall` | `entryPoint: String` |
| `ContractUpdate` | (base fields only) |

### TransactionResult

| Value | Meaning |
|-------|---------|
| `SUCCESS` | All transaction phases completed successfully |
| `PARTIAL_SUCCESS` | Guaranteed phase succeeded, fallible phase failed |
| `FAILURE` | Transaction failed entirely |

### TransactionFees

| Field | Description |
|-------|-------------|
| `paidFees` | Actual fees paid |
| `estimatedFees` | Fees estimated before submission |

> **See also:** `references/graphql-types.md` — complete type definitions including Block, Transaction, TokenBalance, RelevantTransaction, UnshieldedTransaction, and SyncProgress.

## Cross-References

- `midnight-indexer:indexer-architecture` — Deployment modes and configuration
- `midnight-indexer:indexer-data-model` — What gets indexed and database schema
- `compact-core:compact-deployment` — DApp provider configuration using indexer endpoints
