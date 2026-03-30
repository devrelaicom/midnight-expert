# Witness Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cross-domain witness verification to the midnight-verify plugin — a new `witness-verifier` agent that compiles Compact contracts, type-checks TypeScript witnesses against generated types, runs structural checklist analysis, and executes the combined contract+witness pipeline.

**Architecture:** New `witness-verifier` agent (opus) with two new skills: `verify-witness` (domain routing) and `verify-by-witness` (5-phase method: setup → compile+type-check → structural checklist → execute with witness → optional devnet E2E). Own workspace at `.midnight-expert/verify/witness-workspace/`. For Witness+ZKIR claims, witness-verifier runs first and passes build output path to zkir-checker.

**Tech Stack:** `@midnight-ntwrk/compact-runtime`, `typescript`, Compact CLI.

**Spec:** `docs/superpowers/specs/2026-03-30-witness-verification-design.md`

---

### Task 1: Create the `witness-verifier` agent

**Files:**
- Create: `plugins/midnight-verify/agents/witness-verifier.md`

- [ ] **Step 1: Create the agent file**

```markdown
---
name: witness-verifier
description: >-
  Use this agent to verify that TypeScript witness implementations correctly
  match Compact contract declarations. Compiles the contract, type-checks the
  witness against generated types, runs structural analysis (name matching,
  return tuple shape, WitnessContext usage, private state patterns), and
  executes the combined contract+witness pipeline. Dispatched by the verifier
  orchestrator agent.

  Example 1: User runs /verify contracts/counter.compact src/witnesses.ts —
  the agent compiles the contract, type-checks the witness against the generated
  Witnesses type, runs the structural checklist, and executes the circuit with
  the witness implementation.

  Example 2: Claim "This witness correctly implements the counter contract" —
  the agent asks for or identifies the relevant .compact and .ts files, then
  runs the full verification pipeline.

  Example 3: Claim "This contract + witness produces a valid ZK proof" —
  the agent compiles without --skip-zk, runs its pipeline, and reports the
  build output path so the zkir-checker can run PLONK verification.
skills: midnight-verify:verify-by-witness
model: opus
color: orange
---

You are a cross-domain witness verifier for Midnight.

## Your Job

Load `midnight-verify:verify-by-witness` and follow it step by step. The skill defines a 5-phase pipeline:

1. **Setup** — initialize workspace, locate the .compact and .ts files
2. **Compile and Type-Check** — compile the contract, type-check the witness against generated types
3. **Structural Checklist** — automated checks for name matching, return tuple shape, WitnessContext usage, private state immutability, side effects
4. **Execute** — run the circuit with the witness via JS runtime
5. **Optional Devnet E2E** — dispatch to sdk-tester if devnet is available

## Important

- You do NOT classify claims or synthesize verdicts — the verifier orchestrator does that.
- The Compact contract must be compiled where it lives (it may have imports). Direct build output to the job directory.
- For claims that also need PLONK verification, compile without `--skip-zk` and report the build output path so the verifier can pass it to the zkir-checker.
- You may load `compact-core:compact-witness-ts` as a hint for understanding witness patterns, but your verification results are the evidence, not skill content.
```

Write this to `plugins/midnight-verify/agents/witness-verifier.md`.

- [ ] **Step 2: Verify**

```bash
head -5 plugins/midnight-verify/agents/witness-verifier.md
```

