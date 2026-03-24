# Query Expansion

Techniques for turning raw intent into better search input. Apply these before calling MCP search tools.

## Query Rewriting

**When to apply:** Always, as a first pass on any search query.

Rewrite natural language into keyword-rich queries using Midnight-specific terms. Expand shorthand only where genuinely written both ways (e.g., "ZKP" becomes "Zero Knowledge Proof (ZKP)"). Do NOT expand DUST, tDUST, DApp, or other terms that are standard as-is. Fix obvious typos. Strip filler words ("how do I", "what is the best way to").

**Examples:** `examples/query-rewriting.md`

## Multi-Query Generation

**When to apply:** When a single query is unlikely to capture all relevant results — ambiguous terms, multiple synonyms, broad topics.

Generate 2-3 semantically different queries from the same intent. Each query should target different terminology that might appear in the indexed content. Run all queries against the same tool. Combine and deduplicate results.

**Examples:** `examples/multi-query.md`

## Step-Back Queries

**When to apply:** When the specific question is too narrow to return results, or when background context would improve understanding of specific results.

Generate a more abstract version of the question. Search for the abstract version first or alongside the specific query. The step-back result provides context; the specific query provides the direct answer.

**Examples:** `examples/step-back-queries.md`

## HyDE (Pseudo-Answer Generation)

**When to apply:** When the query is conceptual and hard to reduce to keywords, or when you know roughly what the answer should look like but need to find real examples.

Generate a short hypothetical answer — a Compact code snippet or documentation paragraph that would answer the question if it existed. Extract the distinctive terms and structure from that hypothetical. Use those terms as the search query. Do NOT present the hypothetical answer to the user — it is a search aid only.

**Examples:** `examples/hyde.md`

## Decomposition

**When to apply:** When the question involves multiple independent concerns that should be searched separately.

Identify the distinct sub-questions. Search each independently. Combine results. This is better than a single broad query because each sub-question gets targeted results rather than diluted matches.

**Examples:** `examples/decomposition.md`
