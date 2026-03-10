# Compact Language Syntax Reference

Comprehensive syntax reference for the Compact smart contract language. All examples use correct, current syntax verified against the Compact compiler and official documentation.

## File Structure

Every Compact file follows this structure:

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

// Type declarations (enums, structs)
// Ledger declarations
// Witness declarations
// Circuit definitions
// Constructor (optional)
```

The pragma is mandatory. The standard library is imported with a single bare statement -- there is no selective import syntax like `import { fn } from "path"`.

## Primitive Types

| Type | Description | Size (field elements) |
|------|-------------|----------------------|
| `Boolean` | True or false | 1 bit |
| `Field` | Finite field element (~254 bits) | 1 |
| `Uint<N>` | Unsigned integer, N bits | ceil(N/254) |
| `Bytes<N>` | Fixed-size byte array | ceil(N/31) |
| `Vector<N, T>` | Fixed-size array of N elements of type T | N * size(T) |
| `[T, U, ...]` | Tuple (heterogeneous) | sum of element sizes |
| `[]` | Empty tuple (used as "no return value") | 0 |

**Types that do NOT exist**: `Void` (use `[]` instead), `Address` (use `Bytes<32>` or stdlib types like `ContractAddress`, `ZswapCoinPublicKey`).

**Array syntax**: Use `Vector<5, Field>` for a 5-element array of `Field`. The syntax `Field[5]` is invalid.

## Collection Types

### Map

```compact
export ledger balances: Map<Bytes<32>, Uint<64>>;
```

Operations -- no bracket/subscript access:

```compact
// Read a value (returns the value or a default)
const balance = balances.lookup(address);

// Write a value
balances.insert(address, newBalance);

// Check if key exists
const exists = balances.member(address);
```

`map[key]` subscript notation does NOT exist in Compact.

### Set

```compact
export ledger usedNullifiers: Set<Bytes<32>>;
```

Operations:

```compact
// Check membership
const used = usedNullifiers.member(nullifier);

// Add element
usedNullifiers.insert(nullifier);
```

The method is `.member()`, not `.contains()`.

### MerkleTree and HistoricMerkleTree

```compact
export ledger tree: MerkleTree<32, Bytes<32>>;
export ledger historicTree: HistoricMerkleTree<32, Bytes<32>>;
```

MerkleTree supports depths 1 through 32 (`1 <= d <= 32`).

Operations in circuits:

```compact
// Insert a leaf (the leaf value is HIDDEN on-chain)
tree.insert(disclose(leafValue));

// Verify membership via root comparison (not direct member check)
// Step 1: Get path from witness
witness getMerklePath(leaf: Bytes<32>): MerkleTreePath<32, Bytes<32>>;

// Step 2: Compute root from path (pass whole struct, no .value field)
const path = getMerklePath(leaf);
const digest = merkleTreePathRoot<32, Bytes<32>>(path);

// Step 3: Verify root matches
assert(tree.checkRoot(disclose(digest)), "Not in tree");
```

For `HistoricMerkleTree`, `checkRoot()` accepts proofs against any prior version of the tree, so proofs remain valid even after new insertions.

There is no `.member(value, path)` method on MerkleTree. There is no `historicMember(value, path, root)` method. Use the `merkleTreePathRoot` + `checkRoot` pattern shown above.

### Counter

```compact
export ledger count: Counter;
```

Operations:

```compact
// Read current value (returns Uint<64>)
const current = count.read();

// Increment (takes Uint<16>)
count.increment(1);
```

`Counter` is preferred over raw `Field` for counting because it provides type-safe bounded operations.

## Ledger Declarations

Each ledger field is declared individually:

```compact
export ledger counter: Counter;
export ledger commitments: HistoricMerkleTree<32, Bytes<32>>;
export ledger nullifiers: Set<Bytes<32>>;
export ledger balances: Map<Bytes<32>, Uint<64>>;
export ledger authority: Bytes<32>;
export sealed ledger adminKey: Bytes<32>;
```

The `ledger { }` block syntax was removed in Compact 0.10.1 and causes a parse error.

Use `export sealed ledger` for fields that should only be readable by the contract owner.

## Circuit Declarations

### Exported Circuits (Entry Points)

```compact
export circuit increment(): [] {
  counter.increment(1);
}

