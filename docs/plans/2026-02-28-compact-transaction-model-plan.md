# compact-transaction-model Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a comprehensive `compact-transaction-model` skill for the `compact-core` plugin covering Midnight's transaction execution semantics — guaranteed/fallible phases, `kernel.checkpoint()`, transaction composition/merging, state conflicts, DUST fees, gas, and proof verification.

**Architecture:** Execution-centric SKILL.md following the transaction lifecycle, with four reference files (execution-phases, state-and-conflicts, fees-and-gas, zswap-and-offers) and four standalone Compact example contracts. Follows the same conventions as the existing `compact-tokens` and `compact-privacy-disclosure` skills.

**Tech Stack:** Compact language, Midnight MCP for research, markdown skill files

**Design doc:** `docs/plans/2026-02-28-compact-transaction-model-design.md`

---

## Research Requirement

Several tasks require fetching content from Midnight's ecosystem. Use the Midnight MCP tools:
- `mcp__midnight__midnight-search-compact` — Search Compact code across repositories
- `mcp__midnight__midnight-fetch-docs` — Fetch documentation pages from docs.midnight.network
- `mcp__midnight__midnight-search-docs` — Search documentation content
- `mcp__midnight__midnight-get-file` — Fetch specific files from Midnight repositories

Key documentation pages:
- `docs.midnight.network/develop/how-midnight-works/semantics` — Transaction semantics, phases, well-formedness
- `docs.midnight.network/develop/how-midnight-works/building-blocks` — Transaction structure, contract calls, merging
- `docs.midnight.network/develop/how-midnight-works/impact` — Impact VM, ckpt opcode, context/effects
- `docs.midnight.network/develop/how-midnight-works/zswap` — Zswap offers, inputs/outputs, token types

Key repositories:
- `midnightntwrk/compact-export` — `examples/adt/tests/kernel.compact` and `examples/adt/exports/kernel.compact` for checkpoint usage
- `midnightntwrk/midnight-ledger` — `spec/dust.md` and `spec/cost-model.md` for fee model

---

### Task 1: Create Directory Structure

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/SKILL.md` (placeholder)
- Create: `plugins/compact-core/skills/compact-transaction-model/references/` (directory)
- Create: `plugins/compact-core/skills/compact-transaction-model/examples/` (directory)

**Step 1: Create directories and placeholder**

```bash
mkdir -p plugins/compact-core/skills/compact-transaction-model/references
mkdir -p plugins/compact-core/skills/compact-transaction-model/examples
```

Create a minimal placeholder `SKILL.md`:

```markdown
---
name: compact-transaction-model
description: This skill should be used when the user asks about Midnight transaction execution, guaranteed vs fallible phases, kernel.checkpoint(), transaction composition, state conflicts, DUST fees, gas limits, proof verification, partial transaction success, transaction merging, atomic swaps, or how Compact circuits map to on-chain execution. Also triggered by mentions of "transaction semantics", "fallible phase", "guaranteed phase", "checkpoint", "well-formedness", "Impact VM", "Zswap offers", or "transaction merging".
---

# Compact Transaction Model & Execution Semantics

Placeholder — content to follow.
```

**Step 2: Verify structure**

```bash
find plugins/compact-core/skills/compact-transaction-model -type f -o -type d | sort
```

Expected output should show `SKILL.md`, `references/`, and `examples/` directories.

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/
git commit -m "feat(compact-core): scaffold compact-transaction-model skill directory structure"
```

---

### Task 2: Write SKILL.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-transaction-model/SKILL.md`

**Convention reference:** Follow the structure of `plugins/compact-core/skills/compact-tokens/SKILL.md` and `plugins/compact-core/skills/compact-privacy-disclosure/SKILL.md` — YAML frontmatter, concise overview, tables, inline code examples, reference routing at bottom. Target ~180-220 lines.

**Step 1: Research transaction semantics for accuracy**

