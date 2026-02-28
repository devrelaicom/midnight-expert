---
name: compact-transaction-model
description: This skill should be used when the user asks about Midnight transaction execution, guaranteed vs fallible phases, kernel.checkpoint(), transaction composition, state conflicts, DUST fees, gas limits, proof verification, partial transaction success, transaction merging, atomic swaps, or how Compact circuits map to on-chain execution. Also triggered by mentions of "transaction semantics", "fallible phase", "guaranteed phase", "checkpoint", "well-formedness", "Impact VM", "Zswap offers", or "transaction merging".
---

# Compact Transaction Model & Execution Semantics

This skill covers how Compact circuits map to on-chain transaction execution: the three-stage lifecycle (well-formedness, guaranteed, fallible), `kernel.checkpoint()` placement, transaction composition, merging for atomic swaps, the state model, and the fee/gas system. For contract anatomy and circuit/witness design, see `compact-structure`. For ledger ADT types and state design, see `compact-ledger`. For token minting, sending, and receiving, see `compact-tokens`.

## Transaction Lifecycle Overview

Every Midnight transaction passes through three sequential stages. Failure at each stage has different consequences.

| Stage | Type | What Happens | On Failure |
|-------|------|--------------|------------|
| Well-formedness | Stateless | ZK proofs in Zswap offers verified, Schnorr proof on contract section verified, guaranteed offer balanced (minus fees, plus mints), fallible offer balanced, coin claims checked for uniqueness | Transaction rejected entirely |
| Guaranteed phase | Stateful | Contract verifier keys looked up, ZK proofs verified against them, fees collected for ALL phases, Zswap offers applied (commitments inserted, nullifiers checked), guaranteed transcripts executed | Transaction rejected (not included in ledger) |
| Fallible phase | Stateful | Fallible transcripts executed, contract state stored if "strong", contract deployments applied | Partial success -- guaranteed effects still apply, fees still consumed |

Execution flow from the developer's perspective:

```
Compact circuit call
  -> Proof generation (client-side)
    -> Well-formedness check (stateless validation)
      -> Guaranteed phase (proof verification, fees, Zswap)
        -> Fallible phase (contract state mutations)
          -> State update (if "strong")
```

The key insight: a transaction that fails in the fallible phase is a **partial success**, not a full rejection. The guaranteed-phase effects (fee collection, Zswap coin movements, guaranteed transcript operations) persist on the ledger. Only the fallible section's effects are rolled back.

## Guaranteed vs Fallible Phases

### Guaranteed Phase

Operations in the guaranteed phase either all succeed or the transaction is not included in the ledger at all.

| What Executes in Guaranteed | Details |
|-----------------------------|---------|
| ZK proof verification | Contract call proofs verified against stored verifier keys |
| Fee collection | Fees for the ENTIRE transaction (both phases) collected here |
| Zswap offer application | Coin commitments inserted into Merkle tree, nullifiers added to nullifier set, Merkle roots validated |
| Guaranteed transcripts | Impact programs from guaranteed section of each contract call |
| Fallible Zswap pre-check | Fallible Zswap section also applied during guaranteed phase to prevent it from invalidating the fallible section alone |

### Fallible Phase

Operations in the fallible phase may fail without reversing guaranteed-phase effects.

| What Executes in Fallible | Details |
|---------------------------|---------|
| Fallible transcripts | Impact programs from the fallible section of each contract call |
| Contract deployments | New contract creation executes entirely in the fallible phase |
| State storage | Contract state written to ledger only if marked "strong" |

### Key Rules

- Fees for ALL phases are collected in the guaranteed phase. If the fallible phase fails, fees are still consumed (forfeited).
- ZK proofs are verified only in the guaranteed phase.
- Contract deployments execute entirely in the fallible phase. A deployment failure is a partial success: fees are spent but the contract is not created.
- If a circuit contains no `kernel.checkpoint()` call, the entire circuit body maps to the guaranteed phase only. There is no fallible section.

## kernel.checkpoint()

`kernel.checkpoint()` splits a circuit into guaranteed and fallible sections. Everything before the call executes in the guaranteed phase; everything after executes in the fallible phase. It maps to the `ckpt` opcode in the Impact VM.

