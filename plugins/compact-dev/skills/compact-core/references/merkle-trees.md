---
title: Merkle Trees
type: concept
description: MerkleTree and HistoricMerkleTree provide privacy-preserving membership proofs in ZK circuits — the foundation for anonymous credentials and private set membership.
links:
  - ledger-state-design
  - anonymous-membership-proof
  - commitment-and-nullifier-schemes
  - bounded-computation
  - witness-functions
  - standard-library-functions
  - transient-vs-persistent
---

# Merkle Trees

MerkleTree and HistoricMerkleTree are the most powerful ledger ADTs in Compact, enabling privacy-preserving membership proofs. A member can prove they are in the tree without revealing which leaf they occupy — the foundation of the [[anonymous-membership-proof]] pattern.

## MerkleTree<n, T>

A fixed-depth binary Merkle tree that stores commitments as leaves. The depth `n` must be a compile-time constant satisfying `1 < n <= 32` (a requirement of [[bounded-computation]]). A tree of depth `n` can hold up to `2^n` leaves.

```compact
export ledger members: MerkleTree<20, Bytes<32>>;  // ~1 million leaves
```

### Operations

| Operation | Syntax | Notes |
|-----------|--------|-------|
| Insert | `members.insert(leaf)` | Appends a leaf; returns the leaf index |
| Digest | `merkleTreeDigest(members)` | Returns the current root hash |

Insert is append-only — you cannot update or remove existing leaves. This is a deliberate design choice for privacy: if leaves could be updated, the update pattern would reveal which leaf was modified.

### Membership Proofs

Proving membership requires the standard library's `merklePathRoot` function from [[standard-library-functions]]:

```compact
witness getMerklePath(): Vector<20, Bytes<32>>;
witness getLeafIndex(): Field;
witness getLeafValue(): Bytes<32>;

export circuit proveMembership(): [] {
  const path = getMerklePath();
  const index = getLeafIndex();
  const leaf = getLeafValue();

  // Compute the root from the leaf and path
  const computedRoot = merklePathRoot<20>(path, index, leaf);

  // Verify it matches the tree's current root
  assert computedRoot == merkleTreeDigest(members) "Not a member";
}
```

The witness provides the Merkle path (sibling hashes along the path from leaf to root), the leaf index, and the leaf value. All of these are private — the circuit only verifies that they produce the correct root hash. The verifier learns that *some* valid leaf exists, but not which one.

### Privacy Model

The privacy of Merkle tree membership proofs depends on what is stored as leaves. If the leaf is a `transientCommit(secret)` (see [[transient-vs-persistent]]), then the membership proof reveals nothing about the secret. If the leaf is a `persistentHash(secret)`, anyone who knows the secret can identify the leaf — breaking anonymity. The choice between transient and persistent operations here is critical.

## HistoricMerkleTree<n, T>

HistoricMerkleTree extends MerkleTree by preserving root hashes across insertions. This allows proving membership against a past root, not just the current one:

```compact
export ledger history: HistoricMerkleTree<20, Bytes<32>>;
```

### Additional Operations

| Operation | Syntax | Notes |
|-----------|--------|-------|
| Historic digest | `historicMerkleTreeDigest(history, index)` | Root hash at a specific past state |

This is essential for protocols where a member might prove membership against the state at the time they joined, even after new members have been added. Without historic queries, every new insertion changes the root, potentially invalidating in-flight proofs.

## Depth Selection

Tree depth determines capacity (`2^n` leaves) and circuit cost (Merkle path verification requires `n` hash computations):

| Depth | Capacity | Circuit Cost |
|-------|----------|-------------|
| 10 | ~1,000 | Low |
| 16 | ~65,000 | Moderate |
| 20 | ~1,000,000 | High |
| 32 | ~4 billion | Very high |

The depth must balance capacity against proof generation time. For most applications, depth 16-20 provides sufficient capacity without excessive cost. The depth is a compile-time constant as required by [[bounded-computation]], so it cannot be changed after deployment.

## Common Pattern: Insert Commitment, Prove Knowledge

The standard pattern combines insertion with the [[commitment-and-nullifier-schemes]]:

1. **Insert**: Hash the secret data and insert the hash as a leaf
2. **Prove**: Later, provide the secret and the Merkle path via [[witness-functions]], verify in-circuit that `hash(secret)` matches a leaf and the path produces the current root

This is the building block for anonymous voting, private credentials, and shielded transfers.
