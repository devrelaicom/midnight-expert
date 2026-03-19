# MCP Search Technique Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the `mcp-search` skill with a comprehensive search technique library (7 reference files, 29 example files), a `/midnight-mcp:search` slash command, and GitHub issues for server-side enhancements.

**Architecture:** Four-level progressive disclosure — SKILL.md routes intents to cluster references, cluster references name per-technique example files, LLM loads selectively. Slash command provides explicit user control over the same techniques. All content is LLM-consumed operational instructions.

**Tech Stack:** Markdown content files within the Claude Code plugin system. GitHub CLI for issue creation. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-19-mcp-search-technique-library-design.md`

---

## Dependency Graph

```
Task 1 (SKILL.md) ─────────────────────────────────────────┐
  │                                                          │
  ├── Task 2 (Query Expansion cluster)        ──┐            │
  ├── Task 3 (Context Gathering cluster)      ──┤            │
  ├── Task 4 (Tool Routing cluster)           ──┤            │
  ├── Task 5 (Result Refinement cluster)      ──┤── All ──── Task 11 (Integration)
  ├── Task 6 (Iterative Search cluster)       ──┤
  ├── Task 7 (Code-Specific Search cluster)   ──┘
  │
  ├── Task 8 (Server-Enhanced reference)      ──── Task 9 (GitHub Issues)
  │
  └── Task 10 (Slash Command)                 ──── Task 11 (Integration)
```

Tasks 2-7 are independent of each other and CAN run in parallel.
Task 8 and Task 10 are independent of Tasks 2-7 and CAN run in parallel with them.
Task 9 depends on Task 8.
Task 11 depends on all other tasks.

## Conventions

All paths in this plan are relative to `plugins/midnight-mcp/` unless stated otherwise.

**Reference file conventions** (from existing codebase patterns):
- No YAML frontmatter — references are plain markdown
- Start with `# Title` heading
- Concise, operational tone — instructions the LLM executes, not explanations
- Each technique section ends with `**Examples:** \`examples/<name>.md\``

**Example file conventions** (from spec):
- No YAML frontmatter
- Template: `# [Name] Examples` → `## When to Apply` → `## Examples` (3-5 before/after pairs) → `## Anti-Patterns` (2-3 mandatory)
- Scenario labels are concrete Midnight tasks
- All content uses real Midnight terminology, tool names, parameter values

**Command file conventions** (from existing commands like `devnet.md`, `doctor.md`):
- YAML frontmatter with `description`, `allowed-tools`, `argument-hint`
- Step-by-step instructions the LLM follows
- Delegated to MCP tools where applicable

---

### Task 1: Rewrite SKILL.md

**Files:**
- Modify: `skills/mcp-search/SKILL.md`

This is the central routing file. Everything else depends on it being correct.

- [ ] **Step 1: Read the current SKILL.md**

Read `skills/mcp-search/SKILL.md` to confirm current content before overwriting.

- [ ] **Step 2: Write the new SKILL.md**

Replace the entire file with:

```markdown
---
name: mcp-search
description: This skill should be used when the user asks about midnight search, searching Compact code, searching TypeScript SDK code, searching Midnight documentation, fetching docs, MCP search tools, semantic search over Midnight repos, midnight-search-compact, midnight-search-typescript, midnight-search-docs, midnight-fetch-docs, optimizing search queries for the Midnight MCP server, search techniques, query rewriting, multi-query search, search reranking, or improving search result quality.
---

# Midnight MCP Search

Search techniques and tool guidance for the four Midnight MCP search tools. This skill provides a technique library organized as cluster references with per-technique example files. Load only what you need for the current task.

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
| Quick lookup of a specific thing | `references/tool-routing.md` |
| Find code examples for a pattern | `references/query-expansion.md` + `references/tool-routing.md` + `references/code-search.md` |
| Find conceptual documentation | `references/query-expansion.md` + `references/tool-routing.md` |
| Debug an error using search | `references/code-search.md` + `references/tool-routing.md` |
| Comprehensive research on a topic | `references/query-expansion.md` + `references/context-gathering.md` + `references/tool-routing.md` + `references/result-refinement.md` |
| Search with project context | `references/context-gathering.md` + `references/tool-routing.md` |
| Migration / version upgrade search | `references/context-gathering.md` + `references/code-search.md` + `references/tool-routing.md` |
| Refine poor initial results | `references/iterative-search.md` + `references/result-refinement.md` |
| Understand server-side limitations | `references/server-enhanced.md` |

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

Users can invoke `/midnight-mcp:search` to run searches with explicit technique control.

### Modes

| Mode | Invocation | Behavior |
|------|-----------|----------|
| Interactive | `/midnight-mcp:search` | Guided Q&A — asks what the user needs, constructs and executes the search |
| Quick | `/midnight-mcp:search <query>` | Auto-routed with `--quick` defaults |
| Explicit | `/midnight-mcp:search <query> --thorough --compact` | User-specified flags |

### Source Flags

| Flag | MCP Tool(s) |
|------|-------------|
| `--compact` | `midnight-search-compact` |
| `--typescript` | `midnight-search-typescript` |
| `--docs` | `midnight-search-docs` |
| `--all` | All three search tools |

Source flags are combinable. If none specified, auto-routes based on query.

### Modifier Flags

| Flag | Effect |
|------|--------|
| `--trusted-only` | Restricts Compact searches to trusted repos via `filter.repository`. For TypeScript searches (no server-side filter), applies client-side trust-aware reranking. No effect on docs. |

### Presets

| Preset | Activates | Use Case |
|--------|-----------|----------|
| `--quick` | Intent classification, source routing, single query | Fast lookup |
| `--thorough` | Multi-query, step-back, cross-tool orchestration, reranking, coverage balancing, dedup | Comprehensive research |
| `--debug` | Error-to-doc rewriting, symbol-aware search, environmental grounding | Debugging from an error |
| `--examples` | Example mining, query rewriting, trusted-source filtering | Finding runnable code |
| `--migration` | Version-aware, diff-aware, environmental grounding, freshness reranking | Upgrading versions |

### Individual Technique Flags

| Flag | Technique |
|------|-----------|
| `--rewrite` | Query rewriting |
| `--multi-query` | Multi-query generation |
| `--step-back` | Step-back queries |
| `--hyde` | HyDE pseudo-answer generation |
| `--decompose` | Decomposition |
| `--rerank` | Relevance reranking |
| `--dedupe` | Deduplication |
| `--iterative` | Retrieve-read-retrieve |
| `--version-aware` | Version-aware search |
| `--env` | Environmental grounding |

Preset + individual flags: preset techniques plus additional individual techniques. No flags with query: `--quick`. No flags, no query: interactive mode.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `mcp-overview` |
| Verification methodology using search results | `compact-core:verify-correctness` |
| Compact standard library reference | `compact-core:compact-standard-library` |
| Compact compilation for verifying search results | `compact-core:compact-compilation` |
```

- [ ] **Step 3: Verify the SKILL.md**

Read back the file and confirm:
- Frontmatter has `name` and `description` fields
- Routing table has 9 rows mapping intents to reference files
- All 7 reference file paths are mentioned
- Trusted sources table is present
- Command documentation covers all modes, flags, presets
- Cross-references section is present

- [ ] **Step 4: Create directories**

```bash
mkdir -p plugins/midnight-mcp/skills/mcp-search/references
mkdir -p plugins/midnight-mcp/skills/mcp-search/examples
mkdir -p plugins/midnight-mcp/commands
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/SKILL.md
git commit -m "feat(mcp-search): rewrite SKILL.md with intent routing table and technique library structure"
```

---

### Task 2: Query Expansion Cluster (reference + 5 examples)

**Files:**
- Create: `skills/mcp-search/references/query-expansion.md`
- Create: `skills/mcp-search/examples/query-rewriting.md`
- Create: `skills/mcp-search/examples/multi-query.md`
- Create: `skills/mcp-search/examples/step-back-queries.md`
- Create: `skills/mcp-search/examples/hyde.md`
- Create: `skills/mcp-search/examples/decomposition.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/query-expansion.md`**

This file covers 5 techniques for turning raw intent into better search input. Write concise operational instructions for each:

1. **Query Rewriting** — When to apply: always, as a first pass. Instructions: rewrite natural language into keyword-rich queries using Midnight-specific terms. Expand shorthand only where genuinely written both ways (e.g., "ZKP" → "Zero Knowledge Proof (ZKP)"). Do NOT expand DUST, tDUST, DApp, or other terms that are standard as-is. Fix obvious typos. Strip filler words ("how do I", "what is the best way to"). End section with `**Examples:** \`examples/query-rewriting.md\``