Expected: Frontmatter starting with `name: witness-verifier`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/witness-verifier.md
git commit -m "feat(verify): add witness-verifier agent for cross-domain witness verification

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Create the `verify-witness` domain routing skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-witness/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```markdown
---
name: midnight-verify:verify-witness
description: >-
  Witness claim classification and method routing. Determines what kind of
  witness claim is being verified and dispatches to the witness-verifier agent.
  Handles claims about witness type correctness, name matching, return tuple
  shape, type mappings, behavioral correctness, private state patterns, and
  two-file verification. Loaded by the verifier agent alongside the hub skill.
version: 0.5.0
---

# Witness Claim Classification

This skill classifies witness-related claims and determines which agent(s) to dispatch. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Claim Type → Method Routing

When you receive a witness-related claim, classify it using this table:

### Claims About the Contract-Witness Interface

| Claim Type | Example | Dispatch |
|---|---|---|
| Witness type correctness | "This witness correctly implements the contract interface" | **witness-verifier** |
| Witness name matching | "The witness names match the contract declarations" | **witness-verifier** |
| Witness return type | "This witness returns the correct [PrivateState, ReturnValue] tuple" | **witness-verifier** |
| Type mapping correctness | "The Field parameters map to bigint in the witness" | **witness-verifier** |
| WitnessContext usage | "This witness correctly uses the ledger from WitnessContext" | **witness-verifier** |
| Private state patterns | "This witness doesn't mutate private state in place" | **witness-verifier** |

### Claims About Witness Behavior

| Claim Type | Example | Dispatch |
|---|---|---|
| Behavioral correctness | "This contract + witness combination produces valid results" | **witness-verifier** |
| Two-file verification | `/verify contracts/counter.compact src/witnesses.ts` | **witness-verifier** (both files) |
| Witness + devnet E2E | "This witness works correctly when deployed" | **witness-verifier** + **sdk-tester** (concurrent) |

### Cross-Domain Claims

| Claim Type | Example | Dispatch |
|---|---|---|
| Witness + ZK proof | "This contract + witness produces a valid ZK proof" | **witness-verifier** first, then **zkir-checker** (sequential — witness-verifier passes build output path) |

### Routing Rules

**When in doubt:**
- Claims about the contract-witness interface → **witness-verifier**
- Claims about just the TypeScript types (no contract involved) → **type-checker** (existing SDK path)
- Claims about just the Compact declarations (no witness implementation) → **contract-writer** (existing Compact path)

**For Witness + ZKIR claims:** dispatch witness-verifier first (it compiles and verifies), then pass the build output path to zkir-checker. These are sequential, not concurrent, because the zkir-checker depends on the compiled artifacts.

## Hints from Existing Skills

The witness-verifier may consult these skills for context. They are **hints only** — never cite them as evidence.

- `compact-core:compact-witness-ts` — witness implementation patterns, WitnessContext API, type mappings
- `compact-core:compact-structure` — witness declarations, disclosure rules
- `compact-core:compact-review` — witness consistency review checklist
```

Write this to `plugins/midnight-verify/skills/verify-witness/SKILL.md`.

- [ ] **Step 2: Verify**

```bash
head -8 plugins/midnight-verify/skills/verify-witness/SKILL.md
```

Expected: Frontmatter with `name: midnight-verify:verify-witness`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-witness/SKILL.md
git commit -m "feat(verify): add verify-witness domain routing skill

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Create the `verify-by-witness` method skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-witness/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```markdown
---
name: midnight-verify:verify-by-witness
description: >-
  Cross-domain witness verification pipeline. Compiles the Compact contract,
  type-checks the TypeScript witness against the compiled contract's generated
  Witnesses type, runs structural checklist analysis (name matching, return
  tuple shape, WitnessContext usage, private state immutability, side effects),
  executes the circuit with the witness via JS runtime, and optionally
  dispatches to sdk-tester for devnet E2E. Loaded by the witness-verifier agent.
version: 0.5.0
---

# Verify by Witness

You are verifying that a TypeScript witness implementation correctly matches and works with a Compact contract. Follow these phases in order.

## Critical Rule

**Witness verification is cross-domain.** You need both the `.compact` contract file and the `.ts` witness implementation file. If you only have one, ask for the other. Do not attempt verification with only one file.

## Phase 1: Setup and Locate Files

The workspace lives at `.midnight-expert/verify/witness-workspace/` relative to the project root.

**First time (workspace does not exist):**

```bash
mkdir -p .midnight-expert/verify/witness-workspace
cd .midnight-expert/verify/witness-workspace
npm init -y
npm install @midnight-ntwrk/compact-runtime typescript
```

**Subsequent times:**

```bash
cd .midnight-expert/verify/witness-workspace
npm ls typescript
```

If errors, `npm install` to repair.

**Create the job directory:**

```bash
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/witness-workspace/jobs/$JOB_ID
```

**Locate the files:**

- **Two files provided:** Verify both exist. The `.compact` file stays where it is (it may have imports and dependencies on other `.compact` files in its directory). Copy the `.ts` witness file to the job directory.
- **Claim provided:** Identify the relevant files from the claim text. If the claim names specific files or paths, locate them. If not, use `AskUserQuestion` to ask which files to verify.

## Phase 2: Compile and Type-Check

### Compile the Compact contract

Compile the contract where it lives, directing build output to the job directory:

```bash
compact compile -- --skip-zk <source-path> .midnight-expert/verify/witness-workspace/jobs/$JOB_ID/build/
```

If the verifier indicated this claim also needs PLONK verification (Witness + ZKIR), compile without `--skip-zk` instead:

```bash
compact compile -- <source-path> .midnight-expert/verify/witness-workspace/jobs/$JOB_ID/build/
```

This produces `build/contract/index.js` and `build/contract/index.d.ts` which export the generated `Witnesses` type.

### Type-check the witness

Create a type-check harness in the job directory that imports the witness file and validates it against the generated types:

```typescript
// jobs/$JOB_ID/witness-check.ts
import type { Witnesses } from './build/contract/index.js';
import witnesses from '<absolute-path-to-witness-file>';

