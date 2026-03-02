# compact-circuit-costs Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `compact-circuit-costs` skill to the compact-core plugin covering ZK circuit costs, runtime gas model, and state cost implications for Compact smart contracts on Midnight.

**Architecture:** A new skill directory under `plugins/compact-core/skills/compact-circuit-costs/` with a SKILL.md entry point and three reference files organized by cost dimension: circuit/proving costs, runtime/gas costs, and state costs. Content is sourced from Midnight MCP research including compiler documentation, PLONK benchmarks, and SDK runtime sources.

**Tech Stack:** Markdown documentation, Compact code examples, plugin.json configuration

---

### Task 1: Scaffold Directory Structure

**Files:**
- Create: `plugins/compact-core/skills/compact-circuit-costs/SKILL.md` (empty placeholder)
- Create: `plugins/compact-core/skills/compact-circuit-costs/references/` (directory)

**Step 1: Create the skill directory and empty SKILL.md**

```bash
mkdir -p plugins/compact-core/skills/compact-circuit-costs/references
touch plugins/compact-core/skills/compact-circuit-costs/SKILL.md
```

**Step 2: Verify directory structure**

Run: `find plugins/compact-core/skills/compact-circuit-costs -type f -o -type d | sort`
Expected:
```
plugins/compact-core/skills/compact-circuit-costs
plugins/compact-core/skills/compact-circuit-costs/SKILL.md
plugins/compact-core/skills/compact-circuit-costs/references
```

**Step 3: Commit scaffold**

```bash
git add plugins/compact-core/skills/compact-circuit-costs/
git commit -m "feat(compact-core): scaffold compact-circuit-costs skill directory structure"
```

---

### Task 2: Write SKILL.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-circuit-costs/SKILL.md`

**Step 1: Write the complete SKILL.md**

Write the following content to `plugins/compact-core/skills/compact-circuit-costs/SKILL.md`:

````markdown
---
name: compact-circuit-costs
description: This skill should be used when the user asks about Compact circuit costs, ZK proof generation costs, gate counts, loop unrolling behavior, hash function cost tradeoffs (transientHash vs persistentHash), commitment function costs (transientCommit vs persistentCommit), pure circuit optimization benefits, vector operation costs (map/fold/slice unrolling), compiler optimization passes, runtime gas model (readTime, computeTime, bytesWritten, bytesDeleted), ledger state storage costs, or how to write cost-efficient Compact smart contracts on Midnight.
---

# Circuit Costs & Optimization

This skill covers the cost model for Compact smart contracts across three dimensions: circuit/proving costs, runtime gas costs, and state costs. For loop and vector syntax details, see `compact-language-ref`. For ADT operation semantics, see `compact-ledger`. For hash and commitment function signatures, see `compact-standard-library`. For pure circuit declarations, see `compact-structure`.

## Three-Dimension Cost Model

Midnight contracts have three independent cost dimensions. Optimizing one may increase another.

| Dimension | What It Affects | Key Driver | Paid By |
|-----------|----------------|------------|---------|
| Circuit/Proving | Proof generation time (user-side latency) | Gate count in ZK circuit | Transaction submitter |
| Runtime/Gas | Transaction fees | readTime, computeTime, bytesWritten, bytesDeleted | Transaction submitter |
| State | Ongoing storage requirements | Ledger type choice and data volume | Network |

## Circuit Cost Quick Reference

### Loop Unrolling

All `for` loops are fully unrolled at compile time. Each iteration produces a complete copy of the loop body in the circuit.

| Pattern | Gate Cost | Example |
|---------|-----------|---------|
| `for (const i of 0..N) { body }` | N × body_cost | `0..100` with 1 add = 100 additions |
| Nested: `for i of 0..A { for j of 0..B { body } }` | A × B × body_cost | `0..10` × `0..10` = 100× body |
| Triple nested | A × B × C × body_cost | `0..9` × `0..9` × `0..9` = 729× body |

Nested loops are the most common source of circuit size explosions. A 4-level nested loop with 9 iterations each produces 6,561 copies of the innermost body.

### Hash and Commitment Function Costs

| Function | Circuit Cost | Return Type | Safe for Ledger State? | Protects from Disclosure? |
|----------|-------------|-------------|----------------------|--------------------------|
| `transientHash<T>` | **LOW** (circuit-native) | `Field` | No | No |
| `persistentHash<T>` | **HIGH** (SHA-256) | `Bytes<32>` | Yes | No |
| `transientCommit<T>` | **LOW** (circuit-native) | `Field` | No | Yes |
| `persistentCommit<T>` | **HIGH** (SHA-256) | `Bytes<32>` | Yes | Yes |

**Rule of thumb:** Use `transient*` for in-circuit consistency checks. Use `persistent*` for anything stored in ledger state. Use `degradeToTransient()`/`upgradeFromTransient()` to convert between domains.

### Pure Circuit Benefits

A circuit is pure if it has no ledger operations, no witness calls, and no calls to impure circuits.

| Property | Impure Circuit | Pure Circuit |
|----------|---------------|-------------|
| ZK proving keys generated | Yes | **No** |
| zkir generated | Yes | **No** |
| State transcript entries | Yes | **No** |
| Can be fully inlined | Sometimes | **Always** |
| Requires on-chain transaction | Yes | **No** |

Declare with `pure circuit` or `export pure circuit` to enforce purity and make the circuit available in TypeScript via `pureCircuits`.

### Vector Operation Costs

`map`, `fold`, and `slice` are all unrolled at compile time, just like loops.

| Operation | Cost | Example |
|-----------|------|---------|
| `map(f, vector)` | length × f_cost | `map((x) => x + x, vec10)` = 10 additions |
| `fold(f, init, vector)` | length × f_cost | `fold((acc, v) => acc + v, 0, vec10)` = 10 additions |
| `slice<N>(vector, offset)` | Zero additional gates | Compile-time extraction |
| Spread `[...vector]` | Zero additional gates | Compile-time operation |

Complex anonymous circuits inside `map`/`fold` multiply: every statement in the body is replicated per element.

### Compiler Optimizations

