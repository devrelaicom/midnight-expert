# TypeScript Bindings

The Compact compiler generates TypeScript type definitions and a JavaScript implementation in the `contract/` output subdirectory. These files are the bridge between the on-chain Compact contract and the off-chain TypeScript DApp. They provide type-safe access to circuits, witnesses, ledger state, and user-defined types.

The three generated files are:

| File | Purpose |
|------|---------|
| `index.d.ts` | TypeScript type declarations for all exported types, circuits, witnesses, and the `Contract` class |
| `index.js` (or `index.cjs`) | JavaScript implementation with runtime validation, type descriptors, and circuit wrappers |
| `index.js.map` | Source map linking generated JavaScript back to the original `.compact` source |

## index.d.ts -- Type Definitions

Every `.d.ts` file produced by the Compact compiler follows the same structure:

1. An `import` line connecting to `@midnight-ntwrk/compact-runtime`
2. Declarations of exported user-defined types
3. A `Witnesses<T>` type for witness function signatures
4. Circuit type aliases (`Circuits<T>`, `ImpureCircuits<T>`, `PureCircuits`)
5. The `Contract` class
6. A `Ledger` type and `ledger()` constructor function
7. A `pureCircuits` constant

### Exported User-Defined Types

Each type exported from the contract's top level becomes a TypeScript type. Compact types map to TypeScript representations as follows:

| Compact Type | TypeScript Type | Notes |
|---|---|---|
| `Field` | `bigint` | Runtime bounds-checked against MAX_FIELD |
| `Boolean` | `boolean` | |
| `Bytes<N>` | `Uint8Array` | Runtime length-checked to N bytes |
| `Uint<N>` | `bigint` | Runtime bounds-checked against N |
| `Uint<0..N>` | `bigint` | Runtime bounds-checked against N |
| `[T, ...]` | `[S, ...]` or `S[]` | TypeScript tuple or array with runtime length checks |
| `Vector<N, T>` | `T[]` | Fixed-length array with runtime length checks |
| `Maybe<T>` | `{ is_some: boolean; value: T }` | |
| `Either<L, R>` | `{ is_left: boolean; left: L; right: R }` | Both fields present; `is_left` indicates active side |
| `enum` | TypeScript `enum` (numeric) | Runtime membership checks |
| `struct` | TypeScript object type `{ field: Type; ... }` | Fields match Compact field names |
| `Opaque<"string">` | `string` | |
| `Opaque<"Uint8Array">` | `Uint8Array` | |

Compact types carry runtime bounds and constraints that TypeScript's type system cannot express. For example, a `Uint<64>` is represented as `bigint` at the TypeScript level, but the generated JavaScript validates at runtime that the value fits within the 64-bit unsigned range. Similarly, `Bytes<32>` is `Uint8Array` in TypeScript, but the runtime checks that the array is exactly 32 bytes long.

**Enum example.** A Compact `export enum State { VACANT, OCCUPIED }` becomes:

```typescript
export enum State {
  VACANT = 0,
  OCCUPIED = 1
}
```

**Struct example.** A Compact `export struct S<T> { v: T[]; curidx: bigint }` becomes:

```typescript
export type S<T> = { v: T[]; curidx: bigint }
```

Generic type parameters that are used only as size parameters (prefixed with `#` in Compact) are dropped in the exported TypeScript type.

### Witnesses<T>

The `Witnesses<T>` type describes the shape of the witness implementations that must be provided when constructing a `Contract` instance. Each witness declared in Compact produces one entry in this type.

Each witness function receives an additional first parameter of type `WitnessContext<Ledger, T>` and returns `[T, R]`, where `T` is the private state type and `R` is the declared return type.

For a contract with `witness localSecretKey(): Bytes<32>;`:

```typescript
export type Witnesses<PS> = {
  localSecretKey(
    context: __compactRuntime.WitnessContext<Ledger, PS>
  ): [PS, Uint8Array];
}
```

