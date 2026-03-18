---
name: mcp-overview
description: Use when the user asks about listing available tools, what the MCP server can do, compound tools, saving tokens, call frequency, rate limiting, which MCP tool to use for a task, tool categories, tool routing, suggesting the right tool, MCP overview, midnight tool routing, available MCP capabilities, or how to choose between midnight MCP tools.
---

# Midnight MCP Tool Overview

The Midnight MCP server exposes 32 tools across 8 categories. This skill covers what each category does, which tool to use for a given task, and how to minimize token usage.

> **Note:** The routing table below lists 29 unique tool names. The total of 32 includes compound tools counted in both their own rows and the categories they compose, plus Meta-category tools (`midnight-get-update-instructions`, `midnight-get-status`) that overlap with Health. The category counts reflect functional groupings, not a deduplicated list.

## Tool Categories

| Category | Tools | Purpose |
|----------|-------|---------|
| **Search** | 4 | Find code, documentation, and patterns across Midnight repositories |
| **Analyze** | 5 | Inspect contract structure, privacy boundaries, circuit graphs, and diffs |
| **Format** | 1 | Format Compact source using the official formatter |
| **Diff** | 1 | Semantic diff between contract versions |
| **Simulate** | 4 | Deploy, call, inspect, and tear down contract sessions |
| **Repository** | 6 + 2 compound | Retrieve files, examples, updates, breaking changes, and version-specific content |
| **Health** | 6 | Server status, rate limits, version checks, compiler listings, library listings |
| **Meta** | 3 | Update instructions, cache stats, diagnostics |

## Tool Routing — Intent-to-Tool Mapping

Use this table to select the right tool based on what you need to accomplish.

| Intent | Tool | Notes |
|--------|------|-------|
| Find Compact code patterns or examples | `midnight-search-compact` | Semantic search over Compact code |
| Find TypeScript SDK usage | `midnight-search-typescript` | Search SDK code, types, API implementations |
| Look up official documentation | `midnight-search-docs` | Full-text search of indexed docs |
| Fetch a specific doc page live | `midnight-fetch-docs` | Live fetch from docs.midnight.network |
| Understand contract structure | `midnight-analyze-contract` | 5-stage analysis pipeline |
| Check if code compiles | `midnight-compile-contract` | Syntax/type check or full ZK compilation |
| Compile a multi-file project | `midnight-compile-archive` | Multi-file project compilation |
| View circuit call graph | `midnight-visualize-contract` | Mermaid output of circuit and ledger access |
| Analyze privacy boundaries | `midnight-prove-contract` | Per-circuit privacy boundary analysis |
| Format Compact code | `midnight-format-contract` | Official formatter, returns formatted code + diff |
| Compare two contract versions | `midnight-diff-contracts` | Semantic diff between versions |
| Test a contract interactively | `midnight-simulate-deploy` | Start a simulation session |
| Execute a circuit | `midnight-simulate-call` | Call a circuit in an active session |
| Read simulation state | `midnight-simulate-state` | Ledger values, available circuits, call history |
| End a simulation session | `midnight-simulate-delete` | Free resources |
| Get a file from a repo | `midnight-get-file` | Retrieve by repo alias and path |
| Browse example contracts | `midnight-list-examples` | List examples with complexity ratings |
| Check recent changes | `midnight-get-latest-updates` | Recent commits across Midnight repos |
| Check for breaking changes | `midnight-check-breaking-changes` | Breaking changes between versions |
| Get a file at a specific version | `midnight-get-file-at-version` | Exact file content at a tagged version |
| Compare syntax across versions | `midnight-compare-syntax` | Diff between language versions |
| Full upgrade assessment | `midnight-upgrade-check` | Compound: version + breaking changes + migration |
| Get repo context for a task | `midnight-get-repo-context` | Compound: version + syntax ref + examples |
| Check server health | `midnight-health-check` | Server health and API connectivity |
| View rate limits and cache | `midnight-get-status` | Rate limits, cache stats |
| Check installed version | `midnight-check-version` | Compare installed vs npm latest |
| Get update instructions | `midnight-get-update-instructions` | Platform-specific update commands |
| List compiler versions | `midnight-list-compiler-versions` | Installed compilers with language version mapping |
| List available libraries | `midnight-list-libraries` | Available OpenZeppelin Compact modules |

## Compound Tools

Compound tools bundle multiple related operations into a single call, saving significant token overhead.

| Compound Tool | Replaces | Token Savings |
|---------------|----------|---------------|
| `midnight-upgrade-check` | `midnight-check-version` + `midnight-check-breaking-changes` + migration guidance | ~60% |
| `midnight-get-repo-context` | `midnight-check-version` + `midnight-compare-syntax` + `midnight-list-examples` | ~50% |

Always prefer compound tools when they cover your needs. Use the individual tools only when you need a subset of the compound tool's output or need to customize parameters that the compound tool does not expose.

## Call Frequency Guidance

Different tool categories have different cost profiles. Follow these limits to avoid unnecessary token usage and rate limiting.

| Category | Max Calls | Rationale |
|----------|-----------|-----------|
| Search tools | 2 per question | Results are scored and ranked; additional calls rarely add value |
| Analysis / compile tools | 1 per contract | Results are deterministic — recompiling the same source produces the same output |
| Simulation tools | As needed | Stateful lifecycle requires multiple calls by design |
| Repository tools | As needed | File retrieval is cheap and targeted |
| Health tools | 1 per session | Status does not change during a conversation |

## Key Principles

1. **Use compound tools when available.** `midnight-upgrade-check` and `midnight-get-repo-context` save tokens and reduce round trips
2. **Prefer `midnight-search-compact` for Compact questions** and `midnight-search-typescript` for SDK/TypeScript questions. Using the wrong search tool produces low-relevance results
3. **Do not re-call deterministic tools.** If you already compiled a contract or analyzed it, the result will not change for the same input
4. **Check relevance scores.** Search results with low `relevanceScore` values are often tangential — do not treat them as authoritative

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Search tool details and query optimization | `mcp-search` |
| Analysis and compilation tool details | `mcp-analyze` |
| Simulation lifecycle | `mcp-simulate` |
| Repository and version tools | `mcp-repository` |
| Health and diagnostics | `mcp-health` |
| Compact compilation with local CLI | `compact-core:compact-compilation` |
| Verification methodology using MCP tools | `compact-core:verify-correctness` |
| Compact standard library reference | `compact-core:compact-standard-library` |
