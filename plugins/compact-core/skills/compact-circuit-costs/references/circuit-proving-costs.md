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

Compact's `for` loops have compile-time-determined bounds only. The range `a..b` produces `b - a` iterations (upper bound is exclusive), so `0..100` is 100 iterations and `1..10` is 9 iterations. The compiler fully unrolls every loop, replacing it with N copies of the loop body, each specialized for that iteration's index value.

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
| `transientCommit<T>` | `Field` | ~1-2× | Not safe across upgrades | Yes — protects input |
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
