# DUST registration

DUST is the fee resource on Midnight. It is generated over time from
NIGHT UTXOs that have been REGISTERED for DUST generation. Without
registered NIGHT, a wallet cannot pay transaction fees.

## When to register

Immediately after the wallet receives its first NIGHT. The UTXOs only
start generating DUST once registered, so the sooner the better.

## How to register

```typescript
import * as ledger from '@midnight-ntwrk/ledger-v8';

const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;
const state = await wallet.waitForSyncedState();
const nightUtxos = state.unshielded.availableCoins;

if (nightUtxos.length === 0) {
  console.log('No NIGHT UTXOs to register. Fund the wallet first.');
  process.exit(0);
}

// Optional: preview fee + per-UTXO yield
const { fee, dustGenerationEstimations } = await wallet.estimateRegistration(nightUtxos);
console.log(`Estimated registration fee: ${fee}`);

// Register — note: registerNightUtxosForDustGeneration handles signing
// internally; no separate signRecipe call is required.
const finalizedTx = await wallet.registerNightUtxosForDustGeneration(nightUtxos);
const txId = await wallet.submitTransaction(finalizedTx);
console.log(`Registration tx: ${txId}`);

// Wait for DUST to accrue. It appears within seconds-to-minutes on
// devnet; the rate depends on registered NIGHT.
await new Promise((resolve) => setTimeout(resolve, 5000));
const dust = state.dust.balance(new Date());
console.log(`DUST balance: ${dust}`);
```

For the exact `registerNightUtxosForDustGeneration` signature, see
`wallet-sdk:references/transactions.md` and
`/tmp/midnight-wallet/packages/facade/src/index.ts` (during plugin
maintenance).

## Registration is self-funding — it works at a 0 DUST balance

Registration is the step that *starts* DUST generation, so when it runs the
wallet's DUST balance is still `0`. That is fine: **registration pays its own
fee from the DUST the registered NIGHT UTXOs generate** (the SDK builds the
`DustRegistration` with a `feePayment` equal to the coins' `generatedNow` DUST),
not from the wallet's existing DUST balance. So a freshly-funded wallet registers
successfully even with `0` accrued DUST — verified on a local devnet at 5, 100,
and 10,000 NIGHT, all succeeding.

Two consequences:

- A 138 (`BalanceCheckOverspend`) during registration is **not** a NIGHT
  funding-level problem — do **not** raise the NIGHT amount to fix one. Fees are
  denominated in DUST, not NIGHT.
- You do **not** need to set `additionalFeeOverhead` for registration. Setting it
  is also harmless (registration still self-funds), but `examples/register-dust.ts`
  leaves it off to keep the point clear. Add `additionalFeeOverhead` on wallets
  that submit **transfers or contract calls**, which on an idle devnet otherwise
  compute a zero fee and are rejected as NotNormalized (error **117** — see
  `/midnight-status-codes:lookup 117`).

## DUST has expiry

DUST tokens expire. `state.dust.balance(time)` requires a `Date`
argument because the result depends on which DUST has not yet expired
at the queried time.

## Runnable example

`examples/register-dust.ts` — registers all available NIGHT UTXOs of a
seed-derived wallet and prints the resulting DUST balance.