The `WitnessContext` provides three fields to the witness implementation:

| Field | Type | Description |
|-------|------|-------------|
| `ledger` | `Ledger` | Projected ledger state as you see it locally |
| `privateState` | `PS` | Current private state for the contract |
| `contractAddress` | `string` | Address of the contract being called |

The return type `[PS, R]` ensures witness functions are functionally pure from the runtime's perspective -- they return an updated private state along with their result, rather than mutating state as a side effect.

### Circuits<T>, ImpureCircuits<T>, PureCircuits

The compiler generates three circuit-related type aliases:

**`Circuits<T>`** describes all exported circuits (both pure and impure). Each circuit receives a `CircuitContext<T>` as its first parameter and returns `CircuitResults<T, R>`:

```typescript
export type Circuits<PS> = {
  post(
    context: __compactRuntime.CircuitContext<PS>,
    newMessage: string
  ): __compactRuntime.CircuitResults<PS, []>;

  takeDown(
    context: __compactRuntime.CircuitContext<PS>
  ): __compactRuntime.CircuitResults<PS, string>;

  publicKey(
    context: __compactRuntime.CircuitContext<PS>,
    sk: Uint8Array,
    sequence: Uint8Array
  ): __compactRuntime.CircuitResults<PS, Uint8Array>;
}
```

**`ImpureCircuits<T>`** contains only the circuits that modify ledger state. These are the circuits that generate ZK proofs:

```typescript
export type ImpureCircuits<PS> = {
  post(
    context: __compactRuntime.CircuitContext<PS>,
    newMessage: string
  ): __compactRuntime.CircuitResults<PS, []>;

  takeDown(
    context: __compactRuntime.CircuitContext<PS>
  ): __compactRuntime.CircuitResults<PS, string>;
}
```

**`PureCircuits`** contains only pure circuits. Pure circuits are stateless functions -- they have no `CircuitContext` parameter and return plain values, not wrapped in `CircuitResults`:

```typescript
export type PureCircuits = {
  add(a: bigint, b: bigint): bigint;
}
```

### Contract<T, W>

The `Contract` class ties everything together. It is parameterized by the private state type `T` and an optional witness type `W`:

```typescript
export declare class Contract<PS = any, W extends Witnesses<PS> = Witnesses<PS>> {
  witnesses: W;
  circuits: Circuits<PS>;
  impureCircuits: ImpureCircuits<PS>;
  constructor(witnesses: W);
  initialState(
    context: __compactRuntime.ConstructorContext<PS>
  ): __compactRuntime.ConstructorResult<PS>;
}
```

Key members:

| Member | Description |
|--------|-------------|
| `witnesses` | The witness implementations passed to the constructor |
| `circuits` | All exported circuits (pure + impure) |
| `impureCircuits` | Only the impure circuits |
| `initialState(context)` | Executes the contract constructor, producing initial ledger and private state |

The `initialState` method corresponds to the Compact `constructor` block. It takes a `ConstructorContext<PS>` (containing the initial private state and Zswap local state) and returns a `ConstructorResult<PS>` containing:

| Field | Type | Description |
|-------|------|-------------|
| `currentContractState` | `ContractState` | The contract's initial ledger (public state) |
| `currentPrivateState` | `PS` | The contract's initial private state, potentially modified by constructor witnesses |
| `currentZswapLocalState` | `EncodedZswapLocalState` | The contract's initial Zswap local state |

### Ledger Type and ledger() Constructor

The `Ledger` type provides a view into the current on-chain state. It has one field for each exported ledger declaration:

```typescript
export type Ledger = {
  readonly state: State;
  readonly message: { is_some: boolean; value: string };
  readonly sequence: bigint;
  readonly owner: Uint8Array;
}
```

Ledger fields for data-structure types (like `Counter`, `Map`, `Set`, `MerkleTree`) expose their read operations as methods. For example, a `Counter` appears as `bigint` (its current value), while a `Map` or `Set` exposes methods like `member()`, `lookup()`, and `[Symbol.iterator]()`.

