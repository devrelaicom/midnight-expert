# Fix Verification Process Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the broken midnight-verify verification pipeline by eliminating the verifier orchestrator agent, making the `/verify` command the direct orchestrator, updating all agent/skill references to the correct format, and adding SubagentStop hooks to enforce process compliance.

**Architecture:** The `/verify` command (main thread) loads the hub skill and domain skills directly, classifies claims, dispatches sub-agents, and synthesizes verdicts. SubagentStop hooks scan agent transcripts for evidence of real tool usage before allowing agents to complete.

**Tech Stack:** Bash scripts (hooks), Markdown (skills/agents/commands), JSON (hooks.json, plugin.json)

---

### Task 1: Delete the verifier orchestrator agent

**Files:**
- Delete: `plugins/midnight-verify/agents/verifier.md`

- [ ] **Step 1: Delete the file**

```bash
rm plugins/midnight-verify/agents/verifier.md
```

- [ ] **Step 2: Verify deletion**

```bash
ls plugins/midnight-verify/agents/
```

Expected: 7 files listed (contract-writer.md, source-investigator.md, type-checker.md, cli-tester.md, sdk-tester.md, witness-verifier.md, zkir-checker.md). No verifier.md.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md
git commit -m "refactor(midnight-verify): delete verifier orchestrator agent

Subagents cannot spawn subagents in Claude Code, so the verifier
agent (which dispatched domain sub-agents) was broken. The /verify
command will become the direct orchestrator instead."
```

---

### Task 2: Rewrite the `/verify` command to be the orchestrator

**Files:**
- Modify: `plugins/midnight-verify/commands/verify.md`

- [ ] **Step 1: Read the current file**

```bash
# Already read — current content dispatches midnight-verify:verifier agent
```

- [ ] **Step 2: Rewrite the command**

Replace the full content of `plugins/midnight-verify/commands/verify.md` with:

```markdown
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
```

- [ ] **Step 3: Verify the file is valid**

Read back the file and confirm:
- `allowed-tools` includes `Skill`
- No references to `midnight-verify:verifier`
- All agent references use `@"midnight-verify:agent-name (agent)"` format
- Steps reference loading skills explicitly

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/commands/verify.md
git commit -m "refactor(midnight-verify): rewrite /verify command as direct orchestrator

The command now loads the hub skill and domain skills directly,
classifies claims, dispatches sub-agents, and synthesizes verdicts.
No intermediate verifier agent needed."
```

---

### Task 3: Update the verify-correctness hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Update the frontmatter description**

Replace:
```
  Hub skill for the midnight-verify plugin. Classifies claims by domain,
  routes to the appropriate domain skill (verify-compact or verify-sdk),
  dispatches sub-agents (contract-writer and/or source-investigator) based
  on the domain skill's routing, and synthesizes final verdicts. Always loaded
  first by the verifier agent.
```

With:
```
  Hub skill for the midnight-verify plugin. Classifies claims by domain,
  routes to the appropriate domain skill, dispatches sub-agents based on the
  domain skill's routing, and synthesizes final verdicts. Loaded by the
  /verify command — the main thread acts as orchestrator.
```

- [ ] **Step 2: Update the intro paragraph**

Replace:
```
You are the verification orchestrator. This skill tells you how to classify claims, route them, dispatch sub-agents, and synthesize verdicts.
```

With:
```
You are the verification orchestrator. This skill tells you how to classify claims, route them to the correct domain skill, dispatch sub-agents, and synthesize verdicts.
```

- [ ] **Step 3: Update agent references in the dispatch section (lines 41-49)**

Apply these replacements to the "Dispatch Sub-Agents" section:

| Old | New |
|---|---|
| `dispatch \`midnight-verify:contract-writer\` agent` | `dispatch @"midnight-verify:contract-writer (agent)"` |
| `dispatch \`midnight-verify:source-investigator\` agent` | `dispatch @"midnight-verify:source-investigator (agent)"` |
| `dispatch \`midnight-verify:type-checker\` agent` | `dispatch @"midnight-verify:type-checker (agent)"` |
| `dispatch \`midnight-verify:sdk-tester\` agent` | `dispatch @"midnight-verify:sdk-tester (agent)"` |
| `dispatch \`devs:deps-maintenance\` agent` | `dispatch @"devs:deps-maintenance (agent)"` |
| `dispatch \`midnight-verify:zkir-checker\` agent` | `dispatch @"midnight-verify:zkir-checker (agent)"` |
| `dispatch \`midnight-verify:witness-verifier\` agent` | `dispatch @"midnight-verify:witness-verifier (agent)"` |
| `dispatch \`midnight-verify:cli-tester\` agent` | `dispatch @"midnight-verify:cli-tester (agent)"` |

These replacements apply throughout the entire file — every occurrence of `dispatch \`midnight-verify:X\` agent` becomes `dispatch @"midnight-verify:X (agent)"`, and `dispatch \`devs:deps-maintenance\` agent` becomes `dispatch @"devs:deps-maintenance (agent)"`.

- [ ] **Step 4: Update skill references to be explicit**

Replace:
```
instruct it to load the `midnight-verify:zkir-regression` skill
```

With:
```
instruct it to load the `midnight-verify:zkir-regression` skill for the regression claim list and expected verdicts
```

Replace:
```
with instruction to load `midnight-verify:verify-by-wallet-source`
```

With:
```
with instruction to load the `midnight-verify:verify-by-wallet-source` skill for wallet-specific repo routing
```

