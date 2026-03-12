# MCP Review Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Augment the compact-review skill's 11 review categories with Midnight MCP server tools so reviewers have machine-verified evidence alongside their checklist-driven review.

**Architecture:** The orchestrating command (`review-compact.md`) runs 4 shared MCP tools once as a pre-pass, injecting outputs into all 11 reviewer prompts. Each reference file gets a Required MCP Tools section, inline tool hints on applicable checklist items, and a Tool Reference footer. The reviewer agent (`reviewer.md`) gets updated with MCP tool awareness.

**Tech Stack:** Markdown files (Claude Code plugin format), Midnight MCP server tools

---

### Task 1: Update the reviewer agent with MCP tool awareness

**Files:**
- Modify: `plugins/compact-core/agents/reviewer.md`

**Step 1: Edit reviewer.md to add MCP tool step to Review Process**

Insert a new step 1.5 between "Load your checklist" (step 1) and "Read all files" (step 2). Also update the subsequent step about applying the checklist to reference tool evidence. Add a new review principle about tool-backed evidence.

Replace the current Review Process section (lines 18-27) with:

```markdown
## Review Process

1. **Load your checklist**: Invoke the `compact-core:compact-review` skill. Read the reference file that corresponds to your assigned category from the Category Reference Map in the SKILL.md.

2. **Reference shared MCP evidence**: Your prompt includes pre-computed outputs from shared MCP tools (compilation result, structural analysis, contract analysis, and latest syntax reference). Read these outputs — they are your baseline evidence for evaluating checklist items.

3. **Run category-specific MCP tools**: Check your reference file's "Required MCP Tools" section. Any tools marked `[category-specific]` must be run by you now against the contract under review. Tools marked `[shared]` are already provided in your prompt.

4. **Read all files**: Read every file in your assignment list completely.

5. **Apply the checklist systematically**: Go through EVERY item in your category's checklist. For each item:
   - Search the code for the pattern or anti-pattern
   - Cross-reference against the shared MCP tool evidence where applicable
   - When a checklist item has a `> **Tool:**` hint, consider calling that tool for additional verification
   - If found, create a finding with the correct severity
   - If the code correctly avoids the issue, note it in positive highlights
```

Also add to the Review Principles section (after line 73):

```markdown
- **Use tool evidence**: When MCP tool output confirms or contradicts a finding, cite it. Tool-backed findings are stronger than judgment alone. If a tool identifies an issue that matches your checklist, include the tool's output as evidence.
```

**Step 2: Verify the edit is correct**

Read `plugins/compact-core/agents/reviewer.md` and verify the new steps are properly numbered 1-5 and the new review principle is present.

**Step 3: Commit**

```bash
git add plugins/compact-core/agents/reviewer.md
git commit -m "feat(compact-core): add MCP tool awareness to reviewer agent"
```

---

### Task 2: Add shared MCP pre-pass to review-compact command

**Files:**
- Modify: `plugins/compact-core/commands/review-compact.md`

**Step 1: Add allowed MCP tools to command frontmatter**

Update the `allowed-tools` line (line 3) to include the ToolSearch tool so the command can discover and call MCP tools:

```yaml
allowed-tools: Bash, Agent, Read, Glob, Grep, TaskCreate, TaskUpdate, TaskList, AskUserQuestion, ToolSearch
```

**Step 2: Insert new Step 1.5 for shared MCP tool pre-pass**

After Step 1 (Identify Files to Review, ending at line 34) and before Step 2 (Check for Agent Teams, line 36), insert a new step:

```markdown
## Step 1.5: Run Shared MCP Tools

After identifying the files, run these 4 MCP tools against the primary `.compact` contract file. These outputs will be passed to all 11 reviewer agents as shared evidence.

Use the ToolSearch tool to load the Midnight MCP tools, then call each one:

1. **Compile the contract** (syntax validation):
   Call `midnight-compile-contract` with the contract source and `skipZk=true`. Save the output as `COMPILE_RESULT`.

2. **Extract contract structure** (structural analysis):
   Call `midnight-extract-contract-structure` with the contract source. Save the output as `STRUCTURE_RESULT`.

3. **Analyze the contract** (static pattern analysis):
   Call `midnight-analyze-contract` with the contract source. Save the output as `ANALYSIS_RESULT`.

4. **Get latest syntax reference**:
   Call `midnight-get-latest-syntax`. Save the output as `SYNTAX_REFERENCE`.

If any tool call fails (e.g., MCP server unavailable), note the failure and proceed — the review can still run with partial or no tool evidence. Do not block the review on tool failures.

Store all four outputs for injection into reviewer prompts in the next steps.
```

