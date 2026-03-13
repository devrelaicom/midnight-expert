# Compilation Validation for Compact Contracts

Reference for using the Compact compiler as a test gate, understanding compiler errors, and integrating compilation into CI pipelines. For project setup and dependencies, see `references/test-setup.md`. For the Simulator pattern, see `references/simulator-pattern.md`. For assertions and testing strategies, see `references/assertions-and-patterns.md`.

## Compilation as a Test Gate

The `compact compile` command is the first line of defense in a Compact contract testing workflow. Before any unit test runs, the contract must compile successfully. A failing compilation means the contract has structural or semantic errors that would prevent it from executing. Treat compilation as a mandatory gate: if the contract does not compile, skip all downstream tests.

The compiler catches the following categories of errors:

| Category | What It Catches | Example |
|---|---|---|
| Type errors | Wrong types passed to circuits, incorrect return types, type mismatches in assignments | Passing `Field` where `Bytes<32>` is expected |
| Disclosure violations | Witness-derived values crossing public boundaries without `disclose()` | Using a witness value in a conditional or returning it from an exported circuit |
| Sealed ledger misuse | Writing to `sealed` fields outside the constructor | Assigning to a sealed ledger field in a circuit |
| Syntax errors | Wrong pragma format, incorrect enum notation, deprecated block syntax | Using `Void` instead of `[]`, using `ledger { }` block syntax |
| Undefined references | Using undeclared variables, types, or functions | Calling `public_key()` (not a builtin) or referencing an unimported type |

A clean compilation (exit code 0) does not guarantee correctness -- the contract may still have logic errors, wrong assertions, or incorrect witness implementations. But it does guarantee that the contract is structurally valid, type-safe, and ready for unit testing.

## The compile Command

### Basic Usage

```bash
compact compile <source-file> <output-directory>
```

For example:

```bash
compact compile src/counter.compact src/managed/counter
```

The first argument is the path to a `.compact` source file. The second argument is the output directory where the compiler places all generated artifacts. The output directory is created if it does not already exist. If it already exists, the compiler overwrites previous output.

### Output Directory Structure

After successful compilation, the output directory contains four subdirectories:

```
src/managed/<name>/
├── compiler/                 # Compiler metadata
│   └── contract-info.json    # Circuit information, types, and structure
├── contract/
│   ├── index.js              # Generated JavaScript implementation
│   ├── index.js.map          # Source map back to the .compact file
│   └── index.d.ts            # TypeScript declarations (Contract, Ledger, enums)
├── keys/                     # ZK proving and verifying keys
│   ├── <circuit>.prover      # One prover key per exported circuit
│   └── <circuit>.verifier    # One verifier key per exported circuit
└── zkir/                     # ZK intermediate representation
    ├── <circuit>.zkir         # Human-readable ZKIR
    └── <circuit>.bzkir        # Binary ZKIR
```

| Directory | Contents | Used By |
|---|---|---|
| `compiler/` | `contract-info.json` with circuit metadata, type descriptors, and structural information | Build tooling and deployment scripts |
| `contract/` | JavaScript implementation (`index.js`), source map (`index.js.map`), and TypeScript declarations (`index.d.ts`) | Test code, DApp integration, and TypeScript type checking |
| `keys/` | One `.prover` and one `.verifier` file per exported circuit | The proof server during transaction creation and verification |
| `zkir/` | ZKIR files (human-readable `.zkir` and binary `.bzkir`) per exported circuit | Key generation and proof system internals |

### Exit Codes

Exit code 0 indicates successful compilation. Any non-zero exit code means the contract has errors. The compiler prints diagnostic messages to standard error with line numbers, character positions, and explanations.

### Compiler Flags

| Flag | Effect |
|---|---|
| `--version` | Prints the compiler version and exits |
| `--language-version` | Prints the language version and exits |
| `--skip-zk` | Skips ZK proving key generation (faster compilation for development) |
| `--vscode` | Omits newlines from error messages for VS Code extension compatibility |
| `--help` | Prints help text and exits |

The `--skip-zk` flag is particularly useful during development and in CI pipelines where you only need to validate the contract syntax and types without generating the full ZK keys. Key generation is the slowest part of compilation, so skipping it significantly reduces build times. The output directory will contain `contract/` and `zkir/` but not `keys/`.

### Compilation Output

During compilation, the compiler prints progress information:

```
Compiling 2 circuits:
  circuit "post" (k=13, rows=4569)
  circuit "takeDown" (k=13, rows=4580)
Overall progress [====================] 2/2
```

The `k` value and `rows` count describe the circuit complexity. These are informational and do not require action unless you are optimizing proof generation times.

## Common Compiler Errors

The following table lists the most frequently encountered compiler errors, their causes, and how to fix them.

