# Witness Verification Design

**Date:** 2026-03-30
**Plugin:** midnight-verify (v0.4.0 → v0.5.0)
**Scope:** Add cross-domain witness verification to the midnight-verify plugin

## Problem

Witnesses in Midnight span two languages: Compact declares them (no implementation body), TypeScript implements them. The current verify plugin handles these separately — `verify-compact` routes Compact claims to the contract-writer, `verify-sdk` routes TypeScript claims to the type-checker. But there's no verification of the **interface between them**:

- Does the TypeScript witness implementation match the Compact contract's declarations?
- Do the type mappings hold (Field→bigint, Bytes<N>→Uint8Array, etc.)?
- Does the witness return the correct `[PrivateState, ReturnValue]` tuple?
- Does the combined contract + witness actually work end-to-end?

## Scope

Full cross-domain consistency verification:

1. **Type correctness** — TypeScript witness type-checks against the compiled contract's generated `Witnesses` type
2. **Structural analysis** — automated checklist checks for name matching, return tuple shape, WitnessContext usage, private state immutability, no side effects
3. **Behavioral correctness** — execute the contract with the provided witness via JS runtime, verify it produces valid results
4. **Optional devnet E2E** — when devnet is available, dispatch to sdk-tester for the full deploy+call lifecycle

## New Components

### Agent: `witness-verifier`

- **Model:** opus (understanding two languages + type mapping rules + structural patterns is high-judgment)
- **Color:** orange
- **Skills:** `verify-by-witness`
- **Responsibilities:**
  - Compile the Compact contract
  - Type-check the TypeScript witness against the compiled contract's generated types
  - Run structural checklist (name matching, return tuple, WitnessContext, immutability, side effects)
  - Execute the circuit with the provided witness via JS runtime
  - Dispatch to `sdk-tester` for devnet E2E when available
- **Does NOT do:** Domain classification, verdict synthesis, PLONK proof verification (dispatch to zkir-checker if needed)
- **Input patterns:**
  - Two files: `.compact` path + `.ts` path
  - Claim: natural language, agent identifies or asks for relevant files

### Skill: `verify-witness` (domain routing)

Classifies witness claims and dispatches to the witness-verifier.

**Claim Type → Method Routing:**

| Claim Type | Example | Dispatch |
|---|---|---|
| Witness type correctness | "This witness correctly implements the contract interface" | **witness-verifier** |
| Witness name matching | "The witness names match the contract declarations" | **witness-verifier** |
| Witness return type | "This witness returns the correct [PrivateState, ReturnValue] tuple" | **witness-verifier** |
| Type mapping correctness | "The Field parameters map to bigint in the witness" | **witness-verifier** |
| Witness behavioral correctness | "This contract + witness combination produces valid results" | **witness-verifier** |
| Private state patterns | "This witness doesn't mutate private state in place" | **witness-verifier** |
| WitnessContext usage | "This witness correctly uses the ledger from WitnessContext" | **witness-verifier** |
| Two-file verification | `/verify contracts/counter.compact src/witnesses.ts` | **witness-verifier** (both files) |
| Witness + devnet E2E | "This witness works correctly when deployed" | **witness-verifier** + **sdk-tester** (concurrent) |
| Witness + ZK proof | "This contract + witness produces a valid ZK proof" | **witness-verifier** first, then **zkir-checker** (sequential — witness-verifier passes build output path) |

**When in doubt:**
- Claims about the contract-witness interface → **witness-verifier**
- Claims about just the TypeScript types (no contract involved) → **type-checker** (existing SDK path)
- Claims about just the Compact declarations (no witness implementation) → **contract-writer** (existing Compact path)

### Skill: `verify-by-witness` (method)

Five-phase pipeline:

**Phase 1 — Setup and Locate Files**

Workspace: `.midnight-expert/verify/witness-workspace/` with `@midnight-ntwrk/compact-runtime` and `typescript`. Job directory via `uuidgen`.

```bash
mkdir -p .midnight-expert/verify/witness-workspace
cd .midnight-expert/verify/witness-workspace
npm init -y
npm install @midnight-ntwrk/compact-runtime typescript
```

Two input paths:
- **Two files provided:** Verify both exist. Compact file stays where it is (may have imports). Copy the `.ts` witness file to the job directory.
- **Claim provided:** Identify the relevant files from the claim text. If the claim names specific files, locate them. If not, ask.

**Phase 2 — Compile and Type-Check**

1. Compile the `.compact` contract: `compact compile -- --skip-zk <source-path> <job-dir>/build/`. Compile in place (contract may have imports), directing build output to job directory.
2. The compiled output at `build/contract/index.d.ts` exports a `Witnesses` type that defines what TypeScript implementations must satisfy.
3. Create a type-check harness in the job directory that imports the witness file and checks it against the generated types.
4. Run `tsc --noEmit`. Clean = types match. Errors = type mismatches are evidence.

If the claim also requires PLONK verification, compile without `--skip-zk` so the build output can be passed to the zkir-checker without recompiling.

**Phase 3 — Structural Checklist**

Automated checks derived from the `compact-review:witness-consistency-review` checklist:

