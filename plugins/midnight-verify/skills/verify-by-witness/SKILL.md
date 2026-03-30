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
