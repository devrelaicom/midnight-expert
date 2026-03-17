---
version: 0.1.0
name: openzeppelin-compact
description: This skill should be used when the user asks about OpenZeppelin Contracts for Compact, OZ modules for Midnight, the Module/Contract pattern, importing OpenZeppelin into a Compact project, access control (Ownable, ZOwnablePK, AccessControl), security modules (Initializable, Pausable), token modules (FungibleToken/ERC-20, NonFungibleToken/ERC-721, MultiToken/ERC-1155), role-based permissions, creating tokens in Compact, pausing contracts, or testing with createSimulator and mocks.
---

# OpenZeppelin Contracts for Compact

A library for secure smart contract development written in Compact for Midnight. Provides reusable modules for access control, security, tokens, and utilities following the Module/Contract pattern.

> **Warning**: This library contains highly experimental code. Expect rapid iteration.
>
> **Compatibility**: Library v0.0.1-alpha.1 | Compiler: compactc 0.26.0–0.29.0 | Language: `pragma language_version >= 0.21.0`

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

| Module | Import Path | Purpose | Dependencies | Prefix |
|--------|-------------|---------|--------------|--------|
| Ownable | `src/access/Ownable` | Single-owner access control | Initializable, Utils | `Ownable_` |
| ZOwnablePK | `src/access/ZOwnablePK` | Privacy-preserving ownership | Initializable | `ZOwnablePK_` |
| AccessControl | `src/access/AccessControl` | Role-based access control | Utils | `AccessControl_` |
| Initializable | `src/security/Initializable` | One-time initialization guard | — | `Initializable_` |
| Pausable | `src/security/Pausable` | Emergency stop mechanism | — | `Pausable_` |
| FungibleToken | `src/token/FungibleToken` | ERC-20 approximation | Initializable, Utils | `FungibleToken_` |
| NonFungibleToken | `src/token/NonFungibleToken` | ERC-721 approximation | Initializable, Utils | `NonFungibleToken_` |
| MultiToken | `src/token/MultiToken` | ERC-1155 approximation | Initializable, Utils | `MultiToken_` |
| Utils | `src/utils/Utils` | Address comparison utilities | — | `Utils_` |

## Witnesses

Modules in this library are mostly witness-free. The notable exception is `ZOwnablePK`, which defines a `wit_secretNonce(): Bytes<32>` witness for the owner's private nonce used in the shielded ownership commitment scheme. All other modules (Ownable, AccessControl, Initializable, Pausable, FungibleToken, NonFungibleToken, MultiToken, Utils) have no witnesses.

### ZOwnablePK Witness Example

The `ZOwnablePKWitnesses` factory provides the secret nonce witness required for shielded ownership verification:

```typescript
import { WitnessContext } from '@midnight-ntwrk/compact-runtime';

export type ZOwnablePKPrivateState = {
  readonly secretNonce: Uint8Array;
};

export const ZOwnablePKWitnesses = (nonce: Uint8Array) => ({
  secretNonce: (context: WitnessContext<ZOwnablePKPrivateState>): [ZOwnablePKPrivateState, Uint8Array] => {
    return [context.privateState, nonce];
  },
});
```

When creating a simulator or provider for a contract using ZOwnablePK, pass the nonce through the witnesses factory. See the `references/ownable.md` reference for the full commitment scheme and nonce generation strategies.

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

## Known Pitfalls

- **`from` is a reserved keyword** in compactc 0.28.0+ (language version 0.20.0+). Use `fromAddress` as the parameter name in `transferFrom` circuits. Code using `from` as an identifier will fail to parse.

## Troubleshooting

### `failed to locate file "./path/to/Module.compact"`

The import path is wrong or the file doesn't exist. Check that:
- The path is relative to the importing file
- The file exists at the expected location
- You ran `git submodule add` and `yarn` inside `compact-contracts/`

### `X.compact does not contain a (single) module defintion`

You are trying to import a **contract** file rather than a **module** file. Only files containing a `module ModuleName { ... }` block can be imported. Contracts (files with `constructor`, `export circuit`, etc. at the top level) cannot be imported as modules.

### `unbound identifier Prefix_circuitName`

The most common import/call error. Possible causes:

| Cause | Example | Fix |
|-------|---------|-----|
| Missing prefix on import | `import "./Module";` then calling `Module_foo()` | Add `prefix Module_;` to the import |
| Wrong prefix used | Imported with `prefix A_;` but calling `B_foo()` | Use the exact prefix from the import statement |
| Circuit doesn't exist | `TM_doesNotExist()` | Check the module's API — the circuit may be named differently |
| Circuit is not exported | `TM__internalHelper()` | Only `export circuit` declarations are accessible from outside the module. Internal circuits (without `export`) cannot be called. The error is identical to a nonexistent circuit. |
| Calling bare name with prefix set | `import "./Module" prefix M_;` then calling `foo()` | Use `M_foo()` — the prefix is mandatory once set |

### `parse error: found keyword "from"`

`from` became a reserved keyword in compactc 0.28.0+. Use `fromAddress` (or any other non-reserved name) as the parameter name:

```compact
// Wrong — compile error on 0.28.0+
export circuit transferFrom(from: Either<...>, to: Either<...>, value: Uint<128>): Boolean { ... }

// Correct
export circuit transferFrom(fromAddress: Either<...>, to: Either<...>, value: Uint<128>): Boolean { ... }
```

### `no compatible function named Prefix_circuit is in scope at this call`

Type mismatch or wrong number of arguments. The compiler shows both what you supplied and what the circuit expects:

```
supplied argument types: (Bytes<10>)
declared argument types:  (Uint<64>)
```

Check the module's API reference for the correct signature. Common mistakes:
- Passing `Opaque<"string">` where `Bytes<32>` is expected (or vice versa)
- Passing `ZswapCoinPublicKey` instead of `Either<ZswapCoinPublicKey, ContractAddress>`
- Wrong number of arguments to `initialize` (each module's initializer has different parameters)

### Runtime: `Initializable: contract not initialized`

The contract compiles but fails at execution time. This means `initialize()` was not called for one or more modules in the constructor. Every module that depends on Initializable (Ownable, FungibleToken, NonFungibleToken, MultiToken) **must** have its `initialize` circuit called in the constructor. This is not caught at compile time.

### Ledger state conflicts from duplicate imports

If the same module file is imported through different paths, Compact creates **separate ledger state** for each import. This means one import's `_balances` map is independent of the other's — leading to silent data inconsistency. Always import through `node_modules`:

```compact
// Wrong — may create duplicate state if another module also imports Initializable directly
import "../../security/Initializable" prefix Initializable_;

// Correct — all modules resolve to the same file through node_modules
import "./compact-contracts/node_modules/@openzeppelin-compact/contracts/src/security/Initializable"
  prefix Initializable_;
```

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
| Library overview, all modules, file index, version info, limitations | `references/contract-library.md` |
