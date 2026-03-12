---
name: core-concepts:privacy-patterns
description: Use when implementing privacy-preserving logic in Compact, working with hashes, commitments, Merkle trees, nullifier patterns, or keeping data private on-chain.
---

# Privacy Patterns in Midnight

Privacy-preserving design patterns for Compact smart contracts. Covers commitment schemes, nullifiers, Merkle tree membership proofs, round-based unlinkability, selective disclosure, and threat analysis. For basic visibility rules per ledger operation, see `compact-ledger`. For standard library function signatures, see `compact-standard-library`. For shielded token privacy, see `compact-tokens`.

## Pattern Selection Guide

| What to Protect | Approach | Key Primitives |
|----------------|----------|----------------|
| Hide a value on-chain | Commitment | `persistentCommit<T>` / `transientCommit<T>` |
| Prove membership anonymously | MerkleTree + ZK path | `HistoricMerkleTree` + `merkleTreePathRoot<N, T>` |
| Prevent double-actions | Nullifier | `persistentHash<T>` with domain separation + `Set<Bytes<32>>` |
| Hide who is acting | Unlinkable auth | `Counter` + rotated `persistentHash` |
| Multi-step hidden value | Commit-reveal | Commit phase + reveal phase |
| Private token balances | Shielded tokens | Zswap infrastructure (see `compact-tokens`) |
| Share specific data only | Selective disclosure | `disclose()` on boolean result, not the value |

## Pattern 1: Commitment Schemes

A commitment hides a value behind cryptographic randomness while binding the committer to that value. Compact provides hash-based commitments (not algebraic Pedersen commitments -- those are used internally by Zswap for balance proofs, a separate mechanism).

| Function | Signature | Clears Witness Taint | Use Case |
|----------|-----------|---------------------|----------|
| `persistentCommit<T>` | `(value: T, rand: Bytes<32>): Bytes<32>` | Yes | Hide a value you will reveal later |
| `persistentHash<T>` | `(value: T): Bytes<32>` | No | Derive a binding fingerprint (public keys, nullifiers) |
| `transientCommit<T>` | `(value: T, rand: Field): Field` | Yes | In-circuit intermediates only; algorithm may change between compiler versions |
| `transientHash<T>` | `(value: T): Field` | No | In-circuit consistency checks only |

**Persistent vs transient**: Persistent functions use SHA-256 and produce stable outputs across compiler upgrades. Transient functions are circuit-optimized but their algorithm may change between compiler versions, so outputs must not be stored in ledger state.

**When to use commit vs hash**: Use `persistentCommit` when you need to hide a value on-chain and later prove you committed to it (commit-reveal schemes, sealed bids). Use `persistentHash` when binding is sufficient and the hash itself is not secret (public key derivation, nullifiers, domain-separated identifiers). Note that `persistentHash<T>` accepts any serializable type `T`, not just `Bytes<32>`.

**Column note**: "Clears Witness Taint" means the compiler no longer requires `disclose()` for values that flowed through the function's input. The commitment cryptographically hides the input, so the compiler considers it safe. Hash functions do not provide this guarantee because hash outputs could theoretically be brute-forced.

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

// Witnesses are declaration-only; logic is implemented in TypeScript
witness get_randomness(): Bytes<32>;
witness store_opening(commitment: Bytes<32>, salt: Bytes<32>, value: Field): [];

export ledger storedCommitment: Bytes<32>;

export circuit commitValue(value: Field): [] {
  // Fresh randomness from off-chain -- never reuse
  const salt = get_randomness();
  const valueBytes = value as Bytes<32>;
  const commitment = persistentCommit<Vector<2, Bytes<32>>>(
    [valueBytes, pad(32, "myapp:commit:")],
    salt
  );
  // Store the opening off-chain for later reveal
  store_opening(commitment, salt, value);
  // persistentCommit clears witness taint on both input and result;
  // no disclose() needed for the ledger write
  storedCommitment = commitment;
}
```

See `references/commitment-schemes.md` for detailed commitment properties, reveal patterns, and salt management.

## Pattern 2: Nullifier Construction

A nullifier prevents double-actions without revealing which action is being prevented. It is a deterministic derivation from a secret: the same secret always produces the same nullifier, so a `Set` check catches reuse, but the nullifier itself reveals nothing about the underlying identity.

### Derivation Pattern

Nullifiers are derived via `persistentHash` (SHA-256) with a domain-separated vector of inputs:

```compact
persistentHash<Vector<N, Bytes<32>>>([
  pad(32, "contract:purpose:"),
  secret,
  ... additional inputs ...
])
```

**Domain separation is critical.** Nullifiers for different purposes MUST use different domain prefixes. Without domain separation, an observer who sees a nullifier from one contract can check whether the same secret was used in another contract.

### Nullifier vs Commitment Must Be Uncorrelatable

If you derive both a commitment and a nullifier from the same secret, use different domain separators so an observer cannot match commitments to nullifiers:

```compact
// WRONG -- same derivation enables linking
const commitment = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:"), sk]);
const nullifier = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:"), sk]);

