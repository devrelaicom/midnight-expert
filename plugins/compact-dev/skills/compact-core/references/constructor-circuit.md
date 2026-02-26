---
title: Constructor Circuit
type: concept
description: The constructor initializes all ledger state at deployment — it runs exactly once and can call witnesses to receive deployment-time secrets.
links:
  - contract-file-layout
  - ledger-state-design
  - sealed-ledger-fields
  - witness-functions
  - disclosure-model
  - circuit-declarations
  - cell-and-counter
---

# Constructor Circuit

The constructor is a special circuit that runs exactly once when the contract is deployed. Its purpose is to initialize all ledger state. Unlike regular circuits, the constructor is not exported and cannot be called after deployment — it is invoked automatically as part of the deployment transaction.

## Syntax

```compact
constructor(initialOwner: Bytes<32>, maxSupply: Uint<0..1000000>) {
  owner = disclose(initialOwner);
  supply = disclose(maxSupply);
  state = Status.Pending;
}
```

The constructor appears after ledger declarations in the [[contract-file-layout]]. It takes parameters that the deployer provides at deployment time. Like exported circuit arguments, constructor arguments are treated as witness data by the compiler's [[disclosure-model]], so storing them in the ledger requires `disclose()`.

## Initialization Requirements

Every ledger field starts at its type's default value (0 for numbers, false for booleans, first variant for enums). The constructor's job is to set fields to their intended initial values. While not every field must be explicitly assigned in the constructor — unmentioned fields retain their defaults — best practice is to initialize all fields for clarity.

The [[sealed-ledger-fields]] keyword interacts with the constructor: sealed fields can **only** be written inside the constructor body or by circuits called from the constructor. After the constructor completes, sealed fields become immutable.

```compact
sealed ledger admin: Bytes<32>;
export ledger balance: Counter;

constructor(adminKey: Bytes<32>) {
  admin = disclose(adminKey);  // sealed field: writable here
  // balance starts at 0 (Counter default) — no need to set it
}
```

## Calling Witnesses from Constructor

The constructor can call [[witness-functions]] to receive private deployment-time data:

```compact
witness getDeploymentSecret(): Bytes<32>;

constructor() {
  const secret = getDeploymentSecret();
  admin = disclose(persistentHash<Bytes<32>>(secret));
}
```

This pattern stores a hash of the secret rather than the secret itself, combining deployment-time initialization with the privacy model described in [[disclosure-model]].

## Calling Helper Circuits

The constructor can call other circuits for complex initialization logic. This is useful when initialization involves multiple steps or shared validation:

```compact
circuit computeInitialRoot(seed: Bytes<32>): Bytes<32> {
  return persistentHash<Bytes<32>>(seed);
}

constructor(seed: Bytes<32>) {
  merkleRoot = disclose(computeInitialRoot(seed));
}
```

Circuits called from the constructor can write to [[sealed-ledger-fields]] because they execute within the constructor's scope.

## No Constructor is Valid

Contracts without a constructor are valid — all ledger fields simply start at their default values. This is appropriate for contracts whose initial state is the zero state, which can work well with [[cell-and-counter]] where Counter starts at 0 and Cell starts at the type's default.
