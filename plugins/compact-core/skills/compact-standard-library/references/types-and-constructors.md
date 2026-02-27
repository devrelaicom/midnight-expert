# Stdlib Types and Constructor Functions

Complete reference for all types and their constructor functions provided by `import CompactStandardLibrary;`. Every definition below is verified against the official Compact API documentation and MCP codebase.

## Types Overview

| Type | Kind | Purpose |
|------|------|---------|
| `Maybe<T>` | Generic struct | Optional value (present or absent) |
| `Either<A, B>` | Generic struct | Disjoint union (one of two variants) |
| `NativePoint` | Struct | Elliptic curve point on the embedded curve |
| `MerkleTreeDigest` | Struct | Merkle tree root hash wrapper |
| `MerkleTreePathEntry` | Struct | Single step in a Merkle proof path |
| `MerkleTreePath<#n, T>` | Generic struct | Complete Merkle inclusion proof |
| `ContractAddress` | Struct | On-chain contract address |
| `ZswapCoinPublicKey` | Struct | User public key for shielded coin outputs |
| `UserAddress` | Struct | User wallet address for unshielded tokens |

## Maybe\<T\>

Encapsulates an optionally present value. If `isSome` is `false`, `value` should be `default<T>` by convention.

### Definition

```compact
struct Maybe<T> {
  isSome: Boolean;
  value: T;
}
```

### Construction

| Constructor | Signature | Description |
|-------------|-----------|-------------|
| `some<T>(value)` | `circuit some<T>(value: T): Maybe<T>;` | Creates a Maybe containing the given value |
| `none<T>()` | `circuit none<T>(): Maybe<T>;` | Creates an empty Maybe |
| `default<Maybe<T>>` | -- | Equivalent to `none<T>()` |

Type parameters are required. `some(42)` is wrong; `some<Field>(42)` is correct.

### Field Access

| Field | Type | Meaning |
|-------|------|---------|
| `.isSome` | `Boolean` | `true` if a value is present |
| `.value` | `T` | The contained value (meaningful only when `isSome` is `true`) |

### Inspection Pattern

```compact
const result = myMap.lookup(key);
if (result.isSome) {
  balance = (balance + result.value) as Uint<64>;
}
```

### Common Uses

- Return type of `List.head()` -- returns `Maybe<T>`
- Optional witness data from TypeScript
- The `change` field of `ShieldedSendResult` is `Maybe<ShieldedCoinInfo>`
- Note: `Map.lookup()` returns `V` directly (not `Maybe<V>`). Use `Map.member()` to check existence.

### TypeScript Representation

```typescript
{ isSome: boolean, value: T }
```

Where `T` maps to the corresponding TypeScript type for the inner Compact type.

## Either\<A, B\>

Disjoint union of `A` and `B`. If `isLeft` is `true`, `left` should be populated; otherwise `right`. The unpopulated variant should be `default<>` by convention.

### Definition

```compact
struct Either<A, B> {
  isLeft: Boolean;
  left: A;
  right: B;
}
```

### Construction

| Constructor | Signature | Description |
|-------------|-----------|-------------|
| `left<A, B>(value)` | `circuit left<A, B>(value: A): Either<A, B>;` | Creates an Either with the left variant |
| `right<A, B>(value)` | `circuit right<A, B>(value: B): Either<A, B>;` | Creates an Either with the right variant |
| `default<Either<A, B>>` | -- | Equivalent to `left` with default values for both A and B |

Both type parameters are required. `left(42)` is wrong; `left<Field, Boolean>(42)` is correct.

### Field Access

| Field | Type | Meaning |
|-------|------|---------|
| `.isLeft` | `Boolean` | `true` if the left variant is populated |
| `.left` | `A` | The left variant value |
| `.right` | `B` | The right variant value |

### Common Uses

Either is the standard type for representing token recipients in the Compact ecosystem:

| Pattern | Type | Use Case |
|---------|------|----------|
| Shielded recipient | `Either<ZswapCoinPublicKey, ContractAddress>` | Left = user, Right = contract |
| Unshielded recipient | `Either<ContractAddress, UserAddress>` | Left = contract, Right = user |

### Code Example

```compact
// Shielded: send to a user
const toUser = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());

// Shielded: send to a contract
const toContract = right<ZswapCoinPublicKey, ContractAddress>(kernel.self());

// Unshielded: send to a user address
const toUserAddr = right<ContractAddress, UserAddress>(disclose(recipientAddr));

// Inspect which variant
if (recipient.isLeft) {
  // recipient.left is the ZswapCoinPublicKey
} else {
  // recipient.right is the ContractAddress
}
```

### TypeScript Representation

