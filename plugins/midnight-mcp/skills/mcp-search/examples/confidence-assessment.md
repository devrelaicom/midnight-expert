# Confidence Assessment Examples

## When to Apply

After every search, before presenting results to the user.

## Examples

### High Confidence — Multiple Trusted Sources Agree

**Before:**
```
Query: "Counter increment ledger"
Results:
  1. Counter increment example from midnightntwrk/examples (score: 0.75)
  2. Counter usage in midnightntwrk/midnight-examples (score: 0.71)
  3. Counter documentation from midnight-search-docs (score: 0.68)
All three show the same pattern, consistent information
```

**After:**
```
Assessment: HIGH confidence
→ 3 results from trusted sources agree
→ Pattern is consistent across code and documentation
→ Present results directly without caveats
```

**Why:** Multiple trusted sources showing the same pattern is strong evidence. No follow-up search needed.

### Medium Confidence — Partial Answer from Lower-Trust Source

**Before:**
```
Query: "recursive proof composition"
Results:
  1. Community blog post about proof composition (score: 0.45)
  2. A test file mentioning "compose" in a proof context (score: 0.38)
No official documentation or Foundation code found
```

**After:**
```
Assessment: MEDIUM confidence
→ Relevant results exist but from lower-trust sources
→ No official documentation confirms the pattern
→ Present results with note: "This pattern appears in community code but is not documented in official sources. Verify with compilation before relying on it."
→ Consider follow-up search on midnight-search-docs
```

**Why:** Community sources may be correct but lack the authority of official documentation. The user should be aware that this is not officially documented.

### Low Confidence — No Relevant Results

**Before:**
```
Query: "recursive circuit composition Compact"
Results:
  1. Generic "composition" mention in an architecture doc (score: 0.22)
  2. Unrelated circuit example (score: 0.18)
Neither addresses recursive composition
```

**After:**
```
Assessment: LOW confidence
→ No results address the specific question
→ Do not present these results as answers
→ Inform user: "No results found for recursive circuit composition in the search index. This feature may not exist in the current Compact version, or it may not be indexed. Try checking the Compact language reference directly or asking in the Midnight community channels."
```

**Why:** Presenting irrelevant results as answers is worse than admitting the information was not found. Low confidence triggers either a follow-up search or an honest "not found" response.

## Anti-Patterns

### Presenting Low-Confidence Results as Definitive

**Wrong:**
```
Single community result with score 0.35 → present as "here's how to do it"
```

**Problem:** A single low-scoring result from an untrusted source is not a reliable answer. Presenting it as definitive may lead the user to implement an incorrect or outdated pattern.

**Instead:** Flag the uncertainty. Present the result as "one possible approach found in community code" and recommend verification.

### Always Flagging Uncertainty

**Wrong:**
```
3 high-quality results from midnightntwrk → "these results may not be accurate, please verify"
```

**Problem:** Unnecessary caveats on high-confidence results undermine trust. When multiple official sources agree, the answer is reliable.

**Instead:** Reserve uncertainty flags for medium and low confidence results. High confidence results from trusted sources do not need caveats.

### Conflating Search Confidence with Result Trustworthiness

**Wrong:**
```
High confidence search results from untrusted source → present without caveats
```

**Problem:** Search confidence (did we find relevant results?) and result trustworthiness (is the source reliable?) are different concerns. A confident search can return results from unreliable sources.

**Instead:** Assess confidence (did we find what we were looking for?) and trust (are the sources reliable?) separately. Both must be adequate before presenting results without caveats.