2. **Multi-query Generation** — When to apply: when a single query is unlikely to capture all relevant results (ambiguous terms, multiple synonyms, broad topics). Instructions: generate 2-3 semantically different queries from the same intent. Each query should target different terminology that might appear in the indexed content. Run all queries against the same tool. Combine and deduplicate results. End section with `**Examples:** \`examples/multi-query.md\``

3. **Step-back Queries** — When to apply: when the specific question is too narrow to return results, or when background context would improve understanding of specific results. Instructions: generate a more abstract version of the question. Search for the abstract version first or alongside the specific query. The step-back result provides context; the specific query provides the direct answer. End section with `**Examples:** \`examples/step-back-queries.md\``

4. **HyDE (Pseudo-answer Generation)** — When to apply: when the query is conceptual and hard to reduce to keywords, or when you know roughly what the answer should look like but need to find real examples. Instructions: generate a short hypothetical answer — a Compact code snippet or documentation paragraph that would answer the question if it existed. Extract the distinctive terms and structure from that hypothetical. Use those terms as the search query. Do NOT present the hypothetical answer to the user — it is a search aid only. End section with `**Examples:** \`examples/hyde.md\``

5. **Decomposition** — When to apply: when the question involves multiple independent concerns that should be searched separately. Instructions: identify the distinct sub-questions. Search each independently. Combine results. This is better than a single broad query because each sub-question gets targeted results rather than diluted matches. End section with `**Examples:** \`examples/decomposition.md\``

- [ ] **Step 2: Write `examples/query-rewriting.md`**

3-5 before/after pairs showing raw user queries transformed into effective MCP search queries. Use concrete Midnight scenarios:

Example scenarios to cover:
- Natural language → keyword-rich: "how do I make a token that only the owner can mint" → `mint access control owner witness shielded token`
- Shorthand expansion: "ZKP costs for merkle proofs" → `Zero Knowledge Proof (ZKP) circuit cost MerkleTree`
- Filler stripping: "what is the best way to handle state in Compact" → `Compact ledger state management Counter Map Set`
- Typo/terminology fix: "midnite compact smart contract deploy" → `Midnight Compact contract deployment`

Anti-patterns (2-3):
- Expanding terms that should stay as-is (DUST, DApp, tDUST)
- Passing raw natural language questions to the MCP tools
- Over-expanding into generic programming terms that dilute Midnight-specificity

- [ ] **Step 3: Write `examples/multi-query.md`**

3-5 before/after pairs showing single queries expanded into multi-query sets.

Example scenarios:
- Synonym coverage: "token transfer" → queries for `token transfer`, `shielded send`, `DUST transfer circuit`
- Concept vs implementation: "access control" → queries for `access control owner witness`, `OpenZeppelin Ownable Compact`, `authorization circuit`
- Cross-domain: "how does the proof server work" → queries for `proof server architecture` (docs), `ZK proof generation` (compact), `proof server API endpoint` (typescript)

Anti-patterns:
- Generating queries that are all minor rephrases of each other
- Generating more than 3 queries (diminishing returns, wastes calls)
- Using multi-query when a single specific term would suffice

- [ ] **Step 4: Write `examples/step-back-queries.md`**

3-5 before/after pairs showing specific questions with their step-back abstractions.

Example scenarios:
- "does Counter support decrement" → step-back: `Counter type operations increment value`
- "how to handle MerkleTree overflow at depth 32" → step-back: `MerkleTree depth capacity limits`
- "what happens when two transactions modify the same Counter" → step-back: `Compact concurrency ledger contention`

Anti-patterns:
- Stepping back so far the query becomes generic ("Compact programming")
- Using step-back when the original query is already well-formed
- Returning only the step-back results without also trying the specific query

- [ ] **Step 5: Write `examples/hyde.md`**

3-5 before/after pairs showing hypothetical answer generation used as search input.

Example scenarios:
- "how to gate access to a circuit" → hypothetical Compact code snippet with `witness` and access control → extract terms: `witness authorization circuit access guard`
- "what does a basic voting contract look like" → hypothetical contract structure with `ledger`, `vote`, `Counter` → extract terms: `voting contract ledger Counter tally circuit`
- "how to store private data on Midnight" → hypothetical pattern using `local` state and `witness` → extract terms: `local state witness private data off-chain`

Anti-patterns:
- Presenting the hypothetical answer to the user as if it were real
- Using HyDE for simple keyword lookups where direct search works fine
- Generating a hypothetical that hallucinates API names and then searching for those hallucinated names

- [ ] **Step 6: Write `examples/decomposition.md`**

3-5 before/after pairs showing complex questions split into sub-queries.

Example scenarios:
- "How do I build a shielded voting contract with token gating?" → sub-queries: `voting contract Compact tally circuit`, `shielded token privacy ledger`, `token gating access control holder`
- "Migrate my DApp from testnet to mainnet with the new SDK version" → sub-queries: `testnet mainnet network configuration`, `SDK version migration breaking changes`, `DApp deployment provider endpoint`
- "Build a contract with MerkleTree-based membership proofs and Counter-based rate limiting" → sub-queries: `MerkleTree membership proof inclusion`, `Counter rate limiting increment circuit`

Anti-patterns:
- Decomposing simple questions that should be a single search
- Creating overlapping sub-queries that return duplicate results
- Decomposing into more than 3-4 sub-queries (each costs a tool call)

- [ ] **Step 7: Verify all files**

Read back each file. Confirm:
- Reference file has 5 technique sections, each ending with an `**Examples:**` pointer
- Each example file follows the template: `# [Name] Examples` → `## When to Apply` → `## Examples` → `## Anti-Patterns`
- Each example file has 3-5 before/after pairs and 2-3 anti-patterns
- All content uses real Midnight terminology

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/query-expansion.md
git add plugins/midnight-mcp/skills/mcp-search/examples/query-rewriting.md
git add plugins/midnight-mcp/skills/mcp-search/examples/multi-query.md
git add plugins/midnight-mcp/skills/mcp-search/examples/step-back-queries.md
git add plugins/midnight-mcp/skills/mcp-search/examples/hyde.md
git add plugins/midnight-mcp/skills/mcp-search/examples/decomposition.md
git commit -m "feat(mcp-search): add query expansion cluster reference and examples"
```

---

### Task 3: Context Gathering Cluster (reference + 4 examples)

**Files:**
- Create: `skills/mcp-search/references/context-gathering.md`
- Create: `skills/mcp-search/examples/conversation-grounding.md`
- Create: `skills/mcp-search/examples/environmental-grounding.md`
- Create: `skills/mcp-search/examples/entity-extraction.md`
- Create: `skills/mcp-search/examples/facet-extraction.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/context-gathering.md`**

This file covers 4 techniques for enriching queries with existing context.

1. **Conversation Grounding** — When to apply: when prior conversation turns contain entity names, versions, file paths, contract names, or other specifics that the current query lacks. Instructions: scan recent conversation turns for Midnight-specific entities (contract names, type names, version numbers, file paths, package names). Inject the most relevant entities into the search query as additional terms. Do not add entities that would narrow the search inappropriately. End section with `**Examples:** \`examples/conversation-grounding.md\``

2. **Environmental Grounding** — When to apply: when the user is working within a project that has Midnight dependencies or Compact source files, and the search would benefit from knowing the project's version context. Instructions: check these project files:
   - `package.json` — look for `@midnight-ntwrk/*` dependencies and their version ranges
   - `*.compact` files — look for `pragma language_version` declarations
   - Configuration files — look for network targets (devnet, testnet, mainnet), endpoint URLs
   - `node_modules/@midnight-ntwrk/*/package.json` — look for actual installed versions if `package.json` has ranges

   Inject the discovered version and network context as implicit constraints. For example, if the project uses `@midnight-ntwrk/midnight-js-contracts` version `2.x`, bias search results toward SDK v2 patterns. End section with `**Examples:** \`examples/environmental-grounding.md\``

3. **Entity Extraction / Normalization** — When to apply: always, as a pre-processing step before query construction. Instructions: scan the user's query for Midnight-specific entities:
   - Package names: `@midnight-ntwrk/compact`, `@midnight-ntwrk/midnight-js-contracts`, etc.
   - Type names: `Counter`, `MerkleTree`, `Map`, `Set`, `Bytes`, `Uint`, `Field`
   - Construct names: `circuit`, `witness`, `ledger`, `export`, `import`, `disclose`
   - Version strings: `0.28.0`, `v2`, `language_version 0.2.0`
   - Tool/component names: proof server, indexer, node, Compact CLI, Lace wallet

   Normalize detected entities: fix casing (`merkletree` → `MerkleTree`), resolve abbreviations only where written both ways, keep standard forms as-is. End section with `**Examples:** \`examples/entity-extraction.md\``

