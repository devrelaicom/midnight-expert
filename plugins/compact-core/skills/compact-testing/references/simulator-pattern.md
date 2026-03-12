# The Simulator Pattern for Compact Contract Testing

Reference for building Simulator classes that wrap Compact contracts for unit testing. The Simulator pattern is the recommended approach from Midnight's official examples. For project setup and dependencies, see `references/test-setup.md`. For assertions and testing strategies, see `references/assertions-and-patterns.md`.

## Why Use a Simulator

The Simulator class encapsulates the entire contract lifecycle into a single, reusable object. Without it, every test must manually create constructor contexts, run the contract initializer, build circuit contexts, and track context updates after each circuit call. This boilerplate obscures the actual test logic and is error-prone.

A Simulator provides:

| Responsibility | What It Handles |
|----------------|-----------------|
| Contract instantiation | Creates the `Contract` instance with witness implementations |
| Constructor context | Calls `createConstructorContext` with initial private state and entropy seed |
| Initial state | Runs `contract.initialState()` to execute the Compact constructor and produce the first ledger/private/zswap state |
| Circuit context lifecycle | Creates and maintains the `CircuitContext`, reassigning it after every circuit call |
| Circuit method wrappers | Exposes each circuit as a simple method, hiding the context-passing mechanics |
| Ledger state access | Provides a method to read the current ledger state as a typed object |
| Private state access | Provides a method to read (and optionally switch) the current private state |

The result is that test files read like plain function calls against a domain object, with no runtime plumbing visible.

## Anatomy of a Simulator

The following annotated example shows the complete structure. Each numbered comment corresponds to a section explained below.

```typescript
import {
  type CircuitContext,
  createConstructorContext,
  createCircuitContext,
  sampleContractAddress,
  WitnessContext,
} from "@midnight-ntwrk/compact-runtime";
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import {
  Contract,
  type Ledger,
  ledger,
} from "../managed/<name>/contract/index.js";

// 1. Define private state type
type MyPrivateState = {
  readonly secretKey: Uint8Array;
};

// 2. Define witness implementations
const witnesses = {
  local_secret_key: ({
    privateState,
  }: WitnessContext<Ledger, MyPrivateState>): [MyPrivateState, Uint8Array] =>
    [privateState, privateState.secretKey],
};

// 3. Build the simulator class
export class MySimulator {
  private contract: Contract<MyPrivateState>;
  private circuitContext: CircuitContext<MyPrivateState>;

  constructor(secretKey: Uint8Array) {
    setNetworkId("undeployed");

    this.contract = new Contract<MyPrivateState>(witnesses);

    // Run the constructor circuit to initialize state
    const { currentPrivateState, currentContractState, currentZswapLocalState } =
      this.contract.initialState(
        createConstructorContext({ secretKey }, "0".repeat(64)),
      );

    // Create the circuit context for subsequent calls
    this.circuitContext = createCircuitContext(
      sampleContractAddress(),
      currentZswapLocalState,
      currentContractState,
      currentPrivateState,
    );
  }

  // 4. Wrap each circuit as a method
  doSomething(arg: bigint): void {
    this.circuitContext = this.contract.impureCircuits.doSomething(
      this.circuitContext,
      arg,
    ).context;
  }

  // 5. Expose ledger state
  getLedgerState(): Ledger {
    return ledger(this.circuitContext.currentQueryContext.state);
  }

  // 6. Expose private state
  getPrivateState(): MyPrivateState {
    return this.circuitContext.currentPrivateState;
  }
}
```

### Section 1: Private State Type

The private state type is a plain TypeScript object describing the off-chain data that witnesses need. Mark fields `readonly` to signal immutability. For contracts with no witnesses, use `Record<string, never>` and an empty witnesses object. For full details on private state design, see the `compact-witness-ts` skill's `references/witness-implementation.md`.

### Section 2: Witness Implementations

The `witnesses` object provides the TypeScript implementations for every `witness` declaration in the Compact contract. Each key must exactly match the Compact witness function name, and each value follows the `(WitnessContext, ...args) => [PrivateState, ReturnValue]` signature. See the Witness Function Signature section below for the full pattern.

### Section 3: Constructor and Initial State

The constructor performs four steps in sequence:

1. **Set network ID** -- `setNetworkId("undeployed")` configures the runtime for local simulation
2. **Create the Contract instance** -- `new Contract<PS>(witnesses)` binds the witness implementations
3. **Run the contract constructor** -- `contract.initialState(constructorContext)` executes the Compact `constructor` block
4. **Create the circuit context** -- `createCircuitContext(...)` builds the reusable context for all subsequent circuit calls

### Section 4: Circuit Method Wrappers

