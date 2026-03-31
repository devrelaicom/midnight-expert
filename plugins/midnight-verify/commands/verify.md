---
name: midnight-verify:verify
description: Verify claims about Midnight, Compact code, or SDK APIs. Accepts a claim, file path, code snippet, SDK question, or no arguments to be prompted.
allowed-tools: Agent, AskUserQuestion, Read, Glob, Grep, Skill
argument-hint: "[claim, file path, code snippet, or SDK question]"
---

Verify Midnight-related claims by orchestrating the verification pipeline directly.

## Step 1: Determine Input

Determine what `$ARGUMENTS` contains and prepare accordingly:

### No arguments

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask:

> What would you like to verify? You can provide:
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
   - Context: "Verify the correctness of this file. Extract individual claims (stdlib functions used, syntax patterns, type annotations, disclosure usage) and verify each one. Report findings grouped by line/section with an overall summary."

### Code snippet

If `$ARGUMENTS` contains code syntax (keywords like `circuit`, `witness`, `export`, `import`, `const`, `function`, `pragma`, curly braces, semicolons, type annotations):

1. Proceed to Step 2 with:
   - The code snippet as inline content
   - Context: "Verify the correctness of this code snippet. Determine if it is Compact or TypeScript and verify the claims it makes (syntax, stdlib usage, types, patterns)."

### Natural language claim or question

If `$ARGUMENTS` is natural language (a question or assertion):

1. Proceed to Step 2 with:
   - The claim verbatim
   - Context: "Verify this claim about Midnight."

### Multiple files or directory

If `$ARGUMENTS` is a directory path or contains glob patterns:

1. Use Glob to find all `.compact` and `.ts` files matching the path
2. Present the file list to the user for confirmation
3. For each file (or batch if fewer than 5), proceed to Step 2

## Step 2: Load the Hub Skill and Classify

Load the `midnight-verify:verify-correctness` skill. It contains the full classification table, routing logic, dispatch instructions, and verdict synthesis rules. Follow it exactly:

1. **Classify the domain** — use the hub skill's classification table to determine which domain the claim belongs to (Compact, SDK, ZKIR, Witness, Wallet SDK, Ledger/Protocol, Tooling, or Cross-domain)
2. **Load the domain skill** — load the appropriate domain skill as directed by the hub skill (e.g., the `midnight-verify:verify-compact` skill for Compact claims)
3. **Follow the domain skill's routing** — it tells you which sub-agent(s) to dispatch

## Step 3: Dispatch Sub-Agents

Dispatch the sub-agent(s) indicated by the domain skill's routing table. Use `@"midnight-verify:agent-name (agent)"` references.

**Available agents:**
- @"midnight-verify:contract-writer (agent)" — compile and execute Compact test contracts
- @"midnight-verify:source-investigator (agent)" — inspect source code in Midnight repositories
- @"midnight-verify:type-checker (agent)" — run tsc --noEmit for type assertions
- @"midnight-verify:sdk-tester (agent)" — run E2E scripts against local devnet
- @"midnight-verify:cli-tester (agent)" — run Compact CLI commands and observe output
- @"midnight-verify:witness-verifier (agent)" — verify witness implementations against contracts
- @"midnight-verify:zkir-checker (agent)" — run ZKIR circuits through WASM checker or inspect structure
- @"devs:deps-maintenance (agent)" — check package versions (fallback: run `npm view` directly)

**When dispatching, pass:**
- The claim verbatim
- Any relevant context (file path, code snippet, what specifically to check)
- For @"midnight-verify:contract-writer (agent)": what observable behavior would confirm/refute the claim
- For @"midnight-verify:source-investigator (agent)": which repo/area to focus on (from the domain skill's routing)
- For @"midnight-verify:type-checker (agent)": what type assertion to write, or the file path to check
- For @"midnight-verify:sdk-tester (agent)": what runtime behavior to observe

**Concurrent vs sequential dispatch:**
- When multiple agents are independent, dispatch them concurrently
- For Witness + ZKIR: dispatch @"midnight-verify:witness-verifier (agent)" first, get the build output path, then dispatch @"midnight-verify:zkir-checker (agent)" with that path
- For Wallet SDK: dispatch @"midnight-verify:type-checker (agent)" and @"midnight-verify:source-investigator (agent)" concurrently. If source returns Inconclusive, then dispatch @"midnight-verify:sdk-tester (agent)"

## Step 4: Synthesize and Present Verdict

Collect the sub-agent report(s) and follow the hub skill's verdict synthesis rules to produce the final verdict. Present the structured verdict directly to the user using the format from the hub skill. Do not add commentary or interpretation — the verdict speaks for itself.
