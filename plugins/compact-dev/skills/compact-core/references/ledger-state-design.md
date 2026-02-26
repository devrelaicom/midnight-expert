---
title: Ledger State Design
type: concept
description: Choosing the right on-chain ADT — Cell, Counter, Map, Set, List, MerkleTree, or HistoricMerkleTree — based on access patterns, concurrency, and privacy needs.
links:
  - cell-and-counter
  - map-and-set
  - merkle-trees
  - sealed-ledger-fields
  - contract-file-layout
  - constructor-circuit
  - disclosure-model
  - bounded-computation
  - type-system
  - list-adt
---

# Ledger State Design

Every Compact contract stores its on-chain state in ledger fields, each typed with one of the available Abstract Data Types (ADTs). Choosing the right ADT is one of the most consequential design decisions because it affects concurrency behavior, privacy capabilities, gas costs, and circuit complexity.

## Decision Tree

**Do you need a single value?**
- Yes, and it changes by replacement → **Cell** (implicit — just declare `ledger field: Type;`)
- Yes, and it changes by increment/decrement → **Counter** (see [[cell-and-counter]])

**Do you need a key-value collection?**
- Yes, with arbitrary key lookups → **Map<K, V>** (see [[map-and-set]])
- Yes, with membership checks only → **Set<T>** (see [[map-and-set]])

**Do you need an ordered list?**
- Yes, with bounded size → **List<T>** (see [[list-adt]])

**Do you need privacy-preserving membership proofs?**
- Yes, with append-only inserts → **MerkleTree<n, T>** (see [[merkle-trees]])
- Yes, with historical state queries → **HistoricMerkleTree<n, T>** (see [[merkle-trees]])

## All Ledger ADTs

| ADT | Declaration | Key Operations | Concurrency |
|-----|-------------|---------------|-------------|
| Cell<T> | `ledger x: T;` | read, write, resetToDefault | Last-writer-wins |
| Counter | `ledger x: Counter;` | increment, decrement, as Uint | Commutative (safe) |
| Map<K, V> | `ledger x: Map<K, V>;` | lookup, insert, remove | Per-key isolation |
| Set<T> | `ledger x: Set<T>;` | member, insert, remove | Per-element isolation |
| [[list-adt]] | `ledger x: List<T>;` | push, nth, length | Not concurrent |
| MerkleTree<n, T> | `ledger x: MerkleTree<n, T>;` | insert, digest, member via proof | Append-only |
| HistoricMerkleTree<n, T> | `ledger x: HistoricMerkleTree<n, T>;` | insert, digest, historical digest | Append + history |

## Concurrency Considerations

The most important practical distinction is concurrency. Cell uses last-writer-wins semantics: if two transactions write to the same Cell in the same block, one write is lost. Counter avoids this with commutative operations: `increment(5)` and `increment(3)` from concurrent transactions both apply, resulting in an increment of 8.

This is why [[cell-and-counter]] recommends Counter for any value that multiple transactions might modify simultaneously (vote counts, token balances, round numbers).

## Nesting Rules

Only Map values support nesting. A Map's value type can be another ADT:

```compact
ledger nestedState: Map<Bytes<32>, Map<Field, Counter>>;
```

No other ADT supports nested state types. You cannot have a `Set<Map<...>>` or a `List<Counter>`. This constraint shapes how complex state must be modeled — often requiring multiple top-level ledger fields rather than deep nesting.

## Privacy Considerations

All ledger state is publicly visible on the Midnight blockchain regardless of the `export` keyword (which only controls TypeScript API access as described in [[disclosure-model]]). To store private data on-chain, use commitment schemes: store `persistentHash(secret)` in a Cell or `transientCommit(secret)` in a MerkleTree, then prove knowledge of the preimage in circuits. The [[merkle-trees]] section covers the privacy-preserving membership proof pattern in detail.

## Initialization

All ledger fields start at their type's default value and are initialized by the [[constructor-circuit]]. Counter defaults to 0, Map and Set default to empty, and Cell defaults to the type's zero value. Fields that should not change after deployment can use [[sealed-ledger-fields]] to prevent post-constructor modification.

## Size and Cost

Circuit complexity grows with the number of ledger operations. MerkleTree operations are the most expensive because they require computing hash paths proportional to the tree depth. Cell and Counter operations are cheap. Map lookups add moderate overhead. Design contracts to minimize the number of ledger operations per circuit, keeping the constraints of [[bounded-computation]] in mind.
