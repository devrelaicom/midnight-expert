# Retrieve-Read-Retrieve Examples

## When to Apply

When initial results partially answer the question but leave gaps, or when reading results reveals a dimension that the original query missed.

## Examples

### Token Transfer Missing Witness Implementation

**Before:**
```
First search: "token transfer" on midnight-search-compact
→ Returns the transfer circuit but not the witness implementation
Gap: how the off-chain witness authorizes the transfer is not shown
```

**After:**
```
Follow-up search: "token transfer witness TypeScript authorization" on midnight-search-typescript
→ Returns the TypeScript-side witness implementation that pairs with the circuit
Combined: circuit (from first search) + witness (from follow-up) = complete pattern
```

**Why:** Reading the initial results revealed that the circuit calls a witness function, but the witness implementation lives in TypeScript. The follow-up targets that specific gap.

### MerkleTree Usage Missing Capacity Limits

**Before:**
```
First search: "MerkleTree usage example" on midnight-search-compact
→ Returns insertion and membership check examples
Gap: no information about depth limits or maximum capacity
```

**After:**
```
Follow-up search: "MerkleTree depth limit capacity maximum" on midnight-search-docs
→ Returns documentation about MerkleTree depth constraints
Combined: usage examples + capacity limits = complete understanding
```

**Why:** The code examples show how to use MerkleTree but not its limitations. The follow-up targets documentation that covers depth and capacity constraints.

### Deployment Returns Docs But No Code

**Before:**
```
First search: "deploy contract Midnight" on midnight-search-docs
→ Returns conceptual deployment documentation but no runnable code
Gap: actual TypeScript deployment code is missing
```

**After:**
```
Follow-up search: "deploy contract provider code example" on midnight-search-typescript
→ Returns TypeScript deployment implementations
Combined: conceptual overview + runnable code = actionable answer
```

**Why:** Documentation explains the deployment concepts but does not include TypeScript code. The follow-up targets the TypeScript index for actual implementation code.

## Anti-Patterns

### Repeating the Same Query

**Wrong:**
```
First search: "Counter overflow" → 2 results, neither addresses overflow
Follow-up: "Counter overflow" → same 2 results
```

**Problem:** Repeating the same query against the same tool always returns the same results. The follow-up must target different content or use a different tool.

**Instead:** Reformulate the follow-up: try different terms (`Counter limit maximum value`), a different tool (`midnight-search-docs` instead of `midnight-search-compact`), or a step-back query.

### Doing Follow-Up Searches When Results Are Sufficient

**Wrong:**
```
First search returns 5 highly relevant results that fully answer the question
→ Do a follow-up "just to be thorough"
```

**Problem:** The follow-up wastes an API call and tokens when the initial results already provide a complete answer. More results do not mean a better answer.

**Instead:** Assess result sufficiency before deciding on a follow-up. If the initial results cover the question, stop.

### More Than Two Total Search Rounds

**Wrong:**
```
Round 1: initial search → gaps found
Round 2: follow-up → still gaps
Round 3: another follow-up → still gaps
Round 4: yet another follow-up
```

**Problem:** If two rounds of searching do not produce the information, it is likely not in the index. Additional rounds produce diminishing returns and consume excessive API calls.

**Instead:** Limit to two total rounds (initial + one follow-up). If the information is still missing, inform the user and suggest alternative approaches (checking source code directly, asking on community channels).
