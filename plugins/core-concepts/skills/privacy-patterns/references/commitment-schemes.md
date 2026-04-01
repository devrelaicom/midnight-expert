# Commitment Schemes

Detailed reference for Compact's commitment primitives, their cryptographic properties, and correct usage patterns.

## What Commitments Do in Compact

Compact provides **hash-based commitments**, not algebraic Pedersen commitments. The `persistentCommit<T>(value, rand)` function computes a cryptographic hash over the value and a blinding factor (randomness). The result is a fixed-size digest that hides the input while binding the committer to the value.

**Important distinction**: The Pedersen commitment scheme (`v*G + r*H`) is used internally by Zswap for balance proofs -- a separate mechanism at the protocol level. Compact's `persistentCommit` and `transientCommit` are hash-based and operate at the smart contract level.

## Cryptographic Properties

### Hiding

Given a commitment `c = persistentCommit<T>(value, rand)`, an observer who sees `c` cannot determine `value` without knowing `rand`. This requires that `rand` has sufficient entropy -- at least 128 bits of randomness for computational hiding.

### Binding

Once a commitment `c` is published, the committer cannot find a different `(value', rand')` pair that produces the same `c`. This prevents changing the committed value after the fact.

### Relationship to Witness Taint

Commitment functions **clear witness taint** on their inputs and on the commitment result. The compiler considers both the input and the output of `persistentCommit` as clean — neither requires `disclose()` downstream.

- Hash functions (`persistentHash`, `transientHash`) do **not** clear witness taint because hash outputs could theoretically be brute-forced.

## Function Reference

### persistentCommit

```text
persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32>
```

- Uses SHA-256 internally
- Output is stable across compiler versions -- safe to store in ledger state
- `T` can be any serializable type (not just `Bytes<32>`)
- Clears witness taint on the input

### transientCommit

```text
transientCommit<T>(value: T, rand: Field): Field
```

- Circuit-optimized algorithm
- **Algorithm may change between compiler versions** -- outputs must not be stored in ledger state
- Note: randomness argument is `Field`, not `Bytes<32>`
- Clears witness taint on the input
- Use only for in-circuit intermediates that do not persist

### persistentHash (not a commitment)

```text
persistentHash<T>(value: T): Bytes<32>
```

- Uses SHA-256 internally
- No blinding factor -- not hiding
- Does **not** clear witness taint
- Use for public key derivation, nullifiers, domain-separated identifiers
- Accepts any serializable type `T`

### transientHash (not a commitment)

```text
transientHash<T>(value: T): Field
```

- Circuit-optimized, algorithm may change between compiler versions
- No blinding factor -- not hiding
- Does **not** clear witness taint
- Use only for in-circuit consistency checks

## Commit-Reveal Pattern

The standard commit-reveal pattern uses two phases: a commit phase where the value is hidden behind a commitment, and a reveal phase where the value and randomness are disclosed so observers can verify the commitment was honest.

The contract uses an `enum Phase { commit, reveal, finalized }` to enforce ordering, and a `Map<Bytes<32>, Bytes<32>>` to store commitments keyed by participant public key.

**Commit phase:** Each participant derives their public key via `persistentHash` (which does not clear witness taint, so `disclose()` is needed when using the key as a Map argument), obtains fresh randomness from a witness, and computes a commitment via `persistentCommit<Field>(value, salt)`. The commitment result is clean (taint cleared by `persistentCommit`), so no `disclose()` is needed when inserting the commitment value. The opening (salt and value) is stored off-chain via a witness function.

**Reveal phase:** The participant retrieves their stored opening from a witness, recomputes the commitment, and asserts it matches the on-chain value looked up via `Map.lookup(disclose(pk))`. The public key requires `disclose()` for Map operations. On success, the revealed value is returned with `disclose()` (required when returning witness data from an exported circuit).

## Salt / Randomness Management

### Rules

1. **Always source randomness from a witness function.** The randomness must come from the off-chain environment where cryptographically secure random number generation is available.

2. **Never reuse salts.** If the same value is committed with the same salt, the commitment outputs are identical, which breaks hiding (an observer can tell two commitments hide the same value).

3. **Store openings off-chain.** The value and salt needed to reveal a commitment must be stored securely by the witness implementation. The contract only stores the commitment hash on-chain.

### Witness Pattern for Randomness

Randomness is sourced via a witness function declared as `witness get_randomness(): Bytes<32>`. The TypeScript implementation should use `crypto.getRandomValues()` or equivalent to produce 32 bytes of cryptographically secure randomness for each call.

**Do not** use `generateRandomness()` or `generateSecureRandom()` -- these functions do not exist in Compact. Randomness must come from a witness.

## Concurrent Security

Each participant in a multi-party protocol must use their own salt/secret. If two participants share a salt and commit the same value, their commitments will be identical, breaking the hiding property. Always source randomness per-participant from witness functions.
