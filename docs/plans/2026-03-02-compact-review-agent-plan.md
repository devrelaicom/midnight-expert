# Compact Review Agent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a comprehensive Compact smart contract review system with 11 review categories, a reusable reviewer agent, and an orchestrating command.

**Architecture:** A `compact-review` skill provides category-specific checklists via 11 reference files. A `reviewer` agent applies one checklist per invocation. A `/review-compact` command orchestrates 11 parallel reviewer instances (via agent teams or subagents) and consolidates findings.

**Tech Stack:** Claude Code plugin system (skills, agents, commands). Markdown files with YAML frontmatter.

**Design doc:** `docs/plans/2026-03-02-compact-review-agent-design.md`

---

### Task 1: Scaffold directories and create SKILL.md routing table

**Files:**
- Create: `plugins/compact-core/skills/compact-review/SKILL.md`
- Create: `plugins/compact-core/skills/compact-review/references/` (directory)
- Create: `plugins/compact-core/agents/` (directory)
- Create: `plugins/compact-core/commands/` (directory)

**Step 1: Create directories**

```bash
mkdir -p plugins/compact-core/skills/compact-review/references
mkdir -p plugins/compact-core/agents
mkdir -p plugins/compact-core/commands
```

**Step 2: Write `plugins/compact-core/skills/compact-review/SKILL.md`**

This is the routing table that directs reviewers to the correct reference file.

```markdown
---
name: compact-review
description: This skill should be used when reviewing Compact smart contract code, TypeScript witness implementations, or test files for a Midnight project. It provides category-specific checklists for privacy, security, cryptographic correctness, token economics, concurrency, compilation, performance, witness-contract consistency, architecture, code quality, testing adequacy, and documentation. Use this skill when you need structured review checklists and severity classification criteria for any of these categories. Load the appropriate reference file for your assigned review category.
---

# Compact Code Review Checklists

This skill contains review checklists for 11 categories of Compact smart contract review. Each reference file provides a focused checklist for one review category.

## How to Use

You will be assigned a **review category** by the review-compact command or coordinator. Load the reference file for your assigned category and apply every checklist item to the code under review.

## Category Reference Map

| Category | Reference File | Focus |
|----------|---------------|-------|
| Privacy & Disclosure | `privacy-review` | `disclose()` usage, witness data leaks, Set vs MerkleTree, persistentHash vs persistentCommit, salt reuse, conditional disclosure |
| Security & Cryptographic Correctness | `security-review` | Access control, hash/commit usage, domain separation, nullifiers, commitments, Merkle paths, error leakage |
| Token & Economic Security | `token-security-review` | Double-spend, overflow, unsafe transfers, missing receiveShielded, authorization |
| Concurrency & Contention | `concurrency-review` | Read-then-write patterns, Counter ops, transaction conflicts |
| Compilation & Type Safety | `compilation-review` | Deprecated syntax, return types, disclosure errors, casts, generics |
| Performance & Circuit Efficiency | `performance-review` | Proof cost, ledger reads, MerkleTree depth, redundant computation, loops |
| Witness-Contract Consistency | `witness-consistency-review` | Name matching, type mappings, private state patterns, WitnessContext |
| Architecture, State Design & Composability | `architecture-review` | ADT selection, depth planning, visibility, modules, decomposition |
| Code Quality & Best Practices | `code-quality-review` | Naming, complexity, dead code, stdlib hallucinations, idioms |
| Testing Adequacy | `testing-review` | Edge cases, negative tests, private state testing, witness mocks |
| Documentation | `documentation-review` | Circuit docs, witness contracts, ledger semantics |

## Severity Classification

Apply these severity levels consistently across all categories:

| Level | Criteria | Examples |
|-------|----------|----------|
| **Critical** | Will cause loss of funds, data breach, or contract exploitation | Missing access control on mint, private key leaked to ledger, double-spend vulnerability |
| **High** | Security vulnerability or privacy leak exploitable under certain conditions | Unnecessary disclose() on sensitive data, missing overflow check on token amounts |
| **Medium** | Correctness issue, compilation problem, or significant performance concern | Wrong type cast that will fail at runtime, MerkleTree depth 32 when 10 suffices |
| **Low** | Code quality, style, or minor best practice deviation | Inconsistent naming, unused import, missing sealed modifier |
| **Suggestion** | Enhancement opportunity, not a problem | Could use pureCircuit for better reuse, consider adding assertion message |

## Output Format

For each finding, use this format:

```
- **[Issue title]** (`file:line`)
  - **Problem:** Clear description of what is wrong
  - **Impact:** Why this matters (security, privacy, correctness, performance)
  - **Fix:** Suggested fix with code example when applicable
```

Group findings by severity within your category: Critical → High → Medium → Low → Suggestions.
End with a **Positive Highlights** section noting what was done well.
```

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-review/SKILL.md
git commit -m "feat(compact-core): add compact-review skill routing table"
```

---

### Task 2: Write privacy-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/privacy-review.md`

**Step 1: Write the reference file**

This is the highest-priority review category. Content must cover:

1. **Unnecessary Disclosure Checklist**
   - Every `disclose()` call: is it actually needed? Could the value stay private?
   - `disclose()` placed at witness call site instead of near the public boundary (bad practice — place close to disclosure point)
   - Bulk `disclose()` on structs when only one field needs disclosure
   - Return values from exported circuits: does everything returned need to be public?