4. **Facet Extraction** — When to apply: when the query implies constraints that should be used for tool selection or parameter filtering rather than as search terms. Instructions: extract implicit facets:
   - Language/domain: Compact code vs TypeScript SDK vs documentation
   - Version: specific version mentioned or implied
   - Source trust level: user asks for "official" or "audited" → trusted sources
   - Content type: tutorial vs reference vs example code
   - Recency: "latest", "current", "new" → freshness matters

   Use extracted facets to inform tool selection (Tool Routing cluster) and result filtering (Result Refinement cluster). Do not include facets as literal search terms. End section with `**Examples:** \`examples/facet-extraction.md\``

- [ ] **Step 2: Write `examples/conversation-grounding.md`**

Example scenarios:
- User previously mentioned they're working on a contract called `TokenVault` → inject `TokenVault` into search
- User discussed `MerkleTree` depth issues in earlier turns → include `MerkleTree depth` in subsequent searches
- User is debugging a `@midnight-ntwrk/midnight-js-contracts` import error → include the package name and version
- Conversation established the user is targeting testnet → filter for testnet-relevant results

Anti-patterns:
- Injecting entities from stale conversation context that the user has moved past
- Including so many grounded terms that the query becomes overly narrow
- Grounding from the conversation when the user is explicitly asking about something new/different

- [ ] **Step 3: Write `examples/environmental-grounding.md`**

Example scenarios:
- `package.json` shows `"@midnight-ntwrk/compact": "^0.28.0"` → constrain search to Compact language version 0.28.x patterns
- `*.compact` file has `pragma language_version 0.2.0` → search for language version 0.2.0 syntax
- Config has devnet endpoint `http://localhost:9944` → user is in local development context
- `package.json` has both `@midnight-ntwrk/midnight-js-contracts` and `@openzeppelin/compact-contracts` → include OpenZeppelin patterns in results

Anti-patterns:
- Reading `package.json` on every search (expensive — cache the result for the session)
- Treating version ranges as exact versions (`^0.28.0` means 0.28.x, not exactly 0.28.0)
- Ignoring environmental context when the user explicitly asks about a different version

- [ ] **Step 4: Write `examples/entity-extraction.md`**

Example scenarios:
- "how do I use the merkletree in compact" → extract and normalize: `MerkleTree`, `Compact`
- "check my @midnight-ntwrk/midnight-js-contracts types" → extract: package name `@midnight-ntwrk/midnight-js-contracts`, concept `types`
- "counter overflow in my token contract" → extract and normalize: `Counter`, `token`, `contract`, concept: `overflow`
- "deploy to testnet with lace" → extract: `testnet`, `Lace` (wallet), `deploy`

Anti-patterns:
- Normalizing terms that are already correct (changing `DApp` to `decentralized application`)
- Extracting generic programming terms as Midnight entities ("function", "variable")
- Missing Midnight-specific entities because they look like common words ("witness", "circuit", "ledger")

- [ ] **Step 5: Write `examples/facet-extraction.md`**

Example scenarios:
- "show me the TypeScript types for contract deployment" → facets: language=TypeScript, content_type=type_definitions → route to `midnight-search-typescript` with `includeTypes: true`
- "what does the official docs say about token privacy" → facets: source=official_docs → route to `midnight-search-docs`, possibly `midnight-fetch-docs`
- "find me a recent example of Counter usage" → facets: content_type=example, recency=recent → route to `midnight-search-compact` with trusted sources, apply freshness reranking
- "how did the ledger API change in the latest version" → facets: recency=latest, content_type=changelog → route to `midnight-search-docs` with `category: "api"`

Anti-patterns:
- Including facet terms as literal search keywords ("official", "recent", "TypeScript" as search terms instead of as routing decisions)
- Ignoring facets and using the same tool/parameters for every query
- Extracting facets that contradict each other without resolving the conflict

- [ ] **Step 6: Verify all files**

Read back each file. Confirm:
- Reference file has 4 technique sections, each ending with an `**Examples:**` pointer
- Environmental grounding includes all file types to check (`package.json`, `*.compact` pragma, config files)
- Each example file follows the template with 3-5 before/after pairs and 2-3 anti-patterns

- [ ] **Step 7: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/context-gathering.md
git add plugins/midnight-mcp/skills/mcp-search/examples/conversation-grounding.md
git add plugins/midnight-mcp/skills/mcp-search/examples/environmental-grounding.md
git add plugins/midnight-mcp/skills/mcp-search/examples/entity-extraction.md
git add plugins/midnight-mcp/skills/mcp-search/examples/facet-extraction.md
git commit -m "feat(mcp-search): add context gathering cluster reference and examples"
```

---

### Task 4: Tool Routing Cluster (reference + 5 examples)

**Files:**
- Create: `skills/mcp-search/references/tool-routing.md`
- Create: `skills/mcp-search/examples/intent-classification.md`
- Create: `skills/mcp-search/examples/source-routing.md`
- Create: `skills/mcp-search/examples/trusted-source-filtering.md`
- Create: `skills/mcp-search/examples/parameter-optimization.md`
- Create: `skills/mcp-search/examples/cross-tool-orchestration.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/tool-routing.md`**

This file covers 5 techniques for selecting and configuring MCP tools.

1. **Intent Classification** — When to apply: always, before selecting a tool. Instructions: classify the search intent into one of these categories:
   - `code_example` — user wants to see how something is implemented → `midnight-search-compact` or `midnight-search-typescript`
   - `conceptual` — user wants to understand how something works → `midnight-search-docs`
   - `api_reference` — user wants exact API signatures or type definitions → `midnight-search-typescript` with `includeTypes: true`
   - `troubleshooting` — user has an error or problem → `midnight-search-docs` with `category: "guides"`, possibly `midnight-search-compact` for error patterns
   - `migration` — user is upgrading versions → `midnight-search-docs`, `midnight-fetch-docs` for release notes
   - `specific_page` — user knows which doc page they need → `midnight-fetch-docs` directly

   End section with `**Examples:** \`examples/intent-classification.md\``

2. **Source Routing** — When to apply: after intent classification, to select the specific tool. Instructions: map the classified intent and detected entities to the correct MCP tool:
   - Compact language questions → `midnight-search-compact`
   - TypeScript/SDK questions → `midnight-search-typescript`
   - Conceptual/architectural questions → `midnight-search-docs`
   - Known doc page → `midnight-fetch-docs` with the page path
   - Mixed → use cross-tool orchestration (technique 5)

   Decision factors: entity types in the query (Compact types → compact search, npm packages → TypeScript search), language context from prior turns, facets extracted from the query.

   End section with `**Examples:** \`examples/source-routing.md\``

3. **Trusted-Source Filtering** — When to apply: when result reliability matters more than breadth — production code, security-sensitive patterns, official examples. Instructions:
   - For `midnight-search-compact`: set `filter.repository` to restrict to trusted organizations. Supported prefixes: `midnightntwrk`, `OpenZeppelin`, `LFDT-Minokawa`
   - For `midnight-search-typescript`: no server-side filter available. Apply trust-aware reranking from the Result Refinement cluster after retrieval
   - For `midnight-search-docs`: all results are from official docs — no additional filtering needed
   - For `midnight-fetch-docs`: fetches directly from docs.midnight.network — inherently trusted

   End section with `**Examples:** \`examples/trusted-source-filtering.md\``

4. **Parameter Optimization** — When to apply: after tool selection, before making the call. Instructions: set tool-specific parameters to improve result quality:
   - `midnight-search-compact`: `limit` (default 10, increase to 15-20 for broad searches), `filter.repository` (for trusted sources), `filter.isPublic` (for public-only code)
   - `midnight-search-typescript`: `limit`, `includeExamples` (true for usage patterns, false for type-only lookups), `includeTypes` (true for type definitions, false for implementation code)
   - `midnight-search-docs`: `limit`, `category` — set `"guides"` for tutorials/howtos, `"api"` for API references, `"concepts"` for architecture/theory, omit or use `"all"` for broad search
   - `midnight-fetch-docs`: `path` (required), `extractSection` (use when you only need one heading from a large page)

   End section with `**Examples:** \`examples/parameter-optimization.md\``

5. **Cross-Tool Orchestration** — When to apply: when a single tool cannot provide complete coverage — typically for comprehensive research, or when code examples need conceptual context. Instructions:
   - **Compact + Docs** (most common): search compact for implementation patterns, search docs for conceptual explanation. Useful for answering "how and why" questions.
   - **TypeScript + Compact**: search TypeScript for SDK integration, search compact for the contract side. Useful for end-to-end DApp questions.
   - **Search + Fetch**: use search to discover the relevant page, then fetch for full content. Useful when search snippets are insufficient.

   Limit to 2-3 tool calls per question. Additional calls rarely add value beyond the first 2-3.

   End section with `**Examples:** \`examples/cross-tool-orchestration.md\``

