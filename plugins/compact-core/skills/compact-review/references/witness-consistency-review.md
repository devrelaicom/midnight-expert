# Witness-Contract Consistency Review Checklist

Review checklist for the **Witness-Contract Consistency** category. This bridges the Compact contract layer with the TypeScript witness layer. A mismatch between the two causes runtime failures that the Compact compiler cannot catch because the TypeScript side is outside its scope. Apply every item below to the contract and its corresponding witness implementation.

## Name Matching Checklist

Check that every witness declared in the Compact contract has a corresponding key in the TypeScript `witnesses` object.

- [ ] **Every `witness` declaration in the Compact contract has a matching key in the TypeScript `witnesses` object.** The runtime resolves witness functions by name at proof generation time. A missing key means the prover cannot find the function, and proof generation fails with a runtime error. There is no compile-time check for this — it only fails when a circuit that calls the witness is actually invoked.

  ```compact
  // Compact contract — declares three witnesses
  witness local_secret_key(): Bytes<32>;
  witness get_balance(account: Bytes<32>): Uint<64>;
  witness store_result(value: Field): [];
  ```

  ```typescript
  // BAD — missing get_balance; runtime failure when any circuit calls it
  export const witnesses = {
    local_secret_key: ({ privateState }: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => {
      return [privateState, privateState.secretKey];
    },
    store_result: (
      { privateState }: WitnessContext<Ledger, MyState>,
      value: bigint,
    ): [MyState, []] => {
      return [{ ...privateState, lastResult: value }, []];
    },
    // get_balance is MISSING — runtime failure
  };

  // GOOD — all three witnesses implemented
  export const witnesses = {
    local_secret_key: ({ privateState }: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => {
      return [privateState, privateState.secretKey];
    },
    get_balance: (
      { privateState }: WitnessContext<Ledger, MyState>,
      account: Uint8Array,
    ): [MyState, bigint] => {
      const balance = privateState.balances.get(toHex(account));
      if (balance === undefined) {
        throw new Error("Account not found in private state");
      }
      return [privateState, balance];
    },
    store_result: (
      { privateState }: WitnessContext<Ledger, MyState>,
      value: bigint,
    ): [MyState, []] => {
      return [{ ...privateState, lastResult: value }, []];
    },
  };
  ```

- [ ] **Witness names match exactly, including casing.** Witness lookup is case-sensitive. A witness declared as `local_secret_key` in Compact must have the key `local_secret_key` in the TypeScript `witnesses` object — not `localSecretKey`, `LOCAL_SECRET_KEY`, or any other variation. This is a common mistake when developers apply JavaScript naming conventions to witness keys.

  ```compact
  // Compact
  witness local_secret_key(): Bytes<32>;
  witness get_merkle_path(leaf: Bytes<32>): MerkleTreePath<16, Bytes<32>>;
  ```

  ```typescript
  // BAD — camelCase does not match Compact's snake_case declaration
  export const witnesses = {
    localSecretKey: ({ privateState }: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => {
      return [privateState, privateState.secretKey];
    },
    getMerklePath: (
      { privateState }: WitnessContext<Ledger, MyState>,
      leaf: Uint8Array,
    ): [MyState, MerkleTreePath] => {
      return [privateState, computePath(leaf)];
    },
  };

  // GOOD — keys match Compact declarations exactly
  export const witnesses = {
    local_secret_key: ({ privateState }: WitnessContext<Ledger, MyState>): [MyState, Uint8Array] => {
      return [privateState, privateState.secretKey];
    },
    get_merkle_path: (
      { privateState }: WitnessContext<Ledger, MyState>,
      leaf: Uint8Array,
    ): [MyState, MerkleTreePath] => {
      return [privateState, computePath(leaf)];
    },
  };
  ```

- [ ] **No extra witness keys in the TypeScript object that do not exist in the Compact contract.** Extra keys are silently ignored by the runtime but indicate a maintenance problem. They may be leftover from a refactor where a witness was removed from the Compact contract but not from the TypeScript side, or they may indicate a naming mismatch where the developer thinks they implemented a witness but the key does not match.

