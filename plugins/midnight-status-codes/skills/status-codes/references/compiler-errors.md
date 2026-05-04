# Compact Compiler Errors Reference

> **Last verified:** 2026-05-04 against `LFDT-Minokawa/compact@main` — toolchain compiler `0.31.101`, language `0.23.101` (anchor: `compiler/compactc.ss`, modified 2026-04-23).

Compact compiler diagnostics organized by compiler phase. The compiler is written in Chez Scheme and uses a condition-based error system.

---

## Exit Codes

| Code | Meaning | Fix |
|------|---------|-----|
| 0 | Compilation succeeded | N/A |
| 1 | Bad command-line arguments | Check `compact compile --help` for correct flags |
| 254 | Internal compiler error (unhandled exception) | Report as a bug; include the full error output |
| 255 | Compilation failed (source error) | Fix the reported source errors and recompile |

---

## Error Severity Levels

| Mechanism | Severity | Description |
|-----------|----------|-------------|
| `source-errorf` | Fatal | User-visible error with source location |
| `source-warningf` | Warning | Continuable warning with source location |
| `pending-errorf` | Deferred | Collected and shown together after the pass |
| `internal-errorf` | Fatal | Compiler internal bug — "please report" |
| `external-errorf` | Fatal | External tool/file system error |

---

## Lexer Errors

These errors occur during tokenization, before any parsing takes place.

### Unexpected end of file / newline / character

**Messages:**
- `"unexpected end of file"`
- `"unexpected newline"`
- `"unexpected character '<c>'"`

**Triggers:** Unclosed string literals, unclosed block comments, or invalid characters in source.

**Fix:** Check for unclosed strings (`"…`), unclosed block comments (`/* …`), or characters that are not valid in Compact source.

---

### Nested block comment

**Message:** `"attempt to nest block comment"`

**Triggers:** Using `/*` inside an already-open `/* */` block comment.

**Fix:** Block comments cannot be nested in Compact. Use line comments (`//`) for inner comments, or restructure to avoid nesting.

---

### Invalid leading zero in numeric literal

**Message (verbatim from compiler):** `"unsupported numeric syntax syntax: leading 0 must be followed by b, B, o, O, x, X"`

> The doubled "syntax syntax" is an upstream typo in `compiler/lexer.ss`. Match this string verbatim if grepping compiler output.

**Triggers:** Writing a number like `0123` where a digit follows the leading zero.

**Fix:** Use an explicit prefix for non-decimal literals:
- Binary: `0b1010`
- Octal: `0o755`
- Hexadecimal: `0xFF`

Do not start a decimal literal with `0` followed by another digit.

---

### Numeric literal out of Field range

**Message:** `"<value> is out of Field range"`

**Triggers:** A numeric literal exceeds the maximum representable Field value.

**Fix:** Use a smaller number. Field values are bounded by the prime used in the ZK proof system.

---

### Invalid digit in binary literal

**Message:** `"unexpected digit <d> (expected 0 or 1)"`

**Triggers:** A digit other than `0` or `1` appears in a `0b…` literal.

**Fix:** Binary literals may only contain the digits `0` and `1`.

---

### Invalid digit in octal literal

**Message:** `"unexpected digit <d> (expected 0 through 7)"`

**Triggers:** A digit `8` or `9` appears in a `0o…` literal.

**Fix:** Octal literals may only contain digits `0` through `7`.

---

## Parser Errors

These errors occur after tokenization, while the compiler builds the AST.

### Parse error (most common compiler error)

**Message:** `"parse error: found <token> looking for <expected>"`

**Triggers:** Any syntax that does not match the Compact grammar at the point the parser expected something else.

**Fix:** Read the location carefully. Common causes:
- Missing semicolons at the end of statements
- Mismatched braces `{` / `}`
- Wrong or misspelled keyword
- Extra or missing commas in argument lists

---

### Unrecognized pragma setting

**Message:** `"unrecognized pragma setting <value>"`

**Triggers:** A `pragma` directive uses a value the compiler does not recognize.

