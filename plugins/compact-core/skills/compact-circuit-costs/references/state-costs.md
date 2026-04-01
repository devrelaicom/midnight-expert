# State Costs

Detailed reference for understanding how ledger type choices affect storage costs, privacy tradeoffs, and overall contract efficiency. For full ADT operation semantics, see `compact-ledger`. For privacy pattern design, see `compact-privacy-disclosure`.

## Ledger Type Cost Comparison

### Fixed-Size Types

These types have constant storage cost regardless of usage:

| Type | Storage Size | Notes |
|------|-------------|-------|
| `Field` | 1 field element (~32 bytes) | Cheapest single-value storage |
| `Boolean` | 1 field element | Same cost as Field |
| `Uint<N>` | 1 field element | Same cost regardless of N |
| `Bytes<N>` | ⌈N/31⌉ field elements | Grows with byte length |
| Enum | 1 field element | Stored as numeric index |
| Struct | Sum of field sizes | Each field contributes individually |
| `Counter` | 1 field element | Fixed; cheapest ADT |

### Variable-Size Types

These types grow with the number of entries:

| Type | Storage Per Entry | Growth Pattern | Empty Cost |
|------|------------------|----------------|------------|
| `Map<K, V>` | key_size + value_size | Linear with entries | Minimal (empty map) |
| `Set<T>` | element_size | Linear with entries | Minimal (empty set) |
| `List<T>` | element_size + pointer | Linear with entries | Minimal (empty list) |

### Sparse, Lazy Storage Types

MerkleTree uses sparse, lazy storage — `MerkleTree::blank(height)` creates a single stub node. Nodes are computed on-demand via `rehash()`. Storage grows only as leaves are inserted, not upfront.

| Type | Storage Model | Leaf Capacity | Notes |
|------|-------------|----------|-------|
| `MerkleTree<N, T>` | Sparse, lazy — nodes computed on demand | 2^N leaves | No upfront allocation |
| `HistoricMerkleTree<N, T>` | Sparse, lazy + root history | 2^N leaves | Additional storage for retained roots |

MerkleTree depth `N` has significant cost implications:
- `MerkleTree<10, Bytes<32>>` — 1,024 leaf capacity
- `MerkleTree<20, Bytes<32>>` — 1,048,576 leaf capacity
- `MerkleTree<32, Bytes<32>>` — 4,294,967,296 leaf capacity (maximum depth)

Choose the minimum depth that supports your expected membership set size. Deeper trees incur more per-proof hash operations (O(N) hashes per membership proof); undersizing requires contract redeployment.

## Privacy-Cost Tradeoffs

Different ledger types offer different privacy characteristics at different costs. This is the fundamental tradeoff in Midnight contract design.

### Operation Visibility by Type

| Type | Insert/Write | Read/Lookup | Membership Check | Delete/Remove |
|------|-------------|-------------|-----------------|---------------|
| Direct field | Value visible | Value visible | N/A | N/A |
| `Counter` | Amount visible | Value visible | Comparison visible | N/A |
| `Map<K, V>` | Key + value visible | Key + value visible | Key visible | Key visible |
| `Set<T>` | Element visible | N/A | Element visible | Element visible |
| `List<T>` | Element visible | Value visible | N/A | N/A |
| `MerkleTree<N, T>` | **Leaf hidden** — `insert()` applies `leaf_hash()` before storing | N/A | **Proven via ZK (hides which leaf)** | N/A |
| `HistoricMerkleTree<N, T>` | **Leaf hidden** — `insert()` applies `leaf_hash()` before storing | N/A | **Proven via ZK (hides which leaf)** | N/A |

Key insight: `MerkleTree.insert()` hides the leaf value — the compiler applies `leaf_hash()` (a `persistent_hash`) before storing, so only the hash appears in the transaction transcript. This is the only ledger operation that hides its data argument. Additionally, membership is proven without revealing which entry (via ZK path proofs). This privacy comes at the cost of:
- Storage grows with insertions (sparse, lazy allocation)
- Path proof computation (O(N) hashes in-circuit for depth N)
- Off-chain path generation (witness provides the proof path)

### Privacy Cost Decision Matrix

| Privacy Need | Cheapest Solution | Notes |
|-------------|------------------|-------|
| No privacy needed | Direct field, Counter, Map, Set | Cheapest; all operations visible |
| Hide values but not keys | `Map<K, Bytes<32>>` with committed values | Store `persistentCommit(value, rand)` as the value |
| Hide membership | `MerkleTree<N, T>` | Only option for private membership proofs |
| Hide membership + accept old proofs | `HistoricMerkleTree<N, T>` | Higher cost than MerkleTree |
| Hide both keys and values | `MerkleTree<N, Bytes<32>>` with commitments | Store commitments as leaves; verify via nullifiers |

### Example: Membership Check Cost Comparison

```compact
// PUBLIC: Set reveals which member is checked
export ledger voters: Set<Bytes<32>>;

export circuit checkVoterPublic(voter: Bytes<32>): Boolean {
  return voters.member(disclose(voter));  // voter identity visible on-chain
}

// PRIVATE: MerkleTree hides which member is proven
export ledger voterTree: MerkleTree<10, Bytes<32>>;

witness get_voter_path(voter: Bytes<32>): MerkleTreePath<10, Bytes<32>>;

export circuit checkVoterPrivate(voter: Bytes<32>): [] {
  const path = get_voter_path(voter);
  const digest = merkleTreePathRoot<10, Bytes<32>>(path);
  assert(voterTree.checkRoot(disclose(digest)), "Not a voter");
  // voter identity NOT revealed on-chain
}
```