| Error Pattern | Cause | Fix |
|---|---|---|
| `potential witness-value disclosure must be declared` | A witness-derived value reaches a public boundary (ledger write, conditional branch, or circuit return) without explicit acknowledgment | Wrap the expression in `disclose()` where the witness value crosses the boundary |
| `parse error` with expected tokens | Syntax error in the Compact source | Check pragma format, enum dot notation (`Choice.rock` not `Choice::rock`), return type (`[]` not `Void`), and ledger declaration syntax (individual declarations, not block syntax) |
| `type mismatch: expected X, got Y` | Wrong type in an assignment, argument, or return value | Check the type mapping; use `as` for casts (e.g., `value as Field`). Two-step casts are required for some conversions (e.g., `(amount as Field) as Bytes<32>` for Uint to Bytes) |
| `sealed ledger field cannot be assigned outside constructor` | A circuit or non-constructor code attempts to write to a field declared with `sealed` | Only assign sealed fields inside the `constructor` block. Sealed fields are immutable after initialization. |
| `undefined reference` / `unbound identifier` | Using a variable, type, or function that has not been declared or imported | Check imports (`import CompactStandardLibrary;`), ensure types are exported, and verify that the identifier exists. Common mistake: `public_key()` is not a builtin -- use `persistentHash` pattern instead. |
| `Version mismatch: compiled code expects 'X', runtime is 'Y'` | The `@midnight-ntwrk/compact-runtime` npm package version does not match what the compiled contract expects | Update `compact-runtime` to the version that matches your compiler. Delete `node_modules` and reinstall. |
| `language version X mismatch` | The pragma in the `.compact` file does not include the compiler's language version | Update the `pragma language_version` statement to include the current compiler's language version |
| `operation "value" undefined for ledger field type Counter` | Using `.value()` on a Counter (does not exist) | Use `counter.read()` to get the current value |
| `parse error: found "{" looking for an identifier` | Using the deprecated `ledger { }` block syntax | Use individual `export ledger field: Type;` declarations instead |
| `parse error: found "{" looking for ";"` | Using `Void` as a return type | Use `[]` (empty tuple) for circuits that return nothing |
| `unbound identifier "Cell"` | Using the deprecated `Cell<T>` wrapper (removed in language version 0.15) | Remove the `Cell` wrapper and use the type directly: `export ledger myField: Field;` |
| `parse error: found ":" looking for ")"` | Using Rust-style `::` for enum variant access | Use dot notation: `Choice.rock` not `Choice::rock` |
| `parse error` after witness declaration | Adding an implementation body to a witness declaration | Witnesses are declarations only (no body). End with `;`: `witness fn(): T;`. The implementation goes in TypeScript. |
| `cannot cast from type Uint<64> to type Bytes<32>` | Attempting a direct Uint to Bytes cast | Go through Field: `(amount as Field) as Bytes<32>` |
| `expected second argument of insert to have type Uint<64> but received Uint<0..N>` | Arithmetic result has a bounded type that does not match the expected type | Cast the arithmetic result: `(a + b) as Uint<64>` |

### Understanding Disclosure Errors

The most common and most confusing compiler error is the disclosure violation. The full error message looks like this:

```
potential witness-value disclosure must be declared but is not:
    witness value potentially disclosed:
      the return value of witness getBalance at line 2 char 1
    nature of the disclosure:
      the value returned from exported circuit balanceExceeds might disclose
      the result of a comparison involving the witness value
    via this path through the program:
      the comparison at line 5 char 10
```

The compiler traces the path from the witness value to the point of disclosure. Disclosure occurs when:

1. A witness-derived value is stored in a ledger field (on-chain state becomes visible)
2. A witness-derived value is used in a conditional (`if`, `assert`) that affects control flow
3. A witness-derived value is returned from an exported circuit
4. A witness-derived value is used in a Counter increment/decrement that reveals the amount

To fix disclosure errors, wrap the expression at the disclosure point in `disclose()`:

```compact
// BEFORE -- compiler error
export circuit check(threshold: Uint<64>): Boolean {
  const balance = getBalance();  // witness value
  return balance > threshold;    // ERROR: implicit disclosure
}

// AFTER -- compiles successfully
export circuit check(threshold: Uint<64>): Boolean {
  const balance = getBalance();
  return disclose(balance > threshold);  // explicitly acknowledge disclosure
}
```

The `disclose()` wrapper does not cause disclosure by itself. It tells the compiler that the programmer is aware that the value will be visible on-chain and accepts this. Without it, the compiler assumes the disclosure is accidental and rejects the program.

## Pragma Version Compatibility

Every Compact source file should begin with a `pragma language_version` statement that declares which language versions the contract is compatible with.

### Format

```compact
pragma language_version >= 0.21 && <= 0.22;
```

