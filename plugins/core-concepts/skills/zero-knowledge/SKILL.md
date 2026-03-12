---
name: core-concepts:zero-knowledge
description: Use when asking about zero-knowledge proofs, ZK SNARKs, circuit compilation, witness data, prover/verifier roles, constraints, or how Midnight uses ZK for privacy.
---

# Zero-Knowledge Proofs in Midnight

Zero-knowledge proofs let you prove knowledge of a secret without revealing it. In Midnight, ZK proofs validate that transactions follow contract rules without exposing private data.

## Core Concept

A ZK proof proves: "I know values that satisfy these constraints" without revealing the values.

**Midnight application**: Prove a transaction is valid (correct inputs, authorized user, rules followed) without exposing private state or user secrets.

## ZK SNARKs

Midnight uses **ZK SNARKs** (Zero-Knowledge Succinct Non-interactive Arguments of Knowledge):

| Property | Meaning |
|----------|---------|
| **Zero-Knowledge** | Verifier learns nothing beyond validity |
| **Succinct** | Proof small and fast to verify, regardless of computation size |
| **Non-interactive** | No back-and-forth between prover and verifier |
| **Argument of Knowledge** | Prover must actually know the secret |

## How Proofs Work in Midnight

### Transaction Structure

Every Midnight transaction contains:
1. **Public transcript** - Visible state changes
2. **Zero-knowledge proof** - Cryptographic validation

The proof demonstrates: "I know private inputs that, when combined with public data, satisfy the contract's constraints."

### Circuit Mental Model

Contract logic compiles to **circuits** - mathematical constraint systems.

```
Compact Code → Circuit Constraints → ZK Proof
```

A circuit defines relationships between variables. The proof shows you know variable assignments satisfying all constraints without revealing the assignments.

### Proof Lifecycle

```
1. Setup      → Universal SRS generated once; per-circuit keys derived from it
2. Witness    → Prover assembles private inputs
3. Prove      → Generate proof from witness + circuit
4. Verify     → Check proof against public inputs (fast)
```

## Circuits in Practice

### What Gets Proven

When a Compact contract executes:
1. Contract logic compiles to arithmetic circuit
2. Private values become witness inputs
3. Public values become public inputs
4. Proof demonstrates correct execution

### Circuit Constraints

Circuits express computations as gate constraints:

```
// Conceptual: proving x * y = z without revealing x, y
gate constraint: a * b = c
public input: c = 42
witness (private): a = 6, b = 7
```

### Compact to Circuit

```compact
pragma language_version 0.20;
import CompactStandardLibrary;

export ledger target: Field;

// Witness declaration (implementation provided in TypeScript)
witness get_guess(): Field;
witness get_other_factor(): Field;

// This Compact circuit...
export circuit guess(): [] {
  const g = get_guess();
  const other_factor = get_other_factor();
  const product = g * other_factor;
  assert(product == target, "Product does not match target");
}

// ...compiles to constraints that prove:
// 1. guess * other_factor equals target
// 2. Without revealing guess or other_factor values
```

## Practical Applications

### Proving Without Revealing

| Scenario | What's Proven | What's Hidden |
|----------|---------------|---------------|
| Age verification | Age >= 18 | Exact birthdate |
| Balance check | Balance >= amount | Actual balance |
| Membership | In authorized set | Which member |
| Vote validity | Eligible voter, hasn't voted | Voter identity |

### In Contracts

```compact
pragma language_version 0.20;
import CompactStandardLibrary;

export ledger public_target: Field;

// Witnesses - private inputs provided by TypeScript
witness get_secret_a(): Field;
witness get_secret_b(): Field;

// Prove knowledge of factors without revealing them
export circuit proveFactors(): [] {
  const secret_a = get_secret_a();
  const secret_b = get_secret_b();
  // Constraint: factors multiply to public target
  assert(secret_a * secret_b == public_target, "Factors do not match target");
}
```

## Key Concepts

### Witness
Private inputs the prover knows. Never revealed, used only to generate proof. In Compact, witnesses are declared with `witness name(): Type;` and implemented in TypeScript.

### Public Inputs
Values visible to everyone. Proof verified against these.

### Verification
Checking a proof is fast (milliseconds) regardless of original computation complexity.

### Soundness
Computationally infeasible to create valid proof without knowing witness.

## Performance Characteristics

| Operation | Cost |
|-----------|------|
| Circuit compilation | One-time, expensive |
| Proof generation | Seconds for typical contracts, depending on circuit complexity |
| Proof verification | Milliseconds |
| Proof size | Small (less than a kilobyte) |

## References

For detailed technical information:
- **`references/snark-internals.md`** - PLONK proving system, polynomial commitments, universal setup
- **`references/circuit-construction.md`** - How Compact compiles to circuits

## Examples

Working patterns:
- **`examples/circuit-patterns.compact`** - Common proof patterns