- [ ] **Step 2: Write `examples/intent-classification.md`**

Example scenarios:
- "how do I declare a ledger with a Counter" → `code_example` → `midnight-search-compact`
- "what is the transaction model in Midnight" → `conceptual` → `midnight-search-docs`
- "what's the type signature of ContractAddress" → `api_reference` → `midnight-search-typescript` with `includeTypes: true`
- "I'm getting ERR_UNSUPPORTED_DIR_IMPORT" → `troubleshooting` → `midnight-search-docs` + error-to-doc techniques
- "show me the getting started page" → `specific_page` → `midnight-fetch-docs` path `/getting-started/installation`

Anti-patterns:
- Defaulting to `midnight-search-docs` for code questions
- Using `midnight-search-compact` for TypeScript/SDK questions
- Classifying every question as `code_example` because the user is a developer

- [ ] **Step 3: Write `examples/source-routing.md`**

Example scenarios:
- Query mentions `Counter`, `MerkleTree`, `circuit`, `witness` → Compact entities → `midnight-search-compact`
- Query mentions `@midnight-ntwrk/midnight-js-contracts`, `Provider`, `ContractAddress` → TypeScript entities → `midnight-search-typescript`
- Query mentions "architecture", "how does X work", "overview of" → conceptual → `midnight-search-docs`
- Query asks for content of `/compact/reference` → known path → `midnight-fetch-docs`

Anti-patterns:
- Routing based on keywords alone without checking entity types
- Always routing to the same tool regardless of intent
- Routing to `midnight-fetch-docs` without knowing the specific page path (use search first)

- [ ] **Step 4: Write `examples/trusted-source-filtering.md`**

Example scenarios:
- User needs production-ready token transfer pattern → `midnight-search-compact` with `filter.repository` limiting to `midnightntwrk` and `OpenZeppelin`
- User wants to see how anyone has implemented voting → no filter (broad search includes community code)
- TypeScript SDK usage from official sources → `midnight-search-typescript` (no server filter) → apply trust-aware reranking to boost `midnightntwrk` results
- User explicitly asks for "audited" code → filter to `OpenZeppelin` repos

Anti-patterns:
- Passing `filter.repository` to `midnight-search-typescript` (parameter does not exist on this tool)
- Always filtering to trusted-only (misses useful community examples for exploration)
- Treating all `midnightntwrk` results as equally current (some repos have outdated examples)

- [ ] **Step 5: Write `examples/parameter-optimization.md`**

Example scenarios:
- Looking up a single type definition → `midnight-search-typescript` with `includeTypes: true`, `includeExamples: false`, `limit: 5`
- Broad exploration of token patterns → `midnight-search-compact` with `limit: 20` (higher than default for breadth)
- Finding a tutorial on deployment → `midnight-search-docs` with `category: "guides"`, `limit: 10`
- Getting the standard library reference → `midnight-fetch-docs` with `path: "/compact/standard-library"` and `extractSection: "Functions"` to get just the function list

Anti-patterns:
- Using default parameters for every search regardless of task
- Setting `limit: 50` (excessive — most useful results are in the first 10-15)
- Setting `category` on `midnight-search-compact` (this parameter only exists on `midnight-search-docs`)
- Setting `filter` on `midnight-search-typescript` (this parameter only exists on `midnight-search-compact`)

- [ ] **Step 6: Write `examples/cross-tool-orchestration.md`**

Example scenarios:
- "How do I implement token transfers in Compact?" → 1) `midnight-search-compact` for code patterns 2) `midnight-search-docs` for conceptual guidance on token model
- "Show me how to deploy a contract from TypeScript" → 1) `midnight-search-typescript` for deployment API 2) `midnight-search-compact` for the contract being deployed
- "What changed in Compact language version 0.2.0?" → 1) `midnight-search-docs` to find the relevant page 2) `midnight-fetch-docs` to get the full page content

Anti-patterns:
- Calling all 3 search tools on every question (wasteful — most questions need 1-2 tools)
- Using search + fetch when search alone provides sufficient snippets
- Calling the same tool twice with slightly different queries instead of using multi-query technique

- [ ] **Step 7: Verify all files**

Read back each file. Confirm:
- Reference file has 5 technique sections with correct MCP tool names and parameters
- Trusted-source filtering correctly notes that `midnight-search-typescript` has no `filter.repository`
- Parameter optimization attributes each parameter to its correct tool
- Each example file follows the template

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md
git add plugins/midnight-mcp/skills/mcp-search/examples/intent-classification.md
git add plugins/midnight-mcp/skills/mcp-search/examples/source-routing.md
git add plugins/midnight-mcp/skills/mcp-search/examples/trusted-source-filtering.md
git add plugins/midnight-mcp/skills/mcp-search/examples/parameter-optimization.md
git add plugins/midnight-mcp/skills/mcp-search/examples/cross-tool-orchestration.md
git commit -m "feat(mcp-search): add tool routing cluster reference and examples"
```

---

### Task 5: Result Refinement Cluster (reference + 6 examples)

**Files:**
- Create: `skills/mcp-search/references/result-refinement.md`
- Create: `skills/mcp-search/examples/relevance-reranking.md`
- Create: `skills/mcp-search/examples/trust-aware-reranking.md`
- Create: `skills/mcp-search/examples/freshness-reranking.md`
- Create: `skills/mcp-search/examples/deduplication.md`
- Create: `skills/mcp-search/examples/coverage-balancing.md`
- Create: `skills/mcp-search/examples/answerability-scoring.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/result-refinement.md`**

This file covers 6 techniques for processing results after retrieval. All techniques operate on the result set returned by MCP tools — they are client-side reasoning the LLM performs on the response.

1. **Relevance Reranking** — When to apply: always, as a first pass on results. Instructions: re-evaluate each result against the original intent, not just the search query. A result may match query keywords but not address the actual question. Check `relevanceScore` in the response — scores below 0.3 are often tangentially related. Mentally reorder results by how directly they answer the question. Discard results that are clearly irrelevant even if their score is moderate. End section with `**Examples:** \`examples/relevance-reranking.md\``

2. **Trust-Aware Reranking** — When to apply: when result reliability matters — production code, security-sensitive patterns, or when results come from mixed sources. Instructions: check `source.repository` in each result. Apply this trust hierarchy:
   - Highest: `midnightntwrk` official repos (compiler, SDK, examples)
   - High: `OpenZeppelin` audited libraries
   - Medium: `LFDT-Minokawa` infrastructure
   - Lower: community and third-party code
   Boost results from higher-trust sources. When two results provide similar information, prefer the higher-trust source. This is especially important for `midnight-search-typescript` results where server-side filtering is unavailable. End section with `**Examples:** \`examples/trust-aware-reranking.md\``

3. **Freshness Reranking** — When to apply: when the query is time-sensitive — version-specific questions, migration guidance, recent changes, or when the user says "latest" or "current." Instructions: check date metadata in results where available. Prefer results from more recent sources when recency matters. Be cautious: in a blockchain context, older audited code may be more reliable than newer unaudited code. Freshness should boost, not override, trust rankings. End section with `**Examples:** \`examples/freshness-reranking.md\``

4. **Deduplication** — When to apply: when results contain near-identical content from the same or forked repos. Common when searching broad topics. Instructions: identify results that contain substantially the same code or text. Keep the result from the most authoritative source. Collapse duplicates into a single entry, noting that alternatives exist. Watch for fork-induced duplication — the same contract may appear in multiple repos. End section with `**Examples:** \`examples/deduplication.md\``

5. **Coverage Balancing** — When to apply: when the query has multiple facets or sub-topics, and results cluster around only one facet. Instructions: check whether the results cover the different parts of the question. If 8 of 10 results address facet A and 0 address facet B, the result set is imbalanced. Consider a follow-up search targeted at the underrepresented facet. When presenting results, organize by facet rather than by score. End section with `**Examples:** \`examples/coverage-balancing.md\``

6. **Answerability Scoring** — When to apply: as a final filter before using results. Instructions: for each result, assess: "does this actually answer the user's question, or does it just mention the same terms?" A result that contains the relevant code pattern is answerable. A result that mentions the pattern name in passing is not. Prefer results that provide complete, actionable information over those that provide fragments or tangential mentions. End section with `**Examples:** \`examples/answerability-scoring.md\``

- [ ] **Step 2: Write `examples/relevance-reranking.md`**

