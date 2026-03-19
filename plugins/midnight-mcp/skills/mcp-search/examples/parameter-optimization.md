# Parameter Optimization Examples

## When to Apply

After tool selection, before making the call. Configure tool-specific parameters to improve result quality.

## Examples

### Looking Up a Single Type Definition

**Before:**
```
midnight-search-typescript
  query: "ContractAddress"
  (default parameters)
```

**After:**
```
midnight-search-typescript
  query: "ContractAddress type definition"
  includeTypes: true
  includeExamples: false
  limit: 5
```

**Why:** The user wants a type definition, not usage examples. Setting `includeTypes: true` ensures type declaration files are searched. Setting `includeExamples: false` reduces noise from example code. A limit of 5 is sufficient for a single type lookup.

### Broad Exploration of Token Patterns

**Before:**
```
midnight-search-compact
  query: "token pattern"
  (default limit: 10)
```

**After:**
```
midnight-search-compact
  query: "token pattern shielded transfer mint"
  limit: 20
```

**Why:** Broad exploration benefits from more results. The default limit of 10 may miss valuable patterns beyond the first page. Increasing to 20 provides better coverage of different token implementations across repositories.

### Finding a Deployment Tutorial

**Before:**
```
midnight-search-docs
  query: "deploy contract"
  (no category filter)
```

**After:**
```
midnight-search-docs
  query: "deploy contract tutorial setup"
  category: "guides"
  limit: 10
```

**Why:** Setting `category: "guides"` filters to tutorials and how-to content, excluding API reference pages and conceptual overviews that mention deployment in passing.

### Extracting a Specific Section from a Doc Page

**Before:**
```
midnight-fetch-docs
  path: "/compact/standard-library"
  (returns entire page — may be very long)
```

**After:**
```
midnight-fetch-docs
  path: "/compact/standard-library"
  extractSection: "Functions"
```

**Why:** The standard library reference page is long. Using `extractSection` returns only the "Functions" heading and its content, reducing token consumption while getting exactly the information needed.

## Anti-Patterns

### Using Default Parameters for Every Search

**Wrong:**
```
Every call: midnight-search-compact query: "..." (no other parameters)
```

**Problem:** Default parameters are a compromise. Specific tasks benefit from tailored parameters — higher limits for exploration, type filters for API lookups, category filters for docs.

**Instead:** Set parameters based on the task: adjust `limit`, set `category` for docs, set `includeTypes`/`includeExamples` for TypeScript.

### Setting Excessively High Limits

**Wrong:**
```
midnight-search-compact query: "Counter" limit: 50
```

**Problem:** Most useful results are in the first 10-15. Results beyond 20 are almost always irrelevant or duplicative. High limits waste tokens processing low-quality results.

**Instead:** Use `limit: 10` for targeted lookups, `limit: 15-20` for broad exploration. Never exceed 20.

### Setting category on midnight-search-compact

**Wrong:**
```
midnight-search-compact query: "Counter" category: "guides"
```

**Problem:** The `category` parameter only exists on `midnight-search-docs`. Passing it to `midnight-search-compact` has no effect or may cause an error.

**Instead:** Check which parameters belong to which tool. `category` is for docs, `filter.repository` is for compact, `includeTypes` is for TypeScript.