// This assignment checks that the witness object satisfies the generated Witnesses type
const _typeCheck: Witnesses<any> = witnesses;
```

Create a `tsconfig.json` for the job:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "strict": true,
    "noEmit": true,
    "skipLibCheck": false,
    "esModuleInterop": true
  },
  "include": ["witness-check.ts"]
}
```

Run the type check:

```bash
cd .midnight-expert/verify/witness-workspace/jobs/$JOB_ID
npx tsc --noEmit --project tsconfig.json 2>&1
```

**If tsc exits 0:** Types match — the witness satisfies the generated `Witnesses` type.
**If tsc exits non-zero:** Type mismatches found — the compiler errors are evidence of what doesn't match.

Note: The exact shape of the type-check harness depends on how the compiled contract exports the `Witnesses` type. Read `build/contract/index.d.ts` to understand the export shape and adapt the harness accordingly.

## Phase 3: Structural Checklist

Read both the compiled `build/contract/index.d.ts` (for witness declarations) and the `.ts` witness file (for implementations). Perform these automated checks:

### Check 1: Name Matching

Parse the witness function names from the compiled type declarations. Check that every declared witness name exists in the TypeScript implementation with exact casing.

**PASS:** All declared witness names have matching implementations.
**FAIL:** List missing or misspelled names.

### Check 2: Return Tuple Shape

Check that each witness function returns `[PrivateState, ReturnValue]` — a two-element tuple where the first element is the private state type. Look for return type annotations or actual return statements.

**PASS:** All witnesses return a tuple with private state as the first element.
**FAIL:** List witnesses that return just the value without the private state wrapper.

### Check 3: WitnessContext First Parameter

Check that each witness function's first parameter is the `WitnessContext` type (containing `ledger`, `privateState`, `contractAddress`).

**PASS:** All witnesses accept `WitnessContext` as their first parameter.
**FAIL:** List witnesses with wrong or missing first parameter.

### Check 4: Private State Immutability

Check that witness functions create new state objects rather than mutating the existing `privateState` in place. Look for:
- **Correct patterns:** Object spread (`{ ...context.privateState, key: newValue }`), `Object.assign({}, ...)`, creating new objects
- **Incorrect patterns:** Direct property assignment (`context.privateState.key = value`), array `.push()`, `.splice()`, etc.

**PASS:** No direct mutation patterns found.
**FAIL:** List locations where private state appears to be mutated directly.

### Check 5: No Side Effects

Check for non-deterministic or side-effecting code that should not appear in witnesses:
- `console.log`, `console.warn`, `console.error`
- `fetch`, `XMLHttpRequest`
- `fs.readFile`, `fs.writeFile`, any `fs` usage
- `Math.random`, `Date.now`, `crypto.getRandomValues`
- `setTimeout`, `setInterval`

**PASS:** No side effects found.
**FAIL:** List locations of non-deterministic or side-effecting code.

Note: These checks are heuristic — they read source text and look for patterns. They are not as authoritative as compilation or execution. Report findings alongside the mechanical results.

## Phase 4: Execute with Witness

Import the compiled contract and execute the circuit(s) with the witness:

```javascript
import { Contract } from '<job-dir>/build/contract/index.js';
import witnesses from '<absolute-path-to-witness-file>';

// Create contract instance with the witness implementations
const contract = new Contract(witnesses);

// Create initial state
const initialZswapLocalState = { coinPublicKey: new Uint8Array(32) };
const state = contract.initialState({
  initialZswapLocalState,
  initialPrivateState: { /* appropriate initial private state */ }
});

// Create circuit context
const context = compactRuntime.createCircuitContext(
  compactRuntime.dummyContractAddress(),
  initialZswapLocalState.coinPublicKey,
  state.currentContractState.data,
  state.currentPrivateState
);

// Execute each circuit that uses witnesses
const result = contract.circuits.<circuitName>(context);
```

