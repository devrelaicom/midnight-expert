# Fact-Check Findings: zero-knowledge skill

**Date:** 2026-03-10
**Claims verified:** 32
**Valid:** 8 | Ambiguous: 4 | Partially Valid: 4 | Invalid: 12 | Undetermined: 4

## Critical Discovery

**Midnight uses PLONK, not Groth16/R1CS.** The entire skill incorrectly describes R1CS and QAP as the arithmetization — these are Groth16 constructs. PLONK uses gate-based arithmetization with polynomial commitments (KZG10).

## Critical Issues (Invalid)

### 1. Wrong proving system: R1CS/QAP → should be PLONK
- **Claimed:** Compilation pipeline goes through R1CS → QAP
- **Correct:** Compact → Parser → AST → Type Checker → Circuit IR → ZKIR → PLONK keys. PLONK uses gate constraints + copy constraints, not R1CS/QAP.

### 2. Wrong trusted setup model
- **Claimed:** Per-circuit trusted setup required
- **Correct:** PLONK uses a universal SRS (Structured Reference String) — one trusted setup serves all circuits up to max size. Per-circuit keys are derived from the universal SRS, no per-circuit ceremony needed.

### 3. Wrong proof size: "~200-300 bytes"
- **Correct:** Midnight docs say "less than a kilobyte." 200-300 bytes is Groth16/BN254 territory. PLONK proofs are constant-size but larger.

### 4. All `Void` return types
- `Void` doesn't exist in Compact. Use `[]`.

### 5. `export witness` with body is invalid
- Witnesses are declaration-only: `witness name(params): Type;` — no body, no `export`. Implementation goes in TypeScript.

### 6. `ledger { }` block syntax deprecated
- Use individual `export ledger field: Type;`.

### 7. Missing pragma in examples
- All Compact files need `pragma language_version >= 0.16 && <= 0.18;`.

### 8. Wrong Merkle membership check: `ledger.authorized.member(key, path)`
- **Correct:** Use `merkleTreePathRoot()` on the path, then `tree.checkRoot()` on the result.

### 9. Constraint count table is R1CS-specific
- "Addition=0" is an R1CS optimization that doesn't apply to PLONK gate-based systems. All counts should be removed or restated in PLONK terms (rows/gates).

### 10. `persistentHash` uses Poseidon, not Pedersen
- The "Pedersen hash ~1000 constraints" claim conflates hash functions. `persistentHash` is Poseidon-based.

## Partially Valid

### 1. "Midnight uses ZK SNARKs" — correct but should specify PLONK
### 2. Proof generation "seconds to minutes" — "seconds" supported, "minutes" unconfirmed
### 3. `persistentHash` signature — exists, generic `<T>(value: T): Bytes<32>`
### 4. `persistentCommit(value, rand)` — correct two-argument form

## Ambiguous

1. Comparison operators `>=`, `<=` only work on `Uint<N>`, NOT on `Field`
2. `assert` requires parentheses and optional message: `assert(condition, "message")`
3. Proof size "constant" — true for KZG-based PLONK specifically

## Verified Claims

1. Midnight uses ZK SNARKs (specifically PLONK)
2. Proofs are non-interactive
3. Verification is constant-time
4. Per-circuit proving/verification keys derived from universal SRS
5. `persistentHash`, `persistentCommit`, `assert` exist in stdlib
6. `>=`, `<=` exist for Uint types
7. `MerkleTreePath<n, T>` is a real type
8. Witnesses are declaration-only, circuits have bodies
