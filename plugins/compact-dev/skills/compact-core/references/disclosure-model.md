---
title: Disclosure Model
type: concept
description: Midnight's opt-in privacy model where nothing is public unless explicitly wrapped with disclose() — enforced by the compiler at compile time.
links:
  - witness-value-tracking
  - witness-functions
  - circuit-witness-boundary
  - transient-vs-persistent
  - disclosure-compiler-error
  - commitment-and-nullifier-schemes
  - ledger-state-design
  - constructor-circuit
  - export-and-visibility
---

# Disclosure Model

Midnight's core privacy principle is the inverse of traditional blockchains: **nothing is public unless explicitly declared with `disclose()`**. The default state for all computed values is private. This is enforced by the compiler at compile time — there is no runtime opt-out.

## How disclose() Works

The `disclose()` function is a compile-time marker that tells the compiler "I intend to make this value public." It does not change the value's content or type — it removes the witness taint that the compiler's [[witness-value-tracking]] system tracks.

```compact
witness getBalance(): Uint<0..1000000>;

export circuit updateBalance(): [] {
  const b = getBalance();     // b is witness-tainted
  balance = b;                // COMPILE ERROR: witness data → public ledger
  balance = disclose(b);      // OK: explicitly disclosed
}
```

Without `disclose()`, the compiler prevents any witness-derived value from flowing to:
- Ledger field writes (public state described in [[ledger-state-design]])
- Exported circuit return values (the public API surface from [[export-and-visibility]])
- Cross-contract calls (which would expose the value to another contract)

## Sources of Witness Data

The compiler considers the following as witness data:
- Return values of [[witness-functions]]
- Arguments of exported circuits (because the caller provides them)
- Arguments of the [[constructor-circuit]]

Any value derived from witness data — through arithmetic, struct construction, type casting, function calls — is also witness data. The taint propagates transitively as described in [[witness-value-tracking]].

## Where to Place disclose()

Best practice is to place `disclose()` as close to the disclosure point (ledger write, return statement) as possible:

```compact
// GOOD: disclose at the point of ledger write
owner = disclose(getNewOwner());

// WORKS BUT LESS CLEAR: disclose early
const disclosed = disclose(getNewOwner());
owner = disclosed;
```

Both compile, but the first style makes the disclosure intent obvious at the point where privacy is affected.

## The Disclosure Error

When the compiler detects undisclosed witness data flowing to a public sink, it emits a detailed error message that traces the path from the witness source to the disclosure point. Reading these errors is covered in [[disclosure-compiler-error]].

## disclose() Does Not Protect Privacy

A common misconception: `disclose()` does not add privacy — it **removes** it. Calling `disclose(secret)` makes `secret` public. The function exists to require the developer to consciously acknowledge each disclosure, not to provide any protection.

For actual privacy (storing values on-chain without revealing them), use [[commitment-and-nullifier-schemes]] or the [[transient-vs-persistent]] hash functions. The pattern is: commit to a value using `transientCommit()` (private), then later prove knowledge of the preimage without revealing it.

## Interaction with Opaque Types

Opaque types (`Opaque<'string'>`, `Opaque<'Uint8Array'>`) are not subject to disclosure rules because they cannot be inspected in circuits. They pass through circuits unchanged and are visible on-chain. This is a different mechanism from `disclose()` and provides no privacy — see the Opaque type section in the [[type-system]] for details.
