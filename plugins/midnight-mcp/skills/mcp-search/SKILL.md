---
name: midnight-mcp:mcp-search
version: 1.0.0
description: This skill should be used when the user asks about searching Midnight code, searching Compact examples, searching TypeScript SDK code, finding Midnight documentation, fetching docs pages, using MCP search tools (midnight-search-compact, midnight-search-typescript, midnight-search-docs, midnight-fetch-docs), the /midnight-mcp:search command, optimizing search queries, search techniques like query rewriting or multi-query generation, improving search result quality, or reranking search results.
---

# Midnight MCP Search

Search techniques and tool guidance for the four Midnight MCP search tools. This skill provides a technique library organized as cluster references with per-technique example files. Load only what you need for the current task.

**Not this skill:** If the user asks what MCP tools are available, how tools are categorized, or for a general overview of Midnight tooling, use `midnight-mcp:mcp-overview` instead. This skill is for *executing* searches, not describing the tools.

## Search Tools

| Tool | Corpus | Use When |
|------|--------|----------|
| `midnight-search-compact` | Compact code from Foundation, partners, ecosystem | Finding code patterns, examples, stdlib usage |
| `midnight-search-typescript` | TypeScript SDK code and types | Finding SDK API usage, type definitions, DApp integration |
| `midnight-search-docs` | Official documentation index | Finding conceptual explanations, guides, architecture |
| `midnight-fetch-docs` | Live docs.midnight.network pages | Fetching a specific known page, getting full content |

## Intent-to-Reference Routing

Identify your current search task, then load the listed reference files. If multiple rows match, combine the reference lists (deduplicate).

| Intent / Task | Reference Files |
|---------------|----------------|
| Quick lookup of a specific thing | `references/tool-routing.md` (5 techniques) |
| Find code examples for a pattern | `references/query-expansion.md` (5) + `references/tool-routing.md` (5) + `references/code-search.md` (5) |
| Find conceptual documentation | `references/query-expansion.md` (5) + `references/tool-routing.md` (5) |
| Debug an error using search | `references/code-search.md` (5) + `references/tool-routing.md` (5) |
| Comprehensive research on a topic | `references/query-expansion.md` (5) + `references/context-gathering.md` (4) + `references/tool-routing.md` (5) + `references/result-refinement.md` (6) |
| Search with project context | `references/context-gathering.md` (4) + `references/tool-routing.md` (5) |
| Migration / version upgrade search | `references/context-gathering.md` (4) + `references/code-search.md` (5) + `references/tool-routing.md` (5) |
| Refine poor initial results | `references/iterative-search.md` (4) + `references/result-refinement.md` (6) |
| Understand server-side limitations | `references/server-enhanced.md` (7) |

## Loading Example Files

Each reference file describes techniques and names their example files. After reading a reference file, evaluate which techniques you will apply. Load the example file **only** for techniques you intend to use. Do not load example files for techniques you are skipping.

## Trusted Sources

When evaluating search results, prioritize results from these organizations:

| Organization | Repository Prefix | Content |
|-------------|-------------------|---------|
| Midnight Foundation | `midnightntwrk` | Core language, compiler, SDK, examples |
| OpenZeppelin | `OpenZeppelin` | Audited Compact libraries and modules |
| LFDT-Minokawa | `LFDT-Minokawa` | Infrastructure and tooling |

Results from other sources may be valid but require independent verification before relying on them.

## `/midnight-mcp:search` Command

Users can invoke `/midnight-mcp:search` for technique-aware search with preset modes (`--quick`, `--thorough`, `--debug`, `--examples`, `--migration`), source flags, and individual technique flags. See the command file for full flag reference and execution steps.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `midnight-mcp:mcp-overview` |
| Verification methodology using search results | `midnight-verify:verify-correctness` |
| Compact standard library reference | `compact-core:compact-standard-library` |
| Compact compilation for verifying search results | `midnight-tooling:compact-cli` |
