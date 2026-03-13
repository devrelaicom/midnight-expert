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

```
persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32>
```

- Uses SHA-256 internally
- Output is stable across compiler versions -- safe to store in ledger state
- `T` can be any serializable type (not just `Bytes<32>`)
- Clears witness taint on the input

### transientCommit

```
transientCommit<T>(value: T, rand: Field): Field
```

- Circuit-optimized algorithm
- **Algorithm may change between compiler versions** -- outputs must not be stored in ledger state
- Note: randomness argument is `Field`, not `Bytes<32>`
- Clears witness taint on the input
- Use only for in-circuit intermediates that do not persist

### persistentHash (not a commitment)

```
persistentHash<T>(value: T): Bytes<32>
```

- Uses SHA-256 internally
- No blinding factor -- not hiding
- Does **not** clear witness taint
- Use for public key derivation, nullifiers, domain-separated identifiers
- Accepts any serializable type `T`

### transientHash (not a commitment)

```
transientHash<T>(value: T): Field
```

- Circuit-optimized, algorithm may change between compiler versions
- No blinding factor -- not hiding
- Does **not** clear witness taint
- Use only for in-circuit consistency checks

## Commit-Reveal Pattern

The standard commit-reveal pattern uses two phases: a commit phase where the value is hidden behind a commitment, and a reveal phase where the value and randomness are disclosed so observers can verify the commitment was honest.

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export enum Phase { commit, reveal, finalized }

export ledger phase: Phase;
export ledger commitments: Map<Bytes<32>, Bytes<32>>;

witness local_secret_key(): Bytes<32>;
witness get_randomness(): Bytes<32>;
witness storeOpening(id: Bytes<32>, salt: Bytes<32>, value: Field): [];
witness getOpening(): [Bytes<32>, Field];

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Phase 1: Each participant submits a commitment
export circuit submitCommitment(value: Field): [] {
  assert(phase == Phase.commit, "Not in commit phase");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  const salt = get_randomness();
  // persistentCommit clears witness taint on the input (value, salt)
  const c = persistentCommit<Field>(value, salt);
  storeOpening(pk, salt, value);
  // disclose() needed: pk is witness-derived (persistentHash does not clear taint);
  // c is clean (persistentCommit clears taint), so no disclose() needed on c
  commitments.insert(disclose(pk), c);
}

// Phase 2: Each participant reveals their value
export circuit revealValue(): Field {
  assert(phase == Phase.reveal, "Not in reveal phase");
  const sk = local_secret_key();
  const pk = get_public_key(sk);
  // disclose() needed: pk is witness-derived; Map.member() argument must be public
  assert(commitments.member(disclose(pk)), "No commitment found");
  const opening = getOpening();
  const [salt, value] = opening;
  // Recompute the commitment and compare against stored value
  const expected = persistentCommit<Field>(value, salt);
  // disclose() needed: pk is witness-derived; Map.lookup() argument must be public
  // expected is clean (persistentCommit clears taint), so no disclose() on result
  assert(expected == commitments.lookup(disclose(pk)), "Commitment mismatch");
  // disclose() needed: returning witness data from exported circuit
  return disclose(value);
}
```

## Salt / Randomness Management

### Rules

1. **Always source randomness from a witness function.** The randomness must come from the off-chain environment where cryptographically secure random number generation is available.

2. **Never reuse salts.** If the same value is committed with the same salt, the commitment outputs are identical, which breaks hiding (an observer can tell two commitments hide the same value).

3. **Store openings off-chain.** The value and salt needed to reveal a commitment must be stored securely by the witness implementation. The contract only stores the commitment hash on-chain.

### Witness Pattern for Randomness

```compact
// Declaration only -- implemented in TypeScript
witness get_randomness(): Bytes<32>;
```

The TypeScript implementation should use `crypto.getRandomValues()` or equivalent to produce 32 bytes of cryptographically secure randomness for each call.

**Do not** use `generateRandomness()` or `generateSecureRandom()` -- these functions do not exist in Compact. Randomness must come from a witness.

## Concurrent Security

Each participant in a multi-party protocol must use their own salt/secret. If two participants share a salt and commit the same value, their commitments will be identical, breaking the hiding property. Always source randomness per-participant from witness functions.
