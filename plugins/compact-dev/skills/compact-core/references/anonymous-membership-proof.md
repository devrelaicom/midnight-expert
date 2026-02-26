---
title: Anonymous Membership Proof
type: pattern
description: Proving membership in a set (e.g., registered voters, authorized signers) without revealing which member you are — using Merkle trees and ZK proofs.
links:
  - merkle-trees
  - commitment-and-nullifier-schemes
  - witness-functions
  - transient-vs-persistent
  - access-control-pattern
  - standard-library-functions
  - disclosure-model
---

# Anonymous Membership Proof

Anonymous membership proofs allow a participant to prove "I am a member of this group" without revealing which member they are. This is the fundamental building block for anonymous voting, private credentials, and privacy-preserving access control.

## How It Works

1. **Registration**: Each member computes a commitment to their identity and inserts it as a leaf in a [[merkle-trees]]
2. **Proof**: To prove membership, the member provides their identity and a Merkle path via [[witness-functions]]
3. **Verification**: The circuit recomputes the commitment, walks the Merkle path to the root, and verifies the root matches the tree's current digest
4. **Privacy**: The Merkle path reveals nothing about which leaf was used — the verifier only learns that *some* valid leaf exists

## Implementation

```compact
export ledger members: MerkleTree<20, Bytes<32>>;
export ledger usedNullifiers: Set<Bytes<32>>;

witness getSecret(): Bytes<32>;
witness getMerklePath(): Vector<20, Bytes<32>>;
witness getLeafIndex(): Field;

// Register a new member
export circuit register(commitment: Bytes<32>): [] {
  members.insert(disclose(commitment));
}

// Prove membership anonymously and perform an action
export circuit anonymousAction(): [] {
  const secret = getSecret();
  const path = getMerklePath();
  const index = getLeafIndex();

  // Recompute the leaf from the secret
  const leaf = transientCommit<Bytes<32>>(secret) as Bytes<32>;

  // Verify the leaf is in the tree
  const computedRoot = merklePathRoot<20>(path, index, leaf);
  assert computedRoot == merkleTreeDigest(members) "Not a member";

  // Compute and record a nullifier to prevent double-action
  const nullifier = persistentHash<Bytes<32>>(secret);
  assert !usedNullifiers.member(disclose(nullifier)) "Already acted";
  usedNullifiers.insert(disclose(nullifier));
}
```

## Privacy Analysis

The privacy depends on correct use of [[transient-vs-persistent]]:

- **Leaf computation**: Uses `transientCommit` — the commitment cannot be linked to the secret by observers
- **Nullifier computation**: Uses `persistentHash` — deliberately deterministic so the same secret always produces the same nullifier (preventing double-action)
- **Merkle path**: Provided by witness (private) — not revealed on-chain
- **Leaf index**: Provided by witness (private) — not revealed on-chain

The only public information is the nullifier, which cannot be linked back to the original commitment in the tree. This is the standard [[commitment-and-nullifier-schemes]] pattern applied to membership.

## Registration Privacy

In the basic pattern above, the commitment itself is inserted publicly via `register()`. If even the act of registering must be private, use a different approach:
- An administrator inserts commitments during a setup phase
- Or use a commit-then-insert pattern where the insertion is batched

## Comparison with Set-Based Membership

The [[map-and-set]] Set ADT also supports membership checks, but with no privacy: `set.member(value)` reveals which value is being checked. The Merkle tree pattern provides full anonymity at the cost of:
- Higher circuit complexity (Merkle path verification)
- Append-only insertion (leaves cannot be removed)
- Need for a [[witness-functions]] to provide the Merkle path

Choose Set when membership is not sensitive. Choose Merkle trees when anonymity matters.

## Applications

- **Anonymous voting**: Registered voters prove membership to cast a ballot without revealing their identity
- **Private credentials**: Credential holders prove they hold a valid credential without revealing which one
- **Access control**: The [[access-control-pattern]] can be extended with anonymous membership for group-based access
- **Token airdrops**: Eligible addresses prove eligibility without revealing which address they are
