# Cross-Tool Orchestration Examples

## When to Apply

When a single tool cannot provide complete coverage — typically for comprehensive research, or when code examples need conceptual context.

## Examples

### How and Why: Token Transfer Implementation

**Before:**
```
User query: "How do I implement token transfers in Compact?"
Single tool: midnight-search-compact query: "token transfer"
→ Returns code but no explanation of the token model
```

**After:**
```
Call 1: midnight-search-compact query: "token transfer shielded circuit"
→ Returns real implementation patterns

Call 2: midnight-search-docs query: "token transfer model privacy"
→ Returns conceptual guidance on the token model
```

**Why:** The user needs both implementation code and conceptual understanding. Compact search provides the "how," docs search provides the "why." Presenting both gives a complete answer.

### End-to-End: Contract Deployment from TypeScript

**Before:**
```
User query: "Show me how to deploy a contract from TypeScript"
Single tool: midnight-search-typescript query: "deploy contract"
→ Returns SDK deployment code but not the contract itself
```

**After:**
```
Call 1: midnight-search-typescript query: "deploy contract provider TypeScript"
→ Returns SDK deployment patterns

Call 2: midnight-search-compact query: "contract export circuit deployment example"
→ Returns the contract side that gets deployed
```

**Why:** Deployment spans two domains: the TypeScript SDK code that deploys, and the Compact contract being deployed. Both are needed for a complete answer.

### Discovery + Full Content: Compact Language Changes

**Before:**
```
User query: "What changed in Compact language version 0.2.0?"
Single tool: midnight-search-docs query: "Compact language version 0.2.0 changes"
→ Returns snippets but not the full changelog
```

**After:**
```
Call 1: midnight-search-docs query: "Compact language version 0.2.0 changes migration"
→ Returns snippets pointing to the relevant page

Call 2: midnight-fetch-docs path: "/compact/changelog" (or the discovered page path)
→ Returns the full page content with complete details
```

**Why:** Search discovers which page contains the information. Fetch retrieves the complete content. This two-step pattern avoids guessing page paths while still getting full content.

## Anti-Patterns

### Calling All Three Search Tools on Every Question

**Wrong:**
```
User asks: "what is Counter?"
Call 1: midnight-search-compact query: "Counter"
Call 2: midnight-search-typescript query: "Counter"
Call 3: midnight-search-docs query: "Counter"
```

**Problem:** Most questions need 1-2 tools. Calling all three wastes API calls and tokens. "What is Counter?" is a Compact language question — `midnight-search-compact` is sufficient, possibly with `midnight-search-docs` for conceptual explanation.

**Instead:** Classify the intent and route to the appropriate tool(s). Use cross-tool orchestration only when the question genuinely spans domains.

### Using Search + Fetch When Search Alone Suffices

**Wrong:**
```
Search returns clear, complete code snippet
→ Also fetch the full page the snippet came from
```

**Problem:** If the search result already contains the complete answer, fetching the full page adds tokens without new information.

**Instead:** Use search + fetch only when search snippets are insufficient — truncated code, incomplete explanations, or when you need surrounding context.

### Calling the Same Tool Twice with Slightly Different Queries

**Wrong:**
```
Call 1: midnight-search-compact query: "token transfer"
Call 2: midnight-search-compact query: "shielded token send"
```

**Problem:** This is multi-query, not cross-tool orchestration. If you need multiple queries against the same tool, combine them using the multi-query technique in one logical step.

**Instead:** Use cross-tool orchestration for calling different tools. Use multi-query for calling the same tool with variant queries.
