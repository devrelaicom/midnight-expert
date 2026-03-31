# Observable Testing Patterns for Wallet SDK

How to test RxJS Observable state exposed by the wallet facade in Vitest tests.

## Subscribing and Waiting for State

Use `firstValueFrom` with `filter` to wait for a specific state condition:

```typescript
import { firstValueFrom, filter } from 'rxjs';

it('should reach synced state', async () => {
  const syncedState = await firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.shielded.progress.isCompleteWithin() &&
                    s.unshielded.progress.isCompleteWithin() &&
                    s.dust.progress.isCompleteWithin())
    )
  );
  expect(syncedState.shielded.availableBalances).toBeDefined();
}, 30_000); // timeout for slow sync
```

`firstValueFrom` auto-completes the subscription after the first matching
emission — no manual cleanup needed.

## Asserting on FacadeState Shape

The `FacadeState` combines state from all three wallets:

```typescript
it('should expose shielded balances', async () => {
  const state = await firstValueFrom(wallet.state());
  // Shielded balances are a Record<TokenType, bigint>
  expect(state.shielded.availableBalances).toBeDefined();
  expect(state.shielded.pendingBalances).toBeDefined();
});

it('should expose unshielded balances', async () => {
  const state = await firstValueFrom(wallet.state());
  expect(state.unshielded.availableUtxos).toBeDefined();
});

it('should expose dust balance', async () => {
  const state = await firstValueFrom(wallet.state());
  // Dust balance is time-dependent
  expect(state.dust.balance).toBeDefined();
});
```

## Testing State Transitions

To observe a state change after an action, subscribe before acting:

```typescript
it('should transition to pending after submit', async () => {
  // Set up the expectation before acting
  const pendingState = firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.pendingTransactions.length > 0)
    )
  );

  // Act
  await wallet.submitTransaction(tx);

  // Assert
  const state = await pendingState;
  expect(state.pendingTransactions.length).toBe(1);
});
```

## Manual Subscription Cleanup

When you need multiple emissions (not just the first match), subscribe
manually and clean up:

```typescript
import { Subscription } from 'rxjs';

let subscription: Subscription;

afterEach(() => {
  subscription?.unsubscribe();
});

it('should emit multiple state updates', async () => {
  const states: FacadeState[] = [];

  await new Promise<void>((resolve) => {
    subscription = wallet.state().subscribe((s) => {
      states.push(s);
      if (states.length >= 3) resolve();
    });
  });

  expect(states.length).toBeGreaterThanOrEqual(3);
});
```

Always unsubscribe in `afterEach` to prevent:
- Test hangs (subscription keeps the event loop alive)
- State bleed (emissions from one test leak into the next)
- Memory leaks (subscriptions accumulate across tests)

## Timeout Handling

Wallet operations (sync, proving, submission) can be slow. Use Vitest's
per-test timeout:

```typescript
it('should sync within 30 seconds', async () => {
  const synced = await firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.shielded.progress.isCompleteWithin())
    )
  );
  expect(synced).toBeDefined();
}, 30_000);
```
