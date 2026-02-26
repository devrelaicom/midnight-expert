---
title: Transient vs Persistent Operations
type: concept
description: The critical safety distinction — transient hash/commit functions break witness tracking (safe for privacy); persistent ones do NOT (unsafe for privacy on witness data).
links:
  - disclosure-model
  - witness-value-tracking
  - persistent-hash-is-not-safe
  - commitment-and-nullifier-schemes
  - standard-library-functions
  - merkle-trees
  - anonymous-membership-proof
---

# Transient vs Persistent Operations

This is the single most critical safety concept in Compact. The standard library provides two families of hash and commit functions — **transient** and **persistent** — and choosing the wrong one leaks private data. The distinction is explained by how the compiler's [[witness-value-tracking]] system treats their outputs.

## The Core Distinction

| Function | Output Type | Removes Witness Taint? | Safe for Private Data? |
|----------|------------|----------------------|----------------------|
| `transientHash<T>(v)` | `Field` | YES | YES |
| `transientCommit<T>(v)` | `Field` | YES | YES |
| `persistentHash<T>(v)` | `Bytes<32>` | NO | NO (on witness data) |
| `persistentCommit<T>(v)` | `Bytes<32>` | NO | NO (on witness data) |

**Transient** operations produce a hash/commitment that cannot be linked back to the input by an observer. The compiler considers the output as "clean" — no longer witness-tainted. This makes it safe to store the result on-chain without revealing the input.

**Persistent** operations produce a deterministic hash/commitment. Given the same input, the output is always the same. This means anyone who can guess the input can verify their guess against the on-chain output — breaking privacy. The compiler does NOT remove witness taint from persistent outputs, which is why the [[persistent-hash-is-not-safe]] gotcha exists.

## Why Persistent Hash is Dangerous

Consider a vote commitment:

```compact
// DANGEROUS: persistent hash on private vote
witness getVote(): Field;
export circuit commitVote(): [] {
  const vote = getVote();
  const h = persistentHash<Field>(vote);
  commitment = disclose(h);  // Compiles (you forced disclosure), but INSECURE
}
```

An attacker can compute `persistentHash(0)`, `persistentHash(1)`, etc. and compare against the stored commitment. Since the vote is a small domain (e.g., 0 or 1), the hash provides no privacy. The `disclose()` wrapper silences the compiler, but the developer has bypassed the safety system.

## The Safe Alternative

```compact
// SAFE: transient commit on private vote
witness getVote(): Field;
export circuit commitVote(): [] {
  const vote = getVote();
  const c = transientCommit<Field>(vote);
  commitment = c;  // No disclose() needed — taint is removed by transientCommit
}
```

The transient commit produces a value that cannot be reverse-engineered. The compiler recognizes it as safe and removes the witness taint, so no `disclose()` is required. This is both more secure and more ergonomic.

## When to Use Each

**Use transient** when:
- The input is private witness data that must not be revealed
- You are building [[commitment-and-nullifier-schemes]]
- You need to store a commitment in a [[merkle-trees]] for later proof
- You are implementing the [[anonymous-membership-proof]] pattern

**Use persistent** when:
- The input is already public (e.g., computing a key from public ledger data)
- You need a deterministic identifier (e.g., token type computation)
- The hash is used for content-addressing, not privacy
- The input is derived entirely from non-witness sources

## Compact's Safety Net

The compiler's [[witness-value-tracking]] works as a safety net here. Because `persistentHash` does NOT remove witness taint, attempting to store its output in the ledger without `disclose()` triggers a compiler error. The only way to leak data is to explicitly override the safety with `disclose()` — the compiler cannot be blamed for explicit disclosure. However, the [[disclosure-compiler-error]] message will help identify when you're about to disclose a persistent hash of witness data, which should prompt a reconsideration of the approach.

## Domain Conversion Functions

Compact also provides conversion functions between the transient and persistent domains:

| Function | Signature | Purpose |
|----------|-----------|---------|
| `degradeToTransient(v)` | `Bytes<32> → Field` | Converts a persistent value to transient domain |
| `upgradeFromTransient(v)` | `Field → Bytes<32>` | Converts a transient value to persistent domain |

`degradeToTransient()` takes a persistent `Bytes<32>` value and converts it to a `Field` in the transient domain. The term "degrade" reflects that the operation moves from the deterministic (persistent) world to the non-deterministic (transient) world. `upgradeFromTransient()` does the reverse, moving a transient `Field` into the persistent `Bytes<32>` representation.

These functions are useful when integrating code that produces values in one domain with APIs that expect the other — for example, when a persistent hash result needs to be used in a context that expects a transient Field, or when building hybrid commitment schemes.

## Return Type Difference

Note the return type difference from the [[standard-library-functions]]:
- Transient operations return `Field`
- Persistent operations return `Bytes<32>`

This type difference is a deliberate design choice that makes it harder to accidentally swap them — the type system forces awareness of which variant is being used.
