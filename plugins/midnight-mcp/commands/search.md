---
name: midnight-mcp:search
description: Search Midnight code, documentation, and SDK patterns with technique-aware query optimization, preset modes, and interactive guided search
allowed-tools: AskUserQuestion, Read, Glob, Grep, mcp__midnight__midnight-search-compact, mcp__midnight__midnight-search-typescript, mcp__midnight__midnight-search-docs, mcp__midnight__midnight-fetch-docs, mcp__midnight__midnight-list-examples
argument-hint: "[<query>] [--compact | --typescript | --docs | --all] [--quick | --thorough | --debug | --examples | --migration] [--trusted-only] [--rewrite] [--multi-query] [--step-back] [--hyde] [--decompose] [--rerank] [--dedupe] [--iterative] [--version-aware] [--env]"
---

Search Midnight content using the MCP search tools with technique-aware query optimization.

## Step 1: Parse Arguments and Flags

Parse `$ARGUMENTS` into:
- **Query**: everything that is not a flag
- **Source flags**: `--compact`, `--typescript`, `--docs`, `--all`
- **Preset flag**: `--quick`, `--thorough`, `--debug`, `--examples`, `--migration`
- **Modifier flags**: `--trusted-only`
- **Technique flags**: `--rewrite`, `--multi-query`, `--step-back`, `--hyde`, `--decompose`, `--rerank`, `--dedupe`, `--iterative`, `--version-aware`, `--env`

If no arguments at all → go to **Step 2: Interactive Mode**.
If query present but no preset → apply `--quick` as default preset.
If preset present → resolve preset to its technique set (see preset table below).
If technique flags present alongside a preset → merge (preset techniques + individual techniques).

### Preset Technique Mapping

| Preset | Techniques |
|--------|-----------|
| `--quick` | intent-classification, source-routing |
| `--thorough` | multi-query, step-back, cross-tool-orchestration, relevance-reranking, coverage-balancing, deduplication |
| `--debug` | error-to-doc, symbol-aware-search, environmental-grounding |
| `--examples` | example-mining, query-rewriting, trusted-source-filtering |
| `--migration` | version-aware-search, diff-aware-search, environmental-grounding, freshness-reranking |

## Step 2: Interactive Mode

If no arguments were provided, start a guided search session:

1. Ask: "What are you looking for? (code example, documentation, API reference, debugging help, or something else?)"
2. Based on the answer, ask follow-up questions:
   - For code: "Which language — Compact or TypeScript?" and "Can you describe the pattern or feature?"
   - For documentation: "What topic? And do you need a tutorial/guide or a reference page?"
   - For debugging: "What's the error message or unexpected behavior?"
   - For migration: "What version are you migrating from and to?"
3. Ask: "How thorough should the search be? Quick lookup, or comprehensive research?"
4. Construct the query, source flags, and preset from the answers.
5. Continue to **Step 3**.

Use `AskUserQuestion` for each question. One question per message.

## Step 3: Load Technique References

Based on the active techniques (from preset + individual flags), read the relevant reference and example files from the `mcp-search` skill directory.

Use the Read tool to load each needed reference. For each technique you will apply, also load its example file for guidance.

Reference file mapping:
- Query rewriting, multi-query, step-back, HyDE, decomposition → `skills/mcp-search/references/query-expansion.md`
- Environmental grounding, conversation grounding, entity extraction, facet extraction → `skills/mcp-search/references/context-gathering.md`
- Intent classification, source routing, trusted-source filtering, parameter optimization, cross-tool orchestration → `skills/mcp-search/references/tool-routing.md`
- Relevance reranking, trust-aware reranking, freshness reranking, deduplication, coverage balancing, answerability scoring → `skills/mcp-search/references/result-refinement.md`
- Retrieve-read-retrieve, query refinement, confidence assessment, contradiction detection → `skills/mcp-search/references/iterative-search.md`
- Symbol-aware search, error-to-doc, example mining, version-aware search, diff-aware search → `skills/mcp-search/references/code-search.md`

## Step 4: Pre-Search Processing

Apply the active pre-search techniques to the query:

1. **Environmental grounding** (if `--env` or preset includes it): read `package.json` and `*.compact` files to discover version context.
2. **Entity extraction**: detect and normalize Midnight-specific entities in the query.
3. **Facet extraction**: identify implicit filters for tool selection and parameter configuration.
4. **Query rewriting** (if active): transform the query into keyword-rich form.
5. **Multi-query generation** (if active): produce 2-3 variant queries.
6. **Step-back queries** (if active): generate abstract version.
7. **HyDE** (if active): generate pseudo-answer, extract key terms.
8. **Decomposition** (if active): split into sub-queries.

## Step 5: Tool Selection and Configuration

1. **Intent classification**: classify the search intent.
2. **Source routing**: select tool(s) based on intent, entities, facets, and source flags.
   - If source flags were provided, use those tools.
   - If no source flags, auto-route based on intent classification.
3. **Trusted-source filtering** (if `--trusted-only`):
   - For `midnight-search-compact`: set `filter.repository` to restrict to trusted orgs.
   - For `midnight-search-typescript`: note for client-side trust-aware reranking.
4. **Parameter optimization**: set `limit`, `category`, `includeExamples`, `includeTypes` per tool.

## Step 6: Execute Search

Call the selected MCP search tool(s) with the constructed queries and parameters.

If multi-query is active, call the tool once per query variant. Combine all result sets.

If cross-tool orchestration is active, call multiple tools as determined in Step 5.

## Step 7: Post-Search Processing

Apply the active post-search techniques to the result set:

1. **Relevance reranking** (if active or always as baseline): re-evaluate results against the original intent.
2. **Trust-aware reranking** (if `--trusted-only` or active): boost trusted sources.
3. **Freshness reranking** (if active): boost recent content.
4. **Deduplication** (if active): collapse near-identical results.
5. **Coverage balancing** (if active): check facet coverage, note gaps.
6. **Answerability scoring**: rank by how directly results answer the question.

## Step 8: Iterative Refinement (if active)

If `--iterative` is active or if confidence is low:

1. Assess result confidence.
2. If gaps exist, formulate targeted follow-up queries.
3. Execute follow-up search (max 1 additional round).
4. Merge new results with existing results.
5. Re-apply post-search processing.

## Step 9: Present Results

Present the final result set to the user:

1. Group results by relevance/source if multiple tools were used.
2. For each result, show: source repository, relevance assessment, and the content.
3. Note any gaps in coverage.
4. Note any contradictions detected between results.
5. If confidence is low, note the uncertainty and suggest verification approaches.

## Step 10: No-Results Fallback

If no relevant results were found:

1. Suggest alternative query formulations.
2. Suggest trying a different tool or preset.
3. Suggest checking `midnight-list-examples` for curated examples.
4. Note that the information may not be in the search index — suggest checking source code directly.
