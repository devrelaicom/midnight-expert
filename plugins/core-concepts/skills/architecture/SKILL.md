---
name: core-concepts:architecture
description: This skill should be used when the user asks about Midnight network architecture, transaction structure, guaranteed vs fallible sections, Zswap/Kachina/Impact integration, ledger and state management, cryptographic binding (Pedersen commitments, Schnorr proofs, ZK-SNARKs), balance verification, nullifiers, address derivation, transaction merging, atomic swaps, fee handling, or the privacy model separating private and public domains.
version: 0.1.0
---

# Midnight Architecture

Midnight combines ZK proofs, shielded tokens, and smart contracts into a unified privacy-preserving system. Understanding how pieces connect is essential for building applications.

## System Overview

```text
┌─────────────────────────────────────────────────────────┐
│                    Midnight Network                      │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │   Zswap     │  │   Kachina   │  │   Impact    │     │
│  │  (Tokens)   │←→│ (Contracts) │←→│    (VM)     │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│         ↑                ↑                ↑             │
│         └────────────────┼────────────────┘             │
│                          │                              │
│              ┌───────────────────────┐                  │
│              │   ZK Proof System     │                  │
│              │   (ZK SNARKs)         │                  │
│              └───────────────────────┘                  │
└─────────────────────────────────────────────────────────┘
```

> **Note**: Kachina is the academic protocol underpinning Midnight's smart contract privacy model. It has its own documentation page and is referenced in developer-facing materials, though it is not a product name or SDK component.

## Transaction Anatomy

A Midnight transaction combines three concerns: token operations (via Zswap offers), smart contract interactions (via contract calls), and cryptographic binding that ties everything together. The transaction has a guaranteed section whose effects always persist and one or more fallible sections whose effects are rolled back if they fail. Fees are collected in the guaranteed section. The guaranteed Zswap offer is optional (not every transaction must include one), and fallible token operations are organized as a map keyed by contract interaction segment rather than a single optional block.

### Guaranteed vs Fallible

| Section | Behavior |
|---------|----------|
| Guaranteed | Must succeed, or entire tx rejected |
| Fallible | May fail without affecting guaranteed section |

**Use case**: Guaranteed section collects fees. Fallible section attempts swap. If swap fails, fees still collected.

**Subtlety**: Fallible coin operations (commitments and nullifiers) are validated during the guaranteed phase for well-formedness, but they are applied during their own fallible phase. If a fallible section fails, its coin operations are rolled back along with its contract call effects.

## Building Blocks

### 1. Zswap Offers

The token movement layer. Each offer describes a set of coins being spent (which produce nullifiers), a set of new coins being created (which produce commitments), any transient coins that are created and consumed within the same transaction, and a per-token-type net value delta that must balance across the transaction.

### 2. Contract Calls

The computation layer. Each contract interaction targets a specific contract address and entry point. It carries both a guaranteed transcript and a fallible transcript (split via the checkpoint opcode within a single call). A ZK proof accompanies each call, proving the transcripts are valid.

### 3. Cryptographic Binding

Three complementary cryptographic guarantees ensure transaction integrity:
- **Pedersen commitments** — Bind and link all transaction components via homomorphic value commitments
- **Schnorr proofs** — Each contract interaction segment carries a Schnorr proof binding its effects to the transaction, ensuring that the token values contributed by that segment balance correctly
- **ZK-SNARK proofs** — Prove transcript validity for each contract call (coin ownership, state transitions)

## Transaction Integrity

### Homomorphic Commitments

Midnight extends Zswap's Pedersen commitment scheme:

```text
Commitment(v1) + Commitment(v2) = Commitment(v1 + v2)
```

This allows verifying total value without revealing individual values.

### Binding Mechanism

Transaction binding uses homomorphic Pedersen commitments rather than a simple hash. Commitments from all components (Zswap offers and contract calls) are homomorphically combined, ensuring values balance, effects match proofs, and no value is created from nothing. See `references/cryptographic-binding.md` for detailed binding mechanics.

## State Architecture

### Ledger Structure

