# Execution Phases

How Midnight transactions move through the three-stage execution pipeline -- from stateless well-formedness validation through the guaranteed phase to the fallible phase -- and what each stage checks, enforces, and produces.

## Overview

Every Midnight transaction executes in three sequential stages:

| Stage | Nature | Purpose | On Failure |
|-------|--------|---------|------------|
| Well-formedness check | Stateless | Validates structural integrity, verifies ZK proofs and Schnorr proofs, checks balance constraints and I/O claim rules | Transaction rejected entirely; never reaches the ledger |
| Guaranteed phase | Stateful | Looks up contract operations, verifies contract call proofs, collects fees, applies Zswap offers, executes guaranteed transcripts | Transaction not included in the ledger |
| Fallible phase | Stateful | Executes fallible transcripts, applies contract deployments, stores resulting state | Partial success -- guaranteed effects persist, fees consumed |

The pipeline is strictly ordered. A transaction must pass well-formedness before reaching the guaranteed phase, and must pass the guaranteed phase before the fallible phase runs. The critical design property is that guaranteed-phase effects are never rolled back: if the fallible phase fails, the ledger records a partial success and the guaranteed-phase state changes remain committed.

This three-stage model gives developers a tool for risk stratification. Operations that must succeed atomically (authorization checks, fee collection, proof verification) belong in the guaranteed phase. Operations that depend on mutable shared state and may conflict with concurrent transactions can be placed in the fallible phase, accepting the possibility of partial success in exchange for the guarantee that critical invariants are preserved.

## Well-Formedness Check

The well-formedness check is a stateless validation pass. It runs without access to the ledger and verifies structural integrity and internal consistency of the transaction. A transaction that fails this check is rejected outright and never reaches the execution phases.

### What Well-Formedness Does Not Check

Well-formedness is purely structural. It does not access the ledger, so it cannot verify:

- Whether nullifiers have already been spent (that is checked during Zswap offer application in the guaranteed phase).
- Whether Merkle roots are valid past roots (also checked during the guaranteed phase).
- Whether a contract exists at a given address or whether its state is compatible with the call.

These stateful checks are deferred to the guaranteed phase.

### Canonical Format

The transaction must be encoded in a canonical binary format. This prevents equivalent transactions from having multiple valid encodings, which would complicate deduplication and proof verification.

### Proof Verification

Two categories of proofs are verified during well-formedness:

| Proof Type | What Is Verified |
|------------|-----------------|
| Zswap ZK proofs | Every zero-knowledge proof in both the guaranteed and fallible Zswap offers is verified. These proofs attest that coin inputs and outputs are well-formed: commitments correspond to valid coins, nullifiers are correctly derived, and value vectors are consistent. |
| Schnorr proof | The Schnorr proof in the contract section is verified. This proof binds the contract call section to the transaction and ensures the section carries no hidden value that could unbalance the transaction. |

### Balance Checking

Offers must be balanced -- the total value flowing in must equal the total value flowing out, after permitted adjustments. The guaranteed and fallible offers are checked independently:

| Offer | Balance Rule |
|-------|-------------|
| Guaranteed | Must balance after subtracting fees for the entire transaction (both phases) and adding any mints performed in guaranteed transcripts |
| Fallible | Must balance after adding any mints performed in fallible transcripts |

The balance check uses homomorphic Pedersen commitments: validators sum the commitment values without learning individual amounts, then verify the net result is zero (after adjustments). This allows balance verification to work even when amounts are shielded.

### I/O Claim Rules

The well-formedness check enforces strict rules about how contract-owned inputs and outputs are claimed across the transaction:

- Each contract-owned input or output must be claimed exactly once by the same contract. The claim appears in the effects section of the transcript whose fallibility matches the offer the I/O appears in.
- Any outputs that a transcript's effects section declares as being created by a contract must be claimed at most once, and they must appear in the offer matching the fallibility of that transcript.
- Any contract calls claimed in a transcript must be present in the transaction and claimed at most once.

These rules prevent a contract from claiming I/O that belongs to another contract, prevent double-claiming, and ensure that claims and offers are consistent in their fallibility designation.

### The ckpt Boundary Rule

If a contract call has both a guaranteed and a fallible section, the fallible section must start with a `ckpt` operation. This is the Impact VM opcode that `kernel.checkpoint()` compiles to. The rule ensures that the phase boundary is explicitly and correctly marked in every contract call that spans both phases, and that the two sections can be cleanly separated during execution.

## Guaranteed Phase Execution

The guaranteed phase is the first stateful execution stage. It runs against the current ledger state and either produces a new state or fails, in which case the transaction is not included in the ledger at all. Nothing from a failed guaranteed phase is recorded.