**Fix:** Check supported pragma directives. Example of a valid pragma:

```compact
pragma language_version >= 0.22;
```

---

### File I/O errors

**Messages:**
- `"error opening source file"`
- `"error reading source file"`
- `"<path> is a directory"`

**Triggers:** The compiler cannot open or read the specified source file, or the path points to a directory.

**Fix:** Verify the file path is correct, the file exists, and it has a `.compact` extension. Do not pass a directory path where a file is expected.

---

## Frontend Pass Errors

These errors occur during early semantic analysis: include resolution, control flow checks, and basic structural validation.

### Failed to locate included file

**Message:** `"failed to locate file <path>"`

**Triggers:** An `include` directive references a file the compiler cannot find. If the path suggests a standard library file, you may be using `include` where `import` is required.

**Fix:** Check the include path. To use the standard library, write:

```compact
import CompactStandardLibrary;
```

Do not use `include` for standard library modules.

---

### Include cycle

**Message:** `"include cycle involving <path>"`

**Triggers:** Two or more files include each other, directly or transitively.

**Fix:** Remove the circular include dependency. Refactor shared definitions into a common file that neither of the cyclic files includes.

---

### Return inside for loop

**Message:** `"return is not supported within for loops"`

**Triggers:** A `return` statement appears inside a `for` loop body.

**Fix:** Assign the desired value to a variable declared outside the loop, then return that variable after the loop exits.

---

### Unreachable statement

**Message:** `"unreachable statement"`

**Triggers:** A statement appears after a `return` in the same block.

**Fix:** Remove the unreachable code, or reorganize so the `return` comes after all statements that should execute.

---

### Const binding in single-statement context

**Message:** `"const binding found in a single-statement context"`

**Triggers:** A `const` declaration is used where only a single statement is syntactically allowed (e.g., directly as the body of an `if` without braces).

**Fix:** Wrap the body in a block:

```compact
if condition {
  const x = …;
  …
}
```

---

### Duplicate binding in the same block

**Message:** `"found multiple bindings for <name> in the same block"`

**Triggers:** Two `const` declarations use the same name within the same block scope.

**Fix:** Rename one of the duplicate bindings.

---

### Duplicate declaration

**Message:** `"duplicate <kind> <name>"`

**Triggers:** A field, parameter, or other named element is declared more than once in the same declaration context.

**Fix:** Remove or rename the duplicate declaration.

---

## Name Resolution Errors

These errors occur when the compiler resolves identifiers to their definitions.

### Unbound identifier (very common)

**Message:** `"unbound identifier <name>"`

**Triggers:** A name is used that the compiler cannot find in any enclosing scope or imported module.

**Fix:**
- Check spelling
- Ensure the name is defined before it is used
- Verify that `import CompactStandardLibrary;` is present if using standard library names
- Check that the relevant module is imported

---

### Shadowing conflict

**Message:** `"another binding found for <name> in the same scope at <location>"`

**Triggers:** A new binding shadows an existing one in the same scope in a way the compiler flags.

**Fix:** Rename one of the bindings to avoid the conflict.

---

### Circular type alias

**Message:** `"cycle involving <types>"`

**Triggers:** Type aliases form a cycle (e.g., `type A = B; type B = A;`).

**Fix:** Break the cycle by restructuring the type definitions.

---

### Invalid context for name

**Message:** `"invalid context for reference to <kind> name <name>"`

**Triggers:** A type name is used where a value is expected, or a value name is used where a type is expected.

**Fix:** Ensure you are using the name in the correct context (type position vs. value position).

---

### No such export

**Message:** `"no export named <name> in module <module>"`

**Triggers:** An import or qualified reference names an export that does not exist in the module.

**Fix:** Check the module's actual exports. Look for a typo in the name.

---

### Wrong number of generic parameters

**Message:** `"mismatch between actual number <n> and declared number <m> of generic parameters"`

**Triggers:** A generic type or function is applied with the wrong number of type arguments.

**Fix:** Supply exactly the number of type parameters the declaration requires.

