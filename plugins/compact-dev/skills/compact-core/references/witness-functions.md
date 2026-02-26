---
title: Witness Functions
type: concept
description: Off-chain TypeScript functions that feed private data into on-chain circuits — declared in Compact with no body, implemented in TypeScript.
links:
  - circuit-witness-boundary
  - circuit-declarations
  - compact-to-typescript-types
  - disclosure-model
  - witness-value-tracking
  - pure-vs-impure-circuits
  - type-system
  - naming-conventions
  - constructor-circuit
  - witness-context-object
---

# Witness Functions

Witnesses are the bridge between private off-chain data and on-chain ZK proofs. They are declared in Compact as function signatures with no body — the implementation lives in TypeScript on the user's machine. When a circuit calls a witness, the call happens during proof generation: the TypeScript code runs locally, produces a value, and that value is fed into the circuit as a private input.

## Declaration Syntax

```compact
witness getCaller(): Bytes<32>;
witness getBalance(account: Field): Uint<0..1000000>;
witness getUserData(): UserRecord;
```

Witnesses have **no body** in Compact. A witness with a body (e.g., `witness foo(): Field { return 42; }`) is invalid syntax in 0.18.0. By [[naming-conventions]], witness names use camelCase, typically with a `get` or `fetch` prefix.

## TypeScript Implementation

Each declared witness must be implemented in the TypeScript DApp code. The types must match the mapping described in [[compact-to-typescript-types]]:

```typescript
const witnesses = {
  getCaller: async () => {
    // Returns Uint8Array (Bytes<32> → Uint8Array)
    return wallet.getPublicKey();
  },
  getBalance: async (account: bigint) => {
    // Returns bigint (Uint<0..1000000> → bigint)
    return BigInt(await fetchBalance(account));
  },
  getUserData: async () => {
    // Returns { id: bigint, balance: bigint, active: boolean }
    return { id: 1n, balance: 500n, active: true };
  }
};
```

The witness provider object is passed to the contract's transaction builder when submitting a transaction. Missing or incorrectly typed witnesses cause runtime errors during proof generation, not compile-time errors. Each implementation receives a [[witness-context-object]] as its first parameter, providing access to ledger state and contract metadata.

## Trust Model

This is the most critical concept about witnesses: **any DApp can provide any witness implementation**. The Compact compiler does not verify that the TypeScript code is "correct" — it only verifies that the circuit logic is satisfied given whatever values the witness provides. This creates the trust boundary described in [[circuit-witness-boundary]].

The implication is that circuits must **validate** witness outputs using `assert`:

```compact
witness getCaller(): Bytes<32>;

export circuit restrictedAction(): [] {
  const caller = getCaller();
  assert caller == owner "Unauthorized caller";
  // Only reaches here if the witness provided the correct owner key
}
```

Without the `assert`, any DApp could call `restrictedAction()` with any witness value and the proof would still be valid. The ZK proof only proves that the circuit constraints were satisfied — it does not prove the witness was honest.

## Privacy Implications

Witness return values are private by default. The compiler's [[witness-value-tracking]] system tracks every value that originates from a witness call and prevents it from flowing into public state (ledger writes, exported circuit returns, cross-contract calls) without an explicit `disclose()` wrapper. This is the core of the [[disclosure-model]].

A value derived from a witness — through arithmetic, struct construction, type casting, or helper circuit calls — is itself considered witness data. The compiler follows the taint transitively. Only `disclose()` and `transientCommit()` remove the taint.

## Witnesses and Purity

Calling a witness inside a circuit makes that circuit impure, as described in [[pure-vs-impure-circuits]]. Impurity propagates: if circuit A calls witness W, and circuit B calls circuit A, then circuit B is also impure. The `pure` keyword on a circuit causes a compile error if it directly or transitively calls any witness.

## Witnesses in Constructors

The [[constructor-circuit]] can also call witnesses. This is how deployment-time secrets (like admin keys) enter the contract. Constructor arguments are also treated as witness data, so storing them in the ledger requires `disclose()`:

```compact
witness getAdminKey(): Bytes<32>;

constructor() {
  admin = disclose(getAdminKey());
}
```

## Unused Witness Warning

Declaring a witness that no circuit calls generates a compiler warning. Unused witnesses represent dead code and potential security confusion — they suggest a witness provider that will never be invoked.
