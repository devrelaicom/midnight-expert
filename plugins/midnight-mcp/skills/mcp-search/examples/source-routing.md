# Source Routing Examples

## When to Apply

After intent classification, to select the specific MCP tool based on the detected entities and context.

## Examples

### Compact Type Entities Detected

**Before:**
```
User query mentions: Counter, MerkleTree, circuit, witness
→ No routing decision made
```

**After:**
```
Detected entities: Counter (Compact type), MerkleTree (Compact type), circuit (Compact construct), witness (Compact construct)
→ Route to: midnight-search-compact
Query: "Counter MerkleTree circuit witness usage"
```

**Why:** All detected entities are Compact language constructs. These exist in the Compact code index, not in TypeScript SDK or documentation search.

### TypeScript SDK Entities Detected

**Before:**
```
User query mentions: @midnight-ntwrk/midnight-js-contracts, Provider, ContractAddress
→ No routing decision made
```

**After:**
```
Detected entities: @midnight-ntwrk/midnight-js-contracts (npm package), Provider (TypeScript type), ContractAddress (TypeScript type)
→ Route to: midnight-search-typescript
Query: "midnight-js-contracts Provider ContractAddress"
```

**Why:** npm package names and TypeScript SDK types signal a TypeScript question. The TypeScript index contains SDK code and type definitions.

### Conceptual Keywords Detected

**Before:**
```
User query: "overview of how Midnight achieves data protection"
→ Default to midnight-search-compact
```

**After:**
```
Detected signals: "overview", "how...achieves", conceptual framing
→ Route to: midnight-search-docs
Query: "Midnight data protection privacy architecture"
```

**Why:** Conceptual framing words ("overview", "how does X work", "architecture of") indicate the user wants explanations, not code. Documentation provides this.

### Known Documentation Path

**Before:**
```
User query: "show me the compact language reference page"
→ Search for "compact language reference" across tools
```

**After:**
```
Known path: /compact/reference
→ Route to: midnight-fetch-docs with path: "/compact/reference"
```

**Why:** When the user requests a specific documentation page, fetching it directly is faster and returns complete content instead of search snippets.

## Anti-Patterns

### Routing Based on Keywords Alone

**Wrong:**
```
User mentions "TypeScript" in: "how does Compact generate TypeScript types?"
→ Route to midnight-search-typescript
```

**Problem:** The question is about Compact's type generation feature, not about TypeScript SDK usage. The word "TypeScript" is part of the question, not a routing signal.

**Instead:** Check entity types, not just keyword presence. The core entity here is Compact's type generation — route to `midnight-search-compact` or `midnight-search-docs`.

### Always Routing to the Same Tool

**Wrong:**
```
All queries → midnight-search-compact (because the user is a developer)
```

**Problem:** Compact code search is only one of four tools. SDK questions need TypeScript search, conceptual questions need docs search, known pages need fetch.

**Instead:** Classify intent and extract entities before routing. Different questions need different tools.

### Routing to Fetch Without Knowing the Path

**Wrong:**
```
User asks: "what does the docs say about tokens?"
→ Route to midnight-fetch-docs with path: "/token"
→ 404 — the actual path is "/token/overview"
```

**Problem:** `midnight-fetch-docs` requires an exact path. Guessing the path leads to errors.

**Instead:** Use `midnight-search-docs` first to discover the correct page path, then use `midnight-fetch-docs` to get the full content if needed.
