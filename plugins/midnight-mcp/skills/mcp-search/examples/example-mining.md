# Example Mining Examples

## When to Apply

When the user needs runnable, complete code examples rather than documentation or partial snippets.

## Examples

### Complete Token Contract

**Before:**
```
User needs: "a complete token contract"
Search: "token contract" on midnight-search-compact
→ Returns fragments: a single transfer function, an import statement, a type definition
```

**After:**
```
Search: "token contract example ledger circuit export" on midnight-search-compact
  filter.repository: "midnightntwrk" (trusted sources for examples)
→ Returns complete contract implementations from official example repos
Also check: midnight-list-examples for curated token contract examples
```

**Why:** Adding "example" and structural terms (`ledger`, `circuit`, `export`) biases results toward complete implementations. Filtering to trusted sources targets official example repositories which contain runnable code.

### TypeScript Wallet Connection

**Before:**
```
User needs: "how to connect a wallet in TypeScript"
Search: "wallet connect" on midnight-search-typescript
→ Returns type definitions and partial snippets
```

**After:**
```
Search: "wallet provider connect example implementation" on midnight-search-typescript
  includeExamples: true
→ Returns complete wallet connection implementations
```

**Why:** Setting `includeExamples: true` ensures example code is included in results. Adding "example" and "implementation" biases toward complete code rather than type definitions.

### Voting Contract Example

**Before:**
```
User needs: "a voting contract example"
Search: "voting contract" on midnight-search-compact
→ Returns 2 partial results
```

**After:**
```
Step 1: Check midnight-list-examples for curated voting examples
→ Lists available example contracts with complexity ratings

Step 2: midnight-search-compact query: "voting ballot tally circuit example Counter"
  filter.repository: "midnightntwrk"
→ Returns voting contract implementations from example repos
```

**Why:** `midnight-list-examples` provides a curated catalog of example contracts. Checking it first may directly point to a voting example. The search step uses voting-specific terms and structural keywords.

## Anti-Patterns

### Returning Documentation Snippets for Code Requests

**Wrong:**
```
User asks: "show me a token contract"
→ Return a documentation paragraph explaining what token contracts are
```

**Problem:** The user asked for code, not an explanation. Documentation snippets do not provide runnable examples.

**Instead:** Route to `midnight-search-compact` with example-mining terms. If compact search does not return complete examples, try `midnight-list-examples`.

### Returning Partial Implementations

**Wrong:**
```
User asks: "show me a complete voting contract"
→ Return a single circuit function without the ledger declaration or exports
```

**Problem:** A single function is not a complete contract. The user needs the full structure: pragma, imports, ledger, circuits, exports.

**Instead:** Prefer results that include complete file content. Check for structural markers: `pragma language_version`, `ledger {`, `export circuit`, which indicate a complete contract.

### Not Checking midnight-list-examples

**Wrong:**
```
User asks for example code
→ Go directly to midnight-search-compact without checking the curated example list
```

**Problem:** `midnight-list-examples` provides a curated catalog of example contracts with complexity ratings and descriptions. It may directly point to exactly what the user needs, saving a search step.

**Instead:** Check `midnight-list-examples` first for curated examples. Use search as a complement or when the curated list does not cover the specific pattern.
