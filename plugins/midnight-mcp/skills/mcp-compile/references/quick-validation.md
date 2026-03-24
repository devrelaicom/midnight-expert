# Quick Validation Workflow

## When to Use

After writing or modifying Compact code. This is the default compilation workflow — fast syntax and type checking without ZK generation.

## Parameters

| Parameter | Value | Why |
|-----------|-------|-----|
| `code` | Compact source code | Required |
| `skipZk` | `true` | Already the default. Fast syntax and type checking (~1-2s) without ZK generation |
| `version` | `"detect"` | Use when the code has a `pragma language_version` and you want the compiler to match it. Otherwise omit to use the latest version |

## Successful Compilation

```
Call: midnight-compile-contract({ code: "<compact source>", skipZk: true })
Response: {
  success: true,
  compilationMode: "syntax-only",
  compilerVersion: "0.29.0",
  executionTime: 1200,
  errors: [],
  warnings: []
}
Action: Code compiles. Proceed with the task.
```

## Failed Compilation

```
Call: midnight-compile-contract({ code: "<compact source>", skipZk: true })
Response: {
  success: false,
  compilationMode: "syntax-only",
  compilerVersion: "0.29.0",
  errors: [{
    message: "expected ';' but found '{'",
    severity: "error",
    line: 5,
    column: 30
  }],
  executionTime: 800
}
Action: Load references/error-recovery.md to diagnose and fix.
```

## The Fix-and-Recompile Loop

1. Read ALL errors in the response (there may be multiple)
2. Fix all errors in the code before recompiling — do not recompile after each individual fix
3. Recompile once with the corrected code
4. If new errors appear, repeat (max 2-3 rounds)
5. If still failing after 3 attempts, present the errors to the user and ask for help

## Rate Limit Awareness

20 calls per 60 seconds. With the fix-and-recompile loop, each round costs one call. Three rounds = 3 calls. Rapid-fire single-error fixes would waste the budget.

## Warnings

If `success: true` but `warnings` is non-empty, note the warnings but treat the compilation as successful. Warnings are informational — they don't block compilation.

## Response Fields to Check

| Field | What It Tells You |
|-------|-------------------|
| `success` | Did it compile? |
| `errors` | If failed, what went wrong? Load `references/error-recovery.md` |
| `warnings` | If succeeded, any concerns? |
| `compilationMode` | Confirms syntax-only validation |
| `compilerVersion` | Which compiler version was used |
| `originalCode` / `wrappedCode` | If auto-wrapping occurred, these show what was changed. See `references/snippet-compilation.md` |
