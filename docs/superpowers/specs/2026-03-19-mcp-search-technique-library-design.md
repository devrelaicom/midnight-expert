# MCP Search Technique Library — Design Specification

**Date:** 2026-03-19
**Plugin:** `midnight-mcp`
**Skill:** `mcp-search`
**Status:** Draft

## Problem

The `mcp-search` skill is the most-used entry point for LLMs querying Midnight content. It currently provides basic tool descriptions and a handful of query tips in a single SKILL.md file (~148 lines). There is no structured guidance on search techniques — query construction, result refinement, iterative strategies, or code-specific patterns. LLMs default to naive single-query searches with unoptimized terms and no post-processing of results.

## Goals

1. Provide a comprehensive library of search techniques that LLMs can apply when using the Midnight MCP search tools
2. Organize techniques for progressive disclosure — the LLM loads only what it needs for the current task
3. Add a `/midnight-mcp:search` slash command that gives users explicit control over search techniques
4. Document server-side enhancements that would improve search quality, and create GitHub issues for them

## Non-Goals

- Changing result trustworthiness assessment — that remains in `verify-correctness`
- Modifying the MCP server — server-side changes are tracked as GitHub issues on `devrelaicom/compact-playground`
- Adding hooks for search interception — the skill is passively consumed, not actively enforced

## Architecture

### Progressive Disclosure Model

Four levels, each loaded only when needed:

```
Level 1: Skill frontmatter
  Trigger keywords determine when the skill loads.

Level 2: SKILL.md body
  Intent-based routing table maps the LLM's task to reference files.
  Slim tool summary table. Trusted sources. Command documentation.

Level 3: Technique cluster references (references/*.md)
  Operational instructions for a cluster of related techniques.
  Each technique section names its example file.

Level 4: Per-technique example files (examples/*.md)
  Before/after transformation pairs and anti-patterns.
  Loaded selectively — only for techniques the LLM decides to apply.
```

### Consumer

The primary consumer is the LLM itself, operating autonomously. Reference files and examples are written as concise operational instructions, not explanatory documentation. The slash command provides a secondary user-facing interface.

### Boundary with Other Skills

- `mcp-search` owns **search quality**: query construction, technique selection, tool routing, result interpretation
- `verify-correctness` owns **result trustworthiness**: confidence levels, corroboration, escalation
- `mcp-overview` owns **tool discovery**: which tool exists for which purpose (high-level)

The search skill stops at "here are your results, ranked and deduplicated." The verification skill picks up from there.

## Technique Inventory

### Cluster 1: Query Expansion (`references/query-expansion.md`)

Techniques for turning a raw intent into better search input.

| Technique | Status | What the LLM Does |
|-----------|--------|-------------------|
| Query rewriting | Ready | Expand shorthand where genuinely written both ways (e.g., "ZKP" becomes "Zero Knowledge Proof (ZKP)"), fix typos, turn natural language into keyword-rich queries. Do not expand terms that are standard as-is (DUST, tDUST, DApp). |
| Multi-query generation | Ready | Produce 2-3 semantically different queries for broader recall — e.g., searching both "token transfer" and "shielded send" |
| Step-back queries | Ready | Generate a more abstract version of the question for broader context — "how does Counter overflow?" steps back to "Counter type operations" |
| HyDE (pseudo-answer generation) | Ready | Generate what the answer would look like as a Compact code snippet or doc paragraph, use key terms from that as the query |
| Decomposition | Ready | Split complex questions into sub-queries — "How do I build a shielded voting contract?" becomes searches for voting patterns, privacy patterns, and token gating separately |

**Example files:** `examples/query-rewriting.md`, `examples/multi-query.md`, `examples/step-back-queries.md`, `examples/hyde.md`, `examples/decomposition.md`

### Cluster 2: Context Gathering (`references/context-gathering.md`)

Techniques for enriching the query with information the LLM already has.

| Technique | Status | What the LLM Does |
|-----------|--------|-------------------|
| Conversation grounding | Ready | Pull entity names, versions, file paths, contract names from prior conversation turns into the query |
| Environmental grounding | Ready | Inspect the project environment — SDK versions from `package.json` (`@midnight-ntwrk/*` deps), language version from `pragma language_version` in `*.compact` files, network target from config files — and inject these as implicit constraints on the search |
| Entity extraction/normalization | Ready | Detect and normalize Midnight-specific entities — package names (`@midnight-ntwrk/...`), type names (`Counter`, `MerkleTree`), version strings, API names |
| Facet extraction | Ready | Identify implicit filters — if the user is asking about TypeScript, route to `midnight-search-typescript` not `midnight-search-compact`; if they mention a version, note it for result filtering |

