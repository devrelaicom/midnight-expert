# State Management

## Global State Structure

The global ledger state consists of two parts:

- **Zswap state** — tracks coin commitments and nullifiers for shielded token operations
- **Contract map** — stores each deployed contract's current data and its verification keys, indexed by contract address

## Zswap State

### Components

The Zswap state maintains four components that together enable shielded token transfers:

- **Commitment tree** — an append-only Merkle tree containing all coin commitments ever created. New commitments are always appended at the next available position; existing entries are never modified or removed.

- **Next free position** — a running index that tracks the next available slot in the commitment tree. It increments by one each time a new commitment is inserted.

- **Nullifier set** — a permanent, append-only set of all spent coin nullifiers. Once a nullifier is added, it can never be removed. This prevents double-spending: a coin can only be spent once because its nullifier can only appear in this set once.

- **Recent Merkle roots** — a time-windowed set of recent commitment tree roots. When the tree changes, the new root is recorded here. Old roots expire after a configurable number of blocks.

### Commitment Tree Operations

**Insert (new coin created)**:

1. Compute the commitment by hashing the coin information and public key
2. Insert the commitment at the next free position in the tree
3. Advance the next-free-position index
4. Recompute the Merkle root
5. Record the new root in the recent roots set

**Verify (coin exists)**:

1. Receive the commitment, a Merkle path, and a claimed root
2. Confirm the claimed root appears in the recent roots set
3. Verify the Merkle path connects the commitment to the claimed root

### Nullifier Set Operations

**Check (not spent)**:

1. Compute the nullifier by hashing the coin information and the owner's secret key
2. Confirm the nullifier does not already appear in the nullifier set

**Insert (mark spent)**:

1. Add the nullifier to the set
2. The nullifier can never be added again — any future transaction attempting to reuse it will be rejected

### Recent Merkle Roots

The recent roots set exists for practical usability:

- Users who constructed a Merkle path a few blocks ago can still spend their coins even though the tree has since changed
- Concurrent transactions that both modify the tree do not invalidate each other's proofs
- The window covers a configurable number of recent blocks; roots older than the window are expired

## Contract State

### Structure

Each deployed contract stores two things:

- **State data** — the contract's current ledger values, as defined by its Compact source code. This includes any Merkle trees declared in the contract; they are part of the contract's own state, not separate top-level structures.
- **Verification keys** — one key per circuit entry point, used by the network to verify zero-knowledge proofs submitted with transactions

### Contract Address

A contract address is a 32-byte hash derived from the contract's initial state and a nonce, making each deployment unique.

## State Transitions

### Atomic Updates

All state changes within a single transaction are atomic: either every change applies, or none of them do. There is no partial application.

### Contract State Update Flow

1. Load the contract's current state
2. Execute the contract's circuit with the transaction inputs
3. Compute the resulting effects
4. Verify the computed effects match the effects declared in the proof
5. Apply the declared effects to produce the new state
6. Store the new state

### Zswap State Update Flow

For each new coin output in the transaction, the commitment is inserted into the commitment tree.

For each coin input in the transaction, the nullifier is checked against the nullifier set to confirm the coin has not been spent, then the nullifier is added to the set.

## State Consistency

### Cross-Component Consistency

Zswap and contract states must be consistent:
- Coins received by contracts match Zswap outputs
- Coins sent by contracts match Zswap inputs
- Values balance across both

### Proof Binding

ZK proofs bind:
- Private inputs to public effects
- Zswap operations to contract operations
- All components to transaction binding

## State Pruning

### What Can Be Pruned

- **Recent Merkle roots** — old roots expire after the configured window passes
- **Historical contract states** — only the current state is needed; past versions can be discarded

### What Cannot Be Pruned

- **Nullifier set** — must persist forever to prevent double-spending
- **Current contract states** — needed for ongoing operation
- **Commitment tree** — the full tree must be retained so that Merkle paths can be verified

## State Queries

### User Perspective

Users need to:
1. Track their own coins (commitments they own)
2. Generate Merkle paths for spending
3. Monitor for incoming coins (encrypted outputs)

### Node Perspective

Nodes maintain:
1. Full current state (all components)
2. Ability to verify any transaction
3. State proofs for light clients
