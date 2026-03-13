---
name: openzeppelin-compact
description: This skill should be used when the user asks about OpenZeppelin Contracts for Compact, OZ modules for Midnight, the Module/Contract pattern, importing or installing OpenZeppelin in a Compact project, access control (Ownable, ZOwnablePK, AccessControl), security modules (Initializable, Pausable), token modules (FungibleToken/ERC-20, NonFungibleToken/ERC-721, MultiToken/ERC-1155), adding role-based permissions or ownership to a Compact contract, creating an ERC-20 or ERC-721 token in Compact, pausing a Compact contract, testing OpenZeppelin Compact contracts with simulators and mocks, or the createSimulator test API.
---

# OpenZeppelin Contracts for Compact

A library for secure smart contract development written in Compact for Midnight. Provides reusable modules for access control, security, tokens, and utilities following the Module/Contract pattern.

> **Warning**: This library contains highly experimental code. Expect rapid iteration.

## Installation

Initialize git and add OpenZeppelin Contracts for Compact as a submodule:

```bash
mkdir my-project && cd my-project
git init && git submodule add https://github.com/OpenZeppelin/compact-contracts.git
cd compact-contracts && nvm install && yarn && SKIP_ZK=true yarn compact
```

Import modules through `node_modules` to avoid state conflicts:

```compact
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable"
  prefix Ownable_;
```

## The Module/Contract Pattern

OpenZeppelin uses **modular composition by delegation** — contracts call into module-defined circuits to implement behavior rather than inheriting.

**Modules** expose three circuit types:
- `internal`: private helpers within the module
- `public` (prefixed with `_`): composable building blocks for contracts (e.g., `_mint`, `_burn`)
- `external`: standalone circuits safe to expose as-is (e.g., `transfer`, `approve`)

**Contracts** compose modules by:
- Importing with a prefix (`import "..." prefix FungibleToken_;`)
- Re-exposing module circuits through wrapper circuits
- Calling `initialize` from imported modules in the constructor

## Module Quick Reference

| Module | Import Path | Purpose | Prefix |
|--------|-------------|---------|--------|
| Ownable | `src/access/Ownable` | Single-owner access control | `Ownable_` |
| ZOwnablePK | `src/access/ZOwnablePK` | Privacy-preserving ownership | `ZOwnablePK_` |
| AccessControl | `src/access/AccessControl` | Role-based access control | `AccessControl_` |
| Initializable | `src/security/Initializable` | One-time initialization guard | `Initializable_` |
| Pausable | `src/security/Pausable` | Emergency stop mechanism | `Pausable_` |
| FungibleToken | `src/token/FungibleToken` | ERC-20 approximation | `FungibleToken_` |
| NonFungibleToken | `src/token/NonFungibleToken` | ERC-721 approximation | `NonFungibleToken_` |
| MultiToken | `src/token/MultiToken` | ERC-1155 approximation | `MultiToken_` |
| Utils | `src/utils/Utils` | Address comparison utilities | `Utils_` |

## Witnesses

Modules in this library are mostly witness-free. The notable exception is `ZOwnablePK`, which defines a `wit_secretNonce(): Bytes<32>` witness for the owner's private nonce used in the shielded ownership commitment scheme. All other modules (Ownable, AccessControl, Initializable, Pausable, FungibleToken, NonFungibleToken, MultiToken, Utils) have no witnesses.

Contracts implementing these modules may define their own witnesses for custom logic. See `compact-structure` skill for witness design patterns. For native shielded/unshielded ledger tokens (not OpenZeppelin contract-state tokens), consult the `compact-tokens` skill.

## Testing

OpenZeppelin Compact contracts use **Vitest** with the `@openzeppelin-compact/contracts-simulator` package (internal to the compact-contracts monorepo; not published to npm) for local testing without blockchain deployment.

### Test Architecture

Each module follows a three-part test pattern:

1. **Mock Contract** (`.compact`): A minimal contract that exposes all module circuits for testing, including an `init` parameter to test uninitialized states.
2. **Simulator** (`.ts`): Extends `createSimulator` to provide a type-safe testing API with methods like `as(caller)` for multi-user testing.
3. **Test File** (`.test.ts`): Vitest tests using the simulator to verify circuit behavior.

### Running Tests

```bash
cd compact-contracts
turbo test
```

### Key Testing Patterns

```typescript
// Create simulator instance
const token = new FungibleTokenSimulator(NAME, SYMBOL, DECIMALS, true);

// Test as different callers
token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT);

// Test error conditions
expect(() => {
  token.as(UNAUTHORIZED).transfer(Z_RECIPIENT, AMOUNT);
}).toThrow('FungibleToken: insufficient balance');
```

### Test Utilities

The `test-utils/address.ts` module provides helpers for generating test keys:
- `generateEitherPubKeyPair(name)`: Creates `[hexPK, Either<ZswapCoinPublicKey, ContractAddress>]` pairs
- `createEitherTestContractAddress(name)`: Creates `Either` wrapped contract addresses
- `ZERO_KEY` / `ZERO_ADDRESS`: Pre-built zero address constants

## Contract-to-Contract Call Limitations

Contract-to-contract calls are **not yet supported** in Compact. This affects all modules:
- Transfers/mints to `ContractAddress` are disallowed in safe circuits
- `_unsafe*` circuit variants exist for experimenting with contract recipients
- Unsafe circuits will be deprecated once contract-to-contract calls are supported
- Ownable cannot transfer ownership to contract addresses through safe circuits

## Common Contract Pattern

```compact
pragma language_version >= 0.21.0;

import CompactStandardLibrary;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/access/Ownable"
  prefix Ownable_;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Pausable"
  prefix Pausable_;
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/token/FungibleToken"
  prefix FungibleToken_;

constructor(
  _name: Opaque<"string">, _symbol: Opaque<"string">, _decimals: Uint<8>,
  _owner: Either<ZswapCoinPublicKey, ContractAddress>
) {
  FungibleToken_initialize(_name, _symbol, _decimals);
  Ownable_initialize(_owner);
}

export circuit transfer(to: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): Boolean {
  Pausable_assertNotPaused();
  return FungibleToken_transfer(to, value);
}

export circuit mint(account: Either<ZswapCoinPublicKey, ContractAddress>, value: Uint<128>): [] {
  Pausable_assertNotPaused();
  Ownable_assertOnlyOwner();
  FungibleToken__mint(account, value);
}

export circuit pause(): [] { Ownable_assertOnlyOwner(); Pausable__pause(); }
export circuit unpause(): [] { Ownable_assertOnlyOwner(); Pausable__unpause(); }
```

## Reference Routing

| Topic | Reference File |
|-------|---------------|
| Installation, importing, project setup, compilation | `references/installation-and-setup.md` |
| Module/Contract pattern, module types, contract rules | `references/module-contract-pattern.md` |
| Testing setup, simulators, mocks, test utilities, writing tests | `references/testing.md` |
| Ownable module: usage, ownership transfers, API reference | `references/ownable.md` |
| AccessControl module: RBAC, roles, granting/revoking, API reference | `references/access-control.md` |
| Initializable and Pausable modules: usage, API reference | `references/initializable-pausable.md` |
| FungibleToken module: ERC-20, transfers, approvals, minting, API reference | `references/fungible-token.md` |
| NonFungibleToken module: ERC-721, ownership, approvals, URI storage, API reference | `references/non-fungible-token.md` |
| MultiToken module: ERC-1155, multi-type tokens, API reference | `references/multi-token.md` |
| Utils module: address comparison, zero checks, API reference | `references/utils.md` |