The `ledger()` function constructs a `Ledger` instance from raw state data:

```typescript
export declare function ledger(state: __compactRuntime.StateValue): Ledger;
```

This is how DApps read the current contract state:

```typescript
import { ledger } from './managed/bboard/contract/index.js';

const currentLedger = ledger(contractState.data);
console.log(currentLedger.state);     // State.VACANT or State.OCCUPIED
console.log(currentLedger.sequence);  // bigint value
```

### pureCircuits Constant

Pure circuits are also available as a standalone export, separate from the `Contract` class. Since they are stateless (no ledger access, no witnesses), they can be called without instantiating a contract:

```typescript
export declare const pureCircuits: PureCircuits;
```

Usage:

```typescript
import { pureCircuits } from './managed/myContract/contract/index.js';

const result = pureCircuits.add(10n, 20n);  // 30n
```

## index.js -- JavaScript Implementation

The generated JavaScript implementation file (`index.js` or `index.cjs`) is a CommonJS module that implements all the types and logic declared in `index.d.ts`. It has four sections.

### Section 1: Runtime Version and Field Validation

The file begins with safety checks ensuring the installed `@midnight-ntwrk/compact-runtime` matches what the compiler expected:

```javascript
'use strict';
const __compactRuntime = require('@midnight-ntwrk/compact-runtime');

const expectedRuntimeVersionString = '0.8.1';
const expectedRuntimeVersion = expectedRuntimeVersionString.split('-')[0].split('.').map(Number);
const actualRuntimeVersion = __compactRuntime.versionString.split('-')[0].split('.').map(Number);
if (expectedRuntimeVersion[0] != actualRuntimeVersion[0] || /* ... */)
  throw new __compactRuntime.CompactError(`Version mismatch: ...`);

{
  const MAX_FIELD = 52435875175126190479447740508185965837690552500527637822603658699938581184512n;
  if (__compactRuntime.MAX_FIELD !== MAX_FIELD)
    throw new __compactRuntime.CompactError(
      `compiler thinks maximum field value is ${MAX_FIELD}; ` +
      `run time thinks it is ${__compactRuntime.MAX_FIELD}`
    );
}
```

The `MAX_FIELD` constant is the maximum value of the BLS12-381 scalar field (the prime modulus minus one). This check ensures the proof system's field matches the compilation target. A mismatch would mean that values valid at compile time could be invalid at runtime, or vice versa.

The runtime version check validates that the major version matches and the minor version is at least what the compiler expects. Pre-release suffixes (after `-`) are stripped before comparison.

### Section 2: Type Descriptors

Next, the file defines type descriptors that encode and decode values between JavaScript representations and the ledger's field-aligned binary format:

```javascript
var State;
(function (State) {
  State[State['VACANT'] = 0] = 'VACANT';
  State[State['OCCUPIED'] = 1] = 'OCCUPIED';
})(State = exports.State || (exports.State = {}));

const _descriptor_0 = new __compactRuntime.CompactTypeEnum(1, 1);
const _descriptor_1 = new __compactRuntime.CompactTypeUnsignedInteger(18446744073709551615n, 8);
const _descriptor_2 = new __compactRuntime.CompactTypeBytes(32);
const _descriptor_3 = new __compactRuntime.CompactTypeBoolean();
const _descriptor_4 = new __compactRuntime.CompactTypeOpaqueString();
```

Each `_descriptor_*` object implements the `CompactType<T>` interface from `@midnight-ntwrk/compact-runtime`:

| Descriptor Class | Compact Type | TypeScript Type |
|-----------------|--------------|-----------------|
| `CompactTypeField` | `Field` | `bigint` |
| `CompactTypeBoolean` | `Boolean` | `boolean` |
| `CompactTypeBytes(n)` | `Bytes<N>` | `Uint8Array` |
| `CompactTypeUnsignedInteger(max, len)` | `Uint<N>` | `bigint` |
| `CompactTypeEnum(maxValue, length)` | `enum` | `number` |
| `CompactTypeOpaqueString()` | `Opaque<"string">` | `string` |
| `CompactTypeVector(length, type)` | `Vector<N, T>` | `T[]` |

