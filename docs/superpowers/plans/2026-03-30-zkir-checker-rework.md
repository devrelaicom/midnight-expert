# ZKIR Checker Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the ZKIR checker skill to use the real PLONK verification pipeline (compile without `--skip-zk` → execute → serialize → check with real keys), delete all hand-crafted fixtures, rewrite regression as a claim list, and update the agent/inspection skill.

**Architecture:** The `@midnight-ntwrk/zkir-v2` WASM package is a full PLONK prover/verifier requiring circuit-specific keys from compilation. The checker skill's pipeline becomes: compile Compact in place → execute via JS runtime → `proofDataIntoSerializedPreimage()` (5 args) → `check()` with `keyProvider`. Hand-crafted `.zkir` and fixtures are removed entirely.

**Tech Stack:** `@midnight-ntwrk/zkir-v2` (WASM PLONK verifier), `@midnight-ntwrk/compact-runtime` (`proofDataIntoSerializedPreimage`), Compact CLI (without `--skip-zk`).

**Spec:** `docs/superpowers/specs/2026-03-30-zkir-checker-rework-design.md`

---

### Task 1: Delete all fixture files

**Files:**
- Delete: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/` (entire directory tree, 52 files)

- [ ] **Step 1: Delete the fixtures directory**

```bash
rm -rf plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures
```

Verify it's gone:

```bash
ls plugins/midnight-verify/skills/verify-by-zkir-checker/
```

Expected: Only `SKILL.md` remains.

- [ ] **Step 2: Commit**

```bash
git add -A plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures
git commit -m "refactor(verify): remove hand-crafted ZKIR fixtures

Hand-crafted .zkir circuits cannot be executed through the real PLONK
checker — it requires proving keys from Compact compilation. Fixtures
are replaced by the claim-based regression approach.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Rewrite `verify-by-zkir-checker` skill

**Files:**
- Rewrite: `plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md`

- [ ] **Step 1: Replace the entire skill file**

Write the following content to `plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md`:

