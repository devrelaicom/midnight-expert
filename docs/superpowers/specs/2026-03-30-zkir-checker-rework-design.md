# ZKIR Checker Rework Design

**Date:** 2026-03-30
**Plugin:** midnight-verify (v0.4.0)
**Scope:** Rework verify-by-zkir-checker, zkir-regression, and fixtures based on real WASM checker API discovery

## Problem

The initial ZKIR verification implementation assumed the `@midnight-ntwrk/zkir-v2` WASM package was a simple constraint checker: feed it `.zkir` JSON + proof data, get accept/reject. Investigation revealed it's a **full PLONK prover/verifier** that requires:

- A `serializedPreimage` (Uint8Array) — not raw JSON
- PLONK proving keys (circuit-specific, generated during compilation)
- PLONK trusted setup parameters (from `~/.compact/params/params_${k}.bin`)

Hand-crafted `.zkir` circuits cannot be executed through this checker — only circuits compiled from Compact (without `--skip-zk`) produce the required keys.

## Verified Pipeline

Tested and confirmed working:

```
Compact source (compiled in place, output directed to job dir)
  → compact compile -- <source-path> <job-dir>/build/   (WITHOUT --skip-zk)
  → produces: zkir/<circuit>.zkir, zkir/<circuit>.bzkir, keys/<circuit>.prover, keys/<circuit>.verifier
  → execute circuit via JS runtime (import build/contract/index.js)
  → proofDataIntoSerializedPreimage(input, output, publicTranscript, privateTranscriptOutputs, keyLocation)
      (5 individual arguments, not an object)
  → check(serializedPreimage, keyProvider)
      keyProvider.lookupKey() → { proverKey, verifierKey, ir }
      keyProvider.getParams(k) → reads ~/.compact/params/params_${k}.bin
  → ACCEPTED (returns output array) or REJECTED (throws with specific error message)
```

Error messages match the ZKIR reference catalog exactly:
- `"Communications commitment mismatch"` — tampered raw bytes
- `"Public transcript input mismatch for input N; expected: Some(XX), computed: Some(YY)"` — wrong transcript values
- `"Failed direct assertion"`, `"Expected boolean, found: XX"`, `"Bit bound failed"`, etc.

## What Changes

### Delete: All fixture files (52 files)

Delete everything under `skills/verify-by-zkir-checker/fixtures/`:
- `circuits/` — 5 subdirectories with hand-crafted `.zkir` files
- `templates/` — 3 template JSON files
- `test-cases/` — 5 subdirectories with test case JSON files + `manifest.json`

These cannot be executed through the real checker and have no value as reference material — the agent can always read `.zkir` output from compilation.

### Rewrite: `verify-by-zkir-checker` skill

**Two modes:**

**Contract mode** (primary) — user provides a `.compact` file or path. Compile it in place (it may have imports/dependencies), directing build output to the job directory.

**Claim mode** — natural language claim about ZK behavior. Agent writes a minimal contract in the job directory.

**Step-by-step flow:**

1. **Workspace setup** — lazy init at `.midnight-expert/verify/zkir-workspace/` with `@midnight-ntwrk/zkir-v2` and `@midnight-ntwrk/compact-runtime`. Job directory via `JOB_ID=$(uuidgen)`.

2. **Get the contract:**
   - Contract mode: locate user's `.compact` file where it lives. Compile in place, directing output to job directory.
   - Claim mode: write minimal `.compact` in the job directory, compile there.

3. **Compile without `--skip-zk`** — `compact compile -- <source-path> <job-dir>/build/`. Produces `zkir/<circuit>.zkir`, `zkir/<circuit>.bzkir`, `keys/<circuit>.prover`, `keys/<circuit>.verifier`, `contract/index.js`, `compiler/contract-info.json`. If the contract was already compiled with keys elsewhere, copy the build artifacts instead.

