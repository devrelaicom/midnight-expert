---
title: Bounded Computation in ZK Circuits
type: concept
description: All Compact code compiles to ZK circuits requiring deterministic, bounded execution — no unbounded loops, no recursion, no dynamic allocation.
links:
  - circuit-declarations
  - no-unbounded-loops
  - both-branches-execute
  - type-system
  - witness-functions
  - ledger-state-design
  - merkle-trees
  - standard-library-functions
  - token-operations
  - commitment-and-nullifier-schemes
---

# Bounded Computation in ZK Circuits

Every Compact program compiles to a zero-knowledge circuit. This has a profound consequence: the circuit's structure must be fully determined at compile time. There is no runtime branching in the traditional sense, no heap allocation, and no unbounded iteration. Understanding this constraint is essential for writing valid Compact code as described in [[circuit-declarations]].

## Why Boundedness Matters

A ZK circuit is a fixed-size mathematical structure. The prover generates a proof that the circuit was satisfied, and the verifier checks that proof. Both the prover and verifier must agree on the circuit's exact shape, which means every possible execution path must be compiled into the circuit ahead of time. This is fundamentally different from normal programming, where code paths are taken or skipped at runtime.

## Bounded Loops Only

The only loop construct in Compact is the bounded `for` loop:

```compact
for (let i: Uint<0..10> = 0; i < 10; i++) {
  // This body is unrolled into 10 copies at compile time
}
```

The compiler unrolls the loop, creating a fixed number of circuit gates. There are no `while` loops, no `do-while`, and no iterator-based loops — these would require an unknowable number of iterations. This is why [[no-unbounded-loops]] is one of the most common mistakes for developers coming from general-purpose languages.

The loop bound must be a compile-time constant. You cannot write `for (let i = 0; i < dynamicValue; i++)` because `dynamicValue` is not known until proof generation. When you need to iterate over a variable-length portion of a fixed-size collection, iterate over the full collection and use a conditional to skip elements:

```compact
// Process up to `count` elements from a fixed-size vector
for (let i: Uint<0..9> = 0; i < 10; i++) {
  if (i < count) {
    // Process items[i]
  }
}
```

## Both Branches Execute

In a normal program, `if-else` short-circuits: only one branch runs. In a ZK circuit, **both branches are always evaluated** because the circuit must contain gates for every possible path. The condition merely selects which result is used. This is the subject of [[both-branches-execute]] and has real consequences:

```compact
if (condition) {
  ledger.counter.increment(1);  // This gate ALWAYS fires
} else {
  ledger.counter.increment(0);  // This gate ALWAYS fires too
}
```

Assertions in both branches are checked regardless of the condition. If the "else" branch contains `assert false "unreachable"`, that assertion will fire even when the condition is true. The compiler evaluates both paths and uses the condition to multiplex the outputs.

## No Recursion

Circuits cannot call themselves, directly or indirectly. Recursion would create an unbounded circuit structure. Instead, use bounded `for` loops or flatten recursive logic into iterative patterns. The [[circuit-declarations]] section covers how circuits can call other circuits, but never circularly.

For algorithms that are naturally recursive (like tree traversal), Compact provides purpose-built primitives. For example, [[merkle-trees]] offer `merkleTreeDigest` and `merklePathRoot` functions that handle tree traversal internally without requiring user-written recursion.

## No Dynamic Allocation

All data structures have sizes known at compile time. Vectors have fixed lengths, Bytes have fixed sizes, and the depth of [[merkle-trees]] must be a compile-time constant. There is no dynamic array, no growable string, and no heap. The [[type-system]] reflects this with its emphasis on parameterized sizes like `Vector<10, Field>` and `Bytes<32>`.

This constraint shapes [[ledger-state-design]]: you cannot store an unbounded list of items. Instead, use a `Map` (which stores key-value pairs without iteration), a `MerkleTree` (which stores commitments in a fixed-depth tree), or a bounded `List<T>` with a known maximum size.

## Deterministic Execution

Every execution of a circuit with the same inputs must produce the same outputs. Circuits cannot use random numbers, access the current time directly (though `blockTimeGte()` and similar from the [[standard-library-functions]] provide bounded time checks), or perform I/O. Non-deterministic operations are delegated to [[witness-functions]], which run off-chain and feed data into the circuit.

## Implications for Contract Design

These constraints shape every aspect of contract design. When modeling state, [[ledger-state-design]] must account for the fact that iteration over collections is bounded. When implementing privacy patterns like [[commitment-and-nullifier-schemes]], the fixed circuit structure means that the same circuit handles both the "value exists" and "value doesn't exist" cases. When writing token logic as in [[token-operations]], every possible outcome of a send operation must be handled in the circuit.
