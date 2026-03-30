# Witness Testing Reference

## Witness File Structure

A witness file defines three things: a `PrivateState` type, a factory with `.generate()`, and one or more witness functions that return `[P, Uint8Array]` (or `[P, bigint]` depending on the return type).

### `PrivateState` Type

The private state holds secrets the contract needs but that never appear on-ledger:

```typescript
export type ZOwnablePKPrivateState = {
  secretNonce: Buffer;
};
```

For contracts with no private state:

```typescript
export type OwnablePrivateState = Record<string, never>;
export const OwnablePrivateState: OwnablePrivateState = {};
```

### Factory with `.generate()`

The private state object doubles as a factory namespace. The `.generate()` method creates a fresh instance with random secrets:

```typescript
export const ZOwnablePKPrivateState = {
  generate: (): ZOwnablePKPrivateState => {
    return { secretNonce: getRandomValues(Buffer.alloc(32)) };
  },

  withNonce: (nonce: Buffer): ZOwnablePKPrivateState => {
    if (nonce.length !== 32) {
      throw new Error(`withNonce: expected 32-byte nonce, received ${nonce.length} bytes`);
    }
    return { secretNonce: Buffer.from(nonce) };
  },
};
```

For more complex private state with multiple secret fields:

```typescript
export type WitnessPrivateState = {
  secretBytes: Buffer;
  secretField: bigint;
  secretUint: bigint;
};

export const WitnessPrivateState = {
  generate: (): WitnessPrivateState => {
    return {
      secretBytes: getRandomValues(Buffer.alloc(32)),
      secretField: randomBigInt(222),
      secretUint: randomBigInt(128),
    };
  },
};
```

### Witness Functions

Each witness function receives a `WitnessContext` and returns a tuple of `[updatedPrivateState, value]`:

```typescript
export const ZOwnablePKWitnesses =
  (): IZOwnablePKWitnesses<ZOwnablePKPrivateState> => ({
    wit_secretNonce(
      context: WitnessContext<Ledger, ZOwnablePKPrivateState>,
    ): [ZOwnablePKPrivateState, Uint8Array] {
      return [context.privateState, context.privateState.secretNonce];
    },
  });
```

Witness functions can accept additional arguments from the circuit:

```typescript
export const WitnessWitnesses = (): IWitnessWitnesses<WitnessPrivateState> => ({
  wit_secretBytes(
    context: WitnessContext<Ledger, WitnessPrivateState>,
  ): [WitnessPrivateState, Uint8Array] {
    return [context.privateState, context.privateState.secretBytes];
  },
  wit_secretFieldPlusArg(
    context: WitnessContext<Ledger, WitnessPrivateState>,
    arg: bigint,
  ): [WitnessPrivateState, bigint] {
    return [context.privateState, context.privateState.secretField + arg];
  },
  wit_secretUintPlusArgs(
    context: WitnessContext<Ledger, WitnessPrivateState>,
    arg1: bigint,
    arg2: bigint,
  ): [WitnessPrivateState, bigint] {
    return [context.privateState, context.privateState.secretUint + arg1 + arg2];
  },
});
```

## `WitnessContext<L, P>` Shape

The `WitnessContext` that the simulator passes to witness functions contains:

```typescript
{
  ledger: L,              // Decoded public ledger state
  privateState: P,        // Current private state
  contractAddress: string // Deployed contract address
}
```

The simulator constructs this from the current circuit context via `getWitnessContext()`.

## Bulk Witness Override

Replace **all** witness functions at once by assigning to `simulator.witnesses`. This triggers a contract rebuild and circuit proxy reset:

```typescript
const overrideWitnesses = (): IWitnessWitnesses<WitnessPrivateState> => ({
  wit_secretBytes(ctx) {
    return [ctx.privateState, BYTES_OVERRIDE];
  },
  wit_secretFieldPlusArg(ctx) {
    return [ctx.privateState, FIELD_OVERRIDE];
  },
  wit_secretUintPlusArgs(ctx) {
    return [ctx.privateState, UINT_OVERRIDE];
  },
});

// Replace all witnesses
contract.witnesses = overrideWitnesses();

// Subsequent circuit calls use the overridden witnesses
contract.setBytes();
expect(contract.getPublicState()._valBytes).toEqual(BYTES_OVERRIDE);
```

Verify that the override took effect by checking results differ from default behavior:

```typescript
it('should override all witnesses', () => {
  const psBytes = contract.getPrivateState().secretBytes;
  const psField = contract.getPrivateState().secretField;
  const psUint = contract.getPrivateState().secretUint;

  contract.witnesses = overrideWitnesses();

  contract.setBytes();
  contract.setField(VAL1);
  contract.setUint(VAL1, VAL2);

  // Overridden values
  expect(contract.getPublicState()._valBytes).toEqual(BYTES_OVERRIDE);
  expect(contract.getPublicState()._valField).toEqual(FIELD_OVERRIDE);
  expect(contract.getPublicState()._valUint).toEqual(UINT_OVERRIDE);

  // Confirm they differ from default witness behavior
  expect(contract.getPublicState()._valBytes).not.toEqual(new Uint8Array(psBytes));
  expect(contract.getPublicState()._valField).not.toEqual(psField + VAL1);
  expect(contract.getPublicState()._valUint).not.toEqual(psUint + VAL1 + VAL2);
});
```

