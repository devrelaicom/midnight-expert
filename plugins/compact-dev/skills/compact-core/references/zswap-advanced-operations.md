---
title: Zswap Advanced Operations
type: concept
description: Low-level Zswap primitives — createZswapInput and createZswapOutput — for multi-party shielded transactions that go beyond the high-level send/receive API.
links:
  - token-operations
  - coin-lifecycle
  - commitment-and-nullifier-schemes
---

# Zswap Advanced Operations

The high-level token API (`send`, `receive`, `mintToken`) covers most use cases, but Midnight also exposes low-level Zswap primitives for advanced shielded transaction construction. These are used when you need fine-grained control over coin inputs and outputs — typically in multi-party protocols or complex DeFi operations.

## createZswapInput

```compact
createZswapInput(coinInfo)
```

Creates a Zswap transaction input from a coin reference. This marks a coin for spending in the current transaction by creating the necessary nullifier and proof components. The `coinInfo` parameter is a `QualifiedCoinInfo` representing the coin to spend.

Use `createZswapInput` when you need to construct a custom transaction that spends coins without using the high-level `send()` — for example, in atomic swap protocols where inputs and outputs must be precisely matched.

## createZswapOutput

```compact
createZswapOutput(recipient, amount, tokenType)
```

Creates a Zswap transaction output that delivers coins to a recipient. Parameters:
- `recipient` — The target address (wallet public key or contract address)
- `amount` — The number of tokens to send
- `tokenType` — The token color (`Bytes<32>` from `nativeToken()` or `tokenType()`)

This creates a new coin commitment in the shielded pool directed to the recipient, without using the high-level `send()` flow.

## Multi-Party Shielded Transactions

The primary use case for these primitives is constructing multi-party shielded transactions where multiple inputs and outputs must be coordinated atomically:

```compact
// Atomic swap: Alice's token A for Bob's token B
export circuit atomicSwap(
  aliceCoin: QualifiedCoinInfo,
  bobCoin: QualifiedCoinInfo,
  aliceAddr: ZswapCoinPublicKey,
  bobAddr: ZswapCoinPublicKey
): [] {
  // Spend both coins
  createZswapInput(aliceCoin);
  createZswapInput(bobCoin);

  // Create new outputs with swapped recipients
  createZswapOutput(
    left<ZswapCoinPublicKey, ContractAddress>(bobAddr),
    aliceCoin.value,
    aliceCoin.color
  );
  createZswapOutput(
    left<ZswapCoinPublicKey, ContractAddress>(aliceAddr),
    bobCoin.value,
    bobCoin.color
  );
}
```

The transaction is atomic — either all inputs are spent and all outputs are created, or none are. This is enforced by the Zswap protocol's balance constraint: the sum of input values must equal the sum of output values per token type.

## When to Use Low-Level vs High-Level

| Scenario | Use | Why |
|----------|-----|-----|
| Simple transfer | `send()` | Handles change automatically |
| Minting tokens | `mintToken()` | Purpose-built for creation |
| Receiving coins | `receive()` | Standard receive flow |
| Atomic swaps | `createZswapInput/Output` | Need precise input/output control |
| Multi-party protocols | `createZswapInput/Output` | Multiple independent inputs/outputs |
| Custom settlement | `createZswapInput/Output` | Non-standard coin flows |

For most contracts, the high-level API from [[token-operations]] is sufficient and safer — it handles change coins automatically and follows the [[coin-lifecycle]] patterns correctly. Only use the low-level primitives when the high-level API cannot express the required transaction structure.

## Relationship to Commitments

Under the hood, `createZswapOutput` creates a coin commitment that is added to the global Merkle tree. `createZswapInput` creates a nullifier that marks a coin as spent. This is the same [[commitment-and-nullifier-schemes]] mechanism that powers all of Midnight's shielded token operations — the low-level API simply gives you direct access to it.
