# Freshness Reranking Examples

## When to Apply

When the query is time-sensitive — version-specific questions, migration guidance, recent changes, or when the user says "latest" or "current."

## Examples

### Latest Ledger Declaration Syntax

**Before:**
```
User asks: "what's the latest syntax for declaring a ledger"
Results:
  1. Ledger example from 2024 (v0.1 syntax)
  2. Ledger example from 2025 (v0.2 syntax)
  3. Ledger documentation (current)
→ Presented in relevance score order
```

**After:**
```
Reranked by freshness:
  1. Ledger documentation (current) — most recent
  2. Ledger example from 2025 (v0.2 syntax) — recent
  3. Ledger example from 2024 (v0.1 syntax) — note: may use outdated syntax
```

**Why:** The user explicitly asked for "latest" — freshness is a primary signal. Older examples may show deprecated syntax.

### Proven Token Standard (Freshness Less Important)

**Before:**
```
User asks: "how does the proven token standard work"
Results:
  1. Experimental token implementation (last month)
  2. Audited token standard from OpenZeppelin (6 months ago)
  3. Token concept documentation (3 months ago)
```

**After:**
```
Reranked (trust over freshness):
  1. Audited token standard from OpenZeppelin — audited, proven correct
  2. Token concept documentation — official explanation
  3. Experimental token implementation — newer but unaudited
```

**Why:** For a "proven" standard, correctness matters more than recency. The 6-month-old audited code is more reliable than last month's experiment. Freshness should not override trust for correctness-critical queries.

### SDK Migration Between Versions

**Before:**
```
User asks: "what changed between SDK v1 and v2"
Results:
  1. SDK v1 setup guide (old)
  2. SDK v2 migration guide (recent)
  3. SDK v1 API reference (old)
```

**After:**
```
Reranked by version relevance:
  1. SDK v2 migration guide — directly addresses the migration
  2. SDK v1 API reference — useful for comparison (the "from")
  3. SDK v1 setup guide — less relevant to migration
```

**Why:** Migration questions need results from both versions. The migration guide is most valuable. The v1 reference provides the "before" state. The v1 setup guide is tangential.

## Anti-Patterns

### Always Preferring the Newest Result

**Wrong:**
```
Sort all results by date, newest first, regardless of content quality
```

**Problem:** The newest result may be an unfinished experiment, a broken fork, or an incomplete example. Older audited code is often more correct and reliable.

**Instead:** Use freshness as a tiebreaker between equally relevant and trusted results, not as the primary ranking signal.

### Ignoring Freshness for Version-Sensitive Questions

**Wrong:**
```
User asks about "current Compact syntax"
→ Present results from all versions equally, regardless of date
```

**Problem:** Compact syntax changes between versions. Presenting old syntax as equally valid to current syntax misleads the user.

**Instead:** When the query is version-sensitive, boost recent results. Note when older results may show deprecated patterns.

### Treating Freshness as a Primary Signal

**Wrong:**
```
Fresh community code (last week) ranked above audited official code (3 months ago)
```

**Problem:** Freshness is a secondary signal. A week-old community contribution does not outrank a three-month-old official audited implementation.

**Instead:** Apply freshness within trust tiers. Among trusted sources, prefer fresher content. Among community sources, prefer fresher content. But do not promote untrusted fresh content above trusted older content.
