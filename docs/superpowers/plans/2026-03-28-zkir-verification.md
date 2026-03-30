# ZKIR Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ZKIR-level verification to the midnight-verify plugin — a new `zkir-checker` agent with checker and inspection skills, a domain routing skill, a regression sweep skill, and a fixture library mirroring the ZKIR reference document's oracle traces.

**Architecture:** New `zkir-checker` agent (opus) dispatched by the existing verifier orchestrator. Four new skills: `verify-zkir` (domain routing), `verify-by-zkir-checker` (WASM checker method), `verify-by-zkir-inspection` (compiled circuit analysis), `zkir-regression` (sweep). Fixtures live in the checker skill's directory tree. Existing hub/compact/execution skills gain ZKIR-aware routing and verdict qualifiers.

**Tech Stack:** `@midnight-ntwrk/zkir-v2` (WASM checker), `@midnight-ntwrk/compact-runtime`, Compact CLI, hand-crafted `.zkir` JSON circuits.

**Spec:** `docs/superpowers/specs/2026-03-28-zkir-verification-design.md`

---

### Task 1: Create the `zkir-checker` agent

**Files:**
- Create: `plugins/midnight-verify/agents/zkir-checker.md`

- [ ] **Step 1: Create the agent file**

```markdown
---
name: zkir-checker
description: >-
  Use this agent to verify ZKIR-level claims by running circuits through the
  @midnight-ntwrk/zkir-v2 WASM checker or inspecting compiled circuit structure.
  Compiles Compact to extract .zkir, constructs proof data, invokes the checker,
  and analyzes circuit properties. Dispatched by the verifier orchestrator agent.

  Example 1: Claim "add wraps modulo r" — loads a fixture circuit that adds
  (r-1) + 1, runs through the checker, confirms the result wraps to 0.

  Example 2: Claim "constrain_bits enforces 8-bit range" — loads fixture circuits
  for values 0, 255, and 256, runs all three, confirms accept/accept/reject.

  Example 3: Claim "counter increment compiles to fewer than 20 instructions" —
  compiles a counter contract, extracts .zkir, counts instructions.

  Example 4: Claim "this circuit uses persistent_hash for authority" — compiles
  a guarded counter, extracts .zkir, searches for persistent_hash opcode in
  instruction list.
skills: midnight-verify:verify-by-zkir-checker, midnight-verify:verify-by-zkir-inspection
model: opus
color: red
---

You are a ZKIR circuit verifier for Midnight.

## Your Job

Based on the claim you receive, load the appropriate skill:

- **Checker claims** (opcode behavior, constraint semantics, field arithmetic, proof data validity) → load `midnight-verify:verify-by-zkir-checker` and follow it step by step
- **Inspection claims** (compiled circuit structure, instruction counts, opcode usage, transcript encoding) → load `midnight-verify:verify-by-zkir-inspection` and follow it step by step
- **Both** (claims about structure AND behavior) → load both skills, perform inspection first to understand the circuit, then run checker to verify behavior

## Important

- You do NOT classify claims or synthesize verdicts — the verifier orchestrator does that.
- You may compile Compact contracts when needed — use `compact compile --skip-zk` the same way the contract-writer does.
- You may hand-craft `.zkir` JSON directly for IR-level claims not reachable from Compact, or for trivially small circuits.
- Check the fixture library first (`${CLAUDE_SKILL_DIR}/fixtures/` in the checker skill) before writing anything from scratch.
- You may load compact-core skills as hints for writing Compact test contracts, but test results and checker verdicts are your evidence, not skill content.
```

Write this to `plugins/midnight-verify/agents/zkir-checker.md`.

- [ ] **Step 2: Verify the file was created**

Run: `cat plugins/midnight-verify/agents/zkir-checker.md | head -5`
Expected: The frontmatter starting with `---` and `name: zkir-checker`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/zkir-checker.md
git commit -m "feat(verify): add zkir-checker agent for ZKIR-level verification

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Create the `verify-zkir` domain routing skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-zkir/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```markdown
---
name: midnight-verify:verify-zkir
description: >-
  ZKIR claim classification and method routing. Determines what kind of ZKIR
  claim is being verified and which verification method applies: WASM checker
  (accept/reject testing), circuit inspection (compiled structure analysis),
  or source investigation. Handles claims about opcode semantics, constraint
  behavior, field arithmetic, transcript protocol, and compiled circuit
  properties. Loaded by the verifier agent alongside the hub skill.
version: 0.4.0
---

# ZKIR Claim Classification

This skill classifies ZKIR-related claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Claim Type → Method Routing

When you receive a ZKIR-related claim, classify it using this table to determine which agent(s) to dispatch:

### Claims About ZKIR Behavior

| Claim Type | Example | Dispatch |
|---|---|---|
| Opcode semantics | "add wraps modulo r", "mul by zero produces zero" | **zkir-checker** (checker method) |
| Constraint behavior | "assert requires boolean input", "constrain_eq fails on unequal values" | **zkir-checker** (checker method) |
| Field arithmetic | "there are no negative numbers, -1 is r-1", "(r-1) + 1 = 0" | **zkir-checker** (checker method) |
| Transcript protocol | "publicTranscript encodes ledger ops as field elements", "popeq bridges public_input" | **zkir-checker** (checker method) |
| Cryptographic opcodes | "persistent_hash produces two field elements", "ec_mul_generator derives public key" | **zkir-checker** (checker method) |
| Proof data validity | "extra private transcript outputs cause rejection", "tampered public transcript is detected" | **zkir-checker** (checker method) |
| Type encoding | "encode converts a curve point to two field elements", "decode is the inverse of encode" | **zkir-checker** (checker method) |

### Claims About Compiled Circuit Structure

| Claim Type | Example | Dispatch |
|---|---|---|
| Instruction count | "this contract produces N instructions" | **zkir-checker** (inspection method) |
| Opcode usage | "guard counter uses persistent_hash for authority" | **zkir-checker** (inspection method) |
| Transcript encoding | "increment circuit uses 3 transcript ops", "disclosure compiles to declare_pub_input" | **zkir-checker** (inspection method) |
| I/O shape | "this pure circuit has no private_input instructions" | **zkir-checker** (inspection method) |
| ZKIR version format | "compiled output uses v2 format with implicit variable numbering" | **zkir-checker** (inspection method) |

### Claims About ZKIR Internals

| Claim Type | Example | Dispatch |
|---|---|---|
| ZKIR version differences | "v3 uses named variables, v2 uses integer indices" | **source-investigator** |
| Compiler internals | "zkir-passes.ss handles v2 serialization" | **source-investigator** |
| Checker implementation | "the WASM checker enforces transcript integrity" | **source-investigator** |

### Cross-Domain Claims

| Claim Type | Example | Dispatch |
|---|---|---|
| Compact → ZKIR mapping | "this Compact disclosure compiles to these ZKIR constraints" | **zkir-checker** (both methods) + **contract-writer** (concurrent) |
| Behavior + structure | "the guard circuit uses persistent_hash AND correctly rejects wrong keys" | **zkir-checker** (both methods) |
| ZKIR + runtime agreement | "the checker and JS runtime agree on this circuit's behavior" | **zkir-checker** (checker) + **contract-writer** (concurrent) |

### Routing Rules

**When in doubt:**
- Observable checker behavior (accept/reject with specific inputs) → **zkir-checker** (checker method)
- Compiled output properties (structure, counts, patterns) → **zkir-checker** (inspection method)
- Compiler/toolchain internals (how the compiler works, not what it produces) → **source-investigator**

**When multiple methods apply, dispatch concurrently.** Checker and inspection are independent and can run in parallel within the same agent.

## Hints from the ZKIR Reference

The zkir-checker agent has access to a fixture library with pre-crafted test circuits. The ZKIR reference document (Compact compiler v0.29.0) documents 26 opcodes across 8 categories:

- **Arithmetic:** add, mul, neg
- **Constraints:** assert, constrain_bits, constrain_eq, constrain_to_boolean
- **Control Flow:** cond_select, copy
- **Type Encoding:** decode, encode, reconstitute_field
- **Division:** div_mod_power_of_two
- **Cryptographic:** ec_mul, ec_mul_generator, hash_to_curve, persistent_hash, transient_hash
- **I/O:** impact, output, private_input, public_input
- **Comparison:** less_than, test_eq

These categories map directly to the fixture library's directory structure. When a claim is about a specific opcode, mention the category to help the zkir-checker find relevant fixtures.
```