Example scenarios:
- Searched for `token transfer shielded` → results include a shielded transfer circuit (relevant), a generic Counter example that mentions "transfer" in a comment (irrelevant), and a test file that imports the transfer module (marginally relevant) → rerank: circuit first, test file second, Counter example dropped
- Searched for `deploy contract provider` → results include deployment guide (relevant, score 0.7), a provider type definition (partially relevant, score 0.5), and an unrelated indexer configuration (irrelevant, score 0.25) → rerank: guide first, type def second, drop the indexer result
- Results where `relevanceScore` is misleading — a high-scoring result that matches keywords but is from the wrong context

Anti-patterns:
- Accepting all results at face value based on `relevanceScore` alone
- Dropping all results below an arbitrary threshold without checking content
- Reranking based on result length rather than relevance to the question

- [ ] **Step 3: Write `examples/trust-aware-reranking.md`**

Example scenarios:
- Two token transfer implementations: one from `midnightntwrk/examples` and one from `community/midnight-demo` → prefer the `midnightntwrk` version
- OpenZeppelin audited `Ownable` module vs community implementation of similar access control → prefer OpenZeppelin
- TypeScript SDK results (no server filter applied): mixed sources → mentally sort by `source.repository` trust level

Anti-patterns:
- Rejecting all community code (it may be the only source for a niche pattern)
- Trusting all `midnightntwrk` code equally (some repos have outdated or experimental examples)
- Applying trust reranking when the user explicitly asked for broad/diverse results

- [ ] **Step 4: Write `examples/freshness-reranking.md`**

Example scenarios:
- User asks "what's the latest syntax for declaring a ledger" → boost results with more recent dates
- User asks "how does the proven token standard work" → freshness less important than correctness — audited code from 6 months ago may be better than last week's experiment
- Migration question: "changes between SDK v1 and v2" → boost results referencing the target version

Anti-patterns:
- Always preferring the newest result (older audited code can be more correct)
- Ignoring freshness for version-sensitive questions
- Treating freshness as a primary signal rather than a tiebreaker

- [ ] **Step 5: Write `examples/deduplication.md`**

Example scenarios:
- Same token contract appears in `midnightntwrk/examples` and a fork `user/midnight-token-demo` → keep the `midnightntwrk` version, note the fork exists
- Same code snippet appears in 3 different search results because it's in the README, the source file, and a test → collapse to the source file version
- Two genuinely different implementations of the same pattern → do NOT deduplicate — these are distinct and both valuable

Anti-patterns:
- Deduplicating results that look similar but are actually different approaches
- Keeping the duplicate with the higher score when the other is from a more trusted source
- Not deduplicating at all, presenting 5 copies of the same code

- [ ] **Step 6: Write `examples/coverage-balancing.md`**

Example scenarios:
- Query: "Compact state management patterns" → results are all about `Counter` → missing: `Map`, `Set`, `MerkleTree` patterns → follow-up search for `Map Set MerkleTree state`
- Query: "how to test and deploy Compact contracts" → results are all about deployment → missing: testing patterns → follow-up search for `Compact contract testing simulator`
- Query about both Compact and TypeScript sides → all results from `midnight-search-compact` → missing TypeScript coverage → follow-up with `midnight-search-typescript`

Anti-patterns:
- Assuming the first result set is complete without checking coverage
- Doing a follow-up search for every facet (only search for genuinely missing coverage)
- Presenting results in score order when facet-grouped order would be clearer

- [ ] **Step 7: Write `examples/answerability-scoring.md`**

Example scenarios:
- User asks "how to use Counter increment": result A is a complete circuit with Counter.increment() (answerable), result B is a changelog mentioning Counter was added (not answerable) → use result A
- User asks "token transfer pattern": result A is a full contract implementation (answerable), result B is a one-line import of a transfer module (not answerable on its own) → use result A, optionally include B as supplementary
- User asks "deploy to testnet": result A is a deployment tutorial (answerable), result B mentions testnet in passing within an unrelated discussion (not answerable) → use result A only

Anti-patterns:
- Treating any result that mentions the search terms as answerable
- Requiring every result to be independently sufficient (some provide useful supplementary context)
- Not checking answerability at all and presenting all results equally

- [ ] **Step 8: Verify all files**

Read back each file. Confirm:
- Reference file has 6 technique sections, each with `**Examples:**` pointer
- Trust-aware reranking lists the correct trust hierarchy
- Each example file follows the template with 3-5 before/after pairs and 2-3 anti-patterns

- [ ] **Step 9: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/result-refinement.md
git add plugins/midnight-mcp/skills/mcp-search/examples/relevance-reranking.md
git add plugins/midnight-mcp/skills/mcp-search/examples/trust-aware-reranking.md
git add plugins/midnight-mcp/skills/mcp-search/examples/freshness-reranking.md
git add plugins/midnight-mcp/skills/mcp-search/examples/deduplication.md
git add plugins/midnight-mcp/skills/mcp-search/examples/coverage-balancing.md
git add plugins/midnight-mcp/skills/mcp-search/examples/answerability-scoring.md
git commit -m "feat(mcp-search): add result refinement cluster reference and examples"
```

---

### Task 6: Iterative Search Cluster (reference + 4 examples)

**Files:**
- Create: `skills/mcp-search/references/iterative-search.md`
- Create: `skills/mcp-search/examples/retrieve-read-retrieve.md`
- Create: `skills/mcp-search/examples/query-refinement.md`
- Create: `skills/mcp-search/examples/confidence-assessment.md`
- Create: `skills/mcp-search/examples/contradiction-detection.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/iterative-search.md`**

This file covers 4 techniques for refining when initial results are insufficient. These techniques trigger a second (or third) search pass.

1. **Retrieve-Read-Retrieve** — When to apply: when initial results partially answer the question but leave gaps, or when reading results reveals that the question has a dimension that the original query missed. Instructions: read the initial results carefully. Identify what aspects of the question remain unanswered. Formulate a targeted follow-up query that specifically addresses the gap. Do NOT repeat the original query — the follow-up must target different content. Limit to one follow-up pass; if two rounds don't produce answers, the information may not be in the index. End section with `**Examples:** \`examples/retrieve-read-retrieve.md\``

2. **Query Refinement** — When to apply: when results are too broad (many results, none specific enough) or too narrow (few or no results). Instructions:
   - Too broad → add specificity: more Midnight-specific terms, type names, construct names
   - Too narrow → remove constraints: fewer terms, more general concepts, drop version-specific terms
   - Wrong results entirely → rethink the query approach, possibly switch tools or use a different technique from Query Expansion cluster

   End section with `**Examples:** \`examples/query-refinement.md\``

3. **Confidence Assessment** — When to apply: after every search, before presenting results to the user. Instructions: assess the result set:
   - **High confidence**: multiple results from trusted sources agree, covering the full question → present results
   - **Medium confidence**: some relevant results but gaps, or results from lower-trust sources → note the gaps, consider a follow-up search
   - **Low confidence**: few relevant results, conflicting information, or results that don't directly address the question → do a follow-up search, try a different technique, or flag the uncertainty to the user

   This is about search sufficiency, not result trustworthiness (which belongs to `compact-core:verify-correctness`).

   End section with `**Examples:** \`examples/confidence-assessment.md\``

4. **Contradiction Detection** — When to apply: when multiple search results provide conflicting information about the same topic. Instructions: when results disagree (different function signatures, different behaviors described, different recommendations), do NOT silently pick one. Flag both results to the user with their sources. Note which source is more authoritative (trust hierarchy) and more recent (freshness). If the contradiction might be due to version differences, note the versions. Let the user or the verification skill resolve the conflict. End section with `**Examples:** \`examples/contradiction-detection.md\``

- [ ] **Step 2: Write `examples/retrieve-read-retrieve.md`**

Example scenarios:
- First search for `token transfer` returns the transfer circuit but not the witness implementation → follow-up search for `token transfer witness TypeScript`
- First search for `MerkleTree` returns usage examples but not depth/capacity limits → follow-up for `MerkleTree depth limit capacity`
- First search for deployment returns conceptual docs but no code → follow-up with `midnight-search-typescript` for `deploy contract provider code`

Anti-patterns:
- Repeating the same query hoping for different results
- Doing follow-up searches when the initial results are sufficient
- More than 2 total search rounds (diminishing returns)

- [ ] **Step 3: Write `examples/query-refinement.md`**

Example scenarios:
- Too broad: `state management` returns 50+ results about everything → refine to `Counter Map ledger state Compact`
- Too narrow: `MerkleTree<Bytes<32>, 16> insert` returns nothing → broaden to `MerkleTree insert member`
- Wrong tool: searched `midnight-search-compact` for TypeScript types → switch to `midnight-search-typescript`

