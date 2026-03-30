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

The ZKIR reference document (Compact compiler v0.29.0) documents 26 opcodes across 8 categories. When a claim is about a specific opcode, mention the category to help the zkir-checker write an appropriate test contract:

- **Arithmetic:** add, mul, neg
- **Constraints:** assert, constrain_bits, constrain_eq, constrain_to_boolean
- **Control Flow:** cond_select, copy
- **Type Encoding:** decode, encode, reconstitute_field
- **Division:** div_mod_power_of_two
- **Cryptographic:** ec_mul, ec_mul_generator, hash_to_curve, persistent_hash, transient_hash
- **I/O:** impact, output, private_input, public_input
- **Comparison:** less_than, test_eq