The compiler performs these optimization passes automatically (in order):

1. **Copy propagation** — Replaces variable references with their definitions
2. **Constant folding** — Evaluates constant expressions at compile time (`3 + 4` → `7`)
3. **Partial folding** — Simplifies expressions like `x + 0` → `x`
4. **Dead binding elimination** — Removes unreferenced const declarations
5. **Common subexpression elimination** — Reuses identical computations
6. **Known-true assert elimination** — Removes `assert(true, ...)`
7. **Disabled call elimination** — Removes calls gated by known-false conditions

These cascade: copy propagation creates dead bindings, constant folding enables copy propagation, etc. Non-literal vector indexes resolve through this cascade (e.g., `v[2 * i]` where `i = 4` becomes `v[8]`).

## Gas Model Quick Reference

| Dimension | What Contributes | Optimization Strategy |
|-----------|-----------------|----------------------|
| `readTime` | Ledger state reads (`.read()`, `.lookup()`, `.member()`) | Cache reads in local variables; avoid redundant state queries |
| `computeTime` | Circuit computation complexity | Reduce gate count; use pure circuits where possible |
| `bytesWritten` | Ledger state writes (`.insert()`, `.increment()`, field assignments) | Batch writes; minimize state mutations |
| `bytesDeleted` | Ledger state deletions (`.remove()`, `.resetToDefault()`) | Delete only when necessary |

Circuits can have a `gasLimit` set; execution fails if the limit is exceeded.

## State Cost Quick Reference

| Ledger Type | State Size | Growth Pattern | Privacy | Relative Cost |
|-------------|-----------|----------------|---------|---------------|
| Direct field (`Field`, `Bytes<N>`, etc.) | Fixed | None | Public | Lowest |
| `Counter` | Fixed (Uint\<64>) | None | Public | Low |
| `Map<K, V>` | Variable | Grows with entries | Public (keys + values visible) | Medium |
| `Set<T>` | Variable | Grows with entries | Public (elements visible) | Medium |
| `List<T>` | Variable | Grows with entries | Public | Medium |
| `MerkleTree<N, T>` | Fixed (2^N capacity) | Pre-allocated | **Private** (insertions hidden) | Higher |
| `HistoricMerkleTree<N, T>` | Fixed + root history | Pre-allocated + history | **Private** | Highest |

`sealed` fields eliminate state-write circuit costs entirely since they are set once at construction.

## Cost Decision Trees

### Which Hash Function?

```
Need to store result in ledger state?
├── Yes → persistentHash / persistentCommit (SHA-256, stable across upgrades)
└── No → Is this an in-circuit consistency check only?
    ├── Yes → transientHash / transientCommit (circuit-native, much cheaper)
    └── No → Need to protect from disclosure?
        ├── Yes → transientCommit (cheap + disclosure protection)
        └── No → transientHash (cheapest option)
```

### Is My Circuit Too Expensive?

Check in order:
1. **Nested loops?** Flatten or reduce iteration counts
2. **`persistentHash` in loops?** Switch to `transientHash` if result isn't stored in ledger
3. **Unnecessary ledger reads?** Cache `.read()`/`.lookup()` results in local variables
4. **Could any sub-circuit be pure?** Extract state-independent logic into `pure circuit`
5. **Large vector operations?** Check that `map`/`fold` bodies are minimal
6. **Redundant computations?** The compiler handles CSE, but restructuring can help

### Which Ledger Type Minimizes Cost?

```
What kind of data?
├── Single numeric value → Counter (cheapest)
├── Key-value lookups → Map<K, V>
│   └── Need nested state? → Map<K, Map<...>> (only Map supports nesting)
├── Membership checks →
│   ├── Privacy required? → MerkleTree<N, T> (insertions hidden)
│   └── No privacy needed? → Set<T> (cheaper, simpler)
├── Ordered sequence → List<T> (front-access only)
└── Single immutable value → sealed ledger field (zero ongoing cost)
```

## Common Expensive Patterns

| Expensive Pattern | Better Alternative | Why |
|---|---|---|
| Nested loops when a flat loop suffices | Restructure to single loop | Nested loops multiply gate count |
| `persistentHash` inside a loop body | `transientHash` if result isn't stored | SHA-256 costs many more gates than circuit-native hash |
| Impure circuit that only computes from inputs | Refactor to `pure circuit` | Avoids zkir/key generation and state transcript |
| Repeated `.read()` / `.lookup()` on same key | Cache in `const` and reuse | Each ledger operation has gas cost |
| Complex computation in `map`/`fold` body | Extract to named pure circuit | Clearer and enables the compiler to optimize better |
| Large MerkleTree when Set would suffice | Use `Set<T>` if privacy not needed | MerkleTree has higher state cost and requires path proofs |
| Unsealed field used as immutable config | Use `sealed ledger` | Sealed eliminates state-write circuits entirely |

## Reference Files

| Topic | Reference File |
|-------|---------------|
| Gate counts, loop unrolling, hash costs, pure circuits, vector ops, compiler passes, proving benchmarks | `references/circuit-proving-costs.md` |
| Gas model dimensions, RunningCost, CostModel, gas limits, cost-efficient patterns | `references/runtime-gas-costs.md` |
| Ledger type cost comparison, privacy-cost tradeoffs, sealed fields, state design, nested ADTs | `references/state-costs.md` |
````

**Step 2: Verify the SKILL.md follows conventions**

Run: `head -3 plugins/compact-core/skills/compact-circuit-costs/SKILL.md`
Expected: YAML front matter starting with `---`

