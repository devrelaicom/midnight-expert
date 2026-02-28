# Design: compact-transaction-model Skill

## Overview

A dedicated skill for the `compact-core` plugin covering Midnight's transaction model and execution semantics: how Compact code maps to on-chain execution, the guaranteed/fallible phase model, `kernel.checkpoint()`, transaction composition and merging, state conflict handling, DUST fees, gas limits, and proof verification flow.

## Decisions

- **Audience:** Both contract developers (how their Compact code executes) and infrastructure developers (full transaction lifecycle)
- **Organization:** Execution-centric — follows the transaction lifecycle from circuit call through to state update
- **Reference files:** Four files (execution-phases, state-and-conflicts, fees-and-gas, zswap-and-offers)
- **Examples:** Four standalone `.compact` files (checkpoint usage, transaction composition, fee-aware contract, atomic swap)
- **Impact VM:** Mentioned as the compilation target but not detailed (opcode table, stack machine internals omitted)
- **DUST/Zswap:** Practical implications in SKILL.md, full details in separate reference files
- **Existing skills:** No modifications — complements `compact-structure` (circuits/witnesses), `compact-ledger` (state types), and `compact-tokens` (kernel token ops)

## File Structure

```
plugins/compact-core/skills/compact-transaction-model/
├── SKILL.md
├── references/
│   ├── execution-phases.md
│   ├── state-and-conflicts.md
│   ├── fees-and-gas.md
│   └── zswap-and-offers.md
└── examples/
    ├── CheckpointUsage.compact
    ├── TransactionComposition.compact
    ├── FeeAwareContract.compact
    └── AtomicSwap.compact
```

## SKILL.md Structure

### Frontmatter

- **name:** compact-transaction-model
- **description:** This skill should be used when the user asks about Midnight transaction execution, guaranteed vs fallible phases, kernel.checkpoint(), transaction composition, state conflicts, DUST fees, gas limits, proof verification, partial transaction success, transaction merging, atomic swaps, or how Compact circuits map to on-chain execution. Also triggered by mentions of "transaction semantics", "fallible phase", "guaranteed phase", "checkpoint", "well-formedness", "Impact VM", "Zswap offers", or "transaction merging".

### Sections

1. **Opening paragraph** (~3 lines) — Scope definition, cross-references to `compact-structure` for contract anatomy and `compact-ledger` for state types.

2. **Transaction Lifecycle Overview** (~30 lines) — The three execution stages presented as a table/flow:
   - Well-formedness check (stateless validation)
   - Guaranteed phase (proof verification, fee collection, guaranteed effects)
   - Fallible phase (optional, effects applied only on success)
   - Failure outcomes: guaranteed failure → transaction rejected; fallible failure → partial success (guaranteed effects persist)

3. **Guaranteed vs Fallible Phases** (~40 lines) — Detailed semantics of each phase:
   - Guaranteed: ZK proofs verified, Zswap offers applied, contract calls executed, fees collected
   - Fallible: same execution model minus proof verification, state stored only if "strong"
   - Key rule: fees are in guaranteed phase and forfeited on fallible failure
   - When to use each: essential state changes go before checkpoint, optional/risky operations after

4. **kernel.checkpoint()** (~30 lines) — Compact syntax and semantics:
   - `kernel.checkpoint()` separates guaranteed from fallible sections within a circuit
   - Maps to the `ckpt` opcode in Impact VM
   - Everything before checkpoint is guaranteed; everything after is fallible
   - If no checkpoint, entire circuit is guaranteed
   - Inline code example showing before/after checkpoint patterns

5. **Transaction Composition** (~25 lines) — How multiple circuit calls work together:
   - Multiple exported circuits can be called in a single transaction
   - Calls execute sequentially against the evolving state
   - Contract deployments execute entirely in the fallible phase
   - Cross-contract calls are not yet available

