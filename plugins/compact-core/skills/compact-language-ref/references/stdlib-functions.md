# Standard Library Functions

The `CompactStandardLibrary` module provides built-in functions for hashing, commitments, disclosure, assertions, padding, and default values. Import it at the top of every contract:

```compact
import CompactStandardLibrary;
```

## Hashing Functions

Compact provides two hash functions that differ in output type, algorithm stability, and performance.

### persistentHash

```compact
circuit persistentHash<T>(value: T): Bytes<32>;
```

SHA-256 based compression from an arbitrary value to a 256-bit byte string. The algorithm is guaranteed to persist between compiler upgrades, so the same input always produces the same output across different compiler versions. Use `persistentHash` whenever the result will be stored in ledger state, compared across transactions, or used for public key derivation.

```compact
// Derive a public key from a secret key
circuit publicKey(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"),
    sk
  ]);
}

// Compute a domain-separated nullifier
circuit nullifier(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:nul:"),
    sk
  ]);
}
```

Because `persistentHash` is not circuit-optimised, it costs more circuit gates than its transient counterpart. Accept that cost when durability matters.

Disclosure note: hashing is not considered sufficient to protect witness values from disclosure. If the input contains a witness value and the result flows to the public ledger, you must wrap it in `disclose()`.

### transientHash

```compact
circuit transientHash<T>(value: T): Field;
```

Circuit-efficient compression from an arbitrary value to a `Field` element. The underlying algorithm is not guaranteed to remain the same across compiler upgrades, so values produced by `transientHash` must not be stored in ledger state or compared across transactions. Use it for intermediate computations within a single circuit execution.

```compact
// Transient hash for an in-circuit consistency check
export circuit verifyData(data: Field, expected: Field): [] {
  const h = transientHash<Field>(data);
  assert(disclose(h == expected), "Data mismatch");
}
```

Disclosure note: like `persistentHash`, transient hashing is not considered sufficient to protect witness values from disclosure. A `disclose()` wrapper is required when the result reaches the public ledger.

### Choosing Between Persistent and Transient Hashing

| Criterion | `persistentHash` | `transientHash` |
|-----------|------------------|-----------------|
| Return type | `Bytes<32>` | `Field` |
| Algorithm | SHA-256 (stable across upgrades) | Circuit-efficient (may change) |
| Store in ledger | Yes | No |
| Compare across transactions | Yes | No |
| Circuit cost | Higher | Lower |

## Commitment Functions

Commitments are hiding: they conceal the committed value while binding the committer to it. Both commitment functions take an explicit randomness parameter.

### persistentCommit

```compact
circuit persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32>;
```

SHA-256 based commitment from an arbitrary value and a 256-bit randomness opening to a 256-bit byte string. Guaranteed to persist between compiler upgrades. Use when the commitment will be stored in ledger state or verified across transactions.

```compact
witness local_secret_key(): Bytes<32>;
witness get_nonce(): Bytes<32>;

export ledger storedCommitment: Bytes<32>;

export circuit commitValue(value: Field): [] {
  const rand = get_nonce();
  const valueBytes = value as Bytes<32>;
  storedCommitment = persistentCommit<Vector<2, Bytes<32>>>(
    [valueBytes, pad(32, "myapp:commit:")],
    rand
  );
}
```

Disclosure note: unlike hashing, commitment functions are considered sufficient to protect their input from disclosure (assuming the randomness is sufficiently random). You do not need a `disclose()` wrapper around the committed value itself. You also do not need `disclose()` when storing the commitment result in the public ledger. The commitment is considered sufficient protection for its inputs and outputs.

### transientCommit

```compact
circuit transientCommit<T>(value: T, rand: Field): Field;
```

Circuit-efficient commitment from an arbitrary value and a `Field` randomness opening to a `Field` result. Not guaranteed to persist between compiler upgrades. Use for in-circuit consistency checks where the commitment is consumed within the same circuit execution.

```compact
witness fresh_nonce(): Field;

circuit internalCheck(secret: Field): Field {
  const rand = fresh_nonce();
  return transientCommit<Field>(secret, rand);
}
```

Like `persistentCommit`, transient commitments are considered sufficient to protect their input from disclosure. No `disclose()` wrapper is needed around the committed value when storing the result publicly, provided the randomness is sufficiently random.

### Choosing Between Persistent and Transient Commitments

| Criterion | `persistentCommit` | `transientCommit` |
|-----------|--------------------|--------------------|
| Return type | `Bytes<32>` | `Field` |
| Randomness type | `Bytes<32>` | `Field` |
| Algorithm | SHA-256 (stable across upgrades) | Circuit-efficient (may change) |
| Store in ledger | Yes | No |
| Circuit cost | Higher | Lower |

