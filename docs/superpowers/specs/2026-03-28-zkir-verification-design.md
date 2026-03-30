# ZKIR Verification Design

**Date:** 2026-03-28
**Plugin:** midnight-verify (v0.3.0 → v0.4.0)
**Scope:** Add ZKIR-level verification to the midnight-verify plugin

## Problem

The midnight-verify plugin can verify Compact claims by compiling and executing code (contract-writer), inspect source repos (source-investigator), type-check SDK usage (type-checker), and run E2E devnet tests (sdk-tester). But it has no method for verifying claims at the **ZKIR circuit level** — the zero-knowledge intermediate representation that the Compact compiler targets.

This means claims about circuit constraint behavior, opcode semantics, compiled circuit structure, the public transcript protocol, and field arithmetic properties cannot be verified with ground truth. The `@midnight-ntwrk/zkir-v2` WASM checker provides a deterministic accept/reject oracle for ZKIR circuits, but the plugin doesn't use it.

## Scope

Three verification scenarios:

1. **Claims about ZKIR** — opcode semantics, constraint behavior, field arithmetic, transcript protocol
2. **Compiled circuit inspection** — instruction counts, opcode usage, transcript encoding patterns
3. **ZKIR code in DApps** — verifying user-supplied `.zkir` files are well-formed and behave correctly

Plus a **regression sweep** capability for running the full test circuit library against new toolchain versions.

## Available Tooling

| Name | Type | Version | ZKIR Role |
|---|---|---|---|
| `@midnight-ntwrk/zkir-v2` | npm WASM | 2.1.0 | WASM ZKIR v2 checker (browser + Node) |
| `@midnight-ntwrk/compact-runtime` | npm TS | 0.15.0 | Runtime types, ProofData, circuit contexts |
| `@midnight-ntwrk/onchain-runtime-v3` | npm WASM | 3.0.0 | On-chain VM execution |
| `midnightntwrk/midnight-zk` | GitHub | `next` branch | Rust proof system, ZKIR relation builder, circuit gadgets |
| `LFDT-Minokawa/compact` | GitHub | `main` branch | Compiler source: `zkir-passes.ss`, `zkir-v3-passes.ss`, `langs.ss` |

No `@midnight-ntwrk/zkir-v3` npm package exists yet. The custom tools from the ZKIR reference document (`trace-oracle.mjs`, `dump-proof-data.mjs`) are not publicly available — wrapper scripts must be written.

## New Components

### Agent: `zkir-checker`

- **Model:** opus (ZKIR construction is high-complexity)
- **Color:** red
- **Skills:** `verify-by-zkir-checker`, `verify-by-zkir-inspection`
- **Responsibilities:**
  - Compile Compact contracts and extract `.zkir` output
  - Construct proof data (input, output, publicTranscript, privateTranscriptOutputs)
  - Hand-craft `.zkir` JSON directly when needed (IR-level behavior, trivial circuits)
  - Invoke the `@midnight-ntwrk/zkir-v2` WASM checker
  - Inspect compiled `.zkir` structure (instruction counts, opcode usage, transcript encoding)
  - Use fixture templates from the library when applicable
- **Does NOT do:** Domain classification, verdict synthesis, SDK verification

### Skill: `verify-zkir` (domain routing)

Loaded by the verifier orchestrator to classify ZKIR claims and determine dispatch.

**Claim Type → Method Routing:**

| Claim Type | Example | Dispatch |
|---|---|---|
| Opcode semantics | "add wraps modulo r" | **zkir-checker** (checker method) |
| Constraint behavior | "assert requires boolean input" | **zkir-checker** (checker method) |
| Field arithmetic | "-1 is r-1 in ZKIR" | **zkir-checker** (checker method) |
| Transcript protocol | "publicTranscript encodes ledger ops as field elements" | **zkir-checker** (checker method) |
| Cryptographic opcodes | "persistent_hash produces two field elements" | **zkir-checker** (checker method) |
| Compiled circuit structure | "this contract produces N instructions" | **zkir-checker** (inspection method) |
| Circuit opcode usage | "guard counter uses persistent_hash for authority" | **zkir-checker** (inspection method) |
| ZKIR version differences | "v3 uses named variables" | **source-investigator** |
| Compiler internals | "zkir-passes.ss handles v2 serialization" | **source-investigator** |
| Cross-domain | "this disclosure compiles to these ZKIR constraints" | **zkir-checker** (both) + **contract-writer** (concurrent) |

