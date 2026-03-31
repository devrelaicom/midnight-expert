# The Module/Contract Pattern

## Overview

OpenZeppelin uses the term "modular composition by delegation" to describe the practice of having contracts call into module-defined circuits to implement behavior. Rather than inheriting or overriding functionality, a contract delegates responsibility to the module by explicitly invoking its exported circuits.

There are two types of compact files: modules and contracts.

## Module Rules

Modules expose functionality through three circuit types:

1. **internal**: private helpers used to break up logic within the module
2. **public**: composable building blocks intended for contracts to use in complex flows (e.g., `_mint`, `_burn`). Prefixed with `_`.
3. **external**: standalone circuits safe to expose as-is (e.g., `transfer`, `approve`). No `_` prefix.

Modules must:
- Export only `public` and `external` circuits
- Prefix `public` circuits with `_` (e.g., `FungibleToken._mint`)
- Avoid `_` prefix for `external` circuits (e.g., `FungibleToken.transfer`)
- Avoid defining or calling constructors or `initialize()` directly
- Optionally define an `initialize()` circuit for internal setup—but execution must be delegated to the contract

> Compact files must contain only one top-level module and all logic must be defined inside the module declaration.

## Contract Rules

Contracts compose behavior by explicitly invoking the relevant circuits from imported modules. Contracts:
- Can import from modules
- Should add prefix to imports (`import "FungibleToken" prefix FungibleToken_;`)
- Should re-expose external module circuits through wrapper circuits to control naming and layering. Avoid raw re-exports to prevent name clashes.
- Should implement constructor that calls `initialize` from imported modules
- Must not call initializers outside of the constructor

## Full Example: Mintable Pausable Ownable Token

```compact
// FungibleTokenMintablePausableOwnableContract.compact

pragma language_version >= 0.22.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable"
  prefix Ownable_;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Pausable"
  prefix Pausable_;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/FungibleToken"
  prefix FungibleToken_;

constructor(
  _name: Opaque<"string">,
  _symbol: Opaque<"string">,
  _decimals: Uint<8>,
  _owner: Either<ZswapCoinPublicKey, ContractAddress>
) {
  FungibleToken_initialize(_name, _symbol, _decimals);
  Ownable_initialize(_owner);
}

/** IFungibleTokenMetadata */
export circuit name(): Opaque<"string"> { return FungibleToken_name(); }
export circuit symbol(): Opaque<"string"> { return FungibleToken_symbol(); }
export circuit decimals(): Uint<8> { return FungibleToken_decimals(); }

/** IFungibleToken */
export circuit totalSupply(): Uint<128> { return FungibleToken_totalSupply(); }
export circuit balanceOf(account: Either<ZswapCoinPublicKey, ContractAddress>): Uint<128> {
  return FungibleToken_balanceOf(account);
}
export circuit allowance(
  owner: Either<ZswapCoinPublicKey, ContractAddress>,
  spender: Either<ZswapCoinPublicKey, ContractAddress>
): Uint<128> {
  return FungibleToken_allowance(owner, spender);
}

export circuit transfer(to: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): Boolean {
  Pausable_assertNotPaused();
  return FungibleToken_transfer(to, value);
}
export circuit transferFrom(
  fromAddress: Either<ZswapCoinPublicKey, ContractAddress>,
  to: Either<ZswapCoinPublicKey, ContractAddress>,
  value: Uint<128>
): Boolean {
  Pausable_assertNotPaused();
  return FungibleToken_transferFrom(fromAddress, to, value);
}
export circuit approve(spender: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): Boolean {
  Pausable_assertNotPaused();
  return FungibleToken_approve(spender, value);
}

/** IMintable */
export circuit mint(account: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): [] {
  Pausable_assertNotPaused();
  Ownable_assertOnlyOwner();
  FungibleToken__mint(account, value);
}

/** IPausable */
export circuit isPaused(): Boolean { return Pausable_isPaused(); }
export circuit pause(): [] { Ownable_assertOnlyOwner(); Pausable__pause(); }
export circuit unpause(): [] { Ownable_assertOnlyOwner(); Pausable__unpause(); }

/** IOwnable */
export circuit owner(): Either<ZswapCoinPublicKey, ContractAddress> { return Ownable_owner(); }
export circuit transferOwnership(newOwner: Either<ZswapCoinPublicKey, ContractAddress>): [] {
  Ownable_transferOwnership(newOwner);
}
export circuit renounceOwnership(): [] { Ownable_renounceOwnership(); }
```

## ZK Circuits 101

Compact code compiles into arithmetic circuits — mathematical representations of the contract's logic made up of arithmetic gates.

### Circuit Size and Domain

- The **domain size** (`k`) is always a power of 2 (e.g., 2^10 = 1024 rows)
- **Used rows** are the actually filled rows in the circuit
- Example: "k=10, rows=563" means domain of 1024 rows, only 563 used

### Why Circuit Size Matters

The number of rules in a zero-knowledge circuit directly impacts:
- **Prover time**: larger circuits = slower proof generation
- **Proof size**: to a lesser extent
- **Verifier time**: to a lesser extent

Keep circuits as small as possible for better performance on Midnight, where proof generation is often the most computationally expensive part of a transaction.

## Design Patterns

### Combining Access Control with Token Operations
Use `assertOnlyOwner()` or `assertOnlyRole()` before `_mint`, `_burn`, or other privileged operations.

### Pausing Token Operations
Insert `Pausable_assertNotPaused()` at the start of circuits that should be pausable (transfers, approvals, minting).

### Layered Security
Combine multiple modules: Ownable for admin control, Pausable for emergency stops, AccessControl for granular roles.
