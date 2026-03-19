---
name: mcp-search
description: Use when the user asks to find Compact examples, look up SDK types, search Midnight codebase, evaluate search result reliability, or asks about midnight search, searching Compact code, searching TypeScript SDK code, searching Midnight documentation, fetching docs, MCP search tools, semantic search over Midnight repos, optimizing search queries, midnight-search-compact, midnight-search-typescript, midnight-search-docs, or midnight-fetch-docs.
---

# Midnight MCP Search Tools

Four search tools provide access to Compact code, TypeScript SDK code, indexed documentation, and live documentation pages. Each tool targets a different corpus and has different reliability characteristics.

## midnight-search-compact

Semantic search across Compact code and patterns from Midnight Foundation, partners, and ecosystem projects.

**When to use:** Finding Compact code patterns, usage examples, standard library usage, contract structure patterns, or verifying that a Compact construct exists in real code.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `query` | Yes | Search query — specific terms produce better results than vague descriptions |

**Interpreting results:**

- **`relevanceScore`** — Higher is better. Scores below 0.3 are often tangentially related
- **`source.repository`** — Check the source organization. Code from `midnightntwrk`, `OpenZeppelin`, or `LFDT-Minokawa` repositories is more likely to be correct and current than community or third-party code
- Indexed code may be outdated. A function appearing in search results does not guarantee it exists in the current release. Cross-reference with `compact-core:compact-standard-library` or compilation for confirmation

**Example queries:**

| Goal | Good Query | Why |
|------|-----------|-----|
| Find token transfer patterns | `token transfer shielded` | Specific terms matching Compact patterns |
| Find access control examples | `access control owner witness` | Multiple related terms narrow results |
| Find ledger state patterns | `ledger state Map Counter` | Specific type names improve relevance |

## midnight-search-typescript

Search TypeScript SDK code, types, and API implementations.

**When to use:** Finding SDK API usage patterns, TypeScript type definitions, DApp integration code, provider setup, or wallet interaction patterns.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `query` | Yes | Search query targeting TypeScript/SDK concepts |

**Interpreting results:**

- Same `relevanceScore` and `source.repository` checks apply as with `midnight-search-compact`
- TypeScript results include generated types from contract compilation — these reflect actual compiler output
- Import paths change between SDK versions. Always check `source.repository` version metadata

## midnight-search-docs

Full-text search of the official Midnight documentation index.

**When to use:** Finding conceptual explanations, architecture overviews, configuration guides, getting-started content, or network information.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `query` | Yes | Search query targeting documentation content |

**Interpreting results:**

- The documentation search index may lag behind published docs. Published docs themselves can lag behind actual releases
- Check `relevanceScore` — low-scoring results are often tangentially related or pulled from unrelated sections
- Documentation is most reliable for high-level concepts and architecture; least reliable for exact API signatures and version-specific behavior
- Always verify critical information found in docs using an independent source (compilation, `npm view`, or source code)

## midnight-fetch-docs

Live fetch of documentation pages from docs.midnight.network. Returns the rendered content of a specific documentation page.

**When to use:** When you know the specific documentation page you need, when the search index returns outdated results, or when you need the full content of a page rather than search snippets.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `path` | Yes | Documentation path relative to docs.midnight.network |

**Common documentation paths:**

| Path | Content |
|------|---------|
| `/devnet/getting-started` | Getting started guide |
| `/devnet/building-your-first-dapp` | First DApp tutorial |
| `/compact/reference` | Compact language reference |
| `/compact/standard-library` | Standard library reference |
| `/node/overview` | Node architecture overview |
| `/indexer/overview` | Indexer overview |
| `/proof-server/overview` | Proof server overview |
| `/token/overview` | Token and tokenomics overview |

## Query Optimization

The quality of search results depends heavily on query construction.

### Effective Query Patterns

| Strategy | Example | Why It Works |
|----------|---------|-------------|
| Use specific Compact terms | `Counter Bytes Map ledger` | Matches actual type and construct names |
| Include the domain | `shielded token transfer circuit` | Narrows to the right code patterns |
| Name the construct | `witness function parameter` | Matches declaration patterns |
| Combine noun + action | `deploy contract provider` | Matches SDK usage patterns |

### Ineffective Query Patterns

| Pattern | Problem | Better Alternative |
|---------|---------|-------------------|
| `how do I make a contract` | Too vague, natural language | `contract ledger circuit export` |
| `error handling` | Too generic | `assert require revert Compact` |
| `best practices` | Not searchable | Ask about the specific pattern |

### Combining Search Tools

For comprehensive results on a topic, combine `midnight-search-compact` with `midnight-search-docs`:

1. Use `midnight-search-compact` to find real code implementing the pattern
2. Use `midnight-search-docs` to find the conceptual explanation and any caveats

This two-call approach covers both implementation and documentation. Do not exceed 2 search calls per question — additional calls rarely add value beyond what the first two provide.

## Interpreting Results

All search tools return a `relevanceScore` with each result. Use these thresholds consistently across all four tools:

| Score Range | Interpretation |
|-------------|---------------|
| 0.7 and above | High confidence — result is directly relevant to the query |
| 0.3 to 0.7 | Moderate confidence — review the result to confirm relevance before relying on it |
| Below 0.3 | Low confidence — result is often tangentially related; do not treat as authoritative |

Low-scoring results can still contain useful context, but always verify critical information from low-scoring results against an independent source (compilation, `npm view`, or official documentation).

## Trusted Sources

When evaluating search results, prioritize results from these organizations:

| Organization | Repository Prefix | Content |
|-------------|-------------------|---------|
| Midnight Foundation | `midnightntwrk` | Core language, compiler, SDK, examples |
| OpenZeppelin | `OpenZeppelin` | Audited Compact libraries and modules |
| LFDT-Minokawa | `LFDT-Minokawa` | Infrastructure and tooling |

Results from other sources may be valid but require independent verification before relying on them.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `mcp-overview` |
| Verification methodology using search results | `compact-core:verify-correctness` |
| Compact standard library reference | `compact-core:compact-standard-library` |
| Compact compilation for verifying search results | `compact-core:compact-compilation` |
