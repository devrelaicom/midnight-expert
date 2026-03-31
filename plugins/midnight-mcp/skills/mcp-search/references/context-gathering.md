# Context Gathering

Techniques for enriching queries with information already available from the conversation or project environment.

## Conversation Grounding

**When to apply:** When prior conversation turns contain entity names, versions, file paths, contract names, or other specifics that the current query lacks.

Scan recent conversation turns for Midnight-specific entities: contract names, type names, version numbers, file paths, package names. Inject the most relevant entities into the search query as additional terms. Do not add entities that would narrow the search inappropriately.

**Examples:** `examples/conversation-grounding.md`

## Environmental Grounding

**When to apply:** When the user is working within a project that has Midnight dependencies or Compact source files, and the search would benefit from knowing the project's version context.

Check these project files:
- `package.json` — look for `@midnight-ntwrk/*` dependencies and their version ranges
- `*.compact` files — look for `pragma language_version` declarations
- Configuration files — look for network targets (devnet, testnet, mainnet), endpoint URLs
- `node_modules/@midnight-ntwrk/*/package.json` — look for actual installed versions if `package.json` has ranges

Inject the discovered version and network context as implicit constraints. For example, if the project uses `@midnight-ntwrk/midnight-js-contracts` version `2.x`, bias search results toward SDK v2 patterns.

**Examples:** `examples/environmental-grounding.md`

## Entity Extraction / Normalization

**When to apply:** Always, as a pre-processing step before query construction.

Scan the user's query for Midnight-specific entities:
- Package names: `@midnight-ntwrk/compact`, `@midnight-ntwrk/midnight-js-contracts`, etc.
- Type names: `Counter`, `MerkleTree`, `Map`, `Set`, `Bytes`, `Uint`, `Field`
- Construct names: `circuit`, `witness`, `ledger`, `export`, `import`, `disclose`
- Version strings: `0.28.0`, `v2`, `language_version 0.22`
- Tool/component names: proof server, indexer, node, Compact CLI, Lace wallet

Normalize detected entities: fix casing (`merkletree` to `MerkleTree`), resolve abbreviations only where written both ways, keep standard forms as-is.

**Examples:** `examples/entity-extraction.md`

## Facet Extraction

**When to apply:** When the query implies constraints that should be used for tool selection or parameter filtering rather than as search terms.

Extract implicit facets:
- Language/domain: Compact code vs TypeScript SDK vs documentation
- Version: specific version mentioned or implied
- Source trust level: user asks for "official" or "audited" — use trusted sources
- Content type: tutorial vs reference vs example code
- Recency: "latest", "current", "new" — freshness matters

Use extracted facets to inform tool selection (Tool Routing cluster) and result filtering (Result Refinement cluster). Do not include facets as literal search terms.

**Examples:** `examples/facet-extraction.md`