---

### Generic function cannot be top-level export

**Message:** `"cannot export type-parameterized function (<name>) from the top level"`

**Triggers:** Attempting to export a generic (type-parameterized) function directly from the module's top level.

**Fix:** Specialize the function for the concrete type(s) you need, and export the specialized version.

---

### Possibly uninitialized variable

**Message:** `"identifier <name> might be referenced before it is assigned"`

**Triggers:** The compiler's data-flow analysis determines that a variable may be used before it is definitively assigned on all paths.

**Fix:** Reorder bindings or add an initialization so the variable is always assigned before use.

---

## Type Checking Errors

These errors occur during type inference and type checking. They are among the most frequently encountered errors.

### No compatible function in scope (very common)

**Message:** `"no compatible function named <name> is in scope at this call"`

**Triggers:** A function call cannot be resolved because no overload in scope matches the argument types provided.

**Fix:**
- Check that the argument types match the expected function signature
- Check for implicit conversions that may be needed
- Verify the function is imported
- Look at overloaded variants to see which signatures are available

---

### Ambiguous overload

**Message:** `"call site ambiguity (multiple compatible functions) in call to <name>"`

**Triggers:** More than one overloaded function is compatible with the call site's argument types.

**Fix:** Add explicit type annotations to the arguments or result to guide overload resolution to the intended function.

---

### Mismatched branch types

**Message:** `"mismatch between type <A> and type <B> of condition branches"`

**Triggers:** The `then` and `else` branches of an `if` expression return different types.

**Fix:** Both branches must have the same type. Add explicit casts, or restructure so both branches produce the same type.

---

### Condition is not Boolean

**Message:** `"expected test to have type Boolean, received <type>"`

**Triggers:** The condition of an `if`, `while`, or other conditional is not a `Boolean` expression.

**Fix:** Add an explicit comparison. For example, instead of `if x`, write `if x != 0`.

---

### Return type mismatch

**Message:** `"mismatch between actual return type <A> and declared return type <B>"`

**Triggers:** The type inferred for the function body does not match the return type annotation.

**Fix:** Either fix the return expression to produce the declared type, or update the return type annotation to match the actual type.

---

### Assignment type mismatch

**Message:** `"expected right-hand side of = to have type <A> but received <B>"`

**Triggers:** The right-hand side of an assignment or binding has a different type than the left-hand side.

**Fix:** Cast the value or restructure the expression so both sides have the same type.

---

### No such field

**Message:** `"structure <S> has no field named <F>"`

**Triggers:** Field access on a struct type uses a name that does not exist in that struct's definition.

**Fix:** Check the struct definition for the correct field name. Look for typos.

---

### Invalid cast

**Message:** `"cannot cast from type <A> to type <B>"`

**Triggers:** An explicit cast between two types that the compiler does not support.

**Fix:** Not all type casts are valid in Compact. Consult the Compact language reference for which casts are permitted between the types involved.

---

### Uint width out of range

**Message:** `"Uint width <N> is not between 1 and the maximum Uint width 248"`

**Triggers:** A `Uint<N>` type is declared with `N` outside the valid range.

**Fix:** Choose a width `N` satisfying `1 ≤ N ≤ 248`.

---

### Vector or Bytes length too large

**Message:** `"<kind> length <N> exceeds the maximum supported length 16777216"`

**Triggers:** A `Vector` or `Bytes` type is declared with a length greater than 2^24 (16,777,216).

**Fix:** Use a smaller length. Redesign the data layout if you need to handle more elements.

---

## Witness and Disclosure Errors

These errors enforce Compact's privacy model around witness values.

### Undeclared witness disclosure (critical)

**Message:** `"potential witness-value disclosure must be declared but is not"`

**Triggers:** A witness value flows to the ledger or a public output without being wrapped in `disclose()`. This is Compact's core privacy enforcement mechanism.

**Fix:** Wrap the witness value access in `disclose()` before it reaches any ledger state or public output:

```compact
disclose(witnessValue)
```