**Step 3: Update Agent Teams mode prompt template (Step 3a)**

In the Agent Teams section (around line 50), update the teammate instructions to include shared evidence. Replace step 3 in the teammate instructions:

```markdown
> 3. Reference the shared MCP tool evidence provided below
> 4. Read all files: [INSERT FILE LIST]
```

And add at the end of the agent team block (before "Use sonnet model"):

```markdown
>
> **Shared MCP Tool Evidence:**
> - Compilation result: [INSERT COMPILE_RESULT]
> - Structural analysis: [INSERT STRUCTURE_RESULT]
> - Contract analysis: [INSERT ANALYSIS_RESULT]
> - Latest syntax reference: [INSERT SYNTAX_REFERENCE]
```

**Step 4: Update Subagent mode prompt templates (Step 3b)**

Update each of the 11 Agent call prompts in the subagent section to include shared MCP evidence. For each agent call, append to the prompt string:

```
\n\nShared MCP Tool Evidence (pre-computed by orchestrator — reference when evaluating checklist items):\n- Compilation result: [INSERT COMPILE_RESULT]\n- Structural analysis: [INSERT STRUCTURE_RESULT]\n- Contract analysis: [INSERT ANALYSIS_RESULT]\n- Latest syntax reference: [INSERT SYNTAX_REFERENCE]
```

This must be added to all 11 agent call prompts (calls 1-11).

**Step 5: Verify the edits**

Read `plugins/compact-core/commands/review-compact.md` and verify:
- Step 1.5 exists between Step 1 and Step 2
- ToolSearch is in allowed-tools
- Both Agent Teams and Subagent prompts include shared evidence injection
- The original Step 4 (Consolidated Report) is unchanged

**Step 6: Commit**

```bash
git add plugins/compact-core/commands/review-compact.md
git commit -m "feat(compact-core): add shared MCP tool pre-pass to review-compact command"
```

---

### Task 3: Add MCP tools to privacy-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/privacy-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3, ending "Apply every item below to the contract under review.") and before the first checklist section ("## Unnecessary Disclosure Checklist" at line 5), insert:

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation errors from incorrect `disclose()` usage |
| `midnight-extract-contract-structure` | `[shared]` | Detects missing `disclose()` calls, structural disclosure issues |
| `midnight-analyze-contract` | `[shared]` | Static analysis of privacy patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for `disclose()` semantics |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints to applicable checklist items**

