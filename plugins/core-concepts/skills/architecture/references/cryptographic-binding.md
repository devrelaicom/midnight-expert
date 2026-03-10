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

**Structure**:
```
Commit(v) = v·G + r·H
```

**Properties**:
- **Hiding**: Cannot determine v from commitment
- **Binding**: Cannot find different v' with same commitment
- **Homomorphic**: Commit(a) + Commit(b) = Commit(a+b)

**Usage in Midnight**:
```
Coin commitment = Hash<(CoinInfo, ZswapCoinPublicKey)>
Balance verification via homomorphic Pedersen value commitments
```

### 2. Schnorr Proof

One Schnorr proof per transaction. This is a lightweight ZK proof variant (not a separate category from ZK proofs) used to prove contract sections don't inject hidden value.

**What it proves**:
"The contract contribution to this transaction has zero net value."

**Why needed**:
Without this, contracts could create value from nothing by hiding it in their section.

**Structure**:
```
SchnorrProof {
  commitment: Point,    // What we're proving about
  challenge: Scalar,    // Fiat-Shamir challenge
  response: Scalar      // Proof response
}
```

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

Transaction binding uses homomorphic Pedersen commitments rather than a simple hash construction. Commitments from all transaction components — Zswap offers, contract calls, and proofs — are homomorphically combined to produce a single binding commitment.

This approach preserves the homomorphic property needed for balance verification while cryptographically linking all components together.

### What Each Component Binds

| Component | Binds To |
|-----------|----------|
| Input proofs | Specific nullifier, Merkle root, transaction binding |
| Output proofs | Specific commitment, transaction binding |
| Contract proofs | Specific transcript, transaction binding |
| Schnorr proof | Contract value vector, transaction binding |

## Balance Verification

### Homomorphic Balance Check

The two offers are balanced separately with different adjustments:

```
Guaranteed offer:
  For each token type t:
    sum(inputs[t]) - sum(outputs[t]) - fees[t] + mints[t] >= 0

Fallible offer:
  For each token type t:
    sum(inputs[t]) - sum(outputs[t]) + mints[t] >= 0
```

Both must have a non-negative delta per token type. No actual values are revealed — verification is performed over Pedersen commitments using their homomorphic property.

### Multi-Asset Balancing

```
For each offer, per token type:
  delta[type] = sum(inputs) - sum(outputs) + adjustments

For valid transaction:
  ∀ type: delta[type] >= 0  (non-negative)
```

## Proof Composition

### How Proofs Link Together

```
┌─────────────────────────────────────────────┐
│              Transaction                     │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │       Pedersen Binding               │   │
│  │                │                     │   │
│  │    ┌──────────┼──────────┐          │   │
│  │    ↓          ↓          ↓          │   │
│  │ Input     Output    Contract        │   │
│  │ Proofs    Proofs    Proofs          │   │
│  │    │          │          │          │   │
│  │    └──────────┴──────────┘          │   │
│  │              │                       │   │
│  │              ↓                       │   │
│  │       Schnorr Proof                  │   │
│  │    (balance verification)            │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### Verification Order

All proof verification happens during the well-formedness check (stateless phase):

1. Verify each ZK proof independently
2. Verify the Schnorr proof
3. Verify all proofs reference the same binding
4. Verify homomorphic balance (non-negative delta per token type)
5. Transaction is well-formed

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

### Mix-and-Match Attack

**Attack**: Take input proof from Tx1, output from Tx2.
**Prevention**: Both proofs commit to different transaction bindings.

### Value Injection Attack

**Attack**: Create value in contract section.
**Prevention**: Schnorr proof ensures zero net contract value.

### Proof Reuse Attack

**Attack**: Reuse old proof in new transaction.
**Prevention**: Proofs bound to specific transaction binding including fresh randomness.

### Double-Spend Attack

**Attack**: Spend same coin twice.
**Prevention**: Nullifier uniqueness + set membership check.
