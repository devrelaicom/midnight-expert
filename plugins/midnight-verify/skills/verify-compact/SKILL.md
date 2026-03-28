---
name: midnight-verify:verify-compact
description: >-
  Compact-specific claim classification and method routing. Determines what
  kind of Compact claim is being verified and which verification method applies:
  execution (compile+run), source inspection, or both. Loaded by the verifier
  agent alongside the hub skill. Provides the claim type → method routing table
  and guidance on negative testing.
version: 0.2.0
---

# Compact Claim Classification

This skill classifies Compact-related claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Claim Type → Method Routing

When you receive a Compact-related claim, classify it using this table to determine which sub-agent(s) to dispatch:

| Claim Type | Example | Dispatch |
|---|---|---|
| Syntax validity | "You can cast with `as`" | **contract-writer** |
| Type behavior | "Uint arithmetic widens the result type" | **contract-writer** |
| Stdlib function exists | "persistentHash is in the standard library" | **contract-writer** |
| Stdlib function behavior | "persistentHash returns Bytes<32>" | **contract-writer** |
| Return value semantics | "Tuples are 0-indexed" | **contract-writer** |
| Disclosure rules | "Ledger writes require disclose()" | **contract-writer** |
| Compiler error behavior | "Assigning a Field value to Uint<8> is a type error" | **contract-writer** |
| Language feature count | "Compact exports 57 unique primitives" | **source-investigator** |
| Internal implementation | "The Compact compiler is written in Scheme" | **source-investigator** |
| Architecture/design rationale | "Compact uses Field as the base numeric type because..." | **source-investigator** |
| Cross-component behavior | "Compiled output is compatible with compact-runtime v0.X" | **Both (concurrent)** |
| Performance claims | "MerkleTree operations cost more gates than Map" | **contract-writer** (can measure circuit metrics at compile time) |

**When in doubt:** If the claim involves observable runtime behavior, prefer **contract-writer**. If it's about what exists in the codebase or how something is implemented internally, prefer **source-investigator**. If it could benefit from both, dispatch both concurrently.

## Negative Testing

Some claims are best verified by testing what **should not** work. Guide the contract-writer agent to consider negative tests:

- **"Feature X is not supported"** → write code that uses X, confirm the compiler rejects it
- **"You must use disclose() for Y"** → write code that does Y without disclose(), confirm it fails
- **"Type Z cannot hold values above N"** → assign a value above N, confirm the error
- **"Function F does not exist in stdlib"** → try to call F, confirm it's undefined

A compilation error or runtime error in a negative test is **evidence that confirms the claim**, not a test failure.

## Hints from compact-core Skills

The verifier or sub-agents may consult these compact-core skills to inform what to test or where to look. These are **hints only** — never cite them as evidence in the verdict.

- `compact-core:compact-standard-library` — expected function signatures, what functions exist
- `compact-core:compact-structure` — how to structure a test contract (pragma, imports, exports)
- `compact-core:compact-language-ref` — syntax reference, type system, operators, casting
- `compact-core:compact-privacy-disclosure` — disclosure rules and patterns to test
- `compact-core:compact-compilation` — expected compiler behavior, flags, output structure

Load only what's relevant to the specific claim. Do not load all skills for every verification.
