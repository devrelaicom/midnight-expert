# Compiler Errors

The Compact compiler produces descriptive error messages with line numbers, character positions, and explanations of what went wrong. Understanding the error categories helps debug compilation failures quickly. This reference covers every error category, how to interpret the messages, and how to fix the underlying problems.

## Parse Errors

Parse errors occur when the compiler encounters syntax it does not expect. The compiler reports the set of tokens it expected at the failure point using the format:

```
Exception: contract.compact line N char M:
  expected '[token]' but found '[token]'
```

### Common Parse Error Triggers

**Void return type.** Compact does not have a `Void` keyword. Use the empty tuple `[]` for circuits that return nothing.

```compact
// Triggers: expected ";" but found "{"
export circuit doSomething(): Void {
  count.increment(1);
}

// Fix
export circuit doSomething(): [] {
  count.increment(1);
}
```

**Double-colon enum access.** Compact uses dot notation for enum variants, not Rust-style double-colon syntax.

```compact
// Triggers: expected ")" but found ":"
if (state == State::active) { ... }

// Fix
if (state == State.active) { ... }
```

**Deprecated ledger block syntax.** The `ledger { }` block form was removed. Declare ledger fields individually.

```compact
// Triggers: expected an identifier but found "{"
ledger {
  counter: Counter;
  owner: Bytes<32>;
}

// Fix
export ledger counter: Counter;
export ledger owner: Bytes<32>;
```

**Unicode numeric characters.** The compiler only accepts ASCII digits 0-9. Unicode numeric characters from other scripts (such as Eastern Arabic numerals) produce a parse error. Before compiler version 0.25.0, these caused an internal error instead.

**`pure function` keyword.** Compact uses `pure circuit`, not `pure function`.

```compact
// Triggers: unbound identifier "function"
pure function add(a: Field, b: Field): Field {
  return a + b;
}

// Fix
export pure circuit add(a: Field, b: Field): Field {
  return a + b;
}
```

**Division operator.** Compact does not support the `/` operator. The compiler recognizes `/` as the start of a comment token and reports that it expected a binary operator like `+`, `-`, or `*`. Division must be implemented via a witness pattern.

```compact
// Triggers: parse error (compiler looks for comment syntax)
const result = x / y;

// Fix -- use a witness to compute division off-chain, then validate
witness _divMod(x: Uint<32>, y: Uint<32>): [Uint<32>, Uint<32>];

export circuit div(x: Uint<32>, y: Uint<32>): Uint<32> {
  const res = disclose(_divMod(x, y));
  const quotient = res[0];
  const remainder = res[1];
  assert(remainder < y && x == y * quotient + remainder, "Invalid division");
  return quotient;
}
```

**Witness with implementation body.** Witnesses are declarations only. They end with a semicolon and are implemented in TypeScript on the prover side.

```compact
// Triggers: expected ";" but found "{"
witness getSecret(): Field {
  return 42;
}

// Fix
witness getSecret(): Field;
```

## Type Errors

Type errors occur when the compiler cannot find a matching overload for an operation. The compiler shows the expected and actual types with consistent indentation.

### Overload Resolution Failures

When no overload matches, the compiler lists all candidates and explains why each one failed:

```
Exception: contract.compact line N char M:
  no matching overload for operator ...
    expected ... but received ...
```

### Common Type Error Triggers

**Mixing Field and Uint without casting.** `Field` and `Uint<N>` are distinct types. Arithmetic or comparison between them requires an explicit cast.

```compact
// Triggers: no matching overload -- incompatible types Field and Uint
const result = myField + myUint;

// Fix
const result = myField + (myUint as Field);
```

**Arithmetic result type expansion.** Arithmetic on `Uint<N>` values produces an expanded bounded type (`Uint<0..N>`). The result must be cast back before use in typed contexts.

```compact
// Triggers: expected Uint<64> but received Uint<0..N>
balances.insert(key, a + b);

// Fix
balances.insert(key, (a + b) as Uint<64>);
```

**Direct Uint to Bytes cast.** This cast is not allowed. Route through `Field` as an intermediate type.

```compact
// Triggers: cannot cast from type Uint<64> to type Bytes<32>
const b: Bytes<32> = amount as Bytes<32>;

// Fix -- two-step cast through Field
const b: Bytes<32> = (amount as Field) as Bytes<32>;
```

**ADT type argument errors.** Passing the wrong type to Map, Set, Counter, or other ADT operations produces overload failures. The compiler reports the expected parameter types for each ADT method. For example, calling `.insert()` on a `Map<Bytes<32>, Uint<64>>` with a `Field` value instead of `Uint<64>` produces an error listing the expected argument types.

**Generic parameter failures.** Type parameter mismatches are treated like overloading errors. The compiler shows the expected generic constraint and the actual type provided.

## Disclosure Errors

Disclosure errors occur when witness-derived values flow to public boundaries without explicit acknowledgment. The full error message reads:

