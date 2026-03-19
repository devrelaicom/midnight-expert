# Multi-Query Generation Examples

## When to Apply

When a single query is unlikely to capture all relevant results — ambiguous terms, multiple synonyms, or broad topics.

## Examples

### Covering Token Transfer Synonyms

**Before:**
```
Single query: "token transfer"
```

**After:**
```
Query 1: "token transfer circuit"
Query 2: "shielded send DUST"
Query 3: "DUST transfer ledger"
```

**Why:** "Token transfer" might appear as "shielded send" or "DUST transfer" in different codebases. Three queries with distinct terminology cover all naming conventions.

### Searching for Access Control Patterns

**Before:**
```
Single query: "access control"
```

**After:**
```
Query 1: "access control owner witness authorization"
Query 2: "OpenZeppelin Ownable Compact module"
Query 3: "circuit guard restrict caller"
```

**Why:** Access control is implemented differently across the ecosystem — Midnight Foundation uses `witness`-based patterns, OpenZeppelin provides `Ownable` modules, and some contracts use custom circuit guards.

### Cross-Domain Proof Server Research

**Before:**
```
Single query: "how does the proof server work"
```

**After:**
```
Query 1 (midnight-search-docs): "proof server architecture overview"
Query 2 (midnight-search-compact): "Zero Knowledge Proof (ZKP) proof generation circuit"
Query 3 (midnight-search-typescript): "proof server API endpoint client"
```

**Why:** The proof server spans documentation (architecture), Compact code (proof generation), and TypeScript (API integration). Each query targets the tool and terminology appropriate for that domain.

## Anti-Patterns

### Generating Minor Rephrases

**Wrong:**
```
Query 1: "token transfer pattern"
Query 2: "pattern for token transfers"
Query 3: "transferring tokens pattern"
```

**Problem:** These are syntactic variations of the same query. Vector-based search returns nearly identical results for all three, wasting API calls.

**Instead:** Each query should use genuinely different terminology: `token transfer circuit`, `shielded send DUST`, `DUST transfer ledger`.

### Generating Too Many Queries

**Wrong:**
```
Query 1: "Counter increment"
Query 2: "Counter add value"
Query 3: "Counter update state"
Query 4: "Counter modify ledger"
Query 5: "Counter change number"
```

**Problem:** Beyond 3 queries, returns diminish rapidly. Each additional query costs a tool call and adds token overhead without meaningful new results.

**Instead:** Limit to 2-3 queries maximum. Pick the most semantically distinct variants.

### Using Multi-Query for Simple Lookups

**Wrong:**
```
User asks: "what is the Counter type?"
Generating 3 queries for this.
```

**Problem:** Simple, specific lookups work well with a single query. Multi-query adds latency and token cost without benefit when the search term is already precise.

**Instead:** Use a single query: `Counter type Compact`. Reserve multi-query for ambiguous or broad topics.
