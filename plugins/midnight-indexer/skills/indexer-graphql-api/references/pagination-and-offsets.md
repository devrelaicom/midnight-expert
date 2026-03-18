# Pagination and Offsets

The indexer GraphQL API uses offset-based addressing to specify starting points for queries and subscriptions. There is no cursor-based pagination; offsets identify a specific block, transaction, or event from which to begin.

## BlockOffset

A `BlockOffset` identifies a specific block. It accepts either form:

| Form | Type | Example |
|------|------|---------|
| Block hash | Hex string | `"0x1a2b3c..."` |
| Block height | Integer | `42` |

When omitted, the query or subscription starts from the **latest** block.

```graphql
# By hash
query {
  block(offset: "0x1a2b3c4d5e6f...") {
    height
    timestamp
  }
}

# By height
query {
  block(offset: 42) {
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

A `TransactionOffset` identifies a specific transaction. It accepts either form:

| Form | Type | Example |
|------|------|---------|
| Transaction hash | Hex string | `"0xabc123..."` |
| Transaction identifier | String | `"tx-identifier-string"` |

This parameter is **required** for the `transactions` query.

```graphql
# By hash
query {
  transactions(offset: "0xabc123...") {
    hash
    identifier
    result
  }
}

# By identifier
query {
  transactions(offset: "my-tx-identifier") {
    hash
    result
  }
}
```

## Subscription Offsets for Resumption

Each subscription accepts an optional offset parameter to resume from a specific point. This is useful for recovering after disconnections without reprocessing events from the beginning.

### blocks

Resume from a specific block height or hash:

```graphql
subscription {
  blocks(offset: 1000) {
    hash
    height
    timestamp
  }
}
```

### contractActions

Resume from a block offset within a contract's action history:

```graphql
subscription {
  contractActions(address: "0x...", offset: 500) {
    ... on ContractCall {
      entryPoint
      transaction { hash }
    }
  }
}
```

### shieldedTransactions

Resume from a transaction index within the wallet session:

```graphql
subscription {
  shieldedTransactions(sessionId: "session-uuid", index: 50) {
    transaction { hash }
    progress { current total }
  }
}
```

### unshieldedTransactions

Resume from a specific transaction ID:

```graphql
subscription {
  unshieldedTransactions(address: "addr1...", transactionId: "0xtx-hash") {
    transaction { hash }
    progress { current total }
  }
}
```

### dustLedgerEvents and zswapLedgerEvents

Resume from a specific event ID:

```graphql
subscription {
  dustLedgerEvents(id: "event-id-123") {
    # event fields
  }
}

subscription {
  zswapLedgerEvents(id: "event-id-456") {
    # event fields
  }
}
```