```markdown
---
name: midnight-verify:verify-by-zkir-checker
description: >-
  Verification by running the full ZK proof pipeline: compile Compact without
  --skip-zk to generate PLONK keys, execute the circuit via JS runtime to get
  proof data, serialize with proofDataIntoSerializedPreimage(), then verify
  with the @midnight-ntwrk/zkir-v2 WASM PLONK checker. Supports both contract
  mode (verify a user's .compact file) and claim mode (write a minimal contract
  to test a claim). Loaded by the zkir-checker agent.
version: 0.4.1
---

# Verify by ZKIR Checker

You are verifying a Compact contract or ZKIR claim by running the full zero-knowledge proof pipeline. This uses the real PLONK verifier — the same verification path the Midnight network uses. Follow these steps in order.

## Critical Rule

**Always compile without `--skip-zk`.** The whole point of this method is using the real PLONK verifier with real proving keys. A checker ACCEPT proves the ZK proof is valid for those specific inputs. It does NOT prove the circuit is correct for all inputs.

**What this proves that `verify-by-execution` doesn't:** The execution skill compiles with `--skip-zk` and runs the JS runtime — it proves the contract logic works. This skill proves the contract's zero-knowledge proof is valid: constraints are satisfied, transcript encoding is correct, proof data serializes properly, and the PLONK verifier accepts.

## Step 1: Set Up the Workspace

The workspace lives at `.midnight-expert/verify/zkir-workspace/` relative to the project root.

**First time (workspace does not exist):**

```bash
mkdir -p .midnight-expert/verify/zkir-workspace
cd .midnight-expert/verify/zkir-workspace
npm init -y
npm install @midnight-ntwrk/zkir-v2 @midnight-ntwrk/compact-runtime
```

**Subsequent times (workspace exists):**

```bash
cd .midnight-expert/verify/zkir-workspace
npm ls @midnight-ntwrk/zkir-v2
```

If `npm ls` reports errors, run `npm install` to repair.

**Create the job directory:**

```bash
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID
```

## Step 2: Get the Contract

### Contract Mode (primary)

The user provides a `.compact` file or path. The contract may have imports and dependencies on other `.compact` files in its directory — **compile it where it lives**, directing only the build output to the job directory.

If the contract has already been compiled with keys (a build directory exists containing `keys/*.prover` and `zkir/*.bzkir`), copy those build artifacts to the job directory instead of recompiling.

### Claim Mode

No user contract provided — you're verifying a natural language claim about ZK behavior. Write a minimal `.compact` contract in the job directory that exercises the claim.

You may load compact-core skills as hints for writing correct Compact code. The compiled output is your evidence, not the skill content.

## Step 3: Compile Without `--skip-zk`

```bash
compact compile -- <source-path> .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/build/
```

**The source path is the `.compact` file where it lives** (contract mode) or in the job directory (claim mode). The build output always goes to `jobs/$JOB_ID/build/`.

This produces:
- `build/zkir/<circuit>.zkir` — ZKIR JSON
- `build/zkir/<circuit>.bzkir` — ZKIR binary
- `build/keys/<circuit>.prover` — PLONK proving key
- `build/keys/<circuit>.verifier` — PLONK verifying key
- `build/contract/index.js` — compiled JS contract
- `build/compiler/contract-info.json` — circuit metadata

If compilation fails, report the error. For claim mode, fix the contract and retry up to 2 times, then report Inconclusive.

**Note:** Compilation without `--skip-zk` is slower than with it because it generates PLONK proving keys. This is expected — you are running the real ZK pipeline.

## Step 4: Execute Via JS Runtime

Import the compiled contract and execute the circuit(s) to get proof data:

```javascript
import * as compactRuntime from '@midnight-ntwrk/compact-runtime';
import { Contract } from '<job-dir>/build/contract/index.js';

// Create contract instance (may need witnesses depending on the contract)
const contract = new Contract(witnesses);

// Create initial state
const initialZswapLocalState = { coinPublicKey: new Uint8Array(32) };
const state = contract.initialState({ initialZswapLocalState, initialPrivateState: {} });

// Create circuit context
const context = compactRuntime.createCircuitContext(
  compactRuntime.dummyContractAddress(),
  initialZswapLocalState.coinPublicKey,
  state.currentContractState.data,
  state.currentPrivateState
);

// Execute the circuit via the circuits interface
const circuitResult = contract.circuits.<circuitName>(context);

// circuitResult contains: { result, context, proofData, gasCost }
// proofData contains: { input, output, publicTranscript, privateTranscriptOutputs }
```

Check `build/compiler/contract-info.json` for the list of circuits. Each circuit with `"proof": true` can be verified through the PLONK checker.

In **contract mode**, verify each provable circuit. In **claim mode**, only the circuit relevant to the claim.

## Step 5: Serialize Proof Data

```javascript
const serializedPreimage = compactRuntime.proofDataIntoSerializedPreimage(
  circuitResult.proofData.input,
  circuitResult.proofData.output,
  circuitResult.proofData.publicTranscript,
  circuitResult.proofData.privateTranscriptOutputs,
  '<circuitName>'  // keyLocation — matches the circuit name
);
```

**This function takes 5 individual arguments, not an object.** The `keyLocation` parameter is the circuit name (e.g., `'increment'`) which the key provider uses to look up the correct keys.

## Step 6: Run the PLONK Checker

```javascript
import { check } from '@midnight-ntwrk/zkir-v2';
import { readFileSync } from 'fs';

const keyProvider = {
  async lookupKey(keyLocation) {
    return {
      proverKey: readFileSync(`<job-dir>/build/keys/${keyLocation}.prover`),
      verifierKey: readFileSync(`<job-dir>/build/keys/${keyLocation}.verifier`),
      ir: readFileSync(`<job-dir>/build/zkir/${keyLocation}.bzkir`)
    };
  },
  async getParams(k) {
    return readFileSync(`${process.env.HOME}/.compact/params/params_${k}.bin`);
  }
};

try {
  const result = await check(serializedPreimage, keyProvider);
  // ACCEPTED — result is an array of outputs (bigint or undefined for void)
  console.log(JSON.stringify({ verdict: 'ACCEPTED', outputs: result.map(v => v?.toString()) }));
} catch (e) {
  // REJECTED — error message identifies which constraint failed
  console.log(JSON.stringify({ verdict: 'REJECTED', error: e.message }));
}
```

**Checker error message catalog:**
- `"Communications commitment mismatch"` — tampered raw bytes or commitment error
- `"Public transcript input mismatch for input N; expected: Some(XX), computed: Some(YY)"` — wrong transcript values
- `"Failed direct assertion"` — assert input is boolean 0
- `"Expected boolean, found: XX"` — non-boolean to assert/cond_select/constrain_to_boolean
- `"Failed equality constraint: XX != YY"` — constrain_eq inputs differ
- `"Bit bound failed: XX is not N-bit"` — constrain_bits value exceeds range
- `"Ran out of private transcript outputs"` — missing witness data
- `"Transcripts not fully consumed"` — extra unused witness data

## Step 7: Negative Testing (When Appropriate)

For claims about rejection behavior (e.g., "tampering with the transcript is detected"), tamper with the proof data **before serialization** and confirm the checker rejects with the expected error:

```javascript
// Example: modify a transcript value
const tamperedProofData = {
  ...circuitResult.proofData,
  publicTranscript: circuitResult.proofData.publicTranscript.map(op => {
    if ('addi' in op) return { addi: { immediate: 999 } }; // Wrong value
    return op;
  })
};

const tamperedSerialized = compactRuntime.proofDataIntoSerializedPreimage(
  tamperedProofData.input,
  tamperedProofData.output,
  tamperedProofData.publicTranscript,
  tamperedProofData.privateTranscriptOutputs,
  '<circuitName>'
);

// This should reject with "Public transcript input mismatch"
const result = await check(tamperedSerialized, keyProvider);
```

A rejection in a negative test **confirms** the claim (the constraint is enforced).

## Step 8: Report

```
### ZKIR Checker Report

**Claim:** [verbatim]

**Contract source:** [user's file path / minimal contract written for claim]

**Compact source:**
\`\`\`compact
[source code]
\`\`\`

**Compilation:** [compiler version, circuit count, compilation time]

**Execution:** [which circuit(s) executed, proof data summary]

**Checker verdict:** ACCEPTED / REJECTED: [error message]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

## Step 9: Clean Up

```bash
rm -rf .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID
```

Do NOT remove the base workspace — it's shared across jobs.
```

- [ ] **Step 2: Verify the rewrite**

```bash
head -12 plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md
```

Expected: New frontmatter with version `0.4.1` and description mentioning "full ZK proof pipeline" and "PLONK".

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md
git commit -m "refactor(verify): rewrite zkir-checker skill with real PLONK pipeline

Replaces the hand-crafted .zkir approach with the verified pipeline:
compile without --skip-zk → execute via JS runtime →
proofDataIntoSerializedPreimage() → check() with real PLONK keys.

Supports contract mode (verify user's .compact) and claim mode
(write minimal contract). Includes concrete API details:
5-arg serialization, keyProvider shape, error message catalog.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Rewrite `zkir-regression` skill

**Files:**
- Rewrite: `plugins/midnight-verify/skills/zkir-regression/SKILL.md`

- [ ] **Step 1: Replace the entire skill file**

Write the following content to `plugins/midnight-verify/skills/zkir-regression/SKILL.md`:

```markdown
---
name: midnight-verify:zkir-regression
description: >-
  Run a curated set of verification claims against the current toolchain to
  detect behavioral changes. Each claim is verified through the normal
  verification pipeline (verifier → agents → checker/execution). Supports
  full sweep (all categories) and targeted sweep (single category). Invocable
  as /midnight-verify:zkir-regression or loadable by agents as a sense-check
  when they suspect toolchain issues.
version: 0.4.1
argument-hint: "[category: arithmetic|types|state|privacy|zk-proof|transcript]"
---

# ZKIR Regression Sweep

Run a curated set of verification claims against the current toolchain to detect behavioral changes. Unlike fixture-based testing, this exercises the full verification pipeline — claim classification, contract writing, compilation, execution, and PLONK proof verification.

Use this when:
- A new compiler version or checker package version is released
- An agent suspects unexpected behavior from the toolchain
- You want a confidence check before presenting Midnight-specific claims

## Step 1: Determine Mode

If `$ARGUMENTS` is empty → **full sweep** (all categories).

If `$ARGUMENTS` contains a category name → **targeted sweep** (that category only).

Valid categories: `arithmetic`, `types`, `state`, `privacy`, `zk-proof`, `transcript`.

## Step 2: Record Toolchain Versions

```bash
compact compile --language-version
compact --version
```

Record both for the report header.

## Step 3: Run Claims

For each claim in the list below (filtered by category if targeted), dispatch the `midnight-verify:verifier` agent with:
- The claim text
- Instruction to verify using the appropriate method

Collect the verdict for each claim. Do NOT stop on first failure — run all claims and collect all results.

## Claim List

| ID | Category | Claim | Expected Verdict |
|---|---|---|---|
| arith-1 | arithmetic | A pure circuit that adds two Uint32 values (3 + 4) returns the correct sum (7) | Confirmed (tested) |
| arith-2 | arithmetic | A pure circuit that multiplies two Uint32 values (3 * 5) returns the correct product (15) | Confirmed (tested) |
| types-1 | types | Assigning a value of 256 to a Uint8 variable produces a compiler error | Confirmed (tested) |
| types-2 | types | A pure circuit returning a tuple allows 0-indexed access to each element | Confirmed (tested) |
| state-1 | state | A counter contract's increment circuit updates the ledger state by the specified amount | Confirmed (tested) |
| state-2 | state | Reading a counter ledger value returns the current on-chain state | Confirmed (tested) |
| privacy-1 | privacy | A circuit that writes to the ledger requires a disclose() call | Confirmed (tested) |
| zk-1 | zk-proof | A counter contract's increment circuit passes the full PLONK proof verification | Confirmed (zkir-checked) |
| zk-2 | zk-proof | Tampering with the public transcript of a verified circuit causes PLONK checker rejection | Confirmed (zkir-checked) |
| zk-3 | zk-proof | The PLONK checker error for a tampered transcript identifies the exact mismatched input | Confirmed (zkir-checked) |
| transcript-1 | transcript | A counter increment circuit encodes ledger operations in the publicTranscript | Confirmed (zkir-inspected) |
| transcript-2 | transcript | The compiled ZKIR for a counter increment contains declare_pub_input instructions | Confirmed (zkir-inspected) |

## Step 4: Compare Results

For each claim, compare the actual verdict against the expected verdict:
- Verdict matches expected → **PASS**
- Verdict does not match → **FAIL**
- Verification returned Inconclusive but expected Confirmed → **FAIL** (toolchain may be unavailable)

## Step 5: Report

```markdown
## ZKIR Regression Report

**Toolchain:** compact CLI vX.Y.Z, language version A.B.C
**Date:** YYYY-MM-DD
**Mode:** [full sweep / targeted: <category>]
**Ran:** N claims

### Results

| Category | Passed | Failed | Total |
|---|---|---|---|
| arithmetic | N | N | N |
| types | N | N | N |
| state | N | N | N |
| privacy | N | N | N |
| zk-proof | N | N | N |
| transcript | N | N | N |
| **Total** | **N** | **N** | **N** |

### Failures (if any)

**<claim-id>:** Expected <expected verdict>, got <actual verdict>
- Claim: "<claim text>"
- Actual result: [what the verification pipeline returned]
- Interpretation: [what this failure suggests about toolchain changes]
```

If there are zero failures, end with:
> All N claims passed. Toolchain behavior matches expectations.

## Adding New Claims

Add a row to the claim list table above. Each claim should:
- Be verifiable through the normal `/verify` pipeline
- Have a deterministic expected verdict
- Test a specific, observable behavior
- Include the expected verdict qualifier (tested, zkir-checked, zkir-inspected, source-verified)
```

- [ ] **Step 2: Verify the rewrite**

```bash
head -12 plugins/midnight-verify/skills/zkir-regression/SKILL.md
```

Expected: New frontmatter with version `0.4.1` and description mentioning "curated set of verification claims".

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/zkir-regression/SKILL.md
git commit -m "refactor(verify): rewrite zkir-regression as claim-based sweep

Replaces fixture-based regression with a curated claim list that runs
through the full verification pipeline. 12 initial claims across 6
categories (arithmetic, types, state, privacy, zk-proof, transcript).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Update `zkir-checker` agent

**Files:**
- Modify: `plugins/midnight-verify/agents/zkir-checker.md`

- [ ] **Step 1: Update the agent description examples**

Replace the current Example 1 and Example 2 (which reference fixtures) with:

```
  Example 1: Claim "add wraps modulo r" — writes a minimal Compact contract
  that adds (r-1) + 1, compiles with full ZK pipeline, runs the PLONK checker,
  confirms the result wraps to 0.

  Example 2: Claim "constrain_bits enforces 8-bit range" — writes a contract
  using Uint8, compiles without --skip-zk, verifies the PLONK proof accepts
  for valid values and the compiler rejects overflow.
```

- [ ] **Step 2: Update the Important section**

Replace the current body text (everything after `## Your Job` section) with:

```markdown
## Your Job

Based on the claim you receive, load the appropriate skill:

- **Checker claims** (ZK proof validity, constraint behavior, transcript integrity, proof data correctness) → load `midnight-verify:verify-by-zkir-checker` and follow it step by step
- **Inspection claims** (compiled circuit structure, instruction counts, opcode usage, transcript encoding) → load `midnight-verify:verify-by-zkir-inspection` and follow it step by step
- **Both** (claims about structure AND behavior) → load both skills. Compile once without `--skip-zk` (the checker method requires this) and share the build output with the inspection method. Don't compile twice.

## Important

- You do NOT classify claims or synthesize verdicts — the verifier orchestrator does that.
- You may compile contracts in place (directing build output to the job directory) for user-provided contracts, or write minimal contracts in the job directory for claim-based verification.
- For the checker method, always compile without `--skip-zk` — you need the PLONK proving keys.
- For the inspection method alone (no checker), `--skip-zk` is fine since you only need the `.zkir` JSON.
- You may load compact-core skills as hints for writing Compact test contracts, but test results and checker verdicts are your evidence, not skill content.
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/zkir-checker.md
git commit -m "refactor(verify): update zkir-checker agent for real PLONK pipeline

Removes references to fixtures and hand-crafted .zkir. Updates examples
and instructions to reflect compile-in-place with full ZK pipeline.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Update `verify-by-zkir-inspection` skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md`

- [ ] **Step 1: Add shared compilation note**

After the Critical Rule section and before Step 1, add:

```markdown
## Shared Compilation

When the zkir-checker agent is running both inspection and checker methods for the same contract, compile once without `--skip-zk` and share the build output. The `.zkir` JSON produced by full compilation is identical to `--skip-zk` output — the only difference is that full compilation also generates PLONK keys. Don't compile twice.

If the checker method has already compiled the contract, use its build output for inspection. If running inspection alone, `--skip-zk` is fine since you only need the `.zkir` JSON.
```

- [ ] **Step 2: Update the compile command in Step 1**

The current Step 1 hardcodes `--skip-zk`. Update the compilation section to note the alternative:

Replace:
```
compact compile .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/test-claim.compact --skip-zk
```

With:
```
compact compile -- --skip-zk <source-path> .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/build/
```

And add after it:
```
If this inspection will be followed by checker verification, omit `--skip-zk` to avoid recompiling:

\`\`\`bash
compact compile -- <source-path> .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/build/
\`\`\`
```

Also update the compilation to compile the contract in place (for contract mode) matching the checker skill's pattern.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md
git commit -m "refactor(verify): add shared compilation note to inspection skill

When both inspection and checker run on the same contract, compile once
without --skip-zk and share build output. Avoids double compilation.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Validate the rework

- [ ] **Step 1: Verify fixtures are deleted**

```bash
ls plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures 2>&1
```

Expected: `No such file or directory`

- [ ] **Step 2: Verify checker skill mentions PLONK pipeline**

```bash
grep -c "proofDataIntoSerializedPreimage" plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md
```

Expected: At least 2 (referenced in Steps 5 and 7).

```bash
grep -c "skip-zk" plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md
```

Expected: At least 1 (the "without `--skip-zk`" rule).

- [ ] **Step 3: Verify regression skill has claim list**

```bash
grep -c "^| " plugins/midnight-verify/skills/zkir-regression/SKILL.md
```

Expected: At least 14 (header row + 12 claims + total row).

- [ ] **Step 4: Verify no remaining references to hand-crafted .zkir or fixtures**

```bash
grep -ri "hand-craft\|hand_craft\|fixture" plugins/midnight-verify/agents/zkir-checker.md plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md plugins/midnight-verify/skills/zkir-regression/SKILL.md
```

Expected: No matches.

- [ ] **Step 5: Verify git log shows the rework commits**

```bash
git log --oneline -6
```

Expected: 5 new commits (delete fixtures, rewrite checker, rewrite regression, update agent, update inspection).
