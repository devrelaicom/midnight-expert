---
title: "Gotcha: Void Is Not a Return Type"
type: gotcha
description: The Void keyword is deprecated in Compact 0.18.0 — use the empty tuple [] as the void return type for circuits that return nothing.
links:
  - type-system
  - circuit-declarations
  - naming-conventions
  - compact-to-typescript-types
  - contract-file-layout
---

# Gotcha: Void Is Not a Return Type

In Compact 0.18.0, the `Void` keyword is deprecated. Using it as a circuit return type causes a compiler error or deprecation warning (depending on the version). The correct void return type is the empty tuple `[]`.

## The Mistake

```compact
// WRONG: Void is deprecated
export circuit doSomething(): Void {
  counter.increment(1);
}
```

## The Fix

```compact
// CORRECT: Use empty tuple []
export circuit doSomething(): [] {
  counter.increment(1);
}
```

## Why This Catches Developers

Developers coming from Solidity, Rust, Java, or C++ expect a `void` or `()` keyword. Compact uses the empty tuple literal `[]` instead. This is consistent with Compact's [[type-system]] where tuples are first-class types and `[]` is a valid tuple with zero elements.

The Midnight MCP's static analysis will flag `Void` as deprecated syntax. If you encounter this error, the fix is a simple find-and-replace: change `: Void` to `: []` in all [[circuit-declarations]].

## Behavior Difference

Circuits with return type `[]` do not need a `return` statement — the circuit implicitly returns `[]` when execution reaches the end of the body. Circuits with any other return type must have an explicit `return` on every code path.

## TypeScript Mapping

As described in [[compact-to-typescript-types]], a circuit returning `[]` generates a TypeScript method that returns only the transaction result (no content value). The return type in TypeScript corresponds to the transaction builder's completion type, not a literal empty array.

## In the File Layout

The [[contract-file-layout]] example uses `[]` throughout. When following examples from older documentation (pre-0.18.0), be aware that they may use `Void` — always update to `[]`.
