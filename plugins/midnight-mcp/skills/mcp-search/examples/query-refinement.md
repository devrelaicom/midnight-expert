# Query Refinement Examples

## When to Apply

When results are too broad (many results, none specific enough) or too narrow (few or no results).

## Examples

### Too Broad — Narrowing State Management

**Before:**
```
Query: "state management"
→ 50+ results about everything: Counter, Map, ledger, configuration, SDK state
None specific enough to answer the actual question about Counter state patterns
```

**After:**
```
Refined query: "Counter Map ledger state Compact circuit"
→ 8 focused results about Compact state types and patterns
```

**Why:** "State management" is too generic. Adding Compact-specific type names (`Counter`, `Map`) and constructs (`ledger`, `circuit`) narrows results to the relevant domain.

### Too Narrow — Broadening MerkleTree Query

**Before:**
```
Query: "MerkleTree<Bytes<32>, 16> insert"
→ 0 results — the exact generic parameters are too specific
```

**After:**
```
Refined query: "MerkleTree insert member"
→ 6 results showing MerkleTree insertion patterns with various type parameters
```

**Why:** The exact generic signature `MerkleTree<Bytes<32>, 16>` is too specific for the search index. Removing the type parameters while keeping the operation names matches more broadly.

### Wrong Tool — Switching from Compact to TypeScript

**Before:**
```
Query: "Provider setup configuration" on midnight-search-compact
→ Results about Compact code, none about TypeScript Provider setup
```

**After:**
```
Switch tool: midnight-search-typescript
Refined query: "MidnightProvider setup configuration connect"
→ Results showing TypeScript Provider initialization patterns
```

**Why:** The `Provider` and `MidnightProvider` types are TypeScript SDK concepts, not Compact constructs. The wrong tool was selected. Switching to `midnight-search-typescript` and using the correct type name fixes the problem.

### Wrong Results — Rethinking the Approach

**Before:**
```
Query: "privacy" on midnight-search-compact
→ Results about various privacy-related code, none about the user's specific question on disclose behavior
```

**After:**
```
Rethought approach:
Query: "disclose public ledger state visibility" on midnight-search-compact
→ Results specifically about the disclose construct and state visibility
```

**Why:** "Privacy" is too abstract. The user's actual question is about the `disclose` construct. Using the specific construct name and related terms produces targeted results.

## Anti-Patterns

### Adding Random Terms to Narrow a Broad Search

**Wrong:**
```
"state management" → "state management blue fast important"
```

**Problem:** Random adjectives do not narrow the search meaningfully. They may match nothing or match irrelevant content.

**Instead:** Add terms that relate to what was missing from the results. If results were too broad about state, add the specific state type (`Counter`, `Map`) or construct (`ledger`).

### Removing All Specific Terms When Broadening

**Wrong:**
```
"MerkleTree<Bytes<32>, 16> insert" → "data structure"
```

**Problem:** Removing all specific terms broadens the search too far. "Data structure" matches everything and returns no useful results for MerkleTree.

**Instead:** Remove the overly specific parts (generic type parameters) while keeping the core concept: `MerkleTree insert`.

### Refining More Than Twice Without Rethinking

**Wrong:**
```
Round 1: "Counter decrement" → no results
Round 2: "Counter subtract" → no results
Round 3: "Counter minus" → no results
Round 4: "Counter reduce" → no results
```

**Problem:** Four refinement attempts on the same concept suggests the information does not exist in the index with any of these terms. Continuing to try synonyms is unproductive.

**Instead:** After 2 failed refinements, rethink the approach entirely. Try a step-back query (`Counter operations`), switch tools (`midnight-search-docs`), or inform the user that the feature may not exist.
