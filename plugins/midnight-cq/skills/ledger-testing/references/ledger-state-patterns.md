# Ledger State Patterns

Patterns for testing `ZswapLocalState`, `DustLocalState`, and `LedgerState`
from `@midnight-ntwrk/ledger-v8`.

## Key Principle: State Is Immutable

Both `ZswapLocalState` and `DustLocalState` return new instances on every
mutation. The original object is never modified. Tests that assert on the
original after calling a mutation method will always pass — even if the method
is broken.

```typescript
// GOOD: Assert on the returned value
const updated = original.spend(coinInfo);
expect(updated.coins.length).toBe(original.coins.length - 1);

// BAD: Original is unchanged — this assertion proves nothing
// const updated = original.spend(coinInfo);
// expect(original.coins.length).toBe(original.coins.length - 1);
```

---

## ZswapLocalState Patterns

### Testing spend()

```typescript
import { ZswapLocalState } from '@midnight-ntwrk/ledger-v8';

it('should return new state after spend', () => {
  const original = zswapState;
  const updated = original.spend(coinInfo);

  // New instance
  expect(updated).not.toBe(original);
  // Coin removed
  expect(updated.coins.length).toBe(original.coins.length - 1);
  // Original unchanged
  expect(original.coins.length).toBe(initialCoinCount);
});
```

### Testing apply()

`apply()` transitions pending coins (from a submitted transaction) to confirmed.

```typescript
it('should confirm pending coins after apply', () => {
  const withPending = zswapState.addPending(transaction);
  const applied = withPending.apply(transaction);

  expect(applied.pendingCoins.length).toBe(0);
  expect(applied.coins.length).toBeGreaterThan(withPending.coins.length);
});
```

### Testing applyFailed()

`applyFailed()` removes pending coins for a failed transaction.

```typescript
it('should remove pending coins after failure', () => {
  const withPending = zswapState.addPending(transaction);
  const failed = withPending.applyFailed(transaction);

  expect(failed.pendingCoins.length).toBe(0);
  expect(failed.coins.length).toBe(zswapState.coins.length);
});
```

### Testing revertTransaction()

```typescript
it('should revert applied transaction', () => {
  const applied = zswapState.apply(transaction);
  const reverted = applied.revertTransaction(transaction);

  expect(reverted.coins.length).toBe(zswapState.coins.length);
});
```

### Testing replayEvents()

`replayEvents()` rebuilds state from a sequence of events. Use it to verify
that a reconstructed state matches a state built incrementally.

```typescript
it('should rebuild state from events', () => {
  const events = collectEvents(transactions);
  const replayed = ZswapLocalState.empty().replayEvents(events);

  expect(replayed.coins.length).toBe(expectedState.coins.length);
});
```

### Testing watchFor()

`watchFor()` registers a coin for monitoring before it is confirmed on-chain.

```typescript
it('should track watched coin after apply', () => {
  const watching = zswapState.watchFor(coinToWatch);
  const applied = watching.apply(transactionContainingCoin);

  expect(applied.coins).toContainEqual(
    expect.objectContaining({ commitment: coinToWatch.commitment })
  );
});
```

### Testing clearPending()

```typescript
it('should clear all pending coins', () => {
  const withPending = zswapState.addPending(transaction);
  const cleared = withPending.clearPending();

  expect(cleared.pendingCoins.length).toBe(0);
});
```

---

## DustLocalState Patterns

### Time Control

`walletBalance()` takes a `Date` parameter. Dust balances change as TTLs
expire. Always use a fixed date in tests.

```typescript
it('should calculate time-dependent balance', () => {
  // GOOD: Fixed time for deterministic results
  const fixedTime = new Date('2026-01-01T00:00:00Z');
  const balance = dustState.walletBalance(fixedTime);

  expect(balance.available).toBe(expectedAvailable);
  expect(balance.locked).toBe(expectedLocked);
});

// BAD: Non-deterministic — result changes as real time passes
// const balance = dustState.walletBalance(new Date());
```

### Testing Different Times

