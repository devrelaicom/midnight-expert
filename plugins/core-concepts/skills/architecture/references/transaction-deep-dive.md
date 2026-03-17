# Transaction Structure Deep Dive

## Complete Transaction Anatomy

```text
Transaction {
  // Always present; collects fees for all transaction phases
  guaranteed_zswap_offer: Offer,

  // Optional: May-fail Zswap offer
  fallible_zswap_offer: Option<Offer>,

  // Optional: Contract interactions
  contract_calls: Option<Vec<ContractCall>>,

  // Optional: Token mints
  mint: Option<AuthorizedMint>,

  // Binding randomness for the homomorphic Pedersen commitment
  binding_randomness: BindingRandomness
}
```

## Zswap Offer Details

### Offer Structure

```text
Offer {
  inputs: Vec<Input>,
  outputs: Vec<Output>,
  transient: Vec<TransientCoin>,
  deltas: Map<string, bigint>
}
```

### Input Components

```text
Input {
  // Public: Prevents double-spend
  nullifier: Bytes<32>,

  // Public: Type/value commitment for balance verification
  type_value_commit: Bytes<32>,

  // Optional: Contract that controls this coin
  contract_address: Option<ContractAddress>,

  // Merkle proof of coin existence
  merkle_root: Bytes<32>,
  merkle_path: Vec<Bytes<32>>,

  // ZK proof of valid spend
  zk_proof: Proof
}
```

### Output Components

```text
Output {
  // Public: New coin identifier
  commitment: Bytes<32>,

  // Public: For balance verification
  type_value_commit: Bytes<32>,

  // Optional: Target contract
  contract_address: Option<ContractAddress>,

  // Optional: Encrypted note for recipient
  ciphertext: Option<Bytes>,

  // ZK proof of valid creation
  zk_proof: Proof
}
```

## Contract Call Section

### Individual Call

Each ContractCall contains both guaranteed and fallible transcripts. The split between guaranteed and fallible is within each call (via the `ckpt` opcode), not between two separate call lists:

```text
ContractCall {
  // Target contract
  contract_address: ContractAddress,    // Bytes<32>

  // Entry point to invoke
  entry_point: String,

  // Effects that must succeed
  guaranteed_transcript: Transcript,

  // Effects that may fail without reverting guaranteed section
  fallible_transcript: Transcript,

  // Protocol field; cross-contract interaction not yet available
  communication_commitment: Option<Bytes<32>>,

  // ZK proof that execution produces transcripts
  zk_proof: Proof
}
```

### Contract Deploy

```text
ContractDeploy {
  // The compiled contract bytecode (Impact VM program)
  program: Program,

  // Initial contract state
  initial_state: ContractState,

  // ZK verification keys for the contract's circuits
  verifier_keys: Vec<VerifierKey>
}
```

Contract deploys are included alongside contract calls in the transaction's contract interactions segment.

## Transcript Structure

```text
Transcript {
  // Gas bound for execution
  gas_bound: u64,

  // Effects declaration
  effects: {
    // Nullifiers claimed (coins spent)
    claimed_nullifiers: Vec<CoinNullifier>,

    // Coin commitments received
    received_commitments: Vec<CoinCommitment>,

    // Coin commitments spent
    spent_commitments: Vec<CoinCommitment>,

    // Contract calls claimed
    contract_calls_claimed: Vec<ContractCallClaim>,

    // Token mints
    mints: Vec<MintInfo>
  },

  // The Impact program
  program: ImpactProgram
}
```

The ZK proof attests that the Impact program produces exactly the declared effects.

## Binding Mechanism

### Purpose

Transaction binding cryptographically links all transaction components:
- Prevents mix-and-match attacks
- Ensures atomic execution
- Provides transaction uniqueness

### How It Works

Transaction binding uses homomorphic Pedersen commitments. Commitments from all components — Zswap offers and contract calls — are homomorphically combined to produce a single binding commitment.

All proofs commit to this binding, preventing component substitution.

## Proof Relationships

```text
┌─────────────────────────────────────────────────┐
│                 Transaction                      │
├─────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐             │
│  │ Zswap Proofs│    │Contract Proofs│           │
│  │ • Input proofs│  │ • Per-call ZK proof│      │
│  │ • Output proofs│ │ • Transcript proof│       │
│  │ • Balance proof│ │                   │       │
│  └──────┬──────┘    └────────┬──────────┘       │
│         │                    │                   │
│         └────────┬───────────┘                   │
│                  ↓                               │
│         Schnorr Proof (one per tx)               │
│         (No hidden value in contract section)    │
└─────────────────────────────────────────────────┘
```

## Validation Order

### 1. Well-formedness Check (stateless)

This phase includes all proof verification:

**Structural Validation**:
- Canonical encoding
- Required fields present
- Size limits respected

**Proof Validation**:
- Zswap offer ZK proofs verify
- Schnorr proof verifies
- Proof-to-data binding correct

> **Note**: Contract call ZK proofs are verified in the **guaranteed phase**, not during well-formedness.

**Balance Validation**:
- Non-negative delta per token type (not equality)
- Homomorphic commitment check
- Guaranteed offer: subtract fees, add guaranteed mints
- Fallible offer: add fallible mints only

**Merkle Validation**:
- Input Merkle proofs valid
- Roots in valid set

**Nullifier Validation**:
- No nullifier in spent set
- No duplicate nullifiers in transaction

### 2. Guaranteed Execution (stateful)

- Contract operation lookups
- Zswap offer application
- Transcript execution
- State persistence

### 3. Fallible Execution (stateful, may fail)

- Similar to guaranteed
- Only contract call effects reverted on failure
- Fallible Zswap coin operations applied during guaranteed phase

## Fee Handling

```text
Fees paid via Zswap balance:

Guaranteed offer balance must satisfy:
  For each token type:
    sum(inputs) - sum(outputs) - fees + mints >= 0

Excess becomes the transaction fee paid to the network.
```

## Transaction Lifecycle

```text
1. Construction (User)
   └─ Build offers, calls, proofs

2. Submission
   └─ Broadcast to network

3. Mempool
   └─ Basic validation
   └─ Wait for block inclusion

4. Block Inclusion
   └─ Full validation
   └─ State application

5. Finalization
   └─ Confirmation depth reached
   └─ Effects permanent
```