**When in doubt:**
- Observable checker behavior (accept/reject) → zkir-checker (checker method)
- Compiled output properties → zkir-checker (inspection method)
- Compiler/toolchain internals → source-investigator

### Skill: `verify-by-zkir-checker` (method)

Step-by-step instructions for running circuits through the WASM checker.

**Step 1 — Workspace setup:**
Lazy init at `.midnight-expert/verify/zkir-workspace/`:
```bash
mkdir -p .midnight-expert/verify/zkir-workspace
cd .midnight-expert/verify/zkir-workspace
npm init -y
npm install @midnight-ntwrk/zkir-v2 @midnight-ntwrk/compact-runtime
```
Subsequent runs: `npm ls @midnight-ntwrk/zkir-v2` integrity check. Job isolation via `JOB_ID=$(uuidgen)` → `jobs/$JOB_ID/`.

**Step 2 — Determine circuit source (order of preference):**
1. **Fixture match** — check `${CLAUDE_SKILL_DIR}/fixtures/test-cases/` for existing coverage. Copy to job directory, skip to Step 5.
2. **Compile from Compact** — write minimal `.compact`, compile with `compact compile --skip-zk`, extract `.zkir`. Default path for most claims.
3. **Hand-craft `.zkir` JSON** — only for IR-level behavior not reachable from Compact, or trivially small circuits (2-5 instructions). Use templates from `${CLAUDE_SKILL_DIR}/fixtures/templates/`.

**Step 3 — Construct proof data:**
```json
{
  "description": "what this test verifies",
  "circuit": "path/to/circuit.zkir",
  "inputs": {
    "input": { "value": [...], "alignment": [...] },
    "output": { "value": [...], "alignment": [...] },
    "publicTranscript": [...],
    "privateTranscriptOutputs": [...]
  },
  "expect": "accept"
}
```
For compiled circuits, extract proof data via `compact-runtime` types. For hand-crafted circuits, construct manually using fixture patterns.

**Step 4 — Design positive and negative tests:**
- **Positive:** construct valid proof data, expect accept
- **Negative:** tamper with inputs, provide wrong witness, violate constraint, expect reject with specific error

Error message catalog:
- `"Failed direct assertion"` — assert input is boolean 0
- `"Expected boolean, found: XX"` — non-boolean input to assert/cond_select/constrain_to_boolean
- `"Failed equality constraint: XX != YY"` — constrain_eq inputs differ
- `"Bit bound failed: XX is not N-bit"` — constrain_bits value exceeds range
- `"Ran out of private transcript outputs"` — missing witness data
- `"Transcripts not fully consumed"` — extra unused witness data
- `"Public transcript input mismatch for input N"` — tampered public transcript

**Step 5 — Run the checker:**
Write a runner script invoking the WASM checker. The exact API must be discovered from `@midnight-ntwrk/zkir-v2` on first use — inspect the package exports and document the invocation pattern in the workspace.

**Step 6 — Report:**
```markdown
### ZKIR Checker Report

**Claim:** [verbatim]
**Circuit source:** [fixture / compiled from Compact / hand-crafted]
**Circuit:** [.zkir JSON or Compact source if compiled]
**Proof data:** [inputs summary]
**Checker verdict:** ACCEPTED / REJECTED: [error message]
**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

**Step 7 — Clean up:** `rm -rf .midnight-expert/verify/zkir-workspace/jobs/$JOB_ID`

**Critical rules:**
- Checker ACCEPT proves constraints satisfied for those specific inputs, not for all inputs. Note this for universal claims.
- Checker REJECT with a specific error message is strong evidence — the error identifies exactly which constraint failed.
- When compiling from Compact, document where `compact compile` places the `.zkir` output.

### Skill: `verify-by-zkir-inspection` (method)

Step-by-step instructions for analyzing compiled circuit structure without running the checker.

**When used:** Claims about instruction counts, opcode usage, transcript encoding, circuit structure.

Uses the same zkir-workspace as the checker method for job isolation (`jobs/$JOB_ID/`). Does not require the WASM checker — only the Compact CLI and JSON parsing.

**Step 1 — Compile:** Write minimal `.compact`, compile with `compact compile --skip-zk`.

**Step 2 — Locate and parse `.zkir`:** Find `.zkir` JSON in build output. Parse and extract:
- `version` — v2 or v3 format
- `instructions` — full instruction array
- `num_inputs` — input count
- `do_communications_commitment` — transcript presence

**Step 3 — Analyze based on claim:**

| Claim type | Analysis |
|---|---|
| Instruction count | Count `instructions` array length |
| Opcode usage | Filter by `op` field |
| Transcript encoding | Look for `declare_pub_input`/`pi_skip` patterns |
| I/O shape | Count `output`, `public_input`, `private_input` instructions |
| Constraint structure | Trace data flow through `constrain_eq`, `assert`, `constrain_bits` |
| Opcode presence/absence | Check whether specific opcode appears |

**Step 4 — Report:**
```markdown
### ZKIR Inspection Report

