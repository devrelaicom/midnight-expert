# Cryptographic Binding

## Purpose

Cryptographic binding ensures transaction integrity:
- All components linked together
- Cannot mix components from different transactions
- Cannot modify without invalidating proofs
- Atomic execution guaranteed

## Binding Mechanisms

### 1. Pedersen Commitments

Used for value binding in Zswap.

Pedersen commitments are elliptic-curve-based commitments with three key properties:

- **Hiding**: The committed value cannot be determined from the commitment alone
- **Binding**: Once committed, the value cannot be changed without detection
- **Homomorphic**: Adding two commitments produces a valid commitment to the sum of their values

The commitment incorporates the token type through a type-dependent generator point (derived via hash-to-curve), enabling independent balance verification per token type. No actual values are revealed during balance checking.

### 2. Schnorr Proof

Each contract interaction segment carries a Schnorr proof demonstrating the prover knows the randomness used in the Pedersen binding commitment. This binds the segment's effects to the transaction, preventing unauthorized value injection.

The proof uses the Fiat-Shamir transform (deterministic challenge derived from public data) to be non-interactive. During verification, the challenge is recomputed from the public data rather than stored in the proof itself.

**Why needed**:
Without this, contracts could inject hidden value into their transaction segment.

### 3. ZK Proof Binding

Each ZK proof commits to:
- Public inputs (transaction data)
- Statement being proven
- Transaction binding data

**Prevents**:
- Proof reuse across transactions
- Proof substitution
- Public input manipulation

## Transaction Binding

### Pedersen-Based Binding

Transaction binding uses homomorphic Pedersen commitments rather than a simple hash construction. Commitments from all transaction components — Zswap offers and contract calls — are homomorphically combined to produce a single binding commitment.

This approach preserves the homomorphic property needed for balance verification while cryptographically linking all components together.

### What Each Component Binds

| Component | Binds To |
|-----------|----------|
| Input proofs | Specific nullifier, Merkle root, transaction binding |
| Output proofs | Specific commitment, transaction binding |
| Contract proofs | Specific transcript, transaction binding |
| Schnorr proof | Segment binding commitment, transaction binding |

## Balance Verification

### Homomorphic Balance Check

Balance verification is performed entirely over Pedersen commitments using their homomorphic property. No actual values are revealed.

The two offers (guaranteed and fallible) are balanced separately:

- **Guaranteed offer**: For each token type, the sum of inputs minus outputs minus fees plus mints must be non-negative.
- **Fallible offer**: For each token type, the sum of inputs minus outputs plus mints must be non-negative.

Both must have a non-negative delta per token type to ensure no value is created from nothing.

## Proof Composition

### Verification Order

Proof verification proceeds in a defined order:

1. Verify each ZK proof independently
2. Verify Schnorr proofs for each contract interaction segment
3. Verify all proofs reference the same binding commitment
4. Verify homomorphic balance (non-negative delta per token type)
5. State-dependent checks (nullifier uniqueness, verifier key lookup) require ledger access

Steps 1-4 are stateless well-formedness checks. Step 5 requires state access, including looking up verifier keys for proof verification.

## Security Properties

### Unforgeability

Cannot create valid transaction without:
- Knowledge of spent coin secrets
- Valid Merkle paths
- Correct balance

### Non-Malleability

Cannot modify transaction:
- Changing any component invalidates the Pedersen binding
- Proofs bound to specific binding commitment
- Modified transaction = invalid proofs

### Atomicity

All-or-nothing execution:
- All components cryptographically linked
- Cannot execute partial transaction
- Either everything verifies, or nothing does

## Attack Prevention

### Value Injection Attack

**Attack**: Create value in a contract interaction segment.
**Prevention**: The Schnorr proof for each segment demonstrates knowledge of the binding randomness, preventing unauthorized value injection.

### Proof Reuse Attack

**Attack**: Reuse old proof in new transaction.
**Prevention**: Proofs are bound to a specific transaction binding commitment that includes fresh randomness. A proof from one transaction will not verify against a different binding.

### Double-Spend Attack

**Attack**: Spend same coin twice.
**Prevention**: Nullifier uniqueness enforced at the ledger level. Each coin produces a unique nullifier when spent; the ledger rejects duplicate nullifiers.