```
Exception: contract.compact line N char M:
  potential witness-value disclosure must be declared but is not:
    witness value potentially disclosed:
      the return value of witness getBalance at line X char Y
    nature of the disclosure:
      ledger operation might disclose the witness value
    via this path through the program:
      the right-hand side of = at line N char M
```

### What Triggers Disclosure Errors

Any of these operations on a witness-derived value requires `disclose()`:

- **Ledger writes** -- assigning a witness value to a ledger field or passing it to a ledger ADT method (`.insert()`, `.increment()`, etc.)
- **Conditionals** -- using a witness value as the condition of an `if` statement or the basis of a comparison in an `assert`
- **Return from exported circuit** -- returning a witness-derived value from an exported circuit makes it visible to the caller
- **Cross-contract calls** -- passing witness data to another contract via composable contract calls

### How to Fix

Wrap the value or expression in `disclose()` at the point where it crosses the public boundary:

```compact
witness getBalance(): Uint<64>;
export ledger balance: Uint<64>;

// ERROR
export circuit record(): [] {
  balance = getBalance();
}

// FIX
export circuit record(): [] {
  balance = disclose(getBalance());
}
```

The compiler traces witness data through all intermediate computations, struct field accesses, and circuit calls. A single `disclose()` at the point of use is sufficient -- you do not need to disclose every intermediate variable.

For full disclosure rules and the Witness Protection Program implementation details, see the compact-privacy-disclosure skill.

## ZKIR Generation Errors

ZKIR (Zero-Knowledge Intermediate Representation) generation errors are rare issues that occur during circuit compilation, after parsing and type checking succeed.

### Index Allocation Issue

One known ZKIR generation bug involved allocating indexes for circuit arguments when their type constraints had the side effect of also allocating indexes. This was reported via Discord and affected contracts with certain type constraint patterns.

- **Compiler version affected:** Versions before 0.21.105
- **Language version affected:** 0.14.100
- **Fix:** Update to compiler version 0.21.105 or later (language version 0.14.100+)

If you encounter a ZKIR generation error on a current compiler version, update to the latest compiler first. If the error persists, it is likely a compiler bug -- report it with your source file and compiler version.

## Integer Overflow Errors

The Compact compiler detects integer literals that exceed the field modulus at compile time. The maximum value depends on the BLS12-381 elliptic curve used for zero-knowledge proofs.

### The MAX_FIELD Constant

The maximum field value is:

```
52435875175126190479447740508185965837690552500527637822603658699938581184512n
```

This is approximately 2^255. Any integer literal in a Compact contract that exceeds this value produces a compile-time error. Before compiler version 0.23.0, some cases involving large integer literals caused a crash instead of a clean error message. This has been fixed.

The `MAX_FIELD` value changed when the proof system switched from Pluto-Eris to BLS12-381 in compiler version 0.23.0. This was a breaking change -- contracts that relied on the previous maximum field value needed updating.

### How the Check Works

The generated JavaScript boilerplate includes a runtime check that the `MAX_FIELD` in `@midnight-ntwrk/compact-runtime` matches what the compiler expected:

```javascript
const MAX_FIELD = 52435875175126190479447740508185965837690552500527637822603658699938581184512n;
if (__compactRuntime.MAX_FIELD !== MAX_FIELD)
  throw new __compactRuntime.CompactError(`compiler thinks maximum field value is ${MAX_FIELD}...`);
```

A mismatch here indicates a version incompatibility between the compiler and the runtime (see Runtime Compatibility Errors below).

## Composable Contract Errors

When compiling contracts that depend on other deployed contracts, the compiler needs the dependency's `contract-info.json` file to understand the available circuits and their signatures.

### Missing contract-info.json

If the dependency path does not contain a `contract-info.json` file, or the file has been removed after the dependency was initially compiled, the compiler reports an error indicating it cannot locate the dependency contract information.

### Malformed contract-info.json

The compiler validates the structure of `contract-info.json`. The following malformations cause compilation errors:

- **Empty file** -- the JSON is present but contains no data
- **Missing circuit definitions** -- the `circuits` field is absent or not a vector
- **Corrupted circuit entries** -- individual circuit definitions have been deleted or altered in incompatible ways
- **Modified dependency contract** -- if the dependency contract was recompiled after the main contract was first compiled, the circuit definitions may no longer match

### Tolerated Malformations

Malformed argument names in the dependency's `contract-info.json` are tolerated -- compilation succeeds even if circuit parameter names have been altered. The compiler uses argument types, not names, for circuit matching.

## Internal Errors

Internal errors should never occur for any valid or invalid input. They indicate a bug in the compiler itself. The compiler prints a message like:

```
Internal compiler error (please report):
  [error details]
```

When proof key generation fails catastrophically (for example, if the `zkir` binary runs out of memory and crashes without printing anything), the compiler fails with exit code 255 (-1).