**Claim:** [verbatim]
**Compact source:** [source]
**ZKIR version:** v2 / v3
**Analysis:** [relevant metrics]
**Key findings:** [specific instructions/patterns with indices]
**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

**Critical rules:**
- Inspection proves what the compiler emits for specific source. Does not prove circuit correctness — that requires the checker.
- Always note the compiler version in the report.
- When claim spans structure AND behavior, dispatch both methods.

### Skill: `zkir-regression` (sweep)

Runs the full fixture library against the current toolchain. Invocable as `/midnight-verify:zkir-regression` or loadable by agents as a sense-check.

**Two modes:**

**Full sweep** (no arguments):
1. Ensure zkir-workspace initialized
2. Load all test cases from `${CLAUDE_SKILL_DIR}/../verify-by-zkir-checker/fixtures/test-cases/` (resolve path and fail gracefully with a clear error if fixtures directory is not found)
3. Run each through checker, compare to `expect`
4. Re-compile fixture Compact sources to verify compilation still succeeds
5. Produce summary report

**Targeted sweep** (`/midnight-verify:zkir-regression <category>`):
Same but filtered to a single opcode category (arithmetic, constraints, cryptographic, etc.).

**Fixture directory structure:**
```
skills/verify-by-zkir-checker/fixtures/
├── circuits/                    # Pre-crafted .zkir JSON
│   ├── arithmetic/
│   ├── constraints/
│   ├── comparison/
│   ├── control-flow/
│   ├── type-encoding/
│   ├── division/
│   ├── cryptographic/
│   ├── io/
│   └── transcript/
├── templates/                   # Parameterizable patterns
│   ├── pure-circuit.json
│   ├── witness-circuit.json
│   └── transcript-circuit.json
└── test-cases/                  # Test case JSON
    ├── arithmetic/
    │   ├── add-basic.json
    │   ├── add-wrong.json
    │   ├── add-wrap.json
    │   └── ...
    ├── constraints/
    ├── ...
    └── manifest.json
```

**manifest.json:**
```json
{
  "version": "0.1.0",
  "generated_for": "compact-compiler-v0.29.0",
  "checker_package": "@midnight-ntwrk/zkir-v2@2.1.0",
  "test_cases": [
    {
      "id": "add-basic",
      "category": "arithmetic",
      "opcode": "add",
      "file": "arithmetic/add-basic.json",
      "zkir_version": "v2",
      "expect": "accept"
    }
  ]
}
```

**Report format:**
```markdown
## ZKIR Regression Report

**Toolchain:** compact compiler vX.Y.Z, @midnight-ntwrk/zkir-v2@A.B.C
**Fixture version:** 0.1.0
**Ran:** N test cases

### Results

| Category | Passed | Failed | Total |
|---|---|---|---|
| arithmetic | 6 | 0 | 6 |
| constraints | 8 | 0 | 8 |
| ... | | | |
| **Total** | **N** | **0** | **N** |

### Failures (if any)

**add-wrap:** Expected accept, got REJECTED: "Failed equality constraint: 00 != 01"
- Circuit: circuits/arithmetic/add-wrap.zkir
- Interpretation: field wrap behavior may have changed
```

**Building the initial fixture library:**
The ZKIR reference PDF documents 119 oracle traces covering all 26 opcodes. The initial fixture set should mirror the v2 subset (68 traces). The skill includes guidance on adding new fixtures.

## Modified Components

### `verify-correctness` hub skill

**New domain classification row:**

| Domain | Indicators | Route To |
|---|---|---|
| **ZKIR** | ZKIR opcodes, circuit constraints, field elements, proof data, `.zkir` files, transcript protocol, checker behavior, circuit structure | Load `midnight-verify:verify-zkir` |

**New verdict qualifiers:**

| Verdict | Qualifier | When to Use |
|---|---|---|
| Confirmed | (zkir-checked) | WASM checker accepted with expected inputs |
| Confirmed | (zkir-checked + tested) | Both checker and Compact runtime agree |
| Confirmed | (zkir-inspected) | Circuit structure analysis confirms claim |
| Confirmed | (zkir-checked + source-verified) | Checker result + source inspection agree |
| Refuted | (zkir-checked) | Checker produced unexpected accept/reject |
| Refuted | (zkir-inspected) | Circuit structure contradicts claim |
| Inconclusive | (zkir-checker unavailable) | `@midnight-ntwrk/zkir-v2` not installable |

