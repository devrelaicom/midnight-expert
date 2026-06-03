# Transaction Construction Patterns

Patterns for constructing and testing transactions using
`@midnight-ntwrk/ledger-v8`.

## Proof Staging Lifecycle

A transaction moves through four stages, each enforced by TypeScript type
parameters `Transaction<S, P, B>`:

| Stage | Type | How to reach it |
|-------|------|-----------------|
| Unproven | `Transaction<SignatureEnabled, PreProof, PreBinding>` | `Transaction.fromParts(networkId, guaranteed?, fallible?, intent?)` |
| Proved | `Transaction<SignatureEnabled, Proof, PreBinding>` | Call `unproven.prove(provider, costModel)` |
| Bound | `Transaction<SignatureEnabled, Proof, Binding>` | Call `proved.bind()` |
| Proof-erased | `Transaction<SignatureEnabled, NoProof, NoBinding>` | Call `bound.eraseProofs()` |

TypeScript enforces valid transitions — calling methods from the wrong stage
produces a compile error.

### Creating an UnprovenTransaction

An `Intent` is created with `Intent.new(ttl)` and populated with
`ContractCallPrototype` / `ContractDeploy` values. The transaction is then
assembled with `Transaction.fromParts(...)`.

```typescript
import {
  Intent,
  Transaction,
  UnprovenTransaction,
} from '@midnight-ntwrk/ledger-v8';

const intent = Intent.new(ttl) // ttl: Date
  .addCall(contractCallPrototype); // ContractCallPrototype

// guaranteed/fallible Zswap offers are optional; intent is optional too
const unproven: UnprovenTransaction = Transaction.fromParts(
  networkId,        // string
  undefined,        // guaranteed offer (optional)
  undefined,        // fallible offer (optional)
  intent,           // UnprovenIntent (optional)
);
```

### Transitioning to Proved

```typescript
import { CostModel } from '@midnight-ntwrk/ledger-v8';

it('should transition from unproven to proved', async () => {
  // prove(provider: ProvingProvider, costModel: CostModel)
  const proved = await unproven.prove(provingProvider, CostModel.initialCostModel());

  // proved has type Transaction<SignatureEnabled, Proof, PreBinding>
  expect(proved).toBeDefined();

  // Type safety — these would be compile errors:
  // unproven.bind();    // Error: unproven can't be bound
  // proved.prove(...);  // Error: already proved
});
```

### Transitioning to Bound

```typescript
it('should bind the proved transaction', () => {
  // bind() takes no arguments and is irreversible
  const bound = proved.bind();

  // bound has type Transaction<SignatureEnabled, Proof, Binding>
  expect(bound).toBeDefined();
});
```

### Erasing Proofs for Storage

```typescript
it('should erase proofs for storage', () => {
  const erased = bound.eraseProofs();

  // erased has type Transaction<SignatureEnabled, NoProof, NoBinding>
  // Proof data is removed — suitable for persisting without ZK proof bytes
  expect(erased).toBeDefined();
});
```

### Testing the Full Pipeline

```typescript
it('should complete full proof staging pipeline', async () => {
  const intent = Intent.new(ttl).addCall(contractCallPrototype);
  const unproven = Transaction.fromParts(networkId, undefined, undefined, intent);
  const proved = await unproven.prove(provingProvider, CostModel.initialCostModel());
  const bound = proved.bind();
  const erased = bound.eraseProofs();

  // Each stage should be non-null
  expect(unproven).toBeDefined();
  expect(proved).toBeDefined();
  expect(bound).toBeDefined();
  expect(erased).toBeDefined();
});
```

---

## Building Intents

An Intent collects contract calls, deployments, and maintenance updates before
building a transaction. Create one with `Intent.new(ttl)` (a `Date`); each
`add*` method takes a single prototype object and returns a new Intent.

### Adding a Contract Call

```typescript
import { Intent } from '@midnight-ntwrk/ledger-v8';

// addCall(call: ContractCallPrototype) -> Intent<S, PreProof, PreBinding>
const intent = Intent.new(ttl).addCall(contractCallPrototype);
```

### Adding a Contract Deployment

```typescript
// addDeploy(deploy: ContractDeploy) -> Intent<S, PreProof, PreBinding>
const deployIntent = Intent.new(ttl).addDeploy(contractDeploy);
```