### Past Examples of Internal Errors

These have all been fixed in subsequent compiler releases:

- **MerkleTree operator error** -- the compiler reported an internal error when the `MerkleTree` operator `insert_index_default` was used. Fixed in compiler version 0.21.103.
- **`infer-types: no matching clause` error** -- the type inference engine did not handle cases where an ADT type appeared where an ordinary Compact type was expected. Fixed in compiler version 0.21.104.
- **Unicode in identifiers** -- using Unicode numeric characters (other than ASCII 0-9) in identifiers caused an internal error instead of a parse error. Fixed in compiler version 0.25.0.
- **`failed assertion (Ltypescript-Type? type)`** -- occurred when using `insert_default` on a Map whose value type was a ledger ADT. Fixed in compiler version 0.21.102.
- **Common subexpression elimination crash** -- when the first occurrence of a subexpression was in dead code, the optimizer would crash. Fixed in compiler version 0.23.0.
- **Unget-char crash** -- a rare internal error when the range syntax (`..`) appeared at a compiler-internal file input buffer boundary. Fixed in compiler version 0.22.0.

### What to Do

If you encounter an internal error on the current compiler version:

1. Update to the latest compiler version and retry.
2. If the error persists, report it as a bug. Include:
   - The Compact source file (or a minimal reproduction)
   - The compiler version (`compact compile --version`)
   - The full error output
   - The operating system and architecture

## Runtime Compatibility Errors

These errors appear after compilation, when loading the generated JavaScript in your DApp. They are not compilation errors, but they are commonly encountered immediately after compiling with a mismatched toolchain.

### Version Mismatch

The generated JavaScript checks that the installed `@midnight-ntwrk/compact-runtime` version matches what the compiler expected:

```
CompactError: Version mismatch: compiled code expects '0.8.1', runtime is 0.8.0
```

This occurs when the `compact-runtime` package installed in your project does not match the version the compiler was built against.

### MAX_FIELD Mismatch

A separate check verifies that the runtime's `MAX_FIELD` constant matches the compiler's:

```
CompactError: compiler thinks maximum field value is 524358... but runtime says ...
```

This occurs when the compiler targets a different proof system curve than the installed runtime supports. It typically happens after upgrading the compiler without also upgrading `@midnight-ntwrk/compact-runtime`.

### How to Fix

1. Check the compiler version: `compact compile --version`
2. Consult the release compatibility matrix to find the matching runtime version.
3. Install the matching runtime: `npm install @midnight-ntwrk/compact-runtime@<version>`
4. Delete previously compiled artifacts (`node_modules`, `gen/`, `out/`, `dist/` directories).
5. Recompile the contract.

All Midnight runtime packages (`@midnight-ntwrk/compact-runtime`, `@midnight-ntwrk/ledger`, `@midnight-ntwrk/zswap`) should use the same version number.

## Error Debugging Strategy

Quick-reference table for diagnosing compiler errors by symptom.

| Symptom | Category | Check |
|---|---|---|
| "expected ... but found ..." | Parse | Syntax reference, brackets, semicolons |
| "no matching overload" | Type | Argument types, casting rules |
| "potential witness-value disclosure must be declared" | Disclosure | Add `disclose()` wrappers at point of use |
| "integer too large" or crash on large literal | Overflow | Value exceeds field modulus (~2^255) |
| Compilation appears to hang | Key generation | Use `--skip-zk` for development; key gen is slow |
| Exit code 255 (-1) | Internal | Compiler bug or key gen crash -- update compiler, report bug |
| "Version mismatch" at runtime | Runtime | Update `@midnight-ntwrk/compact-runtime` to match compiler |
| "MAX_FIELD" mismatch at runtime | Runtime | Compiler and runtime target different proof curves |
| "unrecognized subcommand 'compile-many'" | Toolchain | Incompatible `zkir` binary in PATH; reinstall compiler |
| "failed to locate file" on import | Import | Check `CompactStandardLibrary` import path and filename |

### Development Workflow Tip

During development, use `--skip-zk` to skip prover and verifier key generation. This makes compilation dramatically faster by producing only TypeScript bindings and ZKIR files without the expensive key generation step. Run full compilation (without `--skip-zk`) only when preparing to deploy or test with actual proofs.

```bash
# Fast development compilation
compact compile contract.compact ./output --skip-zk

# Full compilation for deployment
compact compile contract.compact ./output
```

## Cross-References

- **ErrorTriggers.compact** -- Example in this skill that demonstrates common error triggers and their fixes hands-on.
- **compact-privacy-disclosure skill** -- Full disclosure rules, the Witness Protection Program, and patterns for avoiding unnecessary disclosure. See references/debugging-disclosure.md for step-by-step disclosure error diagnosis.
- **compact-language-ref skill** -- Troubleshooting reference with wrong-to-correct syntax tables. See references/troubleshooting.md for the complete error-to-fix mapping.
