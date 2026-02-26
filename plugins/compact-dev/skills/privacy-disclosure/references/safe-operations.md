# Safe Operations

Reference for safe vs unsafe standard library functions and their privacy implications.

## The Safety Spectrum

| Operation Type | Example | Safety | Reason |
| --------------- | --------- | -------- | -------- |
| Commitment | `persistentCommit(x)` | Safe | Includes nonce, can't brute-force |
| Hash | `persistentHash(x)` | Unsafe | No nonce, brute-forceable |
| Direct use | `return x` | Discloses | Value is public |

## Commitment Functions (Safe)

### persistentCommit

Creates a commitment that persists across transactions.

```compact
import { persistentCommit } from "CompactStandardLibrary";

witness get_secret(): Field;

export circuit create_commitment(): Bytes<32> {
    const secret = get_secret();
    const commitment = persistentCommit(secret);
    return commitment;  // Safe to return
}
```

**Why safe**: Commitments include a random nonce, making them impossible to reverse even with unlimited computation.

**Use when**:
- Storing private data on-chain
- Creating commitment schemes (commit-reveal)
- Hiding values that will be revealed later

### transientCommit

Creates a commitment valid only within the current transaction.

```compact
import { transientCommit } from "CompactStandardLibrary";

witness get_vote(): Field;

export circuit prepare_vote(): Bytes<32> {
    const vote = get_vote();
    return transientCommit(vote);  // Safe, but only valid this tx
}
```

**Use when**:
- Values only need privacy within one transaction
- Slightly more efficient than persistentCommit

## Hash Functions (Unsafe)

### persistentHash

Deterministic hash without nonce.

```compact
import { persistentHash } from "CompactStandardLibrary";

witness get_password(): Bytes<32>;

// UNSAFE: Password can be brute-forced!
export circuit bad_store_password(): Bytes<32> {
    const password = get_password();
    return persistentHash(password);  // Unsafe!
}

// Hash is not witness-tainted, but reveals information
// about low-entropy inputs through brute-force attacks
```

**Why unsafe**:
- No randomness/nonce included
- Same input always produces same hash
- Attacker can hash common values and compare

**When hash IS appropriate**:
- Verifying a value you already committed to
- Hashing high-entropy data (random keys)
- Creating deterministic identifiers

```compact
// SAFE USE: Verification against known commitment
export circuit verify_preimage(commitment: Bytes<32>): Boolean {
    const secret = get_secret();
    const expected = persistentCommit(secret);
    return expected == commitment;  // OK: verification
}

// SAFE USE: High-entropy identifier
export circuit create_nullifier(): Bytes<32> {
    // secret is high-entropy (256 bits)
    const secret = get_secret();
    return persistentHash("nullifier", secret);  // OK for unique ID
}
```

### transientHash

Deterministic hash valid only in current transaction.

Same safety concerns as `persistentHash`, just scoped to one transaction.

## Comparison Table

| Function | Includes Nonce | Deterministic | Safe for Secrets |
| ---------- | --------------- | --------------- | ------------------ |
| `persistentCommit` | Yes | No | Yes |
| `transientCommit` | Yes | No | Yes |
| `persistentHash` | No | Yes | Only high-entropy |
| `transientHash` | No | Yes | Only high-entropy |

## Common Patterns

### Commit-Reveal (Safe)

```compact
import { persistentCommit } from "CompactStandardLibrary";

ledger commitments: Map<Bytes<32>, Bytes<32>>;

witness get_bid(): Uint<64>;

// Phase 1: Commit (safe)
export circuit commit_bid(bidder: Bytes<32>): Bytes<32> {
    const bid = get_bid();
    const commitment = persistentCommit(bid);
    commitments.insert(bidder, commitment);
    return commitment;
}

// Phase 2: Reveal (requires disclosure)
export circuit reveal_bid(bidder: Bytes<32>): Uint<64> {
    const bid = get_bid();
    const commitment = persistentCommit(bid);

    // Verify against stored commitment
    const stored = commitments.lookup(bidder);
    assert stored is Maybe::Some(c), "No commitment found";
    if stored is Maybe::Some(c) {
  assert c == commitment, "Commitment mismatch";
    }

    return disclose(bid);  // Intentional reveal
}
```

### Nullifier Pattern (Safe)

```compact
import { persistentHash, persistentCommit } from "CompactStandardLibrary";

ledger used_nullifiers: Set<Bytes<32>>;

witness get_secret(): Bytes<32>;

export circuit spend(): Bytes<32> {
    const secret = get_secret();

    // Nullifier: deterministic but reveals nothing about secret
    // (assuming secret is high-entropy, like a private key)
    const nullifier = persistentHash("nullifier", secret);

    // Check not already spent
    assert !used_nullifiers.member(nullifier), "Already spent";

    // Mark as spent
    used_nullifiers.insert(nullifier);

    return nullifier;
}
```

### Merkle Membership (Safe)

```compact
import { persistentCommit } from "CompactStandardLibrary";

ledger membership_tree: MerkleTree<Bytes<32>>;

witness get_identity(): Bytes<32>;
witness get_merkle_path(index: Uint<32>): Vector<Bytes<32>, 20>;

export circuit prove_membership(root: Bytes<32>, index: Uint<32>): Boolean {
    const identity = get_identity();

    // Commit to identity for the leaf
    const leaf = persistentCommit(identity);

    // Get and verify Merkle path
    const path = get_merkle_path(index);
    const computed_root = merkleTreePathRoot(leaf, path);

    return computed_root == root;  // Boolean result is safe
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Hashing Low-Entropy Secrets

```compact
// BAD: PIN can be brute-forced (only 10,000 possibilities)
witness get_pin(): Uint<16>;

export circuit store_pin(): Bytes<32> {
    const pin = get_pin();
    return persistentHash(pin as Field);  // Unsafe!
}

// GOOD: Use commitment instead
export circuit store_pin_safe(): Bytes<32> {
    const pin = get_pin();
    return persistentCommit(pin as Field);  // Safe
}
```

### Anti-Pattern 2: Hashing Enumerable Values

```compact
// BAD: Vote can be enumerated (e.g., 0, 1, 2 for options)
witness get_vote(): Uint<8>;

export circuit hash_vote(): Bytes<32> {
    const vote = get_vote();
    return persistentHash(vote as Field);  // Attacker can hash 0, 1, 2 and compare
}

// GOOD: Commit instead
export circuit commit_vote(): Bytes<32> {
    const vote = get_vote();
    return persistentCommit(vote as Field);  // Safe: nonce prevents enumeration
}
```

### Anti-Pattern 3: Hash as Privacy Shield

```compact
// BAD: Thinking hash "protects" the value
witness get_balance(): Uint<64>;

export circuit bad_privacy(): Bytes<32> {
    // "Nobody can see my balance because it's hashed!"
    // Wrong: attacker can hash common balances and compare
    return persistentHash(get_balance() as Field);
}
```

## Decision Guide

**Use `persistentCommit`/`transientCommit` when**:
- Hiding any user-provided value
- Implementing commit-reveal schemes
- Storing private data on-chain
- Value will be revealed later

**Use `persistentHash`/`transientHash` when**:
- Creating nullifiers from high-entropy secrets
- Verifying data integrity
- Computing deterministic IDs from random keys
- Input is provably high-entropy (>=128 bits)
