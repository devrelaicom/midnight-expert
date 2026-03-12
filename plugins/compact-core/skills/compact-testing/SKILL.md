---
name: compact-testing
description: This skill should be used when the user asks about testing Compact smart contracts, writing unit tests for circuits, setting up Vitest for Compact projects, the Simulator pattern for contract testing, creating test context (createConstructorContext, createCircuitContext, sampleContractAddress), calling impureCircuits or circuits in tests, asserting ledger state with the ledger() function, testing assertion failures and error cases, multi-user testing, private state in tests, Compact compiler validation, compilation errors, CI pipeline testing, compact compile as a test gate, or test-driven development for Midnight contracts.
---

# Compact Contract Testing

Compact contracts compile to JavaScript (`index.js`), so you test them using standard JS test runners -- specifically Vitest. There is no official Compact test framework; you import the generated `Contract` class and runtime helpers directly, then assert against ledger state and return values. This skill covers the Simulator pattern for wrapping contract lifecycle, the context creation and reassignment lifecycle, assertion strategies for ledger state and errors, and compilation validation as a test gate. For witness implementation details, see `compact-witness-ts`. For contract anatomy (ledger, circuits, witnesses), see `compact-structure`.

## Quick Start

Minimal test for a counter contract with a single `increment` circuit:

```typescript
import { createConstructorContext, createCircuitContext, sampleContractAddress } from "@midnight-ntwrk/compact-runtime";
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { Contract, ledger } from "../managed/counter/contract/index.js";

setNetworkId("undeployed");

const contract = new Contract({ /* witnesses, if any */ });
const initialState = { privateCounter: 0 };
const deployCtx = createConstructorContext(initialState, "0100");
const { currentPrivateState, currentContractState } = contract.initialState(deployCtx);
let ctx = createCircuitContext(sampleContractAddress(), "0200", currentContractState, currentPrivateState);

const result = contract.impureCircuits.increment(ctx);
ctx = result.context;

expect(ledger(ctx.currentQueryContext.state).round).toEqual(1n);
```

## Simulator Pattern

The Simulator class encapsulates the full contract lifecycle -- instantiation, constructor context, initial state, and circuit context management -- into a single reusable object. Each circuit becomes a simple method call, and ledger/private state become accessor methods. This eliminates boilerplate and prevents the most common mistake: forgetting to reassign the context after a circuit call.

```typescript
class MySimulator {
  private contract: Contract<MyPrivateState>;
  private ctx: CircuitContext<MyPrivateState>;

  constructor(initialPrivateState: MyPrivateState) {
    this.contract = new Contract<MyPrivateState>(witnesses);
    const deployCtx = createConstructorContext(initialPrivateState, "0100");
    const { currentPrivateState, currentContractState } = this.contract.initialState(deployCtx);
    this.ctx = createCircuitContext(sampleContractAddress(), "0200", currentContractState, currentPrivateState);
  }

  myCircuit(args) {
    const result = this.contract.impureCircuits.myCircuit(this.ctx, ...args);
    this.ctx = result.context;
    return result;
  }

  get ledgerState() { return ledger(this.ctx.currentQueryContext.state); }
  get privateState() { return this.ctx.currentPrivateState; }
}
```

See `references/simulator-pattern.md` for the full pattern with multi-user support, private state switching, and pure circuit wrappers.

## Testing Checklist

| What to Test | How | Pattern |
|---|---|---|
| Circuit produces correct ledger state | `ledger(ctx.currentQueryContext.state).field` | Ledger assertion |
| Circuit returns correct value | `.result` from circuit call | Return assertion |
| Circuit rejects bad input | `expect(() => ...).toThrow("failed assert: ...")` | Error testing |
| Private state updates correctly | `ctx.currentPrivateState.field` | Private state assertion |
| Multi-user interaction | Switch `currentPrivateState` between calls | Multi-actor |
| Pure computation | `contract.circuits.<name>(args)` | Pure circuit test |
| Contract compiles | `compact compile` exits 0 | Compilation gate |

## Key API Reference

| Function / Type | Import From | Purpose |
|---|---|---|
| `Contract<PS>` | Generated code | Main contract class |
| `Ledger` | Generated code | Typed ledger interface |
| `ledger()` | Generated code | Extract typed ledger from state |
| `createConstructorContext()` | `@midnight-ntwrk/compact-runtime` | Create constructor context |
| `createCircuitContext()` | `@midnight-ntwrk/compact-runtime` | Create circuit execution context |
| `sampleContractAddress()` | `@midnight-ntwrk/compact-runtime` | Generate dummy address for tests |
| `CircuitContext<PS>` | `@midnight-ntwrk/compact-runtime` | Type for mutable test context |
| `WitnessContext<L, PS>` | `@midnight-ntwrk/compact-runtime` | Type for witness first argument |
| `setNetworkId()` | `@midnight-ntwrk/midnight-js-network-id` | Required test setup |

## Compilation Validation

`compact compile` is the first test gate for any Compact contract. It catches type errors, disclosure violations, sealed ledger misuse, and syntax issues before any runtime tests can run. In CI pipelines, run `compact compile` as a dedicated step that fails the build on any compiler error. See `references/compilation-validation.md` for compiler flags, error categories, and CI integration patterns.

## Common Mistakes

| Mistake | Fix |
|---|---|
| Forgetting `setNetworkId("undeployed")` | Call it before any contract operations |
| Not updating context after circuit call | Always reassign: `ctx = result.context` |
| Using `contract.circuits` for impure ops | Use `contract.impureCircuits` for state-changing circuits |
| Expecting string equality on `Bytes<N>` | Compare `Uint8Array` with `.toEqual()`, not `===` |
| Missing `deps.interopDefault: true` in vitest config | Required for CommonJS `index.js` imports |
| Testing with wrong `compact-runtime` version | Must match the version the compiler expects |
| Witness key mismatch | Witness object keys must exactly match Compact `witness` names |

## Reference Files

| Topic | Reference File |
|---|---|
| Project setup, dependencies, vitest config, directory layout | `references/test-setup.md` |
| Simulator class pattern, constructor, circuit wrappers, state access | `references/simulator-pattern.md` |
| Assertion patterns, error testing, ledger checks, private state checks | `references/assertions-and-patterns.md` |
| Compiler validation, error categories, CI integration | `references/compilation-validation.md` |

## Example Files

| Example | File | Pattern Demonstrated |
|---|---|---|
| Counter contract tests (beginner) | `examples/CounterSimulator.test.ts` | Basic Simulator, ledger assertion, context lifecycle |
| Bulletin board tests (intermediate) | `examples/BBoardSimulator.test.ts` | Witnesses, private state, multi-user interaction |
| Token contract tests (advanced) | `examples/TokenSimulator.test.ts` | Token transfers, balance checks, error testing |
| Pure circuit tests | `examples/PureCircuits.test.ts` | Pure circuits, no state, deterministic outputs |
| Vitest configuration | `examples/vitest.config.ts` | CommonJS interop, test runner setup |