- [ ] **Witness parameter count and order match the Compact declaration.** After the `WitnessContext` first parameter, the remaining parameters must match the Compact declaration in both count and order. The circuit passes arguments positionally. A mismatch means the witness receives the wrong values.

  ```compact
  // Compact — two parameters: account then amount
  witness transfer_private(account: Bytes<32>, amount: Uint<64>): Boolean;
  ```

  ```typescript
  // BAD — parameters in wrong order
  transfer_private: (
    { privateState }: WitnessContext<Ledger, MyState>,
    amount: bigint,     // Should be account (Uint8Array)
    account: Uint8Array, // Should be amount (bigint)
  ): [MyState, boolean] => {
    // ...
  },

  // GOOD — parameters match Compact declaration order
  transfer_private: (
    { privateState }: WitnessContext<Ledger, MyState>,
    account: Uint8Array, // Matches first param: Bytes<32>
    amount: bigint,      // Matches second param: Uint<64>
  ): [MyState, boolean] => {
    // ...
  },
  ```

## Type Mapping Correctness Checklist

Check that Compact types are correctly translated to their TypeScript equivalents in witness parameter types and return types.

- [ ] **All Compact-to-TypeScript type mappings are correct.** Every witness parameter type and return type must use the correct TypeScript representation. The table below is the authoritative mapping. A type mismatch causes proof generation failure or silently incorrect data.

  | Compact Type | TypeScript Type | Common Mistake |
  |---|---|---|
  | `Field` | `bigint` | Using `number` (loses precision for values > 2^53) |
  | `Boolean` | `boolean` | Correct |
  | `Uint<N>` | `bigint` | Using `number` (loses precision for large N) |
  | `Bytes<N>` | `Uint8Array` | Using `string` or `Buffer` |
  | `Opaque<"string">` | `string` | Correct |
  | `Opaque<"Uint8Array">` | `Uint8Array` | Correct |
  | `Maybe<T>` | `{ is_some: boolean; value: T }` | Using `T \| null` or `T \| undefined` (WRONG -- must use tagged object) |
  | `Either<L, R>` | `{ tag: "left"; value: L } \| { tag: "right"; value: R }` | Using `L \| R` union (WRONG -- must use tagged discriminated union) |
  | `Vector<N, T>` | `T[]` (length N) | Not checking array length matches N |
  | Struct `{ x: Field; y: Boolean }` | `{ x: bigint; y: boolean }` | Field names must match exactly |
  | Enum | `bigint` variant index | Mapping variants to wrong indices |
  | `[T1, T2]` (tuple) | `[T1_mapped, T2_mapped]` | Wrong element order |

- [ ] **`Field` and `Uint<N>` use `bigint`, not `number`.** JavaScript `number` is a 64-bit floating-point type that loses precision for integers above 2^53. Compact `Field` values can be up to the ZK field maximum (much larger). `Uint<64>` values can reach 2^64 - 1. Using `number` silently truncates large values, producing incorrect proofs.

  ```typescript
  // BAD — number loses precision for large values
  local_balance: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, number] => {
    return [privateState, Number(privateState.balance)]; // Precision loss!
  },

  // GOOD — bigint preserves full precision
  local_balance: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint] => {
    return [privateState, privateState.balance];
  },
  ```

- [ ] **`Bytes<N>` uses `Uint8Array`, not `string` or `Buffer`.** The runtime expects `Uint8Array` for all `Bytes<N>` types. Using `string` causes a type error at proof generation. Using Node.js `Buffer` may work in some environments because `Buffer` extends `Uint8Array`, but it is not portable and can cause subtle issues in browser contexts.

  ```typescript
  // BAD — string is not Uint8Array
  local_secret_key: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, string] => {
    return [privateState, privateState.secretKeyHex]; // Wrong type
  },

  // GOOD — Uint8Array matches Bytes<32>
  local_secret_key: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, Uint8Array] => {
    return [privateState, privateState.secretKey];
  },
  ```