Run: `grep -c '##' plugins/compact-core/skills/compact-circuit-costs/SKILL.md`
Expected: A count of section headers (should be ~12-15)

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-circuit-costs/SKILL.md
git commit -m "feat(compact-core): write complete SKILL.md for compact-circuit-costs"
```

---

### Task 3: Write references/circuit-proving-costs.md

**Files:**
- Create: `plugins/compact-core/skills/compact-circuit-costs/references/circuit-proving-costs.md`

**Step 1: Write the complete reference file**

Write the following content to `plugins/compact-core/skills/compact-circuit-costs/references/circuit-proving-costs.md`:

````markdown
# Circuit and Proving Costs

Detailed reference for understanding and minimizing the ZK circuit costs of Compact smart contracts. Circuit size is the primary driver of proof generation time, which directly affects user-perceived latency.

## How Compact Circuits Become ZK Proofs

The Compact compiler transforms your contract through several stages:

```
Compact source → AST → Circuit IR → zkir → PLONK gates → Proving/Verifying keys
```

1. **Compact source** — Your `.compact` file
2. **AST** — Abstract syntax tree after parsing
3. **Circuit IR** — Intermediate representation after optimization passes
4. **zkir** — Zero-knowledge intermediate representation (serialized circuit)
5. **PLONK gates** — PLONKish arithmetization with rows, columns, and constraints
6. **Keys** — Proving key (used by transaction submitter) and verifying key (used by network)

The final circuit uses PLONKish arithmetization:
- **k** (size parameter): The circuit has 2^k rows
- **Advice columns**: Private witness data; more columns = larger proof
- **Fixed columns**: Selector columns for gates; compiled into verifying key
- **Lookup arguments**: Precomputed tables for expensive operations (e.g., SHA-256 for `persistentHash`)
- **Gates**: Constraints that the prover must satisfy

Every operation in your Compact code produces gates. The total number of gates determines 2^k, which determines proving time.

## Loop Unrolling In Depth

Compact's `for` loops have compile-time-determined bounds only. The compiler fully unrolls every loop, replacing it with N copies of the loop body, each specialized for that iteration's index value.

### Single Loop

```compact
// This produces 100 additions in the circuit
export circuit sumFirst100(): Field {
  const result = 0 as Field;
  for (const i of 0..100) {
    result = result + 1 as Field;
  }
  return result;
}
```

The compiler generates the equivalent of:
```
result_0 = 0 + 1
result_1 = result_0 + 1
result_2 = result_1 + 1
...
result_99 = result_98 + 1
```

Each iteration's body contributes its full gate cost. If the body contains 5 operations, a loop of 100 iterations produces 500 operations worth of gates.

### Nested Loops

Nested loops multiply. The total gate cost is:

**total_gates = iterations₁ × iterations₂ × ... × iterationsₙ × body_cost**

```compact
// 9 × 9 = 81 copies of the inner body
export circuit nested2(): [] {
  for (const i of 1..10) {
    for (const j of 1..10) {
      assert(i > 0, "positive");  // This assert appears 81 times in the circuit
    }
  }
}

// 9 × 9 × 9 = 729 copies
export circuit nested3(): [] {
  for (const i of 1..10) {
    for (const j of 1..10) {
      for (const k of 1..10) {
        assert(i > 0, "positive");  // 729 copies
      }
    }
  }
}

// 9 × 9 × 9 × 9 = 6,561 copies — avoid this!
export circuit nested4(): [] {
  for (const i of 1..10) {
    for (const j of 1..10) {
      for (const k of 1..10) {
        for (const l of 1..10) {
          assert(i > 0, "positive");  // 6,561 copies
        }
      }
    }
  }
}
```

### Optimization: Flatten When Possible

Before:
```compact
// 10 × 10 = 100 iterations, each doing a hash
for (const row of 0..10) {
  for (const col of 0..10) {
    const idx = (row * 10 + col) as Uint<8>;
    // process grid[idx]
  }
}
```

After:
```compact
// 100 iterations, same work, but the compiler may optimize better
for (const idx of 0..100) {
  // process grid[idx] directly
}
```

Both produce 100 iterations, but the flat version avoids the intermediate multiplication for row/col computation in each inner iteration.

### Optimization: Reduce Iteration Count

Before:
```compact
// Search through all 256 possible values
for (const i of 0..256) {
  if (values[i] == target) {
    found = true;
  }
}
```

If the data structure allows it, consider using a `Set` or `Map` for O(1) membership checks instead of scanning with a loop.

## Hash and Commitment Function Costs

### Why transientHash Is Cheaper

`transientHash` uses a circuit-native hash function optimized for the proving system. It operates directly on `Field` elements, which are the native data type of the arithmetic circuit.

`persistentHash` uses SHA-256, which is not native to the arithmetic circuit. SHA-256 requires hundreds of gates per round (bit manipulations, XOR, rotations) that must be expressed as arithmetic constraints. The compiler uses lookup tables to reduce this cost, but it remains significantly more expensive than the circuit-native alternative.

### Cost Comparison Table

| Function | Return Type | ~Relative Circuit Cost | State Persistence | Disclosure Protection |
|----------|-------------|----------------------|-------------------|----------------------|
| `transientHash<T>` | `Field` | 1× (baseline) | Not safe across upgrades | No — requires `disclose()` |
| `persistentHash<T>` | `Bytes<32>` | ~10-50× | Safe across upgrades | No — requires `disclose()` |
| `transientCommit<T>` | `Field` | ~1× | Not safe across upgrades | Yes — protects input |
| `persistentCommit<T>` | `Bytes<32>` | ~10-50× | Safe across upgrades | Yes — protects input |

The exact cost ratio depends on the input type and size. The key insight is that `transient*` functions are **dramatically** cheaper in-circuit.

### When to Use Each

**Use `transientHash` / `transientCommit` when:**
- The result is used for in-circuit consistency checks only
- The result is compared within the same transaction
- The result is not stored in ledger state
- Performance is critical (tight loops, large vectors)

**Use `persistentHash` / `persistentCommit` when:**
- The result is stored in ledger state (Map, Set, MerkleTree, or direct field)
- The result must be verifiable across contract upgrades
- The result is part of a commitment scheme that spans multiple transactions

**Use `degradeToTransient()` / `upgradeFromTransient()` when:**
- You need to mix persistent and transient values in a single computation
- `degradeToTransient(x: Bytes<32>): Field` — Convert persistent hash to transient domain
- `upgradeFromTransient(x: Field): Bytes<32>` — Convert transient hash to persistent domain

### Anti-Pattern: persistentHash in a Loop

```compact
// EXPENSIVE: SHA-256 computed 100 times
for (const i of 0..100) {
  const h = persistentHash<Uint<64>>(values[i]);
  // use h for consistency check only
}