Use Midnight MCP to verify the following details:
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/semantics` — Confirm the three execution stages: well-formedness, guaranteed, fallible. Confirm failure semantics (guaranteed failure → rejected; fallible failure → partial success).
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/building-blocks` — Confirm transaction structure (guaranteed offer + optional fallible offer + optional contract calls). Confirm merging rules (at least one must have empty contract calls).
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/impact` — Confirm `ckpt` opcode description ("boundary between internally atomic program segments"). Confirm gas limit and context/effects structure.
- `mcp__midnight__midnight-search-compact` query "kernel.checkpoint" — Find real usage examples of `kernel.checkpoint()` in Compact code.

**Step 2: Write SKILL.md content**

Write the full SKILL.md following the design doc's section plan. The ten sections:

1. **Opening paragraph** (~3 lines) — Scope: how Compact code maps to on-chain execution. Cross-references: `compact-structure` for contract anatomy, `compact-ledger` for state types, `compact-tokens` for token operations.

2. **Transaction Lifecycle Overview** (~30 lines) — Table showing the three stages:

| Stage | Type | What Happens | On Failure |
|-------|------|-------------|-----------|
| Well-formedness | Stateless | ZK proofs verified, offers balanced, claims unique | Transaction rejected |
| Guaranteed phase | Stateful | Proof verification, fee collection, Zswap applied, contract calls | Transaction rejected (not included in ledger) |
| Fallible phase | Stateful | Contract calls executed, state stored if "strong" | Partial success — guaranteed effects still apply |

Include a flow showing: `Circuit call → Proof generation → Well-formedness → Guaranteed → Fallible → State update`

3. **Guaranteed vs Fallible Phases** (~40 lines) — Two sub-tables showing what each phase does. Key rules:
   - Fees for ALL phases collected in guaranteed phase
   - If fallible fails, fees are still consumed (forfeited)
   - ZK proofs verified only in guaranteed phase
   - Contract deployments execute entirely in fallible phase
   - If no `kernel.checkpoint()`, entire circuit is guaranteed-only

4. **kernel.checkpoint()** (~30 lines) — Syntax and semantics. Inline code example:

```compact
export circuit transfer(to: Bytes<32>, amount: Uint<64>): [] {
  // --- GUARANTEED PHASE ---
  // Critical state changes that MUST succeed
  assert(balance.lookup(sender) >= amount, "Insufficient balance");
  counter.increment(1);

  kernel.checkpoint();

  // --- FALLIBLE PHASE ---
  // Optional operations — if these fail, guaranteed effects still apply
  balance.insert(sender, disclose(balance.lookup(sender) - amount));
  balance.insert(to, disclose(balance.lookup(to) + amount));
}
```

Rules: everything before `kernel.checkpoint()` → guaranteed; everything after → fallible. Only one checkpoint per circuit. Maps to `ckpt` opcode in Impact VM.

5. **Transaction Composition** (~25 lines) — How multiple circuit calls compose. Key points:
   - A transaction can contain multiple contract calls
   - Calls execute sequentially — each sees the previous call's state changes
   - Contract deployments are fallible-only (they fail → deployment doesn't happen, but guaranteed effects persist)
   - Cross-contract calls not yet available

6. **Transaction Merging** (~25 lines) — Atomic swap mechanics:
   - Two transactions can merge if at least one has empty contract calls
   - Composite transaction has combined effects of both
   - Pedersen commitment binding: each party's inputs/outputs are commitment-bound
   - Contract call binding: Schnorr proof contributes to overall Pedersen commitment
   - Use case: atomic swaps between two parties exchanging different token types

7. **State Model** (~25 lines) — How state works:
   - Contract state = Impact state value + entry point → verifier key map
   - State loaded per call, stored after execution if "strong"
   - Weak state (derived from context/effects) cannot be persisted — prevents cheaply copying transaction data into state
   - Concurrent transactions: within a block, calls are ordered; second transaction sees first's results
   - Practical advice: use append-only structures (MerkleTree, Set) to minimize conflicts

8. **Fees & Gas** (~20 lines):
   - DUST is the fee token (non-transferable, derived from Night, see `compact-tokens`)
   - Each contract call declares a gas bound in its transcript
   - Gas → fee conversion uses dynamic pricing (targets 50% block fullness)
   - SyntheticCost dimensions: compute time, block usage, bytes written, bytes churned
   - Fees collected in guaranteed phase — even if fallible fails, fees are consumed

9. **Proof Verification** (~15 lines):
   - ZK proofs verified in guaranteed phase against contract verifier keys
   - Zswap offer proofs verified during well-formedness check
   - Schnorr proof binds contract calls to transaction integrity
   - Developers don't interact directly — Compact compiler generates circuits, proof server creates proofs

10. **Common Mistakes** — Table:

| Mistake | Correct Approach | Why |
|---------|-----------------|-----|
| Putting critical state changes after `kernel.checkpoint()` | Move essential state changes before checkpoint | Post-checkpoint operations are fallible and may not execute |
| Assuming all transaction effects are atomic | Understand guaranteed vs fallible | Guaranteed effects persist even when fallible section fails |
| Treating contract deployments as guaranteed | Design for deployment being fallible | Deployments execute in fallible phase only |
| Ignoring gas costs for complex circuits | Keep circuits lean; minimize state operations | More operations = higher gas = higher fees |
| Expecting cross-contract calls to work | Use transaction composition instead | Cross-contract calls are not yet available |
| Not handling partial success in DApp | Check transaction status in TypeScript | A "partial success" means guaranteed worked but fallible failed |

11. **Reference Routing** — Table with reference files and example files.

**Step 3: Verify SKILL.md**

Review the SKILL.md for:
- YAML frontmatter has `name` and `description` fields
- All code examples use valid Compact syntax (check pragma, `export circuit ... : []` return type, `disclose()` where needed)
- Cross-references point to correct skill names
- No overlap with existing skills (check that we're not re-explaining token operations that `compact-tokens` already covers, or ledger ADTs that `compact-ledger` covers)

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/SKILL.md
git commit -m "feat(compact-core): write complete SKILL.md for compact-transaction-model"
```