// CORRECT -- different domains prevent correlation
const commitment = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:commit:"), sk]);
const nullifier = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:nul:"), sk]);
```

### Multi-Round Nullifiers

To allow one action per round (e.g., voting in multiple rounds), incorporate a round counter into the nullifier derivation:

```compact
circuit deriveNullifier(round: Uint<64>, sk: Bytes<32>): Bytes<32> {
  // Two-step cast required: Uint<64> -> Field -> Bytes<32>
  const roundBytes = (round as Field) as Bytes<32>;
  return persistentHash<Vector<3, Bytes<32>>>([
    pad(32, "myapp:round-nul:"),
    roundBytes,
    sk
  ]);
}
```

Each round produces a distinct nullifier from the same secret, allowing one action per round while still preventing double-actions within a round.

### Storage

Nullifiers are stored in `Set<Bytes<32>>`. This is public on-chain by design: the nullifier is already a derived value and reveals nothing about the underlying secret.

```compact
export ledger spentNullifiers: Set<Bytes<32>>;

// Check and insert a nullifier
const nul = deriveNullifier(currentRound, sk);
// disclose() needed: nul is witness-derived; Set.member() argument must be public
assert(!spentNullifiers.member(disclose(nul)), "Already acted this round");
spentNullifiers.insert(disclose(nul));
```

### Zerocash Pattern

The Midnight zerocash implementation demonstrates the canonical commitment and nullifier separation:

```compact
// From zerocash.compact -- nullifier derivation
circuit derive_nullifier(coin: coin_info, sk: zk_secret_key): nullifier {
  // Note: domain "lares:zerocash:commit" is intentionally named this way
  // in the reference implementation despite being a nullifier derivation
  return nullifier{ bytes: disclose(persistentHash<Vector<4, Bytes<32>>>([
    pad(32, "lares:zerocash:commit"),
    coin.nonce.bytes,
    coin.opening.bytes,
    sk.bytes
  ]))};
}
```

## Pattern 3: Merkle Tree Anonymous Authentication

`MerkleTree` and `HistoricMerkleTree` enable anonymous set membership proofs. The observer sees that someone proved membership, but not which member.

### Why HistoricMerkleTree

Use `HistoricMerkleTree<N, T>` instead of `MerkleTree<N, T>` when members are added over time. `HistoricMerkleTree.checkRoot()` accepts proofs against any prior version of the tree, so a proof generated before new members were added remains valid. With plain `MerkleTree`, each insertion changes the root and invalidates all existing proofs.

### The On-Chain / Off-Chain Dance

1. **Admin inserts commitments on-chain.** `tree.insert(commitment)` adds a leaf. The leaf value is hidden on-chain (the special privacy property of MerkleTree and HistoricMerkleTree inserts).

2. **User obtains a MerkleTreePath off-chain.** The witness function queries the local copy of the tree state. TypeScript provides `findPathForLeaf(leaf)` (O(n) scan) or `pathForLeaf(index, leaf)` (O(log n) by index).

3. **Circuit computes the root.** `merkleTreePathRoot<N, T>(path)` recomputes the Merkle root from the path. The `MerkleTreePath<N, T>` struct has fields `leaf: T` and `path: Vector<N, MerkleTreePathEntry>`, where each `MerkleTreePathEntry` has `sibling: MerkleTreeDigest` and `goesLeft: Boolean`. Pass the whole struct -- there is no `.value` field.

4. **Circuit verifies the root on-chain.** `tree.checkRoot(disclose(digest))` confirms the computed root matches a current (or historic) root. The `disclose()` is required because the digest is derived from witness data (the path). There is no `historicMember` method -- use `checkRoot` only.

### Full Flow: Anonymous Authentication with Nullifier

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger members: HistoricMerkleTree<16, Bytes<32>>;
export ledger usedNullifiers: Set<Bytes<32>>;

witness local_secret_key(): Bytes<32>;
witness getMemberPath(pk: Bytes<32>): MerkleTreePath<16, Bytes<32>>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Admin adds a member (leaf value is hidden on-chain)
export circuit addMember(memberPk: Bytes<32>): [] {
  members.insert(disclose(memberPk));
}

// Member proves membership anonymously and performs a one-time action
export circuit act(): [] {
  const sk = local_secret_key();
  const pk = get_public_key(sk);

  // Step 1: Get Merkle proof from off-chain state
  const memberPath = getMemberPath(pk);

  // Step 2: Compute root from the full MerkleTreePath struct
  // (no .value field -- pass the whole struct)
  const digest = merkleTreePathRoot<16, Bytes<32>>(memberPath);

  // Step 3: Verify against on-chain tree
  // disclose() needed: digest is derived from witness data (the path)
  assert(members.checkRoot(disclose(digest)), "Not a member");

  // Step 4: Derive nullifier to prevent reuse
  const nul = persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:act-nul:"), sk
  ]);
  // disclose() needed: nul is witness-derived; Set.member() argument must be public
  assert(!usedNullifiers.member(disclose(nul)), "Already acted");
  usedNullifiers.insert(disclose(nul));

  // ... perform the action
}
```

