---
title: "Gotcha: No Unbounded Loops"
type: gotcha
description: Compact only supports bounded for loops that the compiler unrolls at compile time — while loops, do-while, and iterator loops do not exist.
links:
  - bounded-computation
  - circuit-declarations
  - type-system
  - merkle-trees
  - map-and-set
---

# Gotcha: No Unbounded Loops

This is one of the first constraints developers encounter. Compact has no `while` loops, no `do-while`, no iterator-based loops, and no `break` or `continue`. The only loop construct is a bounded `for` loop that the compiler unrolls entirely at compile time.

## The Constraint

Every Compact program compiles to a ZK circuit with a fixed number of gates. A `while` loop's iteration count depends on runtime values, which would make the circuit structure unpredictable. The [[bounded-computation]] model requires all structure to be determined at compile time.

## Valid Loops

```compact
// OK: Bounds are compile-time constants
for (let i: Uint<0..9> = 0; i < 10; i++) {
  // Unrolled into 10 copies
}

// OK: Using a type parameter as the bound
circuit process<#n>(items: Vector<#n, Field>): Field {
  let sum: Field = 0;
  for (let i: Uint<0..#n> = 0; i < #n; i++) {
    sum = sum + items[i];
  }
  return sum;
}
```

## Invalid Loops

```compact
// COMPILE ERROR: while loops don't exist
while (condition) { ... }

// COMPILE ERROR: dynamic bound
const n = getCount();
for (let i = 0; i < n; i++) { ... }

// COMPILE ERROR: break doesn't exist
for (let i: Uint<0..9> = 0; i < 10; i++) {
  if (found) break;  // No break keyword
}
```

## Workarounds

### Processing a Variable Number of Items

Iterate over the full fixed-size collection and conditionally skip:

```compact
circuit processUpTo(items: Vector<10, Field>, count: Uint<0..10>): Field {
  let sum: Field = 0;
  for (let i: Uint<0..9> = 0; i < 10; i++) {
    if (i < count) {
      sum = sum + items[i];
    }
  }
  return sum;
}
```

The loop always runs 10 times (the circuit has 10 copies of the body gates). The `if` condition selects which iterations contribute to the result, but all iterations execute — see [[both-branches-execute]].

### Early Exit Simulation

Since there's no `break`, use a flag:

```compact
circuit findFirst(items: Vector<10, Field>, target: Field): Maybe<Field> {
  let found: Boolean = false;
  let result: Field = 0;
  for (let i: Uint<0..9> = 0; i < 10; i++) {
    if (!found && items[i] == target) {
      result = items[i];
      found = true;
    }
  }
  return found ? some<Field>(result) : none<Field>();
}
```

### Iteration Over Collections

[[map-and-set]] (Map and Set) do not support iteration at all. You cannot "loop over all keys in a Map" because the number of keys is not known at compile time. If you need to process all items, maintain a parallel bounded data structure (like a Vector or List) alongside the Map/Set.

[[merkle-trees]] handle traversal internally — the `merklePathRoot` function walks the tree without user-written loops.

## Cost Implications

Unrolled loops create one copy of the body per iteration in the circuit. A loop of 1000 iterations creates 1000 copies of all gate operations, which can dramatically increase compilation time and proof generation time. Keep loop bounds as small as possible, and consider whether [[merkle-trees]] or other tree-based structures can replace large-iteration patterns.