Replace:
```
with instruction to load `midnight-verify:verify-by-ledger-source`
```

With:
```
with instruction to load the `midnight-verify:verify-by-ledger-source` skill for Rust crate-level routing
```

- [ ] **Step 5: Update the "When dispatching" guidance (lines 78-81)**

Replace:
```
- For the contract-writer: what observable behavior would confirm/refute the claim
- For the source-investigator: which repo/area to focus on (from the domain skill's routing)
- For the type-checker: what type assertion to write, or the file path to check
- For the sdk-tester: what runtime behavior to observe
```

With:
```
- For @"midnight-verify:contract-writer (agent)": what observable behavior would confirm/refute the claim
- For @"midnight-verify:source-investigator (agent)": which repo/area to focus on (from the domain skill's routing)
- For @"midnight-verify:type-checker (agent)": what type assertion to write, or the file path to check
- For @"midnight-verify:sdk-tester (agent)": what runtime behavior to observe
```

- [ ] **Step 6: Update the "dispatch type-checker and sdk-tester concurrently" lines**

Replace:
```
dispatch type-checker and sdk-tester concurrently
```

With:
```
dispatch @"midnight-verify:type-checker (agent)" and @"midnight-verify:sdk-tester (agent)" concurrently
```

This applies to line 56 (wallet SDK), line 147 (SDK claims), and any other occurrence.

- [ ] **Step 7: Update the "What This Skill Does NOT Do" section**

Replace:
```
- It does not contain domain-specific verification logic — that lives in `verify-compact` and `verify-sdk`
- It does not contain method-specific instructions — those live in `verify-by-execution`, `verify-by-source`, `verify-by-type-check`, and `verify-by-devnet`
```

With:
```
- It does not contain domain-specific verification logic — that lives in domain skills like the `midnight-verify:verify-compact` skill and the `midnight-verify:verify-sdk` skill
- It does not contain method-specific instructions — those live in method skills like the `midnight-verify:verify-by-execution` skill, the `midnight-verify:verify-by-source` skill, the `midnight-verify:verify-by-type-check` skill, and the `midnight-verify:verify-by-devnet` skill
```

- [ ] **Step 8: Verify no old references remain**

```bash
grep -n 'verifier agent\|"the verifier\|by the verifier\|Loaded by the verifier' plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

Expected: No matches.

```bash
grep -n 'dispatch `midnight-verify:[a-z-]*` agent' plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

Expected: No matches (all should now use `@"..."` format).

- [ ] **Step 9: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "refactor(midnight-verify): update hub skill references and remove verifier agent dependency

Update all agent references to @\"agent (agent)\" format, make skill
references explicit, update frontmatter to reflect /verify command
as orchestrator."
```

---

### Task 4: Update domain skill — verify-compact

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-compact/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace:
```
  Loaded by the verifier
  agent alongside the hub skill. Provides the claim type → method routing table
  and guidance on negative testing.
```

With:
```
  Loaded by the /verify command alongside the hub skill. Provides the claim
  type → method routing table and guidance on negative testing.
```

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies Compact-related claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies Compact-related claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update the routing table Dispatch column**

Replace every `**contract-writer**` with `@"midnight-verify:contract-writer (agent)"`.
Replace every `**source-investigator**` with `@"midnight-verify:source-investigator (agent)"`.
Replace every `**zkir-checker**` with `@"midnight-verify:zkir-checker (agent)"`.
Replace `**Both (concurrent)**` with `both @"midnight-verify:contract-writer (agent)" and @"midnight-verify:source-investigator (agent)" concurrently`.

- [ ] **Step 4: Update the "When in doubt" paragraph**

Replace:
```
**When in doubt:** If the claim involves observable runtime behavior, prefer **contract-writer**. If it's about what exists in the codebase or how something is implemented internally, prefer **source-investigator**. If it could benefit from both, dispatch both concurrently.
```

With:
```
**When in doubt:** If the claim involves observable runtime behavior, prefer @"midnight-verify:contract-writer (agent)". If it's about what exists in the codebase or how something is implemented internally, prefer @"midnight-verify:source-investigator (agent)". If it could benefit from both, dispatch both concurrently.
```

- [ ] **Step 5: Update the "Guide the contract-writer agent" reference**

Replace:
```
Guide the contract-writer agent to consider negative tests:
```

With:
```
Guide @"midnight-verify:contract-writer (agent)" to consider negative tests:
```

- [ ] **Step 6: Make skill references explicit in hints section**

Replace:
```
The verifier or sub-agents may consult these compact-core skills to inform what to test or where to look. These are **hints only** — never cite them as evidence in the verdict.

- `compact-core:compact-standard-library` — expected function signatures, what functions exist
- `compact-core:compact-structure` — how to structure a test contract (pragma, imports, exports)
- `compact-core:compact-language-ref` — syntax reference, type system, operators, casting
- `compact-core:compact-privacy-disclosure` — disclosure rules and patterns to test
- `compact-core:compact-compilation` — expected compiler behavior, flags, output structure
```

With:
```
Sub-agents may load these skills as hints for what to test or where to look. These are **hints only** — never cite skill content as evidence in the verdict.

