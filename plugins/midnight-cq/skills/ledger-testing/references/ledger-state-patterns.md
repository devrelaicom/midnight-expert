# Ledger State Patterns

Patterns for testing `ZswapLocalState`, `DustLocalState`, and `LedgerState`
from `@midnight-ntwrk/ledger-v8`.

## Key Principle: State Is Immutable

Both `ZswapLocalState` and `DustLocalState` return new instances on every
mutation. The original object is never modified. Tests that assert on the
original after calling a mutation method will always pass — even if the method
is broken.

`ZswapLocalState.coins` is a `Set<QualifiedShieldedCoinInfo>` — assert on
`.size`, not `.length`.

```typescript
// GOOD: Assert on the returned value
const [updated] = original.spend(secretKeys, coin, segment);
expect(updated.coins.size).toBe(original.coins.size - 1);

// BAD: Original is unchanged — this assertion proves nothing
// const [updated] = original.spend(secretKeys, coin, segment);
// expect(original.coins.size).toBe(original.coins.size - 1);
```

---

## ZswapLocalState Patterns

Construct an empty state with `new ZswapLocalState()`. Key read-only fields:
`coins: Set<QualifiedShieldedCoinInfo>`, `pendingOutputs: Map<CoinCommitment, ...>`,
`pendingSpends: Map<Nullifier, ...>`, `firstFree: bigint`,
`merkleTreeRoot: bigint | undefined`. Many methods take `ZswapSecretKeys`
(derive with `ZswapSecretKeys.fromSeed(seed)`).

### Testing spend()

`spend(secretKeys, coin, segment, ttl?)` initiates a spend and returns the
tuple `[ZswapLocalState, UnprovenInput]`; the spent coin moves into
`pendingSpends`.

```typescript
import { ZswapLocalState } from '@midnight-ntwrk/ledger-v8';

it('should return new state after spend', () => {
  const original = zswapState;
  const [updated, input] = original.spend(secretKeys, coin, segment);

  // New instance
  expect(updated).not.toBe(original);
  // Spend is now pending
  expect(updated.pendingSpends.size).toBe(original.pendingSpends.size + 1);
  // Original unchanged
  expect(original.coins.size).toBe(initialCoinCount);
});
```

### Testing apply()

`apply(secretKeys, offer)` ingests an offer, confirming received outputs into
`coins` and clearing matching pending entries.

```typescript
it('should confirm coins after apply', () => {
  const applied = zswapState.apply(secretKeys, offer);

  expect(applied.coins.size).toBeGreaterThanOrEqual(zswapState.coins.size);
});
```

### Testing applyFailed()

`applyFailed(offer)` locally reverts pending outputs/spends from an offer known
to have failed.

```typescript
it('should remove pending entries after failure', () => {
  const withPending = zswapState.apply(secretKeys, offer);
  const failed = withPending.applyFailed(offer);

  expect(failed.pendingOutputs.size).toBe(0);
});
```

### Testing revertTransaction()

`revertTransaction(transaction)` clears all pending outputs/spends from a
transaction that has been discarded.

```typescript
it('should revert pending entries from a discarded transaction', () => {
  const reverted = zswapState.revertTransaction(transaction);

  expect(reverted.pendingSpends.size).toBe(0);
});
```

### Testing replayEvents()

`replayEvents(secretKeys, events)` rebuilds state from a sequence of events.
Use it to verify that a reconstructed state matches a state built incrementally.

```typescript
it('should rebuild state from events', () => {
  const events = collectEvents(transactions);
  const replayed = new ZswapLocalState().replayEvents(secretKeys, events);

  expect(replayed.coins.size).toBe(expectedState.coins.size);
});
```

### Testing watchFor()

`watchFor(coinPublicKey, coin)` registers a coin to receive before it is
confirmed on-chain.

```typescript
it('should track watched coin after apply', () => {
  const watching = zswapState.watchFor(coinPublicKey, coinToWatch);
  const applied = watching.apply(secretKeys, offerContainingCoin);

  expect(applied.coins.size).toBeGreaterThan(zswapState.coins.size);
});
```

### Testing clearPending()

`clearPending(time)` clears pending outputs/spends that have passed their TTL
at the given time.

```typescript
it('should clear pending entries past their TTL', () => {
  const afterTtl = new Date('2026-12-31T23:59:59Z');
  const cleared = zswapState.clearPending(afterTtl);

  expect(cleared.pendingOutputs.size).toBeLessThanOrEqual(
    zswapState.pendingOutputs.size,
  );
});
```

---

## DustLocalState Patterns

Construct with `new DustLocalState(params)` (a `DustParameters`). Spend and
balance methods take secret keys / a `Date`, and methods return new instances.

### Time Control

`walletBalance(time)` takes a `Date` and returns a `bigint` (the spendable Dust
balance at that instant). Dust balances change as generation accrues and TTLs
expire. Always use a fixed date in tests.

```typescript
it('should calculate time-dependent balance', () => {
  // GOOD: Fixed time for deterministic results
  const fixedTime = new Date('2026-01-01T00:00:00Z');
  const balance = dustState.walletBalance(fixedTime); // bigint

  expect(balance).toBe(expectedBalance);
});

// BAD: Non-deterministic — result changes as real time passes
// const balance = dustState.walletBalance(new Date());
```

### Testing Different Times

```typescript
it('should reflect accrued generation over time', () => {
  const earlier = new Date('2026-01-01T00:00:00Z');
  const later = new Date('2026-06-01T00:00:00Z');

  const balanceEarlier = dustState.walletBalance(earlier);
  const balanceLater = dustState.walletBalance(later);

  // Generation accrues over time
  expect(balanceLater).toBeGreaterThanOrEqual(balanceEarlier);
});
```