// BETTER: circuit-native hash computed 100 times
for (const i of 0..100) {
  const h = transientHash<Uint<64>>(values[i]);
  // use h for consistency check only
}
```

If the hash results need to be stored in ledger state after the loop, compute `transientHash` inside the loop for consistency checks, then compute `persistentHash` only for the final values that need persistence.

## Pure Circuit Optimization

### Definition

A Compact circuit is **pure** if its body contains:
- No ledger operations (`.read()`, `.insert()`, `.increment()`, etc.)
- No witness calls
- No calls to any impure circuit

### Benefits

Pure circuits receive special treatment from the compiler:

1. **No zkir generated** — The circuit is not serialized as a standalone ZK circuit
2. **No proving/verifying keys** — No key material is produced or needed
3. **Full inlining** — The circuit body is substituted at every call site during optimization
4. **No state transcript entries** — The circuit produces no public transcript (no on-chain state changes)
5. **TypeScript execution** — Available via `pureCircuits` for local computation without proof generation

### Declaration

```compact
// Internal pure circuit
pure circuit computeScore(a: Field, b: Field): Field {
  return a * a + b * b;
}

// Exported pure circuit (available in TypeScript via pureCircuits)
export pure circuit hashPair(x: Bytes<32>, y: Bytes<32>): Field {
  return transientHash<[Bytes<32>, Bytes<32>]>([x, y]);
}
```

The `pure` modifier causes a compiler error if the circuit is actually impure, catching mistakes early.

### When to Refactor to Pure

Look for circuits that:
- Compute a value entirely from their input parameters
- Don't read or write ledger state
- Don't call witness functions
- Are called from multiple impure circuits (inlining saves duplication)

Before:
```compact
// This circuit is pure but not declared as such
export circuit computeCommitment(value: Field, rand: Field): Field {
  return transientCommit<Field>(value, rand);
}
```

After:
```compact
// Declared pure — no zkir/keys generated, available via pureCircuits
export pure circuit computeCommitment(value: Field, rand: Field): Field {
  return transientCommit<Field>(value, rand);
}
```

### Circuit Composition Costs

When a non-pure circuit calls another non-pure circuit, the callee's body is inlined at the call site. This means:

```compact
// Each call to helper() inlines its full body
circuit helper(): [] {
  ledger_counter.increment(1);
}

// This circuit contains 3 copies of helper's body
export circuit callThrice(): [] {
  helper();
  helper();
  helper();
}
```

Avoid "killer" patterns where circuits call chains of other circuits, each of which calls all previous ones — this creates exponential circuit growth.

## Vector Operation Costs

### map

`map(f, vector)` applies circuit `f` to each element. Since vector lengths are compile-time constants, map is fully unrolled:

```compact
// 10 additions (one per element)
const doubled = [...map((x: Uint<64>): Uint<64> => {
  return (x * 2) as Uint<64>;
}, values)];  // values: Vector<10, Uint<64>>
```

Multi-vector map applies `f` element-wise across multiple vectors:

```compact
// 10 additions (one per pair of elements)
const sums = [...map((a: Field, b: Field): Field => {
  return a + b;
}, vectorA, vectorB)];  // Both Vector<10, Field>
```

### fold

`fold(f, init, vector)` reduces a vector to a single value. Like map, it unrolls completely:

```compact
// 10 sequential additions
const total = fold(
  (acc: Uint<64>, val: Uint<64>): Uint<64> => {
    return (acc + val) as Uint<64>;
  },
  0 as Uint<64>,
  values  // Vector<10, Uint<64>>
);
```

Each element's fold step includes the full body of the anonymous circuit. A complex fold body multiplied by a large vector creates many gates:

```compact
// EXPENSIVE: 100 elements × (1 multiply + 1 add + 1 cast) per step
const weightedSum = fold(
  (acc: Uint<64>, pair: [Uint<64>, Uint<64>]): Uint<64> => {
    const [value, weight] = pair;
    return (acc + value * weight) as Uint<64>;
  },
  0 as Uint<64>,
  pairs  // Vector<100, [Uint<64>, Uint<64>]>
);
```

### slice

`slice<N>(vector, offset)` extracts N elements starting at a compile-time offset. This is a compile-time operation and adds **zero** gates to the circuit.

```compact
// Zero cost — compile-time extraction
const firstFive = slice<5>(myVector, 0);
const lastFive = slice<5>(myVector, 5);
```

### Spread

The spread operator `[...expr]` converts between vector representations at compile time with **zero** gate cost.

## Compiler Optimization Passes

The Compact compiler runs a two-pass optimization system (forward then backward) with seven cascading optimizations. Understanding these helps you write code that the compiler can optimize effectively.

### Pass 1: Copy Propagation

Replaces variable references with their definitions:

```compact
// Before optimization
const x = a + b;
const y = x;       // y is a copy of x
return y * y;

// After copy propagation
const x = a + b;
return x * x;      // y eliminated, x used directly
```

### Pass 2: Constant Folding

Evaluates expressions with constant operands at compile time:

```compact
// Before
const size = 3 + 4;
const vec = slice<size>(data, 0);

// After constant folding
const vec = slice<7>(data, 0);
```

### Pass 3: Partial Folding

Simplifies expressions with identity elements:

```compact
// Before
const result = x + 0;
const scaled = y * 1;

// After partial folding
const result = x;
const scaled = y;
```

### Pass 4: Dead Binding Elimination

Removes `const` declarations that are never referenced:

```compact
// Before
const unused = expensiveComputation(a, b);
const needed = a + b;
return needed;

// After dead binding elimination
const needed = a + b;
return needed;
// unused and its computation are removed entirely
```

### Pass 5: Common Subexpression Elimination (CSE)

Identifies identical computations and computes them once:

```compact
// Before
const sum1 = a + b;
const sum2 = a + b;
return sum1 * sum2;

