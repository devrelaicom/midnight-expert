---
name: compact-compilation
description: This skill should be used when the user asks about compiling Compact contracts, compiler output/artifacts, ZKIR files, prover/verifier keys, circuit metrics (k-value, rows), interpreting compiler errors, pure vs impure circuit compilation differences, the --skip-zk flag, contract-info.json, TypeScript binding generation, or the build output directory structure.
version: 0.1.0
---

# Compact Compilation

The Compact compiler transforms `.compact` source files into four categories of artifacts: TypeScript/JavaScript bindings, ZKIR circuit descriptions, prover/verifier keys, and compiler metadata. Understanding these outputs is essential for building DApps on Midnight, debugging compilation failures, and optimizing the development workflow.

For CLI tool installation, version management, and basic compile command syntax, see the compact-cli skill in midnight-tooling.

## Compilation Output Structure

```
<target-dir>/
├── contract/                    # TypeScript/JavaScript bindings
│   ├── index.d.ts               # Type definitions for all exported circuits
│   ├── index.js                 # JavaScript implementation with runtime checks
│   └── index.js.map             # Source map back to .compact source
├── zkir/                        # ZK Intermediate Representation
│   ├── <circuit>.zkir           # JSON circuit description (per impure circuit)
│   └── <circuit>.bzkir          # Binary ZKIR (per impure circuit)
├── keys/                        # Cryptographic keys (absent with --skip-zk)
│   ├── <circuit>.prover         # Prover key (ProverKey, branded Uint8Array)
│   └── <circuit>.verifier       # Verifier key (Uint8Array)
└── compiler/
    └── contract-info.json       # Circuit manifest and metadata
```

For a detailed walkthrough of each directory, see `references/compilation-output.md`.

## Artifact Quick Reference

| Artifact | Purpose | Generated For |
|----------|---------|---------------|
| `contract/index.d.ts` | TypeScript types: `Contract<PS, W>`, `Ledger`, `Witnesses`, `PureCircuits`, `ImpureCircuits<T>` | All exported circuits |
| `contract/index.js` | Runtime implementation with version and type validation | All exported circuits |
| `contract/index.js.map` | Source map for debugging `.compact` in VS Code | Always |
| `zkir/<circuit>.zkir` | JSON circuit description consumed by proof server | Exported impure circuits only |
| `zkir/<circuit>.bzkir` | Binary ZKIR for efficient proof server processing | Exported impure circuits only |
| `keys/<circuit>.prover` | Prover key (ProverKey, branded Uint8Array) for generating ZK proofs | Exported impure circuits only |
| `keys/<circuit>.verifier` | Verifier key submitted on-chain during deployment | Exported impure circuits only |
| `compiler/contract-info.json` | Circuit manifest (names, types, pure/impure flags) | Always |

**File count formula**: For N exported impure circuits: **2N + 4** files (default with `--skip-zk`: N `.zkir` + N `.bzkir` + 3 contract + 1 metadata) or **4N + 4** files (with `--no-skip-zk`: adds N `.prover` + N `.verifier` keys).

## Pure vs Impure Circuits

The compiler treats circuit types differently during compilation:

```compact
// EXPORTED IMPURE — modifies ledger, gets ZKIR + keys
export circuit increment(amount: Uint<16>): [] {
  const doubled = double(amount);
  count.increment(disclose(doubled));
}

// EXPORTED PURE — no ledger access, NO ZKIR, NO keys
export pure circuit add(a: Uint<64>, b: Uint<64>): Uint<64> {
  return a + b as Uint<64>;
}

// INTERNAL HELPER — not exported, embedded into callers
circuit double(x: Uint<16>): Uint<16> {
  return (x + x) as Uint<16>;
}
```

| Circuit Type | contract/ | zkir/ | keys/ | compiler/ |
|---|---|---|---|---|
| Exported impure | Yes | Yes | Yes | Yes |
| Exported pure | Yes (in `pureCircuits`) | No | No | Yes |
| Internal (non-exported) | No | No | No | No |

See `examples/PureImpureDemo.compact` for a complete annotated example.

## Circuit Metrics

The compiler reports circuit size metrics during compilation:

```
Compiling 1 circuit:
  circuit "increment" (k=5, rows=24)
Overall progress [====================] 1/1
```

| Metric | Meaning | Impact |
|--------|---------|--------|
| `k` | Evaluation domain size = 2^k | Larger k = larger circuit = slower proving |
| `rows` | Actual constraint rows used | Must be <= 2^k |

Proving time scales with `k` — each increment roughly doubles computation. Circuits with the same `k` share SRS parameters.

For details on metrics, key generation, and the proof server relationship, see `references/zkir-and-keys.md`.

## Compiler Error Categories

| Error Type | Key Diagnostic | Common Trigger |
|---|---|---|
| Parse | "expected '[token]' but found '[token]'" | `Void` return type, `::` enum access, `ledger { }` block |
| Type | "no matching overload" | Wrong argument type, missing cast |
| Disclosure | "potential witness-value disclosure must be declared but is not:" | Missing `disclose()` on witness value |
| Overflow | Integer literal exceeds field modulus | Value > ~2^254.86 (BLS12-381 scalar field) |
| Composable | "missing association for circuits" | Missing `contract-info.json` in dependency |
| Internal | Exit code 255 | Subprocess crash (e.g., OOM) — check system resources, update, and report |
| Runtime | "Version mismatch" (post-compilation) | `compact-runtime` version mismatch |

For detailed error interpretation and debugging strategies, see `references/compiler-errors.md`.
See `examples/ErrorTriggers.compact` for hands-on error reproduction.

## Development Workflow

Use `--skip-zk` during development to skip key generation (the slowest compilation phase):

```bash
# Fast development compile (seconds)
compact compile contract.compact ./output --skip-zk

# Full compile before deployment (may take minutes)
compact compile contract.compact ./output
```

With `--skip-zk`, all outputs are produced **except** the `keys/` directory. TypeScript bindings, ZKIR files, and metadata are all still generated.

**Run full compilation** (without `--skip-zk`) when:
- Deploying a contract to the network
- Integration testing with the proof server
- Submitting to CI/CD for release
- After changing circuit logic (keys must be regenerated)

## Cross-References

| Topic | Where to Look |
|-------|---------------|
| CLI installation, version management, compile command flags | compact-cli skill (midnight-tooling plugin) |
| Contract anatomy, circuit/witness definitions | compact-structure skill |
| Disclosure rules, Witness Protection Program | compact-privacy-disclosure skill |
| Standard library function availability | compact-standard-library skill |
| Type system, casting rules, operators | compact-language-ref skill |

## Reference Files

| Topic | File |
|-------|------|
| Full artifact directory structure, file counts, annotated example | `references/compilation-output.md` |
| ZKIR format, prover/verifier keys, circuit metrics, --skip-zk | `references/zkir-and-keys.md` |
| Generated TypeScript types, Contract class, type mapping | `references/typescript-bindings.md` |
| Compiler error categories, interpretation, debugging strategy | `references/compiler-errors.md` |