Write this to `plugins/midnight-verify/skills/verify-zkir/SKILL.md`.

- [ ] **Step 2: Verify the file was created**

Run: `head -10 plugins/midnight-verify/skills/verify-zkir/SKILL.md`
Expected: Frontmatter with `name: midnight-verify:verify-zkir`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-zkir/SKILL.md
git commit -m "feat(verify): add verify-zkir domain routing skill for ZKIR claims

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Create the `verify-by-zkir-checker` skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```markdown
---
name: midnight-verify:verify-by-zkir-checker
description: >-
  Verification by running ZKIR circuits through the @midnight-ntwrk/zkir-v2
  WASM checker. Constructs or loads .zkir circuits, builds proof data, invokes
  the checker, and interprets accept/reject results. Covers workspace setup
  (lazy init), three circuit source paths (fixtures, compiled from Compact,
  hand-crafted), proof data construction, positive and negative testing, and
  result interpretation. Loaded by the zkir-checker agent.
version: 0.4.0
---

# Verify by ZKIR Checker

You are verifying a ZKIR claim by running a circuit through the `@midnight-ntwrk/zkir-v2` WASM checker. The checker is a deterministic oracle: given a circuit and proof data, it returns accept or reject. Follow these steps in order.

## Critical Rule

**A checker ACCEPT proves constraints are satisfied for those specific inputs. It does NOT prove the circuit is correct for all inputs.** When the claim is universal (e.g., "add always wraps"), note that your test covers specific cases, not all possible inputs.

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

Run a quick integrity check:

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

**Discover the checker API (first time only):**

On the very first use of this workspace, inspect the WASM package to understand its API:

```bash
ls node_modules/@midnight-ntwrk/zkir-v2/
cat node_modules/@midnight-ntwrk/zkir-v2/package.json | head -20
```

Look at the TypeScript types or JS exports to find the checker function. Document what you find in `.midnight-expert/verify/zkir-workspace/CHECKER-API.md` so subsequent jobs can reference it.

## Step 2: Determine Circuit Source

Choose the circuit source in this order of preference:

### Option A: Fixture Match (preferred)

Check `${CLAUDE_SKILL_DIR}/fixtures/test-cases/` for an existing test case that covers the claim. Read `${CLAUDE_SKILL_DIR}/fixtures/test-cases/manifest.json` to search by opcode, category, or description.

If a matching fixture exists:
1. Copy the test case JSON to the job directory
2. Copy the referenced `.zkir` circuit to the job directory
3. Skip to Step 5

### Option B: Compile from Compact (default)

Write a minimal `.compact` contract that exercises the claim, compile it, and extract the `.zkir`:

1. Get the current language version: `compact compile --language-version`
2. Write the contract to the job directory: `jobs/$JOB_ID/test-claim.compact`
3. Compile: `compact compile jobs/$JOB_ID/test-claim.compact --skip-zk`
4. Locate the `.zkir` JSON in the build output directory
5. Proceed to Step 3 to construct proof data

You may load compact-core skills as hints for writing correct Compact code. The compiled output is your evidence, not the skill content.

### Option C: Hand-Craft `.zkir` JSON (IR-level only)

Only use this when:
- The claim is about IR-level behavior not reachable from Compact (e.g., specific variable numbering, meta-instruction behavior)
- The circuit is trivially small (2-5 instructions)

Check `${CLAUDE_SKILL_DIR}/fixtures/templates/` for parameterizable patterns:
- `pure-circuit.json` — minimal: load_imm → op → constrain_eq → output
- `witness-circuit.json` — circuit with private_input
- `transcript-circuit.json` — circuit with publicTranscript

A hand-crafted v2 `.zkir` circuit follows this structure:

```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "<hex_value>" },
    { "op": "<opcode>", ... },
    { "op": "output", "var": <index> }
  ]
}
```

Key rules for hand-crafting:
- Variables are implicit sequential integers (0, 1, 2, ...). Each instruction that produces output gets the next index.
- Immediates are hex strings without `0x` prefix: `"01"`, `"FF"`, `"0302"`.
- `load_imm` creates a variable with a literal value.
- Input operands reference previous variable indices or hex immediates.

## Step 3: Construct Proof Data

Build a test case JSON that bundles the circuit with its inputs:

```json
{
  "description": "what this test verifies",
  "circuit": "path/to/circuit.zkir",
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [], "alignment": [] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

**For pure circuits** (no state, no witnesses): `input` contains function arguments, `output` contains return values. `publicTranscript` and `privateTranscriptOutputs` are empty.

**For circuits with witnesses:** `privateTranscriptOutputs` contains the witness values the circuit's `private_input` instructions will read, as an array of `AlignedValue` objects.

**For circuits with transcript:** `publicTranscript` contains the VM operations array. See the ZKIR reference's Section 4.5 for the encoding format.

## Step 4: Design Positive and Negative Tests

**Positive test:** "This should accept" — construct valid proof data that satisfies all constraints.

**Negative test:** "This should reject" — deliberately violate a constraint:
- Wrong output value → `"Failed equality constraint: XX != YY"`
- Non-boolean to assert → `"Expected boolean, found: XX"`
- Boolean 0 to assert → `"Failed direct assertion"`
- Value too large for constrain_bits → `"Bit bound failed: XX is not N-bit"`
- Missing witness → `"Ran out of private transcript outputs"`
- Extra witness → `"Transcripts not fully consumed"`
- Tampered public transcript → `"Public transcript input mismatch for input N"`

A rejection in a negative test **confirms** the claim (the constraint is enforced). A rejection in a positive test **refutes** the claim (the expected behavior doesn't hold).

## Step 5: Run the Checker

Write a runner script in the job directory. The exact API depends on what you discovered in Step 1 — reference `CHECKER-API.md` in the workspace.

General pattern:

```javascript
// jobs/$JOB_ID/run-checker.mjs
import { /* checker function */ } from '@midnight-ntwrk/zkir-v2';
import { readFileSync } from 'fs';

const circuit = JSON.parse(readFileSync('./circuit.zkir', 'utf8'));
const inputs = JSON.parse(readFileSync('./inputs.json', 'utf8'));

try {
  const result = /* invoke checker with circuit and inputs */;
  console.log(JSON.stringify({ verdict: 'ACCEPTED', outputs: result }));
} catch (e) {
  console.log(JSON.stringify({ verdict: 'REJECTED', error: e.message }));
}
```

Run it:

```bash
cd .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID
node run-checker.mjs
```

Capture stdout and stderr. If the script throws due to a bug in your test setup (not a checker rejection), fix and retry once.

## Step 6: Interpret and Report

**Report format:**

```
### ZKIR Checker Report

**Claim:** [verbatim]

**Circuit source:** [fixture / compiled from Compact / hand-crafted]

**Circuit:**
\`\`\`json
[.zkir JSON — or Compact source if compiled, with note about where .zkir was extracted]
\`\`\`

**Proof data:**
\`\`\`json
[inputs summary — full JSON for small circuits, key fields for large ones]
\`\`\`

**Checker output:**
\`\`\`
[raw stdout from runner]
\`\`\`

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of what the checker result means for the claim]
```

## Step 7: Clean Up

```bash
rm -rf .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID
```

Do NOT remove the base workspace — it's shared across jobs.
```

Write this to `plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md`.

- [ ] **Step 2: Verify the file was created**

Run: `head -10 plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md`
Expected: Frontmatter with `name: midnight-verify:verify-by-zkir-checker`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md
git commit -m "feat(verify): add verify-by-zkir-checker skill for WASM checker verification

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Create the `verify-by-zkir-inspection` skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```markdown
---
name: midnight-verify:verify-by-zkir-inspection
description: >-
  Verification by compiling Compact to ZKIR and analyzing the compiled circuit
  structure. Extracts .zkir JSON from compilation output, parses instruction
  arrays, counts opcodes, traces data flow, and checks transcript encoding.
  Does not run the WASM checker — for constraint behavior, use
  verify-by-zkir-checker instead. Loaded by the zkir-checker agent.
version: 0.4.0
---

# Verify by ZKIR Inspection

You are verifying a claim about compiled circuit structure by compiling Compact code and analyzing the resulting `.zkir` JSON. Follow these steps in order.

## Critical Rule

**Inspection proves what the compiler emits for specific source. It does NOT prove the circuit is correct.** Proving constraint correctness requires running the checker — use `verify-by-zkir-checker` for that. If the claim spans both structure and behavior, perform inspection first, then hand off to the checker.

## Step 1: Set Up and Compile

Uses the same workspace as the checker method: `.midnight-expert/verify/zkir-workspace/`. Does not require the WASM checker — only the Compact CLI and JSON parsing.

Create a job directory:

```bash
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID
```

Write a minimal `.compact` contract targeting the claim. Only include what's needed to test the specific structural property.

Get the current language version and compile:

```bash
compact compile --language-version
compact compile .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/test-claim.compact --skip-zk
```

Capture the compiler output. Note the compiler version — ZKIR output may change between versions.

## Step 2: Locate and Parse the `.zkir`

After compilation, find the `.zkir` JSON in the build output directory. The typical structure is:

```
test-claim/build/zkir/<circuit-name>.zkir
```

Read the `.zkir` JSON and extract the top-level fields:

```bash
# Quick overview
node -e "
const zkir = JSON.parse(require('fs').readFileSync('<path-to-zkir>', 'utf8'));
console.log(JSON.stringify({
  version: zkir.version,
  do_communications_commitment: zkir.do_communications_commitment,
  num_inputs: zkir.num_inputs,
  instruction_count: zkir.instructions.length,
  opcodes: [...new Set(zkir.instructions.map(i => i.op))].sort()
}, null, 2));
"
```

## Step 3: Analyze Based on the Claim

Perform targeted analysis based on what the claim asserts:

| Claim type | Analysis approach |
|---|---|
| Instruction count | `zkir.instructions.length` |
| Opcode usage | `zkir.instructions.filter(i => i.op === '<opcode>')` — count and list indices |
| Opcode presence/absence | Check if opcode appears: `zkir.instructions.some(i => i.op === '<opcode>')` |
| Transcript encoding | Look for `declare_pub_input` and `pi_skip` instructions (v2), count groups |
| I/O shape | Count `output`, `public_input`, `private_input` instructions |
| Constraint structure | Trace data flow: find constraint instructions, follow their input variable references back through the DAG to see what feeds into them |
| ZKIR version format | Check `zkir.version.major` — 2 for v2, 3 for v3 |
| Variable numbering | In v2, check that instructions reference sequential integer indices. In v3, look for named variables like `%v.0`, `%v.1` |

For complex structural claims, write a small Node.js script in the job directory to perform the analysis and output structured JSON.

## Step 4: Report

```
### ZKIR Inspection Report

**Claim:** [verbatim]

**Compact source:**
\`\`\`compact
[the contract you compiled]
\`\`\`

**Compiler version:** [output of compact compile --language-version]

**ZKIR version:** v2 / v3

**Analysis:**
- Total instructions: N
- [other relevant metrics based on claim type]

**Key findings:**
[specific instructions, indices, and patterns that address the claim]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

## Step 5: Clean Up

```bash
rm -rf .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID
```
```

Write this to `plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md`.

- [ ] **Step 2: Verify the file was created**

Run: `head -10 plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md`
Expected: Frontmatter with `name: midnight-verify:verify-by-zkir-inspection`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md
git commit -m "feat(verify): add verify-by-zkir-inspection skill for circuit structure analysis

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Create the `zkir-regression` skill

**Files:**
- Create: `plugins/midnight-verify/skills/zkir-regression/SKILL.md`

- [ ] **Step 1: Create the skill directory and file**

```markdown
---
name: midnight-verify:zkir-regression
description: >-
  Run the ZKIR test fixture library against the current toolchain to detect
  behavioral changes. Supports full sweep (all opcodes) and targeted sweep
  (single category). Produces a pass/fail report. Invocable as
  /midnight-verify:zkir-regression or loadable by agents as a sense-check
  when they suspect toolchain issues.
version: 0.4.0
argument-hint: "[category: arithmetic|constraints|comparison|control-flow|type-encoding|division|cryptographic|io|transcript]"
---

# ZKIR Regression Sweep

Run the ZKIR fixture library against the current toolchain to detect behavioral changes. Use this when:
- A new compiler version or checker version is released
- An agent suspects unexpected behavior from the toolchain
- You want to validate the fixture library itself after adding new test cases

## Step 1: Determine Mode

If `$ARGUMENTS` is empty → **full sweep** (all categories).

If `$ARGUMENTS` contains a category name → **targeted sweep** (that category only).

Valid categories: `arithmetic`, `constraints`, `comparison`, `control-flow`, `type-encoding`, `division`, `cryptographic`, `io`, `transcript`.

## Step 2: Set Up the Workspace

Ensure `.midnight-expert/verify/zkir-workspace/` is initialized with `@midnight-ntwrk/zkir-v2` installed. Follow the same workspace setup as `verify-by-zkir-checker` Step 1.

## Step 3: Load the Fixture Manifest

Read the manifest from the checker skill's fixtures directory:

```bash
FIXTURES_DIR="${CLAUDE_SKILL_DIR}/../verify-by-zkir-checker/fixtures"
```

If the directory does not exist, report an error:
> "Fixture library not found at expected path. The verify-by-zkir-checker skill may not be installed or the fixtures have not been created yet."

Read `$FIXTURES_DIR/test-cases/manifest.json`. For targeted sweeps, filter `test_cases` by the requested category.

## Step 4: Record Toolchain Versions

```bash
compact compile --language-version
node -e "console.log(require('@midnight-ntwrk/zkir-v2/package.json').version)"
```

Record both for the report header.

## Step 5: Run Each Test Case

For each test case in the (filtered) manifest:

1. Copy the circuit `.zkir` from `$FIXTURES_DIR/circuits/<path>` to a temporary job directory
2. Copy the test case JSON from `$FIXTURES_DIR/test-cases/<path>` to the job directory
3. Run the checker (same invocation as `verify-by-zkir-checker` Step 5)
4. Compare the checker result to the `expect` field:
   - If `expect: "accept"` and checker accepted → **PASS**
   - If `expect: "reject"` and checker rejected → **PASS**
   - Otherwise → **FAIL** — record the expected vs actual result and error message
5. Clean up the job directory

Do NOT stop on first failure — run all test cases and collect all results.

## Step 6: Report

```markdown
## ZKIR Regression Report

**Toolchain:** compact compiler vX.Y.Z, @midnight-ntwrk/zkir-v2@A.B.C
**Fixture version:** [from manifest.json]
**Mode:** [full sweep / targeted: <category>]
**Ran:** N test cases

### Results

| Category | Passed | Failed | Total |
|---|---|---|---|
| arithmetic | N | N | N |
| constraints | N | N | N |
| comparison | N | N | N |
| control-flow | N | N | N |
| type-encoding | N | N | N |
| division | N | N | N |
| cryptographic | N | N | N |
| io | N | N | N |
| transcript | N | N | N |
| **Total** | **N** | **N** | **N** |

### Failures

[For each failure:]

**<test-id>:** Expected <expect>, got <actual>: "<error message>"
- Circuit: <circuit path>
- Interpretation: [what this failure suggests about toolchain changes]
```

If there are zero failures, end with:
> All N test cases passed. Toolchain behavior matches fixture expectations.

## Adding New Fixtures

To add a new test case to the library:

1. Create the `.zkir` circuit in `$FIXTURES_DIR/circuits/<category>/<name>.zkir`
2. Create the test case JSON in `$FIXTURES_DIR/test-cases/<category>/<name>.json` with the circuit reference, proof data, and expected result
3. Add an entry to `$FIXTURES_DIR/test-cases/manifest.json`
4. Run a targeted sweep on the category to verify the new test passes
```

Write this to `plugins/midnight-verify/skills/zkir-regression/SKILL.md`.

- [ ] **Step 2: Verify the file was created**

Run: `head -10 plugins/midnight-verify/skills/zkir-regression/SKILL.md`
Expected: Frontmatter with `name: midnight-verify:zkir-regression`.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/zkir-regression/SKILL.md
git commit -m "feat(verify): add zkir-regression skill for fixture library sweep

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Create fixture templates

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/pure-circuit.json`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/witness-circuit.json`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/transcript-circuit.json`

- [ ] **Step 1: Create the templates directory and pure-circuit template**

```json
{
  "_comment": "Template: pure circuit with no state or witnesses. Load two immediates, apply an operation, constrain the result, output it.",
  "_usage": "Replace IMMEDIATE_A, IMMEDIATE_B, OPERATION, and EXPECTED_RESULT. Variable indices: 0=imm_a, 1=imm_b, 2=op_result, 3=expected.",
  "circuit": {
    "version": { "major": 2, "minor": 0 },
    "do_communications_commitment": false,
    "num_inputs": 0,
    "instructions": [
      { "op": "load_imm", "imm": "IMMEDIATE_A" },
      { "op": "load_imm", "imm": "IMMEDIATE_B" },
      { "op": "OPERATION", "a": 0, "b": 1 },
      { "op": "load_imm", "imm": "EXPECTED_RESULT" },
      { "op": "constrain_eq", "a": 2, "b": 3 },
      { "op": "output", "var": 2 }
    ]
  },
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": ["EXPECTED_RESULT_BYTES"], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

Write to `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/pure-circuit.json`.

- [ ] **Step 2: Create the witness-circuit template**

```json
{
  "_comment": "Template: circuit with a private witness input. The circuit reads a private value and constrains it.",
  "_usage": "Replace WITNESS_TYPE, PUBLIC_VALUE, and constraint logic. Variable 0=private_input result.",
  "circuit": {
    "version": { "major": 2, "minor": 0 },
    "do_communications_commitment": false,
    "num_inputs": 0,
    "instructions": [
      { "op": "private_input", "type": "WITNESS_TYPE", "guard": null },
      { "op": "load_imm", "imm": "PUBLIC_VALUE" },
      { "op": "constrain_eq", "a": 0, "b": 1 }
    ]
  },
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [], "alignment": [] },
    "publicTranscript": [],
    "privateTranscriptOutputs": [
      { "value": ["WITNESS_VALUE_BYTES"], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] }
    ]
  },
  "expect": "accept"
}
```

Write to `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/witness-circuit.json`.

- [ ] **Step 3: Create the transcript-circuit template**

```json
{
  "_comment": "Template: circuit with public transcript (ledger interaction). Uses declare_pub_input and pi_skip for transcript encoding.",
  "_usage": "Replace transcript operations. This template shows a minimal idx+addi+ins pattern (read, increment, write).",
  "circuit": {
    "version": { "major": 2, "minor": 0 },
    "do_communications_commitment": true,
    "num_inputs": 0,
    "instructions": [
      { "op": "load_imm", "imm": "OPCODE_HEX" },
      { "op": "declare_pub_input", "var": 0 },
      { "op": "load_imm", "imm": "OPERAND_HEX" },
      { "op": "declare_pub_input", "var": 2 },
      { "op": "pi_skip", "guard": 0, "count": 2 }
    ]
  },
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [], "alignment": [] },
    "publicTranscript": ["TRANSCRIPT_OPERATIONS"],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

Write to `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/transcript-circuit.json`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/
git commit -m "feat(verify): add ZKIR fixture templates (pure, witness, transcript circuits)

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: Create initial fixture circuits and test cases — arithmetic

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/arithmetic/add-basic.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/arithmetic/add-wrong.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/arithmetic/mul-basic.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/arithmetic/mul-by-zero.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/arithmetic/neg-basic.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/arithmetic/add-basic.json`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/arithmetic/add-wrong.json`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/arithmetic/mul-basic.json`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/arithmetic/mul-by-zero.json`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/arithmetic/neg-basic.json`

This task creates fixture circuits and test cases for the arithmetic category based on the ZKIR reference PDF's oracle traces. Each circuit is a minimal hand-crafted `.zkir` JSON. Each test case bundles the circuit with proof data and expected verdict.

- [ ] **Step 1: Create add-basic circuit (3 + 4 = 7, expect accept)**

`circuits/arithmetic/add-basic.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "03" },
    { "op": "load_imm", "imm": "04" },
    { "op": "add", "a": 0, "b": 1 },
    { "op": "load_imm", "imm": "07" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`test-cases/arithmetic/add-basic.json`:
```json
{
  "description": "add: 3 + 4 = 7",
  "circuit": "circuits/arithmetic/add-basic.zkir",
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [7], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

- [ ] **Step 2: Create add-wrong circuit (3 + 4 != 8, expect reject)**

`circuits/arithmetic/add-wrong.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "03" },
    { "op": "load_imm", "imm": "04" },
    { "op": "add", "a": 0, "b": 1 },
    { "op": "load_imm", "imm": "08" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`test-cases/arithmetic/add-wrong.json`:
```json
{
  "description": "add: 3 + 4 != 8 (wrong expected value)",
  "circuit": "circuits/arithmetic/add-wrong.zkir",
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [7], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "reject"
}
```

- [ ] **Step 3: Create mul-basic circuit (3 * 5 = 15, expect accept)**

`circuits/arithmetic/mul-basic.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "03" },
    { "op": "load_imm", "imm": "05" },
    { "op": "mul", "a": 0, "b": 1 },
    { "op": "load_imm", "imm": "0F" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`test-cases/arithmetic/mul-basic.json`:
```json
{
  "description": "mul: 3 * 5 = 15",
  "circuit": "circuits/arithmetic/mul-basic.zkir",
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [15], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

- [ ] **Step 4: Create mul-by-zero circuit (42 * 0 = 0, expect accept)**

`circuits/arithmetic/mul-by-zero.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "load_imm", "imm": "00" },
    { "op": "mul", "a": 0, "b": 1 },
    { "op": "load_imm", "imm": "00" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`test-cases/arithmetic/mul-by-zero.json`:
```json
{
  "description": "mul: 42 * 0 = 0",
  "circuit": "circuits/arithmetic/mul-by-zero.zkir",
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [0], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

- [ ] **Step 5: Create neg-basic circuit (x + neg(x) = 0, expect accept)**

`circuits/arithmetic/neg-basic.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "neg", "a": 0 },
    { "op": "add", "a": 0, "b": 1 },
    { "op": "load_imm", "imm": "00" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`test-cases/arithmetic/neg-basic.json`:
```json
{
  "description": "neg: x + neg(x) = 0 (additive inverse)",
  "circuit": "circuits/arithmetic/neg-basic.zkir",
  "inputs": {
    "input": { "value": [], "alignment": [] },
    "output": { "value": [0], "alignment": [{ "tag": "atom", "value": { "tag": "field" } }] },
    "publicTranscript": [],
    "privateTranscriptOutputs": []
  },
  "expect": "accept"
}
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/arithmetic/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/arithmetic/
git commit -m "feat(verify): add arithmetic ZKIR fixture circuits and test cases

Covers add (basic + wrong), mul (basic + zero), neg (additive inverse).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: Create initial fixture circuits and test cases — constraints

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/assert-true.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/assert-false.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/assert-two.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/cb-8bit-zero.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/cb-8bit-255.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/cb-8bit-256.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/ceq-equal.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/ceq-unequal.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/ctb-zero.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/ctb-one.zkir`
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/ctb-two.zkir`
- Create: corresponding test-case JSON files in `test-cases/constraints/`

This task mirrors the ZKIR reference's constraint oracle traces. Each circuit follows the same minimal pattern: `load_imm` → constraint instruction → (optional output).

- [ ] **Step 1: Create assert circuits**

`circuits/constraints/assert-true.zkir` — assert with input 1 (boolean true, accept):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "01" },
    { "op": "assert", "cond": 0 }
  ]
}
```

`circuits/constraints/assert-false.zkir` — assert with input 0 (boolean false, reject: "Failed direct assertion"):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "00" },
    { "op": "assert", "cond": 0 }
  ]
}
```

`circuits/constraints/assert-two.zkir` — assert with input 2 (not boolean, reject: "Expected boolean, found: 02"):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "02" },
    { "op": "assert", "cond": 0 }
  ]
}
```

Create corresponding test-case JSON files in `test-cases/constraints/` with appropriate `expect` values (accept, reject, reject).

- [ ] **Step 2: Create constrain_bits circuits**

`circuits/constraints/cb-8bit-zero.zkir` — constrain_bits: 0 fits in 8 bits (accept):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "00" },
    { "op": "constrain_bits", "var": 0, "bits": 8 }
  ]
}
```

`circuits/constraints/cb-8bit-255.zkir` — constrain_bits: 255 fits in 8 bits (accept):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "FF" },
    { "op": "constrain_bits", "var": 0, "bits": 8 }
  ]
}
```

