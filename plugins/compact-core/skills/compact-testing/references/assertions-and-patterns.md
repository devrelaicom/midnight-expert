# Assertions and Testing Patterns for Compact Contracts

Reference for assertion techniques and testing strategies used with Compact contract simulators and Vitest. For project setup and dependencies, see `references/test-setup.md`. For building the Simulator class itself, see `references/simulator-pattern.md`.

## Ledger State Assertions

The most common assertion pattern reads the on-chain ledger state and checks individual fields. The `ledger()` function (imported from the generated code) parses raw contract state into a typed `Ledger` object. Only fields declared with `export ledger` in the Compact source appear in the returned object.

```typescript
const state = ledger(simulator.circuitContext.currentQueryContext.state);
expect(state.round).toEqual(0n);
expect(state.owner).toEqual(expectedPublicKey);
expect(state.message.is_some).toBe(true);
expect(state.message.value).toEqual("Hello");
expect(state.status).toEqual(State.ACTIVE);
```

When using a Simulator class that exposes a `getLedgerState()` or `getLedger()` method, the call is simpler:

```typescript
const state = simulator.getLedger();
expect(state.round).toEqual(0n);
```

### Field Types in Assertions

| Compact Type | Assertion Matcher | Example |
|---|---|---|
| `Counter`, `Uint<N>`, `Field` | `toEqual(bigint)` | `expect(state.round).toEqual(0n)` |
| `Bytes<N>` | `toEqual(Uint8Array)` | `expect(state.owner).toEqual(expectedKey)` |
| `Boolean` | `toBe(boolean)` | `expect(state.active).toBe(true)` |
| `Opaque<"string">` | `toEqual(string)` | `expect(state.name).toEqual("Alice")` |
| `Maybe<T>` | check `is_some`, then `value` | see below |
| `enum` | `toEqual(EnumType.VARIANT)` | `expect(state.status).toEqual(State.ACTIVE)` |

### Maybe Fields

`Maybe<T>` values have two properties: `is_some` (boolean) and `value` (the inner type, present even when `is_some` is `false`). Always check `is_some` before relying on `value`:

```typescript
// Check that a Maybe field is populated
expect(state.message.is_some).toEqual(true);
expect(state.message.value).toEqual("Hello");

// Check that a Maybe field is empty
expect(state.message.is_some).toEqual(false);
expect(state.message.value).toEqual("");  // default value for the inner type
```

When `is_some` is `false`, the `value` field still exists but contains the default value for the inner type (empty string for `Opaque<"string">`, zero bytes for `Bytes<N>`, `0n` for numeric types).

### Enum Fields

Compact enums are exported as numeric constants from the generated contract code. Import them and use them directly in assertions:

```typescript
import { State } from "../managed/bboard/contract/index.js";

expect(state.state).toEqual(State.VACANT);    // 0
expect(state.state).toEqual(State.OCCUPIED);  // 1
```

Using the named constant (e.g., `State.VACANT`) is preferred over raw numbers for readability. The numeric values follow declaration order starting from 0.

## Circuit Return Value Assertions

Circuits can return values in addition to modifying ledger state. There are two patterns depending on whether the circuit is impure or pure.

### Impure Circuit Return Values

Impure circuits return `{ context, result }`. Destructure both, reassign the context, and assert on the result:

```typescript
const { context, result } = contract.impureCircuits.getValue(circuitContext);
circuitContext = context;  // always reassign
expect(result).toEqual(42n);
```

In a Simulator class, the circuit wrapper method typically returns the result directly:

```typescript
// Simulator method
getValue(): bigint {
  const { context, result } = this.contract.impureCircuits.getValue(this.circuitContext);
  this.circuitContext = context;
  return result;
}

// Test
const value = simulator.getValue();
expect(value).toEqual(42n);
```

### Pure Circuit Return Values

Pure circuits called through `contract.pureCircuits` return the result directly with no context management:

```typescript
const hash = contract.pureCircuits.computeHash(inputData);
expect(hash).toEqual(expectedHash);
```

This is the simplest pattern. See the Pure Circuit Testing section below for more detail.

### Void Circuits

Circuits that return `[]` (void) produce an empty array as their result. You can ignore it:

```typescript
const { context } = contract.impureCircuits.doSomething(circuitContext, arg);
circuitContext = context;
// No result to assert on -- the side effect is the ledger state change
```

## Private State Assertions

Private state lives off-chain and is managed by witness functions. Access it through the circuit context or a Simulator method:

```typescript
const privateState = simulator.circuitContext.currentPrivateState;
expect(privateState.counter).toEqual(5);
expect(privateState.secretKey).toEqual(expectedKey);
```

With a Simulator that exposes `getPrivateState()`:

```typescript
const privateState = simulator.getPrivateState();
expect(privateState).toEqual({ secretKey: key });
expect(privateState.secretKey).toEqual(expectedKey);
```

### Verifying Private State Does Not Change

A common pattern is asserting that private state remains unchanged after a circuit call that should only modify ledger state:

```typescript
const initialPrivateState = simulator.getPrivateState();
simulator.post("Hello");
expect(simulator.getPrivateState()).toEqual(initialPrivateState);
```

### Verifying Private State Updates

When a witness function mutates private state, verify the update by reading private state before and after:

```typescript
expect(simulator.getPrivateState().privateCounter).toEqual(0);
simulator.increment();
expect(simulator.getPrivateState().privateCounter).toEqual(1);
```

## Error Case Testing

Compact `assert` statements throw JavaScript errors when their condition is false. The error message follows the format `"failed assert: <message>"`, where `<message>` is the string provided in the Compact `assert` call.

### Basic Error Assertions

Use Vitest's `toThrow` matcher with the exact error message:

```typescript
expect(() => simulator.doSomething(invalidInput)).toThrow(
  "failed assert: Only owner can perform this action",
);
```

The callback passed to `expect()` must be a function that calls the circuit. Do not call the circuit directly -- wrapping it in a function allows `expect` to catch the thrown error.

### Real-World Examples from Midnight's Official Contracts

From the bulletin board (bboard) example:

```typescript
// Posting to an occupied board
expect(() => simulator.post("Another message")).toThrow(
  "failed assert: Attempted to post to an occupied board",
);

// Taking down someone else's post
expect(() => simulator.takeDown()).toThrow(
  "failed assert: Attempted to take down post, but not the current owner",
);
```

These messages come directly from the Compact source:

```compact
assert(state == State.VACANT, "Attempted to post to an occupied board");
assert(owner == publicKey(...), "Attempted to take down post, but not the current owner");
```

### Error Message Format

The error message always starts with `"failed assert: "` followed by the exact string from the Compact `assert` call. If the Compact `assert` does not include a message string, the error message is just `"failed assert"` (with no trailing text). When writing `toThrow` matchers, you can match either:

- The full string: `toThrow("failed assert: Attempted to post to an occupied board")`
- A substring: `toThrow("Attempted to post to an occupied board")`
- A regular expression: `toThrow(/not the current owner/)`

The full string match is recommended for precision.

### Testing Multiple Error Paths

When a circuit has multiple `assert` statements, write separate tests for each error path to confirm that each guard works independently:

```typescript
it("rejects posting to an occupied board", () => {
  simulator.post("First message");
  expect(() => simulator.post("Second message")).toThrow(
    "failed assert: Attempted to post to an occupied board",
  );
});

it("rejects taking down from an empty board", () => {
  expect(() => simulator.takeDown()).toThrow(
    "failed assert: Attempted to take down post from an empty board",
  );
});

it("rejects unauthorized takedown", () => {
  simulator.post("A message");
  simulator.switchUser(otherUserKey);
  expect(() => simulator.takeDown()).toThrow(
    "failed assert: Attempted to take down post, but not the current owner",
  );
});
```

## Testing Constructors

The contract constructor runs during Simulator instantiation. Verify the initial state immediately after creating the Simulator:

```typescript
it("properly initializes ledger state", () => {
  const key = randomBytes(32);
  const simulator = new BBoardSimulator(key);
  const state = simulator.getLedger();
  expect(state.state).toEqual(State.VACANT);
  expect(state.owner).toEqual(new Uint8Array(32));
  expect(state.sequence).toEqual(1n);
  expect(state.message.is_some).toEqual(false);
  expect(state.message.value).toEqual("");
});
```

### Verifying Private State After Construction

The private state should match what was passed to the constructor context:

```typescript
it("properly initializes private state", () => {
  const key = randomBytes(32);
  const simulator = new BBoardSimulator(key);
  const privateState = simulator.getPrivateState();
  expect(privateState).toEqual({ secretKey: key });
});
```

### Deterministic Construction

Two Simulator instances created with the same inputs should produce identical ledger state. This verifies that the contract constructor is deterministic:

```typescript
it("generates initial ledger state deterministically", () => {
  const key = randomBytes(32);
  const simulator0 = new BBoardSimulator(key);
  const simulator1 = new BBoardSimulator(key);
  expect(simulator0.getLedger()).toEqual(simulator1.getLedger());
});
```

This pattern catches accidental use of randomness in the constructor or witnesses. The entropy seed (`"0".repeat(64)`) is fixed in tests, so identical inputs must produce identical outputs.

### Constructor Parameters

When the Compact constructor accepts parameters, pass them through the Simulator constructor and verify they are reflected in the initial ledger state:

```typescript
it("initializes with constructor parameters", () => {
  const simulator = new MySimulator(100n, adminKey);
  const state = simulator.getLedger();
  expect(state.initialValue).toEqual(100n);
  expect(state.admin).toEqual(adminKey);
});
```

## Multi-User and Multi-Actor Testing

Many contracts involve multiple participants. The Simulator's `switchUser` method changes the private state to represent a different user, allowing you to test access control, ownership, and multi-party interactions within a single test.

### Basic Multi-User Pattern

```typescript
import { randomBytes } from "./utils.js";

const userA = randomBytes(32);
const simulator = new BBoardSimulator(userA);

// User A posts a message
simulator.post("Hello from A");

// Switch to User B
const userB = randomBytes(32);
simulator.switchUser(userB);

// User B cannot take down User A's post
expect(() => simulator.takeDown()).toThrow(
  "failed assert: Attempted to take down post, but not the current owner",
);

// Switch back to User A
simulator.switchUser(userA);

// User A can take down their own post
simulator.takeDown();  // succeeds without error
```

### How switchUser Works

The `switchUser` method directly assigns a new private state object to the circuit context:

```typescript
switchUser(secretKey: Uint8Array): void {
  this.circuitContext.currentPrivateState = { secretKey };
}
```

After calling `switchUser`, all subsequent circuit calls use the new user's private state. Witness functions like `localSecretKey` return the new user's key, which affects authentication and ownership checks in the contract.

### Testing User Handoffs

A common scenario is one user performing an action, then another user continuing:

```typescript
it("lets a different user post after the first user takes down", () => {
  const simulator = new BBoardSimulator(randomBytes(32));
  simulator.post("First message");
  simulator.takeDown();

  // Switch to a new user
  simulator.switchUser(randomBytes(32));

  // New user can post to the now-vacant board
  simulator.post("Second message");
  const state = simulator.getLedger();
  expect(state.message.is_some).toEqual(true);
  expect(state.message.value).toEqual("Second message");
  expect(state.state).toEqual(State.OCCUPIED);
});
```

### Generating Test User Keys

Several approaches for creating distinct user keys in tests:

```typescript
// Using crypto.getRandomValues (browser-compatible, used in official examples)
const randomBytes = (length: number): Uint8Array => {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return bytes;
};
const user = randomBytes(32);

// Using Node.js crypto module
import { randomBytes } from "crypto";
const user = randomBytes(32);

// Deterministic keys (useful for reproducible tests)
const alice = new Uint8Array(32).fill(1);
const bob = new Uint8Array(32).fill(2);
const carol = new Uint8Array(32).fill(3);
```

Deterministic keys (`fill(1)`, `fill(2)`, etc.) are useful when you need reproducible test output or when debugging a specific failure. Random keys are better for general testing because they exercise more of the key space.

## Pure Circuit Testing

Pure circuits are stateless computations that do not modify ledger or private state. They are called through `contract.pureCircuits`, which takes only the circuit arguments and returns the result directly -- no context management required.

### Basic Pure Circuit Assertions

```typescript
const result = contract.pureCircuits.computeHash(inputBytes);
expect(result).toBeInstanceOf(Uint8Array);
expect(result.length).toEqual(32);
```

### Determinism

Pure circuits are deterministic -- the same inputs always produce the same output. This is a fundamental property of ZK circuits and is worth testing explicitly:

```typescript
const result1 = contract.pureCircuits.computeHash(inputBytes);
const result2 = contract.pureCircuits.computeHash(inputBytes);
expect(result1).toEqual(result2);
```

### Testing Pure Circuits Outside a Simulator

Pure circuits can be tested without a Simulator because they have no state dependencies. Import the `Contract` class directly:

