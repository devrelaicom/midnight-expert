---
title: "Gotcha: Reading the Disclosure Compiler Error"
type: gotcha
description: How to read and fix the "potential witness-value disclosure" compiler error — the most common error in Compact development, with a detailed trace from source to sink.
links:
  - witness-value-tracking
  - disclosure-model
  - transient-vs-persistent
  - witness-functions
  - circuit-declarations
  - persistent-hash-is-not-safe
---

# Gotcha: Reading the Disclosure Compiler Error

The "potential witness-value disclosure" error is the most common compiler error in Compact development. It fires when the [[witness-value-tracking]] system detects a path from a witness source to a public sink without an intervening `disclose()` or `transientCommit()`. Learning to read this error quickly is essential.

## Error Structure

The compiler error includes three parts:

1. **The source**: Which witness function or parameter originated the tainted value
2. **The derivation chain**: Every operation that transformed or propagated the taint
3. **The sink**: Where the tainted value would become public (ledger write, return, cross-contract call)

Example error (paraphrased):

```
Error: potential witness-value disclosure
  Source: witness function 'getBalance()' at line 12
  Via: binding 's' at line 15
  Via: field access 's.x' at line 16
  Via: argument to 'obfuscate' at line 16
  Via: computation in 'obfuscate' at line 8
  Via: binding 'x' at line 16
  Sink: ledger assignment to 'balance' at line 17
```

## How to Fix It

### Option 1: Add disclose()

Insert `disclose()` at the point where the value becomes public:

```compact
// Before (error):
balance = x as Bytes<32>;

// After (fixed):
balance = disclose(x as Bytes<32>);
```

This is the right fix when you **intend** to make the value public. See [[disclosure-model]] for when disclosure is appropriate.

### Option 2: Use transient operations

If the value should remain private, replace persistent operations with transient ones from [[transient-vs-persistent]]:

```compact
// Before (error — persistentHash doesn't remove taint):
const h = persistentHash<Field>(witnessValue);
commitment = disclose(h);  // Works but INSECURE

// After (fixed — transientCommit removes taint):
const c = transientCommit<Field>(witnessValue);
commitment = c;  // No disclose needed — taint removed
```

This is the right fix when privacy must be preserved. The [[persistent-hash-is-not-safe]] gotcha explains why the persistent version is dangerous.

### Option 3: Restructure the circuit

Sometimes the error reveals a design issue. If a value shouldn't be public at all, restructure the circuit to avoid the public sink:

```compact
// Before: storing derived value in ledger (public)
ledger result: Field;
export circuit compute(): [] {
  result = someComputation(getWitnessValue());  // Error
}

// After: store a commitment instead
ledger resultCommitment: Field;
export circuit compute(): [] {
  resultCommitment = transientCommit<Field>(
    someComputation(getWitnessValue()));  // Safe
}
```

## Common Error Patterns

### Exported circuit returning witness data

```compact
export circuit getSecret(): Bytes<32> {
  return getSecretKey();  // ERROR: returning witness data from exported circuit
}
```

Fix: Either don't export the circuit, or return a hash/commitment instead.

### Constructor storing witness arguments

```compact
constructor(adminKey: Bytes<32>) {
  admin = adminKey;  // ERROR: constructor args are witness data
}
```

Fix: `admin = disclose(adminKey);` — constructor arguments always need disclosure for ledger writes.

### Intermediate computation on witness data

```compact
const derived = witnessValue + 73;
const encoded = derived as Bytes<32>;
ledger_field = encoded;  // ERROR: derived from witness
```

Fix: `ledger_field = disclose(encoded);` — arithmetic does not remove taint, as tracked by [[witness-value-tracking]].

## The Error Is Your Friend

The disclosure error is a safety feature, not a nuisance. Every time it fires, it's preventing a potential privacy leak. Read the trace carefully:
- If the path includes `persistentHash` on witness data → use `transientCommit` instead
- If the path ends at a ledger write that should be public → add `disclose()`
- If the path suggests the value shouldn't be public at all → restructure using commitments

The compiler traces every step so you can make an informed decision about each disclosure point.
