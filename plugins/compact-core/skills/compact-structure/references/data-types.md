# Compact Data Types

Complete reference for all data types available in the Compact language.

## Primitive Types

### Field

Finite field element — the fundamental numeric type in ZK circuits. Unbounded within the field.

```compact
export ledger total: Field;
const result: Field = 42 * 42 * 42;
```

Use for: hashes, commitments, general computation where range checks are not needed.

### Boolean

Standard true/false type.

```compact
export ledger isActive: Boolean;
const flag: Boolean = true;
const check: Boolean = x > 0;
```

### Bytes<N>

Fixed-size byte array. N specifies the number of bytes.

```compact
export ledger owner: Bytes<32>;
export ledger name: Bytes<64>;
const padded: Bytes<32> = pad(32, "hello");
```

Common uses: addresses, hashes, public keys.

### Uint<N>

Unsigned integer with N bits. Equivalent to `Uint<0..(2^N - 1)>`.

```compact
export ledger balance: Uint<64>;
export ledger small: Uint<8>;     // 0..255
export ledger score: Uint<0..100>; // bounded range
```

`Uint<N>` and `Uint<0..MAX>` are the same type family:
- `Uint<8>` = `Uint<0..255>`
- `Uint<16>` = `Uint<0..65535>`
- `Uint<64>` = `Uint<0..18446744073709551615>`

### Arithmetic on Uint

Supported operators: `+`, `-`, `*` only. Division and modulo are **not** available.

Arithmetic results produce expanded bounded types that must be cast back:

```compact
const sum = (a + b) as Uint<64>;       // (Uint<64> + Uint<64>) -> cast back
const product = (a * b) as Uint<64>;   // Same for multiplication
```

Subtraction can fail at runtime if the result would be negative.

## Opaque Types

Only two opaque type tags are allowed:

```compact
export ledger label: Opaque<"string">;
export ledger data: Opaque<"Uint8Array">;
```

- In circuits, opaque values are represented as their hash (content not inspectable)
- In witnesses, opaque values can be manipulated freely
- In TypeScript, they are `string` or `Uint8Array`
- On-chain, stored as bytes/UTF-8 (not encrypted)

## Collection Types

### Vector<N, T>

Fixed-size array. N is the number of elements, T is the element type.

```compact
const pair: Vector<2, Field> = [10, 20];
const triple: Vector<3, Bytes<32>> = [pad(32, "a"), pad(32, "b"), pad(32, "c")];
```

Access elements by numeric literal index: `pair[0]`, `pair[1]`.

### Maybe<T>

Optional value — either has a value or is empty.

```compact
const opt: Maybe<Field> = some<Field>(42);
const empty: Maybe<Field> = none<Field>();

if (opt.is_some) {
  const val = opt.value;    // Safe to access
}
```

Common pattern with witnesses:

```compact
witness find_user(id: Bytes<32>): Maybe<UserRecord>;

export circuit getUser(id: Bytes<32>): UserRecord {
  const result = find_user(id);
  assert(disclose(result.is_some), "User not found");
  return result.value;
}
```

### Either<L, R>

Sum type — contains either a left value or a right value.

```compact
const success: Either<Field, Bytes<32>> = left<Field, Bytes<32>>(42);
const failure: Either<Field, Bytes<32>> = right<Field, Bytes<32>>(errorHash);

if (result.is_left) {
  const value = result.left;
} else {
  const error = result.right;
}
```

### List<T>

Dynamic list — available as a ledger type.

```compact
export ledger items: List<Field>;
```

Operations (all available in circuits):

| Method | Returns | Description |
|--------|---------|-------------|
| `.pushFront(elem)` | `[]` | Add element to front |
| `.head()` | `Maybe<T>` | Get first element |
| `.isEmpty()` | `Boolean` | Check if empty |
| `.length()` | `Uint<64>` | Number of elements |
| `.popFront()` | `[]` | Remove front element |
| `.resetToDefault()` | `[]` | Clear entire list |