Check `build/compiler/contract-info.json` — circuits with a non-empty `witnesses` array use witnesses.

**Success:** The circuit executed without error and produced valid proof data. The contract + witness combination works.

**Failure:** Capture the error. Common witness execution errors:
- `"expected tuple, got <type>"` — witness returns wrong shape
- `"missing witness: <name>"` — witness function not provided
- `"Contract constructor: expected 1 argument"` — witnesses object not passed
- Type errors at runtime — witness returns wrong types

## Phase 5: Optional Devnet E2E

Check devnet health (load `midnight-tooling:devnet` skill for endpoints). If all services are reachable, dispatch to `midnight-verify:sdk-tester` for the full deploy+call lifecycle with the witness.

If devnet is unavailable, note in the report: "Behavioral verification passed locally. Full deploy+call lifecycle verification requires a running devnet."

## Report

```
### Witness Verification Report

**Contract:** [path to .compact]
**Witness:** [path to .ts]

**Type Check:** PASS / FAIL
[tsc output if failed]

**Structural Checklist:**
- Name matching: PASS / FAIL — [details]
- Return tuple shape: PASS / FAIL — [details]
- WitnessContext pattern: PASS / FAIL — [details]
- Private state immutability: PASS / FAIL — [details]
- No side effects: PASS / FAIL — [details]

**Execution:** PASS / FAIL
[execution output or error]

**Devnet E2E:** PASS / FAIL / SKIPPED (devnet unavailable)

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [summary]
```

If the verifier indicated PLONK verification is needed, include the build output path in the report so the verifier can pass it to the zkir-checker:

```
**Build output:** .midnight-expert/verify/witness-workspace/jobs/$JOB_ID/build/
```

## Clean Up

```bash
rm -rf .midnight-expert/verify/witness-workspace/jobs/$JOB_ID
```

Do NOT remove the base workspace — it's shared across jobs. If the verifier needs the build output for zkir-checker, do NOT clean up until the verifier confirms the zkir-checker is done.
```

Write this to `plugins/midnight-verify/skills/verify-by-witness/SKILL.md`.

- [ ] **Step 2: Verify**

```bash
head -12 plugins/midnight-verify/skills/verify-by-witness/SKILL.md
```

Expected: Frontmatter with `name: midnight-verify:verify-by-witness` and version `0.5.0`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-witness/SKILL.md
git commit -m "feat(verify): add verify-by-witness skill for cross-domain witness pipeline

5-phase pipeline: setup → compile+type-check → structural checklist →
execute with witness → optional devnet E2E.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Update `verify-correctness` hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Add Witness domain to classification table**

In the `### 1. Classify the Domain` section, add a new row after the ZKIR row:

```
| **Witness** | Witness implementation, WitnessContext, private state, `[PrivateState, T]` return tuple, `.compact` + `.ts` file pair, witness declarations, type mappings | Load `midnight-verify:verify-witness` |
```

Update the Cross-domain row:

```
| **Cross-domain** | Spans Compact and SDK, Compact and ZKIR, Witness and ZKIR, or protocol/architecture | Load applicable domain skills |
```

- [ ] **Step 2: Add Witness dispatch instructions**

In the `### 3. Dispatch Sub-Agents` section, add after the ZKIR entries:

```markdown
- **Witness verification needed** → dispatch `midnight-verify:witness-verifier` agent with the claim and both file paths (if provided)
- **Witness + ZKIR verification needed** → dispatch `midnight-verify:witness-verifier` first (it compiles and verifies), then pass the build output path to `midnight-verify:zkir-checker` for PLONK verification. These are sequential, not concurrent.
```

- [ ] **Step 3: Add Witness verdict qualifiers**

In the `### 4. Synthesize the Verdict` section, add these rows to the verdict table:

```
| **Confirmed** | (witness-verified) | Type check + structural checklist + execution all pass |
| **Confirmed** | (witness-verified + tested) | Local verification + devnet E2E both pass |
| **Confirmed** | (witness-verified + zkir-checked) | Witness verification + PLONK proof valid |
| **Refuted** | (witness-verified) | Type check, structural check, or execution failed |
| **Inconclusive** | (devnet unavailable) | Local witness verification passed but devnet E2E needed and unavailable |
```