The ledger maintains two primary areas of state. The Zswap state consists of an append-only Merkle tree of coin commitments, a set of spent nullifiers that prevents double-spending, and a time-windowed history of recent Merkle roots so that slightly stale proofs remain valid. The contract map stores each deployed contract's state and verification keys, keyed by contract address.

### Contract State

Each contract stores its current state data (managed by the Impact VM) and a set of verification keys for its entry points. Contract Merkle trees are Impact values whose depth is determined at runtime, stored as part of the contract's state.

## Execution Flow

### Transaction Processing

```text
1. Well-formedness Check
   ├─ Format validation
   ├─ ZK proof verification (requires state access to look up verifier keys)
   ├─ Schnorr proof verification
   ├─ Balance verification
   └─ Claim matching

2. Guaranteed Execution (stateful)
   ├─ Contract operation lookups
   ├─ Zswap offer application
   ├─ Transcript execution
   └─ State persistence

3. Fallible Execution (stateful, may fail)
   ├─ Similar to guaranteed
   └─ All fallible effects (coin ops and contract calls) reverted on failure
```

### Balance Verification

The two offers are balanced separately with different adjustments:

```text
Guaranteed offer:
  For each token type: sum(inputs) - sum(outputs) - fees + mints >= 0

Fallible offer:
  For each token type: sum(inputs) - sum(outputs) + mints >= 0

Both must have non-negative delta per token type.
```

Excess becomes the transaction fee paid to the network.

## Merging Transactions

Zswap enables atomic composition:

```text
Tx1 (Party A)     Tx2 (Party B)
     ↓                 ↓
     └─────┬───────────┘
           ↓
    Merged Transaction
    (atomic, all-or-nothing)
```

### Merging Rules

- Coin sets must not overlap (no shared inputs or outputs)
- Combined values must balance across all token types
- Proofs remain independently valid

**Why contract calls cannot be merged:** Each contract call includes its own ZK proof bound to a specific transcript. Combining two independent contract call transcripts would require a new proof that neither party can generate unilaterally, since each proof depends on private witness data known only to its creator.

## Address Derivation

**Contract address**: Derived by hashing the contract's initial state together with a nonce, producing a unique identifier for each deployed contract instance.

**Token type**: Derived by hashing the domain separator first, followed by the contract address. This identifies a specific token issued by a given contract.

**Coin commitment**: Derived by hashing the coin's information (value, type) together with the owner's public key. This represents a coin in the commitment tree while hiding its value and owner.

**Nullifier**: Derived by hashing the coin's information together with the owner's secret key. This prevents double-spending while remaining unlinkable to the original commitment.

## Component Integration

### How Tokens Flow

```text
User Wallet                    Contract
    │                              │
    │ ──── Zswap Input ────────→  │  (spend coin)
    │                              │
    │ ←─── Zswap Output ───────── │  (receive coin)
    │                              │
    │ ──── Contract Call ──────→  │  (invoke logic)
```

### How Privacy Works

```text
Private Domain          Public Domain
──────────────          ─────────────
User secrets     ──ZK Proof──→  Transcript
Local state                     State changes
Merkle paths                    Nullifiers
Witness data                    Commitments
```

## Practical Patterns

### Simple Value Transfer

```text
1. Construct Zswap offer
   - Input: Your coin (create nullifier)
   - Output: Recipient coin (create commitment)
2. Delta must be non-negative (excess becomes fees)
3. Generate ZK proof
4. Submit transaction
```

### Contract Interaction

```text
1. Prepare witness data (private inputs)
2. Construct contract call
3. Generate ZK proof (proves valid execution)
4. Optionally combine with Zswap offers
5. Submit transaction
```

### Atomic Swap

```text
1. Party A: Create partial offer (gives TokenX)
2. Party B: Create partial offer (gives TokenY, wants TokenX)
3. Merge offers off-chain
4. Submit merged transaction
5. Both transfers atomic
```

## References

For detailed technical information:
- **`references/transaction-deep-dive.md`** — Complete transaction structure
- **`references/state-management.md`** — Ledger operations, state transitions
- **`references/cryptographic-binding.md`** — Pedersen, Schnorr, proof composition
