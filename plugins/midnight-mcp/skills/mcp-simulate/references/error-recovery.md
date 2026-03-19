# Error Recovery

## When to Use

After any failed simulation operation. Match the error pattern to its category, then load the corresponding example file.

## Reading Error Responses

All errors include `success: false` and an `errors` array with `message`, `severity`, and optional `errorCode`.

## Error Category Routing

Match the error pattern, then load the corresponding example file.

| Error Pattern | Category | Example File |
|---------------|----------|-------------|
| Compiler errors during deploy (syntax, type, disclosure) | Deployment error | `examples/deployment-errors.md` |
| `SESSION_NOT_FOUND` | Session error | `examples/session-errors.md` |
| `CIRCUIT_NOT_FOUND` / parameter type mismatch / assertion failure | Execution error | `examples/execution-errors.md` |
| Witness not provided / witness wrong type | Witness error | `examples/witness-errors.md` |
| `CAPACITY_EXCEEDED` / HTTP 429 | Capacity error | `examples/capacity-errors.md` |

**Load only the example file matching your error.** Do not load all example files.

## The Recovery Loop

1. Read ALL errors in the response
2. Match each error to its category using the routing table above
3. Load the example file for the primary error category
4. Fix the issue (for deploy errors: fix code and redeploy; for call errors: fix parameters and retry)
5. If new errors appear, repeat from step 1
6. Maximum 2-3 rounds. If still failing, present the errors to the user with your diagnosis and ask for help.

## Cross-Reference

Deploy compilation errors use the same compiler as `mcp-compile`. For detailed compiler error guidance, see `mcp-compile` error recovery reference.