Composite types like `Maybe` and `Either` are represented as inline classes that combine primitive descriptors:

```javascript
class _Maybe_0 {
  alignment() {
    return _descriptor_3.alignment().concat(_descriptor_4.alignment());
  }
  fromValue(value_0) {
    return {
      is_some: _descriptor_3.fromValue(value_0),
      value: _descriptor_4.fromValue(value_0)
    };
  }
  toValue(value_0) {
    return _descriptor_3.toValue(value_0.is_some)
      .concat(_descriptor_4.toValue(value_0.value));
  }
}
```

Each descriptor provides three methods:
- `alignment()` -- returns the field-aligned binary layout for the type
- `fromValue(value)` -- converts from ledger binary representation to JavaScript
- `toValue(value)` -- converts from JavaScript to ledger binary representation

### Section 3: Contract Class

The `Contract` class mirrors the Compact contract's entry points. Each exported circuit is wrapped in a method that validates inputs, prepares proof data, and executes the circuit logic:

```javascript
class Contract {
  constructor(witnesses) {
    this.witnesses = witnesses;
    this.circuits = {
      post: (...args) => {
        const context = args[0];
        const newMessage = args[1];
        const partialProofData = {
          input: {
            value: _descriptor_4.toValue(newMessage),
            alignment: _descriptor_4.alignment()
          },
          output: undefined,
          publicTranscript: [],
          privateTranscriptOutputs: []
        };
        const result = this._post_0(context, partialProofData, newMessage);
        return { result, context, proofData: partialProofData };
      },
      // ... other circuits
    };
    this.impureCircuits = { /* same impure circuits */ };
  }
  // ... internal circuit implementations, query helpers, finalize()
}
```

When you call `contract.circuits.post(context, message)`, the wrapper:

1. Validates input types using the appropriate descriptor
2. Encodes data for the ZK circuit via `toValue()`
3. Executes the Compact logic
4. Returns structured results including proof data for verification

The class also contains:
- Internal circuit implementations (prefixed with `_`) that contain the actual logic
- Helper methods generated for `map`, `fold`, and structural equality operations
- The private `#query` method for ledger reads and the `finalize()` method for collecting transcripts

### Section 4: Exports

The file ends with exports and a source map reference:

```javascript
exports.Contract = Contract;
exports.State = State;
exports.ledger = ledger;
exports.pureCircuits = pureCircuits;
//# sourceMappingURL=index.js.map
```

## index.js.map -- Source Map

The source map file links the generated JavaScript back to the original `.compact` source file. This enables stepping through Compact source code in VS Code and other debuggers, even though the runtime is executing JavaScript.

The source map follows the standard Source Map v3 format:

```json
{
  "file": "index.js",
  "sourceRoot": "../../",
  "sources": ["src/bboard.compact"],
  "mappings": "AAAA;AACA;..."
}
```

Key fields:

| Field | Description |
|-------|-------------|
| `file` | The generated JavaScript file this map applies to |
| `sourceRoot` | Relative path from the generated JS to the source directory |
| `sources` | Array of original source files (typically one `.compact` file) |
| `mappings` | VLQ-encoded position mappings between generated and source |

The `sourceRoot` field contains the relative path from the generated JavaScript file to the directory containing the original Compact source. If the project structure places `gen/contract/index.js` and `src/bboard.compact` relative to the project root, the `sourceRoot` would be `../../`.

If your project structure differs from the default, use the `--sourceRoot` compiler flag to override the relative path:

```bash
compactc --sourceRoot '../../' src/myContract.compact gen
```

## The Contract<T> Generic Parameter