Each exported circuit in the Compact contract becomes a method on the Simulator. The method passes the current `circuitContext` to the circuit, then reassigns `this.circuitContext` to the returned `result.context`. This reassignment is mandatory -- see Context Lifecycle below.

### Section 5: Ledger State Access

The `getLedgerState()` method parses the raw contract state into the compiler-generated `Ledger` type. The `ledger()` function is imported from the generated code and takes the state from `circuitContext.currentQueryContext.state`. Only fields declared with `export ledger` in the Compact source appear in the returned object.

### Section 6: Private State Access

The `getPrivateState()` method returns the current private state from the circuit context. This reflects any mutations made by witness functions during circuit execution.

## Context Lifecycle

Understanding the context lifecycle is essential. The runtime uses an immutable data flow -- each operation produces a new context rather than mutating the existing one.

### Step 1: Create the Constructor Context

```typescript
const constructorContext = createConstructorContext(
  initialPrivateState,  // Your private state object (e.g., { secretKey })
  seed,                 // A 64-character hex string for deterministic key derivation
);
```

`createConstructorContext` produces a `ConstructorContext<PS>` that packages the initial private state with a deterministic entropy seed. The seed is used internally for ZK key derivation. In tests, `"0".repeat(64)` (64 zeros) is the standard value because determinism makes tests reproducible. In production, use cryptographically random entropy.

### Step 2: Run the Contract Constructor

```typescript
const { currentPrivateState, currentContractState, currentZswapLocalState } =
  contract.initialState(constructorContext);
```

`contract.initialState(constructorContext)` executes the Compact `constructor` block. It returns three values:

| Field | Type | Description |
|-------|------|-------------|
| `currentPrivateState` | `PS` | The private state after the constructor ran (may differ from the input if witnesses mutated it) |
| `currentContractState` | `ContractState` | The on-chain contract state (ledger values) after initialization |
| `currentZswapLocalState` | `ZswapLocalState` | Internal ZK state tracking (commitment trees, nullifiers) |

All three are needed to construct the circuit context.

### Step 3: Create the Circuit Context

```typescript
const circuitContext = createCircuitContext(
  sampleContractAddress(),   // A deterministic test address
  currentZswapLocalState,    // From Step 2
  currentContractState,      // From Step 2
  currentPrivateState,       // From Step 2
);
```

`createCircuitContext` builds a `CircuitContext<PS>` that bundles everything a circuit needs to execute: the contract address, the ZK state, the ledger state, and the private state. `sampleContractAddress()` returns a deterministic address suitable for testing -- it is always the same value, which makes test output reproducible.

### Step 4: Call Circuits and Reassign the Context

```typescript
// Each circuit call returns { context, result }
const outcome = contract.impureCircuits.myCircuit(circuitContext, arg1, arg2);

// MUST reassign -- the old context is stale
circuitContext = outcome.context;

// Access the return value if the circuit returns one
const returnValue = outcome.result;
```

After each circuit call, the returned `context` reflects the updated ledger state, private state, and ZK state. You must reassign it. Using the old context for subsequent calls produces stale or incorrect results because it still holds the pre-call state.

In a Simulator class, this reassignment happens inside each circuit wrapper method:

```typescript
doSomething(arg: bigint): void {
  this.circuitContext = this.contract.impureCircuits.doSomething(
    this.circuitContext,
    arg,
  ).context;
}
```

### The Seed Parameter

The seed passed to `createConstructorContext` is a 64-character hexadecimal string (representing 32 bytes). It provides deterministic entropy for ZK key derivation during contract initialization.

| Context | Seed Value | Rationale |
|---------|-----------|-----------|
| Unit tests | `"0".repeat(64)` | Deterministic and reproducible |
| Integration tests | `"0".repeat(64)` | Same as unit tests |
| Production deployment | Cryptographically random 64-char hex | Security requires unpredictable entropy |

## Calling Circuits

The `Contract` class exposes three circuit interfaces. Which one you use depends on whether the circuit modifies state and whether you need context tracking.

### Impure Circuits

Impure circuits read or write ledger state, call witnesses, or both. They are the most common type:

```typescript
// Signature: contract.impureCircuits.<name>(ctx, ...args) => { context, result }
const { context, result } = contract.impureCircuits.increment(circuitContext);
this.circuitContext = context;  // Reassign
```

The return type is `{ context: CircuitContext<PS>, result: R }` where `R` matches the Compact circuit's return type. If the circuit returns `[]` (void), `result` is an empty array.

### Pure Circuits (with context)

Pure circuits do not modify state. When called through `contract.circuits`, they still accept and return a context, but the context is unchanged:

