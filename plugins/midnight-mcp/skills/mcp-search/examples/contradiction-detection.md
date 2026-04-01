# Contradiction Detection Examples

## When to Apply

When multiple search results provide conflicting information about the same topic.

## Examples

### Documentation vs Code — Counter Decrement

**Before:**
```
Results:
  A. Documentation says Counter supports decrement operations
  B. Code examples only show Counter.increment() — no decrement found
→ Silently assume documentation is correct
```

**After:**
```
Contradiction detected:
  Source A (docs): "Counter supports increment and decrement"
  Source B (code): only Counter.increment() found in examples

Flag to user: "Documentation suggests Counter supports decrement, but no code examples demonstrate it. This may be planned but unimplemented, or the documentation may be ahead of the current version. Verify by compiling a test contract with Counter decrement — use `midnight-tooling:compact-cli` to check."
```

**Why:** Silently picking one source hides important uncertainty. The user needs to know about the contradiction so they can verify before relying on either source.

### Different Import Paths — Version Difference

**Before:**
```
Results:
  A. Shows: import { ContractAddress } from "@midnight-ntwrk/midnight-js-contracts"
  B. Shows: import { ContractAddress } from "@midnight-ntwrk/compact-runtime"
→ Pick one arbitrarily
```

**After:**
```
Contradiction detected:
  Source A (midnightntwrk/examples, recent): import from "@midnight-ntwrk/midnight-js-contracts"
  Source B (midnightntwrk/old-examples, older): import from "@midnight-ntwrk/compact-runtime"

Flag to user: "Two different import paths found for ContractAddress. Source A uses the current package name (@midnight-ntwrk/midnight-js-contracts) and is more recent. Source B uses an older package name that may have been renamed. Check your project's package.json to confirm which package you have installed."
```

**Why:** The contradiction is likely a version difference. Noting both sources with their dates lets the user determine which applies to their project.

### Conflicting Guidance on disclose

**Before:**
```
Results:
  A. One result says disclose is mandatory for public ledger state
  B. Another result implies disclose is handled automatically
→ Pick the one that sounds more authoritative
```

**After:**
```
Contradiction detected:
  Source A: "All public ledger state must use disclose"
  Source B: "Public ledger state is automatically disclosed"

Flag to user: "Conflicting information found about disclose behavior. Source A states disclose is mandatory and explicit. Source B implies it is automatic. This may depend on the Compact language version or specific context. Recommend checking `compact-core:compact-privacy-disclosure` skill for authoritative guidance, or verify with compilation."
```

**Why:** Privacy semantics are critical in Midnight. Presenting incorrect disclose guidance could lead to unintended data exposure. Both sources should be flagged with a recommendation to verify.

## Anti-Patterns

### Silently Picking the Preferred Result

**Wrong:**
```
Two results disagree → pick the one that matches your assumption → present as the answer
```

**Problem:** Your assumption may be wrong. The user deserves to know that sources disagree so they can make an informed decision or verify independently.

**Instead:** Present both results with their sources and trust/freshness context. Let the user or a verification skill resolve the conflict.

### Treating All Contradictions as Errors

**Wrong:**
```
Two results show different import paths → report: "there is an error in the documentation"
```

**Problem:** Many contradictions are version differences, not errors. Different SDK versions legitimately have different import paths, different API signatures, and different behavior.

**Instead:** Consider whether the contradiction could be a version difference. Note the version context of each source and flag it as "likely version difference" rather than "error."

### Flagging Superficial Differences as Contradictions

**Wrong:**
```
Result A: `const counter = new Counter(0);`
Result B: `let counter = new Counter(0);`
→ Flag as contradiction
```

**Problem:** `const` vs `let` is a style difference, not a semantic contradiction. Both work. Flagging trivial differences wastes the user's attention.

**Instead:** Only flag contradictions that affect behavior: different function names, different parameter types, different return values, different semantics.