**Capacity planning:** `HistoricMerkleTree<N, T>` holds at most 2^N leaves. Depth 16 supports 65,536 members; depth 20 supports about 1 million. Depth also determines proof size (N sibling hashes), so balance capacity against circuit cost.

**Leaf guessing caveat:** If the set of possible leaf values is small (e.g., only 10 known public keys), an observer can verify guesses against the tree. Mitigate by using commitments (hashed with randomness) as leaves instead of raw public keys.

See `references/merkle-tree-usage.md` for detailed Merkle tree patterns and TypeScript integration.

## Pattern 4: Round-Based Unlinkability

This pattern breaks the link between successive transactions from the same user. Instead of storing a fixed public key on-chain, each transaction derives a round-specific key and rotates the stored authority.

### Mechanism

The public key for each round incorporates a counter:

```compact
circuit publicKey(roundVal: Uint<64>, sk: Bytes<32>): Bytes<32> {
  // Two-step cast: Uint<64> -> Field -> Bytes<32>
  const roundBytes = (roundVal as Field) as Bytes<32>;
  return persistentHash<Vector<3, Bytes<32>>>([
    pad(32, "myapp:pk:"),
    roundBytes,
    sk
  ]);
}
```

Each transaction:
1. Reads the current round counter
2. Derives the expected public key for this round
3. Asserts it matches the stored authority
4. Increments the round counter
5. Computes and stores the next round's authority

```compact
export ledger authority: Bytes<32>;
export ledger round: Counter;

witness local_secret_key(): Bytes<32>;

export circuit authorize(): [] {
  const sk = local_secret_key();
  // Counter.read() returns Uint<64>; cast through Field for hash input
  const currentRound = round.read();
  const pk = publicKey(currentRound, sk);
  // disclose() needed: pk is derived from witness data (sk)
  assert(disclose(authority == pk), "Not authorized");

  // Rotate to next round
  round.increment(1);
  const nextRound = round.read();
  // disclose() needed: writing witness-derived value to ledger
  authority = disclose(publicKey(nextRound, sk));
}
```

**Observer perspective:** Each transaction shows a different authority hash. Without knowing the secret key, the observer cannot determine that the same user authorized all transactions.

**Limitation:** The first transaction that initializes the authority is a unique event (the constructor sets it). An observer can identify the deployment transaction. Subsequent transactions are unlinkable to each other but not to the deployment.

## Selective Disclosure

Selective disclosure proves a property about private data without revealing the data itself. The key technique: `disclose()` the boolean result of a comparison, not the underlying value.

### Threshold Check

Prove a witness-held value exceeds a threshold without revealing the value. Note: comparison operators (`>=`, `<=`, `>`, `<`) only work on `Uint<N>`, not `Field`.

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

// Witnesses return Uint<64> because comparison operators
// (>=, <=, >, <) only work on Uint<N>, NOT on Field
witness getCredentialValue(): Uint<64>;
witness getCredentialSalt(): Bytes<32>;

export ledger credentialCommitment: Bytes<32>;

