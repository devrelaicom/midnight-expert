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

Run a curated set of verification claims against the current toolchain to detect behavioral changes. Each claim is verified through the full pipeline — claim classification, contract writing, compilation, execution, and PLONK proof verification.

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