The `T` (or `PS` -- "private state") type parameter is defined by the DApp developer in TypeScript, not in Compact. The Compact contract has no knowledge of the private state structure -- that is entirely a client-side concern.

The DApp defines a private state type and passes it when instantiating the contract:

```typescript
// DApp defines the private state type
type BBoardPrivateState = {
  readonly secretKey: Uint8Array;
};

// Instantiate with the private state type
const contract = new Contract<BBoardPrivateState>(witnesses);
```

The private state flows through the system as follows:

1. The `Contract<PS>` class carries the type parameter
2. `Circuits<PS>` and `ImpureCircuits<PS>` use it in `CircuitContext<PS>`
3. `Witnesses<PS>` use it in `WitnessContext<Ledger, PS>` and the `[PS, R]` return type
4. When a circuit calls a witness, the runtime passes the current private state and receives an updated private state in return

This design keeps the Compact language focused on on-chain logic while letting the TypeScript DApp define whatever private state structure it needs. A simple counter might use `{ privateCounter: number }`, while a complex DApp might use nested maps and complex structures.

## pureCircuits vs impureCircuits

The generated TypeScript separates circuits into two categories based on whether they interact with ledger state:

### pureCircuits

Pure circuits are stateless functions that can be called without a contract instance. They are exported as a standalone constant:

```typescript
import { pureCircuits } from './managed/myContract/contract/index.js';

// No contract instance needed
const sum = pureCircuits.add(10n, 20n);
```

Pure circuit characteristics:
- No `CircuitContext` parameter
- No access to ledger state or witnesses
- Return plain values (not wrapped in `CircuitResults`)
- Can be called anywhere, anytime, without setup
- Do not generate ZKIR files or prover/verifier keys

### impureCircuits

Impure circuits require a contract instance because they read or modify ledger state. They need a `CircuitContext` and return `CircuitResults`:

```typescript
import { Contract, ledger } from './managed/counter/contract/index.js';

const contract = new Contract<MyPrivateState>(witnesses);
// ... set up initial state and circuit context ...

// Requires context; returns CircuitResults
const result = contract.impureCircuits.increment(circuitContext);
const newLedger = ledger(result.context.currentQueryContext.state);
```

Impure circuit characteristics:
- First parameter is always `CircuitContext<PS>`
- Return `CircuitResults<PS, R>` wrapping the result, updated context, and proof data
- Each impure circuit has a corresponding ZKIR file and prover/verifier key pair
- Generate ZK proofs when called in a transaction

### circuits (Union)

The `circuits` member on the `Contract` class contains all exported circuits, both pure and impure. When called through `circuits`, pure circuits still receive a `CircuitContext` and return `CircuitResults` -- they are wrapped to match the unified interface. Use `pureCircuits` directly when you want the simpler unwrapped interface.

## Usage Patterns

### Instantiating a Contract

```typescript
import {
  constructorContext,
  createCircuitContext,
  sampleContractAddress,
} from '@midnight-ntwrk/compact-runtime';
import { Contract, type Ledger, ledger } from './managed/bboard/contract/index.js';

type MyPrivateState = { readonly secretKey: Uint8Array };

const witnesses = {
  localSecretKey: ({ privateState }: WitnessContext<Ledger, MyPrivateState>):
    [MyPrivateState, Uint8Array] =>
    [privateState, privateState.secretKey],
};

const contract = new Contract<MyPrivateState>(witnesses);
const {
  currentPrivateState,
  currentContractState,
  currentZswapLocalState,
} = contract.initialState(
  constructorContext({ secretKey: myKey }, '0'.repeat(64))
);
```

### Reading Ledger State

```typescript
const currentLedger = ledger(contractState.data);
console.log(currentLedger.state);     // 0 (State.VACANT)
console.log(currentLedger.message);   // { is_some: false, value: '' }
console.log(currentLedger.sequence);  // 1n
console.log(currentLedger.owner);     // Uint8Array(32)
```