- `compact-core:compact-standard-library` skill — expected function signatures, what functions exist
- `compact-core:compact-structure` skill — how to structure a test contract (pragma, imports, exports)
- `compact-core:compact-language-ref` skill — syntax reference, type system, operators, casting
- `compact-core:compact-privacy-disclosure` skill — disclosure rules and patterns to test
- `compact-core:compact-compilation` skill — expected compiler behavior, flags, output structure
```

- [ ] **Step 7: Commit**

```bash
git add plugins/midnight-verify/skills/verify-compact/SKILL.md
git commit -m "refactor(midnight-verify): update verify-compact agent/skill references"
```

---

### Task 5: Update domain skill — verify-sdk

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-sdk/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace:
```
  Loaded by the verifier
  agent alongside the hub skill.
```

With:
```
  Loaded by the /verify command alongside the hub skill.
```

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies SDK/TypeScript claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies SDK/TypeScript claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update all agent references in routing tables**

Apply these replacements across the entire file:

| Old | New |
|---|---|
| `**type-checker**` | `@"midnight-verify:type-checker (agent)"` |
| `**source-investigator**` | `@"midnight-verify:source-investigator (agent)"` |
| `**sdk-tester**` | `@"midnight-verify:sdk-tester (agent)"` |
| `**witness-verifier**` | `@"midnight-verify:witness-verifier (agent)"` |
| `**deps-maintenance**` | `@"devs:deps-maintenance (agent)"` |

- [ ] **Step 4: Fix the deps-maintenance reference on line 30**

Replace:
```
| Package exists / version | "@midnight-ntwrk/midnight-js-contracts is at version 4.0.2" | **deps-maintenance** (fallback: verifier runs `npm view` directly) |
```

With:
```
| Package exists / version | "@midnight-ntwrk/midnight-js-contracts is at version 4.0.2" | @"devs:deps-maintenance (agent)" (fallback: run `npm view` directly) |
```

- [ ] **Step 5: Update routing rules section**

Replace:
```
- Types, signatures, imports, interfaces → **type-checker**
- Runtime behavior, what happens when you call something → **sdk-tester**
- Internal implementation, how something works under the hood → **source-investigator**
- Package versions, existence → **deps-maintenance** (or `npm view` fallback)
```

With:
```
- Types, signatures, imports, interfaces → @"midnight-verify:type-checker (agent)"
- Runtime behavior, what happens when you call something → @"midnight-verify:sdk-tester (agent)"
- Internal implementation, how something works under the hood → @"midnight-verify:source-investigator (agent)"
- Package versions, existence → @"devs:deps-maintenance (agent)" (or `npm view` fallback)
```

- [ ] **Step 6: Make skill references explicit in hints section**

Replace:
```
The verifier or sub-agents may consult these skills for context. They are **hints only** — never cite them as evidence in the verdict.

- `dapp-development:midnight-sdk` — provider setup, component overview
- `dapp-development:dapp-connector` — wallet integration patterns
- `compact-core:compact-witness-ts` — witness implementation patterns
- `compact-core:compact-deployment` — deployment patterns
```

With:
```
Sub-agents may load these skills as hints for context. They are **hints only** — never cite skill content as evidence in the verdict.

- `dapp-development:midnight-sdk` skill — provider setup, component overview
- `dapp-development:dapp-connector` skill — wallet integration patterns
- `compact-core:compact-witness-ts` skill — witness implementation patterns
- `compact-core:compact-deployment` skill — deployment patterns
```

- [ ] **Step 7: Commit**

```bash
git add plugins/midnight-verify/skills/verify-sdk/SKILL.md
git commit -m "refactor(midnight-verify): update verify-sdk agent/skill references"
```

---

### Task 6: Update domain skill — verify-witness

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-witness/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace `Loaded by the verifier agent alongside the hub skill.` with `Loaded by the /verify command alongside the hub skill.`

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies witness-related claims and determines which agent(s) to dispatch. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies witness-related claims and determines which agent(s) to dispatch. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update all agent references**

Apply across the entire file:

| Old | New |
|---|---|
| `**witness-verifier**` | `@"midnight-verify:witness-verifier (agent)"` |
| `**sdk-tester**` | `@"midnight-verify:sdk-tester (agent)"` |
| `**zkir-checker**` | `@"midnight-verify:zkir-checker (agent)"` |
| `**type-checker**` | `@"midnight-verify:type-checker (agent)"` |
| `**contract-writer**` | `@"midnight-verify:contract-writer (agent)"` |

- [ ] **Step 4: Make skill references explicit in hints section**

Replace:
```
The witness-verifier may consult these skills for context. They are **hints only** — never cite them as evidence.

- `compact-core:compact-witness-ts` — witness implementation patterns, WitnessContext API, type mappings
- `compact-core:compact-structure` — witness declarations, disclosure rules
- `compact-core:compact-review` — witness consistency review checklist
```

With:
```
The @"midnight-verify:witness-verifier (agent)" may load these skills as hints for context. They are **hints only** — never cite skill content as evidence.

- `compact-core:compact-witness-ts` skill — witness implementation patterns, WitnessContext API, type mappings
- `compact-core:compact-structure` skill — witness declarations, disclosure rules
- `compact-core:compact-review` skill — witness consistency review checklist
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/skills/verify-witness/SKILL.md
git commit -m "refactor(midnight-verify): update verify-witness agent/skill references"
```

---

### Task 7: Update domain skill — verify-zkir

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-zkir/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace `Loaded by the verifier agent alongside the hub skill.` with `Loaded by the /verify command alongside the hub skill.`

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies ZKIR-related claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies ZKIR-related claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update all agent references**

Apply across the entire file:

| Old | New |
|---|---|
| `**zkir-checker**` | `@"midnight-verify:zkir-checker (agent)"` |
| `**source-investigator**` | `@"midnight-verify:source-investigator (agent)"` |
| `**contract-writer**` | `@"midnight-verify:contract-writer (agent)"` |

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-zkir/SKILL.md
git commit -m "refactor(midnight-verify): update verify-zkir agent/skill references"
```

