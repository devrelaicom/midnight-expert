---
name: midnight-verify:verify-compact
description: >-
  This skill should be used when verifying claims about the Compact programming language,
  including stdlib function existence, syntax validity, type compatibility, disclosure
  rules, compiler behavior, design patterns, privacy properties, and circuit costs.
  Loaded by the verify-correctness hub skill when a claim is classified as Compact-related.
  Provides Compact-specific verification methods (MCP search, skill references, compilation)
  and source code repository mapping.
version: 0.1.0
---

# Compact Code Verification

This skill provides Compact-specific verification methods. For generic verification methodology, confidence scoring, and escalation rules, see the hub skill at `midnight-verify:verify-correctness`.

## Compact-Specific Verification Methods

Four methods for verifying Compact-related claims, ordered by confidence.

### MCP midnight-search-compact (Confidence: 20-45)

Use the `midnight-mcp` plugin's `midnight-search-compact` tool to search indexed Compact code.

- Check `relevanceScore` on results — higher scores indicate better matches
- Source repositories from `midnightntwrk`, `OpenZeppelin`, and `LFDT-Minokawa` organizations are generally more trustworthy than community or third-party code
- Indexed code may be outdated relative to the latest compiler version — a function appearing in search results does not guarantee it exists in the current release
- Useful for finding usage patterns and examples; less useful for confirming exact API signatures

### MCP midnight-search-docs (Confidence: 20-30)

Use the `midnight-mcp` plugin's `midnight-search-docs` tool.

- The docs search index may lag behind actual releases. Always verify claims found in docs independently using higher-confidence methods
- Check `relevanceScore` — low-scoring results are often tangentially related or outdated
- Most reliable for conceptual explanations and architecture; less reliable for API signatures and exact syntax

### Midnight Expert Skills (Confidence: 60-80)

Use skills from the `compact-core` plugin which contain verified reference material:

- `compact-core:compact-standard-library` — stdlib function existence, signatures, and behavior
- `compact-core:compact-compilation` — compiler usage, version selection, compile flags
- `compact-core:compact-patterns` — design patterns and best practices
- `compact-core:compact-privacy-disclosure` — privacy properties, hidden vs visible, disclosure rules
- `compact-core:compact-review` — security review methodology
- `compact-core:compact-circuit-costs` — circuit cost analysis and optimization
- `compact-core:compact-tokens` — token verification (NIGHT, DUST, custom tokens)
- `compact-core:compact-debugging` — troubleshooting compile errors and unexpected behavior

Skills contain verified reference material but may lag behind the latest compiler release. Reliable for language semantics, patterns, and architecture. Less reliable for version-specific details or recently changed behavior.

### Compiling the Code (Confidence: 80-95)

Use the `midnight-mcp` plugin's `midnight-compile-contract` tool or local `compact compile` command.

- Use `skipZk=true` (MCP) or `--skip-zk` (CLI) for fast validation — confirms syntax and type correctness without generating ZK proofs
- Compilation is version-specific: a program that compiles on one version may fail on another
- Compilation confirms: syntax validity, type correctness, that exports are well-formed
- Compilation does NOT confirm: runtime behavior, privacy guarantees (requires deeper analysis), optimal patterns, or correctness of business logic

## Categories of Things to Verify

### Compact Language

| What to Verify | Methods | Notes |
|---|---|---|
| Function exists in stdlib | `compact-core:compact-standard-library` skill → compile test | Check both existence and signature |
| Syntax is valid | Compile with `skipZk=true` | Definitive for the compiler version used |
| Type compatibility | Compile a test case | Type errors surface at compile time |
| Disclosure rules | `compact-core:compact-privacy-disclosure` skill → compile | Visibility is enforced by the compiler |
| Compiler behavior per version | Compile → check release notes | Behavior may differ across versions |

### Patterns / Best Practices

| What to Verify | Methods | Notes |
|---|---|---|
| Pattern is correct | `compact-core:compact-patterns` skill → compile | Patterns should compile and produce expected types |
| Security properties | `compact-core:compact-review` skill → source | Some security properties require source-level analysis |
| Performance implications | `compact-core:compact-circuit-costs` skill → compile | Circuit costs are measurable at compile time |

### Privacy Properties

| What to Verify | Methods | Notes |
|---|---|---|
| Hidden vs visible state | `compact-core:compact-privacy-disclosure` skill → compile | Compiler enforces disclosure annotations |
| Privacy guarantees | Skill → compile → source analysis | Some guarantees require understanding the ZK circuit |
| Correlation resistance | Source analysis → protocol review | Requires understanding of the full transaction lifecycle |

### Protocol / Architecture (Compact-adjacent)

| What to Verify | Methods | Notes |
|---|---|---|
| On-chain visibility | `compact-core:compact-privacy-disclosure` skill → ledger source | What the network can see vs what stays private |
| Token behavior | `compact-core:compact-tokens` skill → ledger source | NIGHT/DUST mechanics, custom token patterns |
| Transaction semantics | Skills → `midnight-ledger` source | How transactions are structured and validated |

## Source Code Repositories

When Direct Tooling Checks or compilation cannot resolve a claim, and you need to check source, use this table to find the right repository. Use the `midnight-tooling` plugin's GitHub tools to navigate it.

| What You're Verifying | Repository | Notes |
|---|---|---|
| Compiler behavior, language semantics, stdlib | [LFDT-Minokawa/compact](https://github.com/LFDT-Minokawa/compact) | The Compact compiler source (Scheme). Authoritative for syntax, type system, stdlib |
| Ledger types, transaction structure, token ops | [midnightntwrk/midnight-ledger](https://github.com/midnightntwrk/midnight-ledger) | Rust. Defines ledger ADTs (Counter, Map, Set, MerkleTree), transaction validation |
| ZK proof system, circuit compilation | [midnightntwrk/midnight-zk](https://github.com/midnightntwrk/midnight-zk) | Rust. ZK proof generation, circuit constraints, ZKIR |
| Node runtime, on-chain execution | [midnightntwrk/midnight-node](https://github.com/midnightntwrk/midnight-node) | Rust. How transactions are executed on-chain |
| Compact CLI releases, installer | [midnightntwrk/compact](https://github.com/midnightntwrk/compact) | Release binaries and changelog (distinct from LFDT-Minokawa/compact source) |

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Generic verification methodology and confidence scoring | `midnight-verify:verify-correctness` |
| SDK/TypeScript verification | `midnight-verify:verify-sdk` |
| Stdlib function verification protocol and export inventory | `compact-core:compact-standard-library` |
| Compiler usage, version selection, compile flags | `compact-core:compact-compilation` |
| Troubleshooting verification failures and compile errors | `compact-core:compact-debugging` |
| Privacy and disclosure verification | `compact-core:compact-privacy-disclosure` |
| Security review methodology | `compact-core:compact-review` |
| Circuit cost analysis | `compact-core:compact-circuit-costs` |
| Design patterns | `compact-core:compact-patterns` |
| Token verification | `compact-core:compact-tokens` |
| MCP tool usage | `midnight-mcp` plugin |
