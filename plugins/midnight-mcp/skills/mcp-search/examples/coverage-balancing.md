# Coverage Balancing Examples

## When to Apply

When the query has multiple facets or sub-topics, and results cluster around only one facet.

## Examples

### State Management Patterns — Missing Type Coverage

**Before:**
```
Query: "Compact state management patterns"
Results: 8 about Counter, 2 about ledger declarations
→ Missing: Map, Set, MerkleTree patterns
```

**After:**
```
Identified gap: no results for Map, Set, or MerkleTree state management
Follow-up search: "Map Set MerkleTree state management Compact"
→ Combined results now cover Counter, Map, Set, MerkleTree, and ledger patterns

Presented by facet:
  Counter patterns (3 results)
  Map patterns (2 results)
  Set patterns (1 result)
  MerkleTree patterns (2 results)
  Ledger declarations (2 results)
```

**Why:** "State management" has multiple facets — different state types. The initial results clustered around Counter because it is the most common. A follow-up search fills the gaps.

### Testing and Deployment — Missing Testing Coverage

**Before:**
```
Query: "how to test and deploy Compact contracts"
Results: 7 about deployment, 3 about provider setup
→ Missing: testing patterns entirely
```

**After:**
```
Identified gap: no results about testing
Follow-up search: "Compact contract testing simulator verify"
→ Combined results now cover both deployment and testing

Presented by facet:
  Deployment (4 results — kept the most relevant from original)
  Testing (3 results from follow-up)
```

**Why:** The deployment side dominated because more indexed content covers deployment than testing. Without the follow-up, the user gets an incomplete answer.

### Cross-Language Question — Missing TypeScript Coverage

**Before:**
```
Query: "building a DApp with Compact and TypeScript"
All results from midnight-search-compact — no TypeScript coverage
```

**After:**
```
Identified gap: no TypeScript SDK results
Follow-up: midnight-search-typescript query: "DApp TypeScript SDK integration provider"
→ Combined results cover both Compact and TypeScript sides

Presented by domain:
  Compact contract patterns (from midnight-search-compact)
  TypeScript SDK integration (from midnight-search-typescript)
```

**Why:** The initial search only covered the Compact side. A DApp question requires both Compact (contract) and TypeScript (frontend/integration) coverage.

## Anti-Patterns

### Assuming the First Result Set Is Complete

**Wrong:**
```
Query about multiple topics → get results → present them without checking coverage
```

**Problem:** Search engines return results ranked by relevance to the overall query, which naturally clusters around the dominant facet. Minor facets get underrepresented.

**Instead:** After every multi-facet query, check whether all facets are represented in the results. If not, do a targeted follow-up.

### Doing Follow-Up Searches for Every Facet

**Wrong:**
```
Query has 4 facets → results cover 3 of them → do 4 separate follow-up searches
```

**Problem:** Only the underrepresented facet needs a follow-up. Searching for facets already well-covered wastes API calls.

**Instead:** Only search for genuinely missing coverage. If 3 of 4 facets are covered, search for the one that is missing.

### Presenting Results in Score Order for Multi-Facet Queries

**Wrong:**
```
Results from multiple facets → sort by score → present as flat list
```

**Problem:** Score-ordered presentation mixes facets together. The user cannot easily see which parts of their question are covered and which are not.

**Instead:** Group results by facet when the query has multiple distinct sub-topics. This makes coverage visible.
