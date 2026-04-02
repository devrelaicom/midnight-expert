---
name: midnight-verify:verify-compact
description: >-
  Compact-specific claim classification and method routing. Determines what
  kind of Compact claim is being verified and which verification method applies:
  execution (compile+run), source inspection, or both. Loaded by the /midnight-verify:verify
  command alongside the hub skill. Provides the claim type → method routing
  table and guidance on negative testing.
version: 0.3.0
---

# Compact Claim Classification

This skill classifies Compact-related claims and determines which verification method to use. The /midnight-verify:verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.

## Claim Type → Method Routing

When you receive a Compact-related claim, classify it using this table to determine which sub-agent(s) to dispatch:

| Claim Type | Example | Dispatch |
|---|---|---|
| Syntax validity | "You can cast with `as`" | @"midnight-verify:contract-writer (agent)" |
| Type behavior | "Uint arithmetic widens the result type" | @"midnight-verify:contract-writer (agent)" |
| Stdlib function exists | "persistentHash is in the standard library" | @"midnight-verify:contract-writer (agent)" |
| Stdlib function behavior | "persistentHash returns Bytes<32>" | @"midnight-verify:contract-writer (agent)" |
| Return value semantics | "Tuples are 0-indexed" | @"midnight-verify:contract-writer (agent)" |
| Disclosure rules | "Ledger writes require disclose()" | @"midnight-verify:contract-writer (agent)" |
| Compiler error behavior | "Assigning a Field value to Uint<8> is a type error" | @"midnight-verify:contract-writer (agent)" |
| Language feature count | "Compact exports 57 unique primitives" | @"midnight-verify:source-investigator (agent)" |
| Internal implementation | "The Compact compiler is written in Scheme" | @"midnight-verify:source-investigator (agent)" |
| Architecture/design rationale | "Compact uses Field as the base numeric type because..." | @"midnight-verify:source-investigator (agent)" |
| Cross-component behavior | "Compiled output is compatible with compact-runtime v0.X" | both @"midnight-verify:contract-writer (agent)" and @"midnight-verify:source-investigator (agent)" concurrently |
| Performance claims | "MerkleTree operations cost more gates than Map" | @"midnight-verify:contract-writer (agent)" (can measure circuit metrics at compile time) |
| Circuit constraint structure | "this contract produces N constraints" | @"midnight-verify:zkir-checker (agent)" (inspection) |
| Compiled ZKIR properties | "disclosure compiles to declare_pub_input" | @"midnight-verify:zkir-checker (agent)" (inspection) |
| Constraint correctness | "guard circuit correctly constrains authority hash" | @"midnight-verify:zkir-checker (agent)" (checker) + @"midnight-verify:contract-writer (agent)" (concurrent) |

**When in doubt:** If the claim involves observable runtime behavior, prefer @"midnight-verify:contract-writer (agent)". If it's about what exists in the codebase or how something is implemented internally, prefer @"midnight-verify:source-investigator (agent)". If it could benefit from both, dispatch both concurrently.

## Negative Testing

Some claims are best verified by testing what **should not** work. Guide @"midnight-verify:contract-writer (agent)" to consider negative tests:

- **"Feature X is not supported"** → write code that uses X, confirm the compiler rejects it
- **"You must use disclose() for Y"** → write code that does Y without disclose(), confirm it fails
- **"Type Z cannot hold values above N"** → assign a value above N, confirm the error
- **"Function F does not exist in stdlib"** → try to call F, confirm it's undefined

A compilation error or runtime error in a negative test is **evidence that confirms the claim**, not a test failure.

## Hints from compact-core Skills

Sub-agents may load these compact-core skills to inform what to test or where to look. These are **hints only** — never cite skill content as evidence in the verdict.

- `compact-core:compact-standard-library` skill — expected function signatures, what functions exist
- `compact-core:compact-structure` skill — how to structure a test contract (pragma, imports, exports)
- `compact-core:compact-language-ref` skill — syntax reference, type system, operators, casting
- `compact-core:compact-privacy-disclosure` skill — disclosure rules and patterns to test
- `midnight-tooling:compact-cli` skill — expected compiler behavior, flags, output structure

Load only what's relevant to the specific claim. Do not load all skills for every verification.