---

### Task 8: Update domain skill — verify-tooling

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-tooling/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace `Loaded by the verifier agent alongside the hub skill.` with `Loaded by the /verify command alongside the hub skill.`

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies Compact CLI tooling claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies Compact CLI tooling claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update agent references in verification flow**

Replace:
```
1. **CLI execution (primary)** — dispatch cli-tester. Run the command, observe stdout/stderr/exit code/filesystem. This is the most authoritative evidence for behavioral claims.
2. **Source investigation (secondary)** — dispatch source-investigator (uses existing `verify-by-source`). For internal/architectural claims about how the compiler works under the hood.
```

With:
```
1. **CLI execution (primary)** — dispatch @"midnight-verify:cli-tester (agent)". Run the command, observe stdout/stderr/exit code/filesystem. This is the most authoritative evidence for behavioral claims.
2. **Source investigation (secondary)** — dispatch @"midnight-verify:source-investigator (agent)" (loads the `midnight-verify:verify-by-source` skill). For internal/architectural claims about how the compiler works under the hood.
```

- [ ] **Step 4: Update routing table agent references**

Replace all `cli-tester` and `source-investigator` references in the routing table with the proper `@"midnight-verify:... (agent)"` format.

- [ ] **Step 5: Update routing rules**

Replace:
```
- If you can answer the question by running a command → cli-tester
- If you need to read source code to understand internal behavior → source-investigator
```

With:
```
- If you can answer the question by running a command → @"midnight-verify:cli-tester (agent)"
- If you need to read source code to understand internal behavior → @"midnight-verify:source-investigator (agent)"
```

- [ ] **Step 6: Make skill reference explicit in hints section**

Replace:
```
The cli-tester may consult this skill for context. It is a **hint only** — never cite it as evidence.

- `midnight-tooling:compact-cli` — expected flags, compilation patterns, version management
```

With:
```
The @"midnight-verify:cli-tester (agent)" may load this skill as a hint for context. It is a **hint only** — never cite skill content as evidence.

- `midnight-tooling:compact-cli` skill — expected flags, compilation patterns, version management
```

- [ ] **Step 7: Commit**

```bash
git add plugins/midnight-verify/skills/verify-tooling/SKILL.md
git commit -m "refactor(midnight-verify): update verify-tooling agent/skill references"
```

---

### Task 9: Update domain skill — verify-ledger

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-ledger/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace `Loaded by the verifier agent alongside the hub skill.` with `Loaded by the /verify command alongside the hub skill.`

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies ledger and protocol claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies ledger and protocol claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update agent references in verification flow**

Replace:
```
1. **Type-check (pre-flight)** — for TypeScript API claims only. Dispatch type-checker against the existing sdk-workspace (ledger-v8 is already installed). Pre-flight only, never a standalone verdict.
2. **Source investigation (primary)** — always runs for protocol claims. Dispatch source-investigator, which loads `verify-by-ledger-source` for Rust crate-level routing.
3. **Compilation/execution (secondary)** — for claims testable via Compact contracts. Dispatch contract-writer (compile + execute, extract ledger-level evidence) or zkir-checker (inspect compiled circuits).
```

With:
```
1. **Type-check (pre-flight)** — for TypeScript API claims only. Dispatch @"midnight-verify:type-checker (agent)" against the existing sdk-workspace (ledger-v8 is already installed). Pre-flight only, never a standalone verdict.
2. **Source investigation (primary)** — always runs for protocol claims. Dispatch @"midnight-verify:source-investigator (agent)", which loads the `midnight-verify:verify-by-ledger-source` skill for Rust crate-level routing.
3. **Compilation/execution (secondary)** — for claims testable via Compact contracts. Dispatch @"midnight-verify:contract-writer (agent)" (compile + execute, extract ledger-level evidence) or @"midnight-verify:zkir-checker (agent)" (inspect compiled circuits).
```

- [ ] **Step 4: Update all agent references in routing tables**

Replace all bare `source-investigator`, `type-checker`, `contract-writer`, `zkir-checker` references in the routing table cells with `@"midnight-verify:... (agent)"` format.

- [ ] **Step 5: Update routing rules and hints section**

Apply the same pattern as previous tasks — explicit agent references and "skill" suffix on skill names.

Replace:
```
The verifier or sub-agents may consult these skills for context. They are **hints only** — never cite them as evidence.
```

With:
```
Sub-agents may load these skills as hints for context. They are **hints only** — never cite skill content as evidence.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-verify/skills/verify-ledger/SKILL.md
git commit -m "refactor(midnight-verify): update verify-ledger agent/skill references"
```

---

### Task 10: Update domain skill — verify-wallet-sdk

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace `Loaded by the verifier agent alongside the hub skill.` with `Loaded by the /verify command alongside the hub skill.`

- [ ] **Step 2: Update intro paragraph**

Replace:
```
This skill classifies wallet SDK claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).
```

With:
```
This skill classifies wallet SDK claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.
```

- [ ] **Step 3: Update verification flow agent references**

