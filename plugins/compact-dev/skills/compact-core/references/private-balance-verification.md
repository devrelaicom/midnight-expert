---
title: Private Balance Verification
type: pattern
description: Proving that a balance exceeds a threshold without revealing the exact amount — using witness-provided values with range assertions inside ZK circuits.
links:
  - witness-functions
  - circuit-witness-boundary
  - disclosure-model
  - commitment-and-nullifier-schemes
  - type-system
  - bounded-computation
  - access-control-pattern
---

# Private Balance Verification

This pattern proves that a user's balance or value meets a minimum threshold without revealing the exact amount. It is useful for compliance checks ("prove you have at least $10,000"), access gating ("prove membership tier"), and creditworthiness verification.

## Core Technique

The user provides their balance via a [[witness-functions]], and the circuit asserts it meets the threshold. The balance itself is never disclosed — only the Boolean "threshold met" fact is proven by the ZK proof:

```compact
witness getUserBalance(): Uint<0..1000000>;

export circuit proveMinimumBalance(threshold: Uint<0..1000000>): [] {
  const balance = getUserBalance();
  assert balance >= threshold "Balance below threshold";
  // The proof now guarantees balance >= threshold
  // but the exact balance remains private
}
```

The verifier (blockchain) learns only that the assertion passed — the balance value stays inside the proof and is never written to the ledger or returned from the circuit.

## With On-Chain Commitment

For stronger guarantees, combine with [[commitment-and-nullifier-schemes]] to prove the balance is committed on-chain:

```compact
export ledger balanceCommitments: MerkleTree<20, Bytes<32>>;

witness getBalance(): Uint<0..1000000>;
witness getSalt(): Bytes<32>;
witness getMerklePath(): Vector<20, Bytes<32>>;
witness getLeafIndex(): Field;

export circuit proveBalanceAbove(threshold: Uint<0..1000000>): [] {
  const balance = getBalance();
  const salt = getSalt();

  // Verify the balance is committed in the tree
  const leaf = transientCommit<Vector<2, Field>>(
    [balance as Field, salt as Field]) as Bytes<32>;
  const root = merklePathRoot<20>(getMerklePath(), getLeafIndex(), leaf);
  assert root == merkleTreeDigest(balanceCommitments) "Invalid balance commitment";

  // Prove the threshold is met
  assert balance >= threshold "Balance below threshold";
}
```

This proves not just that the user *claims* to have a sufficient balance, but that they committed to that balance earlier (registered in the Merkle tree). Without the commitment verification, the user could lie about their balance via the [[circuit-witness-boundary]] — any DApp could provide any value.

## Range Proofs

Since Compact's [[type-system]] enforces compile-time range bounds on `Uint`, the balance is already constrained. A `Uint<0..1000000>` cannot be negative or exceed 1,000,000. Combined with the `assert balance >= threshold` check, this forms a complete range proof: `threshold <= balance <= 1000000`.

Due to [[bounded-computation]], these range checks are built into the circuit gates and verified efficiently by the ZK proof system.

## Application: Tiered Access

Combine with the [[access-control-pattern]] for balance-gated features:

```compact
export circuit premiumAction(): [] {
  proveMinimumBalance(10000);  // Must have at least 10,000
  // ... premium-only logic
}
```

## Privacy Considerations

Per the [[disclosure-model]], the threshold itself may be public (it's a circuit argument visible in the transaction), but the balance is private (it comes from a witness and is never disclosed). If even the threshold must be private, make it a witness parameter too — but then the verifier only learns "some threshold was met" without knowing what threshold.