`circuits/constraints/cb-8bit-256.zkir` — constrain_bits: 256 doesn't fit in 8 bits (reject: "Bit bound failed: 0001 is not 8-bit"):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "0100" },
    { "op": "constrain_bits", "var": 0, "bits": 8 }
  ]
}
```

Create corresponding test-case JSON files.

- [ ] **Step 3: Create constrain_eq and constrain_to_boolean circuits**

`circuits/constraints/ceq-equal.zkir` — equal values (accept):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "load_imm", "imm": "2A" },
    { "op": "constrain_eq", "a": 0, "b": 1 }
  ]
}
```

`circuits/constraints/ceq-unequal.zkir` — unequal values (reject):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "load_imm", "imm": "2B" },
    { "op": "constrain_eq", "a": 0, "b": 1 }
  ]
}
```

`circuits/constraints/ctb-zero.zkir` — constrain_to_boolean: 0 is boolean (accept):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "00" },
    { "op": "constrain_to_boolean", "var": 0 }
  ]
}
```

`circuits/constraints/ctb-one.zkir` — constrain_to_boolean: 1 is boolean (accept):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "01" },
    { "op": "constrain_to_boolean", "var": 0 }
  ]
}
```

`circuits/constraints/ctb-two.zkir` — constrain_to_boolean: 2 is not boolean (reject):
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "02" },
    { "op": "constrain_to_boolean", "var": 0 }
  ]
}
```