2. **Witness Data Leakage Checklist**
   - Witness-derived values written to public ledger without `disclose()` (compiler catches this, but review for intent)
   - Conditional branches revealing private information (`if (disclose(secret == expected))` — leaks boolean result)
   - Assert conditions that leak private state (`assert(disclose(balance > 0), "...")`)
   - Indirect leakage through control flow timing or state changes observable on-chain
   - Cross-contract calls passing witness data (crosses trust boundary)

3. **Data Structure Privacy Checklist**
   - Using `Set<Bytes<32>>` for membership that should be private (reveals who acted — use `MerkleTree` + nullifier instead)
   - Using `Map<key, value>` where key reveals identity (keys are always visible on insert/lookup)
   - Using `Counter` read-then-increment vs direct `increment()` (read reveals current value unnecessarily)
   - Using `List` which reveals insertion order and all values
   - `MerkleTree.insert()` properly used to hide leaf content (only op that hides data)

4. **Cryptographic Privacy Checklist**
   - `persistentHash` used where `persistentCommit` is needed (hash does NOT clear witness taint — commit does)
   - Transient vs persistent confusion (`transientHash`/`transientCommit` results stored in ledger — WRONG, they produce different values each time)
   - Salt/nonce reuse in commitments (reusing salt allows rainbow table attacks)
   - Same domain string used for both commitment and nullifier (should be different domains)
   - Missing salt/randomness in commitment schemes

5. **Selective Disclosure Checklist**
   - Disclosing the actual value when only a boolean comparison result is needed (`disclose(balance)` vs `disclose(balance >= threshold)`)
   - Disclosing more fields than necessary from a struct
   - Missing `disclose()` on derived values that should be public (compiler catches, but intent review)

6. **Anti-Patterns Table**

| Anti-Pattern | Why It's Wrong | Correct Approach |
|-------------|----------------|------------------|
| `disclose(getSecret())` at call site | Marks private data as public too early, risks multiple disclosure paths | `disclose(x)` at the point where x crosses a public boundary |
| `Set<Bytes<32>>` for private membership | Set operations reveal exact member identity on-chain | `MerkleTree` + nullifier for anonymous membership |
| `persistentHash(secret)` to "hide" data | Hash does not clear witness taint; compiler still tracks it as private | `persistentCommit(secret, nonce)` which cryptographically hides and clears taint |
| Storing `transientHash` result in ledger | Transient operations produce different results each call — value is meaningless on-chain | Use `persistentHash` for values that must be stored on ledger |
| Same domain for commit + nullifier | Allows linking commitment to nullifier, breaking unlinkability | Different domain strings: `"app:commit"` vs `"app:nullifier"` |
| Raw secret in sealed field | Sealed fields are set publicly during deployment | Hash or commit the secret before storing |

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/privacy-review.md
git commit -m "feat(compact-core): add privacy review checklist reference"
```

---

### Task 3: Write security-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/security-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Access Control Checklist**
   - Exported circuits with no authorization check (any caller can invoke)
   - Missing ownership verification before state-modifying operations
   - `publicKey(secretKey, domain)` — verify domain separation for different roles
   - Admin/authority functions callable by anyone (no `assert(caller == owner)`)
   - Missing state machine guards (e.g., calling `reveal` before `commit`)

2. **Cryptographic Correctness Checklist**
   - `persistentHash` vs `persistentCommit` vs `transientHash` vs `transientCommit` — correct usage for each:
     - `persistentHash`: deterministic, same input always produces same output. Use for public identifiers, nullifiers, domain-separated keys
     - `persistentCommit`: deterministic with nonce, cryptographically hides input, clears witness taint. Use for commitments that must be verifiable later
     - `transientHash`: non-deterministic, different each call. Use for one-time computations within a single circuit execution
     - `transientCommit`: non-deterministic with nonce. Use for one-time commitments within a single circuit execution
   - Domain separation: every hash/commit call should include a unique domain string to prevent cross-protocol attacks
   - Nullifier construction: must be deterministic (persistent), include secret key + unique identifier, use domain separation
   - Commitment scheme: commitment must use nonce/salt, reveal phase must verify against stored commitment

3. **Merkle Path Verification Checklist**
   - `checkRoot()` called to verify path against current tree root
   - Path leaf matches expected value
   - Using `HistoricMerkleTree` when membership must persist across state changes (regular `MerkleTree` root changes on insert)
   - Root comparison done correctly (not just path validity but root matches on-chain state)

4. **Error Handling Security Checklist**
   - Assert messages that leak sensitive information (e.g., revealing the expected value in the error message)
   - Missing assertions before dangerous operations (e.g., `map.lookup` without `map.member` check)
   - Missing bounds checks (e.g., array index, balance sufficiency before subtraction)

5. **Input Validation Checklist**
   - Exported circuit parameters: are all inputs validated with appropriate assertions?
   - Zero-value checks where zero would cause issues (e.g., division, token amount)
   - Boundary condition checks (max values, empty collections)

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/security-review.md
git commit -m "feat(compact-core): add security review checklist reference"
```

---