```compact
export circuit transfer(to: Bytes<32>, amount: Uint<64>): [] {
  // --- GUARANTEED PHASE ---
  // These operations are atomic: all succeed or the transaction is rejected
  const current = balance.lookup(disclose(own_address));
  assert(disclose(current >= amount), "Insufficient balance");
  counter.increment(1);

  kernel.checkpoint();

  // --- FALLIBLE PHASE ---
  // These operations may fail without reversing the guaranteed phase
  balance.insert(disclose(own_address), disclose(current - amount));
  balance.insert(disclose(to), disclose(balance.lookup(disclose(to)) + amount));
}
```

### Checkpoint Rules

| Rule | Detail |
|------|--------|
| At most one per circuit | A circuit can contain zero or one `kernel.checkpoint()` calls |
| Determines phase boundary | Code before checkpoint = guaranteed; code after = fallible |
| No checkpoint = guaranteed-only | Without `kernel.checkpoint()`, the entire circuit body is guaranteed |
| Maps to `ckpt` opcode | Compiles to a single Impact VM instruction that marks the phase boundary |
| No jumps across boundary | The `ckpt` boundary must not be crossed by jump instructions in the compiled Impact program |

### When to Use checkpoint

Place `kernel.checkpoint()` when you need operations that:
- Depend on state that may conflict with concurrent transactions
- Perform complex state mutations that you can tolerate failing
- Deploy contracts as part of a larger workflow

Keep critical invariants (authorization checks, fee collection, proof-dependent logic) **before** the checkpoint in the guaranteed section.

## Transaction Composition

A single Midnight transaction can contain multiple contract calls or deployments. These execute sequentially.

| Property | Behavior |
|----------|----------|
| Sequential execution | Each call sees state changes from previous calls in the same transaction |
| Mixed calls and deploys | A transaction can contain both contract calls and contract deployments |
| Deployment fallibility | Contract deployments are always fallible-phase operations |
| Binding commitment | A cryptographic binding commitment ties all contract calls to the transaction, preventing tampering |
| Schnorr proof | A Schnorr proof binds the contract call section and ensures it carries no hidden value |

