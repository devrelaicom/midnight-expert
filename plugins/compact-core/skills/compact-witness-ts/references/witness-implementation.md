# Witness Implementation in TypeScript

Complete reference for implementing Compact witness functions in TypeScript. For Compact-side witness declarations and disclosure rules, see the `compact-structure` skill. For privacy patterns, see `compact-privacy-disclosure`.

## WitnessContext Interface

Every witness function receives a `WitnessContext` as its first parameter:

```typescript
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

interface WitnessContext<L = any, PS = any> {
  readonly ledger: L;              // Projected ledger state
  readonly privateState: PS;       // Current private state
  readonly contractAddress: string; // Address of the contract being called
}
```

| Field | Type | Description |
|-------|------|-------------|
| `ledger` | `L` (Ledger type) | The projected ledger state as it would look if the transaction ran against the current local view. Read-only. |
| `privateState` | `PS` (your type) | The current private state for this contract. Passed through and updated by witness return values. |
| `contractAddress` | `string` | The on-chain address of the contract being called. Useful for scoping private state per deployment. |

The type parameters are:
- `L` — The compiler-generated `Ledger` type matching your contract's ledger declarations
- `PS` — Your custom private state type

## Witness Return Tuple

Every witness function returns `[PS, ReturnValue]`:

```typescript
myWitness: (context: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => {
  return [context.privateState, someValue];
  //      ^^^^^^^^^^^^^^^^^     ^^^^^^^^^
  //      updated private       declared return
  //      state                 value from Compact
}
```

**Why return private state?** The runtime is functional — no hidden side effects. If a witness needs to update private state (e.g., store data), it returns the new state in the tuple. If no update is needed, return `privateState` unchanged.

## Private State Design

### Defining Private State Types

Private state is a plain TypeScript object type. Mark fields `readonly` to signal immutability:

```typescript
// Simple: one secret key
type MyPrivateState = {
  readonly secretKey: Uint8Array;
};

// Complex: multiple values
type GamePrivateState = {
  readonly secretKey: Uint8Array;
  readonly localGameplay: Record<string, string[]>;
};
```

### Factory Functions

Create a factory function for initialization:

```typescript
export const createMyPrivateState = (secretKey: Uint8Array): MyPrivateState => ({
  secretKey,
});
```

This is used when deploying or joining a contract to provide the initial private state.

### Contracts Without Private State

If your contract has no witnesses (e.g., pure counter), use an empty object:

```typescript
type CounterPrivateState = Record<string, never>;

export const witnesses = {};
```

## The Witnesses Object

The `witnesses` export is a plain object where:
- **Keys** must match Compact witness function names **exactly** (including casing)
- **Values** are functions following the `(WitnessContext, ...args) => [PS, ReturnType]` signature

```compact
// Compact declarations
witness local_secret_key(): Bytes<32>;
witness get_data(id: Bytes<32>): Maybe<UserRecord>;
```

```typescript
// TypeScript implementations — keys match Compact names exactly
export const witnesses = {
  local_secret_key: ({ privateState }: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => {
    return [privateState, privateState.secretKey];
  },

  get_data: (
    { privateState }: WitnessContext<Ledger, MyState>,
    id: Uint8Array,
  ): [MyState, { is_some: boolean; value: UserRecord }] => {
    const record = privateState.records.get(toHex(id));
    if (record) {
      return [privateState, { is_some: true, value: record }];
    }
    return [privateState, { is_some: false, value: defaultRecord }];
  },
};
```

## Common Witness Patterns

### Pattern 1: Secret Key Provider

The simplest and most common pattern. Returns a stored secret key without modifying state:

```compact
// Compact
witness local_secret_key(): Bytes<32>;
```

```typescript
// TypeScript
local_secret_key: ({
  privateState,
}: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => [
  privateState,
  privateState.secretKey,
],
```

Destructuring `{ privateState }` from the WitnessContext is idiomatic when you don't need `ledger` or `contractAddress`.

### Pattern 2: Parameterized Witness

Witnesses can receive additional parameters from the calling circuit. These appear after the WitnessContext parameter and match the Compact declaration:

```compact
// Compact
witness get_user_balance(userId: Bytes<32>): Uint<64>;
```

```typescript
// TypeScript — userId comes after WitnessContext
get_user_balance: (
  { privateState }: WitnessContext<Ledger, BankState>,
  userId: Uint8Array,
): [BankState, bigint] => {
  const userIdStr = new TextDecoder().decode(userId).replace(/\0/g, '');
  const balance = privateState.userBalances.get(userIdStr);
  if (!balance) {
    throw new Error(`User ${userIdStr} not found`);
  }
  return [privateState, balance];
},
```