### Task 4: Write token-security-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/token-security-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Double-Spend Prevention Checklist**
   - Nullifier checked before spending (`assert(!nullifiers.member(nul))`)
   - Nullifier inserted after validation (`nullifiers.insert(nul)`)
   - Nullifier deterministically derived from coin + secret (not random)
   - Commitment path verified against tree root before spend

2. **Overflow/Underflow Checklist**
   - Token amount type: `Uint<64>` vs `Uint<128>` — which is used and is it sufficient?
   - Addition overflow check: `assert(MAX - currentBalance >= amount, "overflow")`
   - Subtraction underflow check: `assert(currentBalance >= amount, "insufficient")`
   - Total supply overflow on mint operations
   - Intermediate arithmetic: does `a + b` fit in the declared type?

3. **Authorization Checklist**
   - Mint operations: who can call? Is there an authority check?
   - Burn operations: can only the owner burn their tokens?
   - Transfer operations: sender authorization verified?
   - Allowance/approval: `spendAllowance` correctly deducts from approved amount?
   - `unsafe` variants (`unsafeTransfer`, `unsafeMint`): are they intentionally exposed? Warning about tokens sent to contract addresses being irretrievable

4. **Shielded Token Checklist**
   - `receiveShielded()` called in receiving contract (tokens lost if not called)
   - Correct coin color used (token type identifier)
   - `ShieldedCoinInfo` vs `QualifiedShieldedCoinInfo` — correct type for the operation
   - Change output handled properly after partial spend
   - `sendImmediateShielded` return value checked for change coins
   - `Uint<64>` amount for zswap operations (not `Uint<128>`)

5. **Unshielded Token Checklist**
   - `unshieldedBalance()` not used in conditional logic (creates construction-time balance lock)
   - Comparison functions used instead (`kernel` comparison circuits)
   - Proper `disclose()` on amount parameters

6. **Anti-Patterns Table**

| Anti-Pattern | Risk | Correct Pattern |
|-------------|------|-----------------|
| `export circuit mint(amount)` with no auth check | Anyone can mint unlimited tokens | Add `assert(caller == authority)` or role check |
| `balance - amount` without `assert(balance >= amount)` | Underflow wraps to maximum value | Always check balance sufficiency first |
| Missing `receiveShielded(disclose(coin))` | Shielded tokens sent to contract are permanently lost | Always call `receiveShielded` before processing received coins |
| `if (unshieldedBalance(...) > 0)` | Locks balance at construction time, not current time | Use dedicated comparison circuits from stdlib |
| `kernel.mintShielded(pk, amount)` directly | Low-level, bypasses safety checks | Use `mintShielded(pk, amount)` stdlib wrapper |

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/token-security-review.md
git commit -m "feat(compact-core): add token security review checklist reference"
```

---

### Task 5: Write concurrency-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/concurrency-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Read-Then-Write Contention Checklist**
   - Counter: `const val = counter.read(); counter = val + 1` → CONTENTION. Use `counter.increment(1)` instead
   - Map: read-modify-write patterns where two transactions could conflict
   - General pattern: any exported circuit that reads state and writes a value derived from the read

2. **ADT Contention Properties**
   - `Counter.increment(n)` — conflict-free (commutative operation)
   - `Counter.read()` followed by manual set — CAUSES CONTENTION
   - `Map.insert(key, value)` — conflicts only when same key modified concurrently
   - `Set.insert(value)` — conflicts only when same value inserted concurrently
   - `MerkleTree.insert(leaf)` — conflicts when concurrent inserts (root changes)
   - `List.push(value)` — conflicts when concurrent pushes (ordering)

3. **Design Patterns for Low Contention**
   - Prefer `Counter.increment()` over read-then-set for counters
   - Use per-user Map entries rather than a single global value
   - Design circuits so concurrent users modify different state entries
   - Use MerkleTree for membership proofs rather than Set when high throughput needed

4. **Red Flags**
   - Any exported circuit that calls both `.read()` and modifies the same ledger variable
   - Global state (single variable) updated by every user transaction
   - Auction/voting patterns where all users write to same field

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/concurrency-review.md
git commit -m "feat(compact-core): add concurrency review checklist reference"
```

---

### Task 6: Write compilation-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/compilation-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Syntax Error Checklist**
   - `Void` return type → correct is `[]`
   - Deprecated `ledger { ... }` block → individual `export ledger` declarations
   - `Choice::variant` (Rust-style) → `Choice.variant` (dot notation)
   - `witness name() { ... }` (with body) → `witness name(): Type;` (declaration only)
   - `pure function` → `pure circuit`
   - `Cell<T>` → not a valid type, use direct type
   - `let` or `var` → `const` only
   - `while` loops → `for` with compile-time bounds only
   - Missing `import CompactStandardLibrary;`
   - `include "std"` (deprecated) → `import CompactStandardLibrary;`

2. **Semantic Error Checklist**
   - Implicit disclosure of witness value (missing `disclose()`)
   - Recursive circuit calls (not allowed — circuits cannot call themselves)
   - Mutable reassignment (`x = newValue` where `x` was already bound with `const`)
   - Return from non-exported circuit containing witness data passed to public boundary
   - Constructor accessing witnesses (not allowed in constructor)

