# Deployment Error Examples

## When This Error Occurs

Contract code fails compilation during `midnight-simulate-deploy`. The simulator cannot create a session because the code doesn't compile. Deploy errors ARE compiler errors — the same error messages and fixes apply as in `midnight-mcp:mcp-compile`.

## Examples

### Parse error in contract code

```
Before:
  midnight-simulate-deploy({ code: "export circuit inc(n: Uint<64>): Void { count.increment(n); }" })

Error:
  { success: false, errors: [{ message: "expected ';' but found '{'", severity: "error", line: 1, column: 42 }] }

Diagnosis:
  Compact does not have a `Void` return type. Use `[]` for circuits that return nothing.
  Other common parse errors:
  - Deprecated `ledger { ... }` block syntax — use `export ledger fieldName: Type;` instead
  - Witness declared with a body — witnesses are declarations only, no body
  - Using `function` instead of `circuit`
  - Using `/` division operator — Compact does not support division

Fix:
  midnight-simulate-deploy({ code: "export circuit inc(n: Uint<64>): [] { count.increment(n); }" })
  → success: true

Cross-reference: mcp-compile examples/parse-errors.md for comprehensive parse error guidance.
```

### Type error in contract code

```
Before:
  midnight-simulate-deploy({
    code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nexport ledger count: Counter;\nexport circuit add(n: Field): [] { count.increment(n); }"
  })

Error:
  { success: false, errors: [{ message: "no matching overload for Counter.increment with argument type Field", severity: "error", line: 4 }] }

Diagnosis:
  Counter.increment expects Uint<16>, but a Field was passed. Common type mismatches:
  - Mixing Field and Uint<N> — these are different types
  - Arithmetic result expansion — Uint<32> + Uint<32> may produce Uint<33>
  - Direct Uint to Bytes cast — use pad/truncate operations

Fix:
  Change parameter type from Field to Uint<16> and add disclosure:
  midnight-simulate-deploy({
    code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nexport ledger count: Counter;\nexport circuit add(n: Uint<16>): [] { count.increment(disclose(n)); }"
  })
  → success: true

Cross-reference: mcp-compile examples/type-errors.md for detailed type error guidance.
```

### Missing import

```
Before:
  midnight-simulate-deploy({
    code: "pragma language_version >= 0.22;\nexport ledger count: Counter;\nexport circuit inc(): [] { count.increment(disclose(1)); }"
  })

Error:
  { success: false, errors: [{ message: "unbound identifier 'Counter'", severity: "error", line: 2 }] }

Diagnosis:
  Counter is defined in CompactStandardLibrary. The code is missing the import statement.

Fix:
  midnight-simulate-deploy({
    code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nexport ledger count: Counter;\nexport circuit inc(): [] { count.increment(disclose(1)); }"
  })
  → success: true
```

### Disclosure error

```
Before:
  midnight-simulate-deploy({
    code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nwitness getSecret(): Field;\nexport ledger stored: Field;\nexport circuit save(): [] { stored = getSecret(); }"
  })

Error:
  { success: false, errors: [{ message: "potential witness-value disclosure must be declared", severity: "error", line: 5 }] }

Diagnosis:
  Witness value flows to public ledger state without being wrapped in disclose(). Compact requires explicit disclosure of witness-derived values.

Fix:
  midnight-simulate-deploy({
    code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nwitness getSecret(): Field;\nexport ledger stored: Field;\nexport circuit save(): [] { stored = disclose(getSecret()); }"
  })
  → success: true

Cross-reference: mcp-compile examples/disclosure-errors.md for disclosure error patterns.
```

### Empty code

```
Before:
  midnight-simulate-deploy({ code: "" })

Error:
  { success: false, errors: [{ message: "Contract code is required", severity: "error" }] }

Diagnosis:
  Empty string or whitespace passed as code. No contract to compile.

Fix:
  Provide actual Compact source code with at least one exported circuit.
```

## Anti-Patterns

### Blind modification

Modifying code in response to a deployment error without reading the compiler error message. The error tells you exactly what line, column, and issue to fix.

### Redeploying unchanged code

Redeploying the same code hoping for a different result. Compilation is deterministic — the same code always produces the same errors.

### Ignoring midnight-mcp:mcp-compile cross-references

Not cross-referencing `midnight-mcp:mcp-compile` error examples when deploy fails. Deploy errors ARE compiler errors — `midnight-mcp:mcp-compile` has detailed guidance for every error category.
