# Compilation & Type Safety Review Checklist

Review checklist for the **Compilation & Type Safety** category. This covers deprecated syntax, incorrect return types, type casting errors, hallucinated API methods, and common compiler error patterns. LLM-generated Compact code is especially prone to these issues because training data contains outdated syntax and invented APIs. Apply every item below to the contract under review.

## Syntax Error Checklist

Check the contract for deprecated or invalid syntax that will cause compilation failures.

- [ ] **`Void` return type instead of `[]`.** The `Void` return type has been removed from Compact. Functions (witnesses and circuits) that return no useful value must now use `[]`, signifying the empty tuple. LLMs frequently hallucinate `Void` because it appears in older documentation and is familiar from other languages.

  ```compact
  // BAD — Void is not a valid return type
  export circuit reset(): Void {
    counter.increment(1);
  }

  // GOOD — empty tuple [] is the correct "no return value" type
  export circuit reset(): [] {
    counter.increment(1);
  }
  ```

- [ ] **Deprecated `ledger { ... }` block instead of individual `export ledger` declarations.** Older versions of Compact used a single `ledger { ... }` block to group all ledger declarations. Current Compact requires each ledger variable to be declared individually with `export ledger`.

  ```compact
  // BAD — ledger block syntax is deprecated
  ledger {
    counter: Counter;
    balances: Map<Bytes<32>, Field>;
    owner: Bytes<32>;
  }

  // GOOD — individual export ledger declarations
  export ledger counter: Counter;
  export ledger balances: Map<Bytes<32>, Field>;
  export ledger owner: Bytes<32>;
  ```

- [ ] **`Choice::variant` (Rust-style) instead of `Choice.variant` (dot notation).** Compact uses dot notation for enum/choice variant access, not Rust-style double-colon path syntax. LLMs trained on Rust code frequently produce the wrong syntax.

  ```compact
  // BAD — Rust-style double-colon path
  const status = State::Active;
  assert(state == State::Committed, "Wrong state");

  // GOOD — dot notation
  const status = State.Active;
  assert(state == State.Committed, "Wrong state");
  ```

- [ ] **`witness name() { ... }` with a function body instead of declaration-only syntax.** In Compact, witness functions are declared in the contract with a signature only (no body). The implementation lives in the TypeScript witness provider, not in the `.compact` file. A witness declaration that includes a body will not compile.

  ```compact
  // BAD — witness with a body (not valid in Compact)
  witness local_secret_key() {
    return generateSecretKey();
  }

  // GOOD — witness declaration only; body is in TypeScript
  witness local_secret_key(): Bytes<32>;
  ```

- [ ] **`pure function` instead of `pure circuit`.** Compact does not have a `function` keyword. Reusable non-exported logic is declared as a `circuit` (or `pure circuit` for circuits that do not access ledger state). LLMs frequently hallucinate `function` because it is ubiquitous in other languages.

  ```compact
  // BAD — function keyword does not exist in Compact
  pure function computeHash(input: Bytes<32>): Bytes<32> {
    return persistentHash<Bytes<32>>(input);
  }

  // GOOD — pure circuit is the correct keyword
  pure circuit computeHash(input: Bytes<32>): Bytes<32> {
    return persistentHash<Bytes<32>>(input);
  }
  ```

- [ ] **`Cell<T>` used as a type.** `Cell<T>` is not a valid Compact type. LLMs sometimes hallucinate it from Rust or other ZK language patterns. Use the type directly for ledger declarations.

  ```compact
  // BAD — Cell<T> is not a Compact type
  export ledger owner: Cell<Bytes<32>>;
  export ledger threshold: Cell<Field>;

  // GOOD — use the type directly
  export ledger owner: Bytes<32>;
  export ledger threshold: Field;
  ```

- [ ] **`let` or `var` instead of `const`.** Compact only supports `const` for variable bindings. There is no `let` or `var` keyword. All bindings are immutable once assigned.

  ```compact
  // BAD — let and var are not valid keywords
  let result = computeHash(input);
  var total = counter.read();

  // GOOD — const is the only variable binding keyword
  const result = computeHash(input);
  const total = counter.read();
  ```