**Conflict resolution addition:** When WASM checker and Compact JS runtime disagree, the checker is more authoritative for constraint behavior (proof system level), the JS runtime is more authoritative for output values (contract logic). Flag disagreement.

### `verify-compact` routing skill

**New rows:**

| Claim Type | Example | Dispatch |
|---|---|---|
| Circuit constraint structure | "this contract produces N constraints" | **zkir-checker** (inspection) |
| Compiled ZKIR properties | "disclosure compiles to declare_pub_input" | **zkir-checker** (inspection) |
| Constraint correctness | "guard circuit correctly constrains authority hash" | **zkir-checker** (checker) + **contract-writer** (concurrent) |

### `verify-by-execution` skill

**New optional Step 4.5 — Extract ZKIR for supplementary evidence:**
After compilation, if the verifier requested ZKIR-level evidence, locate the `.zkir` output and include the path in the report. Do not run the checker — pass the path back so the verifier can dispatch zkir-checker if needed.

### `plugin.json`

Bump version to `0.4.0`. Add keywords: `zkir`, `circuit`, `proof`, `checker`, `wasm`.

## File Layout

```
plugins/midnight-verify/
├── .claude-plugin/plugin.json                   # MODIFIED (v0.4.0)
├── agents/
│   ├── verifier.md
│   ├── contract-writer.md
│   ├── source-investigator.md
│   ├── type-checker.md
│   ├── sdk-tester.md
│   └── zkir-checker.md                          # NEW
├── skills/
│   ├── verify-correctness/SKILL.md              # MODIFIED
│   ├── verify-compact/SKILL.md                  # MODIFIED
│   ├── verify-sdk/SKILL.md
│   ├── verify-by-execution/SKILL.md             # MODIFIED
│   ├── verify-by-source/SKILL.md
│   ├── verify-by-type-check/SKILL.md
│   ├── verify-by-devnet/SKILL.md
│   ├── verify-zkir/SKILL.md                     # NEW
│   ├── verify-by-zkir-checker/
│   │   ├── SKILL.md                             # NEW
│   │   └── fixtures/
│   │       ├── circuits/                        # NEW
│   │       ├── templates/                       # NEW
│   │       └── test-cases/                      # NEW
│   ├── verify-by-zkir-inspection/SKILL.md       # NEW
│   └── zkir-regression/SKILL.md                 # NEW
├── commands/
│   └── verify.md
└── hooks/
    ├── hooks.json
    └── stop-check.sh
```

## End-to-End Flow Examples

### Scenario 1: Opcode semantics claim

```
/verify "constrain_bits enforces that a value fits in N bits"

→ verifier: domain=ZKIR, loads verify-zkir
  routing: constraint behavior → zkir-checker (checker method)
→ zkir-checker: loads verify-by-zkir-checker
  finds fixtures: cb-8bit-zero.json, cb-8bit-255.json, cb-8bit-256.json
  runs all three through checker
  0 fits → ACCEPTED, 255 fits → ACCEPTED, 256 overflows → REJECTED
→ verifier: Confirmed (zkir-checked)
```

### Scenario 2: Compiled circuit inspection

```
/verify "Counter increment compiles to fewer than 20 ZKIR instructions"

→ verifier: domain=ZKIR, loads verify-zkir
  routing: compiled circuit properties → zkir-checker (inspection)
→ zkir-checker: loads verify-by-zkir-inspection
  writes counter contract, compiles, parses .zkir: 14 instructions
→ verifier: Confirmed (zkir-inspected)
```

### Scenario 3: Cross-domain

```
/verify "Guarded counter's persistent_hash correctly constrains authority key"

→ verifier: domain=Compact+ZKIR, loads verify-compact + verify-zkir
→ dispatches concurrently:
  contract-writer: compile + run with valid/invalid keys
  zkir-checker (checker): proof data with valid/wrong key → ACCEPTED/REJECTED
  zkir-checker (inspection): confirms persistent_hash → test_eq → assert chain
→ verifier: Confirmed (zkir-checked + tested)
```

### Scenario 4: Agent-triggered regression

```
(contract-writer encounters unexpected output)
→ loads zkir-regression, runs targeted sweep on constraints
→ detects constrain_bits behavior change
→ reports regression to verifier for inclusion in verdict
```
