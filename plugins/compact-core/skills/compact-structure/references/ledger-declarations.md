# Ledger Declarations

Complete reference for on-chain state management in Compact.

## Declaration Syntax

Each ledger field is declared individually (block syntax `ledger { }` is deprecated):

```compact
export ledger publicField: Field;
ledger privateField: Field;
export sealed ledger immutableField: Bytes<32>;
```

## Modifiers

### `export`

Makes the field readable externally. Required for fields accessed from TypeScript DApp code.

```compact
export ledger counter: Counter;       // Accessible from TypeScript
ledger internalState: Field;          // Internal only
```

### `sealed`

Field can only be set in the constructor. Immutable after deployment.

```compact
export sealed ledger owner: Bytes<32>;
export sealed ledger deployTime: Uint<64>;

constructor() {
  owner = disclose(get_public_key(local_secret_key()));
  deployTime = disclose(42);
}
```

### Combining Modifiers

```compact
export sealed ledger admin: Bytes<32>;    // Public + immutable
sealed ledger secret: Field;              // Private + immutable
export ledger mutable: Field;             // Public + mutable
ledger internal: Field;                   // Private + mutable
```

## Ledger State Types

Valid types for ledger declarations:

| Type | Description |
|------|-------------|
| Any Compact type (`T`) | `Field`, `Boolean`, `Bytes<N>`, `Uint<N>`, enums, structs |
| `Counter` | Increment/decrement counter |
| `Map<K, V>` | Key-value mapping |
| `Set<T>` | Unique value collection |
| `List<T>` | Dynamic list |
| `MerkleTree<N, T>` | Merkle tree (1 < N <= 32) |
| `HistoricMerkleTree<N, T>` | Merkle tree preserving historic roots |

Nested ADTs are supported: `Map<K, Map<K2, V>>`, `Map<K, Set<T>>`, etc.

## On-Chain Visibility

All ledger operations (reads, writes, ADT method arguments) are publicly visible on-chain, including `MerkleTree.insert()` and `HistoricMerkleTree.insert()`.

The privacy benefit of MerkleTree is that **membership proofs** (ZK path proofs via `merkleTreePathRoot` + `checkRoot`) do not reveal which specific leaf is being proven. This enables anonymous membership verification patterns (e.g., proving you are in a voter list without revealing which voter you are).

```compact
export ledger items: Set<Field>;
export ledger tree: MerkleTree<10, Field>;

items.insert(value);      // Reveals value on-chain
tree.insert(value);       // Also reveals value on-chain (all ledger ops are visible)
// Privacy comes from membership PROOFS, not from insert
```

## ADT Operations

### Counter

```compact
export ledger count: Counter;
```

| Method | Returns | Description |
|--------|---------|-------------|
| `.increment(n)` | `[]` | Increase by n (`Uint<16>`) |
| `.decrement(n)` | `[]` | Decrease by n (`Uint<16>`) |
| `.read()` | `Uint<64>` | Get current value |
| `.lessThan(n)` | `Boolean` | Compare with threshold (`Uint<64>`) |
| `.resetToDefault()` | `[]` | Reset to 0 |

All Counter operations are available in circuits.

**Common mistake**: Using `.value()` — the correct method is `.read()`.

```compact
const current = count.read();     // Correct
const current = count.value();    // Wrong - does not exist
```

### Map<K, V>

```compact
export ledger balances: Map<Bytes<32>, Uint<64>>;
```

| Method | Returns | Description |
|--------|---------|-------------|
| `.insert(key, value)` | `[]` | Add or update entry |
| `.insertDefault(key)` | `[]` | Insert default value for key |
| `.remove(key)` | `[]` | Remove entry |
| `.lookup(key)` | `V` | Get value for key |
| `.member(key)` | `Boolean` | Check if key exists |
| `.isEmpty()` | `Boolean` | Check if map is empty |
| `.size()` | `Uint<64>` | Number of entries |
| `.resetToDefault()` | `[]` | Clear entire map |

All Map operations are available in circuits.

**Important**: `lookup()` returns the value type directly (not `Maybe<V>`). Check `.member()` first to avoid unexpected results for missing keys:

```compact
if (balances.member(address)) {
  const balance = balances.lookup(address);
}
```

**TypeScript-only**: `[Symbol.iterator]()` for iteration is not available in circuits.

### Set<T>

```compact
export ledger members: Set<Bytes<32>>;
```

| Method | Returns | Description |
|--------|---------|-------------|
| `.insert(elem)` | `[]` | Add to set |
| `.remove(elem)` | `[]` | Remove from set |
| `.member(elem)` | `Boolean` | Check membership |
| `.isEmpty()` | `Boolean` | Check if empty |
| `.size()` | `Uint<64>` | Number of elements |
| `.resetToDefault()` | `[]` | Clear entire set |

All Set operations are available in circuits.

### List<T>

```compact
export ledger items: List<Field>;
```

| Method | Returns | Description |
|--------|---------|-------------|
| `.pushFront(elem)` | `[]` | Add element to front |
| `.head()` | `Maybe<T>` | Get first element |
| `.isEmpty()` | `Boolean` | Check if empty |
| `.length()` | `Uint<64>` | Number of elements |
| `.popFront()` | `[]` | Remove front element |
| `.resetToDefault()` | `[]` | Clear entire list |

### MerkleTree<N, T>

```compact
export ledger tree: MerkleTree<10, Bytes<32>>;
```

N is the tree depth (1 < N <= 32). Supports up to 2^N leaves.

| Method | Returns | Description |
|--------|---------|-------------|
| `.insert(leaf)` | `[]` | Add leaf at next free index |
| `.insertHash(leafHash)` | `[]` | Insert pre-hashed leaf |
| `.insertIndex(leaf, index)` | `[]` | Insert leaf at a specific index |
| `.insertHashIndex(leafHash, index)` | `[]` | Insert pre-hashed leaf at a specific index |
| `.checkRoot(digest)` | `Boolean` | Verifies digest matches current root (circuit-available) |
| `.isFull()` | `Boolean` | Check if tree is full |
| `.resetToDefault()` | `[]` | Reset tree to empty |
| `.root()` | `MerkleTreeDigest` | Get tree root — TypeScript only, NOT available in circuits |

To verify membership in a circuit, use a witness to provide the Merkle proof:

```compact
witness get_path(leaf: Bytes<32>): MerkleTreePath<10, Bytes<32>>;
```

### HistoricMerkleTree<N, T>

Same as `MerkleTree` but preserves historic root values. Useful for proving membership at a previous point in time.

```compact
export ledger history: HistoricMerkleTree<10, Bytes<32>>;
```

Additional operation compared to `MerkleTree`:

| Method | Returns | Description |
|--------|---------|-------------|
| `.checkRoot(digest)` | `Boolean` | Verifies digest matches any past root (circuit-available) |

All other `MerkleTree` operations are also available on `HistoricMerkleTree`.

## Kernel Ledger

The special `Kernel` type provides access to contract metadata:

```compact
// Note: kernel is auto-declared by `import CompactStandardLibrary;`
// Only declare manually if NOT using the standard library import.
ledger kernel: Kernel;

export circuit getSelf(): ContractAddress {
  return kernel.self();   // Contract's own address
}
```

## Assignment and Direct Value Types

For simple types (`Field`, `Boolean`, `Bytes<N>`, `Uint<N>`, enums, structs), assign directly:

```compact
export ledger owner: Bytes<32>;
export ledger active: Boolean;

owner = disclose(newOwner);    // Direct assignment
active = true;                 // Direct assignment
```

ADT types (Counter, Map, Set, List, MerkleTree) use their methods instead of direct assignment.
