# Transaction Construction Patterns

Patterns for constructing and testing transactions using
`@midnight-ntwrk/ledger-v8`.

## Proof Staging Lifecycle

A transaction moves through four stages, each enforced by TypeScript type
parameters `Transaction<S, P, B>`:

| Stage | Type | How to reach it |
|-------|------|-----------------|
| Unproven | `Transaction<SignatureEnabled, PreProof, PreBinding>` | Build via Intent |
| Proved | `Transaction<SignatureEnabled, Proof, PreBinding>` | Call `unproven.prove(params)` |
| Bound | `Transaction<SignatureEnabled, Proof, FiatShamirPedersen>` | Call `proved.bind(params)` |
| Proof-erased | `Transaction<SignatureEnabled, NoProof, FiatShamirPedersen>` | Call `bound.eraseProofs()` |

TypeScript enforces valid transitions — calling methods from the wrong stage
produces a compile error.

### Creating an UnprovenTransaction

```typescript
import {
  Intent,
  UnprovenTransaction,
  sampleContractAddress,
} from '@midnight-ntwrk/ledger-v8';

const contractAddress = sampleContractAddress();
const intent = Intent.empty()
  .addCall(contractAddress, entrypoint, circuitOutput);

const unproven: UnprovenTransaction = intent.toUnprovenTransaction(
  signingKey,
  networkId,
  ttl,
);
```

### Transitioning to Proved

```typescript
it('should transition from unproven to proved', async () => {
  const proved = await unproven.prove(provingParams);

  // proved has type Transaction<SignatureEnabled, Proof, PreBinding>
  expect(proved).toBeDefined();

  // Type safety — these would be compile errors:
  // unproven.bind(params);    // Error: unproven can't be bound
  // proved.prove(params);     // Error: already proved
});
```

### Transitioning to Bound

```typescript
it('should bind the proved transaction', () => {
  const bound = proved.bind(bindingParams);

  // bound has type Transaction<SignatureEnabled, Proof, FiatShamirPedersen>
  expect(bound).toBeDefined();
});
```

### Erasing Proofs for Storage

```typescript
it('should erase proofs for storage', () => {
  const erased = bound.eraseProofs();

  // erased has type Transaction<SignatureEnabled, NoProof, FiatShamirPedersen>
  // Proof data is removed — suitable for persisting without ZK proof bytes
  expect(erased).toBeDefined();
});
```

### Testing the Full Pipeline

```typescript
it('should complete full proof staging pipeline', async () => {
  const intent = Intent.empty().addCall(addr, entrypoint, output);
  const unproven = intent.toUnprovenTransaction(signingKey, networkId, ttl);
  const proved = await unproven.prove(provingParams);
  const bound = proved.bind(bindingParams);
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

An Intent collects contract calls and deployments before building a transaction.

### Adding a Contract Call

```typescript
import { Intent, sampleContractAddress } from '@midnight-ntwrk/ledger-v8';

const addr = sampleContractAddress();
const intent = Intent.empty().addCall(
  addr,        // ContractAddress
  entrypoint,  // string — the contract entrypoint name
  output,      // CircuitOutput — the compiled circuit output
);
```

### Adding a Contract Deployment

```typescript
const deployIntent = Intent.empty().addDeploy(
  contractDefinition,  // ContractDefinition
  initialState,        // InitialContractState
);
```

### Merging Intents

Multiple intents can be merged into a single transaction. The result contains
all calls and deployments from both intents.

```typescript
it('should merge two intents', () => {
  const intentA = Intent.empty().addCall(addrA, entrypointA, outputA);
  const intentB = Intent.empty().addCall(addrB, entrypointB, outputB);
  const merged = intentA.merge(intentB);

  expect(merged.calls.length).toBe(2);
});
```

---

## Testing Well-Formedness

`wellFormed()` checks that a transaction satisfies all ledger constraints
(disjoint inputs/outputs, balanced token flows, valid TTL, etc.).

```typescript
import { WellFormedStrictness } from '@midnight-ntwrk/ledger-v8';

it('should be well-formed', () => {
  const result = transaction.wellFormed(WellFormedStrictness.default());
  expect(result).toBe(true);
});
```

### Negative Well-Formedness Testing

Testing that invalid transactions are rejected is as important as testing
valid ones. Build transactions that violate constraints deliberately.

```typescript
it('should reject transaction with overlapping inputs', () => {
  // Build a transaction that uses the same coin as both input and output
  const invalidTransaction = buildTransactionWithOverlappingInputs();
  const result = invalidTransaction.wellFormed(WellFormedStrictness.default());
  expect(result).toBe(false);
});

it('should reject transaction with imbalanced tokens', () => {
  // Build a transaction where token inputs do not equal outputs
  const unbalanced = buildUnbalancedTransaction();
  const result = unbalanced.wellFormed(WellFormedStrictness.default());
  expect(result).toBe(false);
});
```

---

## Transaction Merging

Transactions (not just intents) can be merged into a single transaction that
contains all segments from both.

```typescript
it('should merge two transactions', () => {
  const txA = buildUnprovenTransaction(intentA);
  const txB = buildUnprovenTransaction(intentB);
  const merged = txA.merge(txB);

  expect(merged.wellFormed(WellFormedStrictness.default())).toBe(true);
});
```

---

## Fee Calculation via CostModel

`SyntheticCost` has 5 dimensions. Test each dimension that your code is
expected to control — not just that cost is non-zero.

```typescript
import { CostModel } from '@midnight-ntwrk/ledger-v8';

it('should have expected cost dimensions', () => {
  const cost = CostModel.calculate(transaction);

  // Assert specific dimensions
  expect(cost.block_usage).toBeGreaterThan(0n);
  expect(cost.compute_time).toBeGreaterThan(0n);
  expect(cost.bytes_written).toBeGreaterThanOrEqual(0n);
  expect(cost.bytes_churned).toBeGreaterThanOrEqual(0n);
  expect(cost.read_time).toBeGreaterThanOrEqual(0n);
});

it('should stay within block usage limit', () => {
  const cost = CostModel.calculate(transaction);
  const BLOCK_LIMIT = 200_000n;
  expect(cost.block_usage).toBeLessThanOrEqual(BLOCK_LIMIT);
});
```

### Fee Formula

The total fee is calculated as:

```
fee = max(read_time, compute_time, block_usage) + bytes_written + bytes_churned
```

```typescript
it('should calculate fee correctly', () => {
  const cost = CostModel.calculate(transaction);
  const expectedFee =
    BigInt(Math.max(
      Number(cost.read_time),
      Number(cost.compute_time),
      Number(cost.block_usage),
    )) + cost.bytes_written + cost.bytes_churned;

  expect(CostModel.fee(cost)).toBe(expectedFee);
});
```
