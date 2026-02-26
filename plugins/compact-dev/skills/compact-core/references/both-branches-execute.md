---
title: "Gotcha: Both Branches Execute"
type: gotcha
description: In ZK circuits, both sides of an if-else always evaluate — the condition only selects the result, not which code runs. This affects state mutations and assertions.
links:
  - bounded-computation
  - circuit-declarations
  - cell-and-counter
  - state-machine-pattern
  - no-unbounded-loops
---

# Gotcha: Both Branches Execute

In normal programming, `if-else` short-circuits: only one branch runs. In a ZK circuit, **both branches are always evaluated** because the circuit must contain gates for every possible path. The condition merely selects which result is used as the output.

## The Problem

```compact
if (isOwner) {
  counter.increment(1);   // This gate ALWAYS fires
} else {
  counter.increment(0);   // This gate ALWAYS fires too
}
```

Both `increment` operations execute in the circuit. The condition determines which one's *effect* is used, but both sets of gates are present and active. This is a fundamental consequence of [[bounded-computation]]: the circuit has a fixed structure regardless of runtime values.

## Consequences for State Mutations

Ledger mutations (writes to [[cell-and-counter]], Map inserts, etc.) in both branches are evaluated. The circuit selects which mutation to apply based on the condition, but the computation for both happens. This means:

1. **Cost**: Both branches contribute to circuit size (gates and constraints)
2. **Assertions**: An `assert` in either branch is checked regardless of the condition

## The Assert Trap

```compact
// DANGEROUS: assert in else-branch fires even when condition is true
if (phase == Phase.Active) {
  // do something
} else {
  assert false "This should be unreachable";  // ALWAYS fires!
}
```

The `assert false` in the else-branch will always fail the proof, even when `phase == Phase.Active`. This is because both branches execute — the assert is always evaluated.

## The Correct Pattern

Use top-level assertions instead of branch-based assertions:

```compact
// CORRECT: assert at the top, then proceed
export circuit activeAction(): [] {
  assert phase == Phase.Active "Not in active phase";
  // Now you know phase is Active — no branching needed
  counter.increment(1);
}
```

This is why the [[state-machine-pattern]] uses asserts at the beginning of each circuit rather than if-else branching on state.

## Conditional Value Selection

Both branches execute, but the condition selects which *value* is used:

```compact
// Both branches compute, condition selects result
const result = if (flag) { 42 } else { 0 };
// result is 42 if flag is true, 0 if false
// BUT: both 42 and 0 are computed (trivially)
```

For more complex expressions, both sides are fully evaluated:

```compact
// Both hash computations happen regardless of condition
const h = if (flag) {
  persistentHash<Field>(a)
} else {
  persistentHash<Field>(b)
};
```

This doubles the hash computation cost compared to a single branch.

## Interaction with Loops

The same principle applies inside [[no-unbounded-loops]]: an `if` inside a loop body means both branches execute on every unrolled iteration. This can multiply the circuit cost significantly if the branches contain expensive operations.

## Optimization Strategy

When one branch is significantly more expensive than the other, consider restructuring to avoid the conditional entirely. For example, instead of conditionally hashing two different values, compute both hashes unconditionally and select the result:

```compact
const h1 = persistentHash<Field>(a);
const h2 = persistentHash<Field>(b);
const result = if (flag) { h1 } else { h2 };
```

This is equivalent in circuit cost but makes the double-computation explicit and clearer to the reader.
