# Symbol-Aware Search Examples

## When to Apply

When the query targets a specific named symbol — a type, function, module, circuit, or constructor.

## Examples

### Detecting MerkleTree from Natural Language

**Before:**
```
User asks: "how to use merkle trees"
Search: "merkle trees usage"
→ Poor results — index uses "MerkleTree" not "merkle trees"
```

**After:**
```
Detected symbol: MerkleTree (Compact standard library type)
Search: "MerkleTree insert member proof"
→ Results with exact MerkleTree API usage
```

**Why:** The search index contains the exact symbol name `MerkleTree`. Using the normalized form matches indexed content directly.

### Detecting Standard Library Functions

**Before:**
```
User asks: "what's the hash function in Compact"
Search: "hash function Compact"
→ Broad results about hashing concepts
```

**After:**
```
Detected symbols: persistentHash, persistentCommit (Compact stdlib functions)
Search: "persistentHash persistentCommit usage"
→ Results showing actual stdlib hash function usage
```

**Why:** Compact has specific named hash functions (`persistentHash`, `persistentCommit`). Using the exact function names targets real implementations instead of generic hashing discussions.

### Detecting TypeScript SDK Symbol

**Before:**
```
User asks: "how to check contract address"
Search: "check contract address"
→ Mixed results about addresses generally
```

**After:**
```
Detected symbol: ContractAddress (TypeScript SDK type)
Route to: midnight-search-typescript
Search: "ContractAddress type deployed contract"
→ Results showing ContractAddress TypeScript type usage
```

**Why:** `ContractAddress` is a specific TypeScript SDK type. Using the exact type name and routing to the TypeScript search tool produces focused results.

### Detecting Optional Type

**Before:**
```
User mentions: "the optional type in Compact"
Search: "optional type Compact"
→ Results about optional parameters generally
```

**After:**
```
Detected symbol: Optional (Compact standard library type)
Search: "Optional value unwrap Compact type"
→ Results showing Optional type usage with unwrap patterns
```

**Why:** `Optional` is a specific Compact type with methods like unwrap. Using the exact type name distinguishes it from the generic concept of "optional."

## Anti-Patterns

### Paraphrasing Symbol Names

**Wrong:**
```
User asks about MerkleTree
Search: "tree data structure hash verification"
```

**Problem:** Paraphrasing `MerkleTree` as "tree data structure" loses the specific symbol name. The index contains `MerkleTree`, not "tree data structure." Paraphrased terms match too broadly.

**Instead:** Use exact symbol names: `MerkleTree`, `Counter`, `persistentHash`. These are the terms that appear in indexed code.

### Searching for a Symbol Without Context

**Wrong:**
```
Search: "Map"
→ Matches everything — too generic
```

**Problem:** `Map` is both a Compact type and a common programming term. Without context, the search returns results from many unrelated domains.

**Instead:** Add context: `Map Compact ledger state key value` to narrow to Compact-specific Map usage.

### Assuming a Symbol Exists Without Verification

**Wrong:**
```
User asks: "how to use MerkleTree.verifyProof()"
Search: "MerkleTree verifyProof"
→ No results — function name may not exist
```

**Problem:** The user may have assumed a function name that does not exist in Compact's standard library. Searching for a non-existent name wastes a call.

**Instead:** Cross-reference with `compact-core:compact-standard-library` to verify the function exists. The actual function may be `member` rather than `verifyProof`.
