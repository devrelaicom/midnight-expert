# Step-Back Queries Examples

## When to Apply

When the specific question is too narrow to return results, or when background context would improve understanding of specific results.

## Examples

### Counter Decrement Support

**Before:**
```
Specific query: "does Counter support decrement"
→ Few or no results
```

**After:**
```
Step-back query: "Counter type operations increment value"
Specific query: "Counter decrement subtract"
```

**Why:** "Counter decrement" is too narrow — the index may not contain that exact phrase. Stepping back to "Counter type operations" retrieves the full Counter API documentation, which reveals whether decrement exists.

### MerkleTree Overflow at Depth 32

**Before:**
```
Specific query: "MerkleTree overflow at depth 32"
→ No results
```

**After:**
```
Step-back query: "MerkleTree depth capacity limits"
Specific query: "MerkleTree depth 32 maximum"
```

**Why:** The exact phrasing "overflow at depth 32" may not appear anywhere. The step-back query finds documentation about MerkleTree depth limits in general, which will cover the capacity question.

### Concurrent Counter Modification

**Before:**
```
Specific query: "what happens when two transactions modify the same Counter"
→ Few results
```

**After:**
```
Step-back query: "Compact concurrency ledger contention transaction conflict"
Specific query: "Counter concurrent modification race"
```

**Why:** The specific question is about a nuanced scenario. The step-back query retrieves Compact's general concurrency model, providing context for understanding how Counter modifications interact.

### Witness Parameter Validation

**Before:**
```
Specific query: "how to validate witness parameters at circuit boundaries"
→ No results
```

**After:**
```
Step-back query: "witness function circuit parameter Compact"
Specific query: "witness validation assert circuit boundary"
```

**Why:** "Circuit boundaries" is an abstract concept. Stepping back to general witness/circuit documentation reveals how parameter validation is actually structured in Compact.

## Anti-Patterns

### Stepping Back Too Far

**Wrong:**
```
Original: "MerkleTree insert"
Step-back: "Compact programming"
```

**Problem:** "Compact programming" is so broad it returns everything and nothing useful. The step-back query should still be within the relevant domain — one level of abstraction up, not five.

**Instead:** Step back to `MerkleTree operations` or `MerkleTree type usage Compact`.

### Using Step-Back When the Original Query Works

**Wrong:**
```
Original: "Counter increment" → returns 8 relevant results
Step-back: "Counter type operations" → returns similar results
```

**Problem:** The original query already returns good results. The step-back search adds latency and token cost without new information.

**Instead:** Only use step-back when the original query returns few or no results, or when you specifically need broader context.

### Returning Only Step-Back Results

**Wrong:**
```
Step-back: "ledger state types" → returns overview docs
→ Present these results without trying the specific query
```

**Problem:** Step-back results provide context but may not answer the specific question. The user asked about a particular scenario, not for a general overview.

**Instead:** Always run both the step-back and the specific query. Use step-back results for context, specific results for the direct answer.