## Single Witness Override

Replace one witness while keeping all others at their default behavior using `overrideWitness(key, fn)`:

```typescript
contract.overrideWitness('wit_secretBytes', (ctx) => {
  return [ctx.privateState, BYTES_OVERRIDE];
});
```

Verify that only the targeted witness changed:

```typescript
it('should override wit_secretBytes only', () => {
  const psField = contract.getPrivateState().secretField;
  const psUint = contract.getPrivateState().secretUint;

  contract.overrideWitness('wit_secretBytes', (ctx) => {
    return [ctx.privateState, BYTES_OVERRIDE];
  });

  contract.setBytes();
  contract.setField(VAL1);
  contract.setUint(VAL1, VAL2);

  // Overridden
  expect(contract.getPublicState()._valBytes).toEqual(BYTES_OVERRIDE);

  // Other witnesses remain unchanged
  expect(contract.getPublicState()._valField).toEqual(psField + VAL1);
  expect(contract.getPublicState()._valUint).toEqual(psUint + VAL1 + VAL2);
});
```

Under the hood, `overrideWitness` spreads the current witnesses and replaces the specified key, then assigns to `this.witnesses`, which rebuilds the contract and resets circuit proxies.

## Private State Injection

Use `circuitContextManager.updatePrivateState()` to change the private state mid-test without resetting contract or ledger state:

```typescript
// Direct injection
const currentState = simulator.circuitContextManager.getContext().currentPrivateState;
const updatedState = { ...currentState, secretNonce: newNonce };
simulator.circuitContextManager.updatePrivateState(updatedState);
```

The `ZOwnablePKSimulator` wraps this in a convenience API:

```typescript
public readonly privateState = {
  injectSecretNonce: (newNonce: Buffer): ZOwnablePKPrivateState => {
    const currentState = this.circuitContextManager.getContext().currentPrivateState;
    const updatedState = { ...currentState, secretNonce: newNonce };
    this.circuitContextManager.updatePrivateState(updatedState);
    return updatedState;
  },

  getCurrentSecretNonce: (): Uint8Array => {
    return this.circuitContextManager.getContext().currentPrivateState.secretNonce;
  },
};
```

## Testing with `ownPublicKey()`

ZK ownership verification requires both the correct caller public key **and** the correct secret nonce. Combine `.as()` with private state injection to test all four combinations:

```typescript
describe('assertOnlyOwner', () => {
  it('should allow authorized caller with correct nonce', () => {
    expect(ownable.privateState.getCurrentSecretNonce()).toEqual(secretNonce);

    expect(() => {
      ownable.as(OWNER).assertOnlyOwner();
    }).not.toThrow();
  });

  it('should fail when authorized caller has wrong nonce', () => {
    ownable.privateState.injectSecretNonce(BAD_NONCE);
    expect(ownable.privateState.getCurrentSecretNonce()).not.toEqual(secretNonce);

    expect(() => {
      ownable.as(OWNER).assertOnlyOwner();
    }).toThrow('ZOwnablePK: caller is not the owner');
  });

  it('should fail when unauthorized caller has correct nonce', () => {
    expect(ownable.privateState.getCurrentSecretNonce()).toEqual(secretNonce);

    expect(() => {
      ownable.as(UNAUTHORIZED).assertOnlyOwner();
    }).toThrow('ZOwnablePK: caller is not the owner');
  });

  it('should fail when unauthorized caller has wrong nonce', () => {
    ownable.privateState.injectSecretNonce(BAD_NONCE);
    expect(ownable.privateState.getCurrentSecretNonce()).not.toEqual(secretNonce);

    expect(() => {
      ownable.as(UNAUTHORIZED).assertOnlyOwner();
    }).toThrow('ZOwnablePK: caller is not the owner');
  });
});
```

This 2x2 matrix (correct/wrong PK x correct/wrong nonce) ensures the ownership check requires **both** factors.

## Factory Pattern Requirement

Witnesses **must** be factories (functions returning an object), not bare objects. There are two reasons:

1. **Instance isolation.** Each simulator instance needs its own witness object. If witnesses were shared across instances, overriding a witness in one test would corrupt another.

2. **Contract rebuild cycle.** When `simulator.witnesses = newWitnesses` is called, the simulator passes the witnesses into `contractFactory(witnesses)` to rebuild the compiled contract. The contract constructor captures the witness references. If witnesses were a shared mutable object, the old contract would see the mutations too.

```typescript
// WRONG: shared object
const sharedWitnesses = {
  wit_secretNonce(ctx) { return [ctx.privateState, ctx.privateState.secretNonce]; },
};

// RIGHT: factory function
export const ZOwnablePKWitnesses =
  (): IZOwnablePKWitnesses<ZOwnablePKPrivateState> => ({
    wit_secretNonce(context) {
      return [context.privateState, context.privateState.secretNonce];
    },
  });
```

