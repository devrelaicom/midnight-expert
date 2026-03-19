# Facet Extraction Examples

## When to Apply

When the query implies constraints that should be used for tool selection or parameter filtering rather than as search terms.

## Examples

### TypeScript Type Definition Request

**Before:**
```
User query: "show me the TypeScript types for contract deployment"
Naive search: "TypeScript types contract deployment" on midnight-search-compact
```

**After:**
```
Extracted facets:
  language: TypeScript
  content_type: type_definitions

Route to: midnight-search-typescript with includeTypes: true
Search query: "contract deployment type definition"
```

**Why:** "TypeScript" is a routing facet, not a search term. It tells us to use `midnight-search-typescript` instead of `midnight-search-compact`. "Types" signals `includeTypes: true` rather than being a keyword.

### Official Documentation Request

**Before:**
```
User query: "what does the official docs say about token privacy"
Naive search: "official docs token privacy" on midnight-search-compact
```

**After:**
```
Extracted facets:
  source: official_docs
  content_type: conceptual

Route to: midnight-search-docs, possibly midnight-fetch-docs
Search query: "token privacy shielded"
```

**Why:** "Official docs" is a source facet directing us to the documentation tools. Including "official" as a search keyword would not improve results — all docs results are already official.

### Recent Example Request

**Before:**
```
User query: "find me a recent example of Counter usage"
Naive search: "recent example Counter usage"
```

**After:**
```
Extracted facets:
  content_type: example
  recency: recent

Route to: midnight-search-compact with trusted sources
Search query: "Counter usage example increment ledger"
Apply: freshness reranking on results
```

**Why:** "Recent" is a freshness facet for result sorting, not a search keyword. "Example" signals we want code, not documentation. These facets inform tool selection and post-processing.

### API Change History Request

**Before:**
```
User query: "how did the ledger API change in the latest version"
Naive search: "ledger API change latest version"
```

**After:**
```
Extracted facets:
  recency: latest
  content_type: changelog/migration

Route to: midnight-search-docs with category: "api"
Search query: "ledger API changes migration breaking"
Apply: freshness reranking to boost most recent results
```

**Why:** "Latest" and "change" are temporal facets that inform freshness reranking. "API" signals the docs `category` parameter. The actual search query focuses on the content terms.

## Anti-Patterns

### Including Facet Terms as Literal Search Keywords

**Wrong:**
```
Search query: "official recent TypeScript example Counter"
```

**Problem:** "Official", "recent", and "TypeScript" are not content terms — they are meta-information about what kind of result the user wants. Including them as keywords dilutes the query and may match irrelevant content that happens to contain these words.

**Instead:** Extract facets to inform routing and post-processing. Keep only content terms in the search query.

### Ignoring Facets Entirely

**Wrong:**
```
User query: "show me the TypeScript types for deployment"
→ Route to midnight-search-compact (default) with no parameters
```

**Problem:** Ignoring the TypeScript facet routes to the wrong tool. Ignoring the "types" facet misses the `includeTypes: true` parameter that would improve results.

**Instead:** Always extract facets before constructing the query. Even if you are not sure about a facet, it is better to route appropriately than to ignore signals.

### Extracting Contradictory Facets Without Resolving

**Wrong:**
```
User query: "show me the latest stable Counter API"
Extracted facets: recency=latest, stability=stable
→ Apply both without noting the tension
```

**Problem:** "Latest" and "stable" may conflict — the latest version might not be stable. Applying both facets without resolution leads to confusing result ordering.

**Instead:** Note the tension and resolve it. Ask the user to clarify, or default to stable with a note that newer versions exist.
