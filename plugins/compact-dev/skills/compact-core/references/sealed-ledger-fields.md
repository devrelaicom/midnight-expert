---
title: Sealed Ledger Fields
type: concept
description: The sealed keyword makes ledger fields immutable after the constructor runs — only the constructor and circuits it calls can write to sealed fields.
links:
  - ledger-state-design
  - constructor-circuit
  - contract-file-layout
  - export-and-visibility
  - cell-and-counter
---

# Sealed Ledger Fields

The `sealed` keyword on a ledger declaration makes that field immutable after the [[constructor-circuit]] completes. Any circuit attempting to write to a sealed field after deployment causes a compile error.

## Syntax

```compact
sealed ledger adminKey: Bytes<32>;
export sealed ledger maxSupply: Uint<0..1000000>;
```

When combining `export` and `sealed`, `export` must come first in the declaration. This follows the ordering rules in [[contract-file-layout]].

## Writability Rules

Sealed fields can be written:
- Directly inside the constructor body
- Inside circuits called by the constructor (transitively)

Sealed fields **cannot** be written:
- In any exported circuit
- In any circuit called after deployment
- Via any path not originating from the constructor

```compact
sealed ledger admin: Bytes<32>;
export ledger balance: Counter;

constructor(adminKey: Bytes<32>) {
  admin = disclose(adminKey);  // OK — inside constructor
}

export circuit changeAdmin(newAdmin: Bytes<32>): [] {
  admin = newAdmin;  // COMPILE ERROR — sealed field
}
```

## Use Cases

Sealed fields are appropriate for:
- **Admin/owner keys**: Set once at deployment, never changeable
- **Configuration constants**: Maximum supply, token names, protocol parameters
- **Contract metadata**: Version identifiers, deployment timestamps

For values that need to be readable but not writable after deployment, combine `sealed` with `export`:

```compact
export sealed ledger contractName: Bytes<32>;
export sealed ledger maxUsers: Uint<0..1000>;
```

These appear in the TypeScript Ledger type (due to `export`) but cannot be modified by any circuit, providing a strong immutability guarantee. This complements the ADT selection described in [[ledger-state-design]] — sealed Cell fields are effectively constants baked into the contract at deployment.

## Sealed Counter

Counter fields can also be sealed, though this is unusual since a Counter that cannot be incremented or decremented has limited utility. The sealed Counter's value is whatever the [[constructor-circuit]] sets it to, read via the `as Uint<N>` cast described in [[cell-and-counter]].

## Security Implications

Sealing a field provides a **compile-time guarantee** of immutability, which is stronger than a runtime check. A contract claiming "the admin key never changes" backed by a sealed field is provably immutable, whereas the same claim backed by an `assert` could have bugs. When designing contracts where trust in immutability matters, prefer sealed fields over access control checks.