### Testing spend()

`spend(sk, utxo, vFee, ctime)` returns the tuple `[DustLocalState, DustSpend]`.

```typescript
it('should return new state after Dust spend', () => {
  const original = dustState;
  const ctime = new Date('2026-01-01T00:00:00Z');
  const [updated, dustSpend] = original.spend(dustSecretKey, qdo, vFee, ctime);

  expect(updated).not.toBe(original);
  // Spent Dust reduces the spendable balance
  expect(updated.walletBalance(ctime)).toBeLessThan(
    original.walletBalance(ctime),
  );
});
```

### Testing processTtls()

`processTtls(time)` returns a new `DustLocalState` with Dust whose TTL has
passed at the given time removed.

```typescript
it('should return a new state after processTtls', () => {
  const expiredTime = new Date('2026-12-31T23:59:59Z');
  const processed = dustState.processTtls(expiredTime);

  expect(processed).not.toBe(dustState);
});
```

### Testing replayEvents()

`replayEvents(sk, events)` rebuilds Dust state from a sequence of events.

```typescript
it('should rebuild Dust state from events', () => {
  const events = collectDustEvents(dustTransactions);
  const replayed = new DustLocalState(params).replayEvents(dustSecretKey, events);
  const fixedTime = new Date('2026-01-01T00:00:00Z');

  expect(replayed.walletBalance(fixedTime))
    .toBe(expectedState.walletBalance(fixedTime));
});
```

### Testing generationInfo()

`generationInfo(qdo)` returns a `DustGenerationInfo | undefined` with fields
`{ value, owner, nonce, dtime }`.

```typescript
it('should return generation info for Dust', () => {
  const info = dustState.generationInfo(qdo);

  expect(info).toBeDefined();
  expect(info!.value).toBeGreaterThan(0n);
});
```

---

## Serialization Round-Trips

Serialization tests verify that ledger state can be persisted and restored
without loss. Test all state types your code persists.

### ZswapLocalState Round-Trip

```typescript
it('should survive serialize/deserialize', () => {
  const serialized = zswapState.serialize();
  const restored = ZswapLocalState.deserialize(serialized);

  expect(restored.coins.size).toBe(zswapState.coins.size);
  expect(restored.pendingSpends.size).toBe(zswapState.pendingSpends.size);
});
```

### DustLocalState Round-Trip

```typescript
it('should survive serialize/deserialize', () => {
  const serialized = dustState.serialize();
  const restored = DustLocalState.deserialize(serialized);
  const fixedTime = new Date('2026-01-01T00:00:00Z');

  expect(restored.walletBalance(fixedTime))
    .toBe(dustState.walletBalance(fixedTime));
});
```

### Round-Trip After Mutations

Test that serialization works correctly after mutations, not just on the
initial state.

```typescript
it('should round-trip state after mutations', () => {
  const mutated = zswapState
    .watchFor(coinPublicKey, newCoin)
    .apply(secretKeys, offer);

  const serialized = mutated.serialize();
  const restored = ZswapLocalState.deserialize(serialized);

  expect(restored.coins.size).toBe(mutated.coins.size);
});
```

---

## LedgerState.apply() — On-Chain State Testing

`LedgerState.apply(verifiedTransaction, context)` applies a transaction to the
on-chain ledger state. It takes a `VerifiedTransaction` (produced by
`wellFormed()`) and a `TransactionContext`, and RETURNS the tuple
`[LedgerState, TransactionResult]` — it does not throw on a malformed-but-
verified transaction; instead the `TransactionResult.type` reports
`'success' | 'partialSuccess' | 'failure'`. Build a blank state with
`LedgerState.blank(networkId)` (there is no `genesis()`), and read per-contract
state with `index(address): ContractState | undefined` (there is no
`contractState(...)`).

```typescript
import { LedgerState, TransactionContext, BlockContext } from '@midnight-ntwrk/ledger-v8';

it('should update on-chain state after applying transaction', () => {
  const initialState = LedgerState.blank(networkId);
  const context = new TransactionContext(initialState, blockContext);

  const [nextState, result] = initialState.apply(verifiedTransaction, context);

  expect(result.type).toBe('success');
  expect(nextState).not.toBe(initialState);
  // Read the contract state with index(address)
  expect(nextState.index(contractAddress)).toBeDefined();
});

it('should report failure for a transaction that cannot be applied', () => {
  const initialState = LedgerState.blank(networkId);
  const context = new TransactionContext(initialState, blockContext);

  const [, result] = initialState.apply(verifiedBadTransaction, context);

  // apply() does not throw; inspect the TransactionResult.type instead
  expect(result.type).not.toBe('success');
});
```

### Inspecting Zswap Commitments / Nullifiers

Coin commitments and nullifiers live in the Zswap portion of the ledger state
(`ledgerState.zswap`, a `ZswapChainState`) rather than directly on
`LedgerState`. Use `coinCommitment()` / `coinNullifier()` to derive the values
you expect, then compare against the Zswap chain state your code observes
(e.g. via `firstFree` growth or by replaying events into a `ZswapLocalState`).

```typescript
it('should advance the Zswap commitment tree after a deposit', () => {
  const context = new TransactionContext(ledgerState, blockContext);
  const [withDeposit] = ledgerState.apply(verifiedDepositTransaction, context);

  // A new output advances the first-free index of the commitment tree
  expect(withDeposit.zswap.firstFree).toBeGreaterThan(ledgerState.zswap.firstFree);
});
```
