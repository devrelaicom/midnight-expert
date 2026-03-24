# Tool Routing

Techniques for selecting and configuring MCP tools before executing a search.

## Intent Classification

**When to apply:** Always, before selecting a tool.

Classify the search intent into one of these categories:

- `code_example` — user wants to see how something is implemented. Route to `midnight-search-compact` or `midnight-search-typescript`.
- `conceptual` — user wants to understand how something works. Route to `midnight-search-docs`.
- `api_reference` — user wants exact API signatures or type definitions. Route to `midnight-search-typescript` with `includeTypes: true`.
- `troubleshooting` — user has an error or problem. Route to `midnight-search-docs` with `category: "guides"`, possibly `midnight-search-compact` for error patterns.
- `migration` — user is upgrading versions. Route to `midnight-search-docs`, `midnight-fetch-docs` for release notes.
- `specific_page` — user knows which doc page they need. Route to `midnight-fetch-docs` directly.

**Examples:** `examples/intent-classification.md`

## Source Routing

**When to apply:** After intent classification, to select the specific tool.

Map the classified intent and detected entities to the correct MCP tool:

- Compact language questions — `midnight-search-compact`
- TypeScript/SDK questions — `midnight-search-typescript`
- Conceptual/architectural questions — `midnight-search-docs`
- Known doc page — `midnight-fetch-docs` with the page path
- Mixed — use cross-tool orchestration (technique 5)

Decision factors: entity types in the query (Compact types indicate compact search, npm packages indicate TypeScript search), language context from prior turns, facets extracted from the query.

**Examples:** `examples/source-routing.md`

## Trusted-Source Filtering

**When to apply:** When result reliability matters more than breadth — production code, security-sensitive patterns, official examples.

- For `midnight-search-compact`: set `filter.repository` to restrict to trusted organizations. Supported prefixes: `midnightntwrk`, `OpenZeppelin`, `LFDT-Minokawa`.
- For `midnight-search-typescript`: no server-side filter available. Apply trust-aware reranking from the Result Refinement cluster after retrieval.
- For `midnight-search-docs`: all results are from official docs — no additional filtering needed.
- For `midnight-fetch-docs`: fetches directly from docs.midnight.network — inherently trusted.

**Examples:** `examples/trusted-source-filtering.md`

## Parameter Optimization

**When to apply:** After tool selection, before making the call.

Set tool-specific parameters to improve result quality:

- `midnight-search-compact`: `limit` (default 10, increase to 15-20 for broad searches), `filter.repository` (for trusted sources), `filter.isPublic` (for public-only code)
- `midnight-search-typescript`: `limit`, `includeExamples` (true for usage patterns, false for type-only lookups), `includeTypes` (true for type definitions, false for implementation code)
- `midnight-search-docs`: `limit`, `category` — set `"guides"` for tutorials/howtos, `"api"` for API references, `"concepts"` for architecture/theory, omit or use `"all"` for broad search
- `midnight-fetch-docs`: `path` (required), `extractSection` (use when you only need one heading from a large page)

**Examples:** `examples/parameter-optimization.md`

## Cross-Tool Orchestration

**When to apply:** When a single tool cannot provide complete coverage — typically for comprehensive research, or when code examples need conceptual context.

- **Compact + Docs** (most common): search compact for implementation patterns, search docs for conceptual explanation. Useful for answering "how and why" questions.
- **TypeScript + Compact**: search TypeScript for SDK integration, search compact for the contract side. Useful for end-to-end DApp questions.
- **Search + Fetch**: use search to discover the relevant page, then fetch for full content. Useful when search snippets are insufficient.

Limit to 2-3 tool calls per question. Additional calls rarely add value beyond the first 2-3.

**Examples:** `examples/cross-tool-orchestration.md`