- [ ] **`Maybe<T>` uses the tagged object `{ is_some: boolean; value: T }`, not `T | null` or `T | undefined`.** The runtime does not understand JavaScript nullability patterns. It expects the explicit tagged object form with both `is_some` and `value` fields present, even when `is_some` is `false`. When `is_some` is `false`, the `value` field must still be present with a zero/default value of the correct type.

  ```compact
  // Compact
  witness find_record(id: Bytes<32>): Maybe<Uint<64>>;
  ```

  ```typescript
  // BAD — using null for absent values
  find_record: (
    { privateState }: WitnessContext<Ledger, MyState>,
    id: Uint8Array,
  ): [MyState, bigint | null] => {
    const record = privateState.records.get(toHex(id));
    return [privateState, record ?? null]; // WRONG — runtime expects tagged object
  },

  // GOOD — tagged object with is_some and value
  find_record: (
    { privateState }: WitnessContext<Ledger, MyState>,
    id: Uint8Array,
  ): [MyState, { is_some: boolean; value: bigint }] => {
    const record = privateState.records.get(toHex(id));
    if (record !== undefined) {
      return [privateState, { is_some: true, value: record }];
    }
    return [privateState, { is_some: false, value: 0n }];
  },
  ```

- [ ] **`Either<L, R>` uses the tagged discriminated union `{ tag: "left"; value: L } | { tag: "right"; value: R }`, not a bare union `L | R`.** The runtime uses the `tag` field to determine which variant is active. Without the tag, the runtime cannot distinguish between the two sides.

  ```compact
  // Compact
  witness classify_input(data: Bytes<32>): Either<Uint<64>, Boolean>;
  ```

  ```typescript
  // BAD — bare union with no tag
  classify_input: (
    { privateState }: WitnessContext<Ledger, MyState>,
    data: Uint8Array,
  ): [MyState, bigint | boolean] => {
    // WRONG — runtime cannot distinguish left from right
    return [privateState, isNumeric(data) ? toBigInt(data) : false];
  },

  // GOOD — tagged discriminated union
  classify_input: (
    { privateState }: WitnessContext<Ledger, MyState>,
    data: Uint8Array,
  ): [MyState, { tag: "left"; value: bigint } | { tag: "right"; value: boolean }] => {
    if (isNumeric(data)) {
      return [privateState, { tag: "left", value: toBigInt(data) }];
    }
    return [privateState, { tag: "right", value: false }];
  },
  ```

- [ ] **`Vector<N, T>` returns an array of exactly length N.** The runtime performs a length check. If the witness returns an array with fewer or more elements than the declared `N`, proof generation fails. This is especially error-prone when `N` is a compile-time constant that may change between contract versions.

  ```compact
  // Compact
  witness get_setup(): Vector<5, Field>;
  ```

  ```typescript
  // BAD — array length does not match Vector<5, ...>
  get_setup: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint[]] => {
    return [privateState, [1n, 2n, 3n]]; // Only 3 elements, needs 5
  },

  // GOOD — exactly 5 elements
  get_setup: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint[]] => {
    const setup = privateState.setup;
    if (setup.length !== 5) {
      throw new Error(`Setup must have exactly 5 elements, got ${setup.length}`);
    }
    return [privateState, setup];
  },
  ```

- [ ] **Struct field names and types match exactly.** When a witness returns a struct, the TypeScript object must have the same field names as the Compact struct definition. Extra fields are ignored but missing fields cause failures. Field types must also match the mapping table above.

  ```compact
  // Compact
  export struct UserProfile { name: Opaque<"string">; score: Uint<64>; active: Boolean }
  witness get_profile(): UserProfile;
  ```

  ```typescript
  // BAD — wrong field name ("points" instead of "score"), wrong type for active
  get_profile: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, { name: string; points: bigint; active: number }] => {
    return [privateState, {
      name: privateState.name,
      points: privateState.score,  // Wrong field name
      active: 1,                   // Wrong type: should be boolean
    }];
  },

  // GOOD — field names and types match Compact struct exactly
  get_profile: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, { name: string; score: bigint; active: boolean }] => {
    return [privateState, {
      name: privateState.name,
      score: privateState.score,
      active: privateState.active,
    }];
  },
  ```

