# Pagination and Offsets

The indexer GraphQL API uses offset-based addressing to specify starting points for queries and subscriptions. There is no cursor-based pagination; offsets identify a specific block, transaction, or event from which to begin.

## BlockOffset

A `BlockOffset` is a `@oneOf` input object: supply **exactly one** of `hash` or `height`.

| Field | Type | Example |
|-------|------|---------|
| `hash` | HexEncoded | `{ hash: "1a2b3c..." }` |
| `height` | Int | `{ height: 42 }` |

When the argument is omitted, the query or subscription starts from the **latest** block.

```graphql
# By hash
query {
  block(offset: { hash: "1a2b3c4d5e6f..." }) {
    height
    timestamp
  }
}

# By height
query {
  block(offset: { height: 42 }) {
    hash
    timestamp
  }
}

# Omitted — returns latest block
query {
  block {
    hash
    height
  }
}
```

## TransactionOffset

A `TransactionOffset` is a `@oneOf` input object: supply **exactly one** of `hash` or `identifier`.

| Field | Type | Example |
|-------|------|---------|
| `hash` | HexEncoded | `{ hash: "abc123..." }` |
| `identifier` | HexEncoded | `{ identifier: "def456..." }` |

This parameter is **required** for the `transactions` query.

```graphql
# By hash
query {
  transactions(offset: { hash: "abc123..." }) {
    hash
    identifiers
    transactionResult {
      status
    }
  }
}

# By identifier
query {
  transactions(offset: { identifier: "def456..." }) {
    hash
    transactionResult {
      status
    }
  }
}
```

> The `contractAction` query uses `ContractActionOffset`, a `@oneOf` input with either a `blockOffset: BlockOffset` or a `transactionOffset: TransactionOffset` (e.g. `offset: { blockOffset: { height: 10 } }`).

## Subscription Offsets for Resumption

Each subscription accepts an optional offset parameter to resume from a specific point. This is useful for recovering after disconnections without reprocessing events from the beginning.

### blocks

Resume from a specific block height or hash. `offset` is a `BlockOffset` (`@oneOf`):

```graphql
subscription {
  blocks(offset: { height: 1000 }) {
    hash
    height
    timestamp
  }
}
```

### contractActions

Resume from a block offset within a contract's action history. `offset` is a `BlockOffset` (note: the subscription uses `BlockOffset`, not `ContractActionOffset`):

```graphql
subscription {
  contractActions(address: "...", offset: { height: 500 }) {
    ... on ContractCall {
      entryPoint
      transaction { hash }
    }
  }
}
```

### shieldedTransactions

Resume from a zswap transaction `index` (`Int`) within the wallet session. The subscription emits a `ShieldedTransactionsEvent` union — use inline fragments:

```graphql
subscription {
  shieldedTransactions(sessionId: "session-id-hex", index: 50) {
    ... on RelevantTransaction {
      transaction { hash }
    }
    ... on ShieldedTransactionsProgress {
      highestZswapEndIndex
      highestRelevantZswapEndIndex
    }
  }
}
```

### unshieldedTransactions

Resume from a specific transaction ID (`Int`, the indexer-internal BIGSERIAL). The subscription emits an `UnshieldedTransactionsEvent` union:

```graphql
subscription {
  unshieldedTransactions(address: "mn_addr_test1...", transactionId: 1234) {
    ... on UnshieldedTransaction {
      transaction { hash }
      createdUtxos { tokenType value }
      spentUtxos { tokenType value }
    }
    ... on UnshieldedTransactionsProgress {
      highestTransactionId
    }
  }
}
```

### dustLedgerEvents and zswapLedgerEvents

Resume from a specific event `id` (`Int`):

```graphql
subscription {
  dustLedgerEvents(id: 123) {
    id
    raw
    maxId
    protocolVersion
  }
}

subscription {
  zswapLedgerEvents(id: 456) {
    id
    raw
    maxId
    protocolVersion
  }
}
```
