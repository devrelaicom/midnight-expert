# Multi-Version Compilation Workflow

## When to Use

Testing the same code against multiple Compact compiler versions simultaneously. Useful for backwards/forwards compatibility checks without installing different compiler versions locally.

## Parameters

| Parameter | Value | Why |
|-----------|-------|-----|
| `code` | Compact source code | Required |
| `versions` | Array of version strings (max 10) | Each version runs in parallel |
| `skipZk` | `true` | Recommended for multi-version testing — faster, sufficient for compat checks |

## Special Version Values

| Value | Resolves To |
|-------|-------------|
| `"latest"` | Newest installed compiler version |
| `"detect"` | Resolves from `pragma language_version` constraints in the code |
| Specific version string | Exact version, e.g., `"0.29.0"`, `"0.28.0"` |

## Discovering Available Versions

To find which compiler versions the hosted service supports, call `midnight-list-compiler-versions`. This returns the set of version strings you can pass in the `versions` array. Do not guess version numbers — always discover them first.

## Common Use Cases

| Task | Versions to Test |
|------|------------------|
| Backwards compatibility | `["detect", "0.26.0", "0.25.0"]` |
| Forward compatibility (will it work on latest?) | `["detect", "latest"]` |
| Find which version introduced a breaking change | `["0.26.0", "0.27.0", "0.28.0", "0.29.0"]` |
| Test against project's pragma constraints | `["detect"]` (single version, pragma-resolved) |

## Example

```
Call: midnight-compile-contract({
  code: "<compact source>",
  versions: ["latest", "0.28.0", "0.26.0"],
  skipZk: true
})
Response: [
  { success: true,  requestedVersion: "latest", compilerVersion: "0.29.0", ... },
  { success: true,  requestedVersion: "0.28.0", compilerVersion: "0.28.0", ... },
  { success: false, requestedVersion: "0.26.0", compilerVersion: "0.26.0",
    errors: [{ message: "...", line: 3, column: 10 }], ... }
]
Action: Code compiles on 0.28.0+ but not 0.26.0. Report the compatibility boundary.
```

## Interpreting Multi-Version Results

- Each version returns its own result object with `requestedVersion` (what you asked for) and `compilerVersion` (what was resolved)
- Check `success` per version — some may pass while others fail
- If a version fails, check its `errors[]` for version-specific issues (syntax that doesn't exist in older versions, deprecated constructs removed in newer versions)
- When reporting to the user, show the compatibility matrix: which versions pass and which fail

## Limits

Maximum 10 versions per request. For broader sweeps, split into multiple calls.
