---
name: core-concepts:architecture
description: Use when asking about Midnight transaction structure, system architecture, building blocks, how Zswap/Kachina/Impact components fit together, bindings, commitments, or Schnorr proofs.
---

# Midnight Architecture

Midnight combines ZK proofs, shielded tokens, and smart contracts into a unified privacy-preserving system. Understanding how pieces connect is essential for building applications.

## System Overview

```
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

> **Note**: "Kachina" is the academic research protocol name for Midnight's contract layer. It is not a user-facing component or product name.

## Transaction Anatomy

Every Midnight transaction contains:

```
Transaction {
  guaranteed_zswap_offer,    // Optional in API, required at protocol level for fees
  fallible_zswap_offer?,     // Optional: may-fail token ops
  contract_calls?,           // Optional: contract interactions
  schnorr_proof              // One per transaction
}
```

### Guaranteed vs Fallible

| Section | Behavior |
|---------|----------|
| Guaranteed | Must succeed, or entire tx rejected |
| Fallible | May fail without affecting guaranteed section |

**Use case**: Guaranteed section collects fees. Fallible section attempts swap. If swap fails, fees still collected.

**Subtlety**: The fallible Zswap offer's coin operations (commitments and nullifiers) are applied during the guaranteed phase. Only fallible contract call effects are rolled back on failure.

## Building Blocks

### 1. Zswap Offers

Token movement layer:

```
Offer {
  inputs: Coin[],      // Spent coins (nullifiers)
  outputs: Coin[],     // Created coins (commitments)
  transient: Coin[],   // Created and spent same tx
  balance: Map<Type, Value>  // Net value per token
}
```

### 2. Contract Calls

Computation layer. Each ContractCall contains both guaranteed and fallible transcripts (split via the `ckpt` opcode within a single call):

```
ContractCall {
  contract_address: ContractAddress,   // Bytes<32>
  entry_point: String,
  guaranteed_transcript: Transcript,
  fallible_transcript: Transcript,
  communication_commitment: Option<...>,  // Protocol field; cross-contract not yet available
  zk_proof: Proof
}
```

### 3. Cryptographic Binding

All components bound together via Pedersen commitments that are homomorphically combined:
- **Pedersen commitments** — Homomorphic value binding across all transaction components
- **Schnorr proof** — One lightweight ZK proof per transaction proving contract contribution carries no hidden value
- **ZK proofs** — Transcript validity (one per contract call)

## Transaction Integrity

### Homomorphic Commitments

Midnight extends Zswap's Pedersen commitment scheme:

```
Commitment(v1) + Commitment(v2) = Commitment(v1 + v2)
```

This allows verifying total value without revealing individual values.

### Binding Mechanism

Transaction binding uses homomorphic Pedersen commitments rather than a simple hash. Commitments from all components (Zswap offers, contract calls, proofs) are homomorphically combined, ensuring:

1. Zswap values balance (non-negative delta per token type)
2. Contract effects match proofs
3. All components cryptographically linked
4. No value created from nothing

## State Architecture

### Ledger Structure

```
Ledger {
  zswap_state: {
    commitment_tree: MerkleTree,
    commitment_tree_first_free: u32,
    commitment_set: Set<CoinCommitment>,
    nullifiers: Set<CoinNullifier>,
    commitment_tree_history: TimeFilterMap<MerkleTreeRoot>
  },
  contract_map: Map<ContractAddress, ContractState>
}
```

### Contract State

Contract state consists of an Impact state value plus a map of entry point names to operations (SNARK verifier keys):

```
ContractState {
  state: ImpactValue,                            // Impact state value
  operations: Map<String, SNARKVerifierKey>       // Entry point → verifier key
}
```

Contract Merkle trees are `MerkleTree(d)` Impact values with compile-time-fixed depth, stored as part of the Impact state.

## Execution Flow

### Transaction Processing

```
1. Well-formedness Check (stateless)
   ├─ Format validation
   ├─ ZK proof verification
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
   └─ Only contract call effects reverted on failure
```

### Balance Verification

The two offers are balanced separately with different adjustments:

```
Guaranteed offer:
  For each token type: sum(inputs) - sum(outputs) - fees + mints >= 0

Fallible offer:
  For each token type: sum(inputs) - sum(outputs) + mints >= 0

Both must have non-negative delta per token type.
```

Excess becomes the transaction fee paid to the network.

## Merging Transactions

Zswap enables atomic composition:

```
Tx1 (Party A)     Tx2 (Party B)
     ↓                 ↓
     └─────┬───────────┘
           ↓
    Merged Transaction
    (atomic, all-or-nothing)
```

### Merging Rules

- At least one tx must have empty contract calls
- Values must balance when combined
- Proofs remain independently valid

## Address Derivation

```
Contract Address = Hash(contract_state, nonce)
Token Type = Hash(contract_address, domain_separator)
Coin Commitment = Hash<(CoinInfo, ZswapCoinPublicKey)>
Nullifier = Hash<(CoinInfo, ZswapCoinSecretKey)>
```

## Component Integration

### How Tokens Flow

```
User Wallet                    Contract
    │                              │
    │ ──── Zswap Input ────────→  │  (spend coin)
    │                              │
    │ ←─── Zswap Output ───────── │  (receive coin)
    │                              │
    │ ──── Contract Call ──────→  │  (invoke logic)
```

### How Privacy Works

```
Private Domain          Public Domain
──────────────          ─────────────
User secrets     ──ZK Proof──→  Transcript
Local state                     State changes
Merkle paths                    Nullifiers
Witness data                    Commitments
```

## Practical Patterns

### Simple Value Transfer

```
1. Construct Zswap offer
   - Input: Your coin (create nullifier)
   - Output: Recipient coin (create commitment)
2. Delta must be non-negative (excess becomes fees)
3. Generate ZK proof
4. Submit transaction
```

### Contract Interaction

```
1. Prepare witness data (private inputs)
2. Construct contract call
3. Generate ZK proof (proves valid execution)
4. Optionally combine with Zswap offers
5. Submit transaction
```

### Atomic Swap

```
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

## Examples

Working patterns:
- **`examples/transaction-construction.md`** — Building transactions step by step