```typescript
it('should expire TTL-locked Dust after deadline', () => {
  const beforeExpiry = new Date('2026-01-01T00:00:00Z');
  const afterExpiry = new Date('2026-12-31T23:59:59Z');

  const balanceBefore = dustState.walletBalance(beforeExpiry);
  const balanceAfter = dustState.walletBalance(afterExpiry);

  // After TTL, locked becomes available
  expect(balanceAfter.available).toBeGreaterThan(balanceBefore.available);
});
```

### Testing spend()

```typescript
it('should return new state after Dust spend', () => {
  const original = dustState;
  const updated = original.spend(dustCoin);

  expect(updated).not.toBe(original);
  // Spent Dust should no longer appear in available balance
  const balance = updated.walletBalance(new Date('2026-01-01T00:00:00Z'));
  expect(balance.available).toBeLessThan(
    original.walletBalance(new Date('2026-01-01T00:00:00Z')).available
  );
});
```

### Testing processTtls()

`processTtls()` removes Dust entries whose TTL has passed at the given time.

```typescript
it('should remove expired Dust after processTtls', () => {
  const expiredTime = new Date('2026-12-31T23:59:59Z');
  const processed = dustState.processTtls(expiredTime);

  // Expired entries removed
  expect(processed.entries.length).toBeLessThanOrEqual(dustState.entries.length);
});
```

### Testing replayEvents()

```typescript
it('should rebuild Dust state from events', () => {
  const events = collectDustEvents(dustTransactions);
  const replayed = DustLocalState.empty().replayEvents(events);
  const fixedTime = new Date('2026-01-01T00:00:00Z');

  expect(replayed.walletBalance(fixedTime).available)
    .toBe(expectedState.walletBalance(fixedTime).available);
});
```

### Testing generationInfo()

```typescript
it('should return generation info for Dust', () => {
  const info = dustState.generationInfo(dustCoin);

  expect(info).toBeDefined();
  expect(info.ttl).toBeGreaterThan(0n);
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

  expect(restored.coins.length).toBe(zswapState.coins.length);
  expect(restored.pendingCoins.length).toBe(zswapState.pendingCoins.length);
});
```

### DustLocalState Round-Trip

```typescript
it('should survive serialize/deserialize', () => {
  const serialized = dustState.serialize();
  const restored = DustLocalState.deserialize(serialized);
  const fixedTime = new Date('2026-01-01T00:00:00Z');

  expect(restored.walletBalance(fixedTime).available)
    .toBe(dustState.walletBalance(fixedTime).available);
});
```

### Round-Trip After Mutations

Test that serialization works correctly after mutations, not just on the
initial state.

```typescript
it('should round-trip state after mutations', () => {
  const mutated = zswapState
    .watchFor(newCoin)
    .apply(transaction);

  const serialized = mutated.serialize();
  const restored = ZswapLocalState.deserialize(serialized);

  expect(restored.coins.length).toBe(mutated.coins.length);
});
```

---

## LedgerState.apply() — On-Chain State Testing

`LedgerState.apply()` applies a transaction to the on-chain ledger state.
Use it to test that your transactions produce the expected on-chain effects.

```typescript
import { LedgerState } from '@midnight-ntwrk/ledger-v8';

it('should update on-chain state after applying transaction', () => {
  const initialState = LedgerState.genesis();
  const nextState = initialState.apply(transaction);

  expect(nextState).not.toBe(initialState);
  // Check that the contract state was updated
  expect(nextState.contractState(contractAddress)).toBeDefined();
});

it('should reject invalid transaction', () => {
  const initialState = LedgerState.genesis();

  // apply() throws or returns null for invalid transactions
  expect(() => {
    initialState.apply(invalidTransaction);
  }).toThrow();
});
```

### Testing Coin Lifecycle via LedgerState

```typescript
it('should track coin from pending to confirmed to spent', () => {
  const withDeposit = ledgerState.apply(depositTransaction);

  // Coin is now confirmed on-chain
  const commitment = coinCommitment(coin, pk);
  expect(withDeposit.hasCommitment(commitment)).toBe(true);

  // After spend, nullifier is recorded
  const withSpend = withDeposit.apply(spendTransaction);
  const nullifier = coinNullifier(coin, sk);
  expect(withSpend.hasNullifier(nullifier)).toBe(true);
});
```