- [ ] **`while` loop instead of bounded `for` loop.** Compact does not support `while` loops because circuits must have compile-time-bounded execution. Only `for` loops with compile-time-known bounds are allowed. An unbounded loop would make proof generation impossible.

  ```compact
  // BAD — while loops are not allowed (unbounded execution)
  while (i < n) {
    process(items[i]);
    i = i + 1;
  }

  // GOOD — for loop with compile-time bound
  for (const i = 0; i < 10; i++) {
    process(items[i]);
  }
  ```

- [ ] **Missing `import CompactStandardLibrary;` statement.** Compact contracts that use standard library types (`Counter`, `Map`, `Set`, `MerkleTree`, `HistoricMerkleTree`, `Vector`, etc.) must import the standard library. Without this import, all standard library types and functions are undefined.

  ```compact
  // BAD — missing import; Counter and Map are undefined
  export ledger counter: Counter;
  export ledger balances: Map<Bytes<32>, Field>;

  // GOOD — import standard library first
  import CompactStandardLibrary;

  export ledger counter: Counter;
  export ledger balances: Map<Bytes<32>, Field>;
  ```

- [ ] **`include "std"` (deprecated) instead of `import CompactStandardLibrary;`.** Older versions of Compact used `include "std"` or similar include directives. The current syntax is `import CompactStandardLibrary;`. LLMs trained on older documentation frequently produce the deprecated form.

  ```compact
  // BAD — deprecated include syntax
  include "std";

  // GOOD — current import syntax
  import CompactStandardLibrary;
  ```

## Semantic Error Checklist

Check the contract for code that is syntactically valid but semantically incorrect, causing compiler rejections or runtime failures.

- [ ] **Implicit disclosure of witness value at a public boundary.** When a witness-derived value flows to a public context (ledger write, return from exported circuit, public assertion) without an explicit `disclose()` call, the compiler rejects the code. This is the most common semantic error in Compact. The fix is to add `disclose()` at the point where the value crosses the public boundary.

  ```compact
  // BAD — witness value written to ledger without disclose()
  witness get_owner(): Bytes<32>;

  export circuit initialize(): [] {
    const owner_pk = get_owner();
    authority = owner_pk;
    // Compiler error: implicit disclosure of witness value
  }

  // GOOD — explicit disclose() at the public boundary
  export circuit initialize(): [] {
    const owner_pk = get_owner();
    authority = disclose(owner_pk);
  }
  ```

- [ ] **Recursive circuit calls.** Circuits in Compact cannot call themselves, either directly or through mutual recursion. The compiler rejects recursive circuit definitions because ZK circuits must have a fixed, finite structure that can be flattened into constraints. If you need iterative logic, use a bounded `for` loop instead.

  ```compact
  // BAD — recursive circuit call (not allowed)
  circuit factorial(n: Uint<64>): Uint<64> {
    if (n == 0) {
      return 1;
    }
    return n * factorial(n - 1);
    // Compiler error: recursive circuit call
  }

  // GOOD — use bounded iteration instead
  circuit factorial(n: Uint<64>): Uint<64> {
    const result = 1;
    for (const i = 1; i <= 20; i++) {
      // Bounded loop with compile-time limit
      result = (i <= n) ? result * i : result;
    }
    return result;
  }
  ```

- [ ] **Mutable reassignment of a `const` binding.** All variable bindings in Compact use `const` and are immutable. Attempting to reassign a previously bound variable is a compiler error. If you need to compute a new value from an existing one, bind it to a new `const` with a different name.

  ```compact
  // BAD — reassigning a const binding
  const total = balances.lookup(account);
  total = total + amount;
  // Compiler error: cannot reassign const binding

  // GOOD — bind to a new const
  const current_total = balances.lookup(account);
  const new_total = current_total + amount;
  ```

- [ ] **Non-exported circuit returning witness data that crosses a public boundary.** If a non-exported circuit receives witness-tainted data and returns it, the caller may unknowingly pass that tainted data to a public context. The compiler tracks taint through the call chain. Ensure that `disclose()` is applied at the appropriate point before the data reaches a ledger write or exported circuit return.

  ```compact
  // BAD — helper circuit returns tainted data; caller writes to ledger
  circuit computeKey(): Bytes<32> {
    const sk = local_secret_key();
    return publicKey(sk);
    // Return value is witness-tainted
  }

  export circuit register(): [] {
    const pk = computeKey();
    authority = pk;
    // Compiler error: implicit disclosure of witness value
  }

  // GOOD — disclose at the public boundary in the caller
  export circuit register(): [] {
    const pk = computeKey();
    authority = disclose(pk);
  }
  ```