- [ ] **Enum values use the correct `bigint` variant index.** Compact enums are represented as zero-based `bigint` indices in TypeScript. Mapping a variant to the wrong index silently produces incorrect behavior because the contract interprets a different variant than intended.

  ```compact
  // Compact
  export enum Status { pending, approved, rejected }
  witness get_decision(): Status;
  ```

  ```typescript
  // BAD — using string or wrong index
  get_decision: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint] => {
    return [privateState, 2n]; // This is "rejected", not "approved"
    // Or worse: return [privateState, "approved" as any]; // string, not bigint
  },

  // GOOD — use the compiler-generated constants
  import { Status } from "./managed/my-contract/index.cjs";

  get_decision: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint] => {
    return [privateState, BigInt(Status.approved)]; // 1n
  },
  ```

## WitnessContext Pattern Checklist

Check that witness functions correctly use the `WitnessContext` interface and return the expected tuple.

- [ ] **Every witness function takes `WitnessContext<Ledger, PrivateState>` as its first parameter.** This is not optional. The runtime always passes the context as the first argument. A witness that omits the context parameter or declares it with the wrong type will receive arguments in the wrong positions.

  ```typescript
  // BAD — missing WitnessContext as first parameter
  local_secret_key: (secretKey: Uint8Array): Uint8Array => {
    return secretKey; // Wrong: this receives the WitnessContext object, not a key
  },

  // GOOD — WitnessContext is always the first parameter
  local_secret_key: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, Uint8Array] => {
    return [privateState, privateState.secretKey];
  },
  ```

- [ ] **Witness accesses `context.privateState` for current private state.** The `privateState` field on `WitnessContext` contains the current private state for this contract instance. It is the only source of truth for private data. Do not store private state in module-level variables or closures — this breaks when multiple contract instances share the same witness code.

  ```typescript
  // BAD — module-level variable for private state (breaks with multiple instances)
  let globalSecretKey: Uint8Array;

  export const witnesses = {
    local_secret_key: (
      _context: WitnessContext<Ledger, MyState>,
    ): [MyState, Uint8Array] => {
      return [_context.privateState, globalSecretKey]; // Stale or wrong instance
    },
  };

  // GOOD — always read from context.privateState
  export const witnesses = {
    local_secret_key: (
      { privateState }: WitnessContext<Ledger, MyState>,
    ): [MyState, Uint8Array] => {
      return [privateState, privateState.secretKey];
    },
  };
  ```

- [ ] **Witness uses `context.contractAddress` where needed for per-deployment scoping.** When the same witness implementation serves multiple deployed instances of a contract, `contractAddress` distinguishes between them. Without it, private state from one deployment leaks into another.

  ```typescript
  // BAD — no scoping by contract address; all deployments share one entry
  store_data: (
    { privateState }: WitnessContext<Ledger, MyState>,
    data: bigint,
  ): [MyState, []] => {
    return [{ ...privateState, storedData: data }, []]; // Overwrites for all instances
  },

  // GOOD — scoped by contractAddress
  store_data: (
    { privateState, contractAddress }: WitnessContext<Ledger, MyState>,
    data: bigint,
  ): [MyState, []] => {
    const perContract = new Map(privateState.perContract);
    perContract.set(contractAddress, data);
    return [{ ...privateState, perContract }, []];
  },
  ```

- [ ] **Witness uses `context.ledger` (not direct ledger queries) for reading on-chain state.** The `ledger` field provides a projected view of the ledger as it would look if the transaction ran against the current local view. This is the correct way to read ledger state inside a witness. Do not make separate network calls to query ledger state — the data may be inconsistent with the proof context.

