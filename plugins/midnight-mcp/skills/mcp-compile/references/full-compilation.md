# Full Compilation Workflow

## When to Use

Pre-deployment validation, circuit metric analysis, or when TypeScript bindings are needed from the hosted compiler.

## Parameters

| Parameter | Value | Effect |
|-----------|-------|--------|
| `fullCompile` | `true` | Full ZK compilation including circuit generation (~10-30s). Overrides `skipZk` |
| `includeBindings` | `true` | Returns compiler-generated TypeScript artifacts in the response. Implicitly forces full compilation |

## Example — Full Compile with Insights

```
Call: midnight-compile-contract({
  code: "<compact source>",
  fullCompile: true
})
Response: {
  success: true,
  compilationMode: "full",
  compilerVersion: "0.29.0",
  executionTime: 15200,
  insights: {
    circuitCount: 2,
    circuits: [
      { name: "transfer", k: 8, rows: 180 },
      { name: "mint", k: 5, rows: 24 }
    ],
    usesZkProofs: true
  }
}
```

## Interpreting CompilerInsights

| Field | Meaning | What to Watch For |
|-------|---------|-------------------|
| `circuitCount` | Number of compiled circuits | Unexpected count may indicate missing exports |
| `circuits[].name` | Circuit name | Should match your exported circuit names |
| `circuits[].k` | Evaluation domain size (2^k) | Each increment roughly doubles proving time. k=5 is small, k=15+ is expensive |
| `circuits[].rows` | Constraint rows used | Must be <= 2^k. Higher = more complex circuit |
| `usesZkProofs` | Whether any circuit generates ZK proofs | `false` means all circuits are pure (no on-chain state) |

## k-Value Guidance

| k | Rows (2^k) | Complexity |
|---|-----------|------------|
| 5 | ~32 | Small circuit, fast proving |
| 8 | ~256 | Moderate circuit |
| 12 | ~4096 | Complex circuit, noticeable proving time |
| 16+ | ~65536+ | Very complex, significant proving time — consider optimization |

## includeBindings

When `includeBindings: true`, the response includes a `bindings` field — a Record mapping file paths to generated TypeScript content. This is the same content that local compilation writes to the `contract/` directory.

Use this when you need to inspect the generated types without running a local compile. For full artifact generation on disk (ZKIR, keys, plus bindings), use local compilation instead.

## Execution Time Expectations

| Mode | Time | Use Case |
|------|------|----------|
| Syntax-only (`skipZk: true`) | 1-2 seconds | Iterative development, fast feedback |
| Full compilation (`fullCompile: true`) | 10-30 seconds | Pre-deployment, circuit metrics |
| Full with bindings | Same as full | Inspect generated TypeScript types |

## When NOT to Use Full Compilation

- During iterative development — use `skipZk: true` for fast feedback
- When you only need to check syntax/types — full compile is wasteful for validation
- When you need artifacts on disk — use local compilation (`compact-core:compact-compilation`)

## Cross-Reference

For detailed documentation of ZKIR format, prover/verifier key structure, and TypeScript binding types, see `compact-core:compact-compilation`.
