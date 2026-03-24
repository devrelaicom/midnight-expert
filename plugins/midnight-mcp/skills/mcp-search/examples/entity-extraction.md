# Entity Extraction / Normalization Examples

## When to Apply

Always, as a pre-processing step before query construction.

## Examples

### Normalizing Type Name Casing

**Before:**
```
User query: "how do I use the merkletree in compact"
Detected entities: "merkletree" (type, wrong case), "compact" (language, wrong case)
```

**After:**
```
Normalized: "MerkleTree" (correct casing), "Compact" (correct casing)
Search query: "MerkleTree usage Compact"
```

**Why:** The MCP search index contains `MerkleTree` with exact casing. Searching for `merkletree` may miss results due to case-sensitive indexing or reduced relevance scoring.

### Extracting Package Names

**Before:**
```
User query: "check my @midnight-ntwrk/midnight-js-contracts types"
Detected entities: "@midnight-ntwrk/midnight-js-contracts" (package name), "types" (concept)
```

**After:**
```
Search query: "@midnight-ntwrk/midnight-js-contracts type definitions"
Route to: midnight-search-typescript (TypeScript package)
```

**Why:** The package name is a precise entity that should be preserved exactly. It also signals that this is a TypeScript/SDK question, informing tool routing.

### Normalizing Counter Overflow Query

**Before:**
```
User query: "counter overflow in my token contract"
Detected entities: "counter" (type, wrong case), "token" (domain), "contract" (construct), "overflow" (concept)
```

**After:**
```
Normalized: "Counter" (correct casing)
Search query: "Counter overflow token contract limits"
```

**Why:** `Counter` is a specific Compact standard library type. Normalizing the casing ensures the search matches indexed content that uses the canonical form.

### Extracting Tool and Component Names

**Before:**
```
User query: "deploy to testnet with lace"
Detected entities: "testnet" (network), "lace" (wallet, wrong case), "deploy" (action)
```

**After:**
```
Normalized: "testnet" (correct), "Lace" (correct casing for Lace wallet)
Search query: "deploy testnet Lace wallet provider"
```

**Why:** "Lace" is the proper name of the wallet. Normalizing casing and adding the entity type ("wallet") clarifies the search intent and improves result relevance.

## Anti-Patterns

### Normalizing Terms That Are Already Correct

**Wrong:**
```
"DApp" → "decentralized application"
"DUST" → "Digital Utility Settlement Token"
```

**Problem:** DApp and DUST are the standard forms used throughout Midnight documentation and code. Expanding them introduces terms that rarely appear in the index and reduces recall.

**Instead:** Keep DApp, DUST, and tDUST as-is. They are not abbreviations — they are the canonical names.

### Extracting Generic Programming Terms as Midnight Entities

**Wrong:**
```
User query: "how to define a function in Compact"
Extracted entities: "function" (construct), "define" (action)
```

**Problem:** "function" and "define" are generic programming terms, not Midnight-specific entities. In Compact, the relevant construct is `circuit` or `witness`, not "function."

**Instead:** Map generic terms to their Midnight equivalents: "function" likely means `circuit` or `witness` in Compact context.

### Missing Midnight Entities That Look Like Common Words

**Wrong:**
```
User query: "how does the witness work in my circuit"
Extracted entities: (none — "witness" and "circuit" look like common English words)
```

**Problem:** In Midnight/Compact context, `witness` and `circuit` are specific language constructs with precise meanings. Missing them means the query loses its most important terms.

**Instead:** Maintain a recognition list of Midnight terms that overlap with common words: `witness`, `circuit`, `ledger`, `export`, `field`, `pad`, `merge`.