- [ ] **Constructor accessing witnesses.** Constructors in Compact cannot access witness functions. Witnesses are only available during circuit execution (transaction time), not during contract deployment. If the constructor needs initial values, they must be passed as constructor parameters or set to default values.

  ```compact
  // BAD — constructor calling a witness function
  constructor() {
    const sk = local_secret_key();
    // Compiler error: cannot access witnesses in constructor
    authority = publicKey(sk);
  }

  // GOOD — pass initial values as constructor parameters
  constructor(initial_authority: Bytes<32>) {
    authority = initial_authority;
  }
  ```

## Type Error Checklist

Check the contract for type mismatches, incorrect casts, and wrong method names that will cause compiler rejections.

- [ ] **Direct cast from `Uint<N>` to `Bytes<M>`.** Compact does not support direct casting between `Uint` and `Bytes` types. The cast must go through `Field` as an intermediate step. This is a multi-step cast requirement that LLMs frequently miss.

  ```compact
  // BAD — direct cast not supported
  const value: Uint<64> = 42;
  const result = value as Bytes<32>;
  // Compiler error: cannot cast from type Uint<64> to type Bytes<32>

  // GOOD — cast through Field as intermediate
  const value: Uint<64> = 42;
  const result = value as Field as Bytes<32>;
  ```

- [ ] **Direct cast from `Boolean` to `Field`.** `Boolean` cannot be cast directly to `Field`. The cast must go through `Uint<8>` (or another unsigned integer type) first.

  ```compact
  // BAD — direct Boolean to Field cast
  const flag: Boolean = true;
  const field_value = flag as Field;
  // Compiler error: cannot cast from type Boolean to type Field

  // GOOD — cast through Uint<8> as intermediate
  const flag: Boolean = true;
  const field_value = flag as Uint<8> as Field;
  ```

- [ ] **Relational operators (`<`, `>`, `<=`, `>=`) used on `Field` type.** The `Field` type does not support relational (ordering) operators because field elements do not have a natural total ordering. If you need to compare field values, cast them to `Uint<N>` first where ordering is defined.

  ```compact
  // BAD — relational operators not supported on Field
  const a: Field = 10;
  const b: Field = 20;
  assert(a < b, "a must be less than b");
  // Compiler error: operation "<" undefined for Field

  // GOOD — cast to Uint for comparison
  const a: Field = 10;
  const b: Field = 20;
  assert(a as Uint<64> < b as Uint<64>, "a must be less than b");
  ```

- [ ] **Mixing `Field` and `Uint<N>` in arithmetic expressions.** Compact does not implicitly convert between `Field` and `Uint<N>`. Arithmetic operations require both operands to be the same type. Cast one operand to match the other before performing the operation.

  ```compact
  // BAD — mixing Field and Uint in arithmetic
  const field_val: Field = 100;
  const uint_val: Uint<64> = 5;
  const result = field_val + uint_val;
  // Compiler error: type mismatch in arithmetic

  // GOOD — cast one operand to match
  const field_val: Field = 100;
  const uint_val: Uint<64> = 5;
  const result = field_val + (uint_val as Field);
  ```

- [ ] **Arithmetic result type widening: `Uint<8> + Uint<8>` produces `Uint<16>`.** When two `Uint<N>` values are added, the result type widens to `Uint<2N>` to prevent overflow. This means the result may not fit back into the original type without an explicit cast. Assignments to narrower types will fail without a cast.

  ```compact
  // BAD — result is Uint<16>, cannot assign to Uint<8> without cast
  const a: Uint<8> = 100;
  const b: Uint<8> = 50;
  const c: Uint<8> = a + b;
  // Compiler error: cannot assign Uint<16> to Uint<8>

  // GOOD — explicit cast back to narrower type
  const a: Uint<8> = 100;
  const b: Uint<8> = 50;
  const c: Uint<8> = (a + b) as Uint<8>;
  ```