Anti-patterns:
- Adding random terms to narrow a broad search (add terms that relate to what was missing)
- Removing all specific terms when broadening (keep at least the core concept)
- Refining more than twice without rethinking the approach entirely

- [ ] **Step 4: Write `examples/confidence-assessment.md`**

Example scenarios:
- High confidence: 3 results from `midnightntwrk` repos show the same pattern → present with confidence
- Medium confidence: 1 result from a community repo, partially answers the question → note uncertainty, suggest verification
- Low confidence: no relevant results for "recursive proof composition" → inform user this may not be in the index, suggest checking source code directly

Anti-patterns:
- Presenting low-confidence results as definitive answers
- Always flagging uncertainty (high-confidence results from trusted sources don't need caveats)
- Conflating search confidence with result trustworthiness (different concerns)

- [ ] **Step 5: Write `examples/contradiction-detection.md`**

Example scenarios:
- Doc says `Counter` supports decrement, but code examples only show increment → flag: "documentation suggests decrement support, but no code examples found — verify with compilation"
- Two results show different import paths for the same package → likely version difference: note both with their version context
- One result says `disclose` is mandatory for public ledger state, another implies it's automatic → flag and recommend checking `compact-core:compact-privacy-disclosure` skill

Anti-patterns:
- Silently picking the result that matches your assumption
- Treating all contradictions as errors (some are version differences, which are expected)
- Flagging superficial differences as contradictions (different code style, same behavior)

- [ ] **Step 6: Verify all files**

Read back each file. Confirm reference has 4 technique sections with `**Examples:**` pointers, each example file follows the template.

- [ ] **Step 7: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/iterative-search.md
git add plugins/midnight-mcp/skills/mcp-search/examples/retrieve-read-retrieve.md
git add plugins/midnight-mcp/skills/mcp-search/examples/query-refinement.md
git add plugins/midnight-mcp/skills/mcp-search/examples/confidence-assessment.md
git add plugins/midnight-mcp/skills/mcp-search/examples/contradiction-detection.md
git commit -m "feat(mcp-search): add iterative search cluster reference and examples"
```

---

### Task 7: Code-Specific Search Cluster (reference + 5 examples)

**Files:**
- Create: `skills/mcp-search/references/code-search.md`
- Create: `skills/mcp-search/examples/symbol-aware-search.md`
- Create: `skills/mcp-search/examples/error-to-doc.md`
- Create: `skills/mcp-search/examples/example-mining.md`
- Create: `skills/mcp-search/examples/version-aware-search.md`
- Create: `skills/mcp-search/examples/diff-aware-search.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/code-search.md`**

This file covers 5 techniques specifically for searching code patterns.

1. **Symbol-Aware Search** — When to apply: when the query targets a specific named symbol — a type, function, module, circuit, or constructor. Instructions: detect symbol names in the query. Compact symbols include: `Counter`, `MerkleTree`, `Map`, `Set`, `Bytes`, `Uint`, `Field`, `Boolean`, `Void`, `Optional`, `Vector`, `persistentHash`, `persistentCommit`, `pad`, `merge`, `assert`. TypeScript symbols include: `ContractAddress`, `DeployedContract`, `MidnightProvider`, `WalletProvider`, `Transaction`, `NodeApiClient`. Use exact symbol names in queries — do not paraphrase (`Counter` not "counter variable", `MerkleTree` not "tree data structure"). For stdlib functions, cross-reference with `compact-core:compact-standard-library`. End section with `**Examples:** \`examples/symbol-aware-search.md\``

2. **Error-to-Doc Search** — When to apply: when the user provides a compiler error, runtime error, or stack trace. Instructions: extract the distinctive parts of the error message — error codes, specific function names mentioned, type mismatch details. Strip the file-specific context (line numbers, file paths) that won't match in the index. Rewrite into a search query using the error's key terms. For Compact compiler errors, include both the error text and the likely cause terms. For TypeScript runtime errors, include the package name and error type. End section with `**Examples:** \`examples/error-to-doc.md\``

3. **Example Mining** — When to apply: when the user needs runnable, complete code examples rather than documentation or partial snippets. Instructions: bias search queries toward finding complete implementations. Add terms like `example`, `contract`, `circuit export` for Compact code. For TypeScript, add `example`, `implementation`, `deploy`. Prefer results that include full file content over single-function snippets. Check `source.repository` — official example repos (`midnightntwrk/examples`, `midnightntwrk/midnight-examples`) are the richest source. The MCP tool `midnight-list-examples` (from `mcp-overview`) can also list available example contracts with complexity ratings. End section with `**Examples:** \`examples/example-mining.md\``

4. **Version-Aware Search** — When to apply: when the user's project targets a specific Compact language version or SDK version, and results from other versions could be misleading or incorrect. Instructions: determine the target version from environmental grounding (Context Gathering cluster) or user context. Include version-specific terms in the query where relevant. After retrieval, check `source.repository` metadata for version indicators. Deprioritize results from significantly different versions. Be especially careful with import paths, API signatures, and syntax that changes between versions. End section with `**Examples:** \`examples/version-aware-search.md\``

5. **Diff-Aware Search** — When to apply: when the user is in a PR review, migration, or refactoring context and the search should be informed by what's changing. Instructions: identify the files being changed (from git diff, open PR, or user description). Use the changed file paths, modified function names, and affected types as search context. For migrations, search for the specific constructs being migrated. For PR reviews, search for patterns that the PR is trying to implement to verify correctness. End section with `**Examples:** \`examples/diff-aware-search.md\``

- [ ] **Step 2: Write `examples/symbol-aware-search.md`**

Example scenarios:
- User asks "how to use merkle trees" → detect `MerkleTree` symbol → query: `MerkleTree insert member proof`
- User asks about "the hash function" → detect `persistentHash` or `persistentCommit` → query: `persistentHash persistentCommit usage`
- User asks "how to check contract address" → detect `ContractAddress` TypeScript symbol → route to `midnight-search-typescript`, query: `ContractAddress type deployed`
- User mentions "the optional type" → detect `Optional` Compact type → query: `Optional value unwrap Compact`

Anti-patterns:
- Paraphrasing symbol names ("tree structure" instead of `MerkleTree`, "counter variable" instead of `Counter`)
- Searching for a symbol without specifying the context (e.g., `Map` alone matches too broadly)
- Assuming a symbol exists because the user named it (verify with `compact-core:compact-standard-library`)

- [ ] **Step 3: Write `examples/error-to-doc.md`**

Example scenarios:
- Compact compiler error: `Type mismatch: expected Bytes<32>, got Field` → query: `Bytes Field type conversion cast Compact`
- Runtime error: `Cannot find module '@midnight-ntwrk/midnight-js-contracts'` → query: `midnight-js-contracts import module installation` on `midnight-search-typescript`
- Stack trace with `ERR_UNSUPPORTED_DIR_IMPORT` → query: `ERR_UNSUPPORTED_DIR_IMPORT module resolution` on `midnight-search-docs`
- Compiler error: `Undeclared identifier: foo` → strip the specific name, query: `undeclared identifier import module Compact`

Anti-patterns:
- Searching for the full error message including line numbers and file paths
- Searching for just the error code without context terms
- Using `midnight-search-compact` for runtime JavaScript errors (use `midnight-search-typescript` or `midnight-search-docs`)

- [ ] **Step 4: Write `examples/example-mining.md`**

Example scenarios:
- User needs "a complete token contract" → query: `token contract example ledger circuit export` on `midnight-search-compact` with trusted sources
- User needs "how to connect a wallet in TypeScript" → query: `wallet provider connect example implementation` on `midnight-search-typescript`
- User needs "a voting contract example" → first try `midnight-list-examples` to see if one exists, then `midnight-search-compact` with `voting ballot tally example`

Anti-patterns:
- Returning documentation snippets when the user asked for code examples
- Returning partial implementations (a single function) when the user needs a complete contract
- Not checking `midnight-list-examples` for curated example contracts

- [ ] **Step 5: Write `examples/version-aware-search.md`**

Example scenarios:
- Project uses `pragma language_version 0.2.0` → include `language_version 0.2.0` or `v0.2` in queries, deprioritize results referencing 0.1.x syntax
- `package.json` shows `@midnight-ntwrk/midnight-js-contracts: "^2.0.0"` → focus on SDK v2 patterns, deprioritize v1 import paths
- User asks about feature availability → version is critical context: "does Compact support X?" depends entirely on which version

Anti-patterns:
- Ignoring version context and returning results from any version
- Being overly strict about versions (a pattern from 0.27.0 often works in 0.28.0)
- Not checking environmental context when version matters

- [ ] **Step 6: Write `examples/diff-aware-search.md`**

Example scenarios:
- User is refactoring `Counter` to `MerkleTree` in a PR → search for `MerkleTree` patterns that match the previous `Counter` usage context
- User is migrating from SDK v1 to v2 → search for the specific imports and APIs that changed
- User's PR introduces a new `disclose` call → search for `disclose` patterns and privacy implications

Anti-patterns:
- Ignoring the diff context and doing generic searches
- Searching for every changed symbol (focus on the ones relevant to the user's question)
- Using diff-aware search when the user is asking about something unrelated to the current changes

- [ ] **Step 7: Verify all files**

Read back each file. Confirm:
- Reference file has 5 technique sections with `**Examples:**` pointers
- Symbol lists in symbol-aware search include real Compact and TypeScript names
- Each example file follows the template

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/code-search.md
git add plugins/midnight-mcp/skills/mcp-search/examples/symbol-aware-search.md
git add plugins/midnight-mcp/skills/mcp-search/examples/error-to-doc.md
git add plugins/midnight-mcp/skills/mcp-search/examples/example-mining.md
git add plugins/midnight-mcp/skills/mcp-search/examples/version-aware-search.md
git add plugins/midnight-mcp/skills/mcp-search/examples/diff-aware-search.md
git commit -m "feat(mcp-search): add code-specific search cluster reference and examples"
```

---

### Task 8: Server-Enhanced Search Reference

**Files:**
- Create: `skills/mcp-search/references/server-enhanced.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/server-enhanced.md`**

This file documents 7 techniques that require MCP server changes. Each section should include:
- What the technique does
- What it would enable for the LLM consumer
- Current limitation (why the LLM cannot do this today)
- Recommended server-side implementation approach
- What would need to change in this plugin once the server supports it

Techniques:

1. **Hybrid Search** — Currently the MCP server uses either keyword or vector search (implementation-dependent). Adding BM25 + vector fusion would improve recall for queries that mix exact terms with semantic concepts. The LLM currently compensates with multi-query, but hybrid search would produce better results from a single query. Server change: add a `hybrid: true` parameter or make it default. Plugin change: update `references/tool-routing.md` parameter optimization section.

2. **Field-Aware Retrieval** — Currently all text fields are weighted equally. Weighting title and headings higher than body text would improve precision for keyword queries. Server change: add field weights to the scoring algorithm, optionally expose a `fieldWeights` parameter. Plugin change: update `references/tool-routing.md` parameter optimization section.

3. **Extended Metadata Filtering** — Currently `midnight-search-compact` supports `filter.repository` and `filter.isPublic`. Adding filters for date range, language version, doc type, and source author would let the LLM narrow results server-side rather than doing client-side post-filtering. Server change: extend the `filter` parameter schema. Plugin change: update `references/tool-routing.md` and `examples/parameter-optimization.md`.

4. **Diversity-Aware Retrieval** — Currently the server may return multiple chunks from the same document. Adding a `diversify: true` parameter or max-per-document limit would ensure the result set covers different sources. Server change: add a `maxPerDocument` parameter or diversity reranking. Plugin change: update `references/result-refinement.md` to note that server-side dedup reduces the need for client-side deduplication.

5. **Parent-Child Retrieval** — Currently results are individual chunks without surrounding context. Returning the parent section or document alongside the matching chunk would give the LLM more context. Server change: add a `includeParent: true` parameter that returns the surrounding section. Plugin change: update result interpretation guidance in multiple references.

6. **Passage Compression** — Currently full chunks are returned even if only a small span is relevant. Server-side extraction of the most relevant span would reduce token consumption. Server change: add a `compress: true` parameter that returns only the relevant span plus surrounding context. Plugin change: update result interpretation guidance.

7. **Graph-Assisted Retrieval** — Currently documents are retrieved independently. Using links between docs, code symbols, repos, and issues would enable retrieval of related content that doesn't share keywords. Server change: build a link graph across indexed content, add a `followLinks: true` parameter. Plugin change: add new examples for graph-aware search patterns, update cross-tool orchestration guidance.

- [ ] **Step 2: Verify the file**

Read back the file. Confirm all 7 techniques are documented with the required sections.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md
git commit -m "feat(mcp-search): add server-enhanced search reference with 7 MCP server feature requests"
```

---

### Task 9: Create GitHub Issues for Server-Side Enhancements

**Depends on:** Task 8

This task creates 7 GitHub issues on `devrelaicom/compact-playground`, one per technique in `references/server-enhanced.md`.

- [ ] **Step 1: Read back `references/server-enhanced.md`**

Read the file to get the exact content for each issue.

- [ ] **Step 2: Create GitHub issue for Hybrid Search**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add hybrid search (BM25 + vector) to search endpoints" \
  --body "$(cat <<'EOF'
## Summary

Add hybrid search combining keyword/BM25 matching with vector similarity to the search endpoints (`midnight-search-compact`, `midnight-search-typescript`, `midnight-search-docs`).

## Motivation

Currently, search relies on a single retrieval strategy. Queries that mix exact terms (type names like `Counter`, `MerkleTree`) with semantic concepts ("how to manage state") perform poorly because keyword search misses the semantic intent and vector search may miss exact term matches.

LLM consumers currently compensate with multi-query generation (separate keyword-optimized and concept-optimized queries), which doubles the number of API calls. Server-side hybrid search would produce better results from a single query.

## Proposed Change

- Add a `hybrid` boolean parameter to search endpoints (default: `true` or make it the default strategy)
- Implement reciprocal rank fusion (RRF) or similar fusion algorithm to combine BM25 and vector results
- Optionally expose a `hybridWeight` parameter (0.0 = pure keyword, 1.0 = pure vector) for fine-tuning

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add `hybrid` to parameter optimization section
- `plugins/midnight-mcp/skills/mcp-search/examples/parameter-optimization.md` — add examples of hybrid parameter usage
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 3: Create GitHub issue for Field-Aware Retrieval**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add field-aware retrieval with differential field weighting" \
  --body "$(cat <<'EOF'
## Summary

Weight different document fields (title, headings, code blocks, body text, tags) differently in search scoring.

## Motivation

Currently all text fields are weighted equally in scoring. A query for `MerkleTree` should rank a document titled "MerkleTree Operations" higher than one that mentions MerkleTree once in the body. Title and heading matches are stronger relevance signals than body text matches.

LLM consumers currently compensate with relevance reranking (re-evaluating results client-side), which is token-expensive and imprecise.

## Proposed Change

- Implement field-based scoring with default weights: title (3x), headings (2x), code blocks (1.5x), body (1x)
- Optionally expose a `fieldWeights` parameter for consumer-specified weighting

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add field weighting to parameter optimization
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 4: Create GitHub issue for Extended Metadata Filtering**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: extend metadata filtering on search endpoints" \
  --body "$(cat <<'EOF'
## Summary

Extend the `filter` parameter on search endpoints beyond `repository` and `isPublic` to support date range, language version, document type, and source author filtering.

## Motivation

Currently `midnight-search-compact` supports `filter.repository` and `filter.isPublic`. `midnight-search-typescript` and `midnight-search-docs` have no filtering beyond `category` on docs. LLM consumers perform version-aware and freshness filtering client-side after retrieval, which wastes tokens on irrelevant results.

## Proposed Change

Extend the `filter` parameter schema:

```json
{
  "filter": {
    "repository": "string",
    "isPublic": "boolean",
    "dateRange": { "from": "ISO-8601", "to": "ISO-8601" },
    "languageVersion": "string (semver range)",
    "docType": "enum: guide | api | concept | example | changelog",
    "author": "string"
  }
}
```

Apply filtering server-side before scoring to reduce result set size and improve relevance.

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add new filter parameters
- `plugins/midnight-mcp/skills/mcp-search/examples/parameter-optimization.md` — add filter examples
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 5: Create GitHub issue for Diversity-Aware Retrieval**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add diversity-aware retrieval to avoid same-document clustering" \
  --body "$(cat <<'EOF'
## Summary

Add a mechanism to limit the number of results returned from any single document, ensuring the result set covers different sources.

## Motivation

Broad queries often return multiple chunks from the same large document, providing redundant information and missing relevant content from other sources. LLM consumers currently deduplicate client-side, wasting tokens on results that will be discarded.

## Proposed Change

- Add a `maxPerDocument` integer parameter (default: 3) that caps results per source document
- After initial scoring, enforce the per-document limit and backfill with the next-highest-scoring results from other documents

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add `maxPerDocument` parameter
- `plugins/midnight-mcp/skills/mcp-search/references/result-refinement.md` — note reduced need for client-side dedup
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 6: Create GitHub issue for Parent-Child Retrieval**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add parent-child retrieval for surrounding context" \
  --body "$(cat <<'EOF'
## Summary

When a chunk matches, optionally return the surrounding section or parent document alongside the matching chunk.

## Motivation

Search results are individual chunks without surrounding context. The LLM often needs the full function, full section, or full file to understand a code pattern. Currently the LLM must make follow-up calls to get context.

## Proposed Change

- Add an `includeParent` boolean parameter (default: `false`)
- When enabled, return the parent section (heading-delimited) or the full containing file alongside the matching chunk
- Include a `parentContent` field in the response alongside the existing chunk content

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add parameter guidance
- `plugins/midnight-mcp/skills/mcp-search/references/result-refinement.md` — update result interpretation
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 7: Create GitHub issue for Passage Compression**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add passage compression to return only relevant spans" \
  --body "$(cat <<'EOF'
## Summary

Extract and return only the most relevant span from long chunks, reducing token consumption while preserving the answer.

## Motivation

Search results often include full chunks where only a small span is relevant. This wastes LLM context tokens. Client-side extraction is possible but happens after the tokens are already consumed in the API response.

## Proposed Change

- Add a `compress` boolean parameter (default: `false`)
- When enabled, use extractive summarization or span detection to return only the relevant portion plus N lines of surrounding context
- Include both the compressed span and position metadata (start/end offsets) in the response

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add parameter guidance
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 8: Create GitHub issue for Graph-Assisted Retrieval**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add graph-assisted retrieval using cross-entity links" \
  --body "$(cat <<'EOF'
## Summary

Use links between documents, code symbols, repositories, issues, and examples to retrieve related content that doesn't share keywords with the query.

## Motivation

Currently documents are retrieved independently based on text similarity. A search for a Compact function won't surface the related TypeScript SDK bindings, the documentation page that explains it, or the example contract that uses it — unless those share keywords. Graph-assisted retrieval would follow these relationships to provide more complete results.

## Proposed Change

- Build a link graph across indexed content: doc-to-code, code-to-test, function-to-usage, package-to-docs
- Add a `followLinks` boolean parameter (default: `false`)
- When enabled, expand the result set to include directly linked content (1 hop)
- Include `relatedContent` in the response with relationship labels

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-search/references/tool-routing.md` — add parameter guidance and graph-aware search patterns
- `plugins/midnight-mcp/skills/mcp-search/examples/cross-tool-orchestration.md` — add graph-assisted examples
- `plugins/midnight-mcp/skills/mcp-search/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 9: Verify all issues were created**

```bash
gh issue list --repo devrelaicom/compact-playground --label "" --limit 10 --json title,url
```

Confirm 7 new issues exist.

- [ ] **Step 10: Commit (no file changes, but record the issue URLs)**

No file changes needed. The issue URLs are captured in the GitHub repo. Optionally update `references/server-enhanced.md` to include the issue URLs inline as markdown links.

---

### Task 10: Slash Command

**Files:**
- Create: `plugins/midnight-mcp/commands/search.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `commands/search.md`**

Follow the command conventions from existing commands (`devnet.md`, `doctor.md`). The command file needs YAML frontmatter and step-by-step instructions.

```markdown
---
description: Search Midnight code, documentation, and SDK patterns with technique-aware query optimization, preset modes, and interactive guided search
allowed-tools: AskUserQuestion, Read, Glob, Grep, mcp__midnight__midnight-search-compact, mcp__midnight__midnight-search-typescript, mcp__midnight__midnight-search-docs, mcp__midnight__midnight-fetch-docs, mcp__midnight__midnight-list-examples, mcp__midnight__midnight-suggest-tool
argument-hint: [<query>] [--compact | --typescript | --docs | --all] [--quick | --thorough | --debug | --examples | --migration] [--trusted-only] [--rewrite] [--multi-query] [--step-back] [--hyde] [--decompose] [--rerank] [--dedupe] [--iterative] [--version-aware] [--env]
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
```

- [ ] **Step 2: Verify the command file**

Read back the file. Confirm:
- YAML frontmatter has `description`, `allowed-tools`, `argument-hint`
- All MCP tool names in `allowed-tools` use the correct `mcp__midnight__` prefix
- All 10 steps are present and logically ordered
- Interactive mode uses `AskUserQuestion`
- Preset technique mapping matches the spec
- Reference file paths are correct (relative to the skill)

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/commands/search.md
git commit -m "feat(midnight-mcp): add /midnight-mcp:search slash command with presets and interactive mode"
```

---

### Task 11: Integration Verification

**Depends on:** All previous tasks

- [ ] **Step 1: Verify all files exist**

Run a verification check that all 38 expected files exist:

```bash
# SKILL.md
test -f plugins/midnight-mcp/skills/mcp-search/SKILL.md && echo "OK: SKILL.md" || echo "MISSING: SKILL.md"

# 7 reference files
for f in query-expansion context-gathering tool-routing result-refinement iterative-search code-search server-enhanced; do
  test -f "plugins/midnight-mcp/skills/mcp-search/references/$f.md" && echo "OK: references/$f.md" || echo "MISSING: references/$f.md"
done

# 29 example files
for f in query-rewriting multi-query step-back-queries hyde decomposition conversation-grounding environmental-grounding entity-extraction facet-extraction intent-classification source-routing trusted-source-filtering parameter-optimization cross-tool-orchestration relevance-reranking trust-aware-reranking freshness-reranking deduplication coverage-balancing answerability-scoring retrieve-read-retrieve query-refinement confidence-assessment contradiction-detection symbol-aware-search error-to-doc example-mining version-aware-search diff-aware-search; do
  test -f "plugins/midnight-mcp/skills/mcp-search/examples/$f.md" && echo "OK: examples/$f.md" || echo "MISSING: examples/$f.md"
done

# Command file
test -f plugins/midnight-mcp/commands/search.md && echo "OK: commands/search.md" || echo "MISSING: commands/search.md"
```

All 38 files must show "OK". Fix any missing files before proceeding.

- [ ] **Step 2: Verify cross-references in SKILL.md**

Read the SKILL.md and confirm that every reference file path mentioned in the routing table exists. Extract paths with grep and check each:

```bash
grep -oP 'references/[a-z-]+\.md' plugins/midnight-mcp/skills/mcp-search/SKILL.md | sort -u | while read ref; do
  test -f "plugins/midnight-mcp/skills/mcp-search/$ref" && echo "OK: $ref" || echo "BROKEN: $ref"
done
```

- [ ] **Step 3: Verify example file references in cluster references**

For each reference file, confirm that every `examples/*.md` path it mentions exists:

```bash
for ref in plugins/midnight-mcp/skills/mcp-search/references/*.md; do
  grep -oP 'examples/[a-z-]+\.md' "$ref" | while read ex; do
    test -f "plugins/midnight-mcp/skills/mcp-search/$ex" && echo "OK: $(basename $ref) → $ex" || echo "BROKEN: $(basename $ref) → $ex"
  done
done
```

- [ ] **Step 4: Verify example file structure**

Each example file must have:
- `# [Name] Examples` heading
- `## When to Apply` section
- `## Examples` section with at least 3 `### ` subsections
- `## Anti-Patterns` section with at least 2 `### ` subsections

```bash
for f in plugins/midnight-mcp/skills/mcp-search/examples/*.md; do
  name=$(basename "$f")
  examples=$(grep -c '^### ' "$f" 2>/dev/null || echo 0)
  has_when=$(grep -c '## When to Apply' "$f" 2>/dev/null || echo 0)
  has_anti=$(grep -c '## Anti-Patterns' "$f" 2>/dev/null || echo 0)
  if [ "$has_when" -ge 1 ] && [ "$has_anti" -ge 1 ] && [ "$examples" -ge 5 ]; then
    echo "OK: $name ($examples subsections)"
  else
    echo "CHECK: $name (when=$has_when, anti=$has_anti, subsections=$examples)"
  fi
done
```

- [ ] **Step 5: Verify command file frontmatter**

```bash
head -5 plugins/midnight-mcp/commands/search.md
```

Confirm `description`, `allowed-tools`, and `argument-hint` are present in the YAML frontmatter.

- [ ] **Step 6: Verify GitHub issues**

```bash
gh issue list --repo devrelaicom/compact-playground --search "search" --json title,url --limit 10
```

Confirm 7 issues were created.

- [ ] **Step 7: Final commit if any fixes were made**

If any verification steps revealed issues that were fixed:

```bash
git add -A plugins/midnight-mcp/
git commit -m "fix(mcp-search): address integration verification findings"
```

- [ ] **Step 8: Summary**

Report:
- Total files created/modified
- Total GitHub issues created
- Any issues found and fixed during verification
- Any remaining concerns
