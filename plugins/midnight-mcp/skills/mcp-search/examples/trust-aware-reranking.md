# Trust-Aware Reranking Examples

## When to Apply

When result reliability matters — production code, security-sensitive patterns, or when results come from mixed sources.

## Examples

### Preferring Official Token Transfer Implementation

**Before:**
```
Results:
  1. Token transfer from community/midnight-demo (score: 0.73)
  2. Token transfer from midnightntwrk/examples (score: 0.68)
→ Presented in score order
```

**After:**
```
Reranked by trust:
  1. Token transfer from midnightntwrk/examples — official Foundation code
  2. Token transfer from community/midnight-demo — community implementation (note: verify independently)
```

**Why:** The `midnightntwrk` version is maintained by the Midnight Foundation. Despite the slightly lower relevance score, it is the more reliable source for production use.

### Preferring Audited Access Control

**Before:**
```
Results:
  1. Custom access control from user/my-compact-project (score: 0.65)
  2. Ownable module from OpenZeppelin/compact-contracts (score: 0.60)
→ Presented in score order
```

**After:**
```
Reranked by trust:
  1. Ownable module from OpenZeppelin/compact-contracts — audited library
  2. Custom access control from user/my-compact-project — unaudited (note: may contain security issues)
```

**Why:** OpenZeppelin's `Ownable` module is professionally audited. The community implementation may work but has not been reviewed for security vulnerabilities.

### TypeScript Results with Mixed Sources

**Before:**
```
midnight-search-typescript results (no server-side filter):
  1. Provider setup from community/midnight-starter (score: 0.71)
  2. Provider setup from midnightntwrk/midnight-js (score: 0.66)
  3. Provider wrapper from user/my-dapp (score: 0.58)
```

**After:**
```
Reranked by trust:
  1. Provider setup from midnightntwrk/midnight-js — official SDK code
  2. Provider setup from community/midnight-starter — community, check against official
  3. Provider wrapper from user/my-dapp — personal project, lowest trust
```

**Why:** `midnight-search-typescript` has no server-side `filter.repository`. Client-side trust-aware reranking is the only way to prioritize official sources in TypeScript search results.

## Anti-Patterns

### Rejecting All Community Code

**Wrong:**
```
Source is not midnightntwrk, OpenZeppelin, or LFDT-Minokawa → discard
```

**Problem:** Community code may be the only available implementation of a niche pattern. Rejecting it entirely means returning no results when the user needs something that official repos do not cover.

**Instead:** Rank community code lower, but include it with a note about verification. Some patterns only exist in community projects.

### Trusting All midnightntwrk Code Equally

**Wrong:**
```
Source is midnightntwrk → fully trust, no further checks
```

**Problem:** The `midnightntwrk` organization has many repositories. Some contain outdated examples from earlier SDK versions, experimental code, or deprecated patterns. Trust the organization but verify currency.

**Instead:** Apply trust ranking for source quality, then check recency. An official but outdated example from SDK v1 should not be presented as current guidance for SDK v2.

### Applying Trust Reranking When Broad Results Are Requested

**Wrong:**
```
User asks: "show me all the different voting implementations out there"
→ Filter to trusted sources only
```

**Problem:** The user explicitly wants breadth and diversity. Applying trust filtering contradicts their request and limits the result set unnecessarily.

**Instead:** When the user asks for broad or diverse results, present all sources with trust labels rather than filtering.
