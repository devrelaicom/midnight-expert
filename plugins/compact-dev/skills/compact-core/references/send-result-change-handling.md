---
title: "Gotcha: SendResult Change Handling"
type: gotcha
description: When sending tokens via send(), the returned SendResult contains a change field that MUST be stored — ignoring it permanently destroys the remaining tokens.
links:
  - token-operations
  - coin-lifecycle
  - fungible-token-template
  - standard-library-functions
  - circuit-declarations
---

# Gotcha: SendResult Change Handling

When you call `send()` to transfer tokens as described in [[token-operations]], the function returns a `SendResult` containing two fields: `sent` (the coins delivered to the recipient) and `change` (the remaining coins returned to the sender). **Ignoring the `change` field permanently destroys the remaining tokens.**

## The Problem

```compact
export circuit transferTokens(
  coin: QualifiedCoinInfo,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  amount: Uint<128>
): [] {
  const result = send(coin, recipient, amount);
  // BUG: result.change is ignored — remaining tokens are LOST FOREVER
}
```

If the input coin has value 100 and you send 30, the `result.change` contains a CoinInfo with value 70. If you don't write it back to a ledger field, those 70 tokens are permanently burned — there is no way to recover them.

## The Fix

Always write the change back to a ledger field:

```compact
export ledger vault: QualifiedCoinInfo;

export circuit transferTokens(
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  amount: Uint<128>
): [] {
  const result = send(vault, recipient, amount);

  // CRITICAL: Store the change for future spending
  vault.writeCoin(result.change,
    right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
}
```

The `writeCoin()` operation converts the `CoinInfo` (from the change) into a `QualifiedCoinInfo` (with a Merkle tree index) and stores it in the ledger. This makes the remaining tokens spendable in future transactions.

## Why This Happens

Midnight uses a UTXO-style model as described in [[coin-lifecycle]]. A coin is an indivisible unit — you can't "partially spend" it. Instead, `send()` consumes the entire coin and creates two new coins: one for the recipient and one for change. This is exactly like paying with a $100 bill for a $30 item — you get $70 in change, and if you walk away without taking it, it's gone.

## Even Zero Change Matters

When you send the coin's exact value (change = 0), you should still handle the change for defensive programming:

```compact
const result = send(vault, recipient, coin.value);
vault.writeCoin(result.change,
  right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
```

This avoids bugs if the amount calculation is ever modified to send less than the full value.

## The Full Pattern

The [[fungible-token-template]] demonstrates the complete send-with-change pattern. Every `send()` call in the template is followed by a `writeCoin()` for the change. This pattern should be treated as mandatory — there is no valid reason to ignore the change from a `send()` unless you intentionally want to burn tokens (which should be documented explicitly in the [[circuit-declarations]] with a comment).

## Testing for This Bug

The Midnight MCP's static analysis can flag potential missing change handling. When reviewing contracts, check every `send()` call site and verify the `result.change` is stored. This is one of the easiest auditing checks and one of the most costly bugs to miss.