---

### Task 3: Write `references/execution-phases.md`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/references/execution-phases.md`

**Convention reference:** Follow the depth and style of `plugins/compact-core/skills/compact-tokens/references/token-architecture.md` — clear headings, explanatory prose, comparison tables, code examples where helpful. Target ~200-250 lines.

**Step 1: Research execution phase details**

Use Midnight MCP tools:
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/semantics` — Full page for well-formedness checks, phase execution details
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/impact` — Impact VM execution, ckpt opcode, verification mode, gas limits
- `mcp__midnight__midnight-search-docs` query "well-formedness canonical format balanced" — Additional well-formedness details

**Step 2: Write execution-phases.md**

Sections:

1. **Overview** — The three-stage pipeline, summary of what each does

2. **Well-Formedness Check** — Stateless validation:
   - Canonical format verification
   - ZK proof verification for all Zswap offers
   - Schnorr proof verification for contract section
   - Balance checking:
     - Guaranteed offer: must balance after subtracting fees for entire transaction + adding mints from guaranteed transcripts
     - Fallible offer: must balance after adding mints from fallible transcripts
   - I/O claim rules:
     - Each contract-owned I/O claimed exactly once by the same contract
     - Claimed outputs appear in matching-fallibility offer
     - Contract calls claimed in transcripts are present and claimed at most once
   - `ckpt` boundary: if a contract call has both guaranteed and fallible sections, fallible must start with `ckpt`

3. **Guaranteed Phase Execution** — Stateful, with additional work:
   - Contract operations for all calls looked up; ZK proofs verified against verifier keys
   - Fallible Zswap section also applied during guaranteed phase (prevents self-invalidation of fallible section)
   - Then for each phase:
     1. Zswap offer applied: commitments → Merkle tree, nullifiers → nullifier set (abort if already present), Merkle roots checked against valid past roots
     2. Additional guaranteed-phase checks performed
     3. For each contract call in sequence:
        - Contract's current state loaded
        - Context set up from transaction
        - Impact program executed against context, empty effects, transcript, declared gas limit, in verification mode
        - Resulting effects tested against declared effects
        - Resulting state stored if "strong"

4. **Fallible Phase Execution** — Same as guaranteed minus:
   - No ZK proof verification (already done)
   - No fallible Zswap pre-application
   - Contract deployments execute here
   - On failure: guaranteed effects persist, transaction recorded as partial success

5. **Partial Success** — What happens when fallible fails:
   - Guaranteed state changes are committed to ledger
   - Fees are consumed (collected in guaranteed phase)
   - The ledger records the transaction as a partial success
   - DApp implications: TypeScript code must check transaction status and handle partial success cases

6. **Impact VM Execution Context** — Brief overview (not full opcode table):
   - Stack-based, non-Turing-complete
   - Operates on context (transaction info), effects (actions performed), and state
   - Programs either abort (invalidating this part of transaction) or succeed (leaving stack in same shape)
   - Effects must match declared transcript effects
   - Gas-bounded execution

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/references/execution-phases.md
git commit -m "feat(compact-core): add execution-phases reference for compact-transaction-model"
```

---

### Task 4: Write `references/state-and-conflicts.md`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/references/state-and-conflicts.md`

