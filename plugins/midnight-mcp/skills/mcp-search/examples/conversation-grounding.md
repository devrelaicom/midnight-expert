# Conversation Grounding Examples

## When to Apply

When prior conversation turns contain entity names, versions, file paths, contract names, or other specifics that the current query lacks.

## Examples

### Injecting Contract Name from Prior Context

**Before:**
```
Conversation history: User discussed their `TokenVault` contract in turn 3
Current query: "how do I add access control"
Search: "access control Compact"
```

**After:**
```
Search: "access control witness TokenVault contract"
```

**Why:** The user is asking about access control in the context of their `TokenVault` contract. Including the contract name helps surface results from similar token vault implementations.

### Carrying Forward Type Context

**Before:**
```
Conversation history: User was debugging MerkleTree depth issues in turns 5-7
Current query: "how do I check the current size"
Search: "check current size"
```

**After:**
```
Search: "MerkleTree size depth count elements"
```

**Why:** "Check the current size" is ambiguous without context. The prior discussion about MerkleTree depth makes it clear the user is asking about MerkleTree size, not a generic size check.

### Including Package and Version Context

**Before:**
```
Conversation history: User is debugging an import error with @midnight-ntwrk/midnight-js-contracts v2.1.0
Current query: "why can't I import ContractAddress"
Search: "import ContractAddress"
```

**After:**
```
Search: "ContractAddress import @midnight-ntwrk/midnight-js-contracts v2"
```

**Why:** The package name and version from prior context narrow the search to results from the correct SDK version, avoiding outdated v1 import paths.

### Network Target from Earlier Discussion

**Before:**
```
Conversation history: User established they are targeting testnet in turn 2
Current query: "how do I configure the provider"
Search: "configure provider"
```

**After:**
```
Search: "provider configuration testnet endpoint"
```

**Why:** Provider configuration differs between devnet, testnet, and mainnet. The testnet context from earlier conversation ensures results show testnet-specific configuration.

## Anti-Patterns

### Injecting Stale Context

**Wrong:**
```
Conversation history: User discussed Counter in turns 1-3, then switched to MerkleTree in turns 4-8
Current query about MerkleTree: inject "Counter" from stale context
```

**Problem:** The user has moved past Counter. Injecting it into MerkleTree queries adds noise and may return irrelevant results about Counter instead of MerkleTree.

**Instead:** Only ground from recent, relevant conversation turns. If the user has moved to a new topic, drop earlier entities.

### Over-Grounding with Too Many Entities

**Wrong:**
```
Inject contract name + 3 type names + version + network + file path into a single query
```

**Problem:** Too many grounded terms make the query overly narrow. The search engine tries to match all terms, returning few or no results.

**Instead:** Inject 1-2 of the most relevant grounded entities. Prioritize entities that disambiguate the query.

### Grounding When the User Is Exploring Something New

**Wrong:**
```
User has been working on token contracts, now asks: "how does the indexer work?"
Search: "indexer token contract TokenVault"
```

**Problem:** The user is asking about the indexer as a new topic, not about how the indexer relates to their token contract. Grounding from the token context pollutes the results.

**Instead:** Recognize when the user is shifting topics. Do not ground from prior context when the new query is clearly about a different domain.
