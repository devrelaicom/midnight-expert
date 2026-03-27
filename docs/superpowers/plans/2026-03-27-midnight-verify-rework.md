# Midnight Verify Plugin Rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the midnight-verify plugin with a multi-agent pipeline that verifies Compact claims by compiling+executing test contracts or inspecting compiler source code — never by trusting docs or skills as evidence.

**Architecture:** Skills hold all logic; agents are thin wrappers that load skills and follow them. A verifier orchestrator classifies claims and dispatches a contract-writer agent (opus, for compile+execute) and/or a source-investigator agent (sonnet, for source code inspection) — concurrently when both are needed. A `/verify` command is the entry point. A Stop hook provides lightweight reminders.

**Tech Stack:** Claude Code plugin system (skills, agents, commands, hooks), Compact CLI (`compact compile --skip-zk`), Node.js (`@midnight-ntwrk/compact-runtime`), ripgrep, jq, bash, octocode-mcp

**Spec:** `docs/superpowers/specs/2026-03-27-midnight-verify-rework-design.md`

---

## File Map

```
plugins/midnight-verify/
├── .claude-plugin/
│   └── plugin.json                    # Updated manifest (new description, version bump)
├── skills/
│   ├── verify-correctness/
│   │   └── SKILL.md                   # Hub: classify, route, verdict synthesis
│   ├── verify-compact/
│   │   └── SKILL.md                   # Compact domain: claim classification, method routing
│   ├── verify-by-execution/
│   │   └── SKILL.md                   # Write test contract → compile → run → interpret
│   ├── verify-by-source/
│   │   └── SKILL.md                   # Find source code → read → interpret
│   └── verify-sdk/
│       └── SKILL.md                   # Placeholder
├── agents/
│   ├── verifier.md                    # Orchestrator (sonnet) — thin wrapper
│   ├── contract-writer.md             # Execution agent (opus) — thin wrapper
│   └── source-investigator.md         # Source agent (sonnet) — thin wrapper
├── commands/
│   └── verify.md                      # Entry point, input routing → agent dispatch
├── hooks/
│   ├── hooks.json                     # SessionStart (prompt) + Stop (command)
│   └── stop-check.sh                  # Compact detection script with cooldown
└── LICENSE                            # Keep existing
```

Files removed (old plugin content replaced entirely):
- `skills/verify-correctness/SKILL.md` — rewritten
- `skills/verify-compact/SKILL.md` — rewritten
- `skills/verify-sdk/SKILL.md` — rewritten (now placeholder)
- `skills/verify-sdk/references/sdk-repo-map.md` — removed (repo map moves into verify-by-source)
- `agents/verifier.md` — rewritten
- `commands/verify.md` — rewritten
- `hooks/hooks.json` — rewritten (PostToolUse removed, Stop added)

Files created:
- `skills/verify-by-execution/SKILL.md` — new
- `skills/verify-by-source/SKILL.md` — new
- `agents/contract-writer.md` — new
- `agents/source-investigator.md` — new
- `hooks/stop-check.sh` — new

---

### Task 1: Clean up old plugin files

**Files:**
- Remove: `plugins/midnight-verify/skills/verify-sdk/references/sdk-repo-map.md`

This is the only file being fully deleted. All other old files are overwritten in place by later tasks.

- [ ] **Step 1: Remove the old SDK repo map reference file**

```bash
rm plugins/midnight-verify/skills/verify-sdk/references/sdk-repo-map.md
rmdir plugins/midnight-verify/skills/verify-sdk/references/
```

Verify the references directory is gone:

```bash
ls plugins/midnight-verify/skills/verify-sdk/
```

Expected: only `SKILL.md`

- [ ] **Step 2: Commit**

