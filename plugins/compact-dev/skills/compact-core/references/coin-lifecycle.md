---
title: Coin Lifecycle
type: concept
description: The UTXO-style lifecycle of coins in Midnight — from CoinInfo at minting through QualifiedCoinInfo for spending to SendResult with mandatory change handling.
links:
  - token-operations
  - send-result-change-handling
  - type-system
  - compact-to-typescript-types
  - standard-library-functions
  - maybe-and-either-types
  - immediate-vs-deferred-operations
---

# Coin Lifecycle

Midnight uses a UTXO-style model for shielded tokens. Each coin goes through a lifecycle: creation (mint), qualification (Merkle tree allocation), spending (send), and optionally change creation. Understanding the three key structs — `CoinInfo`, `QualifiedCoinInfo`, and `SendResult` — is essential for writing correct [[token-operations]].

## CoinInfo — Newly Minted Coin

`CoinInfo` represents a coin that has just been created by `mintToken()`:

```compact
struct CoinInfo {
  value: Uint<128>;
  color: Bytes<32>;
  nonce: Bytes<32>;
}
```

- `value`: The amount of tokens in this coin
- `color`: The token type identifier (from `nativeToken()` or `tokenType()`)
- `nonce`: The unique identifier used during minting

A `CoinInfo` is returned by `mintToken()`. It can be converted to a `QualifiedCoinInfo` by storing it in a ledger Cell with `writeCoin()`, which allocates a Merkle tree index for it.

## QualifiedCoinInfo — Spendable Coin

`QualifiedCoinInfo` extends `CoinInfo` with a Merkle tree leaf index, making it spendable:

```compact
struct QualifiedCoinInfo {
  value: Uint<128>;
  color: Bytes<32>;
  nonce: Bytes<32>;
  leafIndex: Field;  // Position in the Zswap Merkle tree
}
```

This is the type required by `send()` — you can only spend qualified coins. The qualification happens when a coin is written to a ledger field via `writeCoin()`.

## SendResult — Spending Output

`send()` returns a `SendResult` containing the output of the spend:

```compact
struct SendResult {
  sent: CoinInfo;
  change: CoinInfo;
}
```

- `sent`: The coin that was delivered to the recipient
- `change`: The remaining value returned to the sender

**Critical**: The `change` must always be handled. If you ignore it, the change value is permanently lost. This is covered in detail in [[send-result-change-handling]].

## Lifecycle Flow

```
mintToken() → CoinInfo → writeCoin() → QualifiedCoinInfo → send() → SendResult
                                                                      ├── sent: CoinInfo
                                                                      └── change: CoinInfo → writeCoin() → QualifiedCoinInfo
```

1. **Mint**: `mintToken()` creates a `CoinInfo`
2. **Qualify**: `ledgerField.writeCoin(coin, recipient)` produces a `QualifiedCoinInfo` in the ledger
3. **Spend**: `send(qualifiedCoin, recipient, amount)` produces a `SendResult`
4. **Handle change**: `vault.writeCoin(result.change, self)` stores the change for future spending

Both `send` and `mergeCoin` have immediate variants (`sendImmediate`, `mergeCoinImmediate`) that complete within the transaction rather than at finalization — see [[immediate-vs-deferred-operations]] for when to use each.

## Partial Spending

When you send less than a coin's full value, the remainder becomes the `change` in `SendResult`. For example, sending 30 from a coin of value 100 produces:
- `sent.value` = 30 (delivered to recipient)
- `change.value` = 70 (returned to sender)

If you send the coin's exact value, `change.value` is 0. Even zero-value change should be handled per [[send-result-change-handling]] to avoid unexpected behavior.

## TypeScript Representation

In the DApp code, these types map to TypeScript interfaces as described in [[compact-to-typescript-types]]:

```typescript
interface CoinInfo {
  value: bigint;
  color: Uint8Array;
  nonce: Uint8Array;
}

interface QualifiedCoinInfo extends CoinInfo {
  leafIndex: bigint;
}

interface SendResult {
  sent: CoinInfo;
  change: CoinInfo;
}
```

The `Maybe<CoinInfo>` type from [[maybe-and-either-types]] is frequently used in witness functions when a coin may or may not be available for spending.
