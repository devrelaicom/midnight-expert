# Execution Semantics

How Midnight transactions execute, from submission to finalization. Covers the three-phase execution model, state transitions, and concurrency.

## Transaction Lifecycle

```
User submits transaction
  → Phase 1: Well-Formedness (stateless validation)
  → Phase 2: Guaranteed (stateful, always persists)
  → Phase 3: Fallible (stateful, may revert)
  → Final state committed
```

## Phase 1: Well-Formedness (Stateless)

Every node validates the transaction without accessing ledger state:

1. **Verify ZK proof** against the circuit verification key -- confirms private computation was performed correctly
2. **Verify Schnorr proof** for the transaction's zero-value contribution (one proof per transaction, Fiat-Shamir transformed)
3. **Check structural validity** -- correct format, valid bytecodes, properly encoded fields
4. **Validate token type consistency** -- token types in offers match declared types

This phase is stateless: it does not read from or write to the ledger. A transaction that fails well-formedness is rejected immediately and never touches state.

**Key fact**: ZK proof verification happens here, not in the guaranteed phase. By the time the guaranteed phase runs, the proof has already been validated.

## Phase 2: Guaranteed (Stateful)

The Impact VM executes the guaranteed transcript against the current ledger state. Effects from this phase **always persist**, even if phase 3 fails:

1. **Contract lookup** -- locate contract state on the ledger
2. **Execute Impact program** -- run the bytecode, which replays public state changes
3. **Verify effect matching** -- confirm declared effects (nullifiers, commitments, mints) match actual execution results
4. **Collect fees** -- deduct transaction fees from the guaranteed Zswap offer
5. **Process guaranteed token operations** -- handle the guaranteed Zswap offer (inputs, outputs, mints)

If the guaranteed phase fails (e.g., contract not found, effect mismatch), the entire transaction is rejected.

## Phase 3: Fallible (Stateful)

An optional phase for operations that may fail due to concurrent state changes:

1. **Execute fallible Impact program** -- run the fallible transcript's bytecode
2. **Process fallible token operations** -- handle the fallible Zswap offer

### Fallible Failure Behavior

- Fallible failure does **NOT** revert guaranteed phase effects
- Guaranteed effects persist regardless of fallible outcome
- Fees are forfeited on fallible failure (they were already collected in guaranteed phase)
- Only the fallible effects themselves are reverted

This two-phase design allows contracts to separate critical operations (guaranteed) from optimistic operations (fallible).

## State Transition Model

### Ledger State

Each contract has an `ImpactStateValue` plus a map of entry points to verification keys:

```
ContractState = ImpactStateValue + Map<EntryPoint, ContractOperation>
ContractOperation = SnarkVerifierKey
```

The Impact VM manipulates the `ImpactStateValue` directly. The verification keys are used in phase 1 (well-formedness) to validate ZK proofs.

### Zswap State

The global Zswap state tracks token commitments and nullifiers:

```
ZswapState:
  commitment_tree: MerkleTree          -- all coin commitments
  commitment_tree_first_free: u32      -- next free slot index
  commitment_set: Set                  -- prevents duplicate commitments
  nullifiers: Set                      -- spent coin nullifiers
  commitment_tree_history: TimeFilterMap -- historic roots for proof validity
```

### Zswap State Update (Pseudocode)

```
For each transaction:
  // Process inputs (spending coins)
  for each input nullifier:
    assert(!nullifiers.member(nullifier))  // prevent double-spend
    nullifiers.insert(nullifier)

  // Process outputs (creating coins)
  for each output commitment:
    assert(!commitment_set.member(commitment))  // prevent duplicates
    commitment_tree.insert(commitment)
    commitment_set.insert(commitment)
    commitment_tree_first_free += 1

  // Verify balance
  assert(offer_is_balanced)  // inputs + mints >= outputs + fees
```

Note: `.member()` is the correct method on Set, not `.contains()`.

## Effects Object

Each transcript declares its expected effects:

- **Claimed nullifiers** -- coins being spent
- **Received commitments** -- new coins being created
- **Spent commitments** -- existing commitments being consumed
- **Contract calls** -- other contracts being invoked
- **Mints** -- new tokens being created

The VM verifies that actual execution produces exactly these effects. Any mismatch causes failure.

## Contract Call Execution

### Sequential Processing

Contract calls within a transaction execute sequentially:

```
Transaction with calls [C1, C2, C3]:
  Execute C1 → checkpoint state
  Execute C2 → checkpoint state
  Execute C3 → checkpoint state
  Commit all changes
```

Each call sees the state changes from previous calls in the same transaction.

### Checkpoints

Between contract calls, the VM creates a checkpoint. If a subsequent call fails in the fallible phase, the checkpoint allows partial rollback (only the failed call's fallible effects are reverted, not guaranteed effects).

### Transaction Structure

Each `ContractCall` declares both a `guaranteed_transcript` and a `fallible_transcript`:

```
ContractCall:
  guaranteed_transcript:
    gas_bound: u64
    effects: EffectsObject
    program: ImpactBytecode
  fallible_transcript:
    gas_bound: u64
    effects: EffectsObject
    program: ImpactBytecode
```

Both transcripts are part of the same call structure, not separate lists.

## Concurrency

### Block-Level Parallelism

Multiple transactions in a block can be processed in parallel if:

- They share no Zswap UTXOs (no conflicting nullifiers or commitments)
- They operate on different contracts

### Cross-Contract Calls

Cross-contract calls are **not yet fully implemented** in the current version of Compact. When they become available, contracts that call each other will need to be processed sequentially.

### Conflict Resolution

When two transactions conflict (e.g., both try to spend the same UTXO), one succeeds and the other fails. The block producer determines ordering.

## Gas Model

Every Impact VM operation has a fixed gas cost. Each transcript declares a gas bound:

- If execution exceeds the declared gas bound, the transcript fails
- Gas costs for storage operations are still being finalized and may change
- The gas model ensures deterministic execution costs

## Design Guidelines

### Guaranteed vs Fallible

| Put in Guaranteed | Put in Fallible |
|-------------------|-----------------|
| Fee payment | Token swaps |
| Core state updates | Balance checks against external state |
| Nullifier insertions | Operations depending on volatile state |
| Critical authorization | Optimistic operations |

### State Access Patterns

- Minimize ledger reads/writes -- each operation adds to the public transcript
- Batch related operations in a single circuit call
- Use `Counter` for numeric state that needs concurrent-safe updates
- Use `HistoricMerkleTree` when proofs must survive concurrent insertions
