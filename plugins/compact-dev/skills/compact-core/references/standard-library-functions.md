---
title: Standard Library Functions
type: concept
description: The CompactStandardLibrary provides hashing, commitments, elliptic curve operations, Merkle tree functions, coin operations, and block time queries.
links:
  - pragma-and-imports
  - transient-vs-persistent
  - maybe-and-either-types
  - merkle-trees
  - token-operations
  - commitment-and-nullifier-schemes
  - type-system
  - bounded-computation
  - immediate-vs-deferred-operations
  - zswap-advanced-operations
  - list-adt
---

# Standard Library Functions

The Compact Standard Library is imported with `import CompactStandardLibrary;` as described in [[pragma-and-imports]]. It provides all cryptographic primitives, utility types, and blockchain operations needed for contract development.

## Hashing Functions

The library provides two families of hash functions, differentiated by [[transient-vs-persistent]]:

| Function | Signature | Privacy Safe? |
|----------|-----------|--------------|
| `persistentHash<T>(v)` | `T → Bytes<32>` | No (deterministic) |
| `transientHash<T>(v)` | `T → Field` | Yes (breaks tracking) |
| `persistentCommit<T>(v)` | `T → Bytes<32>` | No (deterministic) |
| `transientCommit<T>(v)` | `T → Field` | Yes (breaks tracking) |
| `degradeToTransient(v)` | `Bytes<32> → Field` | Converts persistent to transient domain |
| `upgradeFromTransient(v)` | `Field → Bytes<32>` | Converts transient to persistent domain |

The type parameter `T` must be specified explicitly: `persistentHash<Field>(x)`, `transientCommit<Vector<2, Bytes<32>>>(v)`. Both hash and commit functions accept any Compact type.

**Hash vs Commit**: Hash functions produce a raw hash. Commit functions produce a commitment that includes blinding factors. For [[commitment-and-nullifier-schemes]], always prefer commit functions.

## Merkle Tree Functions

These functions work with the MerkleTree and HistoricMerkleTree ADTs from [[merkle-trees]]:

| Function | Purpose |
|----------|---------|
| `merkleTreeDigest(tree)` | Current root hash of a MerkleTree |
| `historicMerkleTreeDigest(tree, index)` | Root hash at a past state |
| `merklePathRoot<#n>(path, index, leaf)` | Compute root from a Merkle path |

`merklePathRoot` is the key function for membership proofs: given a path (sibling hashes), a leaf index, and a leaf value, it computes what the root would be. Comparing this against `merkleTreeDigest()` proves membership.

## Elliptic Curve Operations

| Function | Purpose |
|----------|---------|
| `ownPublicKey()` | Returns the caller's ZswapCoinPublicKey |
| `publicKey(round, sk)` | Derives a public key from a round counter and secret key |
| `ecAdd(p1, p2)` | Elliptic curve point addition |
| `ecMul(p, scalar)` | Elliptic curve scalar multiplication |

`ownPublicKey()` returns the ZK-verified public key of the transaction sender — this is more trustworthy than a witness-provided identity because it's proven by the Zswap protocol rather than claimed by the DApp.

## Coin Operations

These functions support the [[token-operations]] and [[coin-lifecycle]]:

| Function | Purpose |
|----------|---------|
| `nativeToken()` | Returns the NIGHT token color |
| `tokenType(domainSep, contract)` | Computes a custom token color |
| `mintToken(domainSep, value, nonce, recipient)` | Creates new shielded coins |
| `send(coin, recipient, amount)` | Transfers coins (deferred) |
| `sendImmediate(coin, recipient, amount)` | Transfers coins (immediate — see [[immediate-vs-deferred-operations]]) |
| `mergeCoin(coinInfo)` | Merges coins of the same type (deferred) |
| `mergeCoinImmediate(coinInfo)` | Merges coins of the same type (immediate — see [[immediate-vs-deferred-operations]]) |
| `createZswapInput(coinInfo)` | Creates a Zswap transaction input (see [[zswap-advanced-operations]]) |
| `createZswapOutput(recipient, amount, tokenType)` | Creates a Zswap transaction output (see [[zswap-advanced-operations]]) |
| `evolveNonce(nonce)` | Derives a new nonce from an existing one |
| `pad(n, string)` | Pads a string to n bytes |

`evolveNonce()` is essential for creating multiple unique nonces from a single seed, which is required when minting multiple coins in a single circuit.

## Block Time Functions

| Function | Purpose |
|----------|---------|
| `blockTimeGte(timestamp)` | Asserts current block time ≥ timestamp |
| `blockTimeLte(timestamp)` | Asserts current block time ≤ timestamp |
| `blockTimeBetween(start, end)` | Asserts current block time in range |

These are the only way to reference time in circuits (direct time access would violate the determinism required by [[bounded-computation]]). They assert constraints rather than returning values — the proof is invalid if the time condition is not met when the transaction is included in a block.

## Utility Functions

| Function | Purpose |
|----------|---------|
| `default<T>()` | Returns the default value of type T |
| `disclose(value)` | Marks a value as intentionally public |
| `kernel.self()` | Returns the current contract's address |
| `some<T>(value)` | Constructs a present Maybe (see [[maybe-and-either-types]]) |
| `none<T>()` | Constructs an absent Maybe |
| `left<A, B>(value)` | Constructs a left Either variant |
| `right<A, B>(value)` | Constructs a right Either variant |