**Convention reference:** Same depth as `execution-phases.md`. Target ~150-180 lines.

**Step 1: Research state handling**

Use Midnight MCP tools:
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/semantics` section "Contract state" — State structure (Impact state value + entry point → verifier key)
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/impact` section "Context and effects" — Strong vs weak state, context/effects flagging

**Step 2: Write state-and-conflicts.md**

Sections:

1. **Contract State Structure**
   - Contract state = Impact state value + map of entry point names → operations
   - Each operation = SNARK verifier key for that entry point
   - Entry points correspond to exported circuits

2. **State Loading and Storage**
   - State loaded at start of each contract call within a transaction
   - After Impact program execution, state stored if it is "strong" (not tainted by weak values)
   - Weak values: context and effects are flagged as weak; any operations derived from them produce weak values
   - Why: prevents cheaply copying transaction data (context/effects) into contract state with minimal opcodes

3. **Sequential Execution Within a Transaction**
   - Multiple contract calls within one transaction execute in order
   - Each call sees the state produced by the previous call
   - Example: Call A increments counter; Call B reads the incremented value
   - Compact inline example showing two circuits that interact through shared state

4. **Concurrent Transactions and Block Ordering**
   - Within a block, transactions are ordered by the block producer
   - Second transaction executes against the state produced by the first
   - If two transactions modify the same contract, the second sees the first's changes
   - This is NOT optimistic concurrency — there's no rollback mechanism for conflicts

5. **Design Patterns for Minimizing Conflicts**
   - Use append-only structures (`MerkleTree`, `Set`) — multiple transactions can insert without conflicts
   - `Counter` operations are commutative — increment(1) from two transactions both succeed
   - `Map` with unique keys avoids overwrites — use user-specific keys (`Map<Bytes<32>, T>` keyed by public key)
   - Avoid reading-then-writing the same field in patterns that assume a fixed value — the value may change between proof creation and execution
   - Table comparing state types by conflict risk:

| State Type | Conflict Risk | Why | Recommendation |
|-----------|--------------|-----|---------------|
| `Counter` | Low | Increments commute | Preferred for counters, sequences |
| `Set<T>` | Low | Insertions don't conflict | Preferred for membership tracking |
| `MerkleTree<N, T>` | Low | Append-only insertions | Preferred for privacy-preserving sets |
| `Map<K, V>` (unique keys) | Low | Different keys don't conflict | Good for per-user state |
| `Map<K, V>` (shared keys) | High | Overwrites conflict | Avoid for concurrent writes |
| `Field` / `Bytes<N>` (shared) | High | Any write conflicts | Use Counter or Map instead |

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/references/state-and-conflicts.md
git commit -m "feat(compact-core): add state-and-conflicts reference for compact-transaction-model"
```

---

### Task 5: Write `references/fees-and-gas.md`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/references/fees-and-gas.md`

**Convention reference:** Similar depth. Target ~150-180 lines.

**Step 1: Research DUST and gas model**

Use Midnight MCP tools:
- `mcp__midnight__midnight-search-docs` query "DUST fee model transaction cost gas limit" — Fee model details
- Fetch from `midnightntwrk/midnight-ledger` repo — `spec/dust.md` and `spec/cost-model.md` via:
  - `mcp__midnight__midnight-get-file` repo "midnight-ledger" path "spec/dust.md"
  - `mcp__midnight__midnight-get-file` repo "midnight-ledger" path "spec/cost-model.md"
- `mcp__midnight__midnight-fetch-docs` path `/develop/faq` section "General questions" — Look for info about testnet gas/tokens

**Step 2: Write fees-and-gas.md**

Sections:

1. **DUST Overview**
   - Shielded non-transferable network resource (not a token)
   - Used exclusively for transaction fees
   - Generated from NIGHT: holding NIGHT UTXOs produces DUST over time
   - Grows linearly toward a cap (~5 DUST per NIGHT, initial parameters)
   - Decays to zero after backing NIGHT UTXO is spent
   - Non-persistent: protocol reserves right to modify allocation rules
   - Testnet: tDUST from tNIGHT via delegation

