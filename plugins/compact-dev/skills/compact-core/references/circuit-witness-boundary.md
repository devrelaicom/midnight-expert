---
title: Circuit-Witness Trust Boundary
type: concept
description: The architectural boundary between on-chain verified circuits and off-chain unverified witnesses — the most important security concept in Compact.
links:
  - circuit-declarations
  - witness-functions
  - pure-vs-impure-circuits
  - disclosure-model
  - witness-value-tracking
  - access-control-pattern
  - commitment-and-nullifier-schemes
---

# Circuit-Witness Trust Boundary

The most important architectural concept in Compact is the boundary between what is verified by the ZK proof (circuits) and what is not (witnesses). Everything inside a circuit body is cryptographically proven correct. Everything a witness provides is an unverified claim that any DApp can fabricate.

## What the Proof Guarantees

When a transaction includes a ZK proof, the verifier (the blockchain) confirms that:
- The circuit logic executed correctly given its inputs
- All `assert` statements passed
- All ledger reads and writes are consistent with the circuit's constraints
- The return value (if any) satisfies the circuit's type

The proof does **not** guarantee that witness values are "correct" in any application-specific sense. A witness claiming `getBalance()` returns 1000000 is accepted by the proof system even if the real balance is 0 — the proof only verifies that the circuit handled the value 1000000 correctly.

## Defense: Assert Everything

The primary defense mechanism is `assert`. Every witness value that affects contract behavior must be validated:

```compact
witness getCaller(): Bytes<32>;

export circuit ownerAction(): [] {
  const caller = getCaller();
  assert caller == owner "Not the owner";
  // Only owner can reach this point — proven by ZK
}
```

Without the `assert`, any DApp could provide any value for `getCaller()` and the proof would succeed. This is why the [[access-control-pattern]] always pairs witness calls with assertions.

## Defense: Commitments

For values that cannot be validated against on-chain state (because the on-chain state is private), use [[commitment-and-nullifier-schemes]]. The pattern is:

1. Store `commit(secret)` on-chain
2. Later, the witness provides `secret`
3. The circuit checks `commit(secret) == stored_commitment`

This proves the witness knows the original secret without revealing it. The commitment bridges the trust boundary by creating a verifiable link between the private witness value and public on-chain state.

## Common Mistakes

**Trusting witness values directly:**
```compact
// DANGEROUS: No validation of witness output
witness getAmount(): Uint<0..1000000>;
export circuit withdraw(): [] {
  const amount = getAmount();
  balance.decrement(amount);  // Any amount can be withdrawn!
}
```

**Fix:** Assert that the amount is within bounds, or use on-chain state to constrain it.

**Assuming witness code matches your implementation:**
The TypeScript witness code in your DApp is not the only code that can generate proofs. Any program that provides valid circuit inputs can create a valid proof. Design circuits defensively, assuming the worst-case witness input.

## The Disclosure Side

The trust boundary also flows the other direction through the [[disclosure-model]]. Witness values are private, and the compiler's [[witness-value-tracking]] prevents them from leaking into public state without explicit `disclose()`. This protects users from accidentally revealing private data, while the `assert` pattern protects the contract from malicious witness values. Together, they define the full security model of the boundary.

## Pure Circuits Have No Boundary

As described in [[pure-vs-impure-circuits]], pure circuits exist entirely within the verified world. They take proven inputs and produce proven outputs. The trust boundary only exists at the point where witness data enters through [[witness-functions]].