// After CSE
const sum1 = a + b;
return sum1 * sum1;   // Reuses the single computation
```

### Pass 6: Known-True Assert Elimination

Removes assertions that the compiler can prove are always true:

```compact
// Before
assert(true, "this always passes");
assert(1 > 0, "one is positive");

// After — both removed
```

### Pass 7: Disabled Call Elimination

Removes circuit calls gated by conditions known to be false:

```compact
// Before (if compiler can prove condition is false)
if (false) {
  expensiveCircuit();
}

// After — entire branch removed
```

### Cascade Effects

These passes run iteratively. Each pass can create opportunities for subsequent passes:

1. Copy propagation → creates unreferenced bindings → dead binding elimination
2. Constant folding → creates copy propagation opportunities → more elimination
3. CSE → creates dead bindings → more elimination
4. All passes together → smaller circuit → faster proving

### Non-Literal Vector Indexing

The optimization cascade enables non-literal vector indexes:

```compact
export circuit foo(v: Vector<10, Uint<8>>): Uint<8> {
  const i = 4;
  return v[2 * i];
  // copy propagation: v[2 * 4]
  // constant folding:  v[8]
}
```

The compiler resolves the index through copy propagation and constant folding.

## Proving Time Benchmarks

PLONK proving benchmarks (Intel Core i9-10885H) showing how circuit size affects proving time:

| Circuit Size (rows) | Compile Time | Prove Time | Verify Time |
|---------------------|-------------|------------|-------------|
| 2^5 (32) | 17.6 ms | 16.2 ms | 4.3 ms |
| 2^8 (256) | 47.5 ms | ~30 ms | 4.3 ms |
| 2^10 (1,024) | 97.5 ms | ~65 ms | ~4.3 ms |
| 2^12 (4,096) | 314.7 ms | ~167 ms | ~4.3 ms |
| 2^14 (16,384) | 1.03 s | ~527 ms | ~4.3 ms |
| 2^16 (65,536) | 3.78 s | ~2.0 s | ~4.3 ms |
| 2^18 (262,144) | 13.6 s | ~6.7 s | ~4.3 ms |

Key insights:
- **Proving time scales roughly linearly** with circuit size (doubling rows ≈ doubles proving time)
- **Verification time is constant** (~4.3 ms regardless of circuit size)
- The bottleneck is always the prover (user's device), never the verifier (network)
- A circuit with 2^16 rows takes ~2 seconds to prove — this is the approximate threshold where users start noticing latency
- A circuit with 2^18 rows takes ~7 seconds — likely too slow for interactive use

## Circuit Size Estimation Heuristics

Without running the compiler, use these rules of thumb to estimate relative circuit cost:

1. **Count your loops**: Multiply all nested loop bounds. If the product exceeds ~1,000, your circuit is getting large.
2. **Count hash calls**: Each `persistentHash` inside a loop is expensive. Each `transientHash` is relatively cheap.
3. **Count ledger operations**: Each `.read()`, `.lookup()`, `.insert()`, `.increment()` adds gas cost and potentially circuit cost.
4. **Check for pure refactoring**: Any circuit with no ledger/witness calls should be `pure`.
5. **Estimate total body cost**: For each loop, multiply: (operations per iteration) × (iterations) × (cost per operation type). Field arithmetic is cheapest; hash operations are most expensive.
````

**Step 2: Verify file was created**

Run: `wc -l plugins/compact-core/skills/compact-circuit-costs/references/circuit-proving-costs.md`
Expected: ~300+ lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-circuit-costs/references/circuit-proving-costs.md
git commit -m "feat(compact-core): add circuit-proving-costs reference for compact-circuit-costs"
```

---

### Task 4: Write references/runtime-gas-costs.md

**Files:**
- Create: `plugins/compact-core/skills/compact-circuit-costs/references/runtime-gas-costs.md`

**Step 1: Write the complete reference file**

Write the following content to `plugins/compact-core/skills/compact-circuit-costs/references/runtime-gas-costs.md`:

````markdown
# Runtime Gas Costs

Detailed reference for understanding the Midnight runtime gas model. Gas costs are separate from circuit/proving costs and directly affect transaction fees.

## The Gas Model

Midnight's gas model tracks four cost dimensions for every circuit execution. Each ledger operation contributes to one or more of these dimensions, and the total determines the transaction fee.

### readTime

**What it measures:** The cost of reading state from the ledger.

**Operations that contribute:**
- `counter.read()` — Reading a counter value
- `map.lookup(key)` — Looking up a map entry
- `map.member(key)` — Checking map membership
- `set.member(elem)` — Checking set membership
- `list.head()` — Reading the list head
- `map.isEmpty()`, `set.isEmpty()`, `list.isEmpty()` — Emptiness checks
- `map.size()`, `set.size()`, `list.length()` — Size queries
- `counter.lessThan(n)` — Counter comparison
- `merkleTree.checkRoot(digest)` — Root verification
- `merkleTree.isFull()` — Capacity check
- Direct field reads

**Optimization strategies:**
- Cache read results in local `const` declarations instead of reading the same state multiple times
- Batch related reads together before performing computations
- Avoid reading state inside loops when the value doesn't change between iterations

```compact
// EXPENSIVE: reads counter 3 times
if (counter.read() > 0 as Uint<64>) {
  if (counter.read() < 100 as Uint<64>) {
    return counter.read();
  }
}

// BETTER: read once, use locally
const current = counter.read();
if (current > 0 as Uint<64>) {
  if (current < 100 as Uint<64>) {
    return current;
  }
}
```

### computeTime

**What it measures:** The cost of circuit computation itself.

**Operations that contribute:**
- All arithmetic operations on circuit values
- Hash function evaluations
- Commitment computations
- Conditional branches (both branches are evaluated in ZK circuits)
- Loop body evaluations (all iterations)

**Optimization strategies:**
- Reduce gate count (see `circuit-proving-costs.md`)
- Use `transientHash` instead of `persistentHash` where possible
- Use pure circuits for reusable computation
- Minimize nested loop depth

### bytesWritten

**What it measures:** The cost of writing data to the ledger.