- [ ] **Return type is ALWAYS `[PrivateState, ReturnValue]` tuple — NOT just the return value.** The runtime expects every witness to return a two-element tuple where the first element is the (potentially updated) private state and the second is the declared return value. Returning only the value, or reversing the order, causes a runtime failure.

  ```typescript
  // BAD — returning only the value (not a tuple)
  local_secret_key: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): Uint8Array => {
    return privateState.secretKey; // WRONG: runtime expects [MyState, Uint8Array]
  },

  // BAD — tuple elements in wrong order
  local_secret_key: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [Uint8Array, MyState] => {
    return [privateState.secretKey, privateState]; // WRONG: state first, value second
  },

  // GOOD — [PrivateState, ReturnValue] in correct order
  local_secret_key: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, Uint8Array] => {
    return [privateState, privateState.secretKey];
  },
  ```

- [ ] **Side-effect-only witnesses (Compact return type `[]`) return `[PrivateState, []]`.** The empty tuple `[]` in the return position is the TypeScript representation of Compact's `[]` return type. Returning `undefined`, `null`, or omitting the second element is incorrect.

  ```compact
  // Compact
  witness save_locally(data: Field): [];
  ```

  ```typescript
  // BAD — returning undefined instead of []
  save_locally: (
    { privateState }: WitnessContext<Ledger, MyState>,
    data: bigint,
  ): [MyState, undefined] => {
    return [{ ...privateState, saved: data }, undefined]; // WRONG
  },

  // GOOD — empty array for [] return type
  save_locally: (
    { privateState }: WitnessContext<Ledger, MyState>,
    data: bigint,
  ): [MyState, []] => {
    return [{ ...privateState, saved: data }, []];
  },
  ```

## Private State Immutability Checklist

Check that witness functions treat private state as immutable and return new state objects rather than mutating in place.

- [ ] **Private state is updated by returning a NEW object, not by mutating the existing one in place.** The runtime treats private state as functional — each witness call receives the current state and returns a new state. Mutating the `privateState` object directly can cause unpredictable behavior because the runtime may reference the original object elsewhere. Always use the spread operator or object construction to create a new state.

  ```typescript
  // BAD — mutating privateState in place
  increment_counter: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint] => {
    privateState.counter += 1n; // MUTATION — unpredictable behavior
    return [privateState, privateState.counter];
  },

  // GOOD — returning a new state object via spread
  increment_counter: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, bigint] => {
    const newCounter = privateState.counter + 1n;
    return [{ ...privateState, counter: newCounter }, newCounter];
  },
  ```

- [ ] **Spread operator (`...`) used for shallow copies; deep clone used for nested objects.** The spread operator creates a shallow copy. If the private state contains nested objects (e.g., `Map`, arrays, nested records), the spread alone shares references to those inner objects. Modifying an inner object through the new state also modifies the old state. For nested data, create new instances of the nested structures.

  ```typescript
  // BAD — shallow spread, then mutating nested Map
  update_records: (
    { privateState }: WitnessContext<Ledger, MyState>,
    key: Uint8Array,
    value: bigint,
  ): [MyState, []] => {
    const newState = { ...privateState }; // Shallow copy
    newState.records.set(toHex(key), value); // MUTATION of shared Map reference
    return [newState, []];
  },

  // GOOD — create a new Map for the nested structure
  update_records: (
    { privateState }: WitnessContext<Ledger, MyState>,
    key: Uint8Array,
    value: bigint,
  ): [MyState, []] => {
    const newRecords = new Map(privateState.records); // New Map instance
    newRecords.set(toHex(key), value);
    return [{ ...privateState, records: newRecords }, []];
  },
  ```

- [ ] **Array state fields are copied, not pushed to or spliced in place.** Similar to nested objects, arrays in private state must be replaced, not mutated. Use the spread operator on arrays or `Array.from()` to create copies before modification.

  ```typescript
  // BAD — mutating array in place
  add_entry: (
    { privateState }: WitnessContext<Ledger, MyState>,
    entry: bigint,
  ): [MyState, []] => {
    privateState.entries.push(entry); // MUTATION of shared array
    return [privateState, []];
  },

  // GOOD — creating a new array
  add_entry: (
    { privateState }: WitnessContext<Ledger, MyState>,
    entry: bigint,
  ): [MyState, []] => {
    const newEntries = [...privateState.entries, entry]; // New array
    return [{ ...privateState, entries: newEntries }, []];
  },
  ```

