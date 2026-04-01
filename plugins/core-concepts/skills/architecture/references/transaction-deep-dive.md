# Transaction Structure Deep Dive

## Complete Transaction Anatomy

A Midnight transaction combines token operations, contract interactions, and cryptographic binding into an atomic unit. A transaction optionally includes a guaranteed Zswap offer, one or more fallible Zswap offers (organized per segment), contract calls, and authorized mints. A binding randomness value cryptographically ties all components together via homomorphic Pedersen commitments.

## Zswap Offer Details

A Zswap offer contains inputs (coins being spent), outputs (new coins being created), transient coins (intermediate coins created and consumed within the same transaction), and deltas (per-token-type balance adjustments).

### What an Input Does

An input represents a coin being spent. The spender provides a nullifier (proving ownership without revealing which coin), evidence the coin exists in the commitment tree, and a value commitment for balance checking. The nullifier prevents double-spending by being recorded on-chain — if the same nullifier appears again, the spend is rejected.

### What an Output Does

An output represents a new coin being created. It carries a commitment hiding the coin's value and owner, a value commitment for balance checking, and optionally encrypted data so the recipient can discover the coin. The commitment scheme ensures that observers cannot determine the coin's value or intended recipient.

## Contract Call Section

A contract call targets a specific contract entry point. It carries guaranteed and fallible transcripts separated by a checkpoint boundary (via the `ckpt` opcode in Compact), plus a ZK proof attesting that the declared effects match actual contract execution. The split between guaranteed and fallible is within each call, not between two separate call lists.

### Contract Deploy

A contract deploy packages the compiled contract program (Impact VM bytecode), initial contract state, and ZK verification keys needed for later proof verification. Deploys are included alongside contract calls in the transaction's contract interactions segment.

## Transcript Structure

A transcript is the public record of claimed contract execution effects. It declares a gas budget for metering execution cost, lists coin operations to perform (nullifiers to claim, commitments to create), and includes the contract program for on-chain re-execution and verification. The ZK proof accompanying the contract call attests that the Impact program produces exactly the declared effects.

## Binding Mechanism

### Purpose

Transaction binding cryptographically links all transaction components:
- Prevents mix-and-match attacks (swapping one component for another)
- Ensures atomic execution of the entire transaction
- Provides transaction uniqueness

### How It Works

Transaction binding uses homomorphic Pedersen commitments. Commitments from all components — Zswap offers and contract calls — are homomorphically combined to produce a single binding commitment. A Schnorr signature over this binding value proves that no hidden value is smuggled through the contract section. All proofs commit to this binding, preventing component substitution.

## Validation Order

### 1. Well-formedness Check

This phase validates structure and verifies all proofs:

**Structural Validation**:
- Canonical encoding verified
- Required components present
- Size limits respected

**Proof Validation**:
- Zswap offer ZK proofs verify
- Contract call ZK proofs verify (via op_check, which requires state access for contract lookup)
- Schnorr binding signature verifies
- Proof-to-data binding correct

**Balance Validation**:
- Non-negative delta per token type (excess becomes the fee)
- Homomorphic commitment check
- Guaranteed offer: subtract fees, add guaranteed mints
- Fallible offer: add fallible mints only

**Merkle Validation**:
- Input Merkle proofs valid against the commitment tree
- Roots in valid set

**Nullifier Validation**:
- No nullifier already in spent set
- No duplicate nullifiers within transaction

### 2. Guaranteed Execution (stateful)

- Contract state lookups
- Zswap offer application
- Transcript execution
- State persistence (always committed)

### 3. Fallible Execution (stateful, may fail)

- Similar to guaranteed phase
- Each fallible segment's effects (both coin operations and contract calls) are applied only if that segment succeeds
- If a fallible segment fails, all its effects are discarded — guaranteed phase effects are unaffected

## Fee Handling

Transaction fees are paid in DUST and handled at the protocol level. There is no explicit fee field in the transaction structure. The balance mechanism ensures non-negative deltas per token type, with the fee accounting occurring in the DUST token dimension.

## Transaction Lifecycle

1. **Construction** — User builds offers, contract calls, and generates ZK proofs off-chain
2. **Submission** — Transaction broadcast to the network
3. **Mempool** — Basic validation while waiting for block inclusion
4. **Block Inclusion** — Full validation and state application in guaranteed/fallible phases
5. **Finalization** — Confirmation depth reached; effects become permanent
