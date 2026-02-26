---
title: Pure vs Impure Circuits
type: concept
description: Pure circuits access no ledger state and call no witnesses — impure circuits do one or both, and impurity propagates transitively through the call graph.
links:
  - circuit-declarations
  - witness-functions
  - circuit-witness-boundary
  - bounded-computation
  - ledger-state-design
  - disclosure-model
---

# Pure vs Impure Circuits

Every circuit in Compact is either pure or impure. This distinction determines what the circuit can do and affects ZK key generation.

## Definition

A **pure** circuit:
- Does not read or write any ledger state
- Does not call any witness functions
- Does not call any impure circuits
- Is purely computational — takes inputs, returns outputs

An **impure** circuit does at least one of:
- Reads or writes ledger fields (the state described in [[ledger-state-design]])
- Calls a witness function (the off-chain data providers described in [[witness-functions]])
- Calls another impure circuit

## The `pure` Keyword

Marking a circuit as `pure` causes the compiler to enforce purity:

```compact
pure circuit hashPair(a: Field, b: Field): Bytes<32> {
  return persistentHash<Vector<2, Field>>([a, b]);
}
```

If a `pure` circuit attempts to access a ledger field or call a witness, the compiler emits an error. This is a guarantee to readers and callers that the circuit has no side effects.

## Impurity Propagates

This is the key rule: impurity is **transitive**. If circuit A calls witness W, circuit A is impure. If circuit B calls circuit A, circuit B is also impure — even though B doesn't directly call any witness. The chain continues: any circuit that calls B is also impure.

```compact
witness getSecret(): Bytes<32>;              // witness

circuit helper(): Bytes<32> {                // impure (calls witness)
  return getSecret();
}

circuit wrapper(): Bytes<32> {               // impure (calls impure helper)
  return helper();
}

export circuit doSomething(): [] {           // impure (calls impure wrapper)
  const s = wrapper();
  result = disclose(s);
}
```

You cannot make `wrapper` pure by marking it with the `pure` keyword — the compiler would reject it because it calls the impure `helper`.

## Implications for ZK Key Generation

Every exported circuit generates a ZK prover/verifier key pair during compilation. This is expensive — compilation time scales with the number and complexity of exported circuits. Pure helper circuits that are not exported do not generate their own key pairs; they are inlined into the calling circuit's proof.

The best practice is to keep the number of exported circuits minimal and use unexported helpers (both pure and impure) to organize code. Only the public API surface described in [[export-and-visibility]] needs to be exported.

## When to Use `pure`

Use the `pure` keyword on utility circuits that should never touch state or witnesses:
- Hash computation helpers
- Type conversion utilities
- Arithmetic combinators
- Validation predicates that only check inputs

The keyword serves as both documentation and compiler enforcement. It protects against accidentally introducing a ledger access or witness call during refactoring, which would silently change the circuit's behavior due to the [[disclosure-model]] treating witness-derived values differently.

## Relationship to the Trust Boundary

The [[circuit-witness-boundary]] is closely related: pure circuits operate entirely within the ZK-verified world, while impure circuits bridge into the unverified witness world. This boundary determines what a verifier can trust about the circuit's execution.
