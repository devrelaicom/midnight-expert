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

Every Midnight transaction contains:

```text
Transaction {
  guaranteed_zswap_offer,    // Always present; collects fees for all transaction phases
  fallible_zswap_offer?,     // Optional: may-fail token ops
  contract_calls_or_deploys?, // Optional: contract interactions or deployments
  binding_randomness         // Opens the homomorphic Pedersen commitment
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

```text
Offer {
  inputs: Coin[],      // Spent coins (nullifiers)
  outputs: Coin[],     // Created coins (commitments)
  transient: Coin[],   // Created and spent same tx
  deltas: Map<Type, Value>   // Net value per token
}
```

### 2. Contract Calls

Computation layer. Each ContractCall contains both guaranteed and fallible transcripts (split via the `ckpt` opcode within a single call):

```text
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

Three complementary cryptographic guarantees ensure transaction integrity:
- **Pedersen commitments** — Bind and link all transaction components via homomorphic value commitments
- **Schnorr proof** — One lightweight ZK proof per transaction proving the contract section contributes zero net value
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

```text
Ledger {
  zswap_state: {
    commitment_tree: MerkleTree,
    commitment_tree_first_free: u32,
    nullifiers: Set<CoinNullifier>,
    commitment_tree_history: Set<MerkleTreeRoot>
  },
  contract_map: Map<ContractAddress, ContractState>
}
```

### Contract State

Contract state consists of an Impact state value plus a map of entry point names to operations (SNARK verifier keys):

```text
ContractState {
  state: ImpactValue,                            // Impact state value
  operations: Map<String, SNARKVerifierKey>       // Entry point → verifier key
}
```

Contract Merkle trees are `MerkleTree(d)` Impact values with compile-time-fixed depth, stored as part of the Impact state.

## Execution Flow

### Transaction Processing

```text
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

- At least one tx must have empty contract calls
- Values must balance when combined
- Proofs remain independently valid

**Why contract calls cannot be merged:** Each contract call includes its own ZK proof bound to a specific transcript. Combining two independent contract call transcripts would require a new proof that neither party can generate unilaterally, since each proof depends on private witness data known only to its creator.

## Address Derivation

```text
Contract Address = Hash(contract_state, nonce)
```
Uniquely identifies a deployed contract instance.

```text
Token Type = Hash(contract_address, domain_separator)
```
Identifies a specific token issued by a contract.

```text
Coin Commitment = Hash<(CoinInfo, CoinPublicKey)>
```
Represents a coin in the commitment tree (hides value and owner).

```text
Nullifier = Hash<(CoinInfo, CoinSecretKey)>
```
Prevents double-spending of a coin (unlinkable to the original commitment).

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

## Examples

Working patterns:
- **`examples/transaction-construction.md`** — Building transactions step by step
