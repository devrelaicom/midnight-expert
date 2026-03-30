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

## Shared Compilation

When the zkir-checker agent is running both inspection and checker methods for the same contract, compile once without `--skip-zk` and share the build output. The `.zkir` JSON produced by full compilation is identical to `--skip-zk` output — the only difference is that full compilation also generates PLONK keys. Don't compile twice.

If the checker method has already compiled the contract, use its build output for inspection. If running inspection alone, `--skip-zk` is fine since you only need the `.zkir` JSON.

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
compact compile -- --skip-zk <source-path> .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/build/
```

For user-provided contracts, compile the contract where it lives (it may have imports) and direct only the build output to the job directory.

If this inspection will be followed by checker verification, omit `--skip-zk` to avoid recompiling:

```bash
compact compile -- <source-path> .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID/build/
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
