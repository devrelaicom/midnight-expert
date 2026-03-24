# Relevance Reranking Examples

## When to Apply

Always, as a first pass on results from any MCP search tool.

## Examples

### Filtering Tangential Results for Shielded Transfer

**Before:**
```
Query: "token transfer shielded"
Results:
  1. Shielded transfer circuit implementation (score: 0.72) — full transfer circuit
  2. Generic Counter example mentioning "transfer" in a comment (score: 0.41) — irrelevant
  3. Test file importing the transfer module (score: 0.38) — marginally relevant
```

**After:**
```
Reranked:
  1. Shielded transfer circuit implementation — directly answers the question
  2. Test file importing the transfer module — shows usage context
  Dropped: Generic Counter example — mentions "transfer" but is about Counter operations
```

**Why:** The Counter example matched the keyword "transfer" but is about Counter increment/decrement, not token transfers. Reranking by intent (not just keyword match) correctly identifies it as irrelevant.

### Correcting Misleading Relevance Scores

**Before:**
```
Query: "deploy contract provider"
Results:
  1. Deployment guide for Midnight DApps (score: 0.71) — comprehensive tutorial
  2. Provider type definition in SDK (score: 0.52) — partial match
  3. Indexer configuration mentioning "provider" (score: 0.25) — wrong context
```

**After:**
```
Reranked:
  1. Deployment guide — directly addresses the question
  2. Provider type definition — useful supplementary information
  Dropped: Indexer configuration — "provider" here means indexer provider, not deployment provider
```

**Why:** The indexer result scored 0.25 and uses "provider" in a different context. Relevance reranking identifies this as a false positive from keyword overlap.

### High Score But Wrong Context

**Before:**
```
Query: "witness function parameter types"
Results:
  1. Documentation page about witness construct (score: 0.68) — explains concept
  2. Compact code with witness accepting Field parameter (score: 0.65) — code example
  3. TypeScript test file with "witness" variable name (score: 0.55) — wrong domain
```

**After:**
```
Reranked:
  1. Compact code with witness accepting Field parameter — shows exactly what was asked
  2. Documentation page about witness construct — provides context
  Dropped: TypeScript test file — "witness" is a variable name, not a Compact construct
```

**Why:** The TypeScript result scored well because it contained the word "witness," but it uses "witness" as a generic variable name, not the Compact language construct.

## Anti-Patterns

### Accepting Results Based on relevanceScore Alone

**Wrong:**
```
Score > 0.5 → include
Score < 0.5 → exclude
```

**Problem:** `relevanceScore` measures keyword/vector similarity, not semantic relevance to the question. A result about "Counter transfer" may score high for a "token transfer" query despite being about transferring Counter ownership, not token transfers.

**Instead:** Use `relevanceScore` as a first filter, then manually assess each remaining result against the original intent.

### Dropping Results Below an Arbitrary Threshold

**Wrong:**
```
Drop all results with score < 0.4 without reading them
```

**Problem:** Some legitimate results score low due to terminology mismatch. A result about `shielded send` may score low for a "token transfer" query but be exactly what the user needs.

**Instead:** Read low-scoring results briefly before dropping them. A quick check of the title or first line reveals whether the low score is a false negative.

### Reranking by Result Length

**Wrong:**
```
Prefer longer results because they seem more comprehensive
```

**Problem:** Length does not correlate with relevance. A 50-line file that happens to contain boilerplate may be less useful than a 10-line snippet that shows exactly the right pattern.

**Instead:** Rank by how directly the result answers the question, regardless of length.
