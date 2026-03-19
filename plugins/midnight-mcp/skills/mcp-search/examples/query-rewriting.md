# Query Rewriting Examples

## When to Apply

Always, as a first pass before calling any MCP search tool.

## Examples

### Finding a Token Minting Pattern

**Before:**
```
how do I make a token that only the owner can mint
```

**After:**
```
mint access control owner witness shielded token
```

**Why:** Stripped filler words ("how do I make"), replaced natural language with Compact-specific terms (`witness`, `shielded`), and added the construct name (`access control`).

### Searching for Zero Knowledge Proof Costs

**Before:**
```
ZKP costs for merkle proofs
```

**After:**
```
Zero Knowledge Proof (ZKP) circuit cost MerkleTree
```

**Why:** Expanded "ZKP" (genuinely written both ways in docs) and normalized `merkle proofs` to the Compact type name `MerkleTree`.

### Looking Up Compact State Management

**Before:**
```
what is the best way to handle state in Compact
```

**After:**
```
Compact ledger state management Counter Map Set
```

**Why:** Stripped filler ("what is the best way to"), added specific state types (`Counter`, `Map`, `Set`) and the core construct (`ledger`).

### Fixing Typos and Terminology

**Before:**
```
midnite compact smart contract deploy
```

**After:**
```
Midnight Compact contract deployment
```

**Why:** Fixed the typo "midnite" to "Midnight" and normalized to standard terminology.

## Anti-Patterns

### Expanding Terms That Are Already Standard

**Wrong:**
```
"DApp" → "decentralized application"
"DUST" → "Digital Utility Settlement Token"
"tDUST" → "test Digital Utility Settlement Token"
```

**Problem:** DUST, tDUST, and DApp are standard forms in Midnight documentation and code. Expanding them produces terms that do not appear in the index, reducing search recall.

**Instead:** Keep DUST, tDUST, and DApp as-is. Only expand shorthand that genuinely appears in both forms (e.g., ZKP).

### Passing Raw Natural Language to MCP Tools

**Wrong:**
```
midnight-search-compact query: "how do I create a contract that stores a list of approved addresses?"
```

**Problem:** Natural language queries produce poor results against code indexes. The search engine matches keywords, not intent.

**Instead:** Extract the key concepts and rewrite: `approved addresses access control list Set Map ledger`

### Over-Expanding Into Generic Terms

**Wrong:**
```
"token transfer" → "cryptocurrency digital asset movement blockchain transaction"
```

**Problem:** Generic programming and blockchain terms dilute the query. The MCP index contains Midnight-specific content — generic terms match too broadly or not at all.

**Instead:** Use Midnight-specific terms: `token transfer shielded circuit DUST`
