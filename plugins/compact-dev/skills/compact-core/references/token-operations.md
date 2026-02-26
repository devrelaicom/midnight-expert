---
title: Token Operations
type: concept
description: Minting, sending, and receiving shielded tokens via Midnight's Zswap protocol — including custom token types, nonce management, and recipient addressing.
links:
  - coin-lifecycle
  - standard-library-functions
  - type-system
  - circuit-declarations
  - export-and-visibility
  - maybe-and-either-types
  - send-result-change-handling
  - commitment-and-nullifier-schemes
  - fungible-token-template
  - immediate-vs-deferred-operations
  - zswap-advanced-operations
---

# Token Operations

Midnight supports shielded fungible tokens through the Zswap protocol. All token operations happen in the shielded pool — coins are never publicly visible. The protocol supports a native token (NIGHT) and custom tokens created by contracts.

## Token Types

Every coin has a "color" — a `Bytes<32>` identifier that distinguishes one token from another:

```compact
// Get the native NIGHT token type
circuit getNightColor(): Bytes<32> {
  return nativeToken();
}

// Create a custom token type for this contract
circuit getGoldColor(): Bytes<32> {
  return tokenType(pad(32, "myapp:GOLD"), kernel.self());
}
```

`nativeToken()` returns the NIGHT token's color. `tokenType(domainSep, contract)` computes a custom color by hashing a domain separator with a contract address. A contract can define multiple token types by using different domain separators. The domain separator should be a stable string — changing it creates a different token type, breaking compatibility.

## Minting

`mintToken()` creates new shielded coins and sends them directly to a recipient:

```compact
export circuit mintGold(
  recipient: ZswapCoinPublicKey,
  amount: Uint<128>,
  nonce: Bytes<32>
): CoinInfo {
  return mintToken(
    pad(32, "myapp:GOLD"),
    amount,
    nonce,
    left<ZswapCoinPublicKey, ContractAddress>(recipient)
  );
}
```

Key rules:
- Only contracts can mint their own custom tokens (bound to `kernel.self()`)
- Nobody can mint NIGHT — only the protocol creates it
- The nonce must be unique per mint call — reusing a nonce creates duplicate coin commitments
- The recipient is `Either<ZswapCoinPublicKey, ContractAddress>` — use `left()` for wallet addresses, `right()` for contracts (see [[maybe-and-either-types]] for Either construction)
- The returned `CoinInfo` describes the new coin as detailed in [[coin-lifecycle]]

## Sending

`send()` transfers an existing coin (or part of it) to a new recipient:

```compact
export circuit transferGold(
  input: QualifiedCoinInfo,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  amount: Uint<128>
): SendResult {
  return send(input, recipient, amount);
}
```

The `input` is a `QualifiedCoinInfo` representing the coin being spent. The function returns a `SendResult` containing both the sent coin and any change — handling this change is mandatory as explained in [[send-result-change-handling]]. Note that `send()` is a deferred operation; for cases where subsequent circuit logic depends on the transfer completing, use `sendImmediate()` as described in [[immediate-vs-deferred-operations]].

## Receiving

Contracts receive coins when they are the recipient of a `mintToken()` or `send()` call. The coin arrives as a `QualifiedCoinInfo` that can be stored in a ledger Cell:

```compact
export ledger vault: QualifiedCoinInfo;

export circuit receiveCoin(coin: QualifiedCoinInfo): [] {
  vault.writeCoin(coin, right<ZswapCoinPublicKey, ContractAddress>(kernel.self()));
}
```

The `writeCoin()` operation is special — it's the only way to store a `QualifiedCoinInfo` in the ledger, and it requires specifying the recipient (usually the contract itself via `kernel.self()`).

## Nonce Management

Every mint and coin operation requires a unique nonce. The `evolveNonce()` function from [[standard-library-functions]] derives deterministic nonces from a seed:

```compact
witness getInitialNonce(): Bytes<32>;

export circuit batchMint(recipients: Vector<3, ZswapCoinPublicKey>): [] {
  let nonce = getInitialNonce();
  for (let i: Uint<0..2> = 0; i < 3; i++) {
    mintToken(pad(32, "myapp:GOLD"), 100, nonce,
      left<ZswapCoinPublicKey, ContractAddress>(recipients[i]));
    nonce = evolveNonce(nonce);
  }
}
```

For advanced multi-party shielded transactions that go beyond the standard send/receive flow, the [[zswap-advanced-operations]] provide low-level `createZswapInput` and `createZswapOutput` primitives.

The complete token contract pattern is provided in [[fungible-token-template]].