## Conversion Between Persistent and Transient

Two utility functions convert values between the `Bytes<32>` domain (persistent) and the `Field` domain (transient).

### degradeToTransient

```compact
circuit degradeToTransient(x: Bytes<32>): Field;
```

Converts the output of `persistentHash` or `persistentCommit` into a `Field` value suitable for use with `transientHash` or `transientCommit`.

### upgradeFromTransient

```compact
circuit upgradeFromTransient(x: Field): Bytes<32>;
```

Converts a `Field` value back into a `Bytes<32>` value compatible with `persistentHash` or `persistentCommit` outputs.

```compact
// Mix persistent and transient operations
const pk = persistentHash<Bytes<32>>(sk);
const pkField = degradeToTransient(pk);
const combined = transientHash<Vector<2, Field>>([pkField, someField]);
const result = upgradeFromTransient(combined);
```

## Utility Functions

### pad

```compact
pad(length, value): Bytes<N>
```

Produces a `Bytes<N>` value from a string literal by UTF-8 encoding the string and appending zero bytes up to the specified length. Both the length and the string must be literals (not variables).

```compact
const label: Bytes<32> = pad(32, "hello");   // 5 content bytes + 27 zero bytes
const tag: Bytes<8> = pad(8, "v1");          // 2 content bytes + 6 zero bytes
```

Common use: create fixed-size domain separators for hashing and commitment schemes.

```compact
const domainSep = pad(32, "myapp:auth:");
const hash = persistentHash<Vector<2, Bytes<32>>>([domainSep, data]);
```

### disclose

```compact
disclose(value: T): T
```

Explicitly marks a value as publicly visible on-chain. Required whenever a witness-derived value flows to a ledger operation, is returned from an exported circuit, is used in a conditional branch, or is passed to another contract via a cross-contract call. The compiler rejects programs that disclose witness values implicitly.

```compact
witness get_secret(): Field;

export circuit check(expected: Field): [] {
  const secret = get_secret();

  // Wrap the comparison in disclose -- branching on witness values
  // reveals information about them
  if (disclose(secret == expected)) {
    count.increment(1);
  }
}

export circuit publish(value: Field): [] {
  const w = get_secret();
  // Storing a witness-derived value in the ledger requires disclose
  storedValue = disclose(w);
}
```

When using commitment functions (`persistentCommit`, `transientCommit`), the commitment itself is considered sufficient to protect both its inputs and the commitment result from disclosure. You do not need `disclose()` around the committed value or when storing the commitment result in the ledger.

### assert

```compact
assert(condition: Boolean, message: string): []
```

Aborts the transaction (fails the circuit proof) if the condition evaluates to false. The message is required.

```compact
export circuit withdraw(amount: Uint<64>): [] {
  const d_amount = disclose(amount);
  assert(d_amount > 0, "Amount must be positive");
  balance = (balance - d_amount) as Uint<64>;
}
```

Assertions are the only error-handling mechanism in Compact. There are no exceptions, try-catch blocks, or error codes. A failed assertion means the entire transaction is invalid and produces no state changes.

### default

```compact
default<T>: T
```

Returns the default value for any Compact type. `default` is a keyword expression, not a function call -- no parentheses. Useful for initializing values and resetting state.

| Type | Default |
|------|---------|
| `Boolean` | `false` |
| `Field` | `0` |
| `Uint<N>` / `Uint<0..n>` | `0` |
| `Bytes<N>` | All-zero byte array |
| Enum | First declared variant |
| Struct | All fields at their defaults |
| `Counter` | Counter at 0 |

```compact
const emptyHash = default<Bytes<32>>;
const zeroBal = default<Uint<64>>;
const initialState = default<GameState>;   // first variant
```

## When to Use Persistent vs Transient

Choose persistent functions (`persistentHash`, `persistentCommit`) when:

- The value will be stored in ledger state
- The value must be compared across separate transactions
- The value serves as a public key, nullifier, or on-chain commitment
- Long-term reproducibility matters (the same input must always yield the same output, even after compiler upgrades)

Choose transient functions (`transientHash`, `transientCommit`) when:

- The value is used only within a single circuit execution and then discarded
- You need lower circuit cost for intermediate computations
- The value serves as a temporary consistency check within one proof

When you need to combine both domains in a single circuit, use `degradeToTransient` and `upgradeFromTransient` to convert between `Bytes<32>` and `Field` representations.
