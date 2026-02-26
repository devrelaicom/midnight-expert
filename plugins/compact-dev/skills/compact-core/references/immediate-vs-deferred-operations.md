---
title: Immediate vs Deferred Operations
type: concept
description: The distinction between deferred token operations (complete at transaction finalization) and immediate variants (complete within the transaction) — affecting when subsequent circuit logic can use results.
links:
  - token-operations
  - coin-lifecycle
  - send-result-change-handling
---

# Immediate vs Deferred Operations

Midnight's token system provides two variants of key coin operations: **deferred** (the default) and **immediate**. The distinction determines when the operation takes effect within the transaction lifecycle, which matters when subsequent circuit logic depends on the result.

## Deferred Operations (Default)

Deferred operations are queued and complete when the transaction is finalized — not during circuit execution:

```compact
// Deferred send — transfer completes at tx finalization
send(input, recipient, amount);

// Deferred merge — coin merge completes at tx finalization
mergeCoin(coinInfo);
```

With `send()`, the actual transfer of value happens after the circuit finishes executing. This means you **cannot** rely on the recipient having received the coins within the same circuit execution. The `SendResult` is still returned immediately (describing what will happen), but the underlying coin state changes are deferred.

## Immediate Operations

Immediate operations complete within the same transaction, allowing subsequent circuit logic to depend on the result:

```compact
// Immediate send — transfer completes within this transaction
sendImmediate(input, recipient, amount);

// Immediate merge — coin merge completes within this transaction
mergeCoinImmediate(coinInfo);
```

With `sendImmediate()`, the coin transfer is executed immediately. This is necessary when subsequent operations in the same circuit need to work with the post-transfer state — for example, when sending coins and then immediately operating on the recipient's updated balance within the same transaction.

## When to Use Each

### Use Deferred (Default) When

- The circuit does not need to observe the result of the operation
- You are performing a simple transfer at the end of a circuit
- Performance matters — deferred operations can be more efficiently batched

### Use Immediate When

- Subsequent circuit logic depends on the operation completing
- You need to chain multiple operations where each depends on the previous result
- You are performing a multi-step token flow within a single circuit

## Comparison Table

| Operation | Deferred | Immediate |
|-----------|----------|-----------|
| Send | `send(input, recipient, amount)` | `sendImmediate(input, recipient, amount)` |
| Merge coin | `mergeCoin(coinInfo)` | `mergeCoinImmediate(coinInfo)` |
| Completion | At tx finalization | Within the transaction |
| Subsequent logic | Cannot depend on result | Can depend on result |

## Practical Example

```compact
// WRONG: using deferred send then trying to use the result immediately
export circuit transferAndVerify(input: QualifiedCoinInfo, to: ZswapCoinPublicKey): [] {
  send(input, left<ZswapCoinPublicKey, ContractAddress>(to), 100);
  // Cannot reliably check post-send state here — send is deferred
}

// RIGHT: using immediate send when subsequent logic depends on the transfer
export circuit transferAndVerify(input: QualifiedCoinInfo, to: ZswapCoinPublicKey): [] {
  sendImmediate(input, left<ZswapCoinPublicKey, ContractAddress>(to), 100);
  // Post-send state is now available for subsequent logic
}
```

Both deferred and immediate variants return `SendResult`, and the change from either variant must be handled as described in [[send-result-change-handling]]. The lifecycle of the coins involved follows the same stages described in [[coin-lifecycle]] — the difference is only in timing within the transaction.
