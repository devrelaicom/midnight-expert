# Merkle Tree Usage

Detailed reference for `MerkleTree`, `HistoricMerkleTree`, membership proofs, and the `MerkleTreePath` struct in Compact.

## Ledger Types

### MerkleTree<N, T>

A Merkle tree with depth `N` and leaf type `T`. Supports up to 2^N leaves. Each insertion changes the root, which invalidates all existing proofs.

```compact
export ledger tree: MerkleTree<10, Bytes<32>>;
```

### HistoricMerkleTree<N, T>

Like `MerkleTree` but retains all historic roots. `checkRoot()` accepts proofs against any prior version of the tree, so proofs generated before new insertions remain valid. Use this when members are added over time.

```compact
export ledger members: HistoricMerkleTree<16, Bytes<32>>;
```

## Operations

### insert(value)

Adds a leaf to the tree. The leaf value is **hidden on-chain** -- this is the unique privacy property of MerkleTree inserts. An observer sees that an insertion occurred but cannot determine what was inserted.

```compact
// disclose() required: argument is witness-derived
// Even though insert() hides the value on-chain, the compiler
// still requires disclose() for the argument
members.insert(disclose(memberPk));
```

### checkRoot(digest)

Verifies that `digest` matches a valid root of the tree. For `HistoricMerkleTree`, this checks against all historic roots. For `MerkleTree`, only the current root.

```compact
// disclose() required: digest is derived from witness data (the path)
assert(members.checkRoot(disclose(digest)), "Not a member");
```

**Important**: There is no `historicMember` method. Use `checkRoot` only. There is no `.member(value, path)` method either -- membership is verified by computing the root from a path and checking it.

## MerkleTreePath Struct

The `MerkleTreePath<N, T>` struct contains everything needed to recompute a Merkle root from a leaf:

| Field | Type | Description |
|-------|------|-------------|
| `leaf` | `T` | The leaf value being proven |
| `path` | `Vector<N, MerkleTreePathEntry>` | The authentication path (sibling hashes and directions) |

Each `MerkleTreePathEntry` has:

| Field | Type | Description |
|-------|------|-------------|
| `sibling` | `MerkleTreeDigest` | The sibling hash at this tree level |
| `goes_left` | `Boolean` | Whether the current node is the left child |

**There is no `.value` field on `MerkleTreePath`.** Pass the whole struct to `merkleTreePathRoot`.

## merkleTreePathRoot Function

```text
merkleTreePathRoot<N, T>(path: MerkleTreePath<N, T>): MerkleTreeDigest
```

Recomputes the Merkle root by hashing from the leaf up through all siblings. Pass the entire `MerkleTreePath` struct -- not a field of it.

```compact
// CORRECT: pass the whole MerkleTreePath struct
const digest = merkleTreePathRoot<16, Bytes<32>>(memberPath);

// WRONG: no .value field exists on MerkleTreePath
// const digest = merkleTreePathRoot<16, Bytes<32>>(memberPath.value);  // ERROR
```

## Complete Membership Proof Pattern

The canonical four-step pattern for anonymous membership verification:

```compact
pragma language_version 0.22;
import CompactStandardLibrary;

export ledger members: HistoricMerkleTree<16, Bytes<32>>;
export ledger usedNullifiers: Set<Bytes<32>>;

// Witnesses are declaration-only
witness local_secret_key(): Bytes<32>;
witness getMemberPath(pk: Bytes<32>): MerkleTreePath<16, Bytes<32>>;

circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Admin adds a member (leaf value is hidden on-chain)
export circuit addMember(memberPk: Bytes<32>): [] {
  // disclose() required: circuit parameter treated as witness data
  members.insert(disclose(memberPk));
}

// Member proves membership anonymously
export circuit proveAndAct(): [] {
  const sk = local_secret_key();
  const pk = get_public_key(sk);

  // Step 1: Get Merkle proof from off-chain state via witness
  const memberPath = getMemberPath(pk);

  // Step 2: Compute root from the full MerkleTreePath struct
  const digest = merkleTreePathRoot<16, Bytes<32>>(memberPath);

  // Step 3: Verify against on-chain tree
  // disclose() required: digest is derived from witness data (the path)
  assert(members.checkRoot(disclose(digest)), "Not a member");

  // Step 4: Derive and check nullifier to prevent reuse
  const nul = persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:act-nul:"), sk
  ]);
  // disclose() required: nul is witness-derived; Set.member() argument must be public
  assert(!usedNullifiers.member(disclose(nul)), "Already acted");
  usedNullifiers.insert(disclose(nul));

  // ... perform the action
}
```

## TypeScript Integration

The off-chain witness implementation must query the local tree state to construct the `MerkleTreePath`. Two APIs are available:

### findPathForLeaf(leaf)

O(n) scan through all leaves to find the matching one and construct the path. Use when you do not know the leaf's index.

### pathForLeaf(index, leaf)

O(log n) path construction when the leaf's index is known. More efficient for large trees.

### Example Witness Implementation

Note: The API shape below is illustrative. Consult the current Midnight SDK documentation for exact method signatures.

```typescript
// Simplified TypeScript witness implementation
const getMemberPath = async (pk: Bytes) => {
  // Query the local ledger state for the tree
  const treeState = await ledgerState.members;
  // Find the path for this leaf
  const path = treeState.findPathForLeaf(pk);
  if (!path) {
    throw new Error("Member not found in tree");
  }
  return path;
};
```

## Capacity Planning

| Depth (N) | Max Leaves | Proof Size (sibling hashes) | Use Case |
|-----------|------------|----------------------------|----------|
| 10 | 1,024 | 10 | Small groups, test scenarios |
| 16 | 65,536 | 16 | Medium communities |
| 20 | ~1,048,576 | 20 | Large-scale applications |
| 32 | ~4.3 billion | 32 | Maximum practical capacity |

Deeper trees increase circuit complexity (more hash computations per proof) but support more members. Balance capacity against proof generation time.

## Privacy Considerations

### Leaf Guessing

If the set of possible leaf values is small (e.g., 10 known public keys), an observer can hash each candidate and check whether it appears as a leaf. Mitigate by using commitments with randomness as leaves:

```compact
// Instead of inserting raw public keys:
// members.insert(disclose(pk));

// Insert commitments that hide the public key behind randomness:
const rand = get_randomness();
const leafCommitment = persistentCommit<Bytes<32>>(pk, rand);
members.insert(disclose(leafCommitment));
```

### Tree Size Leakage

The number of `MerkleTree` insertions is observable (the tree index increments visibly). This reveals the member count even though individual members are hidden.

### Set vs MerkleTree

`Set.member(value)` reveals which element is being tested because the argument is public. When element identity must remain private (e.g., proving you are in an authorized group without revealing which member you are), use `MerkleTree` with a ZK path proof instead.
