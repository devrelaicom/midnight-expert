---
name: mcp-analyze
description: Use when the user asks to check contract for errors, compile my Compact code, show contract call graph, privacy analysis, compare two contracts, format my code, or asks about MCP compile, MCP analyze, contract analysis, semantic contract diff, circuit visualization, midnight-analyze-contract, midnight-compile-contract, midnight-compile-archive, midnight-visualize-contract, midnight-prove-contract, midnight-format-contract, or midnight-diff-contracts.
---

# Midnight MCP Analysis and Compilation Tools

Seven tools for analyzing, compiling, visualizing, formatting, proving, and diffing Compact contracts. All analysis and compilation tools produce deterministic results — call each tool once per contract and reuse the result.

## midnight-analyze-contract

A 5-stage analysis pipeline that examines contract structure, identifies patterns, and produces actionable recommendations.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Compact source code |
| `mode` | No | `fast` (source-level analysis only) or `deep` (compile-backed analysis). Default: `fast` |
| `include` | No | Array of sections to include in the response. Omit for all sections. Options: `summary`, `structure`, `findings`, `recommendations` |

**Analysis stages:**

1. **Parsing** — Tokenize and build AST
2. **Structure extraction** — Identify ledger fields, circuits, witnesses, exports
3. **Pattern matching** — Detect known patterns (access control, token, registry, etc.)
4. **Issue detection** — Find potential problems (missing guards, unused fields, disclosure issues)
5. **Recommendation generation** — Suggest improvements based on findings

**Mode selection:**

| Mode | Speed | Depth | When to Use |
|------|-------|-------|-------------|
| `fast` | < 1s | Source-level only | Quick structural overview, pattern identification |
| `deep` | 5-30s | Compile-backed | Full analysis including ZK circuit metrics and type checking |

**Reducing response size:** Use the `include` parameter to request only the sections you need. For a quick overview, use `include: ["summary"]`. For actionable items only, use `include: ["findings", "recommendations"]`.

## midnight-compile-contract

Compile a Compact contract with configurable options. Use `skipZk=true` for fast syntax and type checking; use `fullCompile=true` when you need ZK proof generation artifacts.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Compact source code |
| `skipZk` | No | `true` for fast compilation (~1-2s) that checks syntax and types but skips ZK circuit generation. Default: `false` |
| `fullCompile` | No | `true` for full compilation (~10-30s) including ZK proof generation. Default: `false` |
| `versions` | No | Array of compiler versions to test against. Enables multi-version testing |
| `detect` | No | `true` to auto-detect the appropriate language version. Default: `false` |

**Compilation strategies:**

| Goal | Settings | Time |
|------|----------|------|
| Syntax/type check | `skipZk: true` | ~1-2s |
| Full ZK compilation | `fullCompile: true` | ~10-30s |
| Multi-version compatibility | `versions: ["0.X.0", "0.Y.0"]` | Per-version time |
| Auto-detect language version | `detect: true` | Adds detection overhead |

**`skipZk` / `fullCompile` interaction:**

- **`skipZk: true`** — Skips ZK circuit generation entirely. Fast syntax and type checking only (~1-2s)
- **`fullCompile: true`** — Performs full compilation including ZK proof generation (~10-30s)
- **Both omitted** — Standard compilation runs, which includes ZK circuit generation but may not produce all deployment artifacts. Equivalent to neither flag being set
- **Both set** — `skipZk` takes precedence; ZK circuit generation is skipped. Do not set both — use one or the other

**When to use each strategy:**

- **`skipZk: true`** — During development, when checking if code compiles, validating syntax corrections, or iterating on contract design. Covers syntax errors, type mismatches, and missing exports
- **`fullCompile: true`** — Before deployment, when circuit metrics matter, when you need prover/verifier keys, or when verifying ZK proof generation behavior
- **Multi-version testing** — When checking compatibility across Compact language versions or preparing for an upgrade

## midnight-compile-archive

Compile a multi-file Compact project. Use when a contract spans multiple source files or depends on library modules.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `files` | Yes | Object mapping file paths to source content |
| `entryPoint` | Yes | Path to the main contract file |
| `skipZk` | No | Same behavior as `midnight-compile-contract` |

Use this tool when working with contracts that import from other Compact files, use OpenZeppelin library modules, or are structured as multi-file projects.

## midnight-visualize-contract

Generate a visual representation of a contract's circuit call graph and ledger access patterns. Output is in Mermaid diagram format.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Compact source code |

**Output includes:**

- Circuit call graph showing which circuits call which other circuits
- Ledger access patterns showing which circuits read or write which ledger fields
- Export boundaries showing which circuits are exposed to external callers

Use this tool to understand complex contracts with many interacting circuits, to identify unexpected ledger access patterns, or to document contract architecture.

**Rendering note:** Present Mermaid output in a fenced code block with the `mermaid` language identifier for rendering.

## midnight-prove-contract

Analyze privacy boundaries on a per-circuit basis. Shows what each circuit proves, what data flows through the ZK boundary, and what is disclosed.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Compact source code |

**Output includes:**

- Per-circuit privacy analysis
- Data flow across the ZK proof boundary
- Disclosure points — where private data becomes public
- Witness inputs and their visibility

Use this tool when reviewing privacy properties of a contract, when auditing disclosure behavior, or when verifying that sensitive data stays within the ZK proof boundary.

## midnight-format-contract

Format Compact source code using the official formatter. Returns both the formatted code and a diff showing what changed.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Compact source code to format |

**Output includes:**

- Formatted source code
- Diff showing changes from the original

Use this tool to apply consistent formatting before sharing code, to clean up user-provided code before analysis, or to verify formatting compliance.

## midnight-diff-contracts

Compute a semantic diff between two versions of a contract. Unlike a text diff, this understands Compact structure and reports changes in terms of circuits, ledger fields, witnesses, and exports.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `oldSource` | Yes | Original contract source |
| `newSource` | Yes | Modified contract source |

**Output includes:**

- Added, removed, and modified circuits
- Ledger field changes
- Witness signature changes
- Export changes
- Breaking change indicators

Use this tool when reviewing contract changes before deployment, when comparing a user's contract against a known-good version, or when assessing the impact of an upgrade.

## Call Frequency

All analysis and compilation tools produce deterministic output for the same input. Call each tool once per contract and reuse the result. Re-calling with the same source code is wasteful.

| Tool | Calls per Contract |
|------|--------------------|
| `midnight-analyze-contract` | 1 |
| `midnight-compile-contract` | 1 (per version, if multi-version testing) |
| `midnight-compile-archive` | 1 |
| `midnight-visualize-contract` | 1 |
| `midnight-prove-contract` | 1 |
| `midnight-format-contract` | 1 |
| `midnight-diff-contracts` | 1 per version pair |

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `mcp-overview` |
| Local compilation with Compact CLI | `compact-core:compact-compilation` |
| Verification methodology using compilation | `compact-core:verify-correctness` |
| Compact standard library for resolving compile errors | `compact-core:compact-standard-library` |
