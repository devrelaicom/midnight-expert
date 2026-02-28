# Design: compact-compilation Skill

**Date:** 2026-02-28
**Plugin:** compact-core
**Status:** Approved

## Purpose

Fill the gap between "here's the `compact compile` command" (compact-cli skill) and "here's how to write Compact code" (other compact-core skills). This skill covers what the compiler produces, how to interpret its output, and how to debug compilation failures.

## Scope

### In Scope

- Compiler output artifact structure (4 directories: contract/, zkir/, keys/, compiler/)
- ZKIR format, versioning, and purpose
- Prover/verifier key contents and generation
- Pure vs impure circuit compilation differences
- Circuit metrics (k-value, rows)
- Compiler error categories and interpretation
- Development workflow (--skip-zk, iteration patterns)
- Composable contract compilation (contract-info.json dependencies)

### Out of Scope

- CLI tool installation and version management (owned by compact-cli in midnight-tooling)
- Loading compiled artifacts in TypeScript (future deployment/DApp skill)
- Provider setup, deployment transactions, proof server interaction
- Writing Compact contract code (owned by other compact-core skills)

## Skill Name

`compact-compilation`

## Trigger Description

Triggered when the user asks about compiling Compact contracts, compiler output/artifacts, ZKIR files, prover/verifier keys, circuit metrics (k-value, rows), interpreting compiler errors, pure vs impure circuit compilation differences, the --skip-zk flag, contract-info.json, TypeScript binding generation, or the build output directory structure.

## File Structure

```
plugins/compact-core/skills/compact-compilation/
├── SKILL.md
├── examples/
│   ├── PureImpureDemo.compact
│   └── ErrorTriggers.compact
└── references/
    ├── compilation-output.md
    ├── zkir-and-keys.md
    ├── typescript-bindings.md
    └── compiler-errors.md
```

## SKILL.md Sections

1. **Opening paragraph** — What compilation produces and why it matters
2. **Compilation Output Structure** — ASCII tree of the 4 output directories with one-line descriptions
3. **Artifact Quick Reference** — Table mapping each artifact type to its purpose and when it's generated
4. **Pure vs Impure Circuits** — How the compiler treats them differently (which get ZKIR/keys, which don't)
5. **Circuit Metrics** — Understanding k-value and rows in compiler output
6. **Compiler Error Categories** — Quick table: error type, what it means, where to look
7. **Development Workflow** — --skip-zk usage, what it skips, when to use full compilation
8. **Cross-references** — Links to compact-cli, compact-structure, compact-standard-library
9. **Reference Files routing table** — Maps topics to reference files

## Reference Files

### compilation-output.md

Complete map of what the compiler produces:
- Full directory tree with every file type annotated
- How many files are generated (function of exported circuits count)
- Relationship: 1 exported impure circuit = 1 ZKIR + 1 prover key + 1 verifier key
- Pure circuits: appear in TypeScript bindings but get NO ZKIR or keys
- compiler/contract-info.json manifest contents and use in composable contracts
- How the compiler handles stale files (removes orphaned ZKIR)

### zkir-and-keys.md

Deep dive into ZK-specific artifacts:
- ZKIR format: JSON (.zkir) and binary (.bzkir) variants
- ZKIR versioning (v2 vs v3), how version is detected
- What ZKIR represents (circuit description consumed by proof server)
- Prover key contents (ProvingKeyMaterial: proverKey + verifierKey + ir as Uint8Array)
- Verifier key contents (branded Uint8Array, submitted on-chain during deployment)
- Circuit metrics: k-value (evaluation domain = 2^k), rows (constraint rows used)
- Key generation as the compilation bottleneck
- When full key generation is needed vs when --skip-zk suffices

### typescript-bindings.md

Understanding the generated TypeScript/JavaScript in contract/:
- index.d.ts — exported types: Contract<T>, Ledger, Witnesses<T>, PureCircuits, user types
- index.js — runtime version check, MAX_FIELD validation, circuit implementations
- index.js.map — source maps for debugging, --sourceRoot flag behavior
- How Compact types map to TypeScript types (enum to enum, struct to interface)
- The Contract<T> generic parameter (T is private state type)
- pureCircuits vs impureCircuits distinction in generated code

### compiler-errors.md

Interpreting and debugging compilation failures:
- Parse errors — expected-token diagnostics, common triggers
- Type errors — overloading resolution, ADT type argument errors, generic parameter failures
- Disclosure errors — witness values reaching ledger without disclose() (cross-ref to compact-privacy-disclosure)
- ZKIR generation errors — index allocation issues, version-specific bugs
- Integer overflow — field modulus limits, compile-time detection
- Composable contract errors — missing/malformed contract-info.json in dependencies
- Internal errors — what they mean (compiler bug), exit code 255, how to report
- Runtime compatibility errors — version mismatch, MAX_FIELD mismatch

## Example Files

### PureImpureDemo.compact (~30-40 lines)

Demonstrates how the compiler treats pure vs impure circuits differently:
- 1 exported impure circuit (modifies ledger) — gets ZKIR + keys
- 1 exported pure circuit (computation only) — appears in TS bindings but NO ZKIR/keys
- 1 internal helper circuit (not exported) — embedded in callers, no standalone output
- Minimal ledger state (a Counter)
- Comments annotating which artifacts each circuit produces

### ErrorTriggers.compact (~30-40 lines)

Collection of commented-out error patterns with exact compiler error messages:
- Each error pattern commented out with // and annotated with expected error
- Covers: parse error, type error, disclosure error, integer overflow
- Users can uncomment individual patterns to reproduce errors
- Valid base contract wraps errors so the file compiles by default

## Cross-References

| Direction | Skill | Reason |
|-----------|-------|--------|
| This skill → compact-cli | CLI flags, version management, --directory | compact-cli owns invocation |
| This skill → compact-structure | Contract anatomy, circuit/witness definitions | Structure explains what gets compiled |
| This skill → compact-privacy-disclosure | Disclosure errors | Privacy skill explains disclose() rules |
| compact-structure → this skill | "For compilation output details..." | Back-reference |
| compact-cli → this skill | "For understanding compiler output..." | Back-reference |

## Plugin Manifest Update

Add keywords to .claude-plugin/plugin.json: "compilation", "compiler-output", "zkir", "prover-keys", "verifier-keys", "circuit-metrics", "build-artifacts".

## Relationship to compact-cli

Clear boundary:
- **compact-cli** owns: CLI installation, compiler version management, basic command syntax and flags, --directory/COMPACT_DIRECTORY
- **compact-compilation** owns: what the compiler produces, how to interpret output, artifact structure and purpose, error categories and debugging, pure vs impure distinction, circuit metrics, development workflow patterns