- [ ] **Step 4: Update version to 0.5.0**

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(verify): add Witness domain, dispatch, and verdicts to hub skill

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Update `verify-sdk` routing skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-sdk/SKILL.md`

- [ ] **Step 1: Update the witness routing row**

In the "Claims About User Code That Uses the SDK" table, find:

```
| Witness implementation | "This witness correctly implements the contract interface" | **type-checker** (+ **contract-writer** for the Compact side) |
```

Replace with:

```
| Witness implementation | "This witness correctly implements the contract interface" | **witness-verifier** |
```

- [ ] **Step 2: Update version to 0.4.0**

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-sdk/SKILL.md
git commit -m "feat(verify): route witness claims to witness-verifier in SDK skill

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Update `verifier` agent and `plugin.json`

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`
- Modify: `plugins/midnight-verify/.claude-plugin/plugin.json`

- [ ] **Step 1: Update verifier agent**

Add `midnight-verify:verify-witness` to the skills frontmatter:

```
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk, midnight-verify:verify-zkir, midnight-verify:verify-witness
```

Add Example 7 to the description frontmatter:

```
  Example 7: User runs /verify contracts/counter.compact src/witnesses.ts —
  the orchestrator classifies this as a witness verification, dispatches the
  witness-verifier agent to compile, type-check, run structural analysis, and
  execute the contract with the witness.
```

Add Witness dispatch block to the body, after the ZKIR block:

```markdown
**Witness verification:**
- Witness verification → dispatch `midnight-verify:witness-verifier`
- Witness + ZKIR → dispatch `midnight-verify:witness-verifier` first, then pass build output path to `midnight-verify:zkir-checker` (sequential)
```

Update the domain routing list in `## Your Job`:

```markdown
   - Compact claims → load `midnight-verify:verify-compact`
   - SDK/TypeScript claims → load `midnight-verify:verify-sdk`
   - ZKIR claims → load `midnight-verify:verify-zkir`
   - Witness claims → load `midnight-verify:verify-witness`
   - Cross-domain → load applicable domain skills
```

- [ ] **Step 2: Update plugin.json**

Change version from `"0.4.0"` to `"0.5.0"`.

Add `"witness"` to the keywords array.

Update description to include witness verification:

```json
"description": "Verification framework for Midnight claims — verifies Compact code by compiling and executing test contracts, SDK/TypeScript claims by type-checking and devnet E2E testing, ZKIR circuits by running through the WASM checker and inspecting compiled structure, witness implementations by cross-domain type-checking and execution against compiled contracts, or by inspecting source code. Multi-agent pipeline with explicit /verify command."
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md plugins/midnight-verify/.claude-plugin/plugin.json
git commit -m "chore(verify): bump to v0.5.0, add witness to verifier and plugin manifest

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: Validate the complete implementation

- [ ] **Step 1: Verify all new files exist**

```bash
echo "=== New agent ===" && ls plugins/midnight-verify/agents/witness-verifier.md
echo "=== New skills ===" && ls plugins/midnight-verify/skills/verify-witness/SKILL.md plugins/midnight-verify/skills/verify-by-witness/SKILL.md
```

Expected: All 3 files present.

- [ ] **Step 2: Verify all skill frontmatter**

```bash
for f in plugins/midnight-verify/skills/*/SKILL.md; do echo "--- $f ---"; head -3 "$f"; echo; done
```

Expected: 13 skills total (11 existing + 2 new), all with valid frontmatter.

- [ ] **Step 3: Verify plugin version is 0.5.0**

```bash
grep '"version"' plugins/midnight-verify/.claude-plugin/plugin.json
```

Expected: `"version": "0.5.0"`

- [ ] **Step 4: Verify witness routing in SDK skill**

```bash
grep -A1 "Witness implementation" plugins/midnight-verify/skills/verify-sdk/SKILL.md
```

Expected: Routes to `**witness-verifier**`, not `**type-checker**`.

- [ ] **Step 5: Verify verifier has all 5 domain skills**

```bash
grep "^skills:" plugins/midnight-verify/agents/verifier.md
```

Expected: Line contains `verify-correctness`, `verify-compact`, `verify-sdk`, `verify-zkir`, `verify-witness`.

- [ ] **Step 6: Verify git log**

```bash
git log --oneline -7
```

Expected: 6 new commits for this implementation.
