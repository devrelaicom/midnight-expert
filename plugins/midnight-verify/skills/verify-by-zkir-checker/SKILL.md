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
