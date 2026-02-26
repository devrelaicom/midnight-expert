---
title: Witness Value Tracking
type: concept
description: The compiler's abstract interpreter that tracks witness-tainted values through the entire program, preventing accidental disclosure.
links:
  - disclosure-model
  - disclosure-compiler-error
  - witness-functions
  - circuit-declarations
  - transient-vs-persistent
  - circuit-witness-boundary
---

# Witness Value Tracking

The Compact compiler includes an abstract interpreter — internally called the "Witness Protection Program" — that tracks how witness-derived values flow through the entire program. This system prevents accidental disclosure of private data by detecting every path from a witness source to a public sink.

## How Tracking Works

The compiler assigns each value an abstract "taint" label: either **witness-tainted** or **untainted**. Starting from witness sources (return values of [[witness-functions]], exported circuit arguments, constructor arguments), it propagates the taint through every operation:

- **Arithmetic**: `witness_value + 73` is tainted
- **Struct construction**: `MyStruct { field: witness_value }` is tainted
- **Type casting**: `witness_value as Bytes<32>` is tainted
- **Function calls**: passing a tainted value through a helper circuit taints the result
- **Tuple/vector construction**: any tainted element taints the container
- **Conditional selection**: if either branch produces a tainted value, the result is tainted

The tracking is conservative: if a value *might* contain witness data on any execution path, it is treated as tainted.

## What Removes Taint

Only two operations remove witness taint:

1. **`disclose()`** — Explicitly acknowledges the value will become public, as described in [[disclosure-model]]
2. **`transientCommit()`** — Cryptographically commits to the value, breaking the link between the commitment and the original value (see [[transient-vs-persistent]])

Notably, `persistentHash()` and `persistentCommit()` do **not** remove taint. These functions produce a deterministic output that allows the original value to be identified if the attacker knows it — they are not safe for privacy. This is the subject of the [[persistent-hash-is-not-safe]] gotcha.

## Error Messages

When the abstract interpreter finds a tainted value reaching a public sink (ledger write, exported return, cross-contract call), it produces a detailed error message. The message includes:

1. The **original witness source** (which witness function or parameter)
2. The **nature of derivation** (arithmetic, comparison, field access, etc.)
3. The **complete path** through the program from source to sink

Reading and fixing these errors is covered in [[disclosure-compiler-error]]. The key insight is that the error traces the exact chain of operations, making it straightforward to find where `disclose()` should be inserted.

## Example: Full Taint Path

```compact
witness getBalance(): Bytes<32>;

struct S { x: Field; }

circuit obfuscate(x: Field): Field {
  return x + 73;
}

export circuit recordBalance(): [] {
  const s = S { x: getBalance() as Field };   // taint: getBalance() → s.x
  const x = obfuscate(s.x);                   // taint: s.x → arg → result
  balance = x as Bytes<32>;                    // ERROR: taint reaches ledger write
}
```

The compiler names every step: `getBalance()` → `s` binding → `obfuscate` argument → computation → `x` binding → ledger assignment. Adding `disclose()` at any point along this chain satisfies the compiler:

```compact
balance = disclose(x as Bytes<32>);  // Fixed: explicit disclosure
```

## Conservative Analysis

The compiler is deliberately conservative. It does not attempt to prove that a particular execution path is unreachable — if the syntax admits a path from witness to public sink, it flags it. This means you may need to add `disclose()` even in branches that "can't happen" at runtime. This is a design choice: false positives (requiring unnecessary `disclose()`) are preferred over false negatives (allowing accidental disclosure).