2. **Fee Collection Mechanics**
   - Fees for ALL phases (guaranteed + fallible) collected in guaranteed phase
   - If fallible fails → fees still consumed, no refund
   - Fee payment uses DUST spends (1-to-1 transfers: 1 input nullifier, 1 output commitment, public fee declaration)
   - DUST spend ZK proof verifies: input valid in commitment tree, output = updated value - fee, same public key for I/O
   - Night registration: at least one Night input must not already be generating Dust; uses what-would-have-been-generated Dust for fees
   - Registrations processed sequentially during guaranteed segment

3. **Gas Model**
   - Each contract call declares a gas bound in its execution transcript
   - Gas bound → fee via dynamic pricing (SyntheticCost → DUST conversion)
   - SyntheticCost dimensions:
     - `compute_time` — Execution time
     - `block_usage` — Block space consumed
     - `bytes_written` — New state bytes written
     - `bytes_churned` — State bytes read + written
   - Example SyntheticCost (from cost-model.md):
     ```
     compute_time: 1 * SECOND
     block_usage: 200_000
     bytes_written: 20_000
     bytes_churned: 1_000_000
     ```

4. **Dynamic Pricing**
   - Per-dimension pricing factors adjusted to target 50% block fullness
   - Blocks >50% full → prices increase; <50% full → prices decrease
   - n-dimensional pricing vector: scalar multiplied by unit vector
   - Mental model: pricing adjusts like a polar coordinate — magnitude × direction
   - This means fees are market-responsive but predictable

5. **Practical Guidance for Developers**
   - More ledger operations = higher gas = higher fees
   - `MerkleTree` insertions are costlier than `Counter` increments (more bytes written)
   - Minimize state reads and writes in circuits
   - Use `pure` circuits for computation that doesn't touch ledger
   - Keep export circuits lean; push complexity into witnesses (off-chain)
   - Table of relative gas costs by operation type (approximate):

| Operation | Gas Impact | Notes |
|-----------|-----------|-------|
| `Counter.increment(n)` | Low | Small state mutation |
| `Map.insert(k, v)` | Medium | Key-value write |
| `Set.insert(v)` | Medium | Similar to Map |
| `MerkleTree.insert(v)` | Higher | Tree rebalancing, more bytes |
| `ledger field = value` | Low | Single cell write |
| `pure circuit` call | Lowest | No state operations |
| `witness` call | None (off-chain) | Happens locally, not on-chain |

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/references/fees-and-gas.md
git commit -m "feat(compact-core): add fees-and-gas reference for compact-transaction-model"
```

---

### Task 6: Write `references/zswap-and-offers.md`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/references/zswap-and-offers.md`

**Convention reference:** Similar depth. Target ~180-220 lines.

**Step 1: Research Zswap and transaction structure**

Use Midnight MCP tools:
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/zswap` — Full Zswap page: offers, inputs, outputs, transient coins, token types
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/building-blocks` — Transaction structure, contract calls, merging, integrity

**Step 2: Write zswap-and-offers.md**

Sections:

