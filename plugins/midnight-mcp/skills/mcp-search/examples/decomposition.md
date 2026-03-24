# Decomposition Examples

## When to Apply

When the question involves multiple independent concerns that should be searched separately.

## Examples

### Shielded Voting Contract with Token Gating

**Before:**
```
Single query: "shielded voting contract with token gating"
→ Too many concepts for one search — results are diluted
```

**After:**
```
Sub-query 1: "voting contract Compact tally circuit Counter"
Sub-query 2: "shielded token privacy ledger witness"
Sub-query 3: "token gating access control holder balance"
```

**Why:** The original question has three independent concerns: voting mechanics, privacy/shielding, and token-based access control. Each sub-query targets one concern with specific Midnight terminology, producing focused results.

### DApp Migration from Testnet to Mainnet

**Before:**
```
Single query: "migrate DApp from testnet to mainnet with new SDK version"
→ Mixes network config, SDK changes, and deployment
```

**After:**
```
Sub-query 1: "testnet mainnet network configuration endpoint"
Sub-query 2: "SDK version migration breaking changes upgrade"
Sub-query 3: "DApp deployment provider endpoint configuration"
```

**Why:** Network migration, SDK version changes, and deployment configuration are independent topics documented in different places. Searching each separately retrieves the relevant guidance without cross-contamination.

### MerkleTree Membership with Rate Limiting

**Before:**
```
Single query: "MerkleTree-based membership proofs and Counter-based rate limiting"
→ Two distinct patterns in one query
```

**After:**
```
Sub-query 1: "MerkleTree membership proof inclusion verify"
Sub-query 2: "Counter rate limiting increment circuit threshold"
```

**Why:** MerkleTree membership proofs and Counter-based rate limiting are completely independent patterns. A single query splits the search engine's attention between them. Two focused queries each return the best results for their pattern.

### End-to-End Contract Deployment

**Before:**
```
Single query: "write a Compact contract and deploy it from TypeScript with wallet integration"
→ Spans three different codebases
```

**After:**
```
Sub-query 1 (midnight-search-compact): "contract ledger circuit export example"
Sub-query 2 (midnight-search-typescript): "deploy contract provider TypeScript"
Sub-query 3 (midnight-search-typescript): "wallet provider Lace connect integration"
```

**Why:** This question spans Compact (contract writing), TypeScript SDK (deployment), and wallet integration. Each sub-query targets the right tool and terminology.

## Anti-Patterns

### Decomposing Simple Questions

**Wrong:**
```
User asks: "how to use Counter"
Sub-query 1: "Counter type definition"
Sub-query 2: "Counter increment"
Sub-query 3: "Counter in ledger"
```

**Problem:** "Counter" is a simple topic that a single well-formed query handles well. Decomposing it wastes three tool calls for results that one query would cover.

**Instead:** Use a single query: `Counter type usage increment ledger Compact`.

### Creating Overlapping Sub-Queries

**Wrong:**
```
Sub-query 1: "shielded token transfer privacy"
Sub-query 2: "private token send shielded"
Sub-query 3: "token privacy transfer mechanism"
```

**Problem:** These sub-queries all target the same concept with minor variations. This is multi-query, not decomposition. Decomposition splits different concerns, not synonyms.

**Instead:** Use multi-query for synonym coverage of a single concept. Use decomposition when the question has genuinely distinct sub-topics.

### Too Many Sub-Queries

**Wrong:**
```
Decompose into 6 sub-queries, each targeting a minor aspect.
```

**Problem:** Each sub-query costs a tool call. Beyond 3-4 sub-queries, the overhead exceeds the benefit. Later sub-queries often target trivially small aspects that are covered by earlier results.

**Instead:** Limit to 3-4 sub-queries. Combine closely related aspects into a single sub-query.