- [ ] **Private state fields are marked `readonly` in the TypeScript type definition.** While `readonly` does not prevent mutation at runtime, it provides a compile-time guard that catches accidental mutations during development. This is a best practice for signaling intent.

  ```typescript
  // BAD — no readonly markers; mutations are not flagged by TypeScript
  type MyState = {
    secretKey: Uint8Array;
    counter: bigint;
    records: Map<string, bigint>;
  };

  // GOOD — readonly markers catch accidental mutations at compile time
  type MyState = {
    readonly secretKey: Uint8Array;
    readonly counter: bigint;
    readonly records: ReadonlyMap<string, bigint>;
  };
  ```

## Witness Implementation Correctness Checklist

Check witness functions for side effects, determinism, and operational issues that affect proof generation.

- [ ] **Witness should not have side effects beyond private state updates.** Witnesses run during proof generation on the client side. Side effects like writing to files, sending network requests, logging to external services, or modifying global variables make the witness non-reproducible and can leak private information. The only intended "side effect" is the private state update returned in the tuple.

  ```typescript
  // BAD — network call and logging inside witness (side effects)
  get_balance: (
    { privateState }: WitnessContext<Ledger, MyState>,
    account: Uint8Array,
  ): [MyState, bigint] => {
    console.log(`Balance queried for ${toHex(account)}`); // Leaks private info
    fetch("https://analytics.example.com/log", {           // Network side effect
      method: "POST",
      body: JSON.stringify({ account: toHex(account) }),
    });
    return [privateState, privateState.balances.get(toHex(account)) ?? 0n];
  },

  // GOOD — pure computation from private state, no side effects
  get_balance: (
    { privateState }: WitnessContext<Ledger, MyState>,
    account: Uint8Array,
  ): [MyState, bigint] => {
    return [privateState, privateState.balances.get(toHex(account)) ?? 0n];
  },
  ```

- [ ] **Witness should be deterministic for the same inputs to allow proof re-generation.** If a transaction needs to be re-proven (e.g., due to a network error or ledger state change), the witness is called again. A non-deterministic witness may produce different output on the second call, causing the new proof to differ from the first and potentially fail. Avoid `Date.now()`, `Math.random()`, or other non-deterministic sources unless the value is immediately stored in private state and reused on subsequent calls.

  ```typescript
  // BAD — uses Math.random(); different result each call
  get_nonce: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, Uint8Array] => {
    const nonce = new Uint8Array(32);
    crypto.getRandomValues(nonce); // Different on each call
    return [privateState, nonce]; // Re-proof produces different nonce
  },

  // GOOD — generate once, store in private state, reuse
  get_nonce: (
    { privateState }: WitnessContext<Ledger, MyState>,
  ): [MyState, Uint8Array] => {
    if (privateState.nonce) {
      return [privateState, privateState.nonce]; // Reuse stored nonce
    }
    const nonce = new Uint8Array(32);
    crypto.getRandomValues(nonce);
    return [{ ...privateState, nonce }, nonce]; // Store for re-proof
  },
  ```

- [ ] **Witness does not perform long-running or async operations that could timeout proof generation.** Witness functions are called synchronously during proof generation. Long-running computation (large data processing, complex cryptographic operations) or attempting asynchronous operations (network calls, file I/O) can cause the proof generation to timeout or fail. Keep witness logic fast and synchronous.

  ```typescript
  // BAD — async operation inside a synchronous witness
  get_merkle_proof: (
    { privateState }: WitnessContext<Ledger, MyState>,
    leaf: Uint8Array,
  ): [MyState, MerkleTreePath] => {
    // This will NOT work — witnesses are synchronous
    const proof = await fetchMerkleProof(leaf); // TypeError: await in non-async
    return [privateState, proof];
  },

  // GOOD — precompute and store in private state before proof generation
  get_merkle_proof: (
    { privateState }: WitnessContext<Ledger, MyState>,
    leaf: Uint8Array,
  ): [MyState, MerkleTreePath] => {
    const proof = privateState.precomputedProofs.get(toHex(leaf));
    if (!proof) {
      throw new Error("Merkle proof not precomputed — call prepareMerkleProof() first");
    }
    return [privateState, proof];
  },
  ```