### Combining Calls and Deployments

A single Intent can accumulate multiple calls/deploys by chaining `add*`. To
combine entire transactions, use `Transaction.merge()` (see below) — `Intent`
itself does not expose a public `merge`.

```typescript
const intent = Intent.new(ttl)
  .addCall(callPrototypeA)
  .addCall(callPrototypeB);
```

---

## Testing Well-Formedness

`wellFormed(refState, strictness, tblock)` checks that a transaction satisfies
all ledger constraints (disjoint inputs/outputs, balanced token flows, valid
TTL, etc.). It takes a reference `LedgerState`, a `WellFormedStrictness`, and a
block time (`Date`). On success it RETURNS a `VerifiedTransaction`; on failure
it THROWS — it does not return a boolean. `WellFormedStrictness` is constructed
with `new WellFormedStrictness()` and configured via its mutable flags
(`enforceBalancing`, `verifyNativeProofs`, `verifyContractProofs`,
`enforceLimits`, `verifySignatures`).

```typescript
import { WellFormedStrictness } from '@midnight-ntwrk/ledger-v8';

it('should be well-formed', () => {
  const strictness = new WellFormedStrictness();
  strictness.enforceBalancing = true;

  // Returns a VerifiedTransaction (does not throw) for a valid transaction
  const verified = transaction.wellFormed(refState, strictness, blockTime);
  expect(verified).toBeDefined();
});
```

### Negative Well-Formedness Testing

Testing that invalid transactions are rejected is as important as testing
valid ones. Build transactions that violate constraints deliberately and assert
that `wellFormed()` THROWS.

```typescript
it('should reject transaction with overlapping inputs', () => {
  // Build a transaction that uses the same coin as both input and output
  const invalidTransaction = buildTransactionWithOverlappingInputs();
  const strictness = new WellFormedStrictness();
  expect(() => {
    invalidTransaction.wellFormed(refState, strictness, blockTime);
  }).toThrow();
});

it('should reject transaction with imbalanced tokens', () => {
  // Build a transaction where token inputs do not equal outputs
  const unbalanced = buildUnbalancedTransaction();
  const strictness = new WellFormedStrictness();
  strictness.enforceBalancing = true;
  expect(() => {
    unbalanced.wellFormed(refState, strictness, blockTime);
  }).toThrow();
});
```

---

## Transaction Merging

Transactions (not just intents) can be merged with `Transaction.merge(other)`,
producing a single transaction that contains all segments from both.

```typescript
it('should merge two transactions', () => {
  const txA = buildUnprovenTransaction(intentA);
  const txB = buildUnprovenTransaction(intentB);
  const merged = txA.merge(txB);

  // wellFormed returns a VerifiedTransaction (or throws); it is not a boolean
  const strictness = new WellFormedStrictness();
  expect(merged.wellFormed(refState, strictness, blockTime)).toBeDefined();
});
```

---

## Cost and Fee Calculation

A transaction's resource cost is computed by its own `cost(params)` method,
returning a `SyntheticCost` with 5 `bigint` dimensions: `readTime`,
`computeTime`, `blockUsage`, `bytesWritten`, `bytesChurned`. The fee in SPECKs
is `transaction.fees(params)` (accurate only for proven transactions);
`feesWithMargin(params, n)` applies an n-block safety margin. `LedgerParameters`
supplies the cost model — there is no `CostModel.calculate(...)` /
`CostModel.fee(...)` helper.

```typescript
import { LedgerParameters } from '@midnight-ntwrk/ledger-v8';

const params = LedgerParameters.initialParameters();

it('should have expected cost dimensions', () => {
  const cost = transaction.cost(params); // SyntheticCost

  // Assert specific dimensions (all bigint)
  expect(cost.blockUsage).toBeGreaterThan(0n);
  expect(cost.computeTime).toBeGreaterThan(0n);
  expect(cost.bytesWritten).toBeGreaterThanOrEqual(0n);
  expect(cost.bytesChurned).toBeGreaterThanOrEqual(0n);
  expect(cost.readTime).toBeGreaterThanOrEqual(0n);
});

it('should produce a non-zero fee for a proven transaction', () => {
  // fees() is only accurate when called on a proven transaction
  const fee = provenTransaction.fees(params); // bigint, in SPECKs
  expect(fee).toBeGreaterThan(0n);
});
```