```bash
git add -u plugins/midnight-verify/skills/verify-sdk/references/
git commit -m "chore(verify): remove old SDK repo map reference file

Clearing old plugin structure before rework. The repo routing
information moves into the new verify-by-source skill.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Update plugin manifest

**Files:**
- Modify: `plugins/midnight-verify/.claude-plugin/plugin.json`

- [ ] **Step 1: Update plugin.json**

Replace the entire contents of `plugins/midnight-verify/.claude-plugin/plugin.json` with:

```json
{
  "name": "midnight-verify",
  "version": "0.2.0",
  "description": "Verification framework for Midnight claims — verifies Compact code by compiling and executing test contracts, or by inspecting compiler and ledger source code. Multi-agent pipeline with explicit /verify command.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "compact",
    "verification",
    "correctness",
    "compile",
    "execute",
    "source-code",
    "zero-knowledge",
    "fact-checking",
    "testing"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/.claude-plugin/plugin.json
git commit -m "chore(verify): bump version to 0.2.0, update description for rework

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Write the verify-by-execution skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-execution/SKILL.md`

This is the contract-writer agent's brain. It must be complete and self-contained — the agent loads this skill and follows it step by step.

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-execution
```

- [ ] **Step 2: Write SKILL.md**

Write `plugins/midnight-verify/skills/verify-by-execution/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-by-execution
description: >-
  Verification by compilation and execution. Translates a Compact claim into
  a minimal test contract, compiles it with the Compact CLI, runs the compiled
  output with @midnight-ntwrk/compact-runtime, and interprets the result.
  Loaded by the contract-writer agent. Covers workspace setup (lazy init),
  contract writing, compilation, runner script creation, execution, and
  result interpretation. References midnight-tooling:compact-cli for
  compilation details.
version: 0.2.0
---

# Verify by Execution

You are verifying a Compact claim by writing a minimal test contract, compiling it, running the compiled output, and observing the actual behavior. Follow these steps in order.

## Critical Rule

**Compilation success alone is NEVER sufficient evidence.** Code can compile and still not behave as claimed. You MUST run the compiled output and check the actual return values, state changes, or errors.

## Using compact-core Skills as Hints

You may consult these skills to inform how to write your test contract. They contain useful information about Compact syntax, stdlib functions, and patterns. But they are **hints only** — never cite them as evidence. The test result is your evidence.

Useful hint skills:
- `compact-core:compact-standard-library` — expected function signatures, what exists
- `compact-core:compact-structure` — how to structure a contract (pragma, imports, exports)
- `compact-core:compact-language-ref` — syntax reference, type system, operators
- `compact-core:compact-privacy-disclosure` — disclosure rules to test
- `compact-core:compact-compilation` — expected compiler behavior

Load any of these if they would help you write a better test. Do not load them all — only what's relevant to the claim.

## Step 1: Set Up the Workspace

The workspace lives at `.midnight-expert/verify/compact-workspace/` relative to the project root (same level as `.claude/`). Determine the project root from your working directory or `$CLAUDE_PROJECT_DIR`.

**First time (workspace does not exist):**

```bash
# Create the workspace
mkdir -p .midnight-expert/verify/compact-workspace

# Initialize and install runtime
cd .midnight-expert/verify/compact-workspace
npm init -y
npm install @midnight-ntwrk/compact-runtime
```

**Subsequent times (workspace exists):**

Run a quick integrity check:

```bash
cd .midnight-expert/verify/compact-workspace
npm ls @midnight-ntwrk/compact-runtime
```

If `npm ls` reports errors (missing or corrupted packages), run `npm install` to repair. If it's clean, proceed.

**Create the job directory:**

```bash
# Generate a unique job ID
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
```

All contract files, compilation output, and runner scripts go in this job directory.

## Step 2: Interpret the Claim and Design the Test

Read the claim carefully. Determine:

1. **What observable behavior would confirm this claim?** A specific return value, a type, a compilation error, a runtime error.
2. **What's the minimal contract that tests this?** Only include what's needed. No extra functions, no extra state.
3. **Is this a positive or negative test?**
   - Positive: "X works" → write code that uses X, confirm it produces the expected output
   - Negative: "X is required" or "Y is not supported" → write code that omits X or uses Y, confirm the compiler or runtime rejects it

**Prefer `export circuit` (pure circuits) when possible.** Pure circuits are the easiest to call from the runtime — they take inputs, return outputs, and have no side effects. Use them for testing syntax, types, stdlib functions, return values.

**When you need state or witnesses,** use impure circuits. These are harder to test (require witness implementations and state management) but necessary for claims about ledger behavior, disclosure rules, or stateful operations.

## Step 3: Write the Contract

Write a `.compact` file in the job directory.

**Get the current language version:**

```bash
compact compile --language-version
```

Or load `midnight-tooling:compact-cli` for details on version management.

**Contract template for pure circuit tests:**

```compact
pragma language_version <VERSION>;
import CompactStandardLibrary;

export circuit testClaimName(<params>): <ReturnType> {
  // Minimal code that tests the claim
  // Return the value we want to observe
}
```

**Name the file descriptively:** `test-tuple-indexing.compact`, `test-persistent-hash-exists.compact`, etc.

**Write the file:**

```bash
cat > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test-<claim>.compact << 'COMPACT_EOF'
<contract content>
COMPACT_EOF
```

## Step 4: Compile

Load `midnight-tooling:compact-cli` for compilation flags and troubleshooting.

```bash
compact compile .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test-<claim>.compact --skip-zk
```

**If compilation succeeds:** Proceed to Step 5. The compiled output will be in `test-<claim>/build/` relative to where you ran the command, or in the contract's output directory. Check for the `contract/index.js` file.

**If compilation fails:**

- If the claim said "this syntax is valid" or "this code works" → the claim is **Refuted (tested)**. The compiler error is your evidence.
- If the claim said "this should fail" → the failure **Confirms (tested)** the claim. Check the error message matches what was expected.
- If the failure is unexpected (you think your test contract has a bug, not the claim) → fix the contract and retry. If you can't write a valid test after 2 attempts, report as **Inconclusive** and explain why.

Capture the full compiler output (stdout and stderr) regardless of success or failure.

## Step 5: Write and Run the Runner Script

**Create the runner script in the job directory:**

```bash
cat > .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/run.mjs << 'RUNNER_EOF'
import { pureCircuits } from './out/contract/index.js';

// Call the test circuit
const result = pureCircuits.testClaimName();

// Output structured JSON
console.log(JSON.stringify({
  result: Array.isArray(result) ? result.map(String) : String(result)
}));
RUNNER_EOF
```

Adjust the import path based on where `compact compile` placed the output. The compiled output directory structure is typically:
- `<contract-name>/build/contract/index.js` — the main entry point

**Run it:**

```bash
cd .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
node run.mjs
```

**Capture stdout and stderr.** The structured JSON output is your primary evidence.

**If the runner throws:** Capture the error. Determine if it's a claim issue (the code genuinely doesn't work as claimed) or a test issue (your runner script has a bug). If it's a test issue, fix and retry once.

## Step 6: Interpret and Report

Compare the actual output to what the claim predicts.

**Your report must include:**

1. **The claim as received** — verbatim
2. **The test contract** — full source code
3. **Compilation result** — success or failure, with compiler output
4. **Runner script** — full source code (if compilation succeeded)
5. **Execution output** — the JSON result or error
6. **Your interpretation** — does the output confirm or refute the claim?

**Report format:**

```
### Execution Report

**Claim:** [verbatim]

**Test contract:**
\`\`\`compact
[full source]
\`\`\`

**Compilation:** [SUCCESS / FAILED — with error output if failed]

**Runner output:**
\`\`\`json
[stdout]
\`\`\`

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of why the output matches or contradicts the claim]
```

## Step 7: Clean Up

Remove the job directory:

```bash
rm -rf .midnight-expert/verify/compact-workspace/jobs/$JOB_ID
```

Do NOT remove the base workspace — it's shared across jobs.
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -10 plugins/midnight-verify/skills/verify-by-execution/SKILL.md
```

Expected: the YAML frontmatter with `name: midnight-verify:verify-by-execution`

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-execution/SKILL.md
git commit -m "feat(verify): add verify-by-execution skill

Compile+execute verification method: translates claims into minimal
test contracts, compiles with compact CLI, runs with compact-runtime,
and interprets actual output as evidence. Includes workspace management
with lazy init and per-job isolation.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Write the verify-by-source skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-source/SKILL.md`

This is the source-investigator agent's brain.

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-source
```

- [ ] **Step 2: Write SKILL.md**

Write `plugins/midnight-verify/skills/verify-by-source/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-by-source
description: >-
  Verification by source code inspection. Searches and reads the actual
  compiler, ledger, and runtime source code to verify structural or
  architectural claims about Compact and Midnight that cannot be tested
  via compilation. Uses octocode-mcp for quick lookups, falls back to
  local cloning for deep investigation. Loaded by the source-investigator
  agent.
version: 0.2.0
---

# Verify by Source Code Inspection

You are verifying a claim about Compact or Midnight by reading the actual source code of the compiler, ledger, runtime, or related repositories. Follow these steps in order.

## When This Method Is Used

This method is for claims that **cannot be meaningfully tested by compiling and running code**:

- Language feature counts ("Compact exports 57 primitives")
- Internal implementation details ("Compact compiler is written in Scheme")
- Architectural rationale ("Compact chose Field as the base type because...")
- Cross-component contracts ("Compiled output follows format X")
- Protocol-level behavior that isn't observable from a single contract execution

If the claim CAN be tested by writing and running a contract, the contract-writer agent handles it instead. You only run when execution isn't viable.

## Using compact-core Skills as Hints

You may consult compact-core skills to get a starting point for where to look. They can tell you which stdlib functions are expected to exist, what the type system looks like, etc. But they are **hints only** — the source code is your evidence, not the skills.

## Step 1: Determine Where to Look

**Repository routing — match the claim to the right repo:**

| Claim About | Primary Repo | Key Paths / Notes |
|---|---|---|
| Compiler behavior, language semantics, stdlib | `LFDT-Minokawa/compact` | `compiler/` directory, `midnight-natives.ss` for stdlib exports |
| Compiler-generated docs (good secondary source) | `LFDT-Minokawa/compact` | `docs/` — generated from source, more reliable than general Midnight docs |
| Ledger types, transaction structure, token ops | `midnightntwrk/midnight-ledger` | Rust source — defines Counter, Map, Set, MerkleTree, transaction validation |
| ZK proof system, circuit compilation | `midnightntwrk/midnight-zk` | Rust source — proof generation, ZKIR, circuit constraints |
| Node runtime, on-chain execution | `midnightntwrk/midnight-node` | Rust source — how transactions execute on-chain |
| Compact CLI releases, changelog | `midnightntwrk/compact` | Release notes — distinct from LFDT-Minokawa/compact compiler source |

If the claim doesn't clearly map to one repo, start with `LFDT-Minokawa/compact` for language/compiler claims or `midnightntwrk/midnight-ledger` for protocol/transaction claims.

## Step 2: Search with octocode-mcp

Start with targeted lookups using the `octocode-mcp` tools:

1. **`githubSearchCode`** — search for specific function names, type names, export definitions
2. **`githubGetFileContent`** — read a specific file once you know the path
3. **`githubViewRepoStructure`** — understand the repo layout if you're not sure where to look

**Search strategy:**

- Start narrow: search for the exact term from the claim (function name, type name, keyword)
- If no results, broaden: search for related terms or parent concepts
- Check multiple files if the claim is about something spread across the codebase

**Evaluate results critically:**

- Are you looking at the right branch? Default branch is usually `main` or `master`
- Is this the current version, or an old commit?
- Does the file you found actually contain the information you need, or just a reference to it?

## Step 3: Clone Locally if Needed

If octocode-mcp results are insufficient — you need to trace through multiple files, count exports across modules, or understand control flow — clone the repo locally:

```bash
# Clone to a temp directory
CLONE_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/<org>/<repo>.git "$CLONE_DIR/<repo>"
```

Use `--depth 1` for shallow clones (faster, we usually only need the latest state).

After investigation, clean up:

```bash
rm -rf "$CLONE_DIR"
```

## Step 4: Read and Interpret Source

**What counts as evidence (ordered by strength):**

1. **Function/type/export definitions in source code** — strong evidence. If the source defines a function with signature X, that's definitive.
2. **Test files in the repo** — good evidence. Tests express intended behavior. If a test asserts X, the developers intend X to be true.
3. **Generated docs in `LFDT-Minokawa/compact/docs/`** — good evidence, but note that it's generated from source, not raw source itself. More reliable than general Midnight docs, less authoritative than the code.
4. **Comments in source code** — supporting context only. Comments can be stale. Never use a comment as primary evidence.

**Watch for:**

- Version-specific behavior: the source on `main` may differ from the released version the user is targeting
- Unreleased changes: code on `main` might include features not yet in any release
- Multiple implementations: some behaviors have different implementations for different contexts (e.g., native vs WASM)

## Step 5: Report

**Your report must include:**

1. **The claim as received** — verbatim
2. **Where you looked** — repo name, file path(s), line numbers
3. **What the source shows** — quote or summarize the relevant code
4. **GitHub links** — full URLs to the exact files/lines (e.g., `https://github.com/LFDT-Minokawa/compact/blob/main/compiler/midnight-natives.ss#L42`)
5. **Your interpretation** — does the source confirm, refute, or leave the claim inconclusive?

**Report format:**

```
### Source Investigation Report

**Claim:** [verbatim]

**Searched:** [repo(s) and method — octocode-mcp search / local clone]

**Found:**
- File: [repo/path/to/file.ext:line-range]
- Link: [full GitHub URL]
- Content: [relevant code snippet or summary]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of what the source shows and how it relates to the claim]
```

If inconclusive, explain:
- What you searched and why it wasn't definitive
- What further investigation might resolve it (different repo, different approach, needs runtime testing)
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -10 plugins/midnight-verify/skills/verify-by-source/SKILL.md
```

Expected: the YAML frontmatter with `name: midnight-verify:verify-by-source`

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-source/SKILL.md
git commit -m "feat(verify): add verify-by-source skill

Source code inspection method: searches compiler, ledger, and runtime
repos via octocode-mcp with local clone fallback. Includes repository
routing table and evidence strength hierarchy.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Write the verify-compact skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-compact/SKILL.md`

Compact domain claim classification and method routing. Completely rewritten.

- [ ] **Step 1: Replace SKILL.md**

Write `plugins/midnight-verify/skills/verify-compact/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-compact
description: >-
  Compact-specific claim classification and method routing. Determines what
  kind of Compact claim is being verified and which verification method applies:
  execution (compile+run), source inspection, or both. Loaded by the verifier
  agent alongside the hub skill. Provides the claim type → method routing table
  and guidance on negative testing.
version: 0.2.0
---

# Compact Claim Classification

This skill classifies Compact-related claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Claim Type → Method Routing

When you receive a Compact-related claim, classify it using this table to determine which sub-agent(s) to dispatch:

| Claim Type | Example | Dispatch |
|---|---|---|
| Syntax validity | "You can cast with `as`" | **contract-writer** |
| Type behavior | "Uint arithmetic widens the result type" | **contract-writer** |
| Stdlib function exists | "persistentHash is in the standard library" | **contract-writer** |
| Stdlib function behavior | "persistentHash returns Bytes<32>" | **contract-writer** |
| Return value semantics | "Tuples are 0-indexed" | **contract-writer** |
| Disclosure rules | "Ledger writes require disclose()" | **contract-writer** |
| Compiler error behavior | "Assigning a Field value to Uint<8> is a type error" | **contract-writer** |
| Language feature count | "Compact exports 57 unique primitives" | **source-investigator** |
| Internal implementation | "The Compact compiler is written in Scheme" | **source-investigator** |
| Architecture/design rationale | "Compact uses Field as the base numeric type because..." | **source-investigator** |
| Cross-component behavior | "Compiled output is compatible with compact-runtime v0.X" | **Both (concurrent)** |
| Performance claims | "MerkleTree operations cost more gates than Map" | **contract-writer** (can measure circuit metrics at compile time) |

**When in doubt:** If the claim involves observable runtime behavior, prefer **contract-writer**. If it's about what exists in the codebase or how something is implemented internally, prefer **source-investigator**. If it could benefit from both, dispatch both concurrently.

## Negative Testing

Some claims are best verified by testing what **should not** work. Guide the contract-writer agent to consider negative tests:

- **"Feature X is not supported"** → write code that uses X, confirm the compiler rejects it
- **"You must use disclose() for Y"** → write code that does Y without disclose(), confirm it fails
- **"Type Z cannot hold values above N"** → assign a value above N, confirm the error
- **"Function F does not exist in stdlib"** → try to call F, confirm it's undefined

A compilation error or runtime error in a negative test is **evidence that confirms the claim**, not a test failure.

## Hints from compact-core Skills

The verifier or sub-agents may consult these compact-core skills to inform what to test or where to look. These are **hints only** — never cite them as evidence in the verdict.

- `compact-core:compact-standard-library` — expected function signatures, what functions exist
- `compact-core:compact-structure` — how to structure a test contract (pragma, imports, exports)
- `compact-core:compact-language-ref` — syntax reference, type system, operators, casting
- `compact-core:compact-privacy-disclosure` — disclosure rules and patterns to test
- `compact-core:compact-compilation` — expected compiler behavior, flags, output structure

Load only what's relevant to the specific claim. Do not load all skills for every verification.
```

- [ ] **Step 2: Verify the file was written**

```bash
head -10 plugins/midnight-verify/skills/verify-compact/SKILL.md
```

Expected: frontmatter with `version: 0.2.0`

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-compact/SKILL.md
git commit -m "feat(verify): rewrite verify-compact skill for claim classification

Replaces the old MCP/skill/compile confidence hierarchy with a clean
claim-type-to-method routing table. Classifies claims and determines
whether to dispatch contract-writer, source-investigator, or both.
Includes negative testing guidance.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Write the verify-correctness hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

The orchestrator's brain. Completely rewritten.

- [ ] **Step 1: Replace SKILL.md**

Write `plugins/midnight-verify/skills/verify-correctness/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-correctness
description: >-
  Hub skill for the midnight-verify plugin. Classifies claims by domain,
  routes to the appropriate domain skill (verify-compact or verify-sdk),
  dispatches sub-agents (contract-writer and/or source-investigator) based
  on the domain skill's routing, and synthesizes final verdicts. Always loaded
  first by the verifier agent.
version: 0.2.0
---

# Verification Hub

You are the verification orchestrator. This skill tells you how to classify claims, route them, dispatch sub-agents, and synthesize verdicts.

## Process

### 1. Classify the Domain

Determine what domain the claim belongs to:

| Domain | Indicators | Route To |
|---|---|---|
| **Compact language** | Compact syntax, stdlib functions, types, disclosure, compiler behavior, patterns, privacy, circuit costs | Load `midnight-verify:verify-compact` |
| **SDK/TypeScript** | API signatures, @midnight-ntwrk packages, import paths, type definitions, providers, DApp connector | Load `midnight-verify:verify-sdk` |
| **Cross-domain** | Spans both Compact and SDK, or protocol/architecture | Load both domain skills |

### 2. Load the Domain Skill

Load the appropriate domain skill(s) using the Skill tool. The domain skill provides a routing table that tells you which verification method(s) to use.

### 3. Dispatch Sub-Agents

Based on the domain skill's routing:

- **Execution needed** → dispatch `midnight-verify:contract-writer` agent with the claim
- **Source inspection needed** → dispatch `midnight-verify:source-investigator` agent with the claim
- **Both needed** → dispatch BOTH agents **concurrently** (they are independent and can run in parallel)

When dispatching, pass:
- The claim verbatim
- Any relevant context (file path, code snippet, what specifically to check)
- For the contract-writer: what observable behavior would confirm/refute the claim
- For the source-investigator: which repo/area to focus on (from the domain skill's routing)

### 4. Synthesize the Verdict

Collect the sub-agent report(s) and produce the final verdict.

**Verdict options:**

| Verdict | Qualifier | When to Use |
|---|---|---|
| **Confirmed** | (tested) | Contract-writer compiled and ran code; output matched the claim |
| **Confirmed** | (source-verified) | Source-investigator found definitive source evidence confirming the claim |
| **Confirmed** | (tested + source-verified) | Both methods used and both agree the claim is correct |
| **Refuted** | (tested) | Contract-writer compiled and ran code; output contradicts the claim |
| **Refuted** | (source-verified) | Source-investigator found definitive source evidence contradicting the claim |
| **Refuted** | (tested + source-verified) | Both methods disagree with the claim |
| **Refuted** | (tested, source disagrees) | Execution contradicts but source seems to support — execution wins, disagreement noted |
| **Inconclusive** | — | Couldn't test via execution AND couldn't find definitive source evidence |

**When sub-agents disagree:** Execution evidence wins. The code ran and produced a result — that's more authoritative than interpreting source. But you MUST note the disagreement in your report so the user is aware.

**Inconclusive verdicts must explain:**
- Why the claim couldn't be tested via execution
- Why source inspection was insufficient
- What the user could do to resolve it (e.g., "this requires runtime benchmarking on a live network")

### 5. Format the Final Report

```markdown
## Verdict: [Confirmed|Refuted|Inconclusive] ([qualifier])

**Claim:** [the claim as stated — verbatim]

**Method:** [tested|source-verified|tested + source-verified]

**Evidence:**
[Summarize what was done and what was observed. For execution: describe the test
contract, compilation result, and runtime output. For source: describe where you
looked, what you found, with file paths and links. Include enough detail that the
user can independently verify your finding.]

**Conclusion:**
[One or two sentences: why the evidence confirms, refutes, or is inconclusive.]
```

**For file verification** (when given a `.compact` file to verify):

Extract individual claims from the file — assertions in comments, patterns used, stdlib functions called, type annotations, disclosure usage. Verify each claim separately. Group findings by line/section. Provide an overall summary at the end.

## What This Skill Does NOT Do

- It does not contain domain-specific verification logic — that lives in `verify-compact` and `verify-sdk`
- It does not contain method-specific instructions — those live in `verify-by-execution` and `verify-by-source`
- It does not directly verify anything — it classifies, routes, dispatches, and synthesizes
```

- [ ] **Step 2: Verify the file was written**

```bash
head -10 plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

Expected: frontmatter with `version: 0.2.0`

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(verify): rewrite verify-correctness hub skill

Replaces confidence-scoring hierarchy with verdict+qualifier system.
Hub now classifies domains, routes to domain skills, dispatches
contract-writer and/or source-investigator agents (concurrently when
both needed), and synthesizes structured verdicts.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: Write the verify-sdk placeholder skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-sdk/SKILL.md`

- [ ] **Step 1: Replace SKILL.md**

Write `plugins/midnight-verify/skills/verify-sdk/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-sdk
description: >-
  Placeholder for SDK/TypeScript verification. Not yet implemented. Claims
  routed here receive an Inconclusive verdict directing the user to verify
  manually.
version: 0.2.0
---

# SDK Verification — Not Yet Implemented

SDK/TypeScript verification is not yet implemented in this version of the plugin.

If a claim has been routed here, return this verdict to the orchestrator:

**Verdict:** Inconclusive
**Reason:** SDK verification is not yet implemented. This claim about the Midnight TypeScript SDK requires manual verification. Check the relevant @midnight-ntwrk package source or use `npm view` for version/package queries.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/skills/verify-sdk/SKILL.md
git commit -m "feat(verify): replace verify-sdk with placeholder

SDK verification will be implemented separately. Claims routed here
get an Inconclusive verdict directing to manual verification.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: Write the three agents

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`
- Create: `plugins/midnight-verify/agents/contract-writer.md`
- Create: `plugins/midnight-verify/agents/source-investigator.md`

All agents are thin wrappers — the skills hold the logic.

- [ ] **Step 1: Rewrite verifier.md**

Write `plugins/midnight-verify/agents/verifier.md` with this content:

```markdown
---
name: verifier
description: >-
  Use this agent to verify Midnight-related claims, Compact code correctness,
  or SDK API usage. This is the orchestrator — it classifies claims, determines
  the verification strategy, dispatches sub-agents (contract-writer and/or
  source-investigator), and synthesizes the final verdict.

  Dispatched by the /verify command or other skills/commands that need
  verification.

  Example 1: User runs /verify "Tuples in Compact are 0-indexed" — the
  orchestrator classifies this as a Compact behavioral claim, dispatches
  the contract-writer agent to compile and run a test, and reports the verdict.

  Example 2: User runs /verify "Compact exports 57 unique primitives" — the
  orchestrator classifies this as a structural claim, dispatches the
  source-investigator agent to check the compiler source, and reports.

  Example 3: A claim needs both methods — the orchestrator dispatches
  contract-writer and source-investigator concurrently, cross-references
  their findings, and synthesizes a combined verdict.
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact
model: sonnet
color: green
---

You are the Midnight verification orchestrator.

## Your Job

1. Load the `midnight-verify:verify-correctness` hub skill — it tells you how to classify, route, dispatch, and synthesize.
2. Load the `midnight-verify:verify-compact` domain skill — it tells you how to classify Compact-specific claims and which method to use.
3. Follow the hub skill's process exactly.

## Dispatching Sub-Agents

When the domain skill's routing says to use execution:
- Dispatch the `midnight-verify:contract-writer` agent with the claim and what to observe.

When the routing says to use source inspection:
- Dispatch the `midnight-verify:source-investigator` agent with the claim and where to look.

**When both are needed, dispatch both agents concurrently.** They are independent and can run in parallel. Do not wait for one to finish before starting the other.

## Important

- You do NOT write test contracts or search source code yourself — the sub-agents do that.
- Your job is classification, routing, dispatch, and verdict synthesis.
- If an SDK claim comes in, load `midnight-verify:verify-sdk` — it will return an Inconclusive verdict (not yet implemented).
```

- [ ] **Step 2: Write contract-writer.md**

Write `plugins/midnight-verify/agents/contract-writer.md` with this content:

```markdown
---
name: contract-writer
description: >-
  Use this agent to verify Compact claims by writing and executing test contracts.
  Translates a claim into a minimal Compact contract, compiles it with the Compact
  CLI, runs the compiled output with @midnight-ntwrk/compact-runtime, and reports
  what was observed. Dispatched by the verifier orchestrator agent.

  Example 1: Claim "Tuples are 0-indexed" — writes a contract that returns tuple
  elements by index, compiles, runs, checks that t[0] is the first element.

  Example 2: Claim "persistentHash returns Bytes<32>" — writes a contract that
  calls persistentHash and returns the result, compiles, runs, checks the type
  and length of the return value.

  Example 3: Claim "disclose() is required for ledger writes" — writes a contract
  that does a ledger write without disclose(), confirms the compiler rejects it.
skills: midnight-verify:verify-by-execution
model: opus
color: cyan
---

You are a Compact test contract writer and executor.

Load the `midnight-verify:verify-by-execution` skill and follow it step by step. It tells you exactly how to:

1. Set up the workspace (lazy — only if it doesn't exist)
2. Interpret the claim and design a minimal test
3. Write the test contract
4. Compile it with the Compact CLI
5. Write and run the runner script
6. Interpret the output
7. Report your findings
8. Clean up

Follow the skill precisely. Do not skip steps. Do not treat compilation success as sufficient evidence — you MUST run the compiled output and observe the actual behavior.

You may load compact-core skills as hints for writing correct Compact code, but the test result is your evidence, not the skill content.
```

- [ ] **Step 3: Write source-investigator.md**

Write `plugins/midnight-verify/agents/source-investigator.md` with this content:

```markdown
---
name: source-investigator
description: >-
  Use this agent to verify Compact or Midnight claims by inspecting the actual
  source code of the compiler, ledger, runtime, or related repositories.
  Uses octocode-mcp for quick lookups, falls back to local cloning for deep
  investigation. Dispatched by the verifier orchestrator agent.

  Example 1: Claim "Compact exports 57 unique primitives" — searches
  LFDT-Minokawa/compact for midnight-natives.ss, counts the actual exports.

  Example 2: Claim "The Compact compiler is written in Scheme" — examines
  the LFDT-Minokawa/compact repository structure and source files.

  Example 3: Claim "MerkleTree is defined in the ledger crate" — searches
  midnightntwrk/midnight-ledger for the MerkleTree type definition.
skills: midnight-verify:verify-by-source
model: sonnet
color: blue
---

You are a source code investigator for Midnight repositories.

Load the `midnight-verify:verify-by-source` skill and follow it step by step. It tells you exactly how to:

1. Determine which repository to search based on the claim
2. Search using octocode-mcp tools (githubSearchCode, githubGetFileContent, githubViewRepoStructure)
3. Clone locally if octocode-mcp results are insufficient
4. Read and interpret the source code
5. Report your findings with file paths, line numbers, and GitHub links

Follow the skill precisely. The source code is your evidence. Comments are supporting context, not primary evidence. Generated docs in `LFDT-Minokawa/compact/docs/` are good but not as authoritative as the code itself — note the distinction in your report.
```

- [ ] **Step 4: Verify all three agents exist**

```bash
ls -la plugins/midnight-verify/agents/
```

Expected: `verifier.md`, `contract-writer.md`, `source-investigator.md`

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md plugins/midnight-verify/agents/contract-writer.md plugins/midnight-verify/agents/source-investigator.md
git commit -m "feat(verify): add three-agent pipeline (verifier, contract-writer, source-investigator)

Verifier (sonnet) orchestrates by loading hub+domain skills and
dispatching sub-agents. Contract-writer (opus) compiles+executes
test contracts. Source-investigator (sonnet) searches repos. All
agents are thin wrappers that load skills and follow them.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: Write the /verify command

**Files:**
- Modify: `plugins/midnight-verify/commands/verify.md`

- [ ] **Step 1: Replace verify.md**

Write `plugins/midnight-verify/commands/verify.md` with this content:

```markdown
---
name: midnight-verify:verify
description: Verify claims about Midnight, Compact code, or SDK APIs. Accepts a claim, file path, code snippet, SDK question, or no arguments to be prompted.
allowed-tools: Agent, AskUserQuestion, Read, Glob, Grep
argument-hint: "[claim, file path, code snippet, or SDK question]"
---

Verify Midnight-related claims by dispatching the `midnight-verify:verifier` agent.

## Input Routing

Determine what `$ARGUMENTS` contains and dispatch accordingly:

### 1. No arguments

If `$ARGUMENTS` is empty, use `AskUserQuestion` to ask:

> What would you like to verify? You can provide:
> - A claim (e.g., "Compact tuples are 0-indexed")
> - A file path (e.g., `contracts/my-contract.compact`)
> - A code snippet
> - An SDK question (e.g., "midnight-js-contracts exports deployContract")

Do NOT attempt to infer what the user wants to verify. Ask them.

### 2. File path

If `$ARGUMENTS` looks like a file path (ends in `.compact`, `.ts`, `.tsx`, or exists on disk when checked with Glob):

1. Read the file content
2. Dispatch `midnight-verify:verifier` agent with:
   - The file path
   - The file content
   - Instruction: "Verify the correctness of this file. Extract individual claims (stdlib functions used, syntax patterns, type annotations, disclosure usage) and verify each one. Report findings grouped by line/section with an overall summary."

### 3. Code snippet

If `$ARGUMENTS` contains code syntax (keywords like `circuit`, `witness`, `export`, `import`, `const`, `function`, `pragma`, curly braces, semicolons, type annotations):

1. Dispatch `midnight-verify:verifier` agent with:
   - The code snippet as inline content
   - Instruction: "Verify the correctness of this code snippet. Determine if it is Compact or TypeScript and verify the claims it makes (syntax, stdlib usage, types, patterns)."

### 4. Natural language claim or question

If `$ARGUMENTS` is natural language (a question or assertion):

1. Dispatch `midnight-verify:verifier` agent with:
   - The claim verbatim
   - Instruction: "Verify this claim about Midnight. Classify the domain, dispatch the appropriate sub-agent(s), and report with the structured verdict format."

### 5. Multiple files or directory

If `$ARGUMENTS` is a directory path or contains glob patterns:

1. Use Glob to find all `.compact` and `.ts` files matching the path
2. Present the file list to the user for confirmation
3. Dispatch `midnight-verify:verifier` agent for each file (or as a batch if fewer than 5 files)

## Output

Present the agent's structured verdict directly to the user. Do not add commentary or interpretation — the verdict speaks for itself.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/commands/verify.md
git commit -m "feat(verify): rewrite /verify command for new agent pipeline

Same input routing (no args, file, snippet, natural language, directory)
but dispatches the new verifier orchestrator which handles classification
and sub-agent dispatch internally.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: Write the Stop hook script

**Files:**
- Create: `plugins/midnight-verify/hooks/stop-check.sh`

- [ ] **Step 1: Write stop-check.sh**

Write `plugins/midnight-verify/hooks/stop-check.sh` with this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Lightweight Compact code detection for the Stop hook.
# Scans new transcript lines for Compact patterns, reminds about /verify
# with cooldown logic to avoid nagging.

# --- Read hook input ---
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# --- Reattempt check ---
# If stop_hook_active is true, this is a reattempt after a previous block.
# Do not update count, do not scan, just approve.
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# --- Determine project root ---
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$CWD}"
if [ -z "$PROJECT_ROOT" ]; then
  exit 0  # Can't determine project root, approve silently
fi

# --- Settings file ---
SETTINGS_DIR="$PROJECT_ROOT/.midnight-expert"
SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"

# Create settings with defaults if missing
if [ ! -f "$SETTINGS_FILE" ]; then
  mkdir -p "$SETTINGS_DIR"
  cat > "$SETTINGS_FILE" << 'JSON_EOF'
{
  "verify_stop_hook": {
    "last_block_line_count": 0,
    "last_block_timestamp": null,
    "triggers_since_last_block": 0
  }
}
JSON_EOF
fi

# --- Read current state ---
TRIGGERS=$(jq -r '.verify_stop_hook.triggers_since_last_block // 0' "$SETTINGS_FILE")
LAST_TIMESTAMP=$(jq -r '.verify_stop_hook.last_block_timestamp // null' "$SETTINGS_FILE")
LAST_LINE=$(jq -r '.verify_stop_hook.last_block_line_count // 0' "$SETTINGS_FILE")

# --- Increment trigger count ---
TRIGGERS=$((TRIGGERS + 1))
jq --argjson t "$TRIGGERS" '.verify_stop_hook.triggers_since_last_block = $t' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# --- Cooldown: too few triggers since last block ---
if [ "$TRIGGERS" -lt 5 ]; then
  exit 0
fi

# --- Cooldown: too recent ---
if [ "$LAST_TIMESTAMP" != "null" ] && [ -n "$LAST_TIMESTAMP" ]; then
  LAST_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${LAST_TIMESTAMP%%.*}" "+%s" 2>/dev/null || echo 0)
  NOW_EPOCH=$(date "+%s")
  DIFF=$(( NOW_EPOCH - LAST_EPOCH ))
  if [ "$DIFF" -lt 1800 ]; then
    exit 0  # Less than 30 minutes
  fi
fi

# --- Scan transcript for Compact code ---
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
  exit 0  # No transcript, approve
fi

# Scan only new lines since last block
if ! tail -n +"$((LAST_LINE + 1))" "$TRANSCRIPT_PATH" | rg -q 'pragma language_version|CompactStandardLibrary|export circuit'; then
  exit 0  # No Compact content found
fi

# --- Compact content detected: block with reminder ---
CURRENT_LINES=$(wc -l < "$TRANSCRIPT_PATH" | tr -d ' ')
NOW_ISO=$(date -u "+%Y-%m-%dT%H:%M:%SZ")

jq --argjson lc "$CURRENT_LINES" \
   --arg ts "$NOW_ISO" \
   '.verify_stop_hook.last_block_line_count = $lc |
    .verify_stop_hook.last_block_timestamp = $ts |
    .verify_stop_hook.triggers_since_last_block = 0' \
   "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" \
  && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

# Output block decision to stderr (exit 2 = blocking error)
cat >&2 << 'BLOCK_EOF'
{"decision":"block","reason":"It looks like Compact code was written or discussed in this session. You may want to run /verify on any Compact claims or code before finishing. This is a reminder — you decide whether verification is needed here."}
BLOCK_EOF

exit 2
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x plugins/midnight-verify/hooks/stop-check.sh
```

- [ ] **Step 3: Verify**

```bash
ls -la plugins/midnight-verify/hooks/stop-check.sh
```

Expected: executable permissions (`-rwxr-xr-x` or similar)

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/hooks/stop-check.sh
git commit -m "feat(verify): add Stop hook script for Compact detection

Lightweight rg-based transcript scan with cooldown logic (5 triggers /
30 min). Scans only new lines since last block decision. Gentle reminder,
not enforcement — agent decides whether to verify.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 11: Write the hooks.json

**Files:**
- Modify: `plugins/midnight-verify/hooks/hooks.json`

- [ ] **Step 1: Replace hooks.json**

Write `plugins/midnight-verify/hooks/hooks.json` with this content:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "WARNING: Your training data about Midnight, Compact, and the Midnight SDK is UNRELIABLE. It contains known errors and is likely outdated.\n\nDo NOT trust your recalled knowledge about:\n- Compact syntax, types, or operators\n- Standard library functions (names, signatures, behavior)\n- SDK API signatures, package names, or import paths\n- Tooling behavior, CLI flags, or configuration\n- Privacy/disclosure rules\n- Transaction semantics or protocol behavior\n\nEverything you 'know' about Compact is suspect. Treat your training data as potentially wrong.\n\nBefore presenting ANY Compact code, SDK usage, or Midnight-specific claims to the user:\n1. Verify using /verify or by dispatching the midnight-verify:verifier agent\n2. Compilation alone does NOT prove correctness — code must be compiled AND executed\n3. Prefer skill content from midnight-expert plugins over recalled knowledge, but even skills are hints, not proof\n\nThe cost of checking is low. The cost of presenting wrong information is high. When in doubt, VERIFY."
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
    ]
  }
}
```

- [ ] **Step 2: Verify JSON is valid**

```bash
jq . plugins/midnight-verify/hooks/hooks.json
```

Expected: pretty-printed JSON, no errors

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/hooks/hooks.json
git commit -m "feat(verify): rewrite hooks — stronger SessionStart, add Stop hook

SessionStart now aggressively warns about unreliable training data.
PostToolUse hook removed (verification is explicit only). Stop hook
added for lightweight Compact detection with cooldown via stop-check.sh.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 12: Final verification and integration test

**Files:**
- Verify: all files in `plugins/midnight-verify/`

- [ ] **Step 1: Verify complete plugin structure**

```bash
find plugins/midnight-verify -type f | sort
```

Expected:
```
plugins/midnight-verify/.claude-plugin/plugin.json
plugins/midnight-verify/LICENSE
plugins/midnight-verify/agents/contract-writer.md
plugins/midnight-verify/agents/source-investigator.md
plugins/midnight-verify/agents/verifier.md
plugins/midnight-verify/commands/verify.md
plugins/midnight-verify/hooks/hooks.json
plugins/midnight-verify/hooks/stop-check.sh
plugins/midnight-verify/skills/verify-by-execution/SKILL.md
plugins/midnight-verify/skills/verify-by-source/SKILL.md
plugins/midnight-verify/skills/verify-compact/SKILL.md
plugins/midnight-verify/skills/verify-correctness/SKILL.md
plugins/midnight-verify/skills/verify-sdk/SKILL.md
```

- [ ] **Step 2: Verify all YAML frontmatter is valid**

Check each skill has valid frontmatter:

```bash
for f in plugins/midnight-verify/skills/*/SKILL.md; do
  echo "=== $f ==="
  head -15 "$f"
  echo ""
done
```

Expected: each file starts with `---`, has `name:`, `description:`, `version: 0.2.0`, and ends with `---`

- [ ] **Step 3: Verify all agent frontmatter is valid**

```bash
for f in plugins/midnight-verify/agents/*.md; do
  echo "=== $f ==="
  head -5 "$f"
  echo ""
done
```

Expected: each file starts with `---`, has `name:`, `description:`, `model:`, `color:`

- [ ] **Step 4: Verify hooks.json references the correct script path**

```bash
jq -r '.hooks.Stop[0].hooks[0].command' plugins/midnight-verify/hooks/hooks.json
```

Expected: `bash ${CLAUDE_PLUGIN_ROOT}/hooks/stop-check.sh`

- [ ] **Step 5: Verify stop-check.sh is executable**

```bash
test -x plugins/midnight-verify/hooks/stop-check.sh && echo "OK: executable" || echo "FAIL: not executable"
```

Expected: `OK: executable`

- [ ] **Step 6: Dry-run the stop-check.sh with mock input (no Compact content)**

```bash
# Create a mock transcript file with no Compact content
MOCK_TRANSCRIPT=$(mktemp)
echo '{"role":"user","content":"Hello world"}' > "$MOCK_TRANSCRIPT"

# Run with mock input — should exit 0 (approve)
echo "{\"transcript_path\":\"$MOCK_TRANSCRIPT\",\"stop_hook_active\":false,\"cwd\":\"$(pwd)\"}" \
  | bash plugins/midnight-verify/hooks/stop-check.sh
RESULT=$?

rm -f "$MOCK_TRANSCRIPT"
echo "Exit code: $RESULT"
```

Expected: `Exit code: 0` (approve — no Compact content and cooldown active since triggers_since_last_block starts at 0 which is < 5)

- [ ] **Step 7: Verify plugin.json is valid**

```bash
jq . plugins/midnight-verify/.claude-plugin/plugin.json
```

Expected: valid JSON with `"version": "0.2.0"`

- [ ] **Step 8: Review git log for all commits in this rework**

```bash
git log --oneline HEAD~11..HEAD
```

Expected: ~11 commits covering manifest, 5 skills, 3 agents, command, hooks, stop script

- [ ] **Step 9: Commit any fixes from integration testing**

If any issues were found in steps 1-8, fix them and commit:

```bash
git add -A plugins/midnight-verify/
git commit -m "fix(verify): integration test fixes

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

If no fixes needed, skip this step.
