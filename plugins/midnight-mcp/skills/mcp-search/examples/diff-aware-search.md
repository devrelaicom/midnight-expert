# Diff-Aware Search Examples

## When to Apply

When the user is in a PR review, migration, or refactoring context and the search should be informed by what is changing.

## Examples

### Refactoring Counter to MerkleTree

**Before:**
```
User's PR: replacing Counter with MerkleTree in a membership contract
User asks: "is my MerkleTree usage correct?"
Search: "MerkleTree usage" (generic, ignores the refactoring context)
```

**After:**
```
Context from diff: replacing Counter.increment() with MerkleTree.insert()
Search: "MerkleTree insert member usage pattern" on midnight-search-compact
Also search: "MerkleTree membership proof verify" (the pattern Counter was being used for)
→ Results show MerkleTree patterns that match the previous Counter usage context
```

**Why:** The diff reveals what the user is trying to achieve — replacing Counter-based membership tracking with MerkleTree-based membership proofs. Searching for MerkleTree patterns that match the original Counter use case produces more relevant results.

### SDK v1 to v2 Migration

**Before:**
```
User is migrating imports from @midnight-ntwrk/compact-runtime to @midnight-ntwrk/midnight-js-contracts
User asks: "what's the v2 equivalent of this import"
Search: "import migration" (too generic)
```

**After:**
```
Context from diff: changing import paths
Search: "midnight-js-contracts import ContractAddress DeployedContract" on midnight-search-typescript
Also: "SDK migration v1 v2 breaking changes" on midnight-search-docs
→ Results show the correct v2 import paths and migration guidance
```

**Why:** The diff shows the specific imports being changed. Searching for those specific type names in the new package produces the exact import patterns needed.

### PR Introduces New disclose Call

**Before:**
```
User's PR adds a disclose statement to a contract
User asks: "did I implement disclose correctly?"
Search: "disclose Compact" (too broad)
```

**After:**
```
Context from diff: new disclose call on a ledger field
Search: "disclose ledger field public state pattern" on midnight-search-compact
Also: "disclose privacy implications public" on midnight-search-docs
→ Results show correct disclose patterns and privacy implications
```

**Why:** The diff reveals which specific construct the user added. Searching for disclose patterns on ledger fields and privacy implications provides verification context that directly relates to the PR changes.

## Anti-Patterns

### Ignoring the Diff Context

**Wrong:**
```
User is in a PR review, asks about a specific change
→ Search generically without considering what is changing
```

**Problem:** Generic searches miss the specific context of the changes. The user's question is about their particular modification, not the general topic.

**Instead:** Read the diff or PR context to understand what is changing. Use changed file names, modified types, and affected functions as search terms.

### Searching for Every Changed Symbol

**Wrong:**
```
Diff changes 15 files, modifies 8 functions
→ Search for all 8 function names individually
```

**Problem:** Not all changes are relevant to the user's question. Searching for every changed symbol wastes API calls and produces unfocused results.

**Instead:** Focus on the symbols relevant to the user's specific question. If they ask about MerkleTree usage, search for MerkleTree patterns, not every other change in the PR.

### Using Diff-Aware Search for Unrelated Questions

**Wrong:**
```
User is in a PR context but asks: "how does the proof server work?"
→ Search using PR diff context: "proof server MerkleTree Counter refactor"
```

**Problem:** The user's question about the proof server is unrelated to their PR changes. Injecting diff context into an unrelated question adds noise.

**Instead:** Recognize when the user's question is unrelated to the current diff. Only use diff context when the question is about the changes themselves.