Replace:
```
1. **Type-check (pre-flight)** — dispatch type-checker in wallet-sdk-workspace mode. Fails fast if the claim is fundamentally broken. Type-checking alone NEVER produces a verdict for wallet SDK claims.
2. **Source investigation (primary)** — always runs. Dispatch source-investigator, which loads `verify-by-wallet-source`. This is the primary evidence source for all wallet SDK verdicts.
3. **Devnet E2E (fallback)** — dispatch sdk-tester in wallet-devnet mode ONLY if source investigation returns Inconclusive.
```

With:
```
1. **Type-check (pre-flight)** — dispatch @"midnight-verify:type-checker (agent)" in wallet-sdk-workspace mode. Fails fast if the claim is fundamentally broken. Type-checking alone NEVER produces a verdict for wallet SDK claims.
2. **Source investigation (primary)** — always runs. Dispatch @"midnight-verify:source-investigator (agent)", which loads the `midnight-verify:verify-by-wallet-source` skill. This is the primary evidence source for all wallet SDK verdicts.
3. **Devnet E2E (fallback)** — dispatch @"midnight-verify:sdk-tester (agent)" in wallet-devnet mode ONLY if source investigation returns Inconclusive.
```

- [ ] **Step 4: Update all routing table references**

Replace all bare `type-checker`, `source-investigator`, `sdk-tester` in routing table cells with `@"midnight-verify:... (agent)"` format.

- [ ] **Step 5: Update hints section**

Replace:
```
The verifier or sub-agents may consult these skills for context. They are **hints only** — never cite them as evidence in the verdict.

- `dapp-development:midnight-sdk` — provider setup, SDK component overview
- `dapp-development:dapp-connector` — wallet integration patterns
- `compact-core:compact-witness-ts` — witness implementation patterns (if claim spans wallet + witness)
```

With:
```
Sub-agents may load these skills as hints for context. They are **hints only** — never cite skill content as evidence in the verdict.

- `dapp-development:midnight-sdk` skill — provider setup, SDK component overview
- `dapp-development:dapp-connector` skill — wallet integration patterns
- `compact-core:compact-witness-ts` skill — witness implementation patterns (if claim spans wallet + witness)
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md
git commit -m "refactor(midnight-verify): update verify-wallet-sdk agent/skill references"
```

---

### Task 11: Update verify-by-witness skill — Phase 5 fix

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-witness/SKILL.md`

- [ ] **Step 1: Rewrite Phase 5**

Replace:
```
## Phase 5: Optional Devnet E2E

Check devnet health (load `midnight-tooling:devnet` skill for endpoints). If all services are reachable, dispatch to `midnight-verify:sdk-tester` for the full deploy+call lifecycle with the witness.

If devnet is unavailable, note in the report: "Behavioral verification passed locally. Full deploy+call lifecycle verification requires a running devnet."
```

With:
```
## Phase 5: Devnet E2E Recommendation

**You cannot dispatch other agents.** Phase 5 is a recommendation to the orchestrator (the /verify command), not something you execute.

In your report, include a recommendation:
- If the claim would benefit from a full deploy+call lifecycle test, state: "**Recommend devnet E2E:** The orchestrator should dispatch @"midnight-verify:sdk-tester (agent)" with the compiled contract and witness for full lifecycle verification."
- If local verification (phases 1-4) is sufficient for the claim, state: "**Devnet E2E not required** for this claim."

The orchestrator will decide whether to dispatch @"midnight-verify:sdk-tester (agent)" based on your recommendation and devnet availability.
```

- [ ] **Step 2: Update the report template**

In the report template section, replace:
```
**Devnet E2E:** PASS / FAIL / SKIPPED (devnet unavailable)
```

With:
```
**Devnet E2E Recommendation:** Recommended / Not required
```

- [ ] **Step 3: Update the "verifier" references**

Replace:
```
If the verifier indicated PLONK verification is needed, include the build output path in the report so the verifier can pass it to the zkir-checker:
```

With:
```
If the orchestrator indicated PLONK verification is needed, include the build output path in the report so the orchestrator can pass it to @"midnight-verify:zkir-checker (agent)":
```

Replace:
```
Do NOT remove the base workspace — it's shared across jobs. If the verifier needs the build output for zkir-checker, do NOT clean up until the verifier confirms the zkir-checker is done.
```

With:
```
Do NOT remove the base workspace — it's shared across jobs. If the orchestrator needs the build output for @"midnight-verify:zkir-checker (agent)", do NOT clean up until the orchestrator confirms the zkir-checker is done.
```

- [ ] **Step 4: Update the frontmatter description**

Replace:
```
  executes the circuit with the witness via JS runtime, and optionally
  dispatches to sdk-tester for devnet E2E. Loaded by the witness-verifier agent.
```

With:
```
  executes the circuit with the witness via JS runtime, and recommends
  devnet E2E to the orchestrator if needed. Loaded by the
  @"midnight-verify:witness-verifier (agent)".
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-witness/SKILL.md
git commit -m "refactor(midnight-verify): fix verify-by-witness Phase 5 — recommend instead of dispatch

The witness-verifier subagent cannot dispatch other agents. Phase 5
now recommends devnet E2E to the orchestrator instead of dispatching
sdk-tester directly."
```

---

### Task 12: Update verify-by-devnet skill references

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-devnet/SKILL.md`

- [ ] **Step 1: Update the frontmatter description**

Replace:
```
  References midnight-tooling:devnet for infrastructure management.
```

