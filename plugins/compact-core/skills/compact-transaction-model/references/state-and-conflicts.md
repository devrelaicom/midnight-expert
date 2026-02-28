# State and Conflicts

How contract state is structured, loaded, and stored on Midnight -- and how sequential execution within transactions and concurrent transaction ordering affect state consistency, with practical patterns for minimizing conflicts.

## Contract State Structure

A contract state on Midnight consists of two parts:

| Component | Description |
|-----------|-------------|
| Impact state value | The persistent data managed by the contract -- maps, arrays, counters, Merkle trees, and other data structures declared in the Compact ledger |
| Entry point map | A map from entry point names to operations, where each entry point corresponds to an exported circuit in the contract |

Each operation contains a SNARK verifier key used to validate the zero-knowledge proof submitted with contract calls against that entry point.

The state value is an Impact state value, which can contain:

- Cells (`Field`, `Bytes<N>`, `Uint<N>`, `Boolean`) -- field-aligned binary values
- `Map` -- key-value associations from field-aligned keys to state values
- `Array(n)` -- fixed-size arrays of state values
- `MerkleTree(d)` -- sparse, fixed-depth Merkle trees with hashed leaf values

At the Compact level, these correspond to the ledger data types (`Counter`, `Map<K, V>`, `Set<T>`, `MerkleTree<N, T>`, `List<T>`, and scalar types), which compile down to Impact state values.

## State Loading and Storage

Contract state is loaded and stored during each contract call within a transaction. The lifecycle follows a strict sequence:

1. **Load.** The contract's current state is loaded from the ledger at the start of each contract call.
2. **Execute.** The Impact program executes against the loaded state, a context object derived from the transaction, and an initially empty effects set.
3. **Validate.** The resulting effects are compared against the declared effects in the transcript. A mismatch causes the call to fail.
4. **Store.** The resulting state is stored as the contract's new state, but only if the state is "strong."

### Strong and Weak Values

The context and effects objects are flagged as **weak**. Any non-size-bounded operation performed on a weak value produces a weak result. This weakness propagates transitively: if you read a value from the context and use it in a computation that modifies contract state, the resulting state becomes weak.

Size-bounded operations -- checking the type or size of a value -- do not propagate weakness. You can safely inspect the shape of context or effects data without tainting the state.

If the final contract state is weak, the transaction fails. The state is not stored. This rule prevents contracts from cheaply copying transaction-specific data (the context and effects) into persistent contract state using as few as two opcodes, circumventing the intended storage cost model.

The practical consequence for Compact developers is that values derived from `kernel.self()`, coin indices, or other context data cannot be directly stored in the ledger through non-size-bounded operations.

## Sequential Execution Within a Transaction

Multiple contract calls within a single transaction execute in strict sequential order. Each call sees the state produced by the previous call. This is a deterministic, serialized execution model within the transaction boundary.

Consider a contract with a shared counter:

```compact
export ledger counter: Counter;

export circuit increment(amount: Uint<32>): [] {
  counter += amount;
}

export circuit readAndIncrement(amount: Uint<32>): Uint<64> {
  const current = counter;
  counter += amount;
  return current;
}
```

If a single transaction contains two calls -- first `increment(5)`, then `readAndIncrement(3)` -- the execution proceeds as follows:

1. `increment(5)` loads the counter (say its value is 0), increments it by 5, and stores the state with counter = 5.
2. `readAndIncrement(3)` loads the counter (now 5), reads the current value (5), increments by 3, and stores the state with counter = 8. The return value is 5.

This sequential model means that a single transaction can compose multiple contract calls that build on each other's state changes. The second call does not see the pre-transaction state; it sees the state produced by the first call.

This also applies across contracts within the same transaction. If a transaction calls contract A and then contract B, the execution is deterministic and sequential.

## Concurrent Transactions and Block Ordering

While calls within a single transaction are sequential, transactions themselves are produced concurrently by different users and submitted to the network independently. The block producer determines the final ordering.

### Block-Level Sequencing

Within a block, transactions are applied sequentially by the block producer. If two transactions modify the same contract, the second transaction sees the state changes produced by the first. This ordering is determined at block production time, not at transaction submission time.

This has an important consequence: when a user constructs a transaction, they generate a zero-knowledge proof against the contract state they observe at that moment. If another transaction modifies the same contract state before theirs is included in a block, the proof may have been generated against stale state.

### No Optimistic Concurrency

Midnight does not use optimistic concurrency control with rollback. There is no mechanism to automatically retry a transaction against updated state. A transaction whose proof was generated against pre-modification state may simply fail if the state it depends on has changed. High-contention contracts will experience transaction failures, and the user must construct a new transaction with a fresh proof against the current state.

