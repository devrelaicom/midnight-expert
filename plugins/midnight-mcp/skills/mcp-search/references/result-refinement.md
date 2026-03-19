# Result Refinement

Techniques for processing results after retrieval. All techniques operate on the result set returned by MCP tools — they are client-side reasoning performed on the response.

## Relevance Reranking

**When to apply:** Always, as a first pass on results.

Re-evaluate each result against the original intent, not just the search query. A result may match query keywords but not address the actual question. Check `relevanceScore` in the response — scores below 0.3 are often tangentially related. Mentally reorder results by how directly they answer the question. Discard results that are clearly irrelevant even if their score is moderate.

**Examples:** `examples/relevance-reranking.md`

## Trust-Aware Reranking

**When to apply:** When result reliability matters — production code, security-sensitive patterns, or when results come from mixed sources.

Check `source.repository` in each result. Apply this trust hierarchy:
- Highest: `midnightntwrk` official repos (compiler, SDK, examples)
- High: `OpenZeppelin` audited libraries
- Medium: `LFDT-Minokawa` infrastructure
- Lower: community and third-party code

Boost results from higher-trust sources. When two results provide similar information, prefer the higher-trust source. This is especially important for `midnight-search-typescript` results where server-side filtering is unavailable.

**Examples:** `examples/trust-aware-reranking.md`

## Freshness Reranking

**When to apply:** When the query is time-sensitive — version-specific questions, migration guidance, recent changes, or when the user says "latest" or "current."

Check date metadata in results where available. Prefer results from more recent sources when recency matters. Be cautious: in a blockchain context, older audited code may be more reliable than newer unaudited code. Freshness should boost, not override, trust rankings.

**Examples:** `examples/freshness-reranking.md`

## Deduplication

**When to apply:** When results contain near-identical content from the same or forked repos. Common when searching broad topics.

Identify results that contain substantially the same code or text. Keep the result from the most authoritative source. Collapse duplicates into a single entry, noting that alternatives exist. Watch for fork-induced duplication — the same contract may appear in multiple repos.

**Examples:** `examples/deduplication.md`

## Coverage Balancing

**When to apply:** When the query has multiple facets or sub-topics, and results cluster around only one facet.

Check whether the results cover the different parts of the question. If 8 of 10 results address facet A and 0 address facet B, the result set is imbalanced. Consider a follow-up search targeted at the underrepresented facet. When presenting results, organize by facet rather than by score.

**Examples:** `examples/coverage-balancing.md`

## Answerability Scoring

**When to apply:** As a final filter before using results.

For each result, assess: "does this actually answer the user's question, or does it just mention the same terms?" A result that contains the relevant code pattern is answerable. A result that mentions the pattern name in passing is not. Prefer results that provide complete, actionable information over those that provide fragments or tangential mentions.

**Examples:** `examples/answerability-scoring.md`
