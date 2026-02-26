---
title: Map and Set ADTs
type: concept
description: Map<K,V> provides key-value storage with per-key isolation; Set<T> provides membership tracking with insert, remove, and member operations.
links:
  - ledger-state-design
  - cell-and-counter
  - merkle-trees
  - type-system
  - bounded-computation
  - constructor-circuit
---

# Map and Set ADTs

Map and Set are the collection-oriented ledger ADTs in Compact. Map provides key-value storage; Set provides membership tracking. Both offer per-element isolation for concurrent access, making them suitable for multi-user contracts.

## Map<K, V> — Key-Value Storage

Map stores values indexed by keys. Keys can be any Compact type from the [[type-system]]; values can be any ledger state type, including other ADTs (Map is the only ADT that supports nesting).

```compact
export ledger balances: Map<Bytes<32>, Counter>;
export ledger userData: Map<Field, UserRecord>;
ledger permissions: Map<Bytes<32>, Map<Field, Boolean>>;  // nested Map
```

### Operations

| Operation | Syntax | Notes |
|-----------|--------|-------|
| Lookup | `balances.lookup(key)` | Returns the value at key, or default if absent |
| Insert | `balances.insert(key, value)` | Sets value at key |
| Remove | `balances.remove(key)` | Deletes the key-value pair |

### Missing Key Behavior

`lookup()` on a missing key returns the **default value** of the value type rather than erroring. For Counter this is 0; for Cell types it's the type's default. This means you cannot distinguish "key exists with default value" from "key doesn't exist." If that distinction matters, use a `Map<K, Maybe<V>>` pattern where `none` indicates absence and `some(v)` indicates presence, using the types from [[maybe-and-either-types]].

### Nested Maps

Map is the only ADT that supports nesting. A Map's value type can be another Map, Counter, or other ADT:

```compact
// Two-level Map: user → token → balance
ledger tokenBalances: Map<Bytes<32>, Map<Bytes<32>, Counter>>;

// Access nested state with chained lookups:
export circuit getBalance(user: Bytes<32>, token: Bytes<32>): Uint<0..1000000> {
  return tokenBalances.lookup(user).lookup(token) as Uint<0..1000000>;
}
```

You must chain lookups in a single expression. The pattern `const inner = map.lookup(key); inner.lookup(key2)` is invalid because ledger ADTs cannot be assigned to local variables.

### Concurrency

Map provides per-key isolation. Two transactions modifying different keys in the same Map can execute concurrently without conflict. Two transactions modifying the same key follow the value type's semantics — if the value is a Counter, concurrent modifications are commutative; if it's a Cell-type, last-writer-wins applies.

## Set<T> — Membership Tracking

Set tracks whether elements are members of a collection. Unlike Map, Set does not store associated values — it only answers "is this element in the set?"

```compact
export ledger registeredUsers: Set<Bytes<32>>;
export ledger usedNonces: Set<Bytes<32>>;
```

### Operations

| Operation | Syntax | Notes |
|-----------|--------|-------|
| Check membership | `registeredUsers.member(value)` | Returns Boolean |
| Insert | `registeredUsers.insert(value)` | Adds to set |
| Remove | `registeredUsers.remove(value)` | Removes from set |

### Use Cases

Set is ideal for:
- **Nonce tracking**: Insert each nonce after use, check `member()` before accepting a new one to prevent replay
- **Registration**: Track which addresses have registered
- **Allowlists/blocklists**: Check membership before granting access

### Set vs MerkleTree for Membership

Both Set and [[merkle-trees]] can answer membership queries, but they differ fundamentally:

- **Set**: Membership is checked on-chain. The element being checked is visible in the transaction. No privacy.
- **MerkleTree**: Membership is proven via a Merkle path in the ZK proof. The element being checked remains private. Full privacy.

Choose Set when membership is not sensitive. Choose MerkleTree when you need the [[anonymous-membership-proof]] pattern.

### Iteration Limitation

Neither Map nor Set supports iteration in circuits. You cannot "loop over all keys" or "loop over all members" because that would violate [[bounded-computation]] (the number of elements is not known at compile time). If you need to process all elements, maintain a separate bounded data structure (like a `Vector` or `List`) alongside the Map/Set.