1. **Zswap Overview**
   - Based on Zerocash, extended with native token support and atomic swaps
   - UTXO model: unspent transactions not computable (can't link inputs to outputs)
   - Basic component: offer (set of inputs + outputs)
   - Permits contracts to hold funds

2. **Zswap Offers**
   - Four components:
     - Set of inputs (spends)
     - Set of outputs
     - Set of transient coins
     - Balance vector
   - Transient coins: created and spent in same transaction; output immediately followed by input; spends from locally created commitment set (not global, to prevent index collisions)
   - Balance vector: dimensions = all possible token types; input counts positively, output counts negatively; must be non-negative after adjustments (fees, mints)

3. **Inputs (Spends)**
   - Nullifier (unlinkable reference to original commitment)
   - Multi-base Pedersen commitment to type/value vector
   - Optional contract address (iff targeted at a contract)
   - Merkle root of tree containing the corresponding commitment
   - ZK proof that the above are correct
   - Validity: ZK proof verifies AND Merkle root is in valid past roots set

4. **Outputs**
   - Coin commitment (placed in global Merkle tree)
   - Multi-base Pedersen commitment to type/value vector
   - Optional contract address (iff targeted at a contract)
   - Optional ciphertext (if output is toward a user who must receive it)
   - ZK proof that the above are correct
   - Validity: ZK proof verifies

5. **Token Types**
   - 256-bit collision-resistant hash or the zero value (native NIGHT token)
   - Contract-issued tokens: hash of contract address + domain separator
   - Derived via `tokenType(domainSep, contractAddress)` in Compact (see `compact-tokens`)

6. **Transaction Structure**
   - Components:
     - Guaranteed Zswap offer (required)
     - Optional fallible Zswap offer
     - Optional contract calls segment (sequence of calls/deploys + binding commitment + binding randomness)
   - Contract call contains: guaranteed and fallible transcripts, communication commitment (for future cross-contract), ZK proof

7. **Transaction Merging**
   - Enables atomic swaps: two independent transactions combined into one
   - Constraint: at least one must have empty contract calls section (cannot merge two transactions that both have contract calls)
   - Output: new composite transaction with combined effects
   - How integrity is preserved:
     - Pedersen commitments commit to each I/O's type/value
     - Commitments are homomorphically summed across the transaction
     - Only people who created individual components know the opening randomnesses
     - This ensures funds are spent as originally intended

8. **Transaction Integrity**
   - Inherited from Zswap's Pedersen commitment scheme
   - Each I/O contributes to overall commitment via its Pedersen commitment
   - Composite commitment opened for whole-transaction integrity check
   - Contract call section contributes to Pedersen commitment (carries no value vector)
   - Binding enforced via Fiat-Shamir transformed Schnorr proof (knowledge of generator exponent)

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/references/zswap-and-offers.md
git commit -m "feat(compact-core): add zswap-and-offers reference for compact-transaction-model"
```

---

### Task 7: Write `examples/CheckpointUsage.compact`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/examples/CheckpointUsage.compact`

**Convention reference:** Follow the style of `plugins/compact-core/skills/compact-privacy-disclosure/examples/CommitRevealScheme.compact` — file header block explaining the pattern, section comments, detailed inline comments. Target ~120-160 lines.

**Step 1: Research checkpoint usage patterns**

Use Midnight MCP tools:
- `mcp__midnight__midnight-search-compact` query "kernel.checkpoint" — Find real examples
- `mcp__midnight__midnight-get-file` repo "compact-export" path "examples/adt/tests/kernel.compact" — Reference implementation
- `mcp__midnight__midnight-get-file` repo "compact-export" path "examples/adt/exports/kernel.compact" — Export patterns

**Step 2: Write CheckpointUsage.compact**

The example should demonstrate:

1. **File header** — Comment block explaining:
   - What the guaranteed/fallible model is
   - What `kernel.checkpoint()` does (separates guaranteed from fallible sections)
   - What is guaranteed (persists even if fallible fails): authentication, fee accounting, counter increment
   - What is fallible (may not execute): state transfers, risky operations
   - What goes on-chain (public ledger state)
   - What stays private (witness values, secrets)

2. **Pragma and imports** — `pragma language_version >= 0.16 && <= 0.18;` and `import CompactStandardLibrary;`

3. **Custom types** — e.g., `export enum TaskStatus { pending, completed, failed }`

4. **Ledger declarations** — Mix of types:
   - `export ledger owner: Bytes<32>;` — who owns the contract
   - `export ledger taskCount: Counter;` — guaranteed increment
   - `export ledger tasks: Map<Bytes<32>, TaskStatus>;` — fallible state updates
   - `sealed ledger ownerKey: Bytes<32>;` — immutable
   - `ledger kernel: Kernel;`

5. **Witness** — `witness localSecretKey(): Bytes<32>;`

6. **Constructor** — Sets up initial state

7. **Circuit: `submitTask(taskId: Bytes<32>)`** — Main demonstration:
   - Before checkpoint (GUARANTEED):
     - Authenticate the caller (verify secret key matches owner)
     - Increment task counter (`taskCount.increment(1)`)
     - These MUST succeed or the entire transaction is rejected
   - `kernel.checkpoint();`
   - After checkpoint (FALLIBLE):
     - Insert task into tasks map
     - These might fail (e.g., if task already exists)
     - If they fail, the counter increment and authentication still happened

8. **Circuit: `completeTask(taskId: Bytes<32>)`** — Secondary example:
   - Before checkpoint: verify caller is owner, increment completion counter
   - After checkpoint: update task status to completed

9. **Pure circuit helper** — e.g., `pure circuit publicKey(sk: Bytes<32>): Bytes<32>`

All code must be valid Compact syntax: `export circuit ... : []`, proper `disclose()` usage, correct types. Use `mcp__midnight__midnight-compile-contract` to validate if possible.

**Step 3: Validate Compact syntax**

Use `mcp__midnight__midnight-compile-contract` with `skipZk: true` to check compilation. Fix any errors.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/examples/CheckpointUsage.compact
git commit -m "feat(compact-core): add CheckpointUsage example for compact-transaction-model"
```

---

### Task 8: Write `examples/TransactionComposition.compact`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/examples/TransactionComposition.compact`

**Convention reference:** Same style as CheckpointUsage.compact. Target ~100-140 lines.

**Step 1: Write TransactionComposition.compact**

The example should demonstrate:

1. **File header** — Comment block explaining:
   - How multiple exported circuits compose into a single transaction
   - Sequential execution: each call sees the previous call's state changes
   - How contract deployments are fallible-only
   - Cross-contract calls are not yet available

2. **Ledger declarations** — State that multiple circuits interact with:
   - `export ledger balance: Map<Bytes<32>, Uint<64>>;`
   - `export ledger totalDeposits: Counter;`
   - `export ledger totalWithdrawals: Counter;`
   - `export ledger lastAction: Bytes<32>;`

3. **Constructor** — Initializes state

4. **Circuit: `deposit(amount: Uint<64>)`** — First in a transaction sequence:
   - Increments totalDeposits counter
   - Adds to user's balance in Map
   - Sets lastAction

5. **Circuit: `withdraw(amount: Uint<64>)`** — Second in a transaction sequence:
   - Reads balance (which may have been updated by a previous deposit in the same transaction)
   - Asserts sufficient balance
   - Decrements balance
   - Increments totalWithdrawals

6. **Circuit: `checkBalance()`** — Third in a transaction sequence:
   - Reads current state (sees effects of previous calls)
   - Comments explaining that this sees the post-deposit, post-withdrawal state

Comments should explain the sequential execution model: "If deposit() and withdraw() are called in the same transaction, withdraw() sees the balance after deposit()."

**Step 2: Validate Compact syntax**

Use `mcp__midnight__midnight-compile-contract` with `skipZk: true` to check compilation. Fix any errors.

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/examples/TransactionComposition.compact
git commit -m "feat(compact-core): add TransactionComposition example for compact-transaction-model"
```

---

### Task 9: Write `examples/FeeAwareContract.compact`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/examples/FeeAwareContract.compact`

**Convention reference:** Same style. Target ~100-140 lines.

**Step 1: Write FeeAwareContract.compact**

The example should demonstrate gas-conscious patterns:

1. **File header** — Comment block explaining:
   - How gas and fees work (gas bound → dynamic pricing → DUST fee)
   - Why keeping circuits lean matters (more operations = higher gas)
   - The difference between circuit-level (on-chain, costs gas) and witness-level (off-chain, free) computation
   - How to push complexity off-chain via witnesses

2. **Ledger declarations** — Minimal state:
   - `export ledger result: Field;`
   - `export ledger computations: Counter;`

3. **Witness functions** — Off-chain computation:
   - `witness heavyComputation(input: Field): Field;` — Expensive work done off-chain

4. **Circuit: `efficientProcess(input: Field)`** — Gas-efficient pattern:
   - Call witness for heavy computation (off-chain, no gas cost)
   - Verify the result on-chain (cheap assertion, low gas)
   - Store only the verified result (minimal state write)
   - Comments explaining: "The expensive work is done in the witness (off-chain). The circuit only verifies the result (on-chain). This minimizes gas."

5. **Circuit: `inefficientProcess(input: Field)`** — Anti-pattern for comparison:
   - Does the same computation directly in the circuit
   - Comments explaining: "This does all computation on-chain — higher gas cost. Prefer the witness pattern above."

6. **Pure circuit: `verify(input: Field, result: Field): Boolean`** — Pure verification:
   - Comments: "Pure circuits don't access ledger state. They're the cheapest on-chain operation."

**Step 2: Validate Compact syntax**

Use `mcp__midnight__midnight-compile-contract` with `skipZk: true`. Fix any errors.

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/examples/FeeAwareContract.compact
git commit -m "feat(compact-core): add FeeAwareContract example for compact-transaction-model"
```

---

### Task 10: Write `examples/AtomicSwap.compact`

**Files:**
- Create: `plugins/compact-core/skills/compact-transaction-model/examples/AtomicSwap.compact`

**Convention reference:** Same style. Target ~120-160 lines.

**Step 1: Research atomic swap patterns**

Use Midnight MCP tools:
- `mcp__midnight__midnight-search-compact` query "atomic swap merge transaction offer" — Find any existing patterns
- `mcp__midnight__midnight-fetch-docs` path `/develop/how-midnight-works/building-blocks` section "Merging" — Merging rules

**Step 2: Write AtomicSwap.compact**

The example should demonstrate the contract side of an atomic swap:

1. **File header** — Comment block explaining:
   - Transaction merging: two transactions combined into one composite
   - Constraint: at least one must have empty contract calls
   - How Pedersen commitments ensure integrity across merged transactions
   - Practical use case: Alice wants to swap Token A for Bob's Token B

2. **Ledger declarations** — Escrow-style state:
   - `export ledger escrowState: EscrowStatus;` — tracking swap lifecycle
   - `export ledger offered: Map<Bytes<32>, Uint<64>>;` — what's offered
   - `export ledger requested: Map<Bytes<32>, Uint<64>>;` — what's requested
   - `export ledger swapCount: Counter;`
   - `ledger kernel: Kernel;`

3. **Custom types** — `export enum EscrowStatus { empty, offered, completed, cancelled }`

4. **Circuit: `createOffer(offerColor: Bytes<32>, offerAmount: Uint<64>, requestColor: Bytes<32>, requestAmount: Uint<64>)`**
   - Records what the offerer is providing and what they want in return
   - Uses guaranteed phase for the core state changes
   - Comments explaining this is one side of the swap

5. **Circuit: `acceptOffer()`**
   - Verifies the counterparty is providing what was requested
   - Completes the swap
   - Comments explaining that in a real atomic swap, this transaction would be merged with the counterparty's transaction

6. **Circuit: `cancelOffer()`**
   - Allows the original offerer to cancel if not yet accepted

Comments throughout should explain the transaction merging model: "In a real deployment, Alice's createOffer transaction would be merged with Bob's token transfer transaction. The Pedersen commitment scheme ensures neither party can cheat."

**Step 3: Validate Compact syntax**

Use `mcp__midnight__midnight-compile-contract` with `skipZk: true`. Fix any errors.

**Step 4: Commit**

```bash
git add plugins/compact-core/skills/compact-transaction-model/examples/AtomicSwap.compact
git commit -m "feat(compact-core): add AtomicSwap example for compact-transaction-model"
```

---

### Task 11: Update plugin.json Keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add transaction-model keywords**

Add the following keywords to the existing `keywords` array (don't remove any existing ones):
- `"transaction-model"`
- `"guaranteed-phase"`
- `"fallible-phase"`
- `"checkpoint"`
- `"transaction-semantics"`
- `"dust-fees"`
- `"gas-model"`
- `"atomic-swap"`
- `"transaction-merging"`
- `"zswap-offers"`
- `"state-conflicts"`

**Step 2: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add transaction-model keywords to plugin.json"
```

---

### Task 12: Final Review and Compilation Verification

**Files:**
- All files in `plugins/compact-core/skills/compact-transaction-model/`

**Step 1: Verify all example files compile**

For each `.compact` example file, run `mcp__midnight__midnight-compile-contract` with `skipZk: true`:
- `CheckpointUsage.compact`
- `TransactionComposition.compact`
- `FeeAwareContract.compact`
- `AtomicSwap.compact`

Fix any compilation errors. If the compiler service is unavailable, use `mcp__midnight__midnight-extract-contract-structure` for static analysis as a fallback.

**Step 2: Cross-reference check**

Verify that:
- SKILL.md reference routing table lists all 4 reference files and 4 examples
- All cross-references to other skills use correct names (`compact-structure`, `compact-ledger`, `compact-tokens`)
- No content overlap: this skill doesn't re-explain token operations (→ `compact-tokens`), ledger ADTs (→ `compact-ledger`), or circuit syntax (→ `compact-structure`)
- All Compact code uses valid syntax: `export circuit ... : []`, proper `disclose()`, correct pragma

**Step 3: Commit any fixes**

```bash
git add plugins/compact-core/skills/compact-transaction-model/
git commit -m "fix(compact-core): address compilation errors in compact-transaction-model examples"
```