Cross-contract calls (one contract calling another contract's circuit within the same execution) are not yet available. To compose operations across contracts, include multiple contract calls in a single transaction. Each call executes independently against its own contract state, but within the shared transaction context.

## Transaction Merging

Midnight supports transaction merging to enable atomic swaps and multi-party transactions.

| Property | Rule |
|----------|------|
| Merge condition | Two transactions can merge if at least one has an empty contract call section |
| Composite result | The merged transaction has the combined effects of both input transactions |
| Integrity | Pedersen commitment binding ensures each party's funds are spent as originally intended |
| Homomorphic summing | Commitment values are homomorphically summed before composite integrity check |
| Opening knowledge | Only the original creators know the opening randomnesses needed to decompose the transaction |

### Atomic Swap Pattern

Transaction merging enables atomic swaps: Alice creates a transaction spending her coins, Bob creates a transaction spending his coins, and the two merge into a single atomic transaction. Because at least one party's transaction has no contract calls, the merge is valid. The Pedersen commitment binding guarantees neither party can alter the other's contribution.

## State Model

Each contract on Midnight maintains state as two components:

| Component | Description |
|-----------|-------------|
| Impact state value | The contract's data (maps, arrays, cells, Merkle trees) stored as an Impact VM state value |
| Entry point map | A map from entry point names to verifier keys, selecting which ZK proof to verify for each circuit |

### State Lifecycle During Execution

1. The contract's current state is loaded from the ledger before each call.
2. A context object (contract address, newly allocated coins, block time, block hash) and an empty effects set are placed on the Impact VM stack alongside the state.
3. The Impact program executes, mutating the state on the stack.
4. If the resulting state is "strong" (not tainted by weak/transient data), it is stored as the contract's updated state. If the state is "weak" (tainted by context or effects data), the transaction fails.
5. The resulting effects are compared to the declared effects in the transcript; mismatches cause failure.

### Concurrency and Conflicts

- Multiple transactions in the same block that touch the same contract are ordered sequentially.
- A transaction that reads or writes state a concurrent transaction also modifies may conflict.
- Practical advice: use append-only data structures (Merkle trees, counters, sets with insert-only patterns) to minimize conflict windows. Avoid read-modify-write patterns on shared mutable state when possible.

## Fees & Gas

DUST is Midnight's fee token. It is a shielded, non-transferable resource derived from NIGHT.

| Property | Detail |
|----------|--------|
| DUST source | Generated over time from held NIGHT UTXOs; value grows to a cap, decays when NIGHT is spent |
| Non-transferable | DUST can only be spent on fees, never sent to another user |
| Gas bound | Each contract call transcript declares a gas bound limiting Impact VM execution |
| Gas to fee | The gas bound is converted to a DUST fee via dynamic, multi-dimensional pricing |
| SyntheticCost dimensions | `read_time`, `compute_time`, `block_usage`, `bytes_written`, `bytes_churned` |
| Dynamic pricing | Per-dimension price factors adjust toward 50% block fullness; a global scalar further adjusts overall cost |
| Collection timing | Fees for ALL phases (guaranteed + fallible) are collected in the guaranteed phase |
| Fallible failure | If the fallible phase fails, fees are still consumed -- the user pays for both phases regardless |

Developers do not set gas prices directly. The declared gas bound in each transcript determines the maximum cost, and the network's dynamic pricing converts this to a DUST amount at inclusion time.

## Proof Verification

ZK proof verification happens automatically and is not directly controlled by the contract developer.

| Proof Type | Verified When | Purpose |
|------------|---------------|---------|
| Zswap offer proofs | Well-formedness check | Verify coin inputs/outputs are valid (commitments, nullifiers, value vectors) |
| Contract call proofs | Guaranteed phase | Verify the circuit execution is correct against the contract's stored verifier key |
| Schnorr proof | Well-formedness check | Bind the contract call section to the transaction and ensure it carries no value vector |

The proof for each contract call is generated client-side when the user invokes a circuit. The verifier key is stored in the contract state (set at deployment) and looked up during the guaranteed phase. If verification fails, the entire transaction is rejected (not included in the ledger). Developers write Compact circuits; the compiler and runtime handle proof generation and verification.

## Common Mistakes

| Mistake | Correct Approach | Why |
|---------|-----------------|-----|
| Putting critical state changes after `kernel.checkpoint()` | Move essential state changes before checkpoint | Post-checkpoint operations are fallible and may not execute |
| Assuming all transaction effects are atomic | Understand guaranteed vs fallible split | Guaranteed effects persist even when the fallible section fails |
| Treating contract deployments as guaranteed | Design for deployment being fallible | Deployments execute entirely in the fallible phase |
| Ignoring gas costs for complex circuits | Keep circuits lean; minimize state operations | More operations = higher gas = higher DUST fees |
| Expecting cross-contract calls to work | Use transaction composition (multiple calls in one transaction) instead | Cross-contract calls are not yet available |
| Not handling partial success in the DApp | Check transaction status in TypeScript client code | A "partial success" means guaranteed worked but fallible failed |
| Omitting `kernel.checkpoint()` when fallible operations are needed | Add `kernel.checkpoint()` before fallible section | Without it, the entire circuit is guaranteed-only and any failure rejects the whole transaction |
| Copying context or effects into contract state | Keep context/effects data on-stack only | Context and effects are "weak" values; tainting the state with them causes the transaction to fail |

## Reference Routing

| Topic | Reference File |
|-------|---------------|
| Three execution stages, phase semantics, state lifecycle, weak vs strong values | `references/execution-phases.md` |
| Contract state model, concurrency, conflict minimization, append-only patterns | `references/state-and-conflicts.md` |
| DUST generation, SyntheticCost dimensions, gas-to-fee conversion, dynamic pricing | `references/fees-and-gas.md` |
| Zswap offers, inputs/outputs, balance vectors, transaction merging, Pedersen binding | `references/zswap-and-offers.md` |

| Example | File |
|---------|------|
| Guaranteed/fallible split with `kernel.checkpoint()` | `examples/CheckpointUsage.compact` |
| Multi-call transaction composition | `examples/TransactionComposition.compact` |
| Fee-aware contract with gas considerations | `examples/FeeAwareContract.compact` |
| Atomic swap via transaction merging | `examples/AtomicSwap.compact` |