- [ ] **Missing generic parameters on data structure types.** Some Compact data structures require multiple generic parameters. A common mistake is omitting the depth parameter on `MerkleTree` or `HistoricMerkleTree`, which require both a depth and a leaf type.

  ```compact
  // BAD — missing depth parameter
  export ledger members: MerkleTree<Bytes<32>>;
  // Compiler error: MerkleTree requires 2 type parameters

  // GOOD — include depth and leaf type
  export ledger members: MerkleTree<16, Bytes<32>>;
  ```

- [ ] **`Counter.value()` instead of `Counter.read()`.** The `Counter` type does not have a `.value()` method. The correct method to read the current counter value is `.read()`. LLMs frequently hallucinate `.value()` from other language patterns.

  ```compact
  // BAD — .value() does not exist on Counter
  const current = counter.value();
  // Compiler error: operation "value" undefined for Counter

  // GOOD — use .read()
  const current = counter.read();
  ```

- [ ] **`Map.get(key)` instead of `Map.lookup(key)`.** The `Map` type does not have a `.get()` method. The correct method to retrieve a value by key is `.lookup(key)`. LLMs hallucinate `.get()` from JavaScript `Map` or other language standard libraries.

  ```compact
  // BAD — .get() does not exist on Map
  const balance = balances.get(account);
  // Compiler error: operation "get" undefined for Map

  // GOOD — use .lookup()
  const balance = balances.lookup(account);
  ```

- [ ] **`Map.has(key)` instead of `Map.member(key)`.** The `Map` type does not have a `.has()` method. The correct method to check whether a key exists is `.member(key)`. LLMs hallucinate `.has()` from JavaScript `Map` or similar APIs.

  ```compact
  // BAD — .has() does not exist on Map
  if (balances.has(account)) {
    // ...
  }
  // Compiler error: operation "has" undefined for Map

  // GOOD — use .member()
  if (balances.member(account)) {
    // ...
  }
  ```

## Common Hallucination Traps

Check the contract for functions and types that LLMs commonly invent but do not exist in Compact. These are the most frequent hallucinations found in LLM-generated Compact code.

- [ ] **`hash()` instead of `persistentHash<T>()` or `transientHash<T>()`.** There is no generic `hash()` function in Compact. The correct functions are `persistentHash<T>()` (deterministic, for values that must be reproducible) or `transientHash<T>()` (non-deterministic, for one-time use). Both require an explicit type parameter.

  ```compact
  // BAD — hash() does not exist
  const h = hash(input);

  // GOOD — use the specific hash function with type parameter
  const h = persistentHash<Bytes<32>>(input);
  // or
  const h = transientHash<Bytes<32>>(input);
  ```

- [ ] **`verify()` as a general verification function.** There is no general `verify()` function in Compact. Verification is done through `assert()` for condition checks, `checkRoot()` for Merkle tree root verification, or specific cryptographic operations. LLMs invent `verify()` because it sounds natural.

  ```compact
  // BAD — verify() does not exist
  verify(proof, publicInput);
  verify(signature, message, publicKey);

  // GOOD — use assert() for condition checks
  assert(condition, "Verification failed");
  // GOOD — use checkRoot() for Merkle verification
  assert(tree.checkRoot(disclose(root)), "Invalid root");
  ```

- [ ] **`encrypt()` / `decrypt()` functions.** Compact does not provide encryption or decryption operations. Privacy in Midnight is achieved through the zero-knowledge proof system and the `disclose()` mechanism, not through encryption. If data must be hidden, use commitments (`persistentCommit`) or keep it off-chain in witness state.

  ```compact
  // BAD — encrypt/decrypt do not exist in Compact
  const ciphertext = encrypt(plaintext, key);
  const decrypted = decrypt(ciphertext, key);

  // GOOD — use commitments for hiding data
  const salt = get_randomness();
  const hidden = persistentCommit<Field>(value, salt);
  ```

- [ ] **`random()` function.** There is no `random()` function available in Compact circuits. Circuits are deterministic by nature. Randomness must be sourced from a witness function (e.g., `get_randomness()`) which runs outside the circuit in the TypeScript witness provider.

  ```compact
  // BAD — random() does not exist in circuits
  const nonce = random();

  // GOOD — source randomness from a witness function
  witness get_randomness(): Bytes<32>;
  // Then in a circuit:
  const nonce = get_randomness();
  ```