- [ ] **Witness throws meaningful errors for invalid state rather than returning garbage values.** When a witness cannot produce a valid result (missing data, invalid state), it should throw an `Error` with a descriptive message. This aborts the transaction before proof generation, giving the developer a clear error. Returning a default or garbage value produces a proof that may pass the circuit but represent incorrect state.

  ```typescript
  // BAD — returns 0n when balance is not found (silently incorrect)
  get_balance: (
    { privateState }: WitnessContext<Ledger, MyState>,
    account: Uint8Array,
  ): [MyState, bigint] => {
    return [privateState, privateState.balances.get(toHex(account)) ?? 0n];
    // If account genuinely doesn't exist, this may produce a valid but wrong proof
  },

  // GOOD — throw when data is genuinely expected to exist
  get_balance: (
    { privateState }: WitnessContext<Ledger, MyState>,
    account: Uint8Array,
  ): [MyState, bigint] => {
    const balance = privateState.balances.get(toHex(account));
    if (balance === undefined) {
      throw new Error(`Account ${toHex(account)} not found in private state`);
    }
    return [privateState, balance];
  },
  ```

## Anti-Patterns Table

Quick reference of common witness-contract consistency anti-patterns.

| Anti-Pattern | Why It's Wrong | Correct Approach |
|---|---|---|
| Missing witness key in TypeScript `witnesses` object | Runtime cannot find the witness function; proof generation fails when any circuit calls it | Every `witness` declaration in Compact must have a matching key in the TypeScript `witnesses` object |
| camelCase key for snake_case Compact witness name | Witness lookup is case-sensitive; the key is silently not found and proof generation fails | Use the exact name from the Compact declaration, including casing |
| `number` instead of `bigint` for `Field` or `Uint<N>` | JavaScript `number` loses precision above 2^53; silently produces incorrect proofs for large values | Always use `bigint` for `Field`, `Uint<N>`, and enum variant indices |
| `string` or `Buffer` instead of `Uint8Array` for `Bytes<N>` | Runtime expects `Uint8Array`; other types cause proof generation failure or portability issues | Always use `Uint8Array` for `Bytes<N>` |
| `T \| null` for `Maybe<T>` | Runtime expects `{ is_some: boolean; value: T }` tagged object; null/undefined is not recognized | Return `{ is_some: true, value: x }` or `{ is_some: false, value: defaultValue }` |
| `L \| R` for `Either<L, R>` | Runtime uses the `tag` field to distinguish variants; a bare union has no tag | Return `{ tag: "left", value: x }` or `{ tag: "right", value: y }` |
| Returning only the value (not the `[PS, Value]` tuple) | Runtime expects a two-element tuple with private state first; single value causes destructuring failure | Always return `[privateState, returnValue]` |
| Mutating `privateState` in place | Shared reference may be used elsewhere by the runtime; in-place mutation causes unpredictable behavior | Spread and override: `{ ...privateState, field: newVal }` |
| `Math.random()` or `Date.now()` in witness | Non-deterministic; produces different output on re-proof, causing proof generation to fail on retry | Generate once and store in private state; reuse on subsequent calls |
| Async operations (`await`, `fetch`) in witness | Witnesses are synchronous; async code either fails or blocks indefinitely during proof generation | Precompute async results and store in private state before proof generation |
| Module-level variable for private state | Breaks when multiple contract instances share the same witness code; stale or wrong instance data | Always read from `context.privateState` |
| Wrong parameter order after WitnessContext | Circuit passes arguments positionally; swapped parameters mean the witness receives wrong values | Match parameter order to Compact declaration exactly |
