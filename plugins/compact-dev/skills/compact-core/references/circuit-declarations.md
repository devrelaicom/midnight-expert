---
title: Circuit Declarations
type: concept
description: Writing circuits — the on-chain logic units that compile to ZK proofs, including parameters, return types, generics, and the export keyword.
links:
  - bounded-computation
  - export-and-visibility
  - pure-vs-impure-circuits
  - witness-functions
  - constructor-circuit
  - type-system
  - compact-to-typescript-types
  - naming-conventions
  - void-is-not-a-return-type
  - disclosure-model
  - circuit-witness-boundary
  - contract-file-layout
---

# Circuit Declarations

A circuit is the fundamental operational element in Compact, compiled directly into a zero-knowledge proof circuit. Every circuit must have a declared return type, all parameters must carry type annotations, and the body must obey the constraints of [[bounded-computation]] — no unbounded loops, no recursion, no dynamic allocation.

## Basic Syntax

```compact
[export] [pure] circuit name(param: Type, ...): ReturnType {
  // statements
  return value;
}
```

The `export` keyword makes a circuit callable from TypeScript as described in [[export-and-visibility]]. The `pure` keyword restricts a circuit from accessing ledger state or calling witnesses, as covered in [[pure-vs-impure-circuits]]. By [[naming-conventions]], circuit names use camelCase.

## Return Types

Every circuit must declare its return type explicitly — there is no type inference at the top level. Circuits that don't return a value use the empty tuple `[]` as their return type, which is Compact's void equivalent. Using `Void` instead is a deprecated syntax error detailed in [[void-is-not-a-return-type]].

```compact
// Returns a value — must have explicit return on every path
export circuit getBalance(): Uint<0..1000000> {
  return balance;
}

// Void circuit — no return statement needed
export circuit setOwner(newOwner: Bytes<32>): [] {
  owner = newOwner;
}
```

When a circuit returns a non-void type, every execution path through the body must end with a `return` statement. The compiler enforces this statically.

## Parameters

Circuit parameters accept any Compact type from the [[type-system]]: primitives, structs, enums, tuples, and vectors. Parameters **cannot** be ledger ADT types (Counter, Map, Set, etc.) — those are accessed directly by their ledger field names. Parameters of exported circuits are treated as witness data by the compiler, meaning returning them or storing them in the ledger requires `disclose()` as described in [[disclosure-model]].

Tuple and struct destructuring is supported in parameter position:

```compact
circuit processPoint([x, y]: [Field, Field]): Field {
  return x + y;
}

circuit processRecord({id, balance}: UserRecord): Field {
  return id;
}
```

## Calling Other Circuits

Circuits can call other circuits like function calls. The call graph must be acyclic — recursion is forbidden by [[bounded-computation]]. When an unexported circuit calls a witness, it becomes impure, and any circuit that calls it is also impure. This transitivity is explained in [[pure-vs-impure-circuits]].

```compact
circuit validateOwner(): [] {
  assert getCaller() == owner "Not the owner";
}

export circuit transferOwnership(newOwner: Bytes<32>): [] {
  validateOwner();  // calls helper circuit
  owner = disclose(newOwner);
}
```

## Generic Circuits

Circuits can be parameterized by type parameters (`T`) and numeric parameters (`#n`):

```compact
circuit hashItems<T, #n>(items: Vector<#n, T>): Bytes<32> {
  return persistentHash<Vector<#n, T>>(items);
}
```

Generic circuits cannot be exported from the top level because TypeScript cannot represent compile-time numeric parameters. The pattern is to create a non-generic wrapper as described in [[export-and-visibility]]:

```compact
export circuit hashThreeFields(items: Vector<3, Field>): Bytes<32> {
  return hashItems<Field, 3>(items);
}
```

## Circuit Overloading

Unexported circuits can be overloaded — multiple circuits with the same name but different parameter types. The compiler selects the correct overload based on argument types. Exported circuits **cannot** be overloaded; each exported name must be unique. This constraint comes from the TypeScript API generation described in [[compact-to-typescript-types]], which requires unambiguous method names.

## Ordering in the File

The [[contract-file-layout]] places internal circuits before exported circuits. Forward references are allowed for circuit calls (unlike types, which must be declared before use), but the canonical layout improves readability.