| Check | How | Evidence |
|---|---|---|
| Name matching | Parse witness declarations from compiled `index.d.ts`, grep for same names in `.ts` file | Missing or misspelled names |
| Return tuple shape | Check each witness function returns `[PrivateState, T]` not just `T` | Missing tuple wrapper |
| WitnessContext first param | Check each witness function's first parameter is typed as `WitnessContext` | Wrong first parameter |
| Private state immutability | Check for spread/Object.assign patterns (correct) vs direct mutation (incorrect) | Direct mutation patterns |
| No side effects | Check for `console.log`, `fetch`, `fs`, `Math.random` and other non-deterministic calls | Non-deterministic code |

These are heuristic checks — not as authoritative as compilation/execution — but catch common mistakes. Report findings alongside mechanical results.

**Phase 4 — Execute with Witness**

1. Import the compiled contract and the witness implementation
2. Create a `Contract` instance with the witness object
3. Create initial state with appropriate context
4. Execute each circuit that uses witnesses (check `contract-info.json`)
5. Capture the result — success means the contract + witness combination produces valid proof data

If execution throws, the error identifies whether it's a witness problem (wrong return type, missing witness, type mismatch at runtime) or a contract problem.

**Phase 5 — Optional Devnet E2E**

If devnet is available (check health via `midnight-tooling:devnet`), dispatch to `sdk-tester` for the full deploy+call lifecycle with the witness. If unavailable, note: "Behavioral verification passed locally. Devnet E2E verification requires a running devnet."

**Report format:**

```markdown
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

**Clean up:** `rm -rf .midnight-expert/verify/witness-workspace/jobs/$JOB_ID`

## Cross-Agent Coordination

When a claim spans Witness + ZKIR (e.g., "this contract + witness produces a valid ZK proof"):

1. Verifier dispatches `witness-verifier` first
2. Witness-verifier compiles without `--skip-zk` (producing PLONK keys), runs its full pipeline, reports results including the build output path
3. Verifier passes the build output path to `zkir-checker`
4. The `verify-by-zkir-checker` skill already supports pre-compiled artifacts: "If the contract was already compiled with keys elsewhere, copy the build artifacts instead"
5. zkir-checker runs PLONK verification using the pre-compiled artifacts

This avoids double compilation. The sequencing is: witness-verifier → zkir-checker (not concurrent, because zkir-checker depends on the build output).

## Modified Components

### `verify-correctness` hub skill

**New domain row:**

| Domain | Indicators | Route To |
|---|---|---|
| **Witness** | Witness implementation, WitnessContext, private state, `[PrivateState, T]` return tuple, `.compact` + `.ts` file pair, witness declarations, type mappings | Load `midnight-verify:verify-witness` |

**New verdict qualifiers:**

| Verdict | Qualifier | When to Use |
|---|---|---|
| Confirmed | (witness-verified) | Type check + structural checklist + execution all pass |
| Confirmed | (witness-verified + tested) | Local verification + devnet E2E both pass |
| Confirmed | (witness-verified + zkir-checked) | Witness verification + PLONK proof valid |
| Refuted | (witness-verified) | Type check, structural check, or execution failed |
| Inconclusive | (devnet unavailable) | Local verification passed but devnet E2E needed and unavailable |

**New dispatch instruction:** When witness + ZK claim, dispatch witness-verifier first, then pass build output path to zkir-checker.

### `verify-sdk` routing skill

Update the existing witness row:

From: `Witness implementation → type-checker (+ contract-writer for the Compact side)`
To: `Witness implementation → witness-verifier`

### `verifier` agent

Add witness dispatch block, Example 7 for witness verification, and `midnight-verify:verify-witness` to the skills list.

### `plugin.json`

Bump version to `0.5.0`. Add keyword `witness`.

## File Changes

| Action | Path |
|---|---|
| **Create** | `agents/witness-verifier.md` |
| **Create** | `skills/verify-witness/SKILL.md` |
| **Create** | `skills/verify-by-witness/SKILL.md` |
| **Modify** | `skills/verify-correctness/SKILL.md` |
| **Modify** | `skills/verify-sdk/SKILL.md` |
| **Modify** | `agents/verifier.md` |
| **Modify** | `.claude-plugin/plugin.json` |

## End-to-End Flow Examples

### Scenario 1: Two-file verification

```
/verify contracts/counter.compact src/witnesses.ts

→ verifier: two files (.compact + .ts), Domain = Witness
→ witness-verifier:
  Phase 2: Compile → type-check witness against generated types → PASS
  Phase 3: Checklist all PASS
  Phase 4: Execute with witness → success
  Phase 5: Devnet unavailable → skip
→ verifier: Confirmed (witness-verified)
```

### Scenario 2: Natural language claim

```
/verify "The increment witness correctly implements the counter contract"

→ verifier: Domain = Witness
→ witness-verifier: asks user for file paths (or finds from context)
  ...proceeds through phases...
→ verifier: Confirmed (witness-verified)
```

### Scenario 3: Witness + ZK proof

```
/verify "This counter contract + witness produces a valid ZK proof"

→ verifier: Domain = Witness + ZKIR (sequential)
  Step 1: witness-verifier compiles without --skip-zk, runs pipeline
  Step 2: passes build output to zkir-checker for PLONK verification
→ verifier: Confirmed (witness-verified + zkir-checked)
```

### Scenario 4: Structural issue detected

```
/verify contracts/guarded.compact src/witnesses.ts

→ witness-verifier:
  Phase 2: tsc clean
  Phase 3: Return tuple shape FAIL — authorize() returns bigint not [PrivateState, bigint]
  Phase 4: Execution fails — "expected tuple, got bigint"
→ verifier: Refuted (witness-verified) — witness return type missing tuple wrapper
```
