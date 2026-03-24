# Trusted-Source Filtering Examples

## When to Apply

When result reliability matters more than breadth — production code, security-sensitive patterns, official examples.

## Examples

### Production Token Transfer Pattern

**Before:**
```
User needs: production-ready token transfer pattern
Search: midnight-search-compact query: "token transfer shielded"
→ Results include community forks, experimental code, and official examples
```

**After:**
```
Search: midnight-search-compact
  query: "token transfer shielded"
  filter.repository: "midnightntwrk" (or "OpenZeppelin")
→ Results restricted to official Foundation and audited sources
```

**Why:** For production code, community implementations may contain bugs or use deprecated patterns. Restricting to `midnightntwrk` and `OpenZeppelin` ensures results come from maintained, reviewed sources.

### Broad Exploration Without Filtering

**Before:**
```
User wants: "show me how anyone has implemented voting in Compact"
→ Apply trusted-source filter by default
```

**After:**
```
Search: midnight-search-compact
  query: "voting ballot tally circuit"
  (no filter.repository — broad search)
→ Results include Foundation, community, and experimental implementations
```

**Why:** The user explicitly wants to see diverse implementations. Filtering to trusted-only would miss creative community approaches that may be useful for inspiration.

### TypeScript SDK Trust-Aware Reranking

**Before:**
```
User needs: reliable SDK integration pattern
Search: midnight-search-typescript query: "contract deployment provider"
  filter.repository: "midnightntwrk" ← WRONG: parameter does not exist on this tool
```

**After:**
```
Search: midnight-search-typescript query: "contract deployment provider"
  (no filter parameter — not supported on this tool)
→ After retrieval: apply trust-aware reranking to boost midnightntwrk results
```

**Why:** `midnight-search-typescript` does not support `filter.repository`. Trust filtering for TypeScript results must be done client-side by checking `source.repository` in the response and reranking results from trusted organizations higher.

### Audited Code Request

**Before:**
```
User asks: "find me audited access control code"
Search: midnight-search-compact query: "access control audited"
```

**After:**
```
Search: midnight-search-compact
  query: "access control Ownable owner"
  filter.repository: "OpenZeppelin"
→ Results restricted to OpenZeppelin's audited libraries
```

**Why:** "Audited" is a trust facet, not a search keyword. OpenZeppelin provides audited Compact libraries. Filtering to their repos and using their module names (`Ownable`) directly targets what the user needs.

## Anti-Patterns

### Passing filter.repository to midnight-search-typescript

**Wrong:**
```
midnight-search-typescript with filter.repository: "midnightntwrk"
```

**Problem:** The `filter.repository` parameter does not exist on `midnight-search-typescript`. The call may fail or the parameter will be silently ignored.

**Instead:** For TypeScript results, retrieve without filtering, then apply trust-aware reranking client-side by checking `source.repository` in each result.

### Always Filtering to Trusted-Only

**Wrong:**
```
Every search: filter.repository: "midnightntwrk"
```

**Problem:** This misses useful community examples, creative implementations, and third-party libraries that may be the only source for niche patterns. Some valid patterns appear only in community code.

**Instead:** Use trusted-source filtering when reliability is critical (production code, security). Use broad search when exploring or when the pattern is niche.

### Treating All midnightntwrk Code as Equally Current

**Wrong:**
```
Result from midnightntwrk/old-examples-repo → trust it fully
```

**Problem:** Not all `midnightntwrk` repositories are actively maintained. Some contain outdated examples from earlier SDK or language versions. The trust hierarchy ranks source quality, not currency.

**Instead:** Apply trust ranking for source quality, then apply freshness reranking for currency. A trusted but outdated result may need verification against current versions.