**Example files:** `examples/conversation-grounding.md`, `examples/environmental-grounding.md`, `examples/entity-extraction.md`, `examples/facet-extraction.md`

### Cluster 3: Tool Routing (`references/tool-routing.md`)

Deciding which MCP tool(s) to call and with what parameters.

| Technique | Status | What the LLM Does |
|-----------|--------|-------------------|
| Intent classification | Ready | Classify the search intent: code example, conceptual explanation, API reference, troubleshooting, migration guidance — maps to which tool and parameters |
| Source routing | Ready | Select `midnight-search-compact` vs `midnight-search-typescript` vs `midnight-search-docs` vs `midnight-fetch-docs` based on intent and entity types |
| Trusted-source filtering | Ready | Apply `filter.repository` to restrict to `midnightntwrk`/`OpenZeppelin`/`LFDT-Minokawa` when reliability matters |
| Parameter optimization | Ready | Set `limit`, `category`, `includeExamples`, `includeTypes` based on the task — e.g., set `category: "api"` for API lookups, increase `limit` for broad exploration |
| Cross-tool orchestration | Ready | Decide when to call multiple tools (compact + docs for comprehensive coverage) vs single tool (quick answer) |

**Example files:** `examples/intent-classification.md`, `examples/source-routing.md`, `examples/trusted-source-filtering.md`, `examples/parameter-optimization.md`, `examples/cross-tool-orchestration.md`

### Cluster 4: Result Refinement (`references/result-refinement.md`)

Processing results after retrieval to improve quality.

| Technique | Status | What the LLM Does |
|-----------|--------|-------------------|
| Relevance reranking | Ready | Re-evaluate results using the original intent — a result may match keywords but not answer the question |
| Trust-aware reranking | Ready | Boost results from trusted repos, recent sources, exact version matches |
| Freshness reranking | Ready | Boost recent content for version-sensitive or time-sensitive queries |
| Deduplication | Ready | Collapse near-identical results from the same or forked repos |
| Coverage balancing | Ready | When the query has multiple facets, ensure results cover different parts rather than all hitting the same facet |
| Answerability scoring | Ready | Rank by "does this actually answer the question?" not just "does this match the terms?" |

**Example files:** `examples/relevance-reranking.md`, `examples/trust-aware-reranking.md`, `examples/freshness-reranking.md`, `examples/deduplication.md`, `examples/coverage-balancing.md`, `examples/answerability-scoring.md`

### Cluster 5: Iterative Search (`references/iterative-search.md`)

Techniques for refining when initial results are insufficient.

| Technique | Status | What the LLM Does |
|-----------|--------|-------------------|
| Retrieve-read-retrieve | Ready | Read initial results, identify gaps in coverage, do a targeted second search for what is missing |
| Query refinement | Ready | If results are too broad, add specificity; if too narrow, remove constraints |
| Confidence assessment | Ready | Judge whether the results are sufficient to answer the question or whether another search pass is needed |
| Contradiction detection | Ready | When results from different sources conflict, flag both and note the disagreement |

**Example files:** `examples/retrieve-read-retrieve.md`, `examples/query-refinement.md`, `examples/confidence-assessment.md`, `examples/contradiction-detection.md`

### Cluster 6: Code-Specific Search (`references/code-search.md`)

Techniques tailored to searching for code patterns.

| Technique | Status | What the LLM Does |
|-----------|--------|-------------------|
| Symbol-aware search | Ready | Detect when the query targets a specific type, function, module, or circuit name and use exact terms |
| Error-to-doc search | Ready | Rewrite compiler errors, stack traces, and runtime errors into effective search queries |
| Example mining | Ready | Bias queries toward finding runnable, complete examples rather than fragments or reference docs |
| Version-aware search | Ready | Incorporate the project's known Compact/SDK version into queries and result filtering |
| Diff-aware search | Ready | Use the current PR, changed files, or migration context to focus searches |

**Example files:** `examples/symbol-aware-search.md`, `examples/error-to-doc.md`, `examples/example-mining.md`, `examples/version-aware-search.md`, `examples/diff-aware-search.md`

### Cluster 7: Server-Enhanced Search (`references/server-enhanced.md`)

Techniques that require MCP server changes. Each becomes a GitHub issue on `devrelaicom/compact-playground`.

| Technique | Status | What It Would Enable |
|-----------|--------|---------------------|
| Hybrid search | SERVER | Combine keyword/BM25 with vector similarity for better recall |
| Field-aware retrieval | SERVER | Weight title, headings, code blocks differently in scoring |
| Metadata filtering | SERVER | Filter by date, author, doc type, language version beyond current `repository`/`isPublic` params |
| Diversity-aware retrieval | SERVER | Avoid returning multiple chunks from the same document |
| Parent-child retrieval | SERVER | Return surrounding context/parent section when a chunk matches |
| Passage compression | SERVER | Return only the most relevant spans from long chunks |
| Graph-assisted retrieval | SERVER | Use links between docs, symbols, repos, issues |

