---
name: ledger-testing
description: >-
  This skill should be used when the user asks to write ledger tests, test
  transaction construction, test proof staging, test ZswapLocalState, test
  DustLocalState, test cost model, test coinCommitment, test ledger-v8,
  test onchain-runtime, or test well-formedness. Also triggered by requests
  to write tests for code that uses @midnight-ntwrk/ledger-v8 or
  @midnight-ntwrk/onchain-runtime directly, test proof staging lifecycle,
  test token type functions, test crypto fixtures, or test serialization
  round-trips for ledger types.
version: 0.1.0
---

# Ledger Testing

Write tests for code that uses `@midnight-ntwrk/ledger-v8` and
`@midnight-ntwrk/onchain-runtime` directly.

## When to Use This Skill

| Question | Skill |
|----------|-------|
| Am I testing code that calls ledger-v8 or onchain-runtime APIs? | **ledger-testing** (this skill) |
| Am I testing Compact contract logic? | `compact-testing` |
| Am I building a custom wallet variant or capability? | `wallet-testing` |
| Am I integrating with the wallet via the DApp Connector API? | `dapp-connector-testing` |
| Am I testing DApp UI flows? | `dapp-testing` |

## What This Skill Covers

You are testing code that uses the ledger packages directly:

- Constructing transactions (building Intents, adding contract calls, signing, proving, binding)
- Managing proof staging (UnprovenTransaction → proved → proof-erased)
- Working with ZswapLocalState (spend, apply, revert, replayEvents, watchFor)
- Working with DustLocalState (time-dependent balances, replayEvents, processTtls)
- Using CostModel for fee estimation
- Calling cryptographic functions (coinCommitment, coinNullifier, persistentHash, etc.)
- Serializing/deserializing ledger types for persistence
- Building and validating well-formed transactions

## What This Skill Does NOT Cover

- Testing Compact contract logic (use `compact-testing`)
- Testing DApp UI flows end-to-end (use `dapp-testing`)
- Testing wallet SDK implementations (use `wallet-testing`)
- Testing DApp Connector API integration (use `dapp-connector-testing`)

## The Core Testing Challenges

### 1. Proof Staging Type Parameters

`Transaction<S, P, B>` has three type parameters controlling what stage the
transaction is in. Tests need to construct transactions at the right stage and
transition them through the pipeline in order.

```typescript
import {
  UnprovenTransaction,
  WellFormedStrictness,
} from '@midnight-ntwrk/ledger-v8';

// Stage 1 — Unproven: Transaction<SignatureEnabled, PreProof, PreBinding>
const unproven: UnprovenTransaction = buildUnprovenTransaction();

// Stage 2 — Proved: Transaction<SignatureEnabled, Proof, PreBinding>
const proved = await unproven.prove(provingParams);

// Stage 3 — Bound: Transaction<SignatureEnabled, Proof, FiatShamirPedersen>
const bound = proved.bind(bindingParams);

// Stage 4 — Erased proofs (for storage)
const erased = bound.eraseProofs();
```

Each stage has different methods available. TypeScript enforces the transitions —
calling `bind()` on an unproven transaction is a compile error.

See `references/transaction-construction-patterns.md` for complete lifecycle examples.

### 2. Hex String Types

Many types (CoinPublicKey, ContractAddress, TokenType, Nullifier, etc.) are
hex-encoded strings with specific lengths and encoding rules. Arbitrary strings
will fail validation at runtime.

```typescript
import {
  sampleCoinPublicKey,
  sampleContractAddress,
  sampleRawTokenType,
} from '@midnight-ntwrk/ledger-v8';

// GOOD: Use sample functions for valid test fixtures
const pk = sampleCoinPublicKey();         // Valid 64-char hex
const addr = sampleContractAddress();     // Valid contract address hex
const rawType = sampleRawTokenType();     // Valid raw token type

// BAD: Arbitrary strings will fail validation
const pk = '0xdeadbeef';          // Wrong length, wrong format
const addr = 'test-contract';     // Not a valid hex string
```