With:
```
  Loads the `midnight-tooling:devnet` skill for infrastructure management.
```

- [ ] **Step 2: Update skill references to be explicit**

Replace:
```
Load `midnight-tooling:devnet` skill for endpoint URLs and health check patterns.
```

With:
```
Load the `midnight-tooling:devnet` skill for endpoint URLs and health check patterns.
```

Replace:
```
- Message: "Devnet not available. Start it with `midnight-tooling:devnet` and retry."
```

With:
```
- Message: "Devnet not available. Load the `midnight-tooling:devnet` skill for instructions on starting the devnet, then retry."
```

Replace:
```
// 2. Set up providers (reference midnight-tooling:devnet for URLs)
```

With:
```
// 2. Set up providers (load the `midnight-tooling:devnet` skill for URLs)
```

Replace:
```
2. **Write and compile a minimal contract** using `compact compile --skip-zk` — load `midnight-tooling:compact-cli` for compilation details
```

With:
```
2. **Write and compile a minimal contract** using `compact compile --skip-zk` — load the `midnight-tooling:compact-cli` skill for compilation details
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-devnet/SKILL.md
git commit -m "refactor(midnight-verify): make verify-by-devnet skill references explicit"
```

---

### Task 13: Update verify-by-execution and verify-by-cli-execution skill references

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-execution/SKILL.md`
- Modify: `plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md`

- [ ] **Step 1: Update verify-by-execution skill references**

In `skills/verify-by-execution/SKILL.md`:

Replace:
```
Or load `midnight-tooling:compact-cli` for details on version management.
```

With:
```
Or load the `midnight-tooling:compact-cli` skill for details on version management.
```

Replace:
```
Load `midnight-tooling:compact-cli` skill (via Skill tool) for compilation flags, version management, and troubleshooting.
```

With:
```
Load the `midnight-tooling:compact-cli` skill for compilation flags, version management, and troubleshooting.
```

Update the hints list in the frontmatter/intro to add "skill" suffix where needed. The skill references at lines 27-31 should read:

```
- `compact-core:compact-standard-library` skill — expected function signatures, what exists
- `compact-core:compact-structure` skill — how to structure a contract (pragma, imports, exports)
- `compact-core:compact-language-ref` skill — syntax reference, type system, operators
- `compact-core:compact-privacy-disclosure` skill — disclosure rules to test
- `compact-core:compact-compilation` skill — expected compiler behavior
```

- [ ] **Step 2: Update verify-by-cli-execution skill references**

In `skills/verify-by-cli-execution/SKILL.md`:

Replace:
```
You may consult `midnight-tooling:compact-cli` to understand what flags exist and how the CLI works. This is a **hint only** — the CLI output is your evidence, not the skill content.
```

With:
```
You may load the `midnight-tooling:compact-cli` skill to understand what flags exist and how the CLI works. This is a **hint only** — the CLI output is your evidence, not the skill content.
```

Replace:
```
midnight-tooling:install-cli and retry.
```

With:
```
Load the `midnight-tooling:install-cli` skill for installation instructions and retry.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-execution/SKILL.md plugins/midnight-verify/skills/verify-by-cli-execution/SKILL.md
git commit -m "refactor(midnight-verify): make skill references explicit in verify-by-execution and verify-by-cli-execution"
```

---

### Task 14: Update all 7 agent files

**Files:**
- Modify: `plugins/midnight-verify/agents/contract-writer.md`
- Modify: `plugins/midnight-verify/agents/source-investigator.md`
- Modify: `plugins/midnight-verify/agents/type-checker.md`
- Modify: `plugins/midnight-verify/agents/cli-tester.md`
- Modify: `plugins/midnight-verify/agents/sdk-tester.md`
- Modify: `plugins/midnight-verify/agents/witness-verifier.md`
- Modify: `plugins/midnight-verify/agents/zkir-checker.md`

- [ ] **Step 1: Update contract-writer.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

In the body, replace:
```
You may load compact-core skills as hints for writing correct Compact code, but the test result is your evidence, not the skill content.
```

With:
```
You may load compact-core skills as hints for writing correct Compact code, but the test result is your evidence, not skill content.
```

(This line is already close — just confirm "the skill content" → "skill content" for consistency.)

- [ ] **Step 2: Update source-investigator.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

In the body, make skill references explicit:

Replace:
```
Load the `midnight-verify:verify-by-source` skill and follow it step by step.
```
This is already correct — keep it.

Replace:
```
**When the claim domain is wallet SDK**, load `midnight-verify:verify-by-wallet-source` instead of `midnight-verify:verify-by-source`.
```

With:
```
**When the claim domain is wallet SDK**, load the `midnight-verify:verify-by-wallet-source` skill instead of the `midnight-verify:verify-by-source` skill.
```

Replace:
```
**When the claim domain is ledger/protocol**, load `midnight-verify:verify-by-ledger-source` instead of `midnight-verify:verify-by-source`.
```

With:
```
**When the claim domain is ledger/protocol**, load the `midnight-verify:verify-by-ledger-source` skill instead of the `midnight-verify:verify-by-source` skill.
```

- [ ] **Step 3: Update type-checker.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

- [ ] **Step 4: Update cli-tester.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

Replace:
```
You may load `midnight-tooling:compact-cli` as a hint for understanding CLI flags, compilation patterns, and version management. But the CLI output is your evidence, not the skill content.
```

With:
```
You may load the `midnight-tooling:compact-cli` skill as a hint for understanding CLI flags, compilation patterns, and version management. But the CLI output is your evidence, not skill content.
```

- [ ] **Step 5: Update sdk-tester.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

- [ ] **Step 6: Update witness-verifier.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

In the body, replace:
```
- You may load `compact-core:compact-witness-ts` as a hint for understanding witness patterns, but your verification results are the evidence, not skill content.
```

With:
```
- You may load the `compact-core:compact-witness-ts` skill as a hint for understanding witness patterns, but your verification results are the evidence, not skill content.
```

Replace Phase 5 reference:
```
5. **Optional Devnet E2E** — dispatch to sdk-tester if devnet is available
```

With:
```
5. **Devnet E2E Recommendation** — recommend devnet E2E to the orchestrator if the claim would benefit from it (you cannot dispatch other agents)
```

- [ ] **Step 7: Update zkir-checker.md**

In the description, replace `Dispatched by the verifier orchestrator agent.` with `Dispatched by the /verify command.`

Replace:
```
- You may load compact-core skills as hints for writing Compact test contracts, but test results and checker verdicts are your evidence, not skill content.
```

(This is already correct. Confirm no changes needed.)

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-verify/agents/contract-writer.md plugins/midnight-verify/agents/source-investigator.md plugins/midnight-verify/agents/type-checker.md plugins/midnight-verify/agents/cli-tester.md plugins/midnight-verify/agents/sdk-tester.md plugins/midnight-verify/agents/witness-verifier.md plugins/midnight-verify/agents/zkir-checker.md
git commit -m "refactor(midnight-verify): update all agent files — remove verifier references, explicit skill names"
```