export circuit transfer(recipient: Bytes<32>, amount: Uint<64>): [] {
  assert(amount > 0, "Amount must be positive");
  balances.insert(disclose(recipient), amount);
}

export circuit getBalance(addr: Bytes<32>): Uint<64> {
  return balances.lookup(addr);
}
```

### Internal Circuits (Helpers)

```compact
// Non-exported circuit (can access ledger)
circuit get_public_key(sk: Bytes<32>): Bytes<32> {
  return persistentHash<Vector<2, Bytes<32>>>([
    pad(32, "myapp:pk:"), sk
  ]);
}

// Pure circuit (no ledger access, purely computational)
pure circuit double(x: Field): Field {
  return x * 2;
}
```

There is no `function` keyword in Compact. Use `circuit` or `pure circuit` for internal helpers.

## Witness Declarations

Witnesses are **declaration-only** -- no body, no `export` keyword:

```compact
witness local_secret_key(): Bytes<32>;
witness getProof(leaf: Bytes<32>): MerkleTreePath<32, Bytes<32>>;
witness getAmount(): Uint<64>;
witness storeData(key: Bytes<32>, value: Field): [];
```

The implementation is provided off-chain in TypeScript. Witness return values are private and carry "witness taint" -- the compiler requires `disclose()` when tainted values flow to public context.

## Variable Bindings

Compact only has `const` for local variable bindings. There is no `let` keyword. All local variables are immutable:

```compact
const x = 42 as Field;
const pk = get_public_key(sk);
const result = persistentHash<Bytes<32>>(data);
```

Constants cannot be reassigned (though they can be shadowed in nested blocks). State mutation happens through ledger operations only.

## Control Flow

### Conditional

Parentheses around the condition are mandatory:

```compact
if (condition) {
  // then branch
} else {
  // else branch
}
```

`if condition { }` without parentheses is a parse error.

### Loop

```compact
for (const i of 0..10) {
  // loop body -- i goes from 0 to 9
}
```

Parentheses are required. `const` is required. The `of` keyword is used (not `in`). The syntax `for i in 0..10` does not exist.

### Assert

```compact
assert(amount > 0, "Amount must be positive");
assert(disclose(pk == authority), "Not authorized");
assert(disclose(!nullifiers.member(nul)), "Already used");
```

Parentheses are required. A message string is expected. `assert condition;` without parentheses is a parse error.

## Arithmetic and Comparison

### Arithmetic Operators

Available on both `Field` and `Uint<N>`:

```compact
const sum = a + b;
const diff = a - b;
const product = a * b;
```

Division is available on `Field` only (modular inverse).

### Comparison Operators

**Critical restriction**: `<`, `>`, `<=`, `>=` only work on `Uint<N>` types. Using them on `Field` causes a type error.

```compact
// VALID -- Uint<64> comparisons
const amount: Uint<64> = getAmount();
assert(amount > 0, "Must be positive");
assert(amount <= 1000, "Exceeds limit");

// INVALID -- Field comparisons
// const x: Field = someField();
// assert(x > 0, "error");  // TYPE ERROR: > not defined on Field
```

Equality (`==`) and inequality (`!=`) work on all types.

### Boolean Operators

```compact
const both = a && b;      // logical AND
const either = a || b;    // logical OR
const negated = !a;       // logical NOT
```

## Type Casting

```compact
const fieldVal = 42 as Field;
const uintVal = 100 as Uint<64>;
const bytesVal = fieldVal as Bytes<32>;

// Two-step cast for Uint<N> to Bytes<N>
const roundBytes = (round as Field) as Bytes<32>;
```

Direct `Uint<N>` to `Bytes<N>` cast is invalid -- cast through `Field` first.

## Hash and Commitment Functions

All provided by `CompactStandardLibrary`:

### persistentHash (SHA-256)

```compact
// Single value
const hash = persistentHash<Bytes<32>>(data);