Create corresponding test-case JSON files for all.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/constraints/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/constraints/
git commit -m "feat(verify): add constraint ZKIR fixture circuits and test cases

Covers assert (true/false/non-boolean), constrain_bits (0/255/256 in 8-bit),
constrain_eq (equal/unequal), constrain_to_boolean (0/1/2).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: Create initial fixture circuits and test cases — comparison, control flow, division

**Files:**
- Create: circuits and test cases for `comparison/` (test_eq, less_than)
- Create: circuits and test cases for `control-flow/` (cond_select, copy)
- Create: circuits and test cases for `division/` (div_mod_power_of_two)

- [ ] **Step 1: Create comparison circuits**

`test_eq` — equal values produce 1, unequal produce 0. Both are accept tests (test_eq doesn't fail, it produces a boolean result):

`circuits/comparison/teq-equal.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "load_imm", "imm": "2A" },
    { "op": "test_eq", "a": 0, "b": 1 },
    { "op": "load_imm", "imm": "01" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`circuits/comparison/teq-unequal.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "load_imm", "imm": "2B" },
    { "op": "test_eq", "a": 0, "b": 1 },
    { "op": "constrain_to_boolean", "var": 2 },
    { "op": "output", "var": 2 }
  ]
}
```

`less_than` — 3 < 10 is true (8-bit), 10 < 3 is false:

`circuits/comparison/lt-true.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "03" },
    { "op": "load_imm", "imm": "0A" },
    { "op": "less_than", "a": 0, "b": 1, "bits": 8 },
    { "op": "load_imm", "imm": "01" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

`circuits/comparison/lt-false.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "0A" },
    { "op": "load_imm", "imm": "03" },
    { "op": "less_than", "a": 0, "b": 1, "bits": 8 },
    { "op": "load_imm", "imm": "00" },
    { "op": "constrain_eq", "a": 2, "b": 3 },
    { "op": "output", "var": 2 }
  ]
}
```

Create corresponding test-case JSON files (all expect accept).

- [ ] **Step 2: Create control flow circuits**

`cond_select` — bit=1 selects first, bit=0 selects second:

`circuits/control-flow/csel-true.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "01" },
    { "op": "load_imm", "imm": "AA" },
    { "op": "load_imm", "imm": "BB" },
    { "op": "cond_select", "bit": 0, "a": 1, "b": 2 },
    { "op": "load_imm", "imm": "AA" },
    { "op": "constrain_eq", "a": 3, "b": 4 },
    { "op": "output", "var": 3 }
  ]
}
```

`circuits/control-flow/csel-false.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "00" },
    { "op": "load_imm", "imm": "AA" },
    { "op": "load_imm", "imm": "BB" },
    { "op": "cond_select", "bit": 0, "a": 1, "b": 2 },
    { "op": "load_imm", "imm": "BB" },
    { "op": "constrain_eq", "a": 3, "b": 4 },
    { "op": "output", "var": 3 }
  ]
}
```

`copy` — copied value equals original:

`circuits/control-flow/copy-basic.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "2A" },
    { "op": "copy", "var": 0 },
    { "op": "constrain_eq", "a": 0, "b": 1 },
    { "op": "output", "var": 1 }
  ]
}
```

Create corresponding test-case JSON files.

- [ ] **Step 3: Create division circuit**

`div_mod_power_of_two` — 11 divmod 2^3 = (1, 3):

`circuits/division/divmod-basic.zkir`:
```json
{
  "version": { "major": 2, "minor": 0 },
  "do_communications_commitment": false,
  "num_inputs": 0,
  "instructions": [
    { "op": "load_imm", "imm": "0B" },
    { "op": "div_mod_power_of_two", "var": 0, "bits": 3 },
    { "op": "load_imm", "imm": "01" },
    { "op": "constrain_eq", "a": 1, "b": 3 },
    { "op": "load_imm", "imm": "03" },
    { "op": "constrain_eq", "a": 2, "b": 5 },
    { "op": "output", "var": 1 },
    { "op": "output", "var": 2 }
  ]
}
```

Create corresponding test-case JSON.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/comparison/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/control-flow/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/division/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/comparison/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/control-flow/
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/division/
git commit -m "feat(verify): add comparison, control flow, division ZKIR fixtures

Covers test_eq, less_than, cond_select, copy, div_mod_power_of_two.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: Create the fixture manifest

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/manifest.json`

- [ ] **Step 1: Create the manifest indexing all test cases from Tasks 7-9**

Build `manifest.json` with entries for every test case created so far. Each entry has: `id`, `category`, `opcode`, `file` (relative path within `test-cases/`), `zkir_version`, `expect`.

```json
{
  "version": "0.1.0",
  "generated_for": "compact-compiler-v0.29.0",
  "checker_package": "@midnight-ntwrk/zkir-v2@2.1.0",
  "test_cases": [
    { "id": "add-basic", "category": "arithmetic", "opcode": "add", "file": "arithmetic/add-basic.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "add-wrong", "category": "arithmetic", "opcode": "add", "file": "arithmetic/add-wrong.json", "zkir_version": "v2", "expect": "reject" },
    { "id": "mul-basic", "category": "arithmetic", "opcode": "mul", "file": "arithmetic/mul-basic.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "mul-by-zero", "category": "arithmetic", "opcode": "mul", "file": "arithmetic/mul-by-zero.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "neg-basic", "category": "arithmetic", "opcode": "neg", "file": "arithmetic/neg-basic.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "assert-true", "category": "constraints", "opcode": "assert", "file": "constraints/assert-true.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "assert-false", "category": "constraints", "opcode": "assert", "file": "constraints/assert-false.json", "zkir_version": "v2", "expect": "reject" },
    { "id": "assert-two", "category": "constraints", "opcode": "assert", "file": "constraints/assert-two.json", "zkir_version": "v2", "expect": "reject" },
    { "id": "cb-8bit-zero", "category": "constraints", "opcode": "constrain_bits", "file": "constraints/cb-8bit-zero.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "cb-8bit-255", "category": "constraints", "opcode": "constrain_bits", "file": "constraints/cb-8bit-255.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "cb-8bit-256", "category": "constraints", "opcode": "constrain_bits", "file": "constraints/cb-8bit-256.json", "zkir_version": "v2", "expect": "reject" },
    { "id": "ceq-equal", "category": "constraints", "opcode": "constrain_eq", "file": "constraints/ceq-equal.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "ceq-unequal", "category": "constraints", "opcode": "constrain_eq", "file": "constraints/ceq-unequal.json", "zkir_version": "v2", "expect": "reject" },
    { "id": "ctb-zero", "category": "constraints", "opcode": "constrain_to_boolean", "file": "constraints/ctb-zero.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "ctb-one", "category": "constraints", "opcode": "constrain_to_boolean", "file": "constraints/ctb-one.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "ctb-two", "category": "constraints", "opcode": "constrain_to_boolean", "file": "constraints/ctb-two.json", "zkir_version": "v2", "expect": "reject" },
    { "id": "teq-equal", "category": "comparison", "opcode": "test_eq", "file": "comparison/teq-equal.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "teq-unequal", "category": "comparison", "opcode": "test_eq", "file": "comparison/teq-unequal.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "lt-true", "category": "comparison", "opcode": "less_than", "file": "comparison/lt-true.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "lt-false", "category": "comparison", "opcode": "less_than", "file": "comparison/lt-false.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "csel-true", "category": "control-flow", "opcode": "cond_select", "file": "control-flow/csel-true.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "csel-false", "category": "control-flow", "opcode": "cond_select", "file": "control-flow/csel-false.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "copy-basic", "category": "control-flow", "opcode": "copy", "file": "control-flow/copy-basic.json", "zkir_version": "v2", "expect": "accept" },
    { "id": "divmod-basic", "category": "division", "opcode": "div_mod_power_of_two", "file": "division/divmod-basic.json", "zkir_version": "v2", "expect": "accept" }
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/manifest.json
git commit -m "feat(verify): add ZKIR fixture manifest indexing all test cases

24 test cases across 5 categories (arithmetic, constraints, comparison,
control-flow, division).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Future: Expand fixture library (cryptographic, io, transcript, type-encoding)

Tasks 7-9 create 24 fixtures covering the simpler opcode categories. The remaining categories — cryptographic (ec_mul, ec_mul_generator, hash_to_curve, persistent_hash, transient_hash), I/O (private_input, public_input, output, impact), transcript (full counter/guarded_counter circuits), and type-encoding (encode, decode, reconstitute_field) — require more complex circuit construction:

- **Cryptographic:** Multi-output instructions (two field elements for point coordinates), curve point alignment metadata
- **I/O:** Witness data in `privateTranscriptOutputs`, guarded inputs
- **Transcript:** Full `declare_pub_input`/`pi_skip` encoding, `publicTranscript` VM operations
- **Type encoding:** v3-only opcodes (encode/decode), `reconstitute_field` with bit-width parameters

These should be added iteratively after the initial fixture set is validated against the WASM checker and the checker API is documented in `CHECKER-API.md`. Target: mirror the ZKIR reference's 68 v2 oracle traces. Update `manifest.json` as new fixtures are added.

---

### Task 11: Update `verify-correctness` hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Add ZKIR domain to classification table**

In the `### 1. Classify the Domain` section, add a new row to the table after the SDK/TypeScript row:

```markdown
| **ZKIR** | ZKIR opcodes, circuit constraints, field elements, proof data, `.zkir` files, transcript protocol, checker behavior, circuit structure | Load `midnight-verify:verify-zkir` |
```

And update the Cross-domain row to include ZKIR:

```markdown
| **Cross-domain** | Spans Compact and SDK, Compact and ZKIR, or protocol/architecture | Load applicable domain skills |
```

- [ ] **Step 2: Add ZKIR dispatch instructions**

In the `### 3. Dispatch Sub-Agents` section, add after the package/version check entry:

```markdown
- **ZKIR checker verification needed** → dispatch `midnight-verify:zkir-checker` agent with the claim and whether to use the checker method, inspection method, or both
- **ZKIR regression sweep needed** → dispatch `midnight-verify:zkir-checker` agent and instruct it to load the `midnight-verify:zkir-regression` skill
```

- [ ] **Step 3: Add ZKIR verdict qualifiers**

In the `### 4. Synthesize the Verdict` section, add these rows to the verdict table:

```markdown
| **Confirmed** | (zkir-checked) | WASM checker accepted the circuit with expected inputs |
| **Confirmed** | (zkir-checked + tested) | Both WASM checker and Compact JS runtime agree |
| **Confirmed** | (zkir-inspected) | Circuit structure analysis confirms the claim |
| **Confirmed** | (zkir-checked + source-verified) | Checker result corroborated by source inspection |
| **Refuted** | (zkir-checked) | WASM checker produced unexpected accept/reject for the claim |
| **Refuted** | (zkir-inspected) | Circuit structure contradicts the claim |
| **Inconclusive** | (zkir-checker unavailable) | `@midnight-ntwrk/zkir-v2` could not be installed or loaded |
```

Add to the conflict resolution paragraph:

```markdown
**When WASM checker and Compact JS runtime disagree:** The checker is more authoritative for constraint behavior (it operates at the proof system level). The JS runtime is more authoritative for output values (it runs the actual contract logic). Flag the disagreement in your report.
```

- [ ] **Step 4: Update the version in frontmatter to 0.4.0**

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(verify): add ZKIR domain, dispatch, and verdicts to hub skill

Adds ZKIR classification, zkir-checker dispatch instructions, 7 new verdict
qualifiers, and checker/runtime conflict resolution guidance.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 12: Update `verify-compact` routing skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-compact/SKILL.md`

- [ ] **Step 1: Add ZKIR-related rows to the routing table**

After the "Performance claims" row in the `## Claim Type → Method Routing` table, add:

```markdown
| Circuit constraint structure | "this contract produces N constraints" | **zkir-checker** (inspection) |
| Compiled ZKIR properties | "disclosure compiles to declare_pub_input" | **zkir-checker** (inspection) |
| Constraint correctness | "guard circuit correctly constrains authority hash" | **zkir-checker** (checker) + **contract-writer** (concurrent) |
```

- [ ] **Step 2: Update the version in frontmatter to 0.3.0**

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-compact/SKILL.md
git commit -m "feat(verify): add ZKIR routing rows to verify-compact skill

Routes circuit structure, compiled ZKIR properties, and constraint correctness
claims to the zkir-checker agent.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 13: Update `verify-by-execution` skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-execution/SKILL.md`

- [ ] **Step 1: Add optional ZKIR extraction step**

After `## Step 4: Compile` and before `## Step 5: Write and Run the Runner Script`, add:

```markdown
## Step 4.5: Extract ZKIR (Optional)

If the verifier requested ZKIR-level evidence alongside execution results, locate the `.zkir` JSON in the compilation output. It is typically found at:

```
<contract-name>/build/zkir/<circuit-name>.zkir
```

If found, note the path in your report so the verifier can dispatch the `zkir-checker` agent if needed. Do NOT run the checker yourself — your job is compilation and JS runtime execution.

If no `.zkir` output is found (some compilation modes may not produce it), note this in your report.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-execution/SKILL.md
git commit -m "feat(verify): add optional ZKIR extraction step to execution skill

Allows contract-writer to surface .zkir paths for cross-method verification.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 14: Update `verifier` agent and `plugin.json`

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`
- Modify: `plugins/midnight-verify/.claude-plugin/plugin.json`

- [ ] **Step 1: Update the verifier agent to include ZKIR dispatch**

In the `## Dispatching Sub-Agents` section, add after the SDK verification block:

```markdown
**ZKIR verification:**
- Checker verification → dispatch `midnight-verify:zkir-checker`
- Circuit inspection → dispatch `midnight-verify:zkir-checker`
- Regression sweep → dispatch `midnight-verify:zkir-checker` with instruction to load `midnight-verify:zkir-regression`
```

Update the `skills:` frontmatter to add `midnight-verify:verify-zkir`:

```
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk, midnight-verify:verify-zkir
```

Add a ZKIR example to the `description:` frontmatter:

```
  Example 6: User runs /verify "constrain_bits enforces 8-bit range" — the
  orchestrator classifies this as a ZKIR opcode claim, dispatches the
  zkir-checker agent to run fixture circuits through the WASM checker.
```

- [ ] **Step 2: Update plugin.json**

Change `version` from `"0.3.0"` to `"0.4.0"`.

Add to `keywords` array: `"zkir"`, `"circuit"`, `"proof"`, `"checker"`, `"wasm"`.

Update `description` to include ZKIR:

```json
"description": "Verification framework for Midnight claims — verifies Compact code by compiling and executing test contracts, SDK/TypeScript claims by type-checking and devnet E2E testing, ZKIR circuits by running through the WASM checker and inspecting compiled structure, or by inspecting source code. Multi-agent pipeline with explicit /verify command."
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md plugins/midnight-verify/.claude-plugin/plugin.json
git commit -m "chore(verify): bump version to 0.4.0, add ZKIR to verifier and plugin manifest

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 15: Validate the complete plugin structure

- [ ] **Step 1: Verify all new files exist**

```bash
echo "=== New agent ===" && ls plugins/midnight-verify/agents/zkir-checker.md
echo "=== New skills ===" && ls plugins/midnight-verify/skills/verify-zkir/SKILL.md plugins/midnight-verify/skills/verify-by-zkir-checker/SKILL.md plugins/midnight-verify/skills/verify-by-zkir-inspection/SKILL.md plugins/midnight-verify/skills/zkir-regression/SKILL.md
echo "=== Fixtures ===" && ls plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/templates/ && ls plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/manifest.json
echo "=== Circuit categories ===" && ls plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/circuits/
echo "=== Test case categories ===" && ls plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/
```

Expected: All files present. Circuit categories: arithmetic, constraints, comparison, control-flow, division. Test case categories match.

- [ ] **Step 2: Verify all skill frontmatter parses correctly**

```bash
for f in plugins/midnight-verify/skills/*/SKILL.md; do echo "--- $f ---"; head -3 "$f"; done
```

Expected: Each skill file starts with `---` and has a `name:` field.

- [ ] **Step 3: Verify plugin.json version is 0.4.0**

```bash
cat plugins/midnight-verify/.claude-plugin/plugin.json | grep version
```

Expected: `"version": "0.4.0"`

- [ ] **Step 4: Count total test cases in manifest matches fixture files**

```bash
node -e "const m = JSON.parse(require('fs').readFileSync('plugins/midnight-verify/skills/verify-by-zkir-checker/fixtures/test-cases/manifest.json','utf8')); console.log('Manifest entries:', m.test_cases.length)"
```

Expected: 24 test cases.

- [ ] **Step 5: Commit final validation (if any fixes were needed)**

Only commit if fixes were made during validation. Otherwise, move on.