```typescript
// Signature: contract.circuits.<name>(ctx, ...args) => { context, result }
const { context, result } = contract.circuits.computeHash(circuitContext, data);
// context === circuitContext (unchanged), but reassigning is harmless
```

### Pure Circuit Helpers (no context)

For pure circuits, the simplest calling convention is `contract.pureCircuits`, which takes only the circuit arguments and returns the result directly:

```typescript
// Signature: contract.pureCircuits.<name>(...args) => result
const hash: Uint8Array = contract.pureCircuits.computeHash(data);
```

This is the preferred way to call pure circuits in tests because it eliminates context management entirely. Use this for computing hashes, validating inputs, or any stateless operation.

### Choosing the Right Interface

| Interface | Use When | Context Required? | State Modified? |
|-----------|----------|-------------------|-----------------|
| `impureCircuits` | Circuit reads/writes ledger or calls witnesses | Yes -- must reassign | Yes |
| `circuits` | You need context tracking for a pure circuit | Yes -- context unchanged | No |
| `pureCircuits` | Simple stateless computation | No | No |

### Returning Values from Circuits

When a circuit returns a value, destructure both `context` and `result`:

```typescript
getBalance(user: Uint8Array): bigint {
  const { context, result } = this.contract.impureCircuits.getBalance(this.circuitContext, user);
  this.circuitContext = context;
  return result;
}
```

When a circuit returns `[]` (void), `result` is an empty array and can be ignored.

## Witness Function Signature

Every witness follows this pattern:

```typescript
witnessName: (
  witnessContext: WitnessContext<Ledger, PrivateState>,
  ...additionalArgs
): [PrivateState, ReturnValue] => {
  return [updatedPrivateState, returnValue];
}
```

Key rules:

- **First parameter** is always `WitnessContext<Ledger, PS>`, which contains `privateState`, `ledger` (read-only), and `contractAddress`. Most witnesses only need `privateState`, so destructuring `{ privateState }` is idiomatic.
- **Return value** is always `[PS, R]` -- the updated private state first, then the value the circuit receives.
- **To update private state**, return a new object: `{ ...privateState, field: newValue }`. Never mutate `privateState` directly.
- **Object keys** must exactly match Compact `witness` declaration names. A mismatch causes a runtime error.

For comprehensive witness patterns (parameterized, ledger-reading, state-mutating, side-effect-only), see the `compact-witness-ts` skill's `references/witness-implementation.md`.

## Multi-User Testing

Many contracts involve multiple participants (e.g., token transfers, voting, games). The Simulator supports multi-user testing by switching the private state to represent a different user.

### Switching Private State

Add a method to the Simulator that replaces the current private state:

```typescript
switchUser(secretKey: Uint8Array): void {
  this.circuitContext.currentPrivateState = { secretKey };
}
```

This directly assigns a new private state object to the context. After calling `switchUser`, subsequent circuit calls use the new user's private state, which means witness functions like `local_secret_key` will return the new user's key.

### Multi-User Test Example

```typescript
describe("Token transfer", () => {
  it("should transfer tokens between users", () => {
    const alice = new Uint8Array(32).fill(1);
    const bob = new Uint8Array(32).fill(2);

    const sim = new TokenSimulator(alice);

    // Alice mints tokens
    sim.mint(100n);
    expect(sim.getLedgerState().totalSupply).toEqual(100n);

    // Switch to Bob's perspective
    sim.switchUser(bob);

    // Now circuit calls use Bob's secret key
    sim.register();

    // Switch back to Alice to perform transfer
    sim.switchUser(alice);
    sim.transfer(bob, 50n);
  });
});
```

### Complex Private State

When the private state has more fields than just a secret key, accept a full state object or provide a convenience constructor:

```typescript
switchUser(secretKey: Uint8Array, additionalData?: Record<string, string[]>): void {
  this.circuitContext.currentPrivateState = {
    secretKey,
    localData: additionalData ?? {},
  };
}
```

## Type Mapping Quick Reference

When constructing test values for circuit arguments, private state, and assertions, use these mappings between Compact types and TypeScript values.

| Compact Type | TypeScript Test Value | Example |
|---|---|---|
| `Field` | `bigint` | `0n`, `42n` |
| `Uint<64>` | `bigint` | `100n` |
| `Bytes<32>` | `Uint8Array` | `new Uint8Array(32)` |
| `Boolean` | `boolean` | `true`, `false` |
| `Opaque<"string">` | `string` | `"hello"` |
| `Maybe<T>` | `{ is_some: boolean; value: T }` | `{ is_some: true, value: "hi" }` |
| `enum` variants | `number` | `State.ACTIVE` (0), `State.INACTIVE` (1) |
| `Counter` (ledger) | `bigint` | via `ledger().counter` |
| `Vector<N, T>` | `T[]` | `[1n, 2n, 3n]` for `Vector<3, Field>` |
| `[]` (empty tuple) | `[]` | Circuit returns nothing |