See `references/crypto-fixture-patterns.md` for all `sample*` functions and
encode/decode patterns.

### 3. State Immutability

`ZswapLocalState` and `DustLocalState` return new instances on every mutation.
The original is unchanged. Tests that assert on the original after calling
`spend()`, `apply()`, or `revertTransaction()` will always pass — even if the
operation is broken.

```typescript
it('should remove coin after spend', () => {
  const original = zswapState;
  const updated = original.spend(coinInfo);

  // GOOD: Assert on the returned state
  expect(updated.coins.length).toBe(original.coins.length - 1);

  // BAD: Asserting on original — this always passes, proves nothing
  // expect(original.coins.length).toBe(original.coins.length);
});
```

See `references/ledger-state-patterns.md` for complete state mutation patterns.

### 4. Time-Dependent Dust

`DustLocalState.walletBalance()` takes a `Date` parameter. Dust balances
change over time as TTLs expire. Tests that use `new Date()` or `Date.now()`
are non-deterministic.

```typescript
it('should calculate balance at fixed time', () => {
  // GOOD: Fixed time for deterministic results
  const fixedTime = new Date('2026-01-01T00:00:00Z');
  const balance = dustState.walletBalance(fixedTime);
  expect(balance).toBeDefined();
  expect(balance.available).toBe(expectedAmount);
});

// BAD: Non-deterministic — result changes as real time passes
// const balance = dustState.walletBalance(new Date());
```

See `references/ledger-state-patterns.md` for time control patterns and TTL
testing.

### 5. Cost Model Assertions

`SyntheticCost` has 5 dimensions: `read_time`, `compute_time`, `block_usage`,
`bytes_written`, and `bytes_churned`. Asserting only that `cost` is defined
proves nothing about the fee structure.

```typescript
import { CostModel } from '@midnight-ntwrk/ledger-v8';

it('should calculate cost with expected dimensions', () => {
  const cost = CostModel.calculate(transaction);

  // GOOD: Assert specific dimensions
  expect(cost.block_usage).toBeGreaterThan(0n);
  expect(cost.bytes_written).toBeGreaterThanOrEqual(0n);
  expect(cost.compute_time).toBeGreaterThan(0n);

  // BAD: Proves nothing
  // expect(cost).toBeDefined();
});
```

See `references/transaction-construction-patterns.md` for cost model patterns.

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Fix |
|---|---|---|
| Arbitrary strings for hex types | Fails validation at runtime; wrong length or encoding | Use `sample*` functions (sampleCoinPublicKey, sampleContractAddress, etc.) |
| Asserting on original state after mutation | Returns always pass; the original is immutable and never changes | Assert on the value returned by spend()/apply()/revertTransaction() |
| Using `new Date()` in Dust balance tests | Non-deterministic; test results change as real time passes | Pass a fixed `new Date('...')` to walletBalance() |
| Asserting only that cost is non-zero | Proves nothing about SyntheticCost dimensions | Assert specific dimension values (block_usage, bytes_written, etc.) |
| Skipping proof staging transitions | Tests bypass type safety; miss stage-dependent bugs | Test each transition: Unproven → prove() → bind() → eraseProofs() |
| Not testing well-formedness rejection | Only happy-path testing; misses constraint violations | Build invalid transactions and assert wellFormed() returns false |
| Sharing state instances across tests | State bleeds between tests; order-dependent failures | Construct fresh state objects in beforeEach |

## Reference Files

| Topic | Reference |
|-------|-----------|
| Proof staging lifecycle, Intent construction, well-formedness, transaction merging, fee calculation | `references/transaction-construction-patterns.md` |
| ZswapLocalState, DustLocalState, time control, serialization, LedgerState.apply() | `references/ledger-state-patterns.md` |
| sample* functions, coinCommitment/coinNullifier, token types, encode/decode, signData/verifySignature | `references/crypto-fixture-patterns.md` |
