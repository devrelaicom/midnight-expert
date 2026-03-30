---
name: midnight-verify:verify-witness
description: >-
  Witness claim classification and method routing. Determines what kind of
  witness claim is being verified and dispatches to the witness-verifier agent.
  Handles claims about witness type correctness, name matching, return tuple
  shape, type mappings, behavioral correctness, private state patterns, and
  two-file verification. Loaded by the verifier agent alongside the hub skill.
version: 0.5.0
---

# Witness Claim Classification

This skill classifies witness-related claims and determines which agent(s) to dispatch. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Claim Type → Method Routing

When you receive a witness-related claim, classify it using this table:

### Claims About the Contract-Witness Interface

| Claim Type | Example | Dispatch |
|---|---|---|
| Witness type correctness | "This witness correctly implements the contract interface" | **witness-verifier** |
| Witness name matching | "The witness names match the contract declarations" | **witness-verifier** |
| Witness return type | "This witness returns the correct [PrivateState, ReturnValue] tuple" | **witness-verifier** |
| Type mapping correctness | "The Field parameters map to bigint in the witness" | **witness-verifier** |
| WitnessContext usage | "This witness correctly uses the ledger from WitnessContext" | **witness-verifier** |
| Private state patterns | "This witness doesn't mutate private state in place" | **witness-verifier** |

### Claims About Witness Behavior

| Claim Type | Example | Dispatch |
|---|---|---|
| Behavioral correctness | "This contract + witness combination produces valid results" | **witness-verifier** |
| Two-file verification | `/verify contracts/counter.compact src/witnesses.ts` | **witness-verifier** (both files) |
| Witness + devnet E2E | "This witness works correctly when deployed" | **witness-verifier** + **sdk-tester** (concurrent) |

### Cross-Domain Claims

| Claim Type | Example | Dispatch |
|---|---|---|
| Witness + ZK proof | "This contract + witness produces a valid ZK proof" | **witness-verifier** first, then **zkir-checker** (sequential — witness-verifier passes build output path) |

### Routing Rules

**When in doubt:**
- Claims about the contract-witness interface → **witness-verifier**
- Claims about just the TypeScript types (no contract involved) → **type-checker** (existing SDK path)
- Claims about just the Compact declarations (no witness implementation) → **contract-writer** (existing Compact path)

**For Witness + ZKIR claims:** dispatch witness-verifier first (it compiles and verifies), then pass the build output path to zkir-checker. These are sequential, not concurrent, because the zkir-checker depends on the compiled artifacts.

## Hints from Existing Skills

The witness-verifier may consult these skills for context. They are **hints only** — never cite them as evidence.

- `compact-core:compact-witness-ts` — witness implementation patterns, WitnessContext API, type mappings
- `compact-core:compact-structure` — witness declarations, disclosure rules
- `compact-core:compact-review` — witness consistency review checklist