4. **Execute via JS runtime** — import compiled contract from `<job-dir>/build/contract/index.js`. Create state with appropriate context. Execute the circuit method(s) via the `circuits` interface (e.g., `contract.circuits.increment(context)`). The result contains `proofData` with `input`, `output`, `publicTranscript`, `privateTranscriptOutputs`.

5. **Serialize proof data** — `compactRuntime.proofDataIntoSerializedPreimage(input, output, publicTranscript, privateTranscriptOutputs, keyLocation)`. Takes 5 individual arguments. Returns `Uint8Array`.

6. **Run the checker** — create `keyProvider`:
   ```javascript
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
   ```
   Call `check(serializedPreimage, keyProvider)`. Accept = returns array of outputs. Reject = throws with error message.

7. **Negative testing** (when appropriate) — for claims about rejection behavior, tamper with proof data before serialization (modify transcript values, swap witness data, alter outputs) and confirm the checker rejects with expected error.

8. **Multi-circuit contracts** — check `compiler/contract-info.json` for circuits with `"proof": true`. In contract mode, verify each provable circuit. In claim mode, only the relevant circuit.

9. **Report and clean up.**

**Critical rules:**
- Always compile without `--skip-zk`. The whole point is using the real PLONK verifier.
- Compile the contract where it lives (it may have imports). Only direct the build output to the job directory.
- `proofDataIntoSerializedPreimage` takes 5 individual arguments, not an object.
- `keyProvider.getParams(k)` loads PLONK trusted setup params from `~/.compact/params/params_${k}.bin`. These are installed with the Compact CLI.
- Checker accept returns an array (outputs as bigint, `undefined` for void). Checker reject throws with an error message.
- A checker ACCEPT proves the ZK proof is valid for those specific inputs. It does NOT prove the circuit is correct for all inputs.

**What this proves that `verify-by-execution` doesn't:** The execution skill compiles with `--skip-zk` and runs the JS runtime — it proves the contract logic works. This skill runs the full ZK pipeline — it proves the contract's zero-knowledge proof is valid: constraints are satisfied, transcript encoding is correct, proof data serializes properly, and the PLONK verifier accepts.

### Rewrite: `zkir-regression` skill

No fixtures, no cached artifacts. A curated list of claims with expected verdicts, embedded in the skill file itself.

**The claim list** is a markdown table in the skill:

```markdown
| ID | Category | Claim | Expected |
|---|---|---|---|
| arith-1 | arithmetic | Adding two Uint32 values produces the correct sum | Confirmed |
| ...etc |
```

**How the sweep works:**
1. Parse the claim list from the skill
2. For each claim, dispatch the normal verification pipeline (verifier → appropriate agents)
3. Compare the verdict against the expected result
4. Collect all results, report pass/fail

**Two modes:**
- Full sweep — all claims
- Targeted — `/midnight-verify:zkir-regression <category>`

**Report format:** Table of category/passed/failed, details on failures.

**Adding new claims:** Add a row to the table in the skill file.

### Update: `zkir-checker` agent

Remove references to hand-crafted `.zkir` and fixture library. Replace with:
- "You may compile contracts in place (directing build output to the job directory) for user-provided contracts, or write minimal contracts in the job directory for claim-based verification."

### Update: `verify-by-zkir-inspection` skill

Add note about shared compilation: when both inspection and checker methods are needed for the same contract, compile once without `--skip-zk` and share the build output. Don't compile twice.

## File Changes

| Action | Path |
|---|---|
| **Delete** | `skills/verify-by-zkir-checker/fixtures/` (entire directory, 52 files) |
| **Rewrite** | `skills/verify-by-zkir-checker/SKILL.md` |
| **Rewrite** | `skills/zkir-regression/SKILL.md` |
| **Update** | `agents/zkir-checker.md` |
| **Update** | `skills/verify-by-zkir-inspection/SKILL.md` |
| No change | All other components (routing, hub, compact, execution, verifier, plugin.json) |