```typescript
import { Contract } from "../managed/mycontract/contract/index.js";

describe("Pure circuit: computeHash", () => {
  const contract = new Contract({});

  it("produces a 32-byte hash", () => {
    const input = new Uint8Array(32).fill(0xab);
    const result = contract.pureCircuits.computeHash(input);
    expect(result).toBeInstanceOf(Uint8Array);
    expect(result.length).toEqual(32);
  });

  it("is deterministic", () => {
    const input = new Uint8Array(32).fill(0xab);
    const a = contract.pureCircuits.computeHash(input);
    const b = contract.pureCircuits.computeHash(input);
    expect(a).toEqual(b);
  });

  it("produces different outputs for different inputs", () => {
    const input1 = new Uint8Array(32).fill(0x01);
    const input2 = new Uint8Array(32).fill(0x02);
    const hash1 = contract.pureCircuits.computeHash(input1);
    const hash2 = contract.pureCircuits.computeHash(input2);
    expect(hash1).not.toEqual(hash2);
  });
});
```

### Pure Circuits via the Context Interface

If you need context tracking for some reason, pure circuits are also available through `contract.circuits`, which follows the `{ context, result }` pattern:

```typescript
const { context, result } = contract.circuits.computeHash(circuitContext, inputBytes);
// context is unchanged (pure circuit), but you can reassign if desired
```

Prefer `contract.pureCircuits` unless you have a specific reason to use the context interface.

## Sequential Operations

Testing state transitions across multiple operations verifies that ledger updates accumulate correctly and that the context lifecycle is handled properly.

### Counter-Style Sequences

```typescript
it("should track state across multiple operations", () => {
  const simulator = new CounterSimulator();
  expect(simulator.getLedger().round).toEqual(0n);

  simulator.increment();
  expect(simulator.getLedger().round).toEqual(1n);

  simulator.increment();
  expect(simulator.getLedger().round).toEqual(2n);
});
```

### State Machine Transitions

For contracts that use enum states to model a state machine, verify each transition:

```typescript
it("follows the state machine lifecycle", () => {
  const simulator = new BBoardSimulator(randomBytes(32));

  // Initial state
  expect(simulator.getLedger().state).toEqual(State.VACANT);

  // Post transitions VACANT -> OCCUPIED
  simulator.post("Hello");
  expect(simulator.getLedger().state).toEqual(State.OCCUPIED);

  // TakeDown transitions OCCUPIED -> VACANT
  simulator.takeDown();
  expect(simulator.getLedger().state).toEqual(State.VACANT);
});
```

### Multi-Field State Tracking

Verify that multiple ledger fields update together correctly:

```typescript
it("updates sequence and state together on takeDown", () => {
  const simulator = new BBoardSimulator(randomBytes(32));

  simulator.post("Message");
  expect(simulator.getLedger().sequence).toEqual(1n);
  expect(simulator.getLedger().state).toEqual(State.OCCUPIED);
  expect(simulator.getLedger().message.is_some).toEqual(true);

  simulator.takeDown();
  expect(simulator.getLedger().sequence).toEqual(2n);
  expect(simulator.getLedger().state).toEqual(State.VACANT);
  expect(simulator.getLedger().message.is_some).toEqual(false);
});
```

### Round-Trip Operations

Verify that performing an action and then undoing it returns the contract to a known state:

```typescript
it("returns to initial state after post and takeDown", () => {
  const simulator = new BBoardSimulator(randomBytes(32));
  const initialState = simulator.getLedger().state;

  simulator.post("Temporary");
  simulator.takeDown();

  expect(simulator.getLedger().state).toEqual(initialState);
  expect(simulator.getLedger().message.is_some).toEqual(false);
});
```

## Edge Cases

Edge case testing catches boundary conditions and default-value assumptions. These tests often reveal off-by-one errors, overflow behavior, and uninitialized state bugs.

### Default and Zero Values After Construction

Verify that all ledger fields have their expected initial values:

```typescript
it("initializes all fields to defaults", () => {
  const simulator = new CounterSimulator();
  const state = simulator.getLedger();

  // Counter starts at zero
  expect(state.round).toEqual(0n);

  // Bytes fields are zeroed
  expect(state.owner).toEqual(new Uint8Array(32));

  // Maybe fields are none
  expect(state.message.is_some).toEqual(false);

  // Enum fields are the first variant
  expect(state.status).toEqual(Status.INITIAL);
});
```

### Maximum Uint Values

Compact `Uint<N>` types have a maximum value of `2^N - 1`. Test behavior at and near the upper bound:

| Compact Type | Maximum Value | BigInt Literal |
|---|---|---|
| `Uint<8>` | 255 | `255n` |
| `Uint<16>` | 65535 | `65535n` |
| `Uint<32>` | 4294967295 | `4294967295n` |
| `Uint<64>` | 18446744073709551615 | `BigInt("18446744073709551615")` |

```typescript
it("handles maximum Uint<64> value", () => {
  const maxU64 = BigInt("18446744073709551615");
  // Test that the circuit accepts the maximum value
  simulator.setValue(maxU64);
  expect(simulator.getLedger().value).toEqual(maxU64);
});
```

### Empty Bytes

`Bytes<N>` initialized to all zeros:

```typescript
it("handles empty Bytes<32>", () => {
  const emptyBytes = new Uint8Array(32);
  simulator.setKey(emptyBytes);
  expect(simulator.getLedger().key).toEqual(emptyBytes);
});
```

### Maybe with is_some: false

When a `Maybe<T>` field is `none`, `is_some` is `false` and `value` contains the type's default:

```typescript
it("handles none Maybe value", () => {
  const state = simulator.getLedger();
  expect(state.optionalMessage.is_some).toEqual(false);
  expect(state.optionalMessage.value).toEqual("");  // default for Opaque<"string">
});
```

### Operations on Empty Collections

Test behavior when `Map`, `Set`, or `Counter` collections are in their default empty state:

```typescript
it("handles operations on empty Counter", () => {
  const simulator = new CounterSimulator();
  // Counter starts at zero
  expect(simulator.getLedger().count).toEqual(0n);
  // Decrementing below zero should fail if the contract enforces it
  // (behavior depends on the Compact contract logic)
});
```

### Boundary Transitions

Test the transition between empty and non-empty states:

```typescript
it("transitions from none to some", () => {
  const simulator = new BBoardSimulator(randomBytes(32));

  // Starts as none
  expect(simulator.getLedger().message.is_some).toEqual(false);

  // Post sets it to some
  simulator.post("Hello");
  expect(simulator.getLedger().message.is_some).toEqual(true);
  expect(simulator.getLedger().message.value).toEqual("Hello");

  // TakeDown sets it back to none
  simulator.takeDown();
  expect(simulator.getLedger().message.is_some).toEqual(false);
});
```

## Vitest Matchers Quick Reference

Summary of Vitest matchers commonly used with Compact contract tests:

| Matcher | Use For | Example |
|---|---|---|
| `toEqual(value)` | Deep equality for objects, arrays, BigInts, Uint8Arrays | `expect(state.round).toEqual(0n)` |
| `toBe(value)` | Strict reference equality for primitives | `expect(state.active).toBe(true)` |
| `toThrow(message)` | Verifying circuit assertion failures | `expect(() => sim.post("x")).toThrow("failed assert: ...")` |
| `toThrow(regex)` | Partial match on error messages | `expect(() => sim.post("x")).toThrow(/occupied/)` |
| `toBeInstanceOf(type)` | Type checking return values | `expect(result).toBeInstanceOf(Uint8Array)` |
| `not.toEqual(value)` | Verifying values differ | `expect(hash1).not.toEqual(hash2)` |

### toEqual vs toBe

Use `toEqual` for `bigint`, `Uint8Array`, objects, and any value that is compared by structure. Use `toBe` for `boolean` and cases where you want strict reference identity. In practice, `toEqual` works for everything, but `toBe(true)` and `toBe(false)` are more idiomatic for boolean checks.

## Common Assertion Mistakes

| Mistake | Symptom | Fix |
|---|---|---|
| Using `toBe` for `bigint` comparison | Test fails even though values look equal | Use `toEqual` -- `toBe` checks reference identity, and `0n !== 0n` across different allocations in some runtimes |
| Forgetting the arrow function in `toThrow` | Error is thrown before `expect` can catch it | Wrap the call: `expect(() => sim.action()).toThrow(...)` |
| Comparing `Uint8Array` with `toBe` | Always fails because arrays are different objects | Use `toEqual` for structural comparison |
| Expecting raw numbers instead of `bigint` | `toEqual(0)` fails when the value is `0n` | Use `bigint` literals: `toEqual(0n)` |
| Checking `Maybe.value` without checking `is_some` | Test passes but is meaningless -- `value` has a default even when `is_some` is `false` | Always assert `is_some` first |
| Wrong error message string in `toThrow` | Test passes when it should not (no error thrown) or fails with "expected to throw" | Copy the exact message from the Compact `assert` statement, prefixed with `"failed assert: "` |
