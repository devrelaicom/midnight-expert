# Balance monitoring

`wallet.state()` returns an `Observable<FacadeState>`. Every state
change emits a new value.

## Reading balances safely

Do not read balances before the wallet is synced. `FacadeState.isSynced`
is true only when all three sub-wallets report strictly complete sync.

```typescript
import * as ledger from '@midnight-ntwrk/ledger-v8';
import { Subscription } from 'rxjs';

const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;

const sub: Subscription = wallet.state().subscribe((state) => {
  if (!state.isSynced) return;
  console.log('NIGHT:',  state.unshielded.balances[NIGHT_TOKEN_TYPE] ?? 0n);
  console.log('SHIELDED:', state.shielded.balances);
  console.log('DUST:',   state.dust.balance(new Date()));
});

// Clean up:
sub.unsubscribe();
await wallet.stop();
```

For one-shot patterns, prefer `wallet.waitForSyncedState()` which
returns a single `FacadeState` once synced.

## What to watch

| Field | Type | Notes |
|-------|------|-------|
| `state.isSynced` | `boolean` | Guard balance reads with this — until true, balances are incomplete |
| `state.unshielded.balances[ledger.nativeToken().raw]` | `bigint` | Native NIGHT balance. The key is the token's raw bytes (64 hex zeros), NOT `""` |
| `state.shielded.balances[<tokenId>]` | `bigint` | Per-token shielded balance |
| `state.dust.balance(new Date())` | `bigint` | DUST balance at the given time (DUST has expiry) |
| `state.unshielded.progress` | `SyncProgress` | For diagnostics when sync stalls |
| `state.shielded.progress` | `SyncProgress` | Same |
| `state.dust.progress` | `SyncProgress` | Same |

## Cleaning up

Always unsubscribe and call `wallet.stop()` when monitoring ends.
WebSocket connections leak otherwise.

## Runnable example

`examples/monitor-wallet.ts` — live ticker of NIGHT, SHIELDED, and DUST
on every state emission until SIGINT.

## See also

`wallet-sdk:references/state-and-balances.md` — full state API.
