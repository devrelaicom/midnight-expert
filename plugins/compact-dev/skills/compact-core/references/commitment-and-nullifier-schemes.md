---
title: Commitment and Nullifier Schemes
type: concept
description: Privacy primitives for hiding values on-chain — commit to a value, later prove knowledge of it, and use nullifiers to prevent double-spending.
links:
  - transient-vs-persistent
  - disclosure-model
  - merkle-trees
  - standard-library-functions
  - witness-functions
  - circuit-witness-boundary
  - commit-reveal-pattern
  - anonymous-membership-proof
  - token-operations
---

# Commitment and Nullifier Schemes

Commitments and nullifiers are the fundamental privacy primitives in Compact. A commitment hides a value while allowing later proof of knowledge. A nullifier prevents the same commitment from being used twice. Together, they enable private transfers, anonymous voting, and credential systems.

## Commitment Basics

A commitment is a hash of a secret value:

```compact
// Using transient commit for privacy (see transient-vs-persistent)
const commitment = transientCommit<Field>(secretValue);
```

The commitment can be stored on-chain (in a Cell or [[merkle-trees]]) without revealing the secret. Later, the prover can demonstrate knowledge of the secret by providing it via a [[witness-functions]] and verifying that `transientCommit(witness_value) == stored_commitment`.

The choice of transient vs persistent commit functions is governed by [[transient-vs-persistent]] — always use `transientCommit` for private data and `persistentCommit` only for public data.

## Nullifier Pattern

A nullifier is a value derived from a commitment's secret that, once revealed, marks the commitment as "spent." The key properties are:

1. **Unique**: Each commitment produces exactly one nullifier
2. **Unlinkable**: The nullifier cannot be linked back to the commitment without knowing the secret
3. **Deterministic**: The same secret always produces the same nullifier

```compact
export ledger commitments: MerkleTree<20, Bytes<32>>;
export ledger usedNullifiers: Set<Bytes<32>>;

witness getSecret(): Bytes<32>;
witness getNullifier(): Bytes<32>;
witness getMerklePath(): Vector<20, Bytes<32>>;
witness getLeafIndex(): Field;

export circuit spend(): [] {
  const secret = getSecret();
  const nullifier = getNullifier();

  // 1. Verify the commitment exists in the tree
  const leaf = transientCommit<Bytes<32>>(secret) as Bytes<32>;
  const root = merklePathRoot<20>(getMerklePath(), getLeafIndex(), leaf);
  assert root == merkleTreeDigest(commitments) "Invalid commitment";

  // 2. Verify the nullifier matches the secret
  assert nullifier == persistentHash<Bytes<32>>(secret) "Invalid nullifier";

  // 3. Check the nullifier hasn't been used before
  assert !usedNullifiers.member(disclose(nullifier)) "Already spent";

  // 4. Record the nullifier to prevent reuse
  usedNullifiers.insert(disclose(nullifier));
}
```

The nullifier is computed with `persistentHash` (deterministic) because it must be the same every time — this is one of the few cases where persistent hash on secret data is correct, because the nullifier is explicitly intended to be public and linkable to prevent double-spend.

## Commitment in Merkle Trees

The standard pattern stores commitments in a [[merkle-trees]] to enable the [[anonymous-membership-proof]]:

1. **Commit phase**: Hash the secret and insert into the MerkleTree
2. **Prove phase**: Provide the secret and Merkle path via witnesses, verify in-circuit

The MerkleTree's append-only nature means commitments cannot be removed or modified, only spent via nullifiers.

## Salt/Nonce for Uniqueness

When the committed value has low entropy (e.g., a vote of 0 or 1), add a random salt to prevent brute-force identification:

```compact
witness getVote(): Field;
witness getSalt(): Bytes<32>;

export circuit commitVote(): [] {
  const vote = getVote();
  const salt = getSalt();
  const c = transientCommit<Vector<2, Field>>([vote, salt as Field]);
  voteCommitment = c;
}
```

The salt ensures that even identical votes produce different commitments. The salt must be remembered by the voter's DApp (via [[witness-functions]]) to later prove the vote during the reveal phase described in [[commit-reveal-pattern]].

## Relationship to Token Operations

The [[token-operations]] in Midnight's Zswap protocol use a variant of commitment-nullifier schemes internally. When you call `mintToken()`, the protocol creates a coin commitment in the shielded pool. When you call `send()`, it consumes (nullifies) one coin and creates new commitments for the output coins. Understanding this underlying mechanism helps explain the [[coin-lifecycle]] and why change handling is mandatory.
