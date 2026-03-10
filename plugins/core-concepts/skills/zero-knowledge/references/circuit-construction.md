# Circuit Construction

## From Compact to Circuit

### Compilation Pipeline

```
Compact Source
     ↓
   Parser
     ↓
Abstract Syntax Tree
     ↓
Type Checker
     ↓
Circuit IR
     ↓
   ZKIR
     ↓
PLONK Proving/Verification Keys
(derived from universal SRS)
```

### What Becomes Constraints

| Compact Construct | Circuit Representation |
|-------------------|----------------------|
| `assert(x == y, "msg")` | Equality constraint |
| `assert(x != 0, "msg")` | Inverse exists constraint |
| `x + y` | Addition gate |
| `x * y` | Multiplication gate |
| `if c then a else b` | Selection constraint |
| `persistentHash(x)` | Hash circuit (many gates) |

## Witness vs Public Input

### Public Inputs

- Known to verifier
- Part of verified statement
- In Compact: ledger reads, explicit public values

### Witness (Private Inputs)

- Known only to prover
- Never revealed
- In Compact: values returned by witness functions

### Example

```compact
pragma language_version >= 0.16 && <= 0.18;
import CompactStandardLibrary;

export ledger hash: Bytes<32>;

// Witness declaration (implementation in TypeScript)
witness get_secret(): Bytes<32>;

// Circuit that uses the witness
export circuit checkSecret(): [] {
  const secret = get_secret();
  // ledger.hash is public input
  assert(persistentHash<Bytes<32>>(secret) == hash, "Hash does not match");
}
```

Circuit has:
- Public input: `hash` ledger value
- Witness: `secret` (returned by witness function)
- Constraint: `Hash(secret) = public_hash`

## Circuit Optimization

### Minimize Gates

```compact
// More gates (comparison requires bit decomposition, only works on Uint<N>)
if amount > 100 { ... }

// Fewer gates (equality is cheaper)
if amount == 100 { ... }
```

### Batch Operations

```compact
// Expensive: Multiple hash calls
hash1 = persistentHash<Bytes<32>>(a);
hash2 = persistentHash<Bytes<32>>(b);

// Consider: Single hash of combined data where possible
```

### Reuse Intermediate Values

```compact
// Computed twice (wasteful)
assert(persistentHash<Bytes<32>>(x) == target1, "Mismatch 1");
assert(persistentHash<Bytes<32>>(x) == target2, "Mismatch 2");

// Computed once
const h = persistentHash<Bytes<32>>(x);
assert(h == target1, "Mismatch 1");
assert(h == target2, "Mismatch 2");
```

## Circuit Size Impact

### On Proof Generation

Larger circuits mean:
- More memory during proving
- Longer proof generation time
- Larger proving key files

### On Verification

Verification is constant time regardless of circuit size. This is the "succinct" property.

## Debugging Circuits

### Unsatisfied Constraints

When a proof fails:
1. Witness doesn't satisfy some constraint
2. Check assert conditions
3. Verify input values

### Circuit Too Large

If circuit exceeds limits:
1. Reduce hash operations
2. Simplify comparisons
3. Split into multiple circuits