This makes the disclosure of private data explicit and auditable in the contract source.

---

### Witness returns contract-typed value

**Message:** `"invalid type <T> for witness <W> return value: witness return values cannot include contract values"`

**Triggers:** A witness function is declared to return a type that includes a contract-typed value.

**Fix:** Witnesses must return primitive types only. Remove contract-typed values from the witness return type; pass any needed information as primitive fields.

---

## Purity and Sealed Field Errors

These errors enforce restrictions on circuit purity and access to sealed ledger state.

### Exported circuit modifies sealed field

**Message:** `"exported circuits cannot modify sealed ledger fields but <circuit> at <location>"`

**Triggers:** An exported circuit attempts to write to a ledger field that is marked `sealed`.

**Fix:** Move the sealed-field modification into an internal (non-exported) circuit, and call that from the exported circuit if needed.

---

### Constructor calls external contract

**Message:** `"constructor cannot call external contracts"`

**Triggers:** The contract constructor contains a call to an external contract.

**Fix:** Move external contract calls into a circuit. The constructor may only set up initial ledger state.

---

### Pure circuit is actually impure

**Message:** `"circuit <name> is marked pure but is actually impure"`

**Triggers:** A circuit annotated as `pure` contains an operation that is impure: writing to the ledger, calling an external contract, etc.

**Fix:** Either remove the `pure` annotation, or eliminate the impure operations from the circuit body.

---

## ZKIR Generation Errors

These errors occur when the compiler generates the ZK Intermediate Representation from the type-checked AST.

### Cross-contract calls not yet supported

**Message:** `"cross-contract calls are not yet supported"`

**Triggers:** The contract attempts a cross-contract call, which has not yet been implemented in the ZKIR output stage.

**Fix:** This is a current compiler limitation. Restructure to avoid cross-contract calls until the feature is available.

---

### ZKIR non-zero exit status

**Message:** `"zkir returned a non-zero exit status <N>"`

**Triggers:** The external ZKIR compilation tool exited with an error.

**Fix:** Review the output for details on the unsupported operation. Check for operations in circuits that the ZKIR backend does not yet support.

---

## Runtime Errors

Runtime errors thrown by `@midnight-ntwrk/compact-runtime` (`CompactError`, `failed assert`, `type error`, `Version mismatch`, `Maximum field mismatch`, and the type-validation / cast / state-dependency errors) live in their own reference: see [`runtime-errors.md`](runtime-errors.md).

The compiler is the *origin* of some of these errors (it generates the runtime code that throws them), but the *surface* — the package whose stack frame appears in user errors — is `@midnight-ntwrk/compact-runtime`. Look up these errors there.

---

## Recently Added Diagnostics (compiler 0.26+ → 0.31)

The following diagnostics were added (or refined) in recent compiler releases. They are not exhaustive — see `LFDT-Minokawa/compact` for the complete list — but cover the highest-impact additions since the original compiler-errors reference was written.

### Merkle tree depth out of bounds (added in compiler 0.26.105)

**Message (template):** `"<kind> depth <D> does not fall in <min> <= depth <= <max>"`

**Triggers:** A `MerkleTree` or `HistoricMerkleTree` is declared with a depth outside the protocol-defined bounds (typically 1..=32).

**Fix:** Choose a depth within the allowed range. For most application scenarios, 32 is the right default.

---

### Opaque-JS persistentHash / persistentCommit (added in compiler 0.29.113)

**Triggers:** Calling `persistentHash` or `persistentCommit` on `Opaque<'string'>` or `Opaque<'Uint8Array'>` JS values, or indirectly via `merkleTreePathRoot` and `MerkleTree` insertion of opaque-JS values.

**Fix:** Hash these in TypeScript before they enter Compact, or restructure to use ledger-native types. This is a hard error, not a warning — the previous behavior allowed unsound hashing across JS-side opacity.

---

### `event` and `log` reserved keywords (added in compiler 0.31.101)

**Triggers:** Using `event` or `log` as an identifier (variable, function, type name).

