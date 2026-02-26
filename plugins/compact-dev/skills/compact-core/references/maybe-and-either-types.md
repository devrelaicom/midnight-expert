---
title: Maybe and Either Types
type: concept
description: Generic wrapper types from the standard library — Maybe<T> for optional values and Either<A,B> for sum types representing one of two alternatives.
links:
  - standard-library-functions
  - type-system
  - token-operations
  - compact-to-typescript-types
  - witness-functions
  - map-and-set
---

# Maybe and Either Types

The Compact Standard Library provides two generic wrapper types used throughout the ecosystem: `Maybe<T>` for optional values and `Either<A, B>` for sum types. These are essential for [[token-operations]] (which use Either for recipient addressing) and for robust state handling with [[map-and-set]] (where lookups may return absent values).

## Maybe<T> — Optional Values

`Maybe<T>` represents a value that may or may not be present:

```compact
struct Maybe<T> {
  isSome: Boolean;
  value: T;
}
```

### Construction

```compact
const present: Maybe<Field> = some<Field>(42);
const absent: Maybe<Field> = none<Field>();
```

The type parameter must be explicitly specified — `some(42)` without `<Field>` is a type inference error. This is a [[type-system]] requirement: Compact does not infer generic type parameters.

### Safe Access

Always check `isSome` before using `value`:

```compact
const result = mapLookup(key);
if (result.isSome) {
  const v = result.value;  // Safe — we know it's present
}
```

Accessing `value` when `isSome` is `false` does not error — it silently returns `default<T>()`. This can hide bugs if you forget the `isSome` check. The value is still the zero/default of type T, not null or undefined.

### Field Name Warning

The field is `isSome` (camelCase), **not** `is_some`. Using `is_some` causes a compile error — one of the most common typos for developers used to Rust conventions.

### Maybe in Ledger State

When stored in a ledger Cell, both fields of a Maybe are on-chain. The `value` field is visible even when `isSome` is false. This matters for privacy — do not store sensitive data in a Maybe and rely on `isSome = false` to hide it.

## Either<A, B> — Sum Type

`Either<A, B>` represents a value that is one of two alternatives:

```compact
struct Either<A, B> {
  isLeft: Boolean;
  left: A;
  right: B;
}
```

### Construction

```compact
const l: Either<Field, Boolean> = left<Field, Boolean>(42);
const r: Either<Field, Boolean> = right<Field, Boolean>(true);
```

Both type parameters must be specified even when constructing only one side.

### Primary Use: Token Recipients

Either's most common use in Compact is the `Either<ZswapCoinPublicKey, ContractAddress>` type for [[token-operations]] recipients:

```compact
// Send to a user's wallet
const recipient = left<ZswapCoinPublicKey, ContractAddress>(userPubKey);

// Send to another contract
const recipient = right<ZswapCoinPublicKey, ContractAddress>(contractAddr);
```

This pattern appears in `mintToken()` and `send()` from the [[standard-library-functions]] — every coin operation requires specifying a recipient as an Either.

### Checking Which Side

```compact
const recipient: Either<ZswapCoinPublicKey, ContractAddress> = getRecipient();
if (recipient.isLeft) {
  // It's a wallet address: recipient.left
} else {
  // It's a contract address: recipient.right
}
```

Like Maybe, the inactive side still contains a value (the default) — accessing it doesn't error but returns meaningless data.

## TypeScript Mapping

As described in [[compact-to-typescript-types]], these types map to TypeScript objects:

```typescript
// Maybe<Field> →
{ isSome: boolean; value: bigint }

// Either<Uint8Array, Uint8Array> →
{ isLeft: boolean; left: Uint8Array; right: Uint8Array }
```

When implementing [[witness-functions]] in TypeScript, construct these objects with the correct field names and types. The `isSome` and `isLeft` fields are boolean, not optional — they must always be present.
