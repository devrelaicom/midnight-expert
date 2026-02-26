---
title: List ADT
type: concept
description: The List<T> ledger ADT — a sequential collection with push/pop at both ends, suitable for event logs, queues, and ordered histories, but not concurrent.
links:
  - ledger-state-design
  - bounded-computation
  - type-system
---

# List ADT

`List<T>` is a sequential collection ADT that supports push and pop operations at both ends, plus indexed access. It fills the gap between simple Cell storage and the key-value semantics of Map — use it when ordering matters and you need queue or stack behavior.

## Declaration

```compact
export ledger history: List<Field>;
export ledger queue: List<Uint<0..1000>>;
export ledger eventLog: List<Bytes<32>>;
```

The element type `T` must be a valid Compact type as defined in the [[type-system]].

## Operations

| Operation | Syntax | Returns | Description |
|-----------|--------|---------|-------------|
| Push front | `history.push_front(value)` | — | Adds element at the beginning |
| Push back | `history.push_back(value)` | — | Adds element at the end |
| Pop front | `history.pop_front()` | `T` | Removes and returns the first element |
| Pop back | `history.pop_back()` | `T` | Removes and returns the last element |
| Indexed access | `history.nth(index)` | `T` | Returns element at index (0-based) |
| Size | `history.size()` | `Uint` | Current number of elements |
| Empty check | `history.isEmpty()` | `Boolean` | True if list has no elements |

## Use Cases

**Event logs**: Append events chronologically for on-chain audit trails:

```compact
export ledger events: List<Field>;

export circuit recordEvent(eventHash: Field): [] {
  events.push_back(eventHash);
}
```

**Queues**: First-in-first-out processing with `push_back` and `pop_front`:

```compact
export ledger taskQueue: List<Field>;

export circuit enqueue(task: Field): [] {
  taskQueue.push_back(task);
}

export circuit dequeue(): Field {
  return taskQueue.pop_front();
}
```

**Ordered histories**: Maintain a sequence where position matters, such as a list of past state transitions.

## Concurrency

**List is not concurrent.** Unlike Counter (which supports commutative operations) or Map (which isolates by key), List operations from concurrent transactions will conflict. If two transactions both `push_back` in the same block, one will fail. This is a significant limitation for high-throughput contracts.

For concurrent append-only needs, consider a MerkleTree instead (see [[ledger-state-design]]). For concurrent counting, use Counter.

## Bounded Size

Like all Compact data structures, List operations must respect [[bounded-computation]]. While there is no compile-time size limit declared in the type (unlike `Vector<n, T>` which has a fixed size), operations on very large lists increase circuit complexity. Design contracts to keep lists bounded through application logic — for example, capping the maximum number of entries via an assert:

```compact
const MAX_EVENTS: Uint<0..1000> = 100;

export circuit addEvent(event: Field): [] {
  assert events.size() < MAX_EVENTS as Field "Event log full";
  events.push_back(event);
}
```

## List vs Other ADTs

| Need | Use | Why |
|------|-----|-----|
| Ordered sequence with push/pop | **List** | Only ADT with positional access |
| Membership testing | Set | O(1) membership checks |
| Key-value lookups | Map | Named access by key |
| Single value | Cell | Simpler, no collection overhead |
| Privacy-preserving membership | MerkleTree | Supports ZK membership proofs |

See [[ledger-state-design]] for the full decision tree.
