---
title: Canonical Contract File Layout
type: concept
description: Compact files follow a strict ordering — pragma, imports, types, constants, then ledger, constructor, witnesses, and circuits.
links:
  - pragma-and-imports
  - type-system
  - export-and-visibility
  - constructor-circuit
  - sealed-ledger-fields
  - disclosure-model
  - naming-conventions
  - circuit-declarations
  - witness-functions
  - starter-contract-templates
---

# Canonical Contract File Layout

A well-structured Compact contract follows a canonical ordering that the compiler expects and developers rely on for readability. Deviating from this order — particularly defining types after their first use — causes compile errors.

## The Canonical Order

```compact
// 1. Pragma (REQUIRED, must be first)
pragma language_version >= 0.18.0;

// 2. Imports
import CompactStandardLibrary;
import "./shared-types.compact";

// 3. Type definitions (structs, enums)
export struct UserRecord { id: Field; balance: Uint<0..1000000>; }
export enum Status { Pending, Active, Closed }

// 4. Constants
const MAX_USERS: Uint<0..1000> = 100;

// 5. Ledger declarations
export ledger owner: Cell<Field>;
export ledger users: Map<Field, UserRecord>;

// 6. Constructor
constructor(initialOwner: Field) {
  owner = initialOwner;
}

// 7. Witness declarations
witness getCaller(): Field;
witness getUserData(): UserRecord;

// 8. Internal (unexported) circuits
circuit requireOwner(): [] {
  assert getCaller() == owner "Not owner";
}

// 9. Exported circuits (the public API)
export circuit addUser(id: Field): [] {
  requireOwner();
  // ...
}
```

The [[pragma-and-imports]] must come first. Type definitions must precede any code that references them as required by the [[type-system]]. Ledger declarations in the 0.18.0 syntax use `export ledger field: Type;` at the top level rather than inside a `ledger {}` block — the old block syntax is deprecated and flagged as a static analysis error.

## Why Order Matters

Compact uses a single-pass compilation model for type resolution. A struct referenced before its definition causes a "type not found" error. This is different from languages like TypeScript where hoisting resolves forward references. The strict ordering also helps the [[constructor-circuit]] see all ledger fields, since it must initialize state declared above it.

## Multi-File Organization

Larger projects split across multiple files:

```
my-contract/
├── main.compact          # Contract block, imports
├── types.compact          # Shared type definitions
└── utils.compact          # Helper circuits and constants
```

The main file imports the others via [[pragma-and-imports]], and each file follows its own internal canonical ordering. When using the module system described in [[export-and-visibility]], each module provides a namespace that prevents name collisions.

## Ledger Declaration Syntax (0.18.0)

The current syntax declares ledger fields at the top level with optional `export` and `sealed` keywords:

```compact
export ledger balance: Counter;
export sealed ledger admin: Cell<Field>;
ledger internal_state: Cell<Boolean>;  // not exported, but still on-chain
```

This replaces the older `ledger { ... }` block syntax. The [[sealed-ledger-fields]] keyword prevents modification after deployment. All ledger fields are on-chain and publicly visible regardless of the `export` keyword — export only controls TypeScript API access, not privacy, which is governed by the [[disclosure-model]].

For ready-to-use contract skeletons that follow this layout, see [[starter-contract-templates]].
