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
- `compact-core:compact-standard-library` skill — expected function signatures, what exists
- `compact-core:compact-structure` skill — how to structure a contract (pragma, imports, exports)
- `compact-core:compact-language-ref` skill — syntax reference, type system, operators
- `compact-core:compact-privacy-disclosure` skill — disclosure rules to test
- `midnight-tooling:compact-cli` skill — expected compiler behavior

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

Or load the `midnight-tooling:compact-cli` skill for details on version management.

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

Load the `midnight-tooling:compact-cli` skill for compilation flags, version management, and troubleshooting.

```bash
compact compile .midnight-expert/verify/compact-workspace/jobs/$JOB_ID/test-<claim>.compact --skip-zk
```

**If compilation succeeds:** Proceed to Step 5. The compiled output will be in `test-<claim>/build/` relative to where you ran the command, or in the contract's output directory. Check for the `contract/index.js` file.

**If compilation fails:**

- If the claim said "this syntax is valid" or "this code works" → the claim is **Refuted (tested)**. The compiler error is your evidence.
- If the claim said "this should fail" → the failure **Confirms (tested)** the claim. Check the error message matches what was expected.
- If the failure is unexpected (you think your test contract has a bug, not the claim) → fix the contract and retry. If you can't write a valid test after 2 attempts, report as **Inconclusive** and explain why.

Capture the full compiler output (stdout and stderr) regardless of success or failure.

## Step 4.5: Extract ZKIR (Optional)

If the orchestrator requested ZKIR-level evidence alongside execution results, locate the `.zkir` JSON in the compilation output. It is typically found at:

```
<contract-name>/build/zkir/<circuit-name>.zkir
```

If found, note the path in your report so the orchestrator can dispatch @"midnight-verify:zkir-checker (agent)" if needed. Do NOT run the checker yourself — your job is compilation and JS runtime execution.

If no `.zkir` output is found (some compilation modes may not produce it), note this in your report.

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

## Ledger Execution Mode

When dispatched for a ledger/protocol claim, you compile and execute a Compact contract as usual, but after execution you extract **ledger-level evidence** — cost data, transaction properties, well-formedness results — in addition to the normal runtime output.

**When to use this mode:** The orchestrator dispatches you with a ledger claim that is testable via compilation. Examples:
- "Fee calculation uses max(read, compute, block) + write + churn" → compile a contract, compute its cost
- "Well-formedness rejects overlapping inputs" → build a transaction with overlapping inputs, check wellFormed() rejects
- "Counter increment costs N bytes of block usage" → compile counter, measure SyntheticCost.block_usage

**What to extract after compilation and execution:**

| Claim type | What to extract | How |
|---|---|---|
| Cost model claims | SyntheticCost breakdown | Call `cost(LedgerParameters.initialParameters())` on the compiled transaction; reads a `SyntheticCost` (camelCase bigint fields) |
| Well-formedness claims | Acceptance/rejection | Call `wellFormed(refState, new WellFormedStrictness(), tblock)`; it returns a `VerifiedTransaction` and throws on invalid |
| Balance claims | Per-segment per-token balance | Inspect transaction structure after construction |
| Transaction structure | Intent/offer properties | Read compiled transaction fields |
| Proof staging | Stage transitions | Construct UnprovenTransaction, call `prove()`, observe state change |

**Extended runner script pattern:**

After the normal circuit execution (Step 5), add ledger-level evidence extraction:

```javascript
import { LedgerParameters, WellFormedStrictness } from '@midnight-ntwrk/ledger-v8';

// ... normal circuit execution from Step 5 ...

// Extract cost data. `cost()` takes LedgerParameters and returns a SyntheticCost
// whose fields are camelCase bigints. (There is no CostModel.calculate(); the
// only CostModel factory is the static CostModel.initialCostModel().)
const cost = transaction.cost(LedgerParameters.initialParameters());
console.log(JSON.stringify({
  circuitResult: result,
  cost: {
    readTime: cost.readTime.toString(),
    computeTime: cost.computeTime.toString(),
    blockUsage: cost.blockUsage.toString(),
    bytesWritten: cost.bytesWritten.toString(),
    bytesChurned: cost.bytesChurned.toString(),
  },
}));

// Well-formedness. `wellFormed(refState, strictness, tblock)` returns a
// VerifiedTransaction and THROWS if the transaction is not well-formed — it is
// NOT a boolean. Build strictness with `new WellFormedStrictness()` (there is no
// WellFormedStrictness.default()). `refState` is the LedgerState to validate
// against (e.g. `LedgerState.blank(networkId)` for an isolated check).
let wellFormed;
try {
  transaction.wellFormed(refState, new WellFormedStrictness(), new Date());
  wellFormed = true;
} catch (e) {
  wellFormed = { ok: false, error: String(e) };
}
console.log(JSON.stringify({ wellFormed }));
```

**Include the ledger-level evidence in your report** alongside the normal execution report. The orchestrator uses both to synthesize the verdict.