6. **Transaction Merging** (~25 lines) — Atomic swap mechanics:
   - Two transactions can be merged if at least one has an empty contract call section
   - Produces a composite transaction with combined effects
   - Pedersen commitment-based integrity binding
   - Contract call section contributes to overall commitment via Schnorr proof
   - Practical use case: atomic swaps between parties

7. **State Model** (~25 lines) — How state works during execution:
   - Contract state = Impact state value + entry point → operation map
   - State loaded at execution time, stored after successful execution
   - Sequential execution within a transaction
   - "Strong" state requirement for storage
   - Brief mention of concurrent transaction conflicts

8. **Fees & Gas** (~20 lines) — What developers need to know:
   - DUST is Midnight's fee token (shielded, non-transferable, derived from Night)
   - Each contract call declares a gas bound → derives fees
   - Fees collected in guaranteed phase, forfeited if fallible fails
   - Practical implication: users pay for guaranteed phase even on fallible failure

9. **Proof Verification** (~15 lines) — Brief coverage:
   - ZK proofs verified during guaranteed phase against contract verifier keys
   - Schnorr proof binds contract calls to transaction integrity
   - Zswap offer proofs verified during well-formedness check
   - Developers don't interact directly — the Compact compiler and proof server handle this

10. **Common Mistakes** (~15 lines) — Table of frequent errors:
    - Putting critical state changes after checkpoint
    - Not understanding partial success (guaranteed effects persist on fallible failure)
    - Assuming contract deployments are guaranteed (they're fallible)
    - Ignoring gas limits when designing complex circuits
    - Expecting cross-contract calls to work (not yet available)

11. **Reference Files** table — Points to the four reference docs with topic descriptions.

## Reference Files

### `references/execution-phases.md`

Deep dive into the three execution stages:

- **Well-formedness check:** Canonical format validation, ZK proof verification for Zswap offers, Schnorr proof verification, balance checking rules (guaranteed offer minus fees plus mints; fallible offer plus mints), I/O claim uniqueness rules, `ckpt` boundary requirement for contracts with both phases
- **Guaranteed phase execution:** Contract operation lookup and proof verification, fallible Zswap applied during guaranteed (to prevent self-invalidation), Zswap offer application (commitments → Merkle tree, nullifiers → nullifier set, root validation), Impact program execution in verification mode, effects matching, strong state storage
- **Fallible phase execution:** Same model minus proof verification/Zswap checks, state stored iff strong, contract deployments
- **Partial success:** What the ledger records, implications for DApp state management

### `references/state-and-conflicts.md`

State handling during transaction execution:

- **Contract state structure:** Impact state value + entry point → operation map (verifier key)
- **State loading and storage:** Loaded per contract call, stored after execution if "strong"
- **Sequential execution:** Calls within a transaction execute in order, each seeing the previous call's state changes
- **Strong state:** What makes state storable vs weak (weak state is in-memory only, cannot be persisted)
- **Concurrent transactions:** State read at execution time; if two transactions modify the same contract state, the second one executes against the first's result (sequential block inclusion)
- **Design patterns:** Append-only structures (Merkle trees, Sets) minimize conflicts; Counters with increment/decrement are idempotent-friendly; Maps with unique keys avoid overwrites

### `references/fees-and-gas.md`

DUST fee model and gas mechanics:

- **DUST overview:** Shielded non-transferable token, derived from Night UTXOs, grows over time to a cap, decays after Night is spent
- **Fee collection:** Guaranteed phase collects fees for ALL phases (guaranteed + fallible), forfeited on fallible failure
- **Gas model:** Each contract call declares a gas bound in its transcript, fees derived from gas via dynamic pricing
- **Dynamic pricing:** Per-dimension pricing factors adjusted to target 50% block fullness, n-dimensional pricing vector model
- **SyntheticCost dimensions:** Compute time, block usage, bytes written, bytes churned
- **Practical guidance:** Gas estimation for circuit complexity, minimizing gas through simpler circuits

### `references/zswap-and-offers.md`

Zswap protocol and transaction structure:

- **Zswap offers:** Sets of inputs (spends with nullifiers), outputs (new coins with commitments), transient coins (created and spent in same transaction), balance vectors
- **Inputs:** Nullifier, Pedersen commitment to type/value, optional contract address, Merkle proof, ZK proof
- **Outputs:** Coin commitment, Pedersen commitment to type/value, optional contract address/ciphertext, ZK proof
- **Transient coins:** Output immediately followed by input; spends from local commitment set
- **Balance vectors:** Dimensions are all possible token types; must be non-negative after adjustments (fees, mints)
- **Token types:** 256-bit hash (contract-issued) or zero (native Night token)
- **Transaction merging:** Requirements (at least one empty contract calls section), composite transaction formation, Pedersen commitment homomorphic combination
- **Transaction integrity:** Pedersen commitments bind inputs/outputs, homomorphic sum checked by opening composite commitment, contract call binding via Schnorr proof

## Example Files

### `examples/CheckpointUsage.compact`
Demonstrates `kernel.checkpoint()` to separate guaranteed from fallible logic:
- Essential state updates before checkpoint (fee collection, authentication, counter increments)
- Optional/risky operations after checkpoint (external interactions, complex state updates)
- Comments explaining what goes in each phase and why
- Shows that guaranteed effects persist even if fallible section fails

### `examples/TransactionComposition.compact`
Demonstrates how multiple exported circuits compose:
- Multiple exported circuits that interact with shared ledger state
- Shows sequential execution ordering within a single transaction
- Constructor for initial state setup
- Comments explaining execution ordering

### `examples/FeeAwareContract.compact`
Demonstrates gas-conscious patterns:
- Circuit designed to minimize gas usage through efficient state operations
- Comments about gas implications of different operations
- Shows how complex circuits increase gas costs
- Practical tips for keeping circuits lean

### `examples/AtomicSwap.compact`
Demonstrates transaction merging for atomic swaps:
- Two-party swap pattern using Zswap offers
- Shows how the guaranteed phase ensures atomicity
- Token type handling for multi-token swaps
- Comments explaining the merging constraints

## Content Sources

All content sourced from official Midnight documentation and code:

- `docs.midnight.network/develop/how-midnight-works/semantics` — Transaction semantics, phases, well-formedness
- `docs.midnight.network/develop/how-midnight-works/building-blocks` — Transaction structure, contract calls, merging
- `docs.midnight.network/develop/how-midnight-works/impact` — Impact VM, ckpt opcode, context/effects
- `docs.midnight.network/develop/how-midnight-works/zswap` — Zswap offers, inputs/outputs, token types
- `midnightntwrk/midnight-ledger/spec/dust.md` — DUST fee model, fee collection
- `midnightntwrk/midnight-ledger/spec/cost-model.md` — Gas model, dynamic pricing
- `midnightntwrk/compact-export/examples/adt/tests/kernel.compact` — kernel.checkpoint() usage example
- `midnightntwrk/compact-export/examples/adt/exports/kernel.compact` — kernel API example

## Relationship to Existing Skills

| Existing Skill | Relationship |
|---------------|-------------|
| `compact-structure` | Covers circuits/witnesses but not execution semantics; this skill explains what happens AFTER compilation |
| `compact-ledger` | Covers state types/operations but not state conflict handling or sequential execution; this skill adds the execution context |
| `compact-tokens` | Covers kernel token operations but not WHY they're in the guaranteed phase; this skill provides the transaction model context |
| `compact-privacy-disclosure` | Covers disclosure mechanics but not how they map to ZK proofs in transactions; complementary |
| `compact-language-ref` | Covers syntax/semantics of the language but not runtime execution; complementary |
| `compact-standard-library` | Covers stdlib functions but not their execution phase implications; complementary |