The pragma uses comparison operators and logical `&&` to define a version range. Key rules:

1. **Use bounded ranges.** Open-ended ranges (e.g., `>= 0.21`) imply your contract works with all future versions, which cannot be guaranteed. Always include an upper bound.
2. **Exact versions are also valid.** `pragma language_version 0.20;` pins to a single version. This is simpler but means you must update the pragma whenever the compiler updates.

### What Happens on Mismatch

If the compiler's language version falls outside the range specified by the pragma, compilation fails immediately with an error like:

```
language version 0.20.0 mismatch
```

This prevents accidentally compiling a contract with an incompatible compiler version that may have different semantics, syntax changes, or breaking changes.

### Version History

The language version and compiler version are distinct. The language version tracks syntax and semantic changes in the Compact language itself, while the compiler version tracks the implementation. For example, compiler version 0.25.0 implements language version 0.17.0.

When updating the compiler, check the release notes for language version changes and update the pragma accordingly.

### Common Pragma Mistakes

| Mistake | Problem | Correct |
|---|---|---|
| `pragma language_version >= 0.14;` | No upper bound | `pragma language_version >= 0.21 && <= 0.22;` |
| `pragma language_version >= 0.21 < 0.22;` | Missing `&&` between conditions | `pragma language_version >= 0.21 && <= 0.22;` |
| No pragma at all | Compiler may reject or use default behavior | Always include a pragma |

## Integrating into CI

### GitHub Actions

A minimal GitHub Actions workflow that compiles the contract and runs tests:

```yaml
name: Contract Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "18"

      - name: Install Compact compiler
        run: |
          curl -sL https://releases.midnight.network/compact/install.sh | bash
          compact --version

      - name: Install dependencies
        run: npm ci
        working-directory: contract

      - name: Compile Compact contracts
        run: npx compact compile src/contract.compact src/managed/contract
        working-directory: contract

      - name: Run unit tests
        run: npx vitest run
        working-directory: contract
```

### Separating Compilation from Testing

Splitting compilation and testing into separate steps makes failures easier to diagnose:

```yaml
      - name: Compile Compact contracts
        run: npx compact compile src/contract.compact src/managed/contract
        working-directory: contract

      - name: Type-check TypeScript
        run: npx tsc --noEmit
        working-directory: contract

      - name: Run unit tests
        run: npx vitest run
        working-directory: contract
```

If the compile step fails, you know the issue is in the Compact source. If TypeScript type-checking fails, the issue is in the witness implementations or test code. If the tests fail, the contract compiles and type-checks but has a logic error.

### Using --skip-zk in CI

For CI pipelines that only need to validate the contract and run unit tests (no on-chain deployment), use `--skip-zk` to skip ZK key generation and reduce build times:

```yaml
      - name: Compile Compact contracts (skip ZK keys)
        run: npx compact compile --skip-zk src/contract.compact src/managed/contract
        working-directory: contract
```

ZK key generation is the slowest part of compilation. Skipping it is safe for unit tests because the Simulator pattern does not use the proving/verifying keys -- it executes circuits directly in JavaScript. Only include full key generation for deployment pipelines or integration tests that require actual proof generation.

### package.json Scripts for CI

Standard scripts that CI pipelines can call:

```json
{
  "scripts": {
    "compact": "compact compile src/contract.compact src/managed/contract",
    "compact:fast": "compact compile --skip-zk src/contract.compact src/managed/contract",
    "build": "npm run compact && tsc",
    "test": "vitest run",
    "test:compile": "npm run compact && vitest run",
    "test:ci": "npm run compact:fast && vitest run"
  }
}
```

| Script | Use In |
|---|---|
| `compact` | Full compilation with ZK keys (deployment pipelines) |
| `compact:fast` | Fast compilation without ZK keys (development and CI test pipelines) |
| `build` | Full build including TypeScript compilation |
| `test` | Run tests only (assumes `managed/` directory already exists) |
| `test:compile` | Compile then test (full validation) |
| `test:ci` | Fast compile then test (CI-optimized) |

## Runtime Version Compatibility

The generated JavaScript code (`contract/index.js`) includes a version check at the top:

```javascript
if (__compactRuntime.versionString !== '0.3.0-a5f2494')
  throw new __compactRuntime.CompactError(
    `Version mismatch: compiled code expects '0.3.0-a5f2494', runtime is ${__compactRuntime.versionString}`
  );
```

This check runs when the contract is first imported. If the installed `@midnight-ntwrk/compact-runtime` version does not match the version the compiler expected, it throws a `CompactError` before any contract code executes.

### Diagnosing Version Mismatches

