---
title: Export Rules and Visibility
type: concept
description: Only exported circuits form the contract's public API; modules provide namespacing with a two-tier visibility model.
links:
  - compact-to-typescript-types
  - circuit-declarations
  - naming-conventions
  - contract-file-layout
  - anonymous-membership-proof
  - disclosure-model
---

# Export Rules and Visibility

Compact has a two-tier visibility model. At the module level, `export` makes items visible to importers. At the top level, `export` on circuits and ledger fields makes them accessible from TypeScript and external callers. Understanding this distinction is critical because it determines the contract's public API surface.

## Exported vs Unexported Circuits

```compact
// PUBLIC API: callable from TypeScript DApps and other contracts
export circuit transfer(to: Field, amount: Uint<0..1000000>): [] {
  // ...
}

// INTERNAL: only callable from within this contract's circuits
circuit validateAmount(amount: Uint<0..1000000>): Boolean {
  return amount > 0;
}
```

Only `export circuit` declarations appear in the generated TypeScript types as described in [[compact-to-typescript-types]]. Internal circuits are helpers — they reduce code duplication but cannot be called externally. Every exported circuit generates a ZK prover/verifier key pair, which increases compilation time, so only export what needs to be public.

## The Enum Export Trap

If an enum type appears as a parameter or return type of an exported circuit, that enum **must** also be exported. The compiler enforces this:

```compact
export enum Status { Active, Inactive }  // MUST be exported

export circuit getStatus(): Status {     // Uses Status in return type
  return Status.Active;
}
```

Forgetting to export the enum is a common mistake flagged by static analysis. This rule applies to structs used in exported signatures as well, which is why the [[contract-file-layout]] places type definitions with their `export` keywords before the circuit declarations.

## Module System

Modules provide namespacing for larger contracts:

```compact
module TokenLogic {
  export circuit mint(amount: Uint<0..1000000>): [] {
    // ...
  }
}
```

Items exported from a module are visible to importers of that module, but they are NOT automatically part of the contract's public API. To make a module's circuit callable from TypeScript, it must be re-exported from the top level — a subtlety that catches many developers. The [[circuit-declarations]] section covers how to create wrapper circuits that bridge this gap.

## Ledger Field Visibility

```compact
export ledger balance: Counter;        // Visible in TypeScript Ledger type
ledger internalFlag: Cell<Boolean>;    // NOT in TypeScript, but still on-chain
```

The `export` keyword on ledger fields controls TypeScript API visibility, **not** on-chain privacy. All ledger state is publicly visible on the blockchain regardless of whether it's exported. Privacy requires the mechanisms described in [[disclosure-model]] and [[commitment-and-nullifier-schemes]]. This is one of the most important mental model corrections for developers who confuse `export` with access control.

## Generic Circuit Export Restriction

Generic circuits cannot be exported directly from the top level because the TypeScript type system cannot represent Compact's compile-time numeric parameters (`#n`). The workaround is a non-generic wrapper that fixes the parameters:

```compact
circuit genericHelper<T>(value: T): Field {
  return persistentHash(value);
}

export circuit hashField(value: Field): Field {
  return genericHelper<Field>(value);
}
```

This pattern ensures the TypeScript interface has concrete types while the internal implementation stays generic, which is relevant when designing reusable logic for patterns like [[anonymous-membership-proof]] where Merkle tree depths vary.
