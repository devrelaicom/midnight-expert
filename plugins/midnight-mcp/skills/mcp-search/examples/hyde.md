# HyDE (Pseudo-Answer Generation) Examples

## When to Apply

When the query is conceptual and hard to reduce to keywords, or when you know roughly what the answer should look like but need to find real examples.

## Examples

### Finding Access-Gated Circuit Patterns

**Before:**
```
User query: "how to gate access to a circuit"
→ Hard to reduce to keywords without losing intent
```

**After:**
```
Hypothetical Compact snippet (not shown to user):
  witness authorized(value: Field): Boolean;
  circuit guarded(value: Field): [] {
    assert authorized(value);
    // ... protected logic
  }

Extracted search terms: "witness authorization circuit access guard assert"
```

**Why:** The hypothetical snippet contains distinctive Compact constructs (`witness`, `circuit`, `assert`) that are likely to appear in real access-control implementations. These terms produce better results than the vague original query.

### Finding a Voting Contract Structure

**Before:**
```
User query: "what does a basic voting contract look like"
→ Too vague for keyword search
```

**After:**
```
Hypothetical structure (not shown to user):
  ledger {
    votes: Map<Bytes<32>, Counter>;
    totalVotes: Counter;
  }
  export circuit cast_vote(candidate: Bytes<32>): [] {
    votes.lookup(candidate).increment(1);
    totalVotes.increment(1);
  }

Extracted search terms: "voting contract ledger Counter tally circuit Map cast vote"
```

**Why:** The hypothetical reveals the likely data types (`Map`, `Counter`), constructs (`ledger`, `export circuit`), and action names (`cast_vote`, `tally`) that real voting contracts would use.

### Finding Private Data Storage Patterns

**Before:**
```
User query: "how to store private data on Midnight"
→ "Private data" is conceptual, not a searchable term
```

**After:**
```
Hypothetical pattern (not shown to user):
  witness get_private_value(): Field;
  ledger {
    commitment: Bytes<32>;
  }
  circuit store(value: Field): [] {
    commitment = persistentCommit(pad(value));
  }

Extracted search terms: "local state witness private data off-chain persistentCommit commitment"
```

**Why:** The hypothetical reveals that private data storage in Compact likely involves `witness` for off-chain data, `persistentCommit` for on-chain commitments, and the distinction between `local` and `ledger` state.

## Anti-Patterns

### Presenting the Hypothetical as Real

**Wrong:**
```
"Based on my analysis, here's how to gate access to a circuit:
  witness authorized(value: Field): Boolean;
  ..."
```

**Problem:** The hypothetical is a search aid, not a verified answer. It may contain hallucinated API names, incorrect syntax, or wrong patterns. Presenting it as real misleads the user.

**Instead:** Use the hypothetical only to extract search terms. Present only verified results from the actual search.

### Using HyDE for Simple Keyword Lookups

**Wrong:**
```
User asks: "Counter increment example"
→ Generate a hypothetical Counter increment snippet
→ Extract terms from it
```

**Problem:** "Counter increment example" is already a perfectly good search query. HyDE adds unnecessary complexity and latency for queries that are already keyword-rich.

**Instead:** Use HyDE only when the query is conceptual and hard to reduce to keywords directly.

### Searching for Hallucinated API Names

**Wrong:**
```
Hypothetical includes: MerkleTree.verifyProof(root, leaf, proof)
→ Search for "MerkleTree verifyProof"
```

**Problem:** `verifyProof` may not be the actual function name in Compact's standard library. Searching for hallucinated names produces zero results. The real function could be `member` or `verify`.

**Instead:** Extract general structural terms (`MerkleTree proof verify member`) rather than specific method names from the hypothetical.
