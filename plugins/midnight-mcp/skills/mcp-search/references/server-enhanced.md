# Server-Enhanced Search

Techniques that require MCP server changes to implement. Each technique is tracked as a GitHub issue on `devrelaicom/compact-playground`. Until server-side support is added, the LLM cannot apply these techniques directly — they are documented here for context and to explain current limitations.

## Hybrid Search

**What it does:** Combines keyword/BM25 matching with vector similarity search using reciprocal rank fusion. A single query benefits from both exact term matching and semantic similarity.

**What it would enable:** Better results from single queries that mix exact terms (type names like `Counter`, `MerkleTree`) with semantic concepts ("how to manage state"). Currently the LLM compensates with multi-query generation, which doubles API calls.

**Current limitation:** The MCP server uses a single retrieval strategy. Queries that need both keyword precision and semantic recall require the LLM to issue separate queries.

**Server-side implementation:** Add a `hybrid` boolean parameter to search endpoints (default: `true`). Implement reciprocal rank fusion to combine BM25 and vector results. Optionally expose a `hybridWeight` parameter for tuning.

**Plugin changes once implemented:** Update `references/tool-routing.md` parameter optimization section to include `hybrid` parameter guidance.

## Field-Aware Retrieval

**What it does:** Weights different document fields (title, headings, code blocks, body text) differently in scoring.

**What it would enable:** A query for `MerkleTree` would rank a document titled "MerkleTree Operations" higher than one that mentions MerkleTree once in the body. Currently all fields are weighted equally, requiring the LLM to perform client-side relevance reranking.

**Current limitation:** All text fields are scored equally. Title and heading matches — which are stronger relevance signals — receive the same weight as body text mentions.

**Server-side implementation:** Implement field-based scoring with default weights: title (3x), headings (2x), code blocks (1.5x), body (1x). Optionally expose a `fieldWeights` parameter.

**Plugin changes once implemented:** Update `references/tool-routing.md` parameter optimization section to include field weight guidance.

## Extended Metadata Filtering

**What it does:** Adds server-side filters for date range, language version, document type, and source author beyond the current `filter.repository` and `filter.isPublic` parameters.

**What it would enable:** The LLM could filter results server-side by version, date, and content type instead of performing client-side post-filtering. This reduces token consumption from irrelevant results.

**Current limitation:** `midnight-search-compact` supports `filter.repository` and `filter.isPublic`. `midnight-search-typescript` and `midnight-search-docs` have no repository-level filtering. No tool supports date, version, or content type filtering.

**Server-side implementation:** Extend the `filter` parameter schema to include `dateRange`, `languageVersion`, `docType`, and `author` fields. Apply filtering server-side before scoring.

**Plugin changes once implemented:** Update `references/tool-routing.md` and `examples/parameter-optimization.md` with new filter parameters.

## Diversity-Aware Retrieval

**What it does:** Limits the number of results returned from any single document, ensuring the result set covers different sources.

**What it would enable:** Broad queries would return results from multiple documents instead of multiple chunks from the same large document. Currently the LLM deduplicates client-side, wasting tokens on results that will be discarded.

**Current limitation:** The server may return multiple chunks from the same document. A search for "state management" might return 5 chunks from the same tutorial, missing relevant content from other sources.

**Server-side implementation:** Add a `maxPerDocument` integer parameter (default: 3). After scoring, enforce the per-document limit and backfill with next-highest results from other documents.

**Plugin changes once implemented:** Update `references/result-refinement.md` to note that server-side deduplication reduces the need for client-side deduplication techniques.

## Parent-Child Retrieval

**What it does:** Returns the surrounding section or parent document alongside the matching chunk when requested.

**What it would enable:** The LLM would get sufficient context from a single search call instead of needing follow-up calls to read surrounding content. A matched function would come with its parent class or module.

**Current limitation:** Results are individual chunks without surrounding context. The LLM often needs the full function, full section, or full file to understand a code pattern, requiring additional tool calls.

**Server-side implementation:** Add an `includeParent` boolean parameter (default: `false`). Return the parent section (heading-delimited) or containing file alongside the matching chunk in a `parentContent` response field.

**Plugin changes once implemented:** Update `references/tool-routing.md` parameter guidance and `references/result-refinement.md` result interpretation guidance.

## Passage Compression

**What it does:** Extracts and returns only the most relevant span from long chunks, reducing token consumption while preserving the answer.

**What it would enable:** Results would contain only the relevant portion plus minimal surrounding context, significantly reducing token consumption. Currently full chunks are returned even if only a small span is relevant.

**Current limitation:** Full chunks are returned regardless of how much of the chunk is relevant. A 200-line file chunk is returned when only 5 lines contain the answer.

**Server-side implementation:** Add a `compress` boolean parameter (default: `false`). Use extractive summarization or span detection to return the relevant portion plus N lines of surrounding context. Include position metadata (start/end offsets).

**Plugin changes once implemented:** Update `references/tool-routing.md` parameter guidance and result interpretation guidance across references.

## Graph-Assisted Retrieval

**What it does:** Uses links between documents, code symbols, repositories, issues, and examples to retrieve related content that does not share keywords with the query.

**What it would enable:** A search for a Compact function would also surface the related TypeScript SDK bindings, the documentation page that explains it, and the example contract that uses it — even if those do not share keywords.

**Current limitation:** Documents are retrieved independently based on text similarity. Related content that uses different terminology is not surfaced. The LLM compensates with cross-tool orchestration, but this requires knowing which tools to call and what terms to use.

**Server-side implementation:** Build a link graph across indexed content: doc-to-code, code-to-test, function-to-usage, package-to-docs. Add a `followLinks` boolean parameter (default: `false`). Return directly linked content (1 hop) in a `relatedContent` response field with relationship labels.

**Plugin changes once implemented:** Update `references/tool-routing.md` with graph-aware search patterns and `examples/cross-tool-orchestration.md` with graph-assisted examples.
