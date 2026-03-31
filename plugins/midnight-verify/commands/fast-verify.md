---
name: midnight-verify:fast-verify
description: Fast source-first verification of Midnight claims. Uses source inspection as the primary method with optional background execution checks. Faster and cheaper than /verify.
allowed-tools: Agent, AskUserQuestion, Read, Glob, Grep, Skill
argument-hint: "[claim, file path, code snippet, or SDK question]"
---

Fast source-first verification of Midnight claims. Returns a verdict based on source inspection, with an optional background execution check that only surfaces if it disagrees.

## Step 1: Determine Input

Determine what `$ARGUMENTS` contains and prepare accordingly:

### No arguments

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask:

> What would you like to fast-verify? You can provide:
> - A claim (e.g., "Compact tuples are 0-indexed")
> - A file path (e.g., `contracts/my-contract.compact`)
> - A code snippet
> - An SDK question (e.g., "midnight-js-contracts exports deployContract")

Do NOT attempt to infer what the user wants to verify. Ask them.

### File path

If `$ARGUMENTS` looks like a file path (ends in `.compact`, `.ts`, `.tsx`, or exists on disk when checked with Glob):

1. Read the file content
2. Proceed to Step 2 with:
   - The file path
   - The file content
   - Context: "Verify the correctness of this file via source inspection. Extract individual claims and verify each one against the source repositories."

### Code snippet

If `$ARGUMENTS` contains code syntax (keywords like `circuit`, `witness`, `export`, `import`, `const`, `function`, `pragma`, curly braces, semicolons, type annotations):

1. Proceed to Step 2 with:
   - The code snippet as inline content
   - Context: "Verify the correctness of this code snippet via source inspection."

### Natural language claim or question

If `$ARGUMENTS` is natural language (a question or assertion):

1. Proceed to Step 2 with:
   - The claim verbatim
   - Context: "Verify this claim about Midnight via source inspection."

### Multiple files or directory

If `$ARGUMENTS` is a directory path or contains glob patterns:

1. Use Glob to find all `.compact` and `.ts` files matching the path
2. Present the file list to the user for confirmation
3. For each file (or batch if fewer than 5), proceed to Step 2

## Step 2: Classify Domain

Load the `midnight-verify:verify-correctness` skill. Use ONLY its domain classification table (Step 1 of the hub skill) to determine the claim's domain. Do NOT follow the hub skill's dispatch or routing instructions — this command has its own routing.

## Step 3: Dispatch Agents

Use the routing table below. Dispatch the foreground agent and wait for its result. If a background agent is listed, dispatch it with `run_in_background: true` — do NOT wait for it.

| Domain | Foreground Agent | Background Agent |
|---|---|---|
| Compact | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:contract-writer (agent)" — instruct to compile with `--skip-zk` |
| SDK | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:type-checker (agent)" |
| ZKIR | @"midnight-verify:source-investigator (agent)" | None |
| Wallet SDK | @"midnight-verify:source-investigator (agent)" | None |
| Ledger | @"midnight-verify:source-investigator (agent)" | None |
| Tooling | @"midnight-verify:cli-tester (agent)" | None |
| Witness | @"midnight-verify:source-investigator (agent)" | None |
| Cross-domain | @"midnight-verify:source-investigator (agent)" | None |

**When dispatching the foreground agent, pass:**
- The claim verbatim
- Any relevant context (file path, code snippet)
- For @"midnight-verify:source-investigator (agent)": which repo/area to focus on based on the domain (Compact → LFDT-Minokawa/compact, SDK → midnightntwrk/midnight-js, Wallet SDK → midnightntwrk/midnight-wallet, Ledger → midnightntwrk/midnight-ledger, ZKIR → midnightntwrk/midnight-zk)

**When dispatching the background contract-writer agent:**
- The claim verbatim
- Explicit instruction: "Compile with `--skip-zk` flag. Do not generate PLONK keys."
- What observable behavior would confirm/refute the claim

**When dispatching the background type-checker agent:**
- The claim verbatim
- What type assertion to write

## Step 4: Present Verdict

Present the foreground agent's verdict immediately using this format:

```markdown
## Verdict: [Confirmed|Refuted|Inconclusive] ([qualifier])

**Claim:** [the claim as stated — verbatim]

**Method:** [source-verified|cli-tested]

**Evidence:**
[Summary of source evidence]

**Conclusion:**
[One or two sentences]
```

**Verdict qualifiers:**
- Foreground with background running: `(source-verified, execution pending)` or `(cli-tested)`
- Foreground without background: `(source-verified)` or `(cli-tested)`

## Step 5: Handle Background Disagreement

If a background agent was dispatched and it completes:

- **Agrees with foreground verdict** → Stay silent. Do not show anything to the user.
- **Disagrees with foreground verdict** → Show this warning:

```markdown
> **WARNING: Background verification disagrees with source verdict.**
> - Source verdict: [foreground verdict]
> - Execution verdict: [background verdict]
> - Recommendation: Run `/verify` for full verification.
```

If the background agent has not completed by the time you present the foreground verdict, that is fine — the background result will surface later only if it disagrees.