```typescript
{ isLeft: boolean, left: A, right: B }
```

## NativePoint

A point on the proof system's embedded elliptic curve, in affine coordinates. Only outputs of elliptic curve operations (`ecAdd`, `ecMul`, `ecMulGenerator`, `hashToCurve`) are guaranteed to actually lie on the curve.

### Definition

```compact
struct NativePoint {
  x: Field;
  y: Field;
}
```

### Accessor Functions

While direct field access (`.x`, `.y`) currently works, the preferred approach is to use accessor functions:

| Function | Signature | Description |
|----------|-----------|-------------|
| `nativePointX(p)` | `circuit nativePointX(p: NativePoint): Field;` | Get the X coordinate |
| `nativePointY(p)` | `circuit nativePointY(p: NativePoint): Field;` | Get the Y coordinate |

### Constructor

```compact
circuit constructNativePoint(x: Field, y: Field): NativePoint;
```

Note: This creates a `NativePoint` from raw field values. The resulting point is not checked to lie on the curve.

### Default Value

`default<NativePoint>` is the identity element of the curve group.

### Deprecation Note

`CurvePoint` is the old name for this type. It is deprecated. Use `NativePoint` in all new code. The elliptic curve functions (`ecAdd`, `ecMul`, `ecMulGenerator`, `hashToCurve`) now take and return `NativePoint`.

### Code Example

```compact
const g = ecMulGenerator(1);                          // generator point
const pk = ecMul(g, secretKey);                        // public key derivation
const combined = ecAdd(pk, hashToCurve<Bytes<32>>(data));
const x = nativePointX(combined);                      // get X coordinate
const y = nativePointY(combined);                      // get Y coordinate
const manual = constructNativePoint(x, y);             // reconstruct from coordinates
```

### TypeScript Representation

```typescript
{ x: bigint, y: bigint }
```

## MerkleTreeDigest

Wrapper around a `Field` representing a Merkle tree root hash.

### Definition

```compact
struct MerkleTreeDigest { field: Field; }
```

### Usage

- Return type of `merkleTreePathRoot<#n, T>(path)` and `merkleTreePathRootNoLeafHash<#n>(path)`
- Parameter type of `MerkleTree.checkRoot(rt)` and `HistoricMerkleTree.checkRoot(rt)`
- Default value: `default<MerkleTreeDigest>` is `{ field: 0 }`

### Code Example

```compact
const digest = merkleTreePathRoot<4, Field>(path);
assert(merkleTree.checkRoot(digest) == true, "invalid root");
```

## MerkleTreePathEntry

One step in a Merkle proof path: the sibling hash and a direction flag.

### Definition

```compact
struct MerkleTreePathEntry {
  sibling: MerkleTreeDigest;
  goesLeft: Boolean;
}
```

### Fields

| Field | Type | Meaning |
|-------|------|---------|
| `.sibling` | `MerkleTreeDigest` | Hash of the sibling node at this level |
| `.goesLeft` | `Boolean` | Direction flag: `true` if the path goes left at this level |

Primarily used as the element type inside `MerkleTreePath`.

## MerkleTreePath\<#n, T\>

A complete Merkle inclusion proof: the leaf value plus the sibling path from leaf to root.

### Definition

```compact
struct MerkleTreePath<#n, T> {
  leaf: T;
  path: Vector<n, MerkleTreePathEntry>;
}
```

### Type Parameters

| Parameter | Meaning |
|-----------|---------|
| `#n` | Tree depth (must match the `MerkleTree` or `HistoricMerkleTree` depth) |
| `T` | Leaf value type |

### Construction

Merkle paths are constructed off-chain in TypeScript using the compiler output's `findPathForLeaf` and `pathForLeaf` functions, then passed into circuits via witness functions.

### Verification

Pass to `merkleTreePathRoot<#n, T>(path)` to recompute the root hash, then check against the on-chain tree:

```compact
witness getMerklePath(): MerkleTreePath<32, Bytes<32>>;

export circuit verifyInclusion(): [] {
  const path = getMerklePath();
  const digest = merkleTreePathRoot<32, Bytes<32>>(path);
  assert(tree.checkRoot(digest) == true, "not in tree");
}
```

For trees where leaves have already been hashed externally, use `merkleTreePathRootNoLeafHash<#n>(path)` instead. In that case `T` must be `Bytes<32>`:

```compact
circuit merkleTreePathRootNoLeafHash<#n>(path: MerkleTreePath<n, Bytes<32>>): MerkleTreeDigest;
```

## Address Types

Three struct types represent different kinds of addresses in the Compact ecosystem. All three wrap a `Bytes<32>` value.