**Operations that contribute:**
- `counter.increment(n)` — Counter updates
- `counter.decrement(n)` — Counter updates
- `map.insert(key, value)` — Adding or updating map entries
- `map.insertDefault(key)` — Adding default entries
- `set.insert(elem)` — Adding set elements
- `list.pushFront(elem)` — Adding list elements
- `merkleTree.insert(leaf)` — Adding tree leaves
- Direct field assignments (`owner = newValue`)

**Optimization strategies:**
- Batch state writes when possible
- Avoid inserting default values if the default will be overwritten immediately
- Prefer updating existing entries over remove-then-insert patterns
- Use `sealed` fields for configuration values set at deployment

```compact
// EXPENSIVE: two writes for what could be one
map.remove(key);
map.insert(key, newValue);

// BETTER: insert overwrites existing entry
map.insert(key, newValue);
```

### bytesDeleted

**What it measures:** The cost of removing data from the ledger.

**Operations that contribute:**
- `map.remove(key)` — Removing map entries
- `set.remove(elem)` — Removing set elements
- `list.popFront()` — Removing list elements
- `counter.resetToDefault()` — Resetting counters
- `map.resetToDefault()` — Clearing maps
- `set.resetToDefault()` — Clearing sets
- `list.resetToDefault()` — Clearing lists
- `merkleTree.resetToDefault()` — Resetting trees

**Optimization strategies:**
- Only delete when necessary — stale entries that are never read again have no computational cost
- Prefer `resetToDefault()` over iterating and removing individual entries
- Consider whether a "soft delete" (setting a flag) is cheaper than actual removal

## RunningCost Structure

The SDK represents gas costs using the `RunningCost` type:

```typescript
interface RunningCost {
  readTime: bigint;
  computeTime: bigint;
  bytesWritten: bigint;
  bytesDeleted: bigint;
}

// Zero-cost starting point
const emptyRunningCost = (): RunningCost => ({
  readTime: 0n,
  computeTime: 0n,
  bytesWritten: 0n,
  bytesDeleted: 0n,
});
```

Each dimension is tracked independently as a `bigint`. The total gas cost is the sum across all dimensions weighted by the cost model.

## CostModel

The `CostModel` defines the per-unit prices for each gas dimension. It is initialized from the network's current parameters:

```typescript
const costModel = CostModel.initialCostModel();
```

Every ledger query during circuit execution is measured against the cost model:

```typescript
const result = circuitContext.currentQueryContext.query(
  program,
  circuitContext.costModel,
  circuitContext.gasLimit,
);
circuitContext.gasCost = result.gasCost;
```

The cost model is a protocol parameter that can change through governance. Contract developers should design for cost efficiency regardless of current pricing, as costs may change over time.

## Gas Limits

Circuits can have a `gasLimit` set to cap total gas consumption. If the limit is exceeded during execution, the transaction fails:

```typescript
// Set a gas limit for the circuit context
context.gasLimit = {
  readTime: 1000n,
  computeTime: 5000n,
  bytesWritten: 2000n,
  bytesDeleted: 500n,
};

// This will throw if gas exceeds the limit
contract.circuits.expensiveOperation(context);
```

Gas limits protect against:
- Runaway computations that exhaust resources
- Unexpected cost spikes from large state operations
- Denial-of-service through expensive circuit calls

## Cost-Efficient Patterns

### Cache Ledger Reads

```compact
// EXPENSIVE: 3 separate reads
export circuit checkAndUpdate(threshold: Uint<64>): [] {
  if (counter.read() > threshold) {
    if (counter.read() < 1000 as Uint<64>) {
      const diff = (1000 as Uint<64> - counter.read()) as Uint<16>;
      counter.increment(diff);
    }
  }
}

// BETTER: 1 read, cached locally
export circuit checkAndUpdate(threshold: Uint<64>): [] {
  const current = counter.read();
  if (current > threshold) {
    if (current < 1000 as Uint<64>) {
      const diff = (1000 as Uint<64> - current) as Uint<16>;
      counter.increment(diff);
    }
  }
}
```

### Minimize State Mutations

```compact
// EXPENSIVE: multiple writes per call
export circuit updateScores(user: Bytes<32>, bonus: Uint<16>): [] {
  scores.lookup(user).increment(bonus);
  scores.lookup(user).increment(bonus);  // Why not just double the bonus?
  totalScore.increment(bonus);
  totalScore.increment(bonus);
}

// BETTER: fewer writes, same result
export circuit updateScores(user: Bytes<32>, bonus: Uint<16>): [] {
  const doubleBonus = (bonus * 2) as Uint<16>;
  scores.lookup(user).increment(doubleBonus);
  totalScore.increment(doubleBonus);
}
```

### Use Sealed Fields for Configuration

```compact
// Without sealed: state-write circuits are generated for admin
export ledger admin: Bytes<32>;

// With sealed: no state-write circuits, lower cost
export sealed ledger admin: Bytes<32>;
```

Sealed fields are set once in the constructor and can never change. This eliminates the need for state-write circuits entirely, reducing both circuit and gas costs for the contract.
````

**Step 2: Verify file was created**

