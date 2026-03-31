# Testing OpenZeppelin Contracts for Compact

## Overview

OpenZeppelin Compact contracts use **Vitest** as the test runner and the `@openzeppelin-compact/contracts-simulator` package for local testing without blockchain deployment. Each module follows a three-part test pattern: Mock Contract, Simulator, and Test File.

> **Important:** `@openzeppelin-compact/contracts-simulator` is an **internal package** within the [OpenZeppelin compact-contracts monorepo](https://github.com/OpenZeppelin/compact-contracts) — it is marked `"private": true` and is **not published to the public npm registry**. To use it, you must clone the compact-contracts monorepo and work within its workspace structure (the package is resolved via workspace references). It is not installable via `npm install` in standalone projects.

## Setting Up Tests

### Project Structure

```
contracts/
├── src/
│   └── token/
│       ├── FungibleToken.compact          # Module source
│       ├── witnesses/
│       │   └── FungibleTokenWitnesses.ts  # Witness implementations
│       └── test/
│           ├── mocks/
│           │   └── MockFungibleToken.compact  # Test mock contract
│           ├── simulators/
│           │   └── FungibleTokenSimulator.ts  # Test simulator
│           └── FungibleToken.test.ts          # Test file
├── test-utils/
│   └── address.ts                         # Shared test utilities
└── vitest.config.ts                       # Vitest configuration
```

### Vitest Configuration

```typescript
// vitest.config.ts
import { configDefaults, defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.test.ts'],
    reporters: 'verbose',
  },
});
```

### Running Tests

```bash
# Run all tests
turbo test

# Or directly with vitest
npx vitest
```

## Test Mocks

Mock contracts are minimal Compact contracts that expose all module circuits for testing. They wrap every module circuit so it can be called through the simulator.

### Example: MockFungibleToken.compact

```compact
pragma language_version >= 0.22.0;

import CompactStandardLibrary;
import "../../FungibleToken" prefix FungibleToken_;

export { ZswapCoinPublicKey, ContractAddress, Either, Maybe };

// `init` param allows testing uninitialized contract states
constructor(
  _name: Opaque<"string">,
  _symbol: Opaque<"string">,
  _decimals: Uint<8>,
  init: Boolean
) {
  if (disclose(init)) {
    FungibleToken_initialize(_name, _symbol, _decimals);
  }
}

// Expose all module circuits
export circuit name(): Opaque<"string"> { return FungibleToken_name(); }
export circuit symbol(): Opaque<"string"> { return FungibleToken_symbol(); }
export circuit decimals(): Uint<8> { return FungibleToken_decimals(); }
export circuit totalSupply(): Uint<128> { return FungibleToken_totalSupply(); }
export circuit balanceOf(account: Either<ZswapCoinPublicKey, ContractAddress>): Uint<128> {
  return FungibleToken_balanceOf(account);
}
// ... expose all remaining circuits including _mint, _burn, _approve, etc.
```

Key pattern: Include a boolean `init` parameter in the constructor to test both initialized and uninitialized states.

## Test Simulators

Simulators provide a type-safe TypeScript API for interacting with mock contracts locally.

### Creating a Simulator with `createSimulator`

```typescript
// This package is internal to the compact-contracts monorepo and is not on npm.
// You must work within the monorepo workspace for this import to resolve.
import { createSimulator, type BaseSimulatorOptions } from '@openzeppelin-compact/contracts-simulator';
import { Contract as MockFungibleToken, ledger } from '../../../../artifacts/MockFungibleToken/contract/index.js';
import { FungibleTokenPrivateState, FungibleTokenWitnesses } from '../../witnesses/FungibleTokenWitnesses.js';

type FungibleTokenArgs = readonly [
  name: string, symbol: string, decimals: bigint, init: boolean,
];

const FungibleTokenSimulatorBase = createSimulator<
  FungibleTokenPrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof FungibleTokenWitnesses>,
  MockFungibleToken<FungibleTokenPrivateState>,
  FungibleTokenArgs
>({
  contractFactory: (witnesses) => new MockFungibleToken<FungibleTokenPrivateState>(witnesses),
  defaultPrivateState: () => FungibleTokenPrivateState,
  contractArgs: (name, symbol, decimals, init) => [name, symbol, decimals, init],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => FungibleTokenWitnesses(),
});
```

### Extending the Base Simulator

```typescript
export class FungibleTokenSimulator extends FungibleTokenSimulatorBase {
  constructor(
    name: string, symbol: string, decimals: bigint, init: boolean,
    options: BaseSimulatorOptions<FungibleTokenPrivateState, ReturnType<typeof FungibleTokenWitnesses>> = {},
  ) {
    super([name, symbol, decimals, init], options);
  }

  public name(): string { return this.circuits.impure.name(); }
  public symbol(): string { return this.circuits.impure.symbol(); }
  public decimals(): bigint { return this.circuits.impure.decimals(); }
  public totalSupply(): bigint { return this.circuits.impure.totalSupply(); }

  public balanceOf(account: Either<ZswapCoinPublicKey, ContractAddress>): bigint {
    return this.circuits.impure.balanceOf(account);
  }

  public transfer(to: Either<ZswapCoinPublicKey, ContractAddress>, value: bigint): boolean {
    return this.circuits.impure.transfer(to, value);
  }

  public _mint(account: Either<ZswapCoinPublicKey, ContractAddress>, value: bigint) {
    this.circuits.impure._mint(account, value);
  }

  public _burn(account: Either<ZswapCoinPublicKey, ContractAddress>, value: bigint) {
    this.circuits.impure._burn(account, value);
  }
  // ... additional circuit wrappers
}
```

### Simulator Features

| Feature | Method | Description |
|---------|--------|-------------|
| Caller context | `simulator.as(caller)` | Execute next operation as specified caller |
| Persistent caller | `simulator.setPersistentCaller(caller)` | Set caller for all operations |
| Reset caller | `simulator.resetCaller()` | Clear caller context |
| Witness override | `simulator.overrideWitness(key, fn)` | Mock witness functions |
| Private state | `simulator.getPrivateState()` | Get current private state |
| Public state | `simulator.getPublicState()` | Get public ledger state |
| Contract state | `simulator.getContractState()` | Get full contract state |

## Test Utilities

### address.ts

The `test-utils/address.ts` module provides helpers for generating test keys and addresses:

```typescript
import * as utils from '#test-utils/address.js';

// Generate public key pairs for testing
const [OWNER, Z_OWNER] = utils.generateEitherPubKeyPair('OWNER');
// OWNER = hex string (for simulator context)
// Z_OWNER = Either<ZswapCoinPublicKey, ContractAddress> (for contract parameters)

const [SPENDER, Z_SPENDER] = utils.generateEitherPubKeyPair('SPENDER');

// Generate contract address
const Z_OWNER_CONTRACT = utils.createEitherTestContractAddress('OWNER_CONTRACT');

// Pre-built zero addresses
utils.ZERO_KEY     // Either with zero ZswapCoinPublicKey
utils.ZERO_ADDRESS // Either with zero ContractAddress
```

**Important**: Same key, different formats:
- `OWNER` (hex string) -- used with `simulator.as(OWNER)`
- `Z_OWNER` (encoded Either) -- used as contract circuit parameters

### Key Helper Functions

| Function | Returns | Purpose |
|----------|---------|---------|
| `generateEitherPubKeyPair(name)` | `[hexPK, Either<ZswapCoinPublicKey, ContractAddress>]` | Create test user key pair |
| `generatePubKeyPair(name)` | `[hexPK, ZswapCoinPublicKey]` | Create raw key pair |
| `createEitherTestUser(name)` | `Either` (left/pk) | Create Either-wrapped user key |
| `createEitherTestContractAddress(name)` | `Either` (right/address) | Create Either-wrapped contract address |
| `encodeToPK(name)` | `ZswapCoinPublicKey` | Encode string to public key |
| `toHexPadded(str, len?)` | `string` | Convert ASCII to padded hex |

## Writing Tests

### Basic Test Structure

```typescript
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import * as utils from '#test-utils/address.js';
import { FungibleTokenSimulator } from './simulators/FungibleTokenSimulator.js';

const NAME = 'MyToken';
const SYMBOL = 'MTK';
const DECIMALS = 18n;
const AMOUNT = 250n;

const [OWNER, Z_OWNER] = utils.generateEitherPubKeyPair('OWNER');
const [SPENDER, Z_SPENDER] = utils.generateEitherPubKeyPair('SPENDER');
const [, Z_RECIPIENT] = utils.generateEitherPubKeyPair('RECIPIENT');

describe('FungibleToken', () => {
  let token: FungibleTokenSimulator;

  beforeEach(() => {
    token = new FungibleTokenSimulator(NAME, SYMBOL, DECIMALS, true);
  });

  describe('transfer', () => {
    beforeEach(() => {
      token._mint(Z_OWNER, AMOUNT);
    });

    afterEach(() => {
      expect(token.totalSupply()).toEqual(AMOUNT);
    });

    it('should transfer tokens', () => {
      const success = token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT);
      expect(success).toBe(true);
      expect(token.balanceOf(Z_OWNER)).toEqual(0n);
      expect(token.balanceOf(Z_RECIPIENT)).toEqual(AMOUNT);
    });

    it('should fail with insufficient balance', () => {
      expect(() => {
        token.as(OWNER).transfer(Z_RECIPIENT, AMOUNT + 1n);
      }).toThrow('FungibleToken: insufficient balance');
    });

    it('should fail when transferring to a contract', () => {
      const Z_CONTRACT = utils.createEitherTestContractAddress('CONTRACT');
      expect(() => {
        token.as(OWNER).transfer(Z_CONTRACT, AMOUNT);
      }).toThrow('FungibleToken: Unsafe Transfer');
    });
  });
});
```

### Testing Uninitialized Contracts

```typescript
describe('when not initialized', () => {
  beforeEach(() => {
    token = new FungibleTokenSimulator('', '', 0n, false); // init = false
  });

  it('all circuits should fail', () => {
    expect(() => token.name()).toThrow('Initializable: contract not initialized');
    expect(() => token.totalSupply()).toThrow('Initializable: contract not initialized');
    expect(() => token._mint(Z_OWNER, AMOUNT)).toThrow('Initializable: contract not initialized');
  });
});
```

### Testing with Witness Overrides

```typescript
it('should handle custom witness behavior', () => {
  const customNonce = new Uint8Array(32).fill(42);

  simulator.overrideWitness('secretNonce', (context) => {
    return [context.privateState, customNonce];
  });

  simulator.someOperation();
  // Verify behavior with overridden witness
});
```

### Testing Multi-User Interactions

```typescript
it('should handle approve + transferFrom flow', () => {
  token._mint(Z_OWNER, AMOUNT);

  // Owner approves spender
  token.as(OWNER).approve(Z_SPENDER, AMOUNT);
  expect(token.allowance(Z_OWNER, Z_SPENDER)).toEqual(AMOUNT);

  // Spender transfers on behalf of owner
  token.as(SPENDER).transferFrom(Z_OWNER, Z_RECIPIENT, AMOUNT);
  expect(token.balanceOf(Z_RECIPIENT)).toEqual(AMOUNT);
  expect(token.allowance(Z_OWNER, Z_SPENDER)).toEqual(0n);
});
```

### Testing Parameterized Scenarios

```typescript
const ownerTypes = [
  ['contract', Z_OWNER_CONTRACT],
  ['pubkey', Z_OWNER],
] as const;

describe.each(ownerTypes)('when the owner is a %s', (_, owner) => {
  it('should return zero for new account', () => {
    expect(token.balanceOf(owner)).toEqual(0n);
  });
});
```

## Simulator Package API Reference

### `createSimulator<P, L, W, C, A>` Configuration

| Option | Type | Description |
|--------|------|-------------|
| `contractFactory` | `(witnesses) => Contract` | Creates contract instance |
| `defaultPrivateState` | `() => P` | Factory for default private state |
| `contractArgs` | `(...args) => ConstructorArgs` | Maps simulator args to constructor args |
| `ledgerExtractor` | `(state) => L` | Extracts ledger from contract state |
| `witnessesFactory` | `() => W` | Factory for witness implementations |

### `BaseSimulatorOptions<P, W>`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `privateState` | `P` | from factory | Initial private state |
| `witnesses` | `W` | from factory | Custom witness implementations |
| `coinPK` | `CoinPublicKey` | `'0'.repeat(64)` | Deployer's coin public key |
| `contractAddress` | `ContractAddress` | `sampleContractAddress()` | Contract address |

### Circuit Access

- `this.circuits.pure.*` -- Pure circuits (no state modification)
- `this.circuits.impure.*` -- Impure circuits (read/modify state)

### Witness Factory Pattern

The simulator requires `witnessesFactory` to be a function, even for empty witnesses:

```typescript
// Wrong: direct object
export const MyWitnesses = {};

// Correct: factory function
export const MyWitnesses = () => ({});
```
