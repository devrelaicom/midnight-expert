---
title: Compact Type System
type: concept
description: Primitive types, user-defined types, generics, and subtyping rules for Compact's strongly-typed ZK language.
links:
  - bounded-computation
  - compact-to-typescript-types
  - naming-conventions
  - circuit-declarations
  - maybe-and-either-types
  - ledger-state-design
  - cell-and-counter
  - witness-functions
  - disclosure-model
  - transient-vs-persistent
  - export-and-visibility
  - void-is-not-a-return-type
  - state-machine-pattern
  - standard-library-functions
  - operators-and-expressions
  - variable-declarations
---

# Compact Type System

Compact is strongly and statically typed. Every value has a type known at compile time, and the type system is designed around the constraints of zero-knowledge circuits. There are no implicit conversions, no dynamic types, and no null values — every type has a well-defined default as described in [[compact-to-typescript-types]].

## Primitive Types

### Field

The workhorse arithmetic type, representing an element of a large prime field used internally by the ZK proof system. Field values support addition, subtraction, multiplication, and equality comparison, but not ordering comparisons (`<`, `>`, `<=`, `>=`). Attempting to compare Fields with ordering operators is a compile error — use `Uint` for ordered arithmetic. This is a direct consequence of [[bounded-computation]], where the underlying field arithmetic operates modulo a prime.

### Uint<m..n>

Unsigned integers with both bounds inclusive. `Uint<0..255>` represents an 8-bit range; `Uint<0..1000000>` covers typical token amounts. The subtyping rule is crucial: `Uint<0..10>` is a subtype of `Uint<0..100>`, meaning a narrower range can be used wherever a wider range is expected. The reverse requires an explicit `as` cast, which inserts a range check into the circuit.

When arithmetic on Uint values might exceed the declared range, explicit casting with `as` is required. For example, adding two `Uint<0..100>` values yields a result that could be up to 200, so you must either cast or use a wider result type.

### Boolean

Holds `true` or `false` and maps directly to TypeScript's `boolean` as described in [[compact-to-typescript-types]]. Boolean is the only type valid in `if` conditions and `assert` statements.

### Bytes<n>

A fixed-length byte array. `Bytes<32>` is the standard size for hash outputs from functions in the [[standard-library-functions]], as well as for public keys and commitments. The choice between `persistentHash` (which returns `Bytes<32>`) and `transientHash` (which returns `Field`) matters enormously for privacy as explained in [[transient-vs-persistent]].

### Opaque Types

`Opaque<'string'>` and `Opaque<'Uint8Array'>` represent data that is visible on-chain but opaque within circuits. They cannot be inspected or manipulated in circuit logic — only passed through to witnesses or stored. Despite the name suggesting hiddenness, Opaque values provide no privacy guarantees, a point reinforced in [[disclosure-model]].

## Tuples and Vectors

Tuples `[A, B, C]` group heterogeneous values and are the mechanism for returning multiple values from [[circuit-declarations]]. The empty tuple `[]` is Compact's void type — using the `Void` keyword instead is a deprecated syntax error covered in [[void-is-not-a-return-type]].

Vectors `Vector<n, T>` are fixed-length homogeneous arrays. The length `n` must be a compile-time constant because [[bounded-computation]] requires all sizes to be statically known. Vectors support indexing (`v[i]`), and vector literals use bracket syntax (`[1, 2, 3]`). Vectors are commonly used as inputs to hash functions: `persistentHash<Vector<3, Field>>([a, b, c])`.

## User-Defined Types

### Structs

Structs define product types with named fields. By [[naming-conventions]], struct names use PascalCase:

```compact
struct UserRecord {
  id: Field;
  balance: Uint<0..1000000>;
  active: Boolean;
}
```

Struct construction requires all fields: `UserRecord { id: someId, balance: 0, active: true }`. There are no optional fields. The expression `default<UserRecord>()` produces a struct with all fields at their zero/false defaults — this is relevant for [[ledger-state-design]] because `Map.lookup()` returns the default when a key is missing.

### Enums

Enums define sum types with named variants. Variant access uses dot syntax (`Status.Active`), never Rust-style `::` as noted in [[naming-conventions]]. Enums are the primary mechanism for the [[state-machine-pattern]]:

```compact
export enum Status { Pending, Active, Closed }
```

The default value of an enum is its first declared variant. When an enum appears in an exported circuit's signature, it must itself be exported — a compiler-enforced rule described in [[export-and-visibility]].

## Generic Types

Structs and circuits can be parameterized with type variables (`T`, `A`, `B`) and compile-time numeric parameters (`#n`, `#depth`). Generic circuits cannot be exported directly from the top level as described in [[export-and-visibility]], because TypeScript cannot represent compile-time numeric parameters.

```compact
circuit hashPair<T>(a: T, b: T): Bytes<32> {
  return persistentHash<Vector<2, T>>([a, b]);
}
```

## Default Values

Every type has a default: `0` for Field and Uint, `false` for Boolean, all-zero bytes for Bytes, first variant for enums, and recursively-defaulted fields for structs. This matters for [[ledger-state-design]] because uninitialized ledger fields take their type's default, and `Map.lookup()` returns the default for missing keys rather than throwing an error.

## Type Conversions

The `as` keyword performs conversions: `Field` to `Bytes<32>`, numeric widening (`Uint<10>` to `Uint<100>`), and numeric narrowing (which inserts a range check). Invalid conversions cause compile errors. Casting never allocates memory — it reinterprets or constrains existing circuit wires. The full set of operators available for each type, including cast expressions, is detailed in [[operators-and-expressions]].

## Variable Binding

Types are attached to variables at the point of declaration using type annotations. The [[variable-declarations]] section covers the three binding forms — `const`, `let`, and `let mut` — and their type annotation syntax.
