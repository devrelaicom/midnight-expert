---
title: Variable Declarations
type: concept
description: Variable binding syntax in Compact — const for immutable values, let for immutable bindings, let mut for mutable bindings, with required type annotations.
links:
  - type-system
  - bounded-computation
  - circuit-declarations
---

# Variable Declarations

Compact variables follow a simple model: all bindings are immutable by default, mutability requires an explicit `mut` keyword, and type annotations are required when the compiler cannot infer the type. There are no `var` declarations, no hoisting, and no re-declaration within the same scope.

## Declaration Forms

### `const` — Compile-Time Immutable

```compact
const MAX_SIZE: Uint<0..100> = 50;
const TOKEN_NAME: Bytes<32> = pad(32, "mytoken:GOLD");
```

`const` bindings are resolved at compile time when the value is a literal or computable from literals. They cannot be reassigned. Constants declared at the top level of a file are available throughout the contract.

### `let` — Immutable Binding

```compact
let value: Boolean = true;
let hash: Field = transientHash<Field>(secret);
```

`let` creates an immutable binding — the variable cannot be reassigned after initialization. This is the default and preferred form for most circuit-local variables.

### `let mut` — Mutable Binding

```compact
let mut counter: Field = 0;
counter = counter + 1;

let mut accumulator: Uint<0..1000000> = 0;
accumulator = accumulator + amount;
```

`let mut` creates a mutable binding that can be reassigned. Use this for loop counters, accumulators, and values that change through a circuit's execution. Mutable variables still have a fixed [[type-system]] type — you cannot change the type, only the value.

## Type Annotations

Type annotations follow the variable name with a colon:

```compact
const x: Field = 42;
let y: Uint<0..255> = 10;
let mut z: Boolean = false;
```

The compiler can infer types in some contexts, but explicit annotations are recommended for clarity, especially for `Uint` ranges where the intended bounds matter. Omitting the type when the compiler cannot infer it produces a compile error.

## Scope Rules

Variables are block-scoped. A variable declared inside an `if` block or `for` loop body is not accessible outside that block:

```compact
for (let i: Uint<0..10> = 0; i < 10; i++) {
  let local: Field = i as Field;
  // local is accessible here
}
// local is NOT accessible here
```

There is no variable shadowing within the same scope — re-declaring a variable with the same name in the same block is a compile error. This prevents accidental redefinition bugs that could silently change circuit behavior.

## Loop Variables

The `for` loop initializer is the most common place for mutable declarations:

```compact
for (let i: Uint<0..10> = 0; i < 10; i++) {
  // i is mutable within the loop, incremented by the loop construct
}
```

The loop variable's type must be a `Uint` range, and the bound must be a compile-time constant — a requirement of [[bounded-computation]]. The loop variable is scoped to the loop body.

## Relationship to Circuit Parameters

Circuit parameters act as immutable bindings within the circuit body, as described in [[circuit-declarations]]:

```compact
export circuit doWork(input: Field, flag: Boolean): Field {
  // input and flag behave like `let` bindings — immutable
  let result: Field = input + 1;
  return result;
}
```

Parameters cannot be reassigned. If you need to modify a parameter's value, bind it to a `let mut` variable first.
