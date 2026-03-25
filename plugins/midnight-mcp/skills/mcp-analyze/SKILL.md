---
name: mcp-analyze
description: This skill should be used when the user asks about analyzing a Compact contract, visualizing a contract, proving a contract, MCP analyze, contract analysis pipelines, midnight-analyze-contract, midnight-visualize-contract, midnight-prove-contract, midnight-diff-contracts, semantic contract diff, or circuit visualization.
---

# Midnight MCP Analysis Tools

Four tools for analyzing, visualizing, proving, and diffing Compact contracts. All tools produce deterministic results — call each tool once per contract and reuse the result.

For compilation tools (`midnight-compile-contract`, `midnight-compile-archive`), see the `mcp-compile` skill.
For formatting tools (`midnight-format-contract`), see the `mcp-format` skill.

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

All tools produce deterministic output for the same input. Call each tool once per contract and reuse the result. Re-calling with the same source code is wasteful.

| Tool | Calls per Contract |
|------|--------------------|
| `midnight-analyze-contract` | 1 |
| `midnight-visualize-contract` | 1 |
| `midnight-prove-contract` | 1 |
| `midnight-diff-contracts` | 1 per version pair |

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| MCP-hosted compilation workflows and error recovery | `mcp-compile` |
| MCP-hosted formatting and code style | `mcp-format` |
| Tool routing and category overview | `mcp-overview` |
| Local compilation with Compact CLI | `compact-core:compact-compilation` |
| Verification methodology using compilation | `midnight-verify:verify-correctness` |
| Compact standard library for resolving compile errors | `compact-core:compact-standard-library` |