### Additional Work in the Guaranteed Phase

Before the standard per-phase execution steps, the guaranteed phase performs two pieces of additional work that the fallible phase does not:

1. **Contract operation lookup and proof verification.** For every contract call in the transaction, the contract's operations are looked up from the ledger. Each operation contains a SNARK verifier key corresponding to an exported circuit. The zero-knowledge proof submitted with each contract call is verified against the appropriate verifier key. If any proof fails verification, the entire transaction is rejected.

2. **Fallible Zswap pre-application.** The fallible Zswap section is also applied during the guaranteed phase. This prevents a scenario where an attacker merges an invalid spend into a transaction that would specifically invalidate only the fallible section while allowing the guaranteed section to succeed. By applying the fallible Zswap section early, any invalidity in it causes failure in the guaranteed phase, rejecting the entire transaction rather than permitting a partial success with corrupted fallible-section semantics.

### Phase Execution Steps

The guaranteed phase executes in three ordered steps:

1. **Zswap offer application.** The guaranteed-phase Zswap offer is applied to the ledger:
   - New coin commitments are inserted into the Merkle tree.
   - Nullifiers are inserted into the nullifier set. If any nullifier is already present (double-spend attempt), the transaction aborts.
   - Merkle roots referenced by inputs are checked against the set of valid past roots. If any root is not in the set, the transaction aborts.
   - The past roots set is updated to include the new Merkle tree root.

2. **Contract operation lookup, proof verification, and fallible Zswap pre-application.** For every contract call, the contract's operations are looked up from the ledger and the ZK proof is verified against the appropriate verifier key (see "Additional Work" above). The fallible Zswap section is also applied at this point to prevent selective invalidation attacks.

3. **Contract call execution.** For each contract call in sequence, the transcript relevant to the guaranteed phase is applied:
   - The contract's current state is loaded from the ledger.
   - A context object is set up from the transaction, containing the contract's address, a map of newly allocated coin commitments to their Merkle tree indices, block timestamp information, and the block hash.
   - The Impact program is executed against the context, an empty effects set, the transcript program, and the declared gas limit. Execution runs in **verification mode**, meaning `popeq` arguments are enforced for equality rather than gathered as results.
   - The resulting effects are tested for equality against the declared effects in the transcript. A mismatch causes failure.
   - The resulting state is stored as the contract's new state, but only if the state is "strong" (not weak). If the state has been weakened by incorporating context or effects data, the call fails.

Because each contract call in a transaction executes sequentially, later calls see the state changes produced by earlier calls within the same phase.

## Fallible Phase Execution

The fallible phase follows the guaranteed phase and operates on the ledger state that the guaranteed phase produced. Its execution steps are largely the same as the guaranteed phase, with several important differences:

| Difference | Detail |
|------------|--------|
| No ZK proof verification | Contract call proofs were already verified in the guaranteed phase. They are not verified again. |
| No fallible Zswap pre-application | The fallible Zswap section was already applied during the guaranteed phase. It is not re-applied. |
| Contract deployments | New contract deployments execute in the fallible phase, not the guaranteed phase. |
| Failure semantics | If the fallible phase fails, the guaranteed-phase effects persist. The transaction is recorded as a partial success. |

The standard execution steps (Zswap offer application, contract call execution) proceed in the same order as in the guaranteed phase. The fallible-phase Zswap offer is applied, then each contract call's fallible transcript is executed sequentially.

Contract deployments create new contract state entries in the ledger. A deployment establishes the contract's initial state value and its entry point map (mapping exported circuit names to SNARK verifier keys). Because deployments are fallible, a deployment failure does not undo the guaranteed-phase effects. The fees for the deployment (collected in the guaranteed phase) are still consumed.

### Why Deployments Are Fallible

Placing contract deployments in the fallible phase is a deliberate design choice. Deployment involves creating new persistent state, which is inherently a mutable operation that could conflict with other transactions or fail for state-dependent reasons. By making deployments fallible, the protocol ensures that the guaranteed-phase invariants (fee collection, proof verification) are never compromised by deployment failures. The trade-off is that a failed deployment still costs the user fees.

## Partial Success

A partial success occurs when a transaction's guaranteed phase succeeds but its fallible phase fails. This is not a full rejection -- it is a legitimate on-chain outcome with real consequences.

### What Happens on Partial Success

| Aspect | Outcome |
|--------|---------|
| Guaranteed state changes | Committed to the ledger permanently |
| Guaranteed Zswap effects | Coin commitments inserted, nullifiers recorded, Merkle tree updated |
| Fees | Consumed in full -- fees for both phases were collected in the guaranteed phase |
| Fallible state changes | Rolled back; not applied to the ledger |
| Fallible contract deployments | Not created |
| Ledger record | The transaction is recorded on-chain with a partial success status |