### ContractAddress

The address of a deployed contract.

```compact
struct ContractAddress { bytes: Bytes<32>; }
```

| Obtained via | Context |
|--------------|---------|
| `kernel.self()` | Returns the current contract's own address |

Used as a recipient in `sendShielded`, `sendImmediateShielded`, `createZswapOutput`, `mintShieldedToken`, `mintUnshieldedToken`, and `sendUnshielded`.

### ZswapCoinPublicKey

The public key used to output shielded coins to a user.

```compact
struct ZswapCoinPublicKey { bytes: Bytes<32>; }
```

| Obtained via | Context |
|--------------|---------|
| `ownPublicKey()` | Returns the transaction submitter's public key |

Used as a recipient in `sendShielded`, `sendImmediateShielded`, and `createZswapOutput`.

### UserAddress

A user wallet address for unshielded token operations.

```compact
struct UserAddress { bytes: Bytes<32>; }
```

Used as a recipient in `sendUnshielded` and `mintUnshieldedToken`. The `UserAddress` is typically provided as a circuit parameter (passed in by the caller) rather than derived on-chain.

### Address Type Usage Patterns

```compact
// Shielded: user receives
const userRecipient = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());

// Shielded: contract receives
const contractRecipient = right<ZswapCoinPublicKey, ContractAddress>(kernel.self());

// Unshielded: contract receives
const contractDest = left<ContractAddress, UserAddress>(kernel.self());

// Unshielded: user receives
const userDest = right<ContractAddress, UserAddress>(disclose(userAddr));
```

## Constructor Functions

Summary of all stdlib constructor circuits for `Maybe` and `Either`.

### some\<T\>

```compact
circuit some<T>(value: T): Maybe<T>;
```

Creates a `Maybe<T>` with `isSome = true` and `.value` set to the given value.

### none\<T\>

```compact
circuit none<T>(): Maybe<T>;
```

Creates a `Maybe<T>` with `isSome = false` and `.value` set to `default<T>`.

### left\<A, B\>

```compact
circuit left<A, B>(value: A): Either<A, B>;
```

Creates an `Either<A, B>` with `isLeft = true`, `.left` set to the given value, and `.right` set to `default<B>`.

### right\<A, B\>

```compact
circuit right<A, B>(value: B): Either<A, B>;
```

Creates an `Either<A, B>` with `isLeft = false`, `.right` set to the given value, and `.left` set to `default<A>`.

### Type Parameter Rules

Type parameters are always required for constructor functions. The compiler cannot infer them.

```compact
// Correct
const opt = some<Field>(42);
const empty = none<Uint<64>>();
const l = left<ZswapCoinPublicKey, ContractAddress>(ownPublicKey());
const r = right<Field, Boolean>(true);

// Wrong -- missing type parameters
const opt = some(42);         // compile error
const empty = none();         // compile error
const l = left(ownPublicKey()); // compile error
```

### Patterns

Checking variants:

```compact
const result: Maybe<Field> = myMap.lookup(key);
if (result.isSome) {
  // use result.value
}

const addr: Either<ZswapCoinPublicKey, ContractAddress> = getRecipient();
if (addr.isLeft) {
  // use addr.left (ZswapCoinPublicKey)
} else {
  // use addr.right (ContractAddress)
}
```

Using with List.head (returns Maybe<T>):

```compact
// List.head() returns Maybe<T>
const first = myList.head();             // returns Maybe<T>
if (first.isSome) {
  const item = first.value;
}
```

Note on Map.lookup vs List.head:

```compact
// Map.lookup(key) returns V directly (NOT Maybe<V>).
// It returns default<V> if the key is not found.
// Use Map.member(key) to check existence first.
const val = myMap.lookup(key);           // returns V (or default<V> if missing)
const exists = myMap.member(key);        // returns Boolean

// Nested maps chain directly:
const balance = balances.lookup(tokenId).lookup(userId);
```

## Re-Exporting Stdlib Types

When your contract uses stdlib types as circuit parameters or return types, those types must be re-exported to make them available in the generated TypeScript interface code.

```compact
export { Maybe, Either, ShieldedCoinInfo, QualifiedShieldedCoinInfo };
```

This is required because the TypeScript code generated by the compiler needs type definitions for all types that appear in exported circuit signatures. Without the re-export, the generated TypeScript code will reference types it cannot resolve.

Common re-exports for token contracts:

```compact
export { Maybe, Either, ZswapCoinPublicKey, ContractAddress, ShieldedCoinInfo, QualifiedShieldedCoinInfo };
```

Only re-export types that actually appear in your exported circuit signatures. There is no need to re-export types used only internally.
