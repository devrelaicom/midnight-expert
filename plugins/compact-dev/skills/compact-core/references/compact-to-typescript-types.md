---
title: Compact to TypeScript Type Mapping
type: concept
description: How Compact types map to TypeScript types in generated code — Field→bigint, Uint→bigint, Boolean→boolean, Bytes→Uint8Array, structs→interfaces.
links:
  - type-system
  - witness-functions
  - export-and-visibility
  - circuit-declarations
  - naming-conventions
  - maybe-and-either-types
  - coin-lifecycle
  - witness-context-object
---

# Compact to TypeScript Type Mapping

When a Compact contract is compiled, the compiler generates TypeScript type definitions that DApp code uses to call exported circuits, implement witnesses, and read ledger state. Understanding this mapping is essential for writing [[witness-functions]] and for building the DApp-side transaction logic.

## Primitive Type Mapping

| Compact Type | TypeScript Type | Notes |
|-------------|----------------|-------|
| `Field` | `bigint` | Arbitrary-precision integer |
| `Boolean` | `boolean` | Direct mapping |
| `Uint<N>` | `bigint` | Range enforcement is at proof time, not TypeScript time |
| `Bytes<N>` | `Uint8Array` | Fixed length N bytes |
| `Opaque<'string'>` | `string` | Transparent in TypeScript, opaque in circuits |
| `Opaque<'Uint8Array'>` | `Uint8Array` | Same — transparent in TS, opaque in circuits |

The most common mistake is assuming `Uint<N>` maps to `number`. It maps to `bigint` because Compact's numeric ranges can exceed JavaScript's safe integer limit. Always use `BigInt(value)` or the `n` suffix (`100n`) when constructing values for Compact circuits from TypeScript.

## Struct Mapping

Compact structs become TypeScript interfaces with the same field names:

```compact
struct UserRecord { id: Field; balance: Uint<0..1000000>; active: Boolean; }
```

Generates:

```typescript
interface UserRecord { id: bigint; balance: bigint; active: boolean; }
```

Field names preserve the camelCase convention from [[naming-conventions]], and the struct name preserves PascalCase. This is why conventions matter — they ensure the generated TypeScript code is idiomatic.

## Enum Mapping

Compact enums map to TypeScript string union types or discriminated unions depending on whether variants carry data:

```compact
enum Status { Pending, Active, Closed }
```

Generates a representation where each variant is a distinct value. Enum variants are referenced in TypeScript using the contract's type namespace. Only enums that are exported (see [[export-and-visibility]]) appear in the generated types.

## Circuit Signature Mapping

Exported circuits generate TypeScript function signatures in the contract's API:

```compact
export circuit transfer(to: Bytes<32>, amount: Uint<0..1000000>): [] { ... }
```

Generates a callable method that takes `{ to: Uint8Array, amount: bigint }` and returns a transaction builder. The return type `[]` (void) means the TypeScript method returns only the transaction result, while circuits that return values provide them through the proof's public outputs.

The [[circuit-declarations]] section covers which circuits get exported, and each exported circuit generates a corresponding TypeScript entry point. Unexported circuits have no TypeScript representation.

## Witness Implementation Types

When implementing [[witness-functions]] in TypeScript, the generated types define the expected function signatures:

```typescript
// Generated from: witness getCaller(): Bytes<32>;
type Witnesses = {
  getCaller: () => Promise<Uint8Array>;
};
```

The witness provider object must match these types exactly. Returning the wrong type (e.g., `string` instead of `Uint8Array` for `Bytes<32>`) causes runtime errors during proof generation. Every witness implementation also receives a [[witness-context-object]] as its first parameter, which provides ledger state access and contract metadata.

## Standard Library Types

The [[maybe-and-either-types]] map to TypeScript as:

- `Maybe<T>` → `{ isSome: boolean; value: T_mapped }` where `T_mapped` is the TypeScript equivalent of `T`
- `Either<A, B>` → a discriminated union with `tag` and `value` fields

The [[coin-lifecycle]] types (`CoinInfo`, `SendResult`, `QualifiedCoinInfo`) also have TypeScript representations that DApp code must handle when building token transactions.

## Ledger State Types

Exported ledger fields generate a `Ledger` type that the DApp uses to read on-chain state:

```typescript
// Generated from: export ledger balance: Counter;
type Ledger = {
  balance: bigint;  // Counter reads as bigint
  owner: Uint8Array;  // Bytes<32> reads as Uint8Array
};
```

Counter values read as `bigint`, Map entries require a lookup key, and MerkleTree fields are not directly readable from TypeScript (they require proof-based access patterns).