Run: `wc -l plugins/compact-core/skills/compact-circuit-costs/references/runtime-gas-costs.md`
Expected: ~180+ lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-circuit-costs/references/runtime-gas-costs.md
git commit -m "feat(compact-core): add runtime-gas-costs reference for compact-circuit-costs"
```

---

### Task 5: Write references/state-costs.md

**Files:**
- Create: `plugins/compact-core/skills/compact-circuit-costs/references/state-costs.md`

**Step 1: Write the complete reference file**

Write the following content to `plugins/compact-core/skills/compact-circuit-costs/references/state-costs.md`:

````markdown
# State Costs

Detailed reference for understanding how ledger type choices affect storage costs, privacy tradeoffs, and overall contract efficiency. For full ADT operation semantics, see `compact-ledger`. For privacy pattern design, see `compact-privacy-disclosure`.

## Ledger Type Cost Comparison

### Fixed-Size Types

These types have constant storage cost regardless of usage:

| Type | Storage Size | Notes |
|------|-------------|-------|
| `Field` | 1 field element (~32 bytes) | Cheapest single-value storage |
| `Boolean` | 1 field element | Same cost as Field |
| `Uint<N>` | 1 field element | Same cost regardless of N |
| `Bytes<N>` | ⌈N/31⌉ field elements | Grows with byte length |
| Enum | 1 field element | Stored as numeric index |
| Struct | Sum of field sizes | Each field contributes individually |
| `Counter` | 1 Uint\<64> (~8 bytes) | Fixed; cheapest ADT |

### Variable-Size Types

These types grow with the number of entries:

| Type | Storage Per Entry | Growth Pattern | Empty Cost |
|------|------------------|----------------|------------|
| `Map<K, V>` | key_size + value_size | Linear with entries | Minimal (empty map) |
| `Set<T>` | element_size | Linear with entries | Minimal (empty set) |
| `List<T>` | element_size + pointer | Linear with entries | Minimal (empty list) |

### Pre-Allocated Types

These types allocate storage for their maximum capacity at deployment:

| Type | Storage Size | Capacity | Notes |
|------|-------------|----------|-------|
| `MerkleTree<N, T>` | ~2^(N+1) nodes | 2^N leaves | Full tree allocated upfront |
| `HistoricMerkleTree<N, T>` | ~2^(N+1) nodes + root history | 2^N leaves | Larger than MerkleTree due to root history |

MerkleTree depth `N` has significant cost implications:
- `MerkleTree<10, Bytes<32>>` — 1,024 leaf capacity
- `MerkleTree<20, Bytes<32>>` — 1,048,576 leaf capacity
- `MerkleTree<32, Bytes<32>>` — 4,294,967,296 leaf capacity (maximum depth)

Choose the minimum depth that supports your expected membership set size. Oversizing wastes storage; undersizing requires contract redeployment.

## Privacy-Cost Tradeoffs

Different ledger types offer different privacy characteristics at different costs. This is the fundamental tradeoff in Midnight contract design.

### Operation Visibility by Type

| Type | Insert/Write | Read/Lookup | Membership Check | Delete/Remove |
|------|-------------|-------------|-----------------|---------------|
| Direct field | Value visible | Value visible | N/A | N/A |
| `Counter` | Amount visible | Value visible | Comparison visible | N/A |
| `Map<K, V>` | Key + value visible | Key + value visible | Key visible | Key visible |
| `Set<T>` | Element visible | N/A | Element visible | Element visible |
| `List<T>` | Element visible | Value visible | N/A | N/A |
| `MerkleTree<N, T>` | **Leaf hidden** | N/A | **Proven via ZK** | N/A |
| `HistoricMerkleTree<N, T>` | **Leaf hidden** | N/A | **Proven via ZK** | N/A |

Key insight: `MerkleTree` is the only ADT where inserts are shielded and membership is proven without revealing which entry. This privacy comes at the cost of:
- Pre-allocated storage (full tree)
- Path proof computation (O(N) hashes in-circuit for depth N)
- Off-chain path generation (witness provides the proof path)

### Privacy Cost Decision Matrix

| Privacy Need | Cheapest Solution | Notes |
|-------------|------------------|-------|
| No privacy needed | Direct field, Counter, Map, Set | Cheapest; all operations visible |
| Hide values but not keys | `Map<K, Bytes<32>>` with committed values | Store `persistentCommit(value, rand)` as the value |
| Hide membership | `MerkleTree<N, T>` | Only option for private membership proofs |
| Hide membership + accept old proofs | `HistoricMerkleTree<N, T>` | Higher cost than MerkleTree |
| Hide both keys and values | `MerkleTree<N, Bytes<32>>` with commitments | Store commitments as leaves; verify via nullifiers |

### Example: Membership Check Cost Comparison

```compact
// PUBLIC: Set reveals which member is checked
export ledger voters: Set<Bytes<32>>;

export circuit checkVoterPublic(voter: Bytes<32>): Boolean {
  return voters.member(disclose(voter));  // voter identity visible on-chain
}

// PRIVATE: MerkleTree hides which member is proven
export ledger voterTree: MerkleTree<10, Bytes<32>>;

witness get_voter_path(voter: Bytes<32>): MerkleTreePath<10, Bytes<32>>;

export circuit checkVoterPrivate(voter: Bytes<32>): [] {
  const path = get_voter_path(voter);
  const digest = merkleTreePathRoot<10, Bytes<32>>(path);
  assert(voterTree.checkRoot(disclose(digest)), "Not a voter");
  // voter identity NOT revealed on-chain
}
```

The private version costs more (MerkleTree state + path proof computation) but hides which voter is being checked.

## Sealed Fields

The `sealed` modifier makes a ledger field immutable after construction:

```compact
export sealed ledger admin: Bytes<32>;
export sealed ledger maxSupply: Uint<64>;
export sealed ledger contractName: Bytes<32>;
```

### Cost Benefits

1. **No state-write circuits** — The compiler doesn't generate circuits for modifying sealed fields, reducing the contract's overall circuit count
2. **No bytesWritten gas** — After construction, these fields never incur write costs
3. **Simpler verification** — Immutable config values don't need change-tracking logic
4. **Smaller proving keys** — Fewer circuits means less key material to distribute

### When to Use Sealed

Use `sealed` for:
- Admin addresses or public keys
- Contract configuration (thresholds, limits, names)
- Token metadata (domain separator, max supply)
- Any value that should never change after deployment

Do not use `sealed` for:
- Values that need updating (balances, counters, state machines)
- Values set conditionally after deployment

## State Design for Cost

### Choosing the Right Type

| Requirement | Recommended Type | Cost Reasoning |
|-------------|-----------------|----------------|
| Count something | `Counter` | Smallest fixed cost; no key/value overhead |
| Store a single value | Direct field (`Field`, `Bytes<N>`, etc.) | Smallest possible storage |
| Key-value lookups with rare writes | `Map<K, V>` | Efficient reads; write cost acceptable if infrequent |
| Key-value lookups with frequent writes | `Map<K, V>` with batched updates | Same type, but design circuits to minimize write frequency |
| Membership checks (no privacy) | `Set<T>` | Lower overhead than Map; no value storage |
| Membership checks (with privacy) | `MerkleTree<N, T>` | Higher cost but necessary for privacy |
| Ordered data with front access | `List<T>` | Use only when ordering matters |
| Immutable configuration | `sealed` direct field | Zero ongoing state-write cost |
| Complex nested state | `Map<K, Map<...>>` or `Map<K, Counter>` | Only Map supports nesting; adds lookup overhead |

### Counter vs Direct Field for Numeric Values

```compact
// Counter: supports increment/decrement, costs Uint<64> storage
export ledger count: Counter;