### Creating Test Byte Arrays

Several helper patterns for `Bytes<N>` values in tests:

```typescript
// All zeros (32 bytes)
const emptyKey = new Uint8Array(32);

// Filled with a specific byte (useful for distinct test users)
const alice = new Uint8Array(32).fill(1);
const bob = new Uint8Array(32).fill(2);

// From a hex string (when you need a specific value)
const knownKey = Uint8Array.from(
  Buffer.from("abcd".repeat(16), "hex"),
);
```

### Enum Values in Tests

Compact enums are exported as numeric constants from the generated code:

```compact
// Compact
export enum GameState { waiting, playing, finished }
```

```typescript
// TypeScript -- import from generated code
import { GameState } from "../managed/<name>/contract/index.js";

// Use in assertions
expect(sim.getLedgerState().state).toEqual(GameState.waiting);  // 0
sim.startGame();
expect(sim.getLedgerState().state).toEqual(GameState.playing);  // 1
```

For the complete type mapping reference including runtime bounds checking, `Either`, structs, and generic types, see the `compact-witness-ts` skill's `references/type-mappings.md`.

## Contracts Without Witnesses

For contracts with no `witness` declarations (e.g., a simple counter), the Simulator structure is the same but the private state and witnesses are empty:

```typescript
type CounterPrivateState = Record<string, never>;

export class CounterSimulator {
  private contract: Contract<CounterPrivateState>;
  private circuitContext: CircuitContext<CounterPrivateState>;

  constructor() {
    setNetworkId("undeployed");
    this.contract = new Contract<CounterPrivateState>({});

    const { currentPrivateState, currentContractState, currentZswapLocalState } =
      this.contract.initialState(createConstructorContext({}, "0".repeat(64)));

    this.circuitContext = createCircuitContext(
      sampleContractAddress(), currentZswapLocalState, currentContractState, currentPrivateState,
    );
  }

  increment(): void {
    this.circuitContext = this.contract.impureCircuits.increment(this.circuitContext).context;
  }

  getLedgerState(): Ledger {
    return ledger(this.circuitContext.currentQueryContext.state);
  }
}
```

The key differences: `Record<string, never>` for the private state type, `{}` for the witnesses object, and `{}` for the initial private state in `createConstructorContext`.

## Contracts With Constructor Parameters

When the Compact contract accepts constructor parameters, they are passed as additional arguments to `contract.initialState` after the constructor context:

```compact
// Compact
constructor(initialValue: Uint<64>, adminKey: Bytes<32>) {
  counter = default<Counter>();
  counter.increment(initialValue);
  admin = disclose(adminKey);
}
```

```typescript
// TypeScript Simulator
constructor(initialValue: bigint, adminKey: Uint8Array) {
  setNetworkId("undeployed");

  this.contract = new Contract<MyPrivateState>(witnesses);

  const { currentPrivateState, currentContractState, currentZswapLocalState } =
    this.contract.initialState(
      createConstructorContext({ secretKey: adminKey }, "0".repeat(64)),
      initialValue,
      adminKey,
    );

  this.circuitContext = createCircuitContext(
    sampleContractAddress(),
    currentZswapLocalState,
    currentContractState,
    currentPrivateState,
  );
}
```

The constructor parameters follow the constructor context argument positionally, matching the order declared in the Compact `constructor`.

## Common Mistakes

| Mistake | Symptom | Fix |
|---------|---------|-----|
| Not reassigning `this.circuitContext` after a circuit call | Subsequent calls use stale state; ledger values do not update | Always assign `this.circuitContext = result.context` |
| Using `contract.circuits` instead of `contract.impureCircuits` for state-changing circuits | Unexpected behavior or missing state changes | Use `impureCircuits` for circuits that modify ledger or call witnesses |
| Wrong argument order in `createCircuitContext` | Type errors or runtime crashes | Order is: `(address, zswapState, contractState, privateState)` |
| Witness key name mismatch | Runtime error: witness not found | Keys must exactly match Compact `witness` declaration names |
| Forgetting `setNetworkId("undeployed")` | Network configuration error on contract instantiation | Call `setNetworkId("undeployed")` in the Simulator constructor or at module level |
| Passing the wrong seed length | Runtime error during constructor context creation | Seed must be exactly 64 hex characters (32 bytes) |
| Importing `ledger` from the wrong path | Module not found error | Import from `../managed/<name>/contract/index.js` |
| Mutating `privateState` directly in a witness | State changes are lost | Return a new object: `{ ...privateState, field: newValue }` |