### The Proof Staleness Problem

The fundamental issue is timing. Between proof generation (off-chain, potentially slow) and block inclusion, the contract state may change:

1. User A reads contract state S0 and begins generating a proof for their transaction.
2. User B submits a transaction that modifies the contract state from S0 to S1.
3. User B's transaction is included in a block. The on-chain state is now S1.
4. User A submits their transaction, which was proved against S0.
5. If User A's transaction depends on specific values in S0 that have changed in S1, the transaction fails.

Whether a transaction fails depends on what it does with the state. A transaction that only appends to a set may succeed regardless of other changes. A transaction that reads a specific field value and asserts it matches a constant will fail if that field has changed.

## Design Patterns for Minimizing Conflicts

The choice of ledger data types and access patterns directly determines how susceptible a contract is to conflicts from concurrent transactions. The goal is to design state structures where independent transactions can succeed without interfering with each other.

### Conflict Risk by State Type

| State Type | Conflict Risk | Why | Recommendation |
|-----------|--------------|-----|----------------|
| `Counter` | Low | Increments commute | Preferred for counters, sequences |
| `Set<T>` | Low | Insertions do not conflict | Preferred for membership tracking |
| `MerkleTree<N, T>` | Low | Append-only insertions | Preferred for privacy-preserving sets |
| `Map<K, V>` (unique keys) | Low | Different keys do not conflict | Good for per-user state |
| `Map<K, V>` (shared keys) | High | Overwrites conflict | Avoid for concurrent writes |
| `Field` / `Bytes<N>` (shared) | High | Any write conflicts | Use Counter or Map instead |

### Append-Only and Commutative Structures

`Counter` operations are commutative. Two transactions that each call `counter.increment(1)` on the same counter will both succeed regardless of ordering, because the final result is the same: the counter increases by 2. The intermediate state does not matter because the operation is defined as a relative increment, not an absolute write.

```compact
// Low conflict: both transactions succeed regardless of order
export circuit vote(): [] {
  voteCount += 1;
}
```

`Set<T>` and `MerkleTree<N, T>` insertions are similarly low-conflict. Two transactions that insert different elements into the same set will both succeed. The set grows by two elements regardless of which transaction is applied first.

```compact
// Low conflict: independent insertions into a set
export circuit register(member: Bytes<32>): [] {
  members.insert(member);
}
```

### Per-User State with Map

Using a `Map` keyed by the user's public key (or other unique identifier) partitions the state so that each user's transaction modifies a different key. Two users updating their own balances in a `Map<Bytes<32>, Uint<64>>` do not conflict because they write to different keys.

```compact
// Low conflict: each user modifies only their own entry
export ledger balances: Map<Bytes<32>, Uint<64>>;

export circuit deposit(
  userKey: Bytes<32>,
  amount: Uint<64>
): [] {
  const current = balances.lookup(userKey);
  balances.insert(userKey, current + amount);
}
```

However, if multiple transactions write to the same map key -- for example, a shared configuration value or a global accumulator stored as a single map entry -- conflicts arise just as they would with a plain scalar field.

### Patterns to Avoid

Avoid reading a shared field value and then writing back a derived value when the pattern assumes the field has not changed between proof generation and block inclusion:

```compact
// High conflict: read-modify-write on a shared scalar field
export ledger totalBalance: Field;

export circuit addToTotal(amount: Field): [] {
  totalBalance = totalBalance + amount;  // Conflicts if another tx changes totalBalance
}
```

In this pattern, the proof encodes the value of `totalBalance` at proof generation time. If another transaction modifies `totalBalance` before this transaction is included, the state no longer matches and the transaction fails.

The fix is to use a `Counter` instead of a `Field` for accumulator patterns:

```compact
// Low conflict: counter increment is commutative
export ledger totalBalance: Counter;

export circuit addToTotal(amount: Uint<32>): [] {
  totalBalance += amount;  // Commutes with other increments
}
```

### Combining Strategies

Real contracts often combine multiple conflict-reduction strategies. A token contract might use:

- A `Counter` for total supply (commutative increments from concurrent mints)
- A `Map<Bytes<32>, Uint<64>>` for per-user balances (partitioned by user key)
- A `Set<Bytes<32>>` for tracking authorized minters (independent insertions)

This combination ensures that most operations from different users can succeed concurrently. The remaining high-conflict scenario -- two users trying to transfer tokens from the same account simultaneously -- is handled by the application's business logic rather than the data structure choice.