---

### Task 15: Update zkir-regression skill

**Files:**
- Modify: `plugins/midnight-verify/skills/zkir-regression/SKILL.md`

- [ ] **Step 1: Update frontmatter description**

Replace:
```
  Run a curated set of verification claims against the current toolchain to
  detect behavioral changes. Each claim is verified through the normal
  verification pipeline (verifier → agents → checker/execution). Supports
  full sweep (all categories) and targeted sweep (single category). Invocable
  as /midnight-verify:zkir-regression or loadable by agents as a sense-check
  when they suspect toolchain issues.
```

With:
```
  Run a curated set of verification claims against the current toolchain to
  detect behavioral changes. Each claim is verified through the normal
  verification pipeline (classify → dispatch agent → verify). Supports
  full sweep (all categories) and targeted sweep (single category). Invocable
  as /midnight-verify:zkir-regression or loadable as a sense-check when
  toolchain issues are suspected.
```

- [ ] **Step 2: Update Step 3**

Replace:
```
For each claim in the list below (filtered by category if targeted), dispatch the `midnight-verify:verifier` agent with:
- The claim text
- Instruction to verify using the appropriate method
```

With:
```
For each claim in the list below (filtered by category if targeted):

1. Load the `midnight-verify:verify-correctness` skill to classify the claim domain
2. Load the appropriate domain skill
3. Dispatch the sub-agent(s) indicated by the domain skill's routing table
4. Collect the verdict

This follows the same flow as the `/verify` command — you are the orchestrator for each claim.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/zkir-regression/SKILL.md
git commit -m "refactor(midnight-verify): update zkir-regression to use direct orchestration instead of verifier agent"
```

---

### Task 16: Create SubagentStop hook script — contract-writer

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-contract-writer.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:contract-writer
# Verifies the agent actually compiled and set up the runtime (not just guessing from skills)

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Must have set up or verified the compact-runtime package
if ! echo "$CONTENT" | grep -qE 'npm install @midnight-ntwrk/compact-runtime|npm ls @midnight-ntwrk/compact-runtime'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-execution` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Check 2: Must have run compact compile
if ! echo "$CONTENT" | grep -qE 'compact compile'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-execution` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-contract-writer.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-contract-writer.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for contract-writer agent"
```

---

### Task 17: Create SubagentStop hook script — source-investigator

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-source-investigator.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:source-investigator
# Verifies the agent actually inspected source code (not just guessing from skills)

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Must have used octocode-mcp tools OR cloned a repo
if ! echo "$CONTENT" | grep -qE 'mcp__octocode-mcp__githubSearchCode|mcp__octocode-mcp__githubGetFileContent|mcp__octocode-mcp__githubViewRepoStructure|git clone'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-source` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-source-investigator.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-source-investigator.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for source-investigator agent"
```

---

### Task 18: Create SubagentStop hook script — type-checker

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-type-checker.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:type-checker
# Verifies the agent actually ran the TypeScript compiler

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Must have run tsc (covers tsc --noEmit, npx tsc, etc.)
if ! echo "$CONTENT" | grep -qE 'tsc'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-type-check` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-type-checker.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-type-checker.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for type-checker agent"
```

---

### Task 19: Create SubagentStop hook script — cli-tester

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-cli-tester.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:cli-tester
# Verifies the agent actually ran Compact CLI commands

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Must have run compact or compactc
if ! echo "$CONTENT" | grep -qE 'compact |compactc '; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-cli-execution` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-cli-tester.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-cli-tester.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for cli-tester agent"
```

---

### Task 20: Create SubagentStop hook script — sdk-tester

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-sdk-tester.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:sdk-tester
# Verifies the agent set up a workspace and loaded the devnet skill

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Must have created the workspace directory
if ! echo "$CONTENT" | grep -qE 'mkdir -p .midnight-expert/verify/sdk-workspace|mkdir -p .midnight-expert/verify/wallet-sdk-workspace'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-devnet` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Check 2: Must have loaded the devnet skill
if ! echo "$CONTENT" | grep -qE 'midnight-tooling:devnet'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-devnet` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-sdk-tester.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-sdk-tester.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for sdk-tester agent"
```