// Prove value >= threshold without revealing value
export circuit verifyThreshold(threshold: Uint<64>): [] {
  const value = getCredentialValue();
  const salt = getCredentialSalt();

  // Verify the witness value matches the on-chain commitment
  // persistentCommit<T> accepts any serializable type T
  const expected = persistentCommit<Uint<64>>(value, salt);
  // persistentCommit clears witness taint; no disclose() needed on result
  assert(expected == credentialCommitment, "Invalid credential");

  // Disclose only the boolean result, NOT the value
  // disclose() needed: comparison involves witness data (value)
  assert(disclose(value >= threshold), "Below threshold");
}
```

### Range Proof

```compact
export circuit verifyRange(minimum: Uint<64>, maximum: Uint<64>): [] {
  const value = getCredentialValue();
  const salt = getCredentialSalt();
  const expected = persistentCommit<Uint<64>>(value, salt);
  assert(expected == credentialCommitment, "Invalid credential");

  // Disclose the combined range check as a single boolean
  assert(disclose(value >= minimum && value <= maximum), "Out of range");
}
```

### Selective Field Disclosure

When working with structured data, disclose only specific fields:

```compact
// Witnesses return Uint<64> for fields that need comparison operators
witness getProfile(): [Bytes<32>, Uint<64>, Uint<64>];

// Reveal age bracket but not name or exact income
export circuit proveAgeAbove(minAge: Uint<64>): [] {
  const profile = getProfile();
  const [name, age, income] = profile;  // name and income NOT disclosed; age comparison result disclosed

  // Only the boolean result of the age comparison is made public
  // disclose() needed: age is witness data used in a conditional
  assert(disclose(age >= minAge), "Age requirement not met");
}
```

## Threat Model: What an On-Chain Observer Can See

### Always Visible

- **Which exported circuit was called** (circuit name is part of the transaction)
- **Which contract was called** (contract address is visible)
- **Number of ledger operations** (each read/write creates observable state change)
- **Transaction timing** (block inclusion time)
- **Counter increment/decrement amounts** (all Counter operations are public)
- **Map and Set operation arguments** (keys, values, and elements are public). Exception: `MerkleTree.insert()` hides its leaf argument.
- **The `disclose()`d values** (by definition, intentionally public)

### Hidden by ZK Proofs

- **Witness function return values** (unless explicitly disclosed)
- **Internal circuit computations** (intermediate variables)
- **Values passed to `MerkleTree.insert()` and `HistoricMerkleTree.insert()`** (the only ledger operations that hide their data argument)
- **The specific leaf proven in a Merkle membership proof** (observer sees only the root check)

### Mitigation Strategies

| Attack | Mitigation |
|--------|------------|
| Small anonymity set | Add dummy members to increase set size |
| Timing correlation | Introduce random delays; batch transactions |
| Amount fingerprinting | Standardize amounts; split into uniform denominations |
| Leaf guessing | Use committed values (with randomness) as MerkleTree leaves |
| Nullifier timing | Decouple registration order from action order |
| Circuit selection | Use a single circuit with internal branching where feasible |

## Common Mistakes

| Wrong | Correct | Why |
|-------|---------|-----|
| `Set` for private membership | `MerkleTree` + ZK path proof | Set reveals which element is tested (note: only an issue when element identity must be hidden) |
| Missing domain separator on nullifiers | Always prefix with unique `pad(32, "contract:purpose:")` | Prevents cross-contract correlation |
| `persistentHash` to "hide" witness data | `persistentCommit` with randomness | Hash does not clear witness taint; commit does |
| Same derivation for commitment and nullifier | Different domain separators | Prevents linking attack |
| Disclosing at witness call site | Disclose at the disclosure point | Over-discloses; all downstream uses lose privacy |
| Reusing salts across commitments | Unique randomness per commitment | Same value + same salt = same output |
| `round as Bytes<32>` cast for `Uint<64>` | `(round as Field) as Bytes<32>` two-step | Direct `Uint<64>` to `Bytes<32>` cast is invalid |
| `>=` / `<=` on `Field` type | Use `Uint<64>` for comparisons | Comparison operators only work on `Uint<N>` |
| `merkleTreePathRoot(path.value)` | `merkleTreePathRoot(path)` passing whole struct | `MerkleTreePath` has no `.value` field |

## References

| Topic | File |
|-------|------|
| Commitment properties, hiding/binding, `persistentCommit` vs `transientCommit`, salt management | `references/commitment-schemes.md` |
| MerkleTree/HistoricMerkleTree, `MerkleTreePath` struct, `checkRoot` pattern, TypeScript integration | `references/merkle-tree-usage.md` |

## Examples

| Example | File | Pattern |
|---------|------|---------|
| Multi-signature and role-based authentication with Merkle proofs | `examples/auth-patterns.compact` | Authentication |
| Anonymous voting with commit-reveal and nullifiers | `examples/private-voting.compact` | Private Voting |
