# Overflow Error Examples

## When This Error Occurs

The compiler detected an integer value or computation that exceeds the BLS12-381 scalar field modulus (~2^255). These errors involve literal values, compile-time arithmetic, or runtime field mismatches.

## Examples

### Integer literal exceeds field modulus

**Error:**
`integer too large`

**Code that caused it:**
```compact
export circuit setBigValue(): Field {
  const huge = 999999999999999999999999999999999999999999999999999999999999999999999999999999;
  return huge;
}
```

**Diagnosis:** All integer literals in Compact must fit within the BLS12-381 scalar field (~2^255). This value exceeds that limit. The field modulus is a hard constraint of the underlying proof system — no type annotation can change it.

**Fix:**
```compact
export circuit setBigValue(): Field {
  const value = 1000000;
  return value;
}
```

Use values within the field modulus. If you need to represent very large numbers, split them across multiple fields or use `Bytes<N>` for raw byte storage.

### Large constant computation overflow at compile time

**Error:**
`compile-time arithmetic exceeds field modulus`

**Code that caused it:**
```compact
export circuit power(): Field {
  const result = 2 ** 256;
  return result;
}
```

**Diagnosis:** The exponentiation `2 ** 256` is evaluated at compile time and produces a value larger than the field modulus. Even though the individual operands are small, the result overflows.

**Fix:**
```compact
witness computePower(): Field;

export circuit power(): Field {
  const result = disclose(computePower());
  return result;
}
```

Restructure as a runtime computation using a witness if the large value is needed. The witness computes the value off-chain where there are no field modulus constraints, and the circuit verifies the result.

### MAX_FIELD runtime mismatch (post-compilation)

**Error:**
`CompactError: compiler thinks maximum field value is 524358... but runtime says ...`

**Code that caused it:**
```
This is not a Compact code error — it occurs at runtime when the compiled contract
is loaded by @midnight-ntwrk/compact-runtime.
```

**Diagnosis:** The compiler and `@midnight-ntwrk/compact-runtime` are targeting different proof system curves. This happens when the compiler version and runtime package version are out of sync. They must agree on the BLS12-381 parameters.

**Fix:**
```
Align package versions:
  npm install @midnight-ntwrk/compact-runtime@<version-matching-your-compiler>

Check the compiler version in the MCP compile response (compilerVersion field)
and install the matching runtime package.
```

## Anti-Patterns

### Trying to increase the integer type size

**Wrong:** Changing `Uint<128>` to `Uint<256>` to fix an overflow error.
**Problem:** The field modulus is a hard limit of the BLS12-381 proof system (~2^255). It is not related to the `Uint<N>` type width. `Uint<256>` cannot hold values larger than the field modulus either. The constraint comes from the proof system, not the type.
**Instead:** Restructure the computation to stay within the field modulus, or split large values across multiple fields.

### Confusing Uint max values with the field modulus

**Wrong:** Assuming that because `Uint<64>` max is 2^64-1, the field can hold 2^255 in a `Uint<255>`.
**Problem:** `Uint<N>` max values and the field modulus are different constraints applied at different stages. `Uint<64>` enforces a range constraint (0 to 2^64-1) on top of the field. The field modulus constrains what values are representable at all. A `Uint<255>` can exist but its actual max is capped by the field modulus.
**Instead:** Understand that the field modulus (~2^255) is the absolute ceiling. `Uint<N>` for N >= 255 is effectively capped at the field modulus, not at 2^N-1.
