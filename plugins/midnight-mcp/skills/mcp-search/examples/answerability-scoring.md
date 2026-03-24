# Answerability Scoring Examples

## When to Apply

As a final filter before using results to answer the user's question.

## Examples

### Counter Increment — Complete vs Tangential

**Before:**
```
User asks: "how to use Counter increment"
Results:
  A. Complete circuit with Counter.increment(1) in a ledger context (answerable)
  B. Changelog entry: "Counter type was added in v0.2.0" (not answerable)
  C. Test file that asserts Counter value after increment (partially answerable)
```

**After:**
```
Scored:
  A. Answerable — shows exactly how to call Counter.increment in context → primary result
  C. Partially answerable — shows expected behavior after increment → supplementary
  B. Not answerable — mentions Counter but does not show how to use increment → dropped
```

**Why:** Result A provides the complete pattern the user needs. Result C shows testing context that supplements the answer. Result B merely mentions Counter's existence, which does not answer "how to use" it.

### Token Transfer Pattern — Implementation vs Import

**Before:**
```
User asks: "token transfer pattern"
Results:
  A. Full contract with transfer circuit, ledger, and witness (answerable)
  B. One-line import: `import { transfer } from "./token"` (not answerable alone)
  C. Documentation paragraph explaining the token model (partially answerable)
```

**After:**
```
Scored:
  A. Answerable — complete implementation showing the pattern → primary result
  C. Partially answerable — conceptual explanation → supplementary context
  B. Not answerable on its own — shows the import but not the implementation → dropped or footnote
```

**Why:** The user asked for a "pattern," which implies a complete implementation. The one-line import tells us a transfer module exists but does not show the pattern itself.

### Deploy to Testnet — Tutorial vs Passing Mention

**Before:**
```
User asks: "deploy to testnet"
Results:
  A. Step-by-step deployment tutorial for testnet (answerable)
  B. Sentence mentioning testnet in an unrelated architecture discussion (not answerable)
  C. Configuration snippet showing testnet endpoint (partially answerable)
```

**After:**
```
Scored:
  A. Answerable — complete deployment instructions → primary result
  C. Partially answerable — useful configuration detail → supplementary
  B. Not answerable — testnet is mentioned in passing → dropped
```

**Why:** Result A is a complete, actionable answer. Result C provides a useful detail (the endpoint). Result B mentions testnet but is about architecture, not deployment.

## Anti-Patterns

### Treating Any Keyword Match as Answerable

**Wrong:**
```
Result mentions "Counter" and "increment" → mark as answerable
```

**Problem:** A result may contain both keywords without showing how to use them together. A changelog that says "Counter increment performance improved" mentions both terms but does not answer "how to increment a Counter."

**Instead:** Check whether the result provides actionable information for the specific question, not just whether it contains the right keywords.

### Requiring Every Result to Be Independently Sufficient

**Wrong:**
```
Result C shows a useful configuration snippet but not the full deployment process → drop it
```

**Problem:** Supplementary results add value when combined with a primary result. A configuration snippet alongside a deployment tutorial gives the user a more complete picture.

**Instead:** Score results as "answerable" (complete), "partially answerable" (supplementary), or "not answerable" (drop). Include partially answerable results as supporting context.

### Not Checking Answerability at All

**Wrong:**
```
Present all 10 results from the search, in score order, without assessing whether any of them actually answer the question
```

**Problem:** The user receives a mix of relevant and irrelevant results with no guidance. They have to evaluate each result themselves, which defeats the purpose of having an LLM assistant.

**Instead:** Always assess answerability before presenting results. Lead with the most answerable results and drop or deprioritize results that merely mention the topic.
