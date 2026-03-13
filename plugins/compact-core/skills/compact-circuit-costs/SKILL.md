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

All `for` loops are fully unrolled at compile time. The range `a..b` produces `b - a` iterations (upper bound is exclusive). Each iteration produces a complete copy of the loop body in the circuit.

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

The compiler performs these **circuit-phase** optimization passes automatically (in order). These are a subset of the full compilation pipeline (~23 passes total including frontend, analysis, and emission phases):

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
| `MerkleTree<N, T>` | Fixed (2^N capacity) | Pre-allocated | Insert public; **privacy via membership proofs** | Higher |
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
│   └── Need nested state? → Map<K, V> where V is any ledger type (Counter, Set<T>, List<T>, MerkleTree, or another Map)
├── Membership checks →
│   ├── Privacy required? → MerkleTree<N, T> (membership proofs hide which leaf)
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