The private version costs more (MerkleTree state + path proof computation) but hides which voter is being checked.

## Sealed Fields

The `sealed` modifier makes a ledger field immutable after construction:

```compact
export sealed ledger admin: Bytes<32>;
export sealed ledger maxSupply: Uint<64>;
export sealed ledger contractName: Bytes<32>;
```

### Cost Benefits

1. **No state-write circuits** — The compiler doesn't generate circuits for modifying sealed fields, reducing the contract's overall circuit count
2. **No bytesWritten gas** — After construction, these fields never incur write costs
3. **Simpler verification** — Immutable config values don't need change-tracking logic
4. **Smaller proving keys** — Fewer circuits means less key material to distribute

### When to Use Sealed

Use `sealed` for:
- Admin addresses or public keys
- Contract configuration (thresholds, limits, names)
- Token metadata (domain separator, max supply)
- Any value that should never change after deployment

Do not use `sealed` for:
- Values that need updating (balances, counters, state machines)
- Values set conditionally after deployment

## State Design for Cost

### Choosing the Right Type

| Requirement | Recommended Type | Cost Reasoning |
|-------------|-----------------|----------------|
| Count something | `Counter` | Smallest fixed cost; no key/value overhead |
| Store a single value | Direct field (`Field`, `Bytes<N>`, etc.) | Smallest possible storage |
| Key-value lookups with rare writes | `Map<K, V>` | Efficient reads; write cost acceptable if infrequent |
| Key-value lookups with frequent writes | `Map<K, V>` with batched updates | Same type, but design circuits to minimize write frequency |
| Membership checks (no privacy) | `Set<T>` | Lower overhead than Map; no value storage |
| Membership checks (with privacy) | `MerkleTree<N, T>` | Higher cost but necessary for privacy |
| Ordered data with front access | `List<T>` | Use only when ordering matters |
| Immutable configuration | `sealed` direct field | Zero ongoing state-write cost |
| Complex nested state | `Map<K, Map<...>>` or `Map<K, Counter>` | Only Map supports nesting; adds lookup overhead |

### Counter vs Direct Field for Numeric Values

```compact
// Counter: supports increment/decrement, costs Uint<64> storage
export ledger count: Counter;

// Direct field: supports arbitrary assignment, costs 1 field element
export ledger value: Uint<64>;
```

Use `Counter` when you need atomic increment/decrement operations. Use a direct field when you need arbitrary value assignment. Counter is slightly more specialized but provides safe concurrent increment semantics.

### Map Size Management

Maps grow unboundedly. If your contract inserts entries without ever removing them, state costs grow linearly over the contract's lifetime. Strategies:

1. **Bounded maps** — Check `size()` before inserting and reject when full
2. **Periodic cleanup** — Provide a circuit that removes stale entries
3. **Fixed-size alternative** — Use a `Vector` if the number of entries is known at compile time

```compact
export ledger entries: Map<Bytes<32>, Uint<64>>;

export circuit addEntry(key: Bytes<32>, value: Uint<64>): [] {
  // Bound the map size to prevent unbounded growth
  assert(entries.size() < 1000 as Uint<64>, "Map is full");
  entries.insert(disclose(key), disclose(value));
}
```

## Nested ADT Cost Implications

Only `Map` supports values that are other ledger state types. Nesting adds cost at each level of access:

```compact
export ledger nested: Map<Bytes<32>, Map<Bytes<32>, Counter>>;
```

### Access Cost Chain

Each level of nesting requires a `lookup()` (which costs `readTime` gas):

```compact
// 2 lookups + 1 read = 3 read operations
const value = nested.lookup(outerKey).lookup(innerKey).read();

// 2 lookups + 1 increment = 2 reads + 1 write
nested.lookup(outerKey).lookup(innerKey).increment(1);
```

### When Nesting Is Worth It

**Use nesting when:**
- The data naturally has a hierarchical key structure (e.g., user → resource → count)
- You need per-user or per-category sub-state
- The inner state type provides useful operations (e.g., Counter's atomic increment)

**Avoid nesting when:**
- A composite key achieves the same result: `Map<[Bytes<32>, Bytes<32>], Uint<64>>` instead of `Map<Bytes<32>, Map<Bytes<32>, Uint<64>>>`
- The inner map/set/counter is rarely accessed
- You only need flat key-value storage

### Initialization Cost

Nested ADTs must be initialized with `default<V>` before use. Each initialization is a state write:

```compact
// 3 writes to initialize a nested structure
nested.insert(userKey, default<Map<Bytes<32>, Counter>>);       // Write 1
nested.lookup(userKey).insert(resourceKey, default<Counter>);   // Write 2
nested.lookup(userKey).lookup(resourceKey).increment(1);        // Write 3
```

For contracts with many users, this initialization cost is incurred once per user but adds up. Consider whether the nesting provides enough benefit to justify the per-user setup cost.