---

### Task 21: Create SubagentStop hook script — witness-verifier

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-witness-verifier.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:witness-verifier
# Verifies the agent compiled the contract AND type-checked the witness

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Must have compiled the contract
if ! echo "$CONTENT" | grep -qE 'compact compile'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-witness` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Check 2: Must have run the TypeScript compiler
if ! echo "$CONTENT" | grep -qE 'tsc'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-witness` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-witness-verifier.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-witness-verifier.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for witness-verifier agent"
```

---

### Task 22: Create SubagentStop hook script — zkir-checker

**Files:**
- Create: `plugins/midnight-verify/hooks/subagent-stop-zkir-checker.sh`

- [ ] **Step 1: Create the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# SubagentStop hook for midnight-verify:zkir-checker
# Verifies the agent compiled a contract AND set up the ZKIR checker

INPUT=$(cat)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.agent_transcript_path // empty')

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  exit 0  # No transcript available, allow
fi

CONTENT=$(cat "$TRANSCRIPT")

# Check 1: Must have compiled a contract
if ! echo "$CONTENT" | grep -qE 'compact compile'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-zkir-checker` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

# Check 2: Must have set up or verified the zkir-v2 package
if ! echo "$CONTENT" | grep -qE 'npm install @midnight-ntwrk/zkir-v2|npm ls @midnight-ntwrk/zkir-v2'; then
  cat >&2 <<'EOF'
{"decision":"block","reason":"You must follow the process as described in the `midnight-verify:verify-by-zkir-checker` skill. Do not attempt to take shortcuts. Only verifications which have followed the process will be accepted and not blocked."}
EOF
  exit 2
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-verify/hooks/subagent-stop-zkir-checker.sh
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/subagent-stop-zkir-checker.sh
git commit -m "feat(midnight-verify): add SubagentStop hook for zkir-checker agent"
```

---

### Task 23: Update hooks.json with SubagentStop entries

**Files:**
- Modify: `plugins/midnight-verify/hooks/hooks.json`

- [ ] **Step 1: Add SubagentStop entries**

Replace the entire content of `hooks/hooks.json` with:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "WARNING: Your training data about Midnight, Compact, and the Midnight SDK is UNRELIABLE. It contains known errors and is likely outdated.\n\nDo NOT trust your recalled knowledge about:\n- Compact syntax, types, or operators\n- Standard library functions (names, signatures, behavior)\n- SDK API signatures, package names, or import paths\n- Tooling behavior, CLI flags, or configuration\n- Privacy/disclosure rules\n- Transaction semantics or protocol behavior\n\nEverything you 'know' about Compact is suspect. Treat your training data as potentially wrong.\n\nBefore presenting ANY Compact code, SDK usage, or Midnight-specific claims to the user:\n1. Verify using /verify or by dispatching the appropriate midnight-verify agent\n2. Compilation alone does NOT prove correctness — code must be compiled AND executed\n3. Prefer skill content from midnight-expert plugins over recalled knowledge, but even skills are hints, not proof\n\nThe cost of checking is low. The cost of presenting wrong information is high. When in doubt, VERIFY."
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-check.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "midnight-verify:contract-writer",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-contract-writer.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "midnight-verify:source-investigator",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-source-investigator.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "midnight-verify:type-checker",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-type-checker.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "midnight-verify:cli-tester",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-cli-tester.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "midnight-verify:sdk-tester",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-sdk-tester.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "midnight-verify:witness-verifier",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-witness-verifier.sh",
            "timeout": 10
          }
        ]
      },
      {
        "matcher": "midnight-verify:zkir-checker",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-stop-zkir-checker.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

```bash
cat plugins/midnight-verify/hooks/hooks.json | jq .
```

Expected: Valid JSON output, no errors.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/hooks.json
git commit -m "feat(midnight-verify): add SubagentStop hook entries for all 7 verification agents"
```

---

### Task 24: Version bump and final verification

**Files:**
- Modify: `plugins/midnight-verify/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump version**

In `plugins/midnight-verify/.claude-plugin/plugin.json`, change:

```json
"version": "0.7.0",
```

To:

```json
"version": "0.8.0",
```

- [ ] **Step 2: Run final verification grep**

```bash
# No references to the deleted verifier agent anywhere in the plugin
grep -rn 'midnight-verify:verifier' plugins/midnight-verify/
```

Expected: No matches.

```bash
# No bold-name agent references remaining
grep -rn '\*\*contract-writer\*\*\|\*\*source-investigator\*\*\|\*\*type-checker\*\*\|\*\*cli-tester\*\*\|\*\*sdk-tester\*\*\|\*\*witness-verifier\*\*\|\*\*zkir-checker\*\*\|\*\*deps-maintenance\*\*' plugins/midnight-verify/
```

Expected: No matches.

```bash
# All hook scripts exist and are executable
ls -la plugins/midnight-verify/hooks/subagent-stop-*.sh
```

Expected: 7 executable files.

```bash
# hooks.json is valid
cat plugins/midnight-verify/hooks/hooks.json | jq .type
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/.claude-plugin/plugin.json
git commit -m "chore(midnight-verify): bump version to 0.8.0 for verification process fix"
```
