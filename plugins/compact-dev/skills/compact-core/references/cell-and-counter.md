---
title: Cell and Counter ADTs
type: concept
description: Cell stores a single replaceable value (implicit for plain types); Counter stores a commutative integer supporting concurrent increment and decrement.
links:
  - ledger-state-design
  - constructor-circuit
  - disclosure-model
  - type-system
  - map-and-set
  - bounded-computation
  - state-machine-pattern
---

# Cell and Counter ADTs

Cell and Counter are the two simplest ledger ADTs in Compact. Cell stores a single replaceable value; Counter stores an integer that supports commutative modifications. Every contract uses at least one of these.

## Cell<T> — Implicit Value Storage

Cell is the implicit ADT for any plain Compact type stored in the ledger. You never write `Cell<T>` explicitly — it is inferred:

```compact
ledger owner: Bytes<32>;          // This IS a Cell<Bytes<32>>
ledger state: Status;             // This IS a Cell<Status>
// ledger x: Cell<Uint<64>>;      // WRONG — Cell cannot be written explicitly
```

### Operations

| Operation | Syntax | Notes |
|-----------|--------|-------|
| Read | `owner` or `owner.read()` | Returns current value |
| Write | `owner = newVal` or `owner.write(newVal)` | Replaces value |
| Reset | `owner.resetToDefault()` | Sets to type's default |

Assignment syntax is sugar for `.write()`. Reading a field name in circuit context is sugar for `.read()`.

### Default Values

Every Cell starts at the default value of its type T until the [[constructor-circuit]] sets it. Defaults are: `0` for numeric types, `false` for Boolean, all-zero bytes for Bytes, and the first declared variant for enums (which is critical for the [[state-machine-pattern]] where the initial variant represents the starting state).

### Concurrency Warning

Cell uses **last-writer-wins** semantics. If two transactions in the same block both write to the same Cell, one write is silently lost. This makes Cell unsuitable for values that multiple users modify concurrently. Use Counter instead for concurrent modifications.

### Disclosure Requirement

Writing a witness-derived value to a Cell requires `disclose()` per the [[disclosure-model]]:

```compact
witness getNewOwner(): Bytes<32>;

export circuit changeOwner(): [] {
  const newOwner = getNewOwner();
  owner = disclose(newOwner);  // disclose required — witness data → public ledger
}
```

## Counter — Commutative Integer

Counter is designed for values that multiple transactions need to modify concurrently. Unlike Cell, Counter operations are commutative: `increment(5)` followed by `increment(3)` gives the same result regardless of order.

```compact
export ledger voteCount: Counter;
export ledger balance: Counter;
export ledger round: Counter;
```

### Operations

| Operation | Syntax | Notes |
|-----------|--------|-------|
| Increment | `voteCount.increment(n)` | Adds n to the counter |
| Decrement | `voteCount.decrement(n)` | Subtracts n (saturates at 0) |
| Read as Uint | `voteCount as Uint<0..N>` | Casts to a bounded integer |

Counter does not support direct assignment (`voteCount = 5` is invalid). It only supports increment and decrement. To read the current value, cast it: `const currentVotes = voteCount as Uint<0..1000000>;`.

### When to Use Counter vs Cell

Use **Counter** when:
- Multiple transactions might modify the value in the same block (vote tallies, token balances, round numbers)
- The modification is additive/subtractive rather than replacement
- Concurrency safety matters

Use **Cell** when:
- Only one transaction should modify the value at a time (owner address, contract state enum)
- The modification is a full replacement (setting a new owner, changing state)
- The value is read-only after initialization (consider [[sealed-ledger-fields]])

### Decrement Saturation

Counter decrement saturates at 0 — it does not underflow or error. If the counter is at 3 and you `decrement(5)`, the result is 0, not -2 and not an error. If underflow protection is needed, read the counter first and assert:

```compact
export circuit withdraw(amount: Uint<0..1000000>): [] {
  const current = balance as Uint<0..1000000>;
  assert current >= amount "Insufficient balance";
  balance.decrement(amount);
}
```

This pattern connects to the guards needed when implementing [[token-operations]] to prevent over-spending.