// Direct field: supports arbitrary assignment, costs 1 field element
export ledger value: Uint<64>;
```

Use `Counter` when you need atomic increment/decrement operations. Use a direct field when you need arbitrary value assignment. Counter is slightly more specialized but provides safe concurrent increment semantics.

### Map Size Management

Maps grow unboundedly. If your contract inserts entries without ever removing them, state costs grow linearly over the contract's lifetime. Strategies:

1. **Bounded maps** — Check `size()` before inserting and reject when full
2. **Periodic cleanup** — Provide a circuit that removes stale entries
3. **Fixed-size alternative** — Use a `Vector` if the number of entries is known at compile time

```compact
export ledger entries: Map<Bytes<32>, Uint<64>>;

export circuit addEntry(key: Bytes<32>, value: Uint<64>): [] {
  // Bound the map size to prevent unbounded growth
  assert(entries.size() < 1000 as Uint<64>, "Map is full");
  entries.insert(disclose(key), disclose(value));
}
```

## Nested ADT Cost Implications

Only `Map` supports values that are other ledger state types. Nesting adds cost at each level of access:

```compact
export ledger nested: Map<Bytes<32>, Map<Bytes<32>, Counter>>;
```

### Access Cost Chain

Each level of nesting requires a `lookup()` (which costs `readTime` gas):

```compact
// 2 lookups + 1 read = 3 read operations
const value = nested.lookup(outerKey).lookup(innerKey).read();

// 2 lookups + 1 increment = 2 reads + 1 write
nested.lookup(outerKey).lookup(innerKey).increment(1);
```

### When Nesting Is Worth It

**Use nesting when:**
- The data naturally has a hierarchical key structure (e.g., user → resource → count)
- You need per-user or per-category sub-state
- The inner state type provides useful operations (e.g., Counter's atomic increment)

**Avoid nesting when:**
- A composite key achieves the same result: `Map<[Bytes<32>, Bytes<32>], Uint<64>>` instead of `Map<Bytes<32>, Map<Bytes<32>, Uint<64>>>`
- The inner map/set/counter is rarely accessed
- You only need flat key-value storage

### Initialization Cost

Nested ADTs must be initialized with `default<V>` before use. Each initialization is a state write:

```compact
// 3 writes to initialize a nested structure
nested.insert(userKey, default<Map<Bytes<32>, Counter>>);       // Write 1
nested.lookup(userKey).insert(resourceKey, default<Counter>);   // Write 2
nested.lookup(userKey).lookup(resourceKey).increment(1);        // Write 3
```

For contracts with many users, this initialization cost is incurred once per user but adds up. Consider whether the nesting provides enough benefit to justify the per-user setup cost.
````

**Step 2: Verify file was created**

Run: `wc -l plugins/compact-core/skills/compact-circuit-costs/references/state-costs.md`
Expected: ~200+ lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-circuit-costs/references/state-costs.md
git commit -m "feat(compact-core): add state-costs reference for compact-circuit-costs"
```

---

### Task 6: Update plugin.json with New Keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add cost-related keywords to the keywords array**

Add these keywords after the existing ones in `plugin.json`:
- `"circuit-costs"`
- `"gate-count"`
- `"proving-time"`
- `"optimization"`
- `"gas-model"`
- `"loop-unrolling"`
- `"transientHash"`
- `"persistentHash"`
- `"pure-circuit"`
- `"compiler-optimization"`

The updated keywords array should end with:
```json
    "compiler-generated",
    "circuit-costs",
    "gate-count",
    "proving-time",
    "optimization",
    "gas-model",
    "loop-unrolling",
    "transientHash",
    "persistentHash",
    "pure-circuit",
    "compiler-optimization"
```

**Step 2: Verify plugin.json is valid JSON**

Run: `cat plugins/compact-core/.claude-plugin/plugin.json | python3 -m json.tool > /dev/null && echo "Valid JSON"`
Expected: `Valid JSON`

**Step 3: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add circuit-costs keywords to plugin.json"
```

---

### Task 7: Final Verification

**Files:** None (verification only)

**Step 1: Verify all files exist**

Run: `find plugins/compact-core/skills/compact-circuit-costs -type f | sort`
Expected:
```
plugins/compact-core/skills/compact-circuit-costs/SKILL.md
plugins/compact-core/skills/compact-circuit-costs/references/circuit-proving-costs.md
plugins/compact-core/skills/compact-circuit-costs/references/runtime-gas-costs.md
plugins/compact-core/skills/compact-circuit-costs/references/state-costs.md
```

**Step 2: Verify SKILL.md has front matter**

Run: `head -3 plugins/compact-core/skills/compact-circuit-costs/SKILL.md`
Expected:
```
---
name: compact-circuit-costs
description: This skill should be used when...
```

**Step 3: Verify all cross-references in SKILL.md point to existing files**

Run: `grep 'references/' plugins/compact-core/skills/compact-circuit-costs/SKILL.md`
Expected: Each referenced file should match one of the files found in Step 1.

**Step 4: Verify plugin.json is valid and contains new keywords**

Run: `python3 -c "import json; data=json.load(open('plugins/compact-core/.claude-plugin/plugin.json')); print(len(data['keywords']), 'keywords'); assert 'circuit-costs' in data['keywords']"`
Expected: `58 keywords` (48 original + 10 new)

**Step 5: Verify the total skill count for the plugin**

Run: `ls -d plugins/compact-core/skills/*/`
Expected: 8 skill directories (7 original + compact-circuit-costs)