The `SimulatorConfig.witnessesFactory` field enforces this: it expects `() => W`, not `W`.

## Complete Example

Full witness test for a ZOwnablePK-style contract. This demonstrates private state generation, witness override, private state injection, and commitment verification:

```typescript
import {
  CompactTypeBytes,
  CompactTypeVector,
  convertFieldToBytes,
  persistentHash,
} from '@midnight-ntwrk/compact-runtime';
import { beforeEach, describe, expect, it } from 'vitest';
import * as utils from '#test-utils/address.js';
import type { ZswapCoinPublicKey } from '../../../artifacts/MockZOwnablePK/contract/index.js';
import { ZOwnablePKPrivateState } from '../witnesses/ZOwnablePKWitnesses.js';
import { ZOwnablePKSimulator } from './simulators/ZOwnablePKSimulator.js';

// Keys
const [OWNER, Z_OWNER] = utils.generatePubKeyPair('OWNER');
const [NEW_OWNER, Z_NEW_OWNER] = utils.generatePubKeyPair('NEW_OWNER');
const [UNAUTHORIZED, _] = utils.generatePubKeyPair('UNAUTHORIZED');

// Constants
const INSTANCE_SALT = new Uint8Array(32).fill(8675309);
const BAD_NONCE = Buffer.from(Buffer.alloc(32, 'BAD_NONCE'));
const DOMAIN = 'ZOwnablePK:shield:';
const INIT_COUNTER = 1n;

let secretNonce: Uint8Array;
let ownable: ZOwnablePKSimulator;

// Helper: recompute id hash locally
const createIdHash = (pk: ZswapCoinPublicKey, nonce: Uint8Array): Uint8Array => {
  const rt_type = new CompactTypeVector(2, new CompactTypeBytes(32));
  return persistentHash(rt_type, [pk.bytes, nonce]);
};

// Helper: recompute commitment locally
const buildCommitmentFromId = (
  id: Uint8Array, instanceSalt: Uint8Array, counter: bigint,
): Uint8Array => {
  const rt_type = new CompactTypeVector(4, new CompactTypeBytes(32));
  const bCounter = convertFieldToBytes(32, counter, '');
  const bDomain = new TextEncoder().encode(DOMAIN);
  return persistentHash(rt_type, [id, instanceSalt, bCounter, bDomain]);
};

describe('ZOwnablePK', () => {
  beforeEach(() => {
    // Generate fresh private state with random nonce
    const PS = ZOwnablePKPrivateState.generate();
    secretNonce = PS.secretNonce;

    // Derive owner ID from PK + nonce
    const ownerId = createIdHash(Z_OWNER, secretNonce);

    // Deploy with generated private state
    ownable = new ZOwnablePKSimulator(ownerId, INSTANCE_SALT, true, {
      privateState: PS,
    });
  });

  describe('owner commitment', () => {
    it('should store the correct initial commitment', () => {
      const expected = buildCommitmentFromId(
        createIdHash(Z_OWNER, secretNonce),
        INSTANCE_SALT,
        INIT_COUNTER,
      );
      expect(ownable.owner()).toEqual(expected);
    });
  });

  describe('assertOnlyOwner with witness-based auth', () => {
    it('should pass with correct PK + correct nonce', () => {
      expect(() => {
        ownable.as(OWNER).assertOnlyOwner();
      }).not.toThrow();
    });

    it('should fail with correct PK + wrong nonce', () => {
      ownable.privateState.injectSecretNonce(BAD_NONCE);

      expect(() => {
        ownable.as(OWNER).assertOnlyOwner();
      }).toThrow('ZOwnablePK: caller is not the owner');
    });

    it('should fail with wrong PK + correct nonce', () => {
      expect(() => {
        ownable.as(UNAUTHORIZED).assertOnlyOwner();
      }).toThrow('ZOwnablePK: caller is not the owner');
    });
  });

  describe('transferOwnership', () => {
    it('should transfer and bump counter', () => {
      const beforeCounter = ownable.getPublicState().ZOwnablePK__counter;

      const newOwnerNonce = ZOwnablePKPrivateState.generate().secretNonce;
      const newIdHash = createIdHash(Z_NEW_OWNER, newOwnerNonce);

      ownable.as(OWNER).transferOwnership(newIdHash);

      // Counter bumped
      const afterCounter = ownable.getPublicState().ZOwnablePK__counter;
      expect(afterCounter).toEqual(beforeCounter + 1n);

      // New commitment matches local computation
      const expectedCommitment = buildCommitmentFromId(
        newIdHash, INSTANCE_SALT, INIT_COUNTER + 1n,
      );
      expect(ownable.owner()).toEqual(expectedCommitment);

      // New owner can assert after injecting their nonce
      ownable.privateState.injectSecretNonce(Buffer.from(newOwnerNonce));
      expect(() => {
        ownable.as(NEW_OWNER).assertOnlyOwner();
      }).not.toThrow();
    });
  });
});
```