### Pattern 3: State-Mutating Witness

When a witness needs to update private state, spread the existing state and override changed fields:

```compact
// Compact
witness store_gameplay(setup: Vector<10, Uint<64>>): Bytes<32>;
```

```typescript
// TypeScript — returns updated private state
store_gameplay: (
  { privateState, contractAddress }: WitnessContext<Ledger, GameState>,
  playerSetup: bigint[],
): [GameState, Uint8Array] => {
  const updatedGameplay = { ...privateState.localGameplay };
  updatedGameplay[contractAddress] = playerSetup.map(String);

  return [
    { ...privateState, localGameplay: updatedGameplay },
    computeSetupHash(playerSetup),
  ];
},
```

### Pattern 4: Ledger-Reading Witness

Access current ledger state to make decisions. The `ledger` field provides a read-only view:

```compact
// Compact
witness should_participate(): Boolean;
```

```typescript
// TypeScript — reads ledger state
should_participate: ({
  privateState,
  ledger,
}: WitnessContext<Ledger, MyState>): [MyState, boolean] => {
  // Check on-chain state to decide
  const currentRound = ledger.round;
  return [privateState, currentRound < 10n];
},
```

### Pattern 5: Contract-Address-Keyed State

Use `contractAddress` to scope private state per deployment, enabling one witness implementation to work across multiple contract instances:

```compact
// Compact
witness get_local_data(): Vector<5, Field>;
```

```typescript
// TypeScript — different data per contract deployment
get_local_data: ({
  privateState,
  contractAddress,
}: WitnessContext<Ledger, MultiContractState>): [MultiContractState, bigint[]] => {
  const data = privateState.perContract.get(contractAddress) ?? defaultData;
  return [privateState, data];
},
```

### Pattern 6: Side-Effect-Only Witness

Witnesses returning `[]` in Compact perform side effects only (store data locally):

```compact
// Compact
witness save_result(value: Field): [];
```

```typescript
// TypeScript — returns empty array for the "return value"
save_result: (
  { privateState }: WitnessContext<Ledger, MyState>,
  value: bigint,
): [MyState, []] => {
  return [
    { ...privateState, lastResult: value },
    [],
  ];
},
```

### Pattern 7: Multiple Secret Keys

Some contracts need multiple keys (e.g., identity systems with per-DID keys):

```compact
// Compact
witness local_secret_key(): Bytes<32>;
witness additional_keys(): Vector<5, Bytes<32>>;
```

```typescript
// TypeScript
type MultiKeyState = {
  readonly local_secret_key: Uint8Array;
  readonly multiple_local_secret_keys: Uint8Array[];
};

export const witnesses = {
  local_secret_key: ({
    privateState,
  }: WitnessContext<Ledger, MultiKeyState>): [MultiKeyState, Uint8Array] => [
    privateState,
    privateState.local_secret_key,
  ],

  additional_keys: ({
    privateState,
  }: WitnessContext<Ledger, MultiKeyState>): [MultiKeyState, Uint8Array[]] => [
    privateState,
    privateState.multiple_local_secret_keys,
  ],
};
```

## Error Handling

Throwing an error inside a witness function aborts the transaction. Use this for validation:

```typescript
get_balance: (
  { privateState }: WitnessContext<Ledger, BankState>,
  userId: Uint8Array,
): [BankState, bigint] => {
  const balance = privateState.balances.get(decodeUserId(userId));
  if (balance === undefined) {
    throw new Error(`User not found in private state`);
  }
  return [privateState, balance];
},
```

The error propagates to the circuit caller. There is no on-chain effect from a failed witness — the transaction is simply not submitted.

## Common Mistakes

| Mistake | Correct | Why |
|---------|---------|-----|
| Witness key doesn't match Compact name | Keys must be identical to Compact witness names | Runtime lookup by name |
| Forgetting to return updated private state | Always return `[newState, value]` tuple | Runtime expects the tuple |
| Mutating `privateState` directly | Spread and override: `{ ...privateState, field: newVal }` | Private state should be treated as immutable |
| Returning wrong tuple order | `[privateState, returnValue]` not `[returnValue, privateState]` | State first, value second |
| Missing parameters after WitnessContext | Additional params must match Compact declaration order | Circuit passes args positionally |