**No example files** — techniques are not actionable until server-side changes are implemented.

## SKILL.md Structure

The rewritten SKILL.md contains:

### 1. Tool Summary Table

Slim overview — tool name, corpus, one-line "use when." No parameter tables or response structure (already provided by MCP tool schemas).

| Tool | Corpus | Use When |
|------|--------|----------|
| `midnight-search-compact` | Compact code from Foundation, partners, ecosystem | Finding code patterns, examples, stdlib usage |
| `midnight-search-typescript` | TypeScript SDK code and types | Finding SDK API usage, type definitions, DApp integration |
| `midnight-search-docs` | Official documentation index | Finding conceptual explanations, guides, architecture |
| `midnight-fetch-docs` | Live docs.midnight.network pages | Fetching a specific known page, getting full content |

### 2. Intent-to-Reference Routing Table

Maps the LLM's current task to which reference files to load.

| Intent / Task | Reference Files |
|---------------|----------------|
| Quick lookup of a specific thing | `references/tool-routing.md` |
| Find code examples for a pattern | `references/query-expansion.md` + `references/tool-routing.md` + `references/code-search.md` |
| Find conceptual documentation | `references/query-expansion.md` + `references/tool-routing.md` |
| Debug an error using search | `references/code-search.md` + `references/tool-routing.md` |
| Comprehensive research on a topic | `references/query-expansion.md` + `references/context-gathering.md` + `references/tool-routing.md` + `references/result-refinement.md` |
| Search with project context | `references/context-gathering.md` + `references/tool-routing.md` |
| Migration / version upgrade search | `references/context-gathering.md` + `references/code-search.md` + `references/tool-routing.md` |
| Refine poor initial results | `references/iterative-search.md` + `references/result-refinement.md` |
| Understand server-side limitations | `references/server-enhanced.md` |

### 3. Example Loading Instructions

Short instruction block telling the LLM to load example files selectively:

> After reading a reference file, evaluate which techniques you will apply. Load the example file only for techniques you intend to use. Do not load example files for techniques you are skipping.

### 4. Trusted Sources

Retained from current SKILL.md — the organization/repository trust table.

### 5. Slash Command Documentation

Full documentation of `/midnight-mcp:search` — modes, presets, flags.

### 6. Cross-References

Updated cross-reference table linking to `mcp-overview`, `verify-correctness`, and other relevant skills.

## Slash Command: `/midnight-mcp:search`

### Invocation Modes

| Mode | Invocation | Behavior |
|------|-----------|----------|
| Interactive | `/midnight-mcp:search` | Guided Q&A session using AskUserQuestion — asks what the user is trying to find, what context they are working in, how comprehensive they need results to be, then constructs and executes the right search |
| Quick | `/midnight-mcp:search <query>` | Auto-routed with `--quick` defaults |
| Explicit | `/midnight-mcp:search <query> --thorough --compact` | User-specified flags |

### Source Flags

Control which MCP tools are called. If none specified, the command auto-routes based on query analysis.

| Flag | MCP Tool(s) |
|------|-------------|
| `--compact` | `midnight-search-compact` |
| `--typescript` | `midnight-search-typescript` |
| `--docs` | `midnight-search-docs` |
| `--all` | All three search tools |

Source flags are combinable: `--compact --docs` searches both.

### Modifier Flags

| Flag | Effect |
|------|--------|
| `--trusted-only` | Restricts code searches to `midnightntwrk`, `OpenZeppelin`, `LFDT-Minokawa` via `filter.repository`. No effect on docs searches. |

### Preset Flags

Shorthands for technique combinations. One preset at a time.

| Preset | Techniques Activated | Use Case |
|--------|---------------------|----------|
| `--quick` | Intent classification, source routing, single best-guess query | Fast lookup, minimal token cost |
| `--thorough` | Multi-query + step-back + cross-tool orchestration + result reranking + coverage balancing + deduplication | Comprehensive research |
| `--debug` | Error-to-doc rewriting + symbol-aware search + environmental grounding | Working from an error message or stack trace |
| `--examples` | Example mining + query rewriting + trusted-source filtering | Finding runnable code patterns |
| `--migration` | Version-aware search + diff-aware search + environmental grounding + freshness reranking | Upgrading between versions |

### Individual Technique Flags

Override or supplement presets. Map 1:1 to techniques in reference files.