### Calling Circuits in Tests

```typescript
const circuitContext = createCircuitContext(
  sampleContractAddress(),
  currentZswapLocalState,
  currentContractState,
  currentPrivateState,
);

// Call an impure circuit
const result = contract.impureCircuits.post(circuitContext, 'Hello!');
const updatedLedger = ledger(result.context.currentQueryContext.state);
console.log(updatedLedger.state);   // 1 (State.OCCUPIED)
console.log(updatedLedger.message); // { is_some: true, value: 'Hello!' }
```

## Annotated Example: Bulletin Board

Given this Compact contract:

```compact
export enum State { VACANT, OCCUPIED }

export ledger state: State;
export ledger message: Maybe<Opaque<'string'>>;
export ledger sequence: Counter;
export ledger owner: Bytes<32>;

constructor() {
  state = State.VACANT;
  message = none<Opaque<'string'>>();
  sequence.increment(1);
}

witness localSecretKey(): Bytes<32>;

export circuit post(newMessage: Opaque<'string'>): [] { /* ... */ }
export circuit takeDown(): Opaque<'string'> { /* ... */ }
export circuit publicKey(sk: Bytes<32>, sequence: Bytes<32>): Bytes<32> { /* ... */ }
```

The compiler generates the following `index.d.ts` (simplified):

```typescript
import type * as __compactRuntime from '@midnight-ntwrk/compact-runtime';

// 1. Exported user-defined types
export type Maybe<a> = { is_some: boolean; value: a };

export enum State {
  VACANT = 0,
  OCCUPIED = 1
}

// 2. Witness type
export type Witnesses<PS> = {
  localSecretKey(
    context: __compactRuntime.WitnessContext<Ledger, PS>
  ): [PS, Uint8Array];
}

// 3. Circuit types
export type ImpureCircuits<PS> = {
  post(
    context: __compactRuntime.CircuitContext<PS>,
    newMessage: string
  ): __compactRuntime.CircuitResults<PS, []>;
  takeDown(
    context: __compactRuntime.CircuitContext<PS>
  ): __compactRuntime.CircuitResults<PS, string>;
}

export type PureCircuits = {
  publicKey(sk: Uint8Array, sequence: Uint8Array): Uint8Array;
}

export type Circuits<PS> = {
  post(
    context: __compactRuntime.CircuitContext<PS>,
    newMessage: string
  ): __compactRuntime.CircuitResults<PS, []>;
  takeDown(
    context: __compactRuntime.CircuitContext<PS>
  ): __compactRuntime.CircuitResults<PS, string>;
  publicKey(
    context: __compactRuntime.CircuitContext<PS>,
    sk: Uint8Array,
    sequence: Uint8Array
  ): __compactRuntime.CircuitResults<PS, Uint8Array>;
}

// 4. Contract class
export declare class Contract<PS = any, W extends Witnesses<PS> = Witnesses<PS>> {
  witnesses: W;
  circuits: Circuits<PS>;
  impureCircuits: ImpureCircuits<PS>;
  constructor(witnesses: W);
  initialState(
    context: __compactRuntime.ConstructorContext<PS>
  ): __compactRuntime.ConstructorResult<PS>;
}

// 5. Ledger
export type Ledger = {
  readonly state: State;
  readonly message: { is_some: boolean; value: string };
  readonly sequence: bigint;
  readonly owner: Uint8Array;
}

export declare function ledger(state: __compactRuntime.StateValue): Ledger;

// 6. Pure circuits as standalone functions
export declare const pureCircuits: PureCircuits;
```

Note how:
- `Opaque<'string'>` became `string`
- `Bytes<32>` became `Uint8Array`
- `Counter` became `bigint` (its readable value)
- `Maybe<Opaque<'string'>>` became `{ is_some: boolean; value: string }`
- The `publicKey` circuit appears in both `PureCircuits` and `Circuits`, but only `Circuits` wraps it with `CircuitContext` and `CircuitResults`
