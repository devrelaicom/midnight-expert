# Intent Classification Examples

## When to Apply

Always, before selecting a tool. Classify the search intent to determine which MCP tool and parameters to use.

## Examples

### Code Example Intent

**Before:**
```
User query: "how do I declare a ledger with a Counter"
Unclassified → default to midnight-search-docs
```

**After:**
```
Intent: code_example
→ Route to: midnight-search-compact
Query: "ledger Counter declaration example"
```

**Why:** The user wants to see implementation code, not read about the concept. `midnight-search-compact` returns real Compact code patterns, which is what "how do I" + specific construct signals.

### Conceptual Intent

**Before:**
```
User query: "what is the transaction model in Midnight"
Unclassified → default to midnight-search-compact
```

**After:**
```
Intent: conceptual
→ Route to: midnight-search-docs
Query: "transaction model architecture Midnight"
```

**Why:** "What is" + architectural concept signals the user wants an explanation, not code. Documentation provides conceptual overviews that code indexes do not.

### API Reference Intent

**Before:**
```
User query: "what's the type signature of ContractAddress"
Unclassified → search all tools
```

**After:**
```
Intent: api_reference
→ Route to: midnight-search-typescript with includeTypes: true
Query: "ContractAddress type definition"
```

**Why:** Type signatures live in TypeScript definitions. Setting `includeTypes: true` ensures type definition files are included in results.

### Troubleshooting Intent

**Before:**
```
User query: "I'm getting ERR_UNSUPPORTED_DIR_IMPORT when importing midnight-js-contracts"
Unclassified → search midnight-search-compact
```

**After:**
```
Intent: troubleshooting
→ Route to: midnight-search-docs with category: "guides"
→ Also consider: midnight-search-typescript for import patterns
Query: "ERR_UNSUPPORTED_DIR_IMPORT module resolution import"
```

**Why:** Runtime import errors are JavaScript/Node.js issues. Documentation guides cover common setup problems. TypeScript search shows correct import patterns.

### Specific Page Intent

**Before:**
```
User query: "show me the getting started page"
→ Search for "getting started" across all tools
```

**After:**
```
Intent: specific_page
→ Route to: midnight-fetch-docs with path: "/devnet/getting-started"
```

**Why:** The user knows exactly which page they want. Fetching directly is faster and more complete than searching for snippets.

## Anti-Patterns

### Defaulting to Docs for Code Questions

**Wrong:**
```
User asks: "show me a Counter example"
→ Route to midnight-search-docs
```

**Problem:** Documentation may describe Counter conceptually but rarely contains complete, runnable code examples. The compact code index has real implementations.

**Instead:** Classify as `code_example` and route to `midnight-search-compact`.

### Using Compact Search for TypeScript/SDK Questions

**Wrong:**
```
User asks: "how to set up the MidnightProvider"
→ Route to midnight-search-compact
```

**Problem:** `MidnightProvider` is a TypeScript SDK type. The Compact code index does not contain TypeScript SDK implementations.

**Instead:** Classify as `code_example` with TypeScript context and route to `midnight-search-typescript`.

### Classifying Everything as code_example

**Wrong:**
```
User asks: "what is the role of the proof server in Midnight's architecture?"
→ Classify as code_example → midnight-search-compact
```

**Problem:** This is a conceptual/architectural question. Code search returns implementation details, not architectural explanations.

**Instead:** Classify as `conceptual` and route to `midnight-search-docs`.
