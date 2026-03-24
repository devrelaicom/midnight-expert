# Deduplication Examples

## When to Apply

When results contain near-identical content from the same or forked repos. Common when searching broad topics.

## Examples

### Fork-Induced Duplication

**Before:**
```
Results:
  1. Token contract from midnightntwrk/examples (score: 0.72)
  2. Same token contract from user/midnight-token-demo (score: 0.68) — forked repo
  3. Same token contract from another-user/my-midnight-fork (score: 0.61) — another fork
```

**After:**
```
Deduplicated:
  1. Token contract from midnightntwrk/examples — authoritative source
  Note: same contract also found in 2 community forks
```

**Why:** The forked copies are identical to the original. Showing all three wastes result slots and confuses the user. Keep the authoritative source, note the forks exist.

### Same Content in Multiple Locations

**Before:**
```
Results:
  1. Counter usage in README.md of midnightntwrk/examples (score: 0.65)
  2. Counter usage in src/counter.compact (score: 0.63) — same code, the source file
  3. Counter usage in test/counter.test.ts (score: 0.55) — same code imported in test
```

**After:**
```
Deduplicated:
  1. Counter usage in src/counter.compact — the source implementation
  Note: same code referenced in README and test files
```

**Why:** The source file is the authoritative version. The README quotes it and the test imports it. Keeping the source file provides the most useful, complete version.

### Genuinely Different Implementations

**Before:**
```
Results:
  1. Token transfer using direct ledger update (midnightntwrk/examples)
  2. Token transfer using witness-based authorization (OpenZeppelin/compact-contracts)
  3. Token transfer with privacy-preserving amounts (midnightntwrk/midnight-examples)
```

**After:**
```
Keep all three — these are distinct approaches:
  1. Direct ledger update — simplest pattern
  2. Witness-based authorization — access-controlled pattern
  3. Privacy-preserving amounts — shielded pattern
```

**Why:** These are three genuinely different implementations of token transfer, each using a different approach. They are not duplicates — they represent distinct patterns the user should see.

## Anti-Patterns

### Deduplicating Different Approaches

**Wrong:**
```
Two results both about "token transfer" → deduplicate to one
```

**Problem:** Two results about the same topic may use completely different approaches. Deduplicating them hides valuable alternatives from the user.

**Instead:** Compare the actual content, not just the topic label. Deduplicate only when the code or text is substantially identical.

### Keeping the Higher-Scored Duplicate Instead of the More Trusted One

**Wrong:**
```
community/fork has score 0.73, midnightntwrk/original has score 0.68
→ Keep the community fork because it scored higher
```

**Problem:** The higher score is likely a coincidence of indexing order or chunk size. The `midnightntwrk` version is the authoritative source that the fork copied.

**Instead:** When deduplicating, keep the version from the most trusted source regardless of score.

### Not Deduplicating at All

**Wrong:**
```
Present 5 copies of the same Counter example from 5 different forks
```

**Problem:** The user sees the same code repeated 5 times, wasting their attention and making it seem like the search returned nothing diverse.

**Instead:** Always check for near-identical results, especially from forked repositories. Collapse duplicates and note their existence.