**Fix:** Rename the identifier. These are reserved for future language features.

---

### Multiple top-level exports for the same name

**Message:** `"multiple top-level exports for ~s"`

**Triggers:** The same identifier is exported more than once at the top level of a Compact program.

**Fix:** Remove the duplicate export. Each name can be exported at most once.

---

### Indirect-call sealed/pure/constructor variants

**Triggers:** A circuit calls (directly or indirectly) another circuit that violates a contract:

- **Pure circuit transitively calls impure code:** `"circuit ~a is marked pure but is actually impure because it calls (directly or indirectly) impure circuit ~a at ~a"`
- **Exported circuit transitively modifies sealed field:** `"exported circuits cannot modify sealed ledger fields but ~a calls (directly or indirectly) ~a, which ~a at ~a"`
- **Constructor transitively calls external contract:** `"constructor cannot call external contracts but ~a calls (directly or indirectly) ~a, which ~a at ~a"`

**Fix:** Trace the call chain from the offending circuit. Either remove the contract violation in the inner circuit, or remove the call from the constraining outer one.

> The plugin previously documented only the **direct** form of each error. Indirect (transitive) variants are a separate diagnostic with a longer message that includes the call chain.

---

### Contract-info file mismatch family

When a `.compact` file declares an external contract that no longer matches its `contract-info` JSON file:

- `"declared circuit ~s not present in contract-info file ~a"`
- `"pure-flag mismatch for circuit ~s in ~a: declared ~a, actual ~a"`
- `"mismatch between actual number ~s and declared number ~s of generic parameters for ~s"`
- `"~a depth ~d does not fall in ~d <= depth <= ~d"` (also covered above)
- `"~a has been modified more recently than ~a; try recompiling ~a"` — staleness check
- `"malformed contract-info file ~a for ~s: ~a; try recompiling ~a"` — `external-errorf`

**Fix:** Recompile the upstream contract or update the calling contract's external declarations to match.

---

### Uint range bounds

**Messages:**
- `"range start for Uint type is ~d but must be 0"`
- `"range end for Uint type is ~d but must be …"`
- `"constant ~d is larger than the largest representable Uint; use…"`

**Triggers:** Declaring a `Uint` with an out-of-range start, end, or literal value.

**Fix:** Use `0` as the start (Uint is always nonnegative), and choose an end ≤ the maximum the bit width supports.

---

### For-loop range bound errors

**Messages:**
- `"start bound ~d is greater than the maximum unsigned integer"`
- `"end bound ~d is less than start bound"`
- `"the difference … exceeds the maximum vector size"`

**Triggers:** A `for` loop over an explicit range with start/end values that produce an unrepresentable iteration set.

**Fix:** Adjust the bounds so the loop's iteration count fits within `2^24` (the maximum vector size).

---

### Witness-disclosure (pending-errorf nature)

**Message (multi-line, verbatim):**
```
potential witness-value disclosure must be declared but is not:
    witness value potentially disclosed:
      <name>{<context>}
```

**Triggers:** A witness value flows into a position visible from the public transcript without an explicit `disclose(...)` call.

**Fix:** Either wrap the disclosing expression in `disclose(...)` to make the disclosure explicit, or restructure the circuit so the witness value does not reach a public position.

> This is one of the few `pending-errorf` diagnostics — the compiler defers and batches these so multiple disclosure issues report together rather than aborting on the first one. Severity is still fatal.

---

### Reserved-word used as identifier

**Message (template):** `"~s is a reserved word and may not be used as an identifier"`

**Triggers:** Using a reserved Compact keyword (including newly-reserved `event` and `log` from compiler 0.31.101) as an identifier name.

**Fix:** Rename the identifier.

---

### "expected select test" — Boolean condition variant

**Message:** `"expected select test to have type Boolean, received ~a"`

**Triggers:** A `select` expression's test position has a non-Boolean type.

**Fix:** Wrap the test in a comparison or boolean operation. Same root cause as the existing "Condition is not Boolean" entry, but the message wording differs for `select` vs `if`.
