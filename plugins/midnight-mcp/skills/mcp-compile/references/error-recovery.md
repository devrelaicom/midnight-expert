# Error Recovery Workflow

## When to Use

After any failed compilation. This reference helps diagnose the error and route to the correct example file.

## Reading the CompilerError Structure

```
{
  message: "expected ';' but found '{'",   // Error description
  severity: "error",                        // "error", "warning", or "info"
  file: "contract.compact",                 // Source file (optional)
  line: 5,                                  // 1-based line number (optional)
  column: 30                                // 1-based column (optional)
}
```

## Error Category Routing

Match the error message pattern, then load the corresponding example file.

| Error Pattern | Category | Example File |
|---------------|----------|-------------|
| `"expected '...' but found '...'"` | Parse error | `examples/parse-errors.md` |
| `"no matching overload"` | Type error | `examples/type-errors.md` |
| `"potential witness-value disclosure must be declared"` | Disclosure error | `examples/disclosure-errors.md` |
| `"integer too large"`, `"MAX_FIELD"`, overflow | Overflow error | `examples/overflow-errors.md` |
| HTTP 429, timeout, 5xx, connection error | Service error | `examples/service-errors.md` |
| `"internal compiler error"` | Compiler bug | See recovery steps below |

Load only the example file matching your error. Do not load all example files.

## Line Number Adjustment for Wrapped Snippets

If the compilation used auto-wrapping (check `originalCode` / `wrappedCode` in response), subtract the wrapper offset from error line numbers before interpreting. See `references/snippet-compilation.md` for offset rules.

## The Recovery Loop

1. Read ALL errors in the response
2. Match each error to its category using the routing table above
3. Load the example file for the primary error category
4. Fix all errors in the code
5. Recompile once
6. If new errors appear (common — fixing one error can reveal others), repeat from step 1
7. Maximum 2-3 rounds. If still failing, present the errors to the user with your diagnosis and ask for help.

## Internal Compiler Errors

If the error message contains "internal compiler error" or the compilation exits with no message:

1. Try a different compiler version (`version: "latest"` or a specific recent version)
2. If it persists across versions, this is a compiler bug — inform the user and suggest filing an issue
3. Cross-reference: `compact-core:compact-compilation` references/compiler-errors.md has a catalog of known internal errors and their fixed versions

## Full Error Catalog

For detailed explanations of every error category, compiler behavior, and version-specific quirks, see `compact-core:compact-compilation` references/compiler-errors.md. The example files below cover the most common errors and how to fix them in the MCP context.