| Flag | Technique | Cluster |
|------|-----------|---------|
| `--rewrite` | Query rewriting | Query Expansion |
| `--multi-query` | Multi-query generation | Query Expansion |
| `--step-back` | Step-back queries | Query Expansion |
| `--hyde` | HyDE pseudo-answer generation | Query Expansion |
| `--decompose` | Decomposition | Query Expansion |
| `--rerank` | Relevance reranking | Result Refinement |
| `--dedupe` | Deduplication | Result Refinement |
| `--iterative` | Retrieve-read-retrieve | Iterative Search |
| `--version-aware` | Version-aware search | Code-Specific |
| `--env` | Environmental grounding | Context Gathering |

### Flag Combination Rules

- Preset alone: activates its listed techniques
- Individual flags alone: activates only those techniques, auto-routes source
- Preset + individual flags: preset techniques plus additional individual techniques
- No flags, with query: equivalent to `--quick` with auto-routed source
- No flags, no query: interactive mode

## Example File Format

Every example file follows this template:

```markdown
# [Technique Name] Examples

## When to Apply
One-line reminder of when this technique is relevant.

## Examples

### [Concrete Midnight scenario label]

**Before:**
[The raw query, result set, or LLM reasoning before the technique]

**After:**
[The improved query, refined result set, or corrected reasoning]

**Why:** [One sentence explaining what changed and why it is better]

## Anti-Patterns

### [Anti-pattern label]

**Wrong:**
[What the LLM might naively do]

**Problem:** [Why this fails — specific to Midnight/MCP context]

**Instead:** [What to do]
```

Requirements:
- 3-5 before/after examples per file
- 2-3 anti-patterns per file (mandatory)
- Scenario labels are concrete Midnight tasks, not abstract descriptions
- All examples use real Midnight terminology, tool names, and parameter values

## File Inventory

### New Files (34 total)

**SKILL.md** (1 file — rewrite of existing):
- `skills/mcp-search/SKILL.md`

**Reference files** (7):
- `skills/mcp-search/references/query-expansion.md`
- `skills/mcp-search/references/context-gathering.md`
- `skills/mcp-search/references/tool-routing.md`
- `skills/mcp-search/references/result-refinement.md`
- `skills/mcp-search/references/iterative-search.md`
- `skills/mcp-search/references/code-search.md`
- `skills/mcp-search/references/server-enhanced.md`

**Example files** (25):
- `skills/mcp-search/examples/query-rewriting.md`
- `skills/mcp-search/examples/multi-query.md`
- `skills/mcp-search/examples/step-back-queries.md`
- `skills/mcp-search/examples/hyde.md`
- `skills/mcp-search/examples/decomposition.md`
- `skills/mcp-search/examples/conversation-grounding.md`
- `skills/mcp-search/examples/environmental-grounding.md`
- `skills/mcp-search/examples/entity-extraction.md`
- `skills/mcp-search/examples/facet-extraction.md`
- `skills/mcp-search/examples/intent-classification.md`
- `skills/mcp-search/examples/source-routing.md`
- `skills/mcp-search/examples/trusted-source-filtering.md`
- `skills/mcp-search/examples/parameter-optimization.md`
- `skills/mcp-search/examples/cross-tool-orchestration.md`
- `skills/mcp-search/examples/relevance-reranking.md`
- `skills/mcp-search/examples/trust-aware-reranking.md`
- `skills/mcp-search/examples/freshness-reranking.md`
- `skills/mcp-search/examples/deduplication.md`
- `skills/mcp-search/examples/coverage-balancing.md`
- `skills/mcp-search/examples/answerability-scoring.md`
- `skills/mcp-search/examples/retrieve-read-retrieve.md`
- `skills/mcp-search/examples/query-refinement.md`
- `skills/mcp-search/examples/confidence-assessment.md`
- `skills/mcp-search/examples/contradiction-detection.md`
- `skills/mcp-search/examples/symbol-aware-search.md`
- `skills/mcp-search/examples/error-to-doc.md`
- `skills/mcp-search/examples/example-mining.md`
- `skills/mcp-search/examples/version-aware-search.md`
- `skills/mcp-search/examples/diff-aware-search.md`

**Command file** (1):
- `commands/search.md`

### Modified Files

None. The existing SKILL.md is fully rewritten but at the same path.

### External Artifacts

7 GitHub issues on `devrelaicom/compact-playground` — one per technique in `references/server-enhanced.md`:

1. Hybrid search (BM25 + vector)
2. Field-aware retrieval (differential field weighting)
3. Extended metadata filtering (date, author, doc type, language version)
4. Diversity-aware retrieval (same-document deduplication)
5. Parent-child retrieval (surrounding context return)
6. Passage compression (relevant span extraction)
7. Graph-assisted retrieval (cross-entity linking)

Each issue includes: description of the technique, what it enables for the LLM, required MCP server changes, and what needs updating in the plugin once implemented.