## Custom Types

### Enums

Define named variants. Must be exported to use from TypeScript:

```compact
export enum GameState { waiting, playing, finished }
export enum Choice { rock, paper, scissors }
```

Access variants with dot notation:

```compact
state = GameState.waiting;      // Correct
state = GameState::waiting;     // Wrong - parse error
```

Cast enum to Field to get variant index:

```compact
const index: Field = choice as Field;
```

### Structs

Define compound types with named fields:

```compact
export struct PlayerConfig {
  name: Bytes<32>,
  score: Uint<32>,
  isActive: Boolean,
}

export struct ShieldedCoinInfo {
  nonce: Bytes<32>,
  color: Bytes<32>,
  value: Uint<128>,
}
```

Construct structs with named field syntax:

```compact
const config = PlayerConfig {
  name: pad(32, "Alice"),
  score: 100,
  isActive: true,
};
```

Access fields with dot notation: `config.score`, `config.isActive`.

## Type Casting Rules

All casts use `expression as Type` syntax.

### Safe Casts (always succeed)

| From | To | Kind |
|------|----|------|
| `Uint<N>` | `Field` | Static |
| `Uint<0..m>` | `Uint<0..n>` where m <= n | Static (widening) |
| `Boolean` | `Uint<0..n>` where n >= 1 | Conversion (false=0, true=1) |
| `enum` | `Field` | Conversion (variant index) |

### Checked Casts (can fail at runtime)

| From | To | Kind |
|------|----|------|
| `Field` | `Uint<0..n>` | Checked (fails if value > n) |
| `Uint<0..m>` | `Uint<0..n>` where m > n | Checked (narrowing) |
| `Field` | `Bytes<n>` | Conversion (can fail) |
| `Bytes<n>` | `Field` | Conversion (can fail if exceeds max Field) |

### Multi-step Casts

Some conversions can use intermediate types, though direct casts may also work:

```compact
// Uint -> Bytes: the intermediate Field route always works
const b: Bytes<32> = (amount as Field) as Bytes<32>;

// Boolean -> Field: direct cast is valid
const f: Field = flag as Field;
```

### Arithmetic Result Casts

Arithmetic produces expanded bounded types. Always cast back to target:

```compact
const sum: Uint<64> = (a + b) as Uint<64>;
const product: Uint<64> = (a * b) as Uint<64>;
```

## Language Built-ins

These are keywords/built-in functions available without imports:

| Function | Signature | Description |
|----------|-----------|-------------|
| `pad` | `pad(length, value): Bytes<N>` | Pad string to fixed-length bytes |
| `disclose` | `disclose(value: T): T` | Explicitly reveal a value |
| `assert` | `assert(condition, message): []` | Fail circuit if condition is false |
| `default` | `default<T>` | Default value for a type (keyword expression, not a function call) |

## Standard Library Functions

Provided by `import CompactStandardLibrary`:

| Function | Signature | Description |
|----------|-----------|-------------|
| `persistentHash` | `persistentHash<T>(value: T): Bytes<32>` | SHA-256 hash, guaranteed stable across upgrades |
| `persistentCommit` | `persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32>` | Persistent hiding commitment; rand must be unique Bytes<32> |
| `transientHash` | `transientHash<T>(value: T): Field` | Hash for non-stored values (returns `Field`, not `Bytes<32>`) |
| `transientCommit` | `transientCommit<T>(value: T, rand: Field): Field` | Commitment for non-stored values (returns `Field`, not `Bytes<32>`) |

### Functions That Do NOT Exist

These are common misconceptions — they are not built-in:

| Assumed Function | Reality |
|-----------------|---------|
| `public_key(sk)` | Use `persistentHash` pattern |
| `verify_signature(msg, sig, pk)` | Do off-chain in witness |
| `random()` | ZK circuits are deterministic — use witnesses |