Add `> **Tool:**` hints after the following checklist items (insert after the item's description/code block, before the next checklist item):

1. After the first checklist item "Every `disclose()` call: is it actually needed?" (after line 9's description):
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all `disclose()` call sites. Cross-reference each one against necessity.
   ```

2. After "`disclose()` placed at witness call site instead of near the public boundary" (after the code block ending around line 23):
   ```
   > **Tool:** `midnight-extract-contract-structure` flags early-disclosure patterns. Check its output for disclosure placement warnings.
   ```

3. After "Witness-derived values written to public ledger without `disclose()`" (after the description around line 43):
   ```
   > **Tool:** `midnight-compile-contract` output shows `implicit disclosure of witness value` errors for these cases.
   ```

4. After "Conditional branches revealing private information" (after the code block around line 55):
   ```
   > **Tool:** Consider calling `midnight-explain-circuit` on circuits that use `disclose()` inside conditionals to understand the full privacy implications.
   ```

5. After "Using `Set<Bytes<32>>` for membership that should be private" (after the code block around line 92):
   ```
   > **Tool:** `midnight-extract-contract-structure` shows all data structure declarations. Look for `Set` types used in membership contexts.
   ```

6. After "`persistentHash` used where `persistentCommit` is needed" (after the code block around line 126):
   ```
   > **Tool:** `midnight-extract-contract-structure` flags `persistentHash` vs `persistentCommit` usage. Check for misuse patterns.
   ```

7. After "Transient vs persistent confusion" (after the code block around line 136):
   ```
   > **Tool:** `midnight-search-docs` can clarify the transient vs persistent guarantees if there is any ambiguity in the contract's usage.
   ```

**Step 3: Add Tool Reference footer**

At the end of the file (after the Anti-Patterns Table), append:

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation, `fullCompile=true` for full ZK compilation. |
| `midnight-extract-contract-structure` | Deep structural analysis: deprecated syntax, missing `disclose()`, potential overflows, data structure usage. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference from the latest compiler version. |
| `midnight-explain-circuit` | Explains what a circuit does in plain language, including ZK proof and privacy implications. |
| `midnight-search-docs` | Full-text search across official Midnight documentation. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/privacy-review.md
git commit -m "feat(compact-core): add MCP tool integration to privacy review checklist"
```

---

### Task 4: Add MCP tools to security-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/security-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Access Control Checklist" (line 5), insert:

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation errors from missing assertions, type mismatches |
| `midnight-extract-contract-structure` | `[shared]` | Detects missing access control, structural security issues |
| `midnight-analyze-contract` | `[shared]` | Static analysis of security patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for cryptographic primitives |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Exported circuit with no authorization check" (first item under Access Control):
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all exported circuits and their structure. Cross-reference each exported circuit that modifies state against the presence of authorization checks.
   ```

2. After "`persistentHash` vs `persistentCommit` vs `transientHash` vs `transientCommit` — correct usage":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies hash and commit usage. Verify each call uses the correct primitive per the table above. `midnight-search-compact` can find reference patterns for correct cryptographic primitive usage.
   ```

3. After "Domain separation: every hash/commit call should include a unique domain string":
   ```
   > **Tool:** `midnight-search-compact` can find official examples of domain separation patterns to compare against.
   ```

4. After "`checkRoot()` called to verify path against current tree root":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies MerkleTree operations. Verify every `merkleTreePathRoot` call is followed by a `checkRoot()` assertion.
   ```

5. After "Missing assertions before dangerous operations":
   ```
   > **Tool:** `midnight-compile-contract` output may reveal runtime failures from missing safety checks. `midnight-search-docs` has guidance on safe Map/Set access patterns.
   ```

**Step 3: Add Tool Reference footer**

Same footer as Task 3, with the addition of `midnight-search-compact`:

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation, `fullCompile=true` for full ZK compilation. |
| `midnight-extract-contract-structure` | Deep structural analysis: deprecated syntax, missing access control, cryptographic primitive usage. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference from the latest compiler version. |
| `midnight-search-compact` | Semantic search across Compact smart contract code and patterns. |
| `midnight-search-docs` | Full-text search across official Midnight documentation. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/security-review.md
git commit -m "feat(compact-core): add MCP tool integration to security review checklist"
```

---

### Task 5: Add MCP tools to token-security-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/token-security-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Double-Spend Prevention Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation errors from type mismatches in token operations |
| `midnight-extract-contract-structure` | `[shared]` | Detects structural issues in token handling, missing checks |
| `midnight-analyze-contract` | `[shared]` | Static analysis of token patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for token operation signatures |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Nullifier deterministically derived from coin and secret, not random":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies hash function usage. Verify all nullifier derivations use `persistentHash`, not `transientHash`.
   ```

2. After "Token amount type: `Uint<64>` vs `Uint<128>`":
   ```
   > **Tool:** `midnight-get-latest-syntax` provides the authoritative stdlib function signatures showing the exact `Uint` width for each token operation. `midnight-compile-contract` output will show type mismatch errors if the wrong width is used.
   ```

3. After "`receiveShielded()` called in receiving contract":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies all `receiveShielded` calls. Cross-reference against all circuits that accept `ShieldedCoinInfo` parameters — each must call `receiveShielded`. `midnight-search-compact` can find reference patterns for correct shielded token handling.
   ```

4. After "Correct `Uint` width for token operations":
   ```
   > **Tool:** `midnight-get-latest-syntax` is the authoritative source for these function signatures. Cross-reference every token operation call against the syntax reference.
   ```

5. After "`unshieldedBalance()` not used in conditional logic":
   ```
   > **Tool:** `midnight-search-docs` has guidance on construction-time balance locks and the correct use of comparison functions.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation. |
| `midnight-extract-contract-structure` | Deep structural analysis: token patterns, missing `receiveShielded`, hash function usage. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including token operation signatures. |
| `midnight-search-compact` | Semantic search across Compact code for token handling patterns. |
| `midnight-search-docs` | Full-text search across official Midnight documentation. |
| `midnight-list-examples` | List available example contracts with token implementations for reference. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/token-security-review.md
git commit -m "feat(compact-core): add MCP tool integration to token security review checklist"
```

---

### Task 6: Add MCP tools to concurrency-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/concurrency-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Read-Then-Write Contention Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output helps identify ledger operation patterns |
| `midnight-extract-contract-structure` | `[shared]` | Identifies data structure declarations and usage patterns |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contention-prone patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for ADT operation semantics |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Counter read-then-set pattern":
   ```
   > **Tool:** `midnight-extract-contract-structure` shows all `Counter` operations. Look for `.read()` calls followed by manual writes to the same variable.
   ```

2. After "General read-then-write on any exported circuit":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all exported circuits and their ledger operations. Cross-reference reads and writes to the same variables within each circuit.
   ```

3. After "`MerkleTree.insert(leaf)` — conflicts when concurrent inserts occur":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies all MerkleTree declarations. Check whether `HistoricMerkleTree` is used where concurrent inserts are expected. `midnight-search-docs` has guidance on choosing between `MerkleTree` and `HistoricMerkleTree`.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation. |
| `midnight-extract-contract-structure` | Deep structural analysis: data structure declarations, ledger operation patterns. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including ADT operation semantics. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for concurrency guidance. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/concurrency-review.md
git commit -m "feat(compact-core): add MCP tool integration to concurrency review checklist"
```

---

### Task 7: Add MCP tools to compilation-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/compilation-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Syntax Error Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | **Primary evidence source.** Actual compilation output reveals all syntax and type errors. |
| `midnight-extract-contract-structure` | `[shared]` | Detects deprecated syntax, hallucinated APIs, structural issues |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract patterns |
| `midnight-get-latest-syntax` | `[shared]` | **Critical for this category.** Authoritative syntax reference — the ground truth for what is valid Compact. |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

**Important:** For Compilation & Type Safety review, the `midnight-compile-contract` and `midnight-get-latest-syntax` outputs are your primary evidence. Cross-reference every checklist item against actual compilation results before reporting findings.

```

**Step 2: Add inline tool hints**

1. After "`Void` return type instead of `[]`":
   ```
   > **Tool:** `midnight-compile-contract` output will show `unknown type "Void"` or `found "{" looking for ";"` if present. `midnight-extract-contract-structure` also flags deprecated syntax.
   ```

2. After "Deprecated `ledger { ... }` block instead of individual ledger declarations":
   ```
   > **Tool:** `midnight-compile-contract` output shows `found "{" looking for ";"` for deprecated ledger block syntax. `midnight-extract-contract-structure` flags this pattern.
   ```

3. After "`witness name() { ... }` with a function body":
   ```
   > **Tool:** `midnight-compile-contract` output will show a parsing error for witness bodies. `midnight-get-latest-syntax` confirms witness declaration-only syntax.
   ```

4. After "`pure function` instead of `pure circuit`":
   ```
   > **Tool:** `midnight-compile-contract` output will show an error for the `function` keyword. `midnight-get-latest-syntax` confirms `circuit` and `pure circuit` as the only keywords.
   ```

5. After "Missing `import CompactStandardLibrary;` statement":
   ```
   > **Tool:** `midnight-compile-contract` output will show undefined type errors for stdlib types if the import is missing. `midnight-extract-contract-structure` checks for the import presence.
   ```

6. After "Direct cast from `Uint<N>` to `Bytes<M>`":
   ```
   > **Tool:** `midnight-compile-contract` output will show `cannot cast from type X to type Y`. `midnight-get-latest-syntax` documents the valid cast paths.
   ```

7. After "`Counter.value()` instead of `Counter.read()`":
   ```
   > **Tool:** `midnight-compile-contract` output will show `operation "value" undefined for Counter`. `midnight-get-latest-syntax` lists the correct Counter API methods.
   ```

8. After "`Map.get(key)` instead of `Map.lookup(key)`":
   ```
   > **Tool:** `midnight-compile-contract` output will show `operation "get" undefined for Map`. `midnight-search-compact` can find correct Map usage patterns in reference code.
   ```

9. After "`hash()` instead of `persistentHash<T>()` or `transientHash<T>()`":
   ```
   > **Tool:** `midnight-compile-contract` output will show `unknown function "hash"`. `midnight-get-latest-syntax` lists all valid hash functions.
   ```

10. After "`CurvePoint` instead of `NativePoint`":
    ```
    > **Tool:** `midnight-compile-contract` output will show an unknown type error for `CurvePoint`. `midnight-get-latest-syntax` confirms `NativePoint` as the current type name.
    ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | **Primary tool for this category.** Compile contract with hosted compiler. Use `skipZk=true` for syntax/type validation. All compilation errors listed in the Compiler Error Quick Reference are directly caught by this tool. |
| `midnight-extract-contract-structure` | Deep structural analysis: deprecated syntax, hallucinated APIs, missing imports. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | **Critical for this category.** Authoritative Compact syntax reference — use as ground truth for valid types, functions, and keywords. |
| `midnight-search-compact` | Semantic search across Compact code for correct API usage patterns. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/compilation-review.md
git commit -m "feat(compact-core): add MCP tool integration to compilation review checklist"
```

---

### Task 8: Add MCP tools to performance-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/performance-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Proof Generation Cost Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Syntax validation and basic compilation checks |
| `midnight-extract-contract-structure` | `[shared]` | Identifies data structure declarations, loop patterns, type casts |
| `midnight-analyze-contract` | `[shared]` | Static analysis of circuit complexity patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for pure circuit syntax and type cast rules |
| `midnight-compile-contract` (fullCompile) | `[category-specific]` | **Run this yourself** with `fullCompile=true` to get full ZK compilation including circuit size metrics. This reveals proof generation cost. |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.
Tools marked `[category-specific]` must be run by you during your review.

```

**Step 2: Add inline tool hints**

1. After "Oversized depth wastes proof generation time" (MerkleTree depth section):
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all MerkleTree declarations with their depth parameters. Cross-reference each depth against the expected capacity table above.
   ```

2. After "`for` loops in Compact are unrolled at compile time":
   ```
   > **Tool:** `midnight-compile-contract` with `fullCompile=true` reveals the actual constraint count. Compare against the expected count based on loop iterations and body complexity.
   ```

3. After "Reusable logic that does not touch ledger state should be `pure circuit`":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies all circuits and whether they access ledger state. Flag any non-pure circuit that does not read or write ledger variables. `midnight-explain-circuit` can analyze specific circuits to confirm whether they access ledger state.
   ```

4. After "Expensive computation in circuit that could be in witness":
   ```
   > **Tool:** `midnight-explain-circuit` can explain what a circuit does in plain language, helping identify computations that could be moved to the witness. `midnight-search-docs` has guidance on the circuit vs witness boundary optimization.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation, `fullCompile=true` for circuit size metrics and proof generation cost analysis. |
| `midnight-extract-contract-structure` | Deep structural analysis: data structure declarations, loop patterns, type cast chains, pure circuit candidates. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including `pure circuit` rules and type cast paths. |
| `midnight-explain-circuit` | Explains what a circuit does in plain language, including ZK proof cost implications. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for performance guidance. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/performance-review.md
git commit -m "feat(compact-core): add MCP tool integration to performance review checklist"
```

---

### Task 9: Add MCP tools to witness-consistency-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/witness-consistency-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Name Matching Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output reveals witness-related errors |
| `midnight-extract-contract-structure` | `[shared]` | Lists all witness declarations, their parameter types, and return types |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract structure |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for witness declaration syntax and type mappings |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Every `witness` declaration in the Compact contract has a matching key":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all witness declarations in the contract. Use this as your definitive list of witness names to cross-reference against the TypeScript `witnesses` object.
   ```

2. After "All Compact-to-TypeScript type mappings are correct":
   ```
   > **Tool:** `midnight-extract-contract-structure` shows the Compact types for each witness parameter and return value. `midnight-get-latest-syntax` confirms the authoritative type mapping rules. `midnight-search-docs` has detailed WitnessContext documentation.
   ```

3. After "Witness parameter count and order match the Compact declaration":
   ```
   > **Tool:** `midnight-extract-contract-structure` provides the exact parameter list for each witness. Compare against the TypeScript implementation parameter-by-parameter.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Reveals witness-related compilation errors. |
| `midnight-extract-contract-structure` | Deep structural analysis: lists all witness declarations with their exact parameter types, return types, and names. |
| `midnight-analyze-contract` | Static analysis of contract structure and common patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including witness declaration rules and type mappings. |
| `midnight-search-compact` | Semantic search across Compact code for witness implementation patterns. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for WitnessContext and type mapping details. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/witness-consistency-review.md
git commit -m "feat(compact-core): add MCP tool integration to witness consistency review checklist"
```

---

### Task 10: Add MCP tools to architecture-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/architecture-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## ADT Selection Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output reveals structural issues |
| `midnight-extract-contract-structure` | `[shared]` | Identifies all data structure declarations, visibility modifiers, modules |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract architecture |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for ADT types, visibility modifiers, module syntax |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "ADT Selection Decision Tree":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all ledger variable declarations with their types. Cross-reference each declaration against the ADT selection decision tree above.
   ```

2. After "MerkleTree depth matches expected capacity":
   ```
   > **Tool:** `midnight-extract-contract-structure` shows all MerkleTree declarations with their depth parameters. Verify each depth against the planning table.
   ```

3. After "Visibility reference":
   ```
   > **Tool:** `midnight-extract-contract-structure` shows the visibility modifier for each ledger variable. `midnight-list-examples` provides reference architectures showing idiomatic visibility patterns.
   ```

4. After "Module system used for separation of concerns":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies module structure and imports. `midnight-search-compact` can find reference examples of module decomposition patterns.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Use `skipZk=true` for syntax validation. |
| `midnight-extract-contract-structure` | Deep structural analysis: data structure declarations, visibility modifiers, module organization. |
| `midnight-analyze-contract` | Static analysis of contract architecture and patterns. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including ADT types and module syntax. |
| `midnight-list-examples` | List available example contracts for reference architectures and idiomatic patterns. |
| `midnight-search-compact` | Semantic search across Compact code for architectural patterns. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/architecture-review.md
git commit -m "feat(compact-core): add MCP tool integration to architecture review checklist"
```

---

### Task 11: Add MCP tools to code-quality-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/code-quality-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Naming Conventions Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Catches hallucinated functions and type errors |
| `midnight-extract-contract-structure` | `[shared]` | Identifies dead code, unused declarations, structural patterns |
| `midnight-analyze-contract` | `[shared]` | Static analysis of code patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for valid stdlib functions and types |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Verify every stdlib function call exists":
   ```
   > **Tool:** `midnight-compile-contract` output will show `unknown function` or `operation undefined` errors for any hallucinated API calls. `midnight-get-latest-syntax` is the authoritative list of valid stdlib functions. Cross-reference every function call in the contract against these two sources.
   ```

2. After "`hash()` does not exist":
   ```
   > **Tool:** `midnight-compile-contract` output will show `unknown function "hash"` if present.
   ```

3. After "`counter.value()` does not exist":
   ```
   > **Tool:** `midnight-compile-contract` output will show `operation "value" undefined for Counter`.
   ```

4. After "`CurvePoint` or `EllipticCurvePoint` do not exist":
   ```
   > **Tool:** `midnight-compile-contract` output will show an unknown type error. `midnight-get-latest-syntax` confirms `NativePoint` as the current type name.
   ```

5. After "Unused ledger variables (declared but never read or written)":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies all ledger declarations. Cross-reference each against usage in circuit bodies.
   ```

6. After "Pure circuits not used for reusable logic":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies all circuits and whether they access ledger state. Flag any non-pure circuit that could be marked `pure`. `midnight-list-examples` shows idiomatic use of `pure circuit` in reference contracts.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Catches hallucinated functions, wrong method names, invalid types. |
| `midnight-extract-contract-structure` | Deep structural analysis: dead code detection, unused declarations, circuit structure. |
| `midnight-analyze-contract` | Static analysis of code patterns and quality. |
| `midnight-get-latest-syntax` | Authoritative list of valid Compact stdlib functions, types, and methods. Ground truth for hallucination detection. |
| `midnight-search-compact` | Semantic search across Compact code for idiomatic patterns and stdlib usage examples. |
| `midnight-list-examples` | List available example contracts showing best practices and correct patterns. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/code-quality-review.md
git commit -m "feat(compact-core): add MCP tool integration to code quality review checklist"
```

---

### Task 12: Add MCP tools to testing-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/testing-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Test Coverage Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output reveals contract structure for coverage analysis |
| `midnight-extract-contract-structure` | `[shared]` | Lists all exported circuits (required for coverage checklist) |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract patterns |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for type mappings (needed for mock correctness) |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Every exported circuit has at least one test":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all exported circuits. Use this as your definitive checklist — every exported circuit name must appear in the test files.
   ```

2. After "Mock type mappings match the Compact-to-TypeScript type table":
   ```
   > **Tool:** `midnight-get-latest-syntax` provides the authoritative type mapping rules. `midnight-extract-contract-structure` shows the Compact types for each witness, which must match the mock types per the mapping table.
   ```

3. After "Multi-step flows tested end-to-end":
   ```
   > **Tool:** `midnight-extract-contract-structure` and `midnight-analyze-contract` reveal the contract's state machine and multi-phase patterns. Use these to identify which flows need end-to-end tests. `midnight-list-examples` shows test patterns from reference implementations.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Reveals contract structure for coverage analysis. |
| `midnight-extract-contract-structure` | Lists all exported circuits, witness declarations, and state structure — the definitive list for coverage analysis. |
| `midnight-analyze-contract` | Static analysis of contract patterns and state machines. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference including type mapping rules for mock correctness. |
| `midnight-list-examples` | List available example contracts with test suites for reference patterns. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for testing guidance. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/testing-review.md
git commit -m "feat(compact-core): add MCP tool integration to testing review checklist"
```

---

### Task 13: Add MCP tools to documentation-review.md

**Files:**
- Modify: `plugins/compact-core/skills/compact-review/references/documentation-review.md`

**Step 1: Insert Required MCP Tools section**

After the intro paragraph (line 3) and before "## Contract-Level Documentation Checklist":

```markdown

## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation output reveals contract structure for documentation completeness analysis |
| `midnight-extract-contract-structure` | `[shared]` | Lists all exported circuits, ledger variables, witnesses — the definitive inventory for documentation coverage |
| `midnight-analyze-contract` | `[shared]` | Static analysis of contract patterns and structure |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative reference for verifying documentation accuracy |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.

```

**Step 2: Add inline tool hints**

1. After "Every exported circuit has a comment explaining its purpose":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all exported circuits. Use this as your definitive checklist — every exported circuit must have documentation.
   ```

2. After "Every ledger variable has a comment explaining its purpose":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all ledger variable declarations with their types and visibility modifiers. Use this as your checklist for documentation coverage.
   ```

3. After "Every witness declaration has a comment explaining what data it provides":
   ```
   > **Tool:** `midnight-extract-contract-structure` lists all witness declarations. Use this to verify every witness has documentation. `midnight-search-docs` can provide context on standard witness patterns and WitnessContext documentation.
   ```

4. After "Privacy documentation covers the full data lifecycle":
   ```
   > **Tool:** `midnight-extract-contract-structure` identifies all `disclose()` calls, ledger writes, and data flow patterns. Use this to verify the privacy documentation covers every disclosure point. `midnight-search-docs` has guidance on documenting privacy models.
   ```

**Step 3: Add Tool Reference footer**

```markdown

## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract with hosted compiler. Reveals complete contract structure. |
| `midnight-extract-contract-structure` | Lists all exported circuits, ledger variables, witnesses, and data flow — the definitive inventory for documentation coverage analysis. |
| `midnight-analyze-contract` | Static analysis of contract patterns for architectural documentation. |
| `midnight-get-latest-syntax` | Authoritative Compact syntax reference for verifying technical accuracy of documentation. |
| `midnight-search-docs` | Full-text search across official Midnight documentation for documentation standards and privacy model guidance. |
```

**Step 4: Verify and commit**

```bash
git add plugins/compact-core/skills/compact-review/references/documentation-review.md
git commit -m "feat(compact-core): add MCP tool integration to documentation review checklist"
```