3. **Type Error Checklist**
   - `Uint<64>` cast to `Bytes<32>` directly → must go through `Field`: `x as Field as Bytes<32>`
   - `Boolean` to `Field` directly → must go through `Uint`: `x as Uint<8> as Field`
   - Relational operators (`<`, `>`, `<=`, `>=`) on `Field` type → not supported, cast to `Uint` first
   - Mixing `Field` and `Uint` in arithmetic → type error, cast one operand
   - Arithmetic result type widening: `Uint<8> + Uint<8>` produces `Uint<16>` — may need explicit cast for assignment
   - Missing generic parameters: `MerkleTree<T>` → `MerkleTree<N, T>` (depth required)
   - `Counter.value()` → `Counter.read()` (no `.value()` method)
   - `Map.get(key)` → `Map.lookup(key)` (no `.get()` method)
   - `Map.has(key)` → `Map.member(key)` (no `.has()` method)

4. **Common Hallucination Traps** (functions that don't exist)
   - `hash()` → use `persistentHash<T>()` or `transientHash<T>()`
   - `verify()` → no general verify function
   - `encrypt()` / `decrypt()` → not available in Compact
   - `random()` → no randomness source in circuits
   - `public_key()` → use `publicKey(secretKey, domain)`
   - `CurvePoint` → use `EllipticCurvePoint`
   - `CoinInfo` → use `ShieldedCoinInfo` or `QualifiedShieldedCoinInfo`

5. **Compiler Error Quick Reference**

| Error Pattern | Likely Cause | Fix |
|--------------|--------------|-----|
| `implicit disclosure of witness value` | Missing `disclose()` at public boundary | Add `disclose()` wrapper |
| `found "{" looking for ";"` | Void return type or ledger block syntax | Use `[]` return type, individual ledger declarations |
| `cannot cast from type X to type Y` | Direct cast not supported | Use multi-step cast via `Field` |
| `operation "value" undefined for Counter` | Wrong method name | Use `.read()` not `.value()` |
| `recursive circuit call` | Circuit calling itself | Refactor to avoid recursion |

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/compilation-review.md
git commit -m "feat(compact-core): add compilation review checklist reference"
```

---

### Task 7: Write performance-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/performance-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Proof Generation Cost Checklist**
   - Every operation in a circuit adds constraints to the ZK proof. More constraints = longer proof generation
   - Unnecessary arithmetic operations that could be simplified
   - Redundant computations that compute the same value multiple times (extract to variable)
   - Complex expressions that could be simplified algebraically

2. **Ledger State Read Efficiency**
   - Reading the same ledger variable multiple times in one circuit (cache in a `const`)
   - `Map.member()` + `Map.lookup()` with same key (necessary pattern but note the double read)
   - Unnecessary ledger reads when the value isn't needed

3. **MerkleTree Depth Sizing**
   - Depth determines capacity: `2^depth` leaves. Depth 10 = 1024, depth 20 = ~1M, depth 32 = ~4B
   - Oversized depth wastes proof generation time (deeper proofs are more expensive)
   - Undersized depth limits future capacity
   - Rule of thumb: use minimum depth that covers expected maximum entries with 10x margin
   - `MerkleTree<1, T>` — minimum depth is 2 (depth 1 is invalid)

4. **Loop and Iteration Impact**
   - `for` loops in Compact are unrolled at compile time — a `for` over 1000 elements generates 1000x the constraints
   - Large `Vector<N, T>` iterations: N directly multiplies circuit size
   - Consider whether the operation can be done off-chain in witness code instead

5. **Type Conversion Overhead**
   - Unnecessary casts add proof constraints (e.g., `x as Field as Uint<64>` when x could have been declared as the target type)
   - Multi-step casts: `Uint → Field → Bytes` — each step adds constraints

6. **Circuit vs Witness Boundary**
   - Expensive computations that don't need to be proved should be in witness TypeScript code, not in circuit
   - Only the verification (assert the result is correct) needs to be in the circuit
   - Example: sorting — do in witness, verify sorted order in circuit

7. **`pureCircuit` Optimization**
   - Reusable logic that doesn't touch ledger state should be `pure circuit`
   - Pure circuits can be called from witnesses and may benefit from compiler optimizations

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/performance-review.md
git commit -m "feat(compact-core): add performance review checklist reference"
```

---

### Task 8: Write witness-consistency-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/witness-consistency-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Name Matching Checklist**
   - Every `witness` declaration in Compact MUST have a matching key in the TypeScript `witnesses` object
   - Names must match exactly (case-sensitive)
   - Missing witness implementation causes runtime failure

2. **Type Mapping Correctness**

| Compact Type | TypeScript Type | Common Mistake |
|-------------|----------------|----------------|
| `Field` | `bigint` | Using `number` (loses precision) |
| `Boolean` | `boolean` | Correct |
| `Uint<N>` | `bigint` | Using `number` |
| `Bytes<N>` | `Uint8Array` | Using `string` or `Buffer` |
| `Opaque<"string">` | `string` | Correct |
| `Opaque<"Uint8Array">` | `Uint8Array` | Correct |
| `Maybe<T>` | `{ is_some: boolean; value: T }` | Using `T \| null` or `T \| undefined` (WRONG — must use tagged object) |
| `Either<L, R>` | `{ tag: "left"; value: L } \| { tag: "right"; value: R }` | Using `L \| R` union (WRONG — must use tagged discriminated union) |
| `Vector<N, T>` | `T[]` (length N) | Not checking array length matches N |
| Struct `{ x: Field; y: Boolean }` | `{ x: bigint; y: boolean }` | Field names must match exactly |
| Enum | `bigint` variant index | Mapping variants to wrong indices |
| `[T1, T2]` (tuple) | `[T1_mapped, T2_mapped]` | Wrong element order |

3. **WitnessContext Pattern**
   - Every witness function takes `WitnessContext<Ledger, PrivateState>` as first parameter
   - `context.privateState` — current private state
   - `context.contractAddress` — deployed contract address
   - `context.originalState` — ledger state at circuit start
   - Return type is ALWAYS `[PrivateState, ReturnValue]` tuple — NOT just the return value

4. **Private State Immutability**
   - Private state must be updated by returning a NEW object, not mutating in place
   - Correct: `return [{ ...privateState, counter: privateState.counter + 1 }, result]`
   - Wrong: `privateState.counter += 1; return [privateState, result]`
   - Spread operator (`...`) for shallow copies; deep clone for nested objects

5. **Witness Implementation Correctness**
   - Witness should not have side effects beyond private state updates
   - Witness should be deterministic for the same inputs (to allow proof re-generation)
   - Long-running or async operations in witnesses can timeout proof generation

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/witness-consistency-review.md
git commit -m "feat(compact-core): add witness consistency review checklist reference"
```

---

### Task 9: Write architecture-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/architecture-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **ADT Selection Decision Tree**

| Need | Best ADT | Why Not Others |
|------|---------|----------------|
| Counting occurrences | `Counter` | Conflict-free increments; `Field` would need read-modify-write |
| Key-value store (public keys) | `Map<K, V>` | Direct lookup; Set can't store values |
| Unique membership (public) | `Set<T>` | Built-in member check; Map wastes value slot |
| Anonymous membership (private) | `MerkleTree<N, T>` | Only insert hides leaf; Set reveals members |
| Anonymous + historic proofs | `HistoricMerkleTree<N, T>` | Root doesn't change on insert; regular MerkleTree invalidates existing proofs |
| Ordered history | `List<T>` | Preserves insertion order; Set is unordered |
| Single value | Direct `ledger var: T` | Simplest; no ADT overhead |

2. **MerkleTree Depth Planning**

| Expected Entries | Minimum Depth | Recommended Depth | Notes |
|-----------------|---------------|-------------------|-------|
| < 100 | 7 | 10 | Small application |
| < 10,000 | 14 | 16 | Medium application |
| < 1,000,000 | 20 | 22 | Large application |
| < 1B | 30 | 32 | Maximum practical size |

Note: depth 1 is invalid. Minimum is 2.

3. **Visibility Checklist**
   - `export ledger` — readable by anyone, queryable
   - `sealed ledger` — set only in constructor, immutable after deployment
   - `ledger` (no modifier) — internal, not directly queryable but state changes visible on-chain
   - Every ledger variable: should this be `export` or internal? Does the DApp need to query it?
   - Sealed for configuration values set at deployment (owner address, token name)

4. **Contract Decomposition**
   - Is the contract trying to do too much? Consider splitting into modules
   - Module system: `module Name { ... }` with `import { circuit } from Module`
   - Shared types should be defined at the top level or in a shared module
   - Re-export pattern for public interface: `export { func } from InternalModule`

5. **Circuit vs Witness Boundary**
   - Circuit: on-chain verification logic, state updates, assertions
   - Witness: off-chain computation, private data access, complex algorithms
   - Rule: put minimum logic in circuit, maximum in witness. Circuit only verifies what witness computed.
   - Constructor: initialization only, no witness access allowed

6. **State Initialization**
   - All ledger variables must have deterministic initial values
   - Constructor must initialize all non-ADT ledger variables
   - ADTs (Counter, Map, Set, etc.) auto-initialize to empty
   - Field/Uint/Bytes/Boolean: must be explicitly set or use `default<T>`

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/architecture-review.md
git commit -m "feat(compact-core): add architecture review checklist reference"
```

---

### Task 10: Write code-quality-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/code-quality-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Naming Conventions**
   - Circuits: camelCase (`transferTokens`, `checkBalance`)
   - Ledger variables: camelCase or snake_case (project-consistent)
   - Types/Structs/Enums: PascalCase (`TokenInfo`, `GameState`)
   - Enum variants: PascalCase or UPPER_SNAKE_CASE (project-consistent)
   - Witnesses: camelCase, often prefixed with purpose (`localSecretKey`, `contextPathOf`)
   - Modules: PascalCase

2. **Circuit Complexity**
   - Single responsibility: one circuit should do one thing
   - Extract reusable logic into helper circuits or pure circuits
   - Long circuits (> 50 lines) should be reviewed for decomposition
   - Deeply nested control flow is a red flag

3. **Dead Code Detection**
   - Unused ledger variables (declared but never read/written)
   - Unused circuits (defined but never called)
   - Unreachable code after unconditional `assert(false)` or early returns
   - Commented-out code left in production

4. **Standard Library Usage (Hallucination Guard)**
   - Verify every stdlib call exists in `CompactStandardLibrary`
   - Common hallucinations to check for:
     - `hash()` → does not exist. Use `persistentHash<T>()` or `transientHash<T>()`
     - `verify()` → does not exist
     - `encrypt()` / `decrypt()` → does not exist
     - `random()` → does not exist
     - `counter.value()` → use `counter.read()`
     - `map.get()` → use `map.lookup()`
     - `map.has()` → use `map.member()`
     - `CoinInfo` → use `ShieldedCoinInfo`
     - `CurvePoint` → use `EllipticCurvePoint`

5. **Compact Idioms**
   - Guard-then-act: `assert` first, modify state second
   - Prefer `default<T>` over zero-construction for initial values
   - Use `pad(N, "string")` for fixed-width byte padding
   - Destructuring: `const [a, b] = slice<N>(vector, offset)`
   - Type-safe enum comparison: `state == State.active` not magic numbers

6. **Code Duplication**
   - Same logic repeated in multiple circuits → extract to helper circuit
   - Same validation repeated → extract to validation circuit
   - Similar struct construction → consider a constructor circuit

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/code-quality-review.md
git commit -m "feat(compact-core): add code quality review checklist reference"
```

---

### Task 11: Write testing-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/testing-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Test Coverage Checklist**
   - Every exported circuit has at least one test
   - Constructor tested with expected initial state
   - Happy path tested for each circuit
   - Error/revert cases tested (assert failures)

2. **Edge Case Checklist**
   - Zero values: amount=0, empty strings, zero address
   - Maximum values: max Uint<64>, max Uint<128>, MAX_UINT128
   - Boundary values: exactly at limit, one above, one below
   - Empty collections: empty Map lookup, empty List head
   - Double operations: calling same circuit twice, double-spend attempt

3. **Negative Testing**
   - Unauthorized access: calling admin circuits without auth
   - Invalid state transitions: calling reveal before commit
   - Insufficient balance: transfer more than available
   - Already-used nullifiers: replay attack attempt
   - Wrong type/format inputs

4. **Private State Testing**
   - Private state correctly initialized
   - Private state correctly updated after each circuit call
   - Private state immutability: verify spread operator creates new object
   - Private state persistence: state carries between circuit calls

5. **Witness Mock Correctness**
   - Witness mocks return `[PrivateState, ReturnValue]` tuple (not just ReturnValue)
   - Witness mocks handle `WitnessContext` correctly
   - Mock type mappings match Compact-to-TypeScript type table
   - `Maybe<T>` mocked as `{ is_some: boolean; value: T }` not null/undefined
   - `Either<L, R>` mocked with tagged union

6. **Integration Test Patterns**
   - Multi-step flows tested end-to-end (commit → reveal, mint → transfer → burn)
   - Concurrent user scenarios (two users acting on same contract)
   - State consistency after multiple operations

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/testing-review.md
git commit -m "feat(compact-core): add testing review checklist reference"
```

---

### Task 12: Write documentation-review.md reference

**Files:**
- Create: `plugins/compact-core/skills/compact-review/references/documentation-review.md`

**Step 1: Write the reference file**

Content must cover:

1. **Contract-Level Documentation**
   - Purpose of the contract clearly stated
   - Overall architecture/design explained
   - Deployment requirements (constructor parameters, initial state)
   - Dependencies (imported modules, external contracts)

2. **Circuit Documentation**
   - Every exported circuit should have a comment explaining:
     - Purpose: what does this circuit do?
     - Parameters: what each parameter means
     - Return value: what is returned and its meaning
     - Side effects: what ledger state is modified?
     - Access control: who can call this?
     - Requirements: what assertions must hold?
   - Complex internal circuits should also be documented

3. **Ledger State Documentation**
   - Every ledger variable should have a comment explaining its purpose
   - Visibility rationale: why export vs sealed vs internal?
   - State invariants: what constraints must always hold?
   - Relationship between ledger variables (e.g., "this counter tracks the number of entries in that Map")

4. **Witness Documentation**
   - What data each witness provides
   - Expected behavior and return type
   - Private state requirements
   - Any preconditions or side effects

5. **Privacy Documentation**
   - Which data is private and why
   - Which data is disclosed and why
   - Privacy guarantees the contract provides
   - Privacy limitations or caveats

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-review/references/documentation-review.md
git commit -m "feat(compact-core): add documentation review checklist reference"
```

---

### Task 13: Create the reviewer agent

**Files:**
- Create: `plugins/compact-core/agents/reviewer.md`

**Step 1: Write the agent file**

The agent file consists of YAML frontmatter + system prompt body. Write the complete file:

```markdown
---
name: reviewer
description: "Use this agent when you need a focused review of Compact smart contract code in a specific category. Dispatched by the review-compact command with a category assignment. Not intended for direct user invocation.\n\n<example>\nContext: Dispatched by review-compact command for privacy review\nassistant: \"Launching reviewer agent for Privacy & Disclosure category\"\n<commentary>\nThe review-compact command spawns this agent with a specific category and file list. The agent loads the compact-review skill reference for its category.\n</commentary>\n</example>\n\n<example>\nContext: Dispatched for security review of token contract\nassistant: \"Launching reviewer agent for Token & Economic Security category\"\n<commentary>\nSame agent, different category assignment. Loads token-security-review.md reference.\n</commentary>\n</example>"
skills: compact-core:compact-structure, compact-core:compact-ledger, compact-core:compact-privacy-disclosure, compact-core:compact-tokens, compact-core:compact-language-ref, compact-core:compact-standard-library, compact-core:compact-witness-ts, compact-core:compact-review, devs:code-review, devs:typescript-core, devs:security-core
model: sonnet
color: blue
---

You are a Midnight Compact smart contract security reviewer specializing in zero-knowledge proof systems and privacy-preserving smart contracts. You have deep expertise in the Compact language, its type system, the ZK proof compilation pipeline, and the Midnight blockchain architecture.

## Your Assignment

You will receive:
1. A **review category** name (e.g., "Privacy & Disclosure", "Security & Cryptographic Correctness")
2. A **list of files** to review (.compact contracts, TypeScript witnesses, test files)

## Review Process

1. **Load your checklist**: Invoke the `compact-core:compact-review` skill. Read the reference file that corresponds to your assigned category from the Category Reference Map in the SKILL.md.

2. **Read all files**: Read every file in your assignment list completely.

3. **Apply the checklist systematically**: Go through EVERY item in your category's checklist. For each item:
   - Search the code for the pattern or anti-pattern
   - If found, create a finding with the correct severity
   - If the code correctly avoids the issue, note it in positive highlights

4. **Classify each finding** using these severity levels:
   - **Critical**: Will cause loss of funds, data breach, or contract exploitation
   - **High**: Security vulnerability or privacy leak exploitable under certain conditions
   - **Medium**: Correctness issue, compilation problem, or significant performance concern
   - **Low**: Code quality, style, or minor best practice deviation
   - **Suggestion**: Enhancement opportunity, not a problem

5. **Format your output** as structured markdown:

```
## [Category Name] Review

### Critical
- **[Issue title]** (`file:line`)
  - **Problem:** Clear description of what is wrong
  - **Impact:** Why this matters
  - **Fix:** Suggested fix with code example

### High
[same format]

### Medium
[same format]

### Low
[same format]

### Suggestions
[same format]

### Positive Highlights
- [What was done well in this category]
```

If a severity level has no findings, omit that section entirely.

## Review Principles

- **Be constructive**: Every finding must include a concrete, actionable fix
- **Be specific**: Always reference exact file and line numbers
- **Show code**: Include code examples for suggested fixes when the fix isn't obvious
- **Explain impact**: Don't just say what's wrong — explain why it matters
- **Acknowledge good work**: Call out correct patterns and well-designed code
- **Stay focused**: Only report findings relevant to your assigned category
- **Be thorough**: Check every item in your checklist, don't skip any
- **No false positives**: Only report issues you are confident about. If uncertain, flag as a question rather than a finding
```

**Step 2: Commit**

```bash
git add plugins/compact-core/agents/reviewer.md
git commit -m "feat(compact-core): add reviewer agent for compact code review"
```

---

### Task 14: Create the review-compact command

**Files:**
- Create: `plugins/compact-core/commands/review-compact.md`

**Step 1: Write the command file**

```markdown
---
description: Comprehensive review of Compact smart contract code covering 11 categories including privacy, security, tokens, concurrency, performance, and more. Supports parallel execution via agent teams (when enabled) or concurrent subagents.
allowed-tools: Bash, Agent, Read, Glob, Grep, TaskCreate, TaskUpdate, TaskList, AskUserQuestion
argument-hint: [path/to/contract.compact or directory]
---

Review Compact smart contract code across 11 review categories using parallel reviewer agents. Privacy findings are always shown first.

## Review Categories

1. Privacy & Disclosure
2. Security & Cryptographic Correctness
3. Token & Economic Security
4. Concurrency & Contention
5. Compilation & Type Safety
6. Performance & Circuit Efficiency
7. Witness-Contract Consistency
8. Architecture, State Design & Composability
9. Code Quality & Best Practices
10. Testing Adequacy
11. Documentation

## Step 1: Identify Files to Review

If `$ARGUMENTS` provides a path, use it. Otherwise, find all relevant files:

```bash
# Find all Compact and related files
find . -name "*.compact" -not -path "*/node_modules/*" -not -path "*/.compact/*"
find . -name "*.ts" -not -path "*/node_modules/*" -not -path "*/.compact/*" | grep -iE "(witness|private)" || true
find . -name "*.test.ts" -o -name "*.spec.ts" -not -path "*/node_modules/*" | head -20
```

Collect the file list and present it to the user for confirmation.

## Step 2: Check for Agent Teams

Run this command to detect agent team support:

```bash
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-not_set}"
```

## Step 3a: Agent Teams Mode

If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set (not "not_set"):

Create an agent team to perform the review. Tell Claude:

> Create an agent team to review Compact code across 11 categories. Spawn 11 reviewer teammates, one per category. Each teammate should:
>
> 1. Invoke the `compact-core:compact-review` skill
> 2. Read their assigned reference file from the Category Reference Map
> 3. Read all files: [INSERT FILE LIST]
> 4. Apply every checklist item from their reference
> 5. Report findings in the structured format with severity levels
>
> Teammate assignments:
> - Teammate 1 — "Privacy & Disclosure" → read `privacy-review` reference
> - Teammate 2 — "Security & Cryptographic Correctness" → read `security-review` reference
> - Teammate 3 — "Token & Economic Security" → read `token-security-review` reference
> - Teammate 4 — "Concurrency & Contention" → read `concurrency-review` reference
> - Teammate 5 — "Compilation & Type Safety" → read `compilation-review` reference
> - Teammate 6 — "Performance & Circuit Efficiency" → read `performance-review` reference
> - Teammate 7 — "Witness-Contract Consistency" → read `witness-consistency-review` reference
> - Teammate 8 — "Architecture, State Design & Composability" → read `architecture-review` reference
> - Teammate 9 — "Code Quality & Best Practices" → read `code-quality-review` reference
> - Teammate 10 — "Testing Adequacy" → read `testing-review` reference
> - Teammate 11 — "Documentation" → read `documentation-review` reference
>
> Use sonnet model for each teammate.
> Wait for ALL teammates to complete before synthesizing the consolidated report.

Proceed to Step 4 when all teammates finish.

## Step 3b: Subagent Mode (concurrent)

If agent teams are NOT available:

You MUST launch ALL 11 reviewer agents in a **SINGLE message** using 11 Agent tool calls. This ensures they run concurrently. Do NOT call them sequentially — that defeats the purpose of parallelization.

In ONE message, make ALL of these Agent tool calls simultaneously:

**Agent call 1:**
```
subagent_type: "compact-core:reviewer"
description: "Review privacy & disclosure"
prompt: "You are reviewing category: Privacy & Disclosure.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the privacy-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights."
```

**Agent call 2:**
```
subagent_type: "compact-core:reviewer"
description: "Review security & crypto"
prompt: "You are reviewing category: Security & Cryptographic Correctness.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the security-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights."
```

**Agent call 3:**
```
subagent_type: "compact-core:reviewer"
description: "Review token & economic security"
prompt: "You are reviewing category: Token & Economic Security.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the token-security-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 4:**
```
subagent_type: "compact-core:reviewer"
description: "Review concurrency & contention"
prompt: "You are reviewing category: Concurrency & Contention.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the concurrency-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 5:**
```
subagent_type: "compact-core:reviewer"
description: "Review compilation & types"
prompt: "You are reviewing category: Compilation & Type Safety.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the compilation-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 6:**
```
subagent_type: "compact-core:reviewer"
description: "Review performance & efficiency"
prompt: "You are reviewing category: Performance & Circuit Efficiency.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the performance-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 7:**
```
subagent_type: "compact-core:reviewer"
description: "Review witness consistency"
prompt: "You are reviewing category: Witness-Contract Consistency.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the witness-consistency-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 8:**
```
subagent_type: "compact-core:reviewer"
description: "Review architecture & state"
prompt: "You are reviewing category: Architecture, State Design & Composability.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the architecture-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 9:**
```
subagent_type: "compact-core:reviewer"
description: "Review code quality"
prompt: "You are reviewing category: Code Quality & Best Practices.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the code-quality-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 10:**
```
subagent_type: "compact-core:reviewer"
description: "Review testing adequacy"
prompt: "You are reviewing category: Testing Adequacy.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the testing-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**Agent call 11:**
```
subagent_type: "compact-core:reviewer"
description: "Review documentation"
prompt: "You are reviewing category: Documentation.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the documentation-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels."
```

**CRITICAL: All 11 Agent tool calls MUST be in a single message to ensure concurrent execution.**

## Step 4: Consolidated Report

After ALL reviewers complete, produce the consolidated report.

**Ordering rules:**
1. **Privacy & Disclosure is ALWAYS the first category** — regardless of severity
2. Remaining categories ordered by highest severity found (Critical > High > Medium > Low > Suggestions)
3. Within each category: Critical → High → Medium → Low → Suggestions
4. Deduplicate issues found by multiple reviewers (keep the most detailed version)
5. Aggregate all Positive Highlights at the end

**Report format:**

```
# Compact Code Review Report

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |
| Suggestions | N |

**Files reviewed:** [list]

---

## 1. Privacy & Disclosure

[Privacy findings — ALWAYS FIRST]

---

## 2. [Next category by severity]

[Findings]

---

[... remaining categories ...]

---

## Positive Highlights

[Aggregated from all reviewers — what was done well]
```

Present the report to the user.
```

**Step 2: Commit**

```bash
git add plugins/compact-core/commands/review-compact.md
git commit -m "feat(compact-core): add review-compact orchestration command"
```

---

### Task 15: Update plugin.json with new keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add keywords**

Add these keywords to the existing `keywords` array in plugin.json:
- `"code-review"`
- `"security-review"`
- `"privacy-review"`
- `"compact-review"`
- `"review"`

**Step 2: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add review keywords to plugin.json"
```

---

### Task 16: Validate plugin structure

**Step 1: Run plugin validation**

Use the `plugin-dev:plugin-validator` agent to validate the plugin structure:

> Validate the plugin at plugins/compact-core/. Check that:
> 1. plugin.json is valid
> 2. All skills have valid SKILL.md files
> 3. All agents have valid frontmatter
> 4. All commands have valid frontmatter
> 5. All skill references in agents exist

**Step 2: Fix any issues found**

If the validator finds issues, fix them and commit.