- [ ] **`public_key()` instead of `publicKey()`.** The correct function name uses camelCase, not snake_case. The function signature is `publicKey(secretKey, domain)` or derived from a domain-separated hash. LLMs sometimes generate `public_key()` due to snake_case conventions in other languages.

  ```compact
  // BAD — wrong function name (snake_case)
  const pk = public_key(sk);

  // GOOD — correct camelCase function name
  const pk = publicKey(sk);
  ```

- [ ] **`CurvePoint` instead of `EllipticCurvePoint`.** The correct type name for elliptic curve points in Compact is `EllipticCurvePoint`, not `CurvePoint`. LLMs abbreviate the type name because `CurvePoint` is shorter and feels natural.

  ```compact
  // BAD — CurvePoint is not a valid type
  const point: CurvePoint = computePoint(scalar);

  // GOOD — use the full type name
  const point: EllipticCurvePoint = computePoint(scalar);
  ```

- [ ] **`CoinInfo` instead of `ShieldedCoinInfo` or `QualifiedShieldedCoinInfo`.** The correct type names for coin information in Compact are `ShieldedCoinInfo` or `QualifiedShieldedCoinInfo`, not `CoinInfo`. LLMs simplify the type name because `CoinInfo` is shorter.

  ```compact
  // BAD — CoinInfo is not a valid type
  const coin: CoinInfo = getCoinDetails();

  // GOOD — use the correct type name
  const coin: ShieldedCoinInfo = getCoinDetails();
  // or
  const coin: QualifiedShieldedCoinInfo = getQualifiedCoinDetails();
  ```

## Compiler Error Quick Reference

Quick reference of common compiler error patterns, their likely causes, and fixes.

| Error Pattern | Likely Cause | Fix |
|---|---|---|
| `implicit disclosure of witness value` | Witness-derived value flows to a public context (ledger write, return from exported circuit) without `disclose()` | Add `disclose()` at the point where the value crosses the public boundary |
| `found "{" looking for ";"` | Void return type used (e.g., `circuit foo(): Void {`) or deprecated ledger block syntax (`ledger { ... }`) | Use `[]` as the return type for circuits that return nothing; use individual `export ledger` declarations |
| `cannot cast from type X to type Y` | Direct cast between incompatible types (e.g., `Uint<64>` to `Bytes<32>`, or `Boolean` to `Field`) | Use multi-step cast via `Field` as intermediate: `x as Field as Bytes<32>` |
| `operation "value" undefined for Counter` | Using `.value()` instead of `.read()` on a `Counter` | Replace `.value()` with `.read()` |
| `operation "get" undefined for Map` | Using `.get(key)` instead of `.lookup(key)` on a `Map` | Replace `.get()` with `.lookup()` |
| `operation "has" undefined for Map` | Using `.has(key)` instead of `.member(key)` on a `Map` | Replace `.has()` with `.member()` |
| `recursive circuit call` | A circuit calls itself directly or through mutual recursion | Refactor to use bounded `for` loops or restructure logic to avoid recursion |
| `type X requires N type parameters` | Missing generic parameters on a data structure (e.g., `MerkleTree<Bytes<32>>` instead of `MerkleTree<16, Bytes<32>>`) | Add all required type parameters; check documentation for the type's full generic signature |
| `type mismatch` in arithmetic | Mixing `Field` and `Uint<N>` in the same expression without casting | Cast one operand to match the other: `field_val + (uint_val as Field)` |
| `cannot assign Uint<2N> to Uint<N>` | Arithmetic widening — `Uint<8> + Uint<8>` produces `Uint<16>` | Add explicit cast to narrow the result: `(a + b) as Uint<8>` |
| `unknown type "Void"` | Using `Void` as a return type | Replace `Void` with `[]` (empty tuple) |
| `unknown function "hash"` | Using `hash()` instead of `persistentHash<T>()` or `transientHash<T>()` | Use the correct hash function with explicit type parameter |
| `witnesses not available in constructor` | Constructor body calls a witness function | Remove witness calls from constructor; pass initial values as constructor parameters |
| `operation "<" undefined for Field` | Using relational operators on `Field` type | Cast to `Uint<N>` before comparison: `(a as Uint<64>) < (b as Uint<64>)` |