// Multiple values -- wrap in Vector
const hash = persistentHash<Vector<2, Bytes<32>>>([data1, data2]);

// Domain-separated hash
const pk = persistentHash<Vector<2, Bytes<32>>>([
  pad(32, "myapp:pk:"), secretKey
]);
```

`persistentHash` takes exactly ONE typed argument. To hash multiple values, wrap them in a `Vector`. Output is stable across compiler versions (SHA-256).

### persistentCommit

```compact
// Commit to a value with randomness
const commitment = persistentCommit<Uint<64>>(value, randomness);
// randomness must be Bytes<32>
```

Signature: `persistentCommit<T>(value: T, rand: Bytes<32>): Bytes<32>`. Clears witness taint on the input (the committed value is considered cryptographically hidden).

### Transient Variants

```compact
// Circuit-optimized hash (output may change between compiler versions)
const tHash = transientHash<Field>(value);

// Circuit-optimized commitment (rand is Field, not Bytes<32>)
const tCommit = transientCommit<Field>(value, randomField);
```

Transient function outputs must NOT be stored in ledger state because the algorithm may change between compiler versions.

## Token Operations

Token operations are standard library circuit calls, not special statement syntax:

```compact
// Receive a coin
receive(coinInfo: CoinInfo): []

// Send a coin
send(
  input: QualifiedCoinInfo,
  recipient: Either<ZswapCoinPublicKey, ContractAddress>,
  value: Uint<128>
): SendResult

// Mint an unshielded token
mintUnshieldedToken(
  domainSep: Bytes<32>,
  value: Uint<64>,
  recipient: Either<ContractAddress, UserAddress>
): Bytes<32>
```

There is no `receive coins: Coin[];` or `send value, to: Address;` statement syntax.

## Comments

```compact
// Single-line comment

/* Multi-line
   comment */
```

## Enum and Struct Types

```compact
// Enum declaration
export enum Phase { setup, commit, reveal, finalized }

// Enum usage
phase = Phase.setup;
if (phase == Phase.commit) { ... }
```

Enum values use dot notation: `Phase.commit` (not `Phase::commit`).

## disclose() Annotation

The `disclose()` function marks the boundary between private (witness-tainted) and public (ledger-visible) data:

```compact
// Required when writing witness-derived values to ledger
authority = disclose(pk);

// Required when using witness data in assert conditions
assert(disclose(pk == authority), "Not authorized");

// Required when using witness data in Set/Map operations
nullifiers.insert(disclose(nul));
assert(disclose(!nullifiers.member(nul)), "Already used");

// Required when returning witness data from exported circuits
return disclose(value);
```

Commitment functions (`persistentCommit`, `transientCommit`) clear witness taint on their inputs. Hash functions do not.

## Best Practices

### Comparison Cost

Comparisons on `Uint<N>` values are expensive in ZK circuits because they require bit decomposition to check ordering. Equality checks (`==`) are cheaper than relational comparisons (`<`, `>`, `<=`, `>=`). Use equality when possible:

```compact
// More expensive (requires bit decomposition)
if (amount > 0) { ... }

// Cheaper (direct field comparison)
if (amount != 0 as Uint<64>) { ... }
```

Note: both `amount` values must be `Uint<N>` for comparison operators to work.

### Domain Separation

Always use domain separators when deriving hashes for different purposes:

```compact
// Different domains prevent cross-purpose correlation
const pk = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), sk]);
const nul = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:nul:"), sk]);
```

### Minimize Disclosure

Disclose only what is necessary. Prefer disclosing boolean results over underlying values:

```compact
// GOOD: disclose only the comparison result
assert(disclose(value >= threshold), "Below minimum");

// BAD: disclose the actual value (reveals more than needed)
const disclosedValue = disclose(value);
assert(disclosedValue >= threshold, "Below minimum");
```