### Implications for DApp Development

Partial success is a normal outcome that DApp developers must handle. The TypeScript client code should check the transaction status after submission and finalization:

- A fully successful transaction has a status indicating complete success across all sections.
- A partial success has a status indicating that one or more sections failed.
- The `ExecutionStatus` type in the DApp connector API records per-section success or failure as `Record<number, "Success" | "Failure">`.

Failing to check for partial success can lead to state inconsistencies between the on-chain contract and the DApp's local state. For example, if a transfer circuit places the balance check in the guaranteed phase and the balance update in the fallible phase, a partial success means the check passed and fees were collected, but the balances were not updated.

Practical guidance:

- Always watch for transaction finalization and inspect the resulting status.
- Do not update local or private state until you have confirmed full success.
- Design circuits so that partial success leaves the contract in a consistent state. Avoid placing complementary operations (debit and credit) across the checkpoint boundary.

## Impact VM Execution Context

The Impact VM is the execution engine for on-chain contract logic. Understanding its execution model is essential for reasoning about what happens during the guaranteed and fallible phases.

### Execution Model

Impact is a stack-based, non-Turing-complete state manipulation language. Execution proceeds linearly -- no operation can decrease the program counter, and every operation is bounded in time. This guarantees termination and predictable resource consumption.

A contract executes on a stack containing three items:

| Stack Item | Description |
|------------|-------------|
| Context | An array describing the containing transaction: the contract's address, a map of newly allocated coins to Merkle tree indices, block timestamp, timestamp precision bound, and block hash. **Note:** Currently only the contract address and newly-allocated coin indices are correctly initialized; the timestamp and block hash fields are defined in the spec but not yet correctly populated on-chain. |
| Effects | An array gathering actions performed by the contract during execution: claimed nullifiers, received coins, spent coins, contract calls, and minted coins |
| State | The contract's current state value (maps, arrays, cells, Merkle trees) |

### Transcripts

Each contract call's execution is governed by a transcript, which consists of three components:

| Component | Purpose |
|-----------|---------|
| Declared gas bound | Sets the maximum execution cost, used to derive the fees for this call |
| Declared effects | Binds the contract's runtime behavior to the rest of the transaction semantics |
| Program | The Impact bytecode to execute |

The transcript serves as a commitment: the declared effects must match the actual effects produced by execution, and the declared gas bound caps resource consumption. This structure allows validators to verify execution without re-running the full proof generation.

### Execution Constraints

Programs either abort (invalidating this part of the transaction) or succeed, in which case the stack must be in the same shape as when execution began. Several constraints govern execution:

- **Effects matching.** The resulting effects must equal the declared effects in the transcript. This binding connects the contract's runtime behavior to the statically declared transaction structure.
- **Gas-bounded execution.** Each transcript declares a gas limit. Execution costs are bounded by this limit, and exceeding it causes the call to abort. The gas limit directly determines the fees charged for the call.
- **Verification mode.** During ledger execution, the Impact VM runs in verification mode. In this mode, `popeq` arguments are enforced for equality rather than gathered as outputs. This is the mechanism by which the on-chain verifier checks that the prover's claimed outputs match the actual execution.

### Weak Value Propagation

The context and effects objects are flagged as **weak**. This weakness propagates through operations:

- Any non-size-bounded operation on a weak value produces a weak result.
- Size-bounded operations (such as checking the type or size of a value) do not propagate weakness.
- If the final contract state is weak, the transaction fails. The state must be "strong" (not weakened) to be stored. This prevents contracts from cheaply copying transaction context or effects data into persistent storage, which would circumvent the intended cost model.

The practical consequence is that contracts cannot store context or effects data directly into their state. Values derived from context or effects through non-size-bounded operations inherit the weakness and cannot be persisted. This is a deliberate design choice: context and effects are ephemeral execution data, not state.

### Evaluating vs Verifying Mode

The Impact VM supports two execution modes:

| Mode | When Used | Behavior |
|------|-----------|----------|
| Evaluating | Client-side proof generation | `popeq` arguments are gathered as results, building the transcript |
| Verifying | On-chain ledger execution | `popeq` arguments are enforced for equality, checking the transcript |

During transaction construction, the client runs the Impact program in evaluating mode to produce the transcript (including the declared effects). During ledger validation, the same program runs in verifying mode to confirm that the declared effects match what the program actually computes. This dual-mode design separates proof generation (off-chain) from proof verification (on-chain) while using the same program for both.