| Symptom | Cause | Fix |
|---|---|---|
| `Version mismatch: compiled code expects 'X', runtime is 'Y'` | `compact-runtime` npm package does not match the compiler | Install the matching runtime version: `npm install @midnight-ntwrk/compact-runtime@<version>` |
| `MAX_FIELD` mismatch | Runtime and compiler disagree on cryptographic parameters | Same fix -- update `compact-runtime` to match the compiler |
| Tests pass locally but fail in CI | Different compiler or runtime versions in CI environment | Pin exact versions in `package.json` and ensure CI installs the same compiler version |

### Keeping Versions in Sync

1. When you update the Compact compiler, also update `@midnight-ntwrk/compact-runtime` in `package.json`.
2. After updating, delete the `managed/` directory and recompile: `rm -rf src/managed && npm run compact`.
3. Delete `node_modules` and reinstall if you encounter persistent version errors.
4. Pin the runtime version in `package.json` (use exact versions, not ranges) to prevent drift.

## Using the MCP Compiler

The Midnight MCP server provides a `midnight-compile-contract` tool for quick validation without requiring a local compiler installation. This is useful for rapid iteration during development, especially when exploring syntax or prototyping contracts.

### Compilation Modes

| Option | Speed | What It Does |
|---|---|---|
| `skipZk=true` (default) | Fast (~1-2 seconds) | Syntax and type validation only. Catches all structural errors but does not generate ZK circuits or keys. |
| `fullCompile=true` | Slow (~10-30 seconds) | Full compilation including ZK circuit generation. Equivalent to running `compact compile` locally without `--skip-zk`. |

### Interpreting Results

The response includes a `validationType` field that indicates which validation method was used:

| `validationType` Value | Meaning |
|---|---|
| `"compiler"` | The contract was validated by the real Compact compiler. Errors and success are authoritative. |
| `"static-analysis-fallback"` | The compiler service was unavailable. The tool fell back to static analysis, which catches common patterns but may miss semantic errors. |

When the validation type is `"static-analysis-fallback"`, treat a passing result with caution -- the contract may still have errors that only the real compiler catches. Always confirm with a local `compact compile` before deployment.

### Limitations

The MCP compiler is designed for quick validation, not for producing deployment artifacts. It does not generate the `contract/`, `keys/`, or `zkir/` directories that a local `compact compile` produces. Use it during development for fast feedback, but always use the local compiler for the final build.

### When to Use Each

| Scenario | Tool | Why |
|---|---|---|
| Exploring Compact syntax | MCP compiler (`skipZk=true`) | Instant feedback, no local setup required |
| Validating a contract during development | MCP compiler (`skipZk=true`) or local `compact compile --skip-zk` | Fast validation of types and structure |
| Running unit tests | Local `compact compile` (with or without `--skip-zk`) | Tests require the generated `contract/index.js` |
| Preparing for deployment | Local `compact compile` (full, no `--skip-zk`) | Deployment requires ZK keys |
| CI pipeline | Local `compact compile --skip-zk` for test jobs, full compile for deployment jobs | Balance speed and completeness |

## Pre-Compilation Checks

Before running the compiler, catch common issues early with static analysis tools. The MCP server provides `midnight-extract-contract-structure` which performs structural analysis on Compact source code without invoking the compiler.

### What Static Analysis Catches

- Deprecated `ledger { }` block syntax
- `Void` return type (should be `[]`)
- Old pragma format
- Unexported enums (not accessible from TypeScript)
- Deprecated `Cell<T>` wrapper
- Module-level `const` usage
- Standard library name collisions
- Missing `disclose()` calls (heuristic, not exhaustive)

### What Static Analysis Cannot Catch

Static analysis is pattern-based and does not perform type checking or semantic analysis. It cannot catch:

- Type mismatches between circuit parameters and ledger field types
- Incorrect sealed field semantics
- Complex disclosure paths through multiple function calls
- Runtime cast failures
- Arithmetic overflow in bounded types

Always follow static analysis with actual compilation. Static analysis is a first pass that provides fast feedback, not a replacement for the compiler.

## Compilation Validation Checklist

Use this checklist when validating a Compact contract:

1. **Pragma version** -- Does the `pragma language_version` statement include the current compiler's language version?
2. **Standard library import** -- Is `import CompactStandardLibrary;` present?
3. **Compile with `compact compile`** -- Does the contract compile with exit code 0?
4. **Runtime version** -- Does `@midnight-ntwrk/compact-runtime` match the compiler version?
5. **TypeScript type-check** -- Does `tsc --noEmit` pass on the witness implementations and test code?
6. **Unit tests** -- Do all Vitest tests pass with `vitest run`?

Steps 1-3 validate the Compact source. Steps 4-5 validate the integration between the generated code and your TypeScript code. Step 6 validates the contract logic. If any step fails, fix it before proceeding to the next.
