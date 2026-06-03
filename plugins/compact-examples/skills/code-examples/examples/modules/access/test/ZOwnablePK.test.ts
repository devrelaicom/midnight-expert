import {
  CompactTypeBytes,
  CompactTypeVector,
  convertFieldToBytes,
  persistentHash,
} from '@midnight-ntwrk/compact-runtime';
import { getRandomValues } from 'node:crypto';
import { beforeEach, describe, expect, it } from 'vitest';
import { ZOwnablePKPrivateState } from '../witnesses/ZOwnablePKWitnesses.js';
import { ZOwnablePKSimulator } from './simulators/ZOwnablePKSimulator.js';

// =============================================================================
//  SECURE PATTERN — witness-derived identity.
//  The owner's identity is derived ENTIRELY from a single 32-byte witness
//  secret: pk = H("zownablepk:owner:pk:v1", secret) and
//  nonce = H("zownablepk:owner:nonce:v1", secret). The ownerId committed at
//  deploy is H(pk, nonce). `ownPublicKey()` plays no role in authorization.
// =============================================================================

const DOMAIN = 'ZOwnablePK:shield:';
const PK_DOMAIN = 'zownablepk:owner:pk:v1';
const NONCE_DOMAIN = 'zownablepk:owner:nonce:v1';
const INSTANCE_SALT = new Uint8Array(32).fill(8);
const INIT_COUNTER = 1n;

// Deterministic 32-byte secrets for stable identities across the suite.
const padTo32 = (s: string): Uint8Array => {
  const u = new Uint8Array(32);
  u.set(new TextEncoder().encode(s).subarray(0, 32));
  return u;
};
const OWNER_SECRET = padTo32('owner-secret');
const NEW_OWNER_SECRET = padTo32('new-owner-secret');
const UNAUTHORIZED_SECRET = padTo32('unauthorized-secret');
const BAD_SECRET = padTo32('bad-secret');

let ownable: ZOwnablePKSimulator;

// Off-chain mirrors of the in-circuit derivations.
const hashDomain2 = (domain: string, b: Uint8Array): Uint8Array => {
  const rt = new CompactTypeVector(2, new CompactTypeBytes(32));
  return persistentHash(rt, [padTo32(domain), b]);
};

const deriveOwnerPk = (secret: Uint8Array): Uint8Array =>
  hashDomain2(PK_DOMAIN, secret);
const deriveOwnerNonce = (secret: Uint8Array): Uint8Array =>
  hashDomain2(NONCE_DOMAIN, secret);

const createIdFromSecret = (secret: Uint8Array): Uint8Array => {
  const pk = deriveOwnerPk(secret);
  const nonce = deriveOwnerNonce(secret);
  const rt = new CompactTypeVector(2, new CompactTypeBytes(32));
  return persistentHash(rt, [pk, nonce]);
};

const buildCommitmentFromId = (
  id: Uint8Array,
  instanceSalt: Uint8Array,
  counter: bigint,
): Uint8Array => {
  const rt = new CompactTypeVector(4, new CompactTypeBytes(32));
  const bCounter = convertFieldToBytes(32, counter, '');
  const bDomain = new TextEncoder().encode(DOMAIN);
  return persistentHash(rt, [id, instanceSalt, bCounter, bDomain]);
};

const buildCommitmentFromSecret = (
  secret: Uint8Array,
  instanceSalt: Uint8Array,
  counter: bigint,
): Uint8Array =>
  buildCommitmentFromId(createIdFromSecret(secret), instanceSalt, counter);

describe('ZOwnablePK', () => {
  describe('before initialize', () => {
    it('should fail when setting owner id as 0', () => {
      expect(() => {
        const badId = new Uint8Array(32).fill(0);
        new ZOwnablePKSimulator(badId, INSTANCE_SALT, true);
      }).toThrow('ZOwnablePK: invalid id');
    });

    it('should initialize with non-zero commitment', () => {
      const id = createIdFromSecret(OWNER_SECRET);
      ownable = new ZOwnablePKSimulator(id, INSTANCE_SALT, true, {
        privateState: ZOwnablePKPrivateState.withSecret(OWNER_SECRET),
      });

      const expectedCommitment = buildCommitmentFromId(
        id,
        INSTANCE_SALT,
        INIT_COUNTER,
      );
      expect(ownable.owner()).toEqual(expectedCommitment);
    });
  });

  describe('when not initialized correctly', () => {
    const isNotInit = false;
    const randomByteArray = new Uint8Array(32).fill(123);
    const randomCounter = 321n;

    beforeEach(() => {
      ownable = new ZOwnablePKSimulator(
        randomByteArray,
        INSTANCE_SALT,
        isNotInit,
      );
    });

    type FailingCircuits = [method: keyof ZOwnablePKSimulator, args: unknown[]];
    // Circuit calls should fail before the args are used.
    const circuitsToFail: FailingCircuits[] = [
      ['owner', []],
      ['assertOnlyOwner', []],
      ['transferOwnership', [randomByteArray]],
      ['renounceOwnership', []],
      ['_computeOwnerCommitment', [randomByteArray, randomCounter]],
      ['_transferOwnership', [randomByteArray]],
    ];
    it.each(circuitsToFail)('%s should fail', (circuitName, args) => {
      expect(() => {
        (ownable[circuitName] as (...args: unknown[]) => unknown)(...args);
      }).toThrow('Initializable: contract not initialized');
    });

    it('should allow pure derivations and _computeOwnerId without init', () => {
      const sk = { bytes: randomByteArray };
      expect(() => {
        const pk = ownable._deriveOwnerPublicKey(sk);
        const nonce = ownable._deriveOwnerNonce(sk);
        ownable._computeOwnerId(pk, nonce);
      }).not.toThrow();
    });
  });

  describe('after initialization', () => {
    beforeEach(() => {
      const id = createIdFromSecret(OWNER_SECRET);
      ownable = new ZOwnablePKSimulator(id, INSTANCE_SALT, true, {
        privateState: ZOwnablePKPrivateState.withSecret(OWNER_SECRET),
      });
    });

    describe('owner', () => {
      it('should return the correct owner commitment', () => {
        const expCommitment = buildCommitmentFromSecret(
          OWNER_SECRET,
          INSTANCE_SALT,
          INIT_COUNTER,
        );
        expect(ownable.owner()).toEqual(expCommitment);
      });
    });

    describe('transferOwnership', () => {
      let newOwnerId: Uint8Array;
      let newOwnerCommitment: Uint8Array;
      const newCounter = INIT_COUNTER + 1n;

      beforeEach(() => {
        newOwnerId = createIdFromSecret(NEW_OWNER_SECRET);
        newOwnerCommitment = buildCommitmentFromId(
          newOwnerId,
          INSTANCE_SALT,
          newCounter,
        );
      });

      it('should transfer ownership', () => {
        ownable.transferOwnership(newOwnerId);
        expect(ownable.owner()).toEqual(newOwnerCommitment);

        // Old owner (still holding the old secret) is denied.
        expect(() => {
          ownable.assertOnlyOwner();
        }).toThrow('ZOwnablePK: caller is not the owner');

        // The new owner, providing the new secret, is authorized.
        ownable.privateState.injectSecret(NEW_OWNER_SECRET);
        expect(() => {
          ownable.assertOnlyOwner();
        }).not.toThrow();
      });

      it('should fail when transferring to id zero', () => {
        const badId = new Uint8Array(32).fill(0);
        expect(() => {
          ownable.transferOwnership(badId);
        }).toThrow('ZOwnablePK: invalid id');
      });

      it('should fail when an unauthorized secret transfers ownership', () => {
        ownable.privateState.injectSecret(UNAUTHORIZED_SECRET);
        expect(() => {
          ownable.transferOwnership(newOwnerId);
        }).toThrow('ZOwnablePK: caller is not the owner');
      });

      it('should bump counter after transfer', () => {
        const before = ownable.getPublicState().ZOwnablePK__counter;
        ownable.transferOwnership(newOwnerId);
        const after = ownable.getPublicState().ZOwnablePK__counter;
        expect(after).toEqual(before + 1n);
      });

      it('should change commitment when transferring to self with same secret', () => {
        const sameId = createIdFromSecret(OWNER_SECRET);
        const initCommitment = ownable.owner();

        ownable.transferOwnership(sameId);

        const bumped = ownable.owner();
        expect(initCommitment).not.toEqual(bumped);

        const expNew = buildCommitmentFromId(
          sameId,
          INSTANCE_SALT,
          INIT_COUNTER + 1n,
        );
        expect(bumped).toEqual(expNew);

        // Same owner keeps permissions after a self-transfer.
        expect(() => {
          ownable.assertOnlyOwner();
        }).not.toThrow();
      });
    });

    describe('renounceOwnership', () => {
      it('should renounce ownership', () => {
        ownable.renounceOwnership();
        expect(ownable.owner()).toEqual(new Uint8Array(32).fill(0));

        expect(() => {
          ownable.assertOnlyOwner();
        }).toThrow('ZOwnablePK: caller is not the owner');
      });

      it('should fail when renouncing from an unauthorized secret', () => {
        ownable.privateState.injectSecret(UNAUTHORIZED_SECRET);
        expect(() => {
          ownable.renounceOwnership();
        }).toThrow('ZOwnablePK: caller is not the owner');
      });

      it('should fail when renouncing with a bad secret', () => {
        ownable.privateState.injectSecret(BAD_SECRET);
        expect(() => {
          ownable.renounceOwnership();
        }).toThrow('ZOwnablePK: caller is not the owner');
      });
    });

    describe('assertOnlyOwner', () => {
      it('should allow the owner holding the correct secret', () => {
        expect(ownable.privateState.getCurrentSecret()).toEqual(OWNER_SECRET);
        expect(() => {
          ownable.assertOnlyOwner();
        }).not.toThrow();
      });

      it('should fail when the secret is wrong', () => {
        ownable.privateState.injectSecret(BAD_SECRET);
        expect(ownable.privateState.getCurrentSecret()).not.toEqual(
          OWNER_SECRET,
        );
        expect(() => {
          ownable.assertOnlyOwner();
        }).toThrow('ZOwnablePK: caller is not the owner');
      });

      it('should fail for an unauthorized secret', () => {
        ownable.privateState.injectSecret(UNAUTHORIZED_SECRET);
        expect(() => {
          ownable.assertOnlyOwner();
        }).toThrow('ZOwnablePK: caller is not the owner');
      });
    });

    describe('_computeOwnerCommitment', () => {
      const MAX_U64 = 2n ** 64n - 1n;
      const testCases = [
        ...Array.from({ length: 10 }, (_, i) => ({
          label: `User${i}`,
          secret: padTo32(`User${i}-secret`),
          counter: BigInt(Math.floor(Math.random() * 2 ** 32)),
        })),
        { label: 'ZeroCounter', secret: padTo32('ZeroCounter'), counter: 0n },
        { label: 'MaxCounter', secret: padTo32('MaxUser'), counter: MAX_U64 },
      ];
      it.each(testCases)(
        'should match commitment for $label with counter $counter',
        ({ secret, counter }) => {
          const id = createIdFromSecret(secret);
          const fromContract = ownable._computeOwnerCommitment(id, counter);
          const fromHelper = buildCommitmentFromId(id, INSTANCE_SALT, counter);
          expect(fromContract).toEqual(fromHelper);
        },
      );
    });

    describe('_computeOwnerId', () => {
      const testCases = [
        ...Array.from({ length: 10 }, (_, i) => ({
          label: `User${i}`,
          secret: padTo32(`User${i}-id-secret`),
        })),
        { label: 'Zero secret', secret: new Uint8Array(32).fill(0) },
        { label: 'Max secret', secret: new Uint8Array(32).fill(255) },
      ];

      it.each(testCases)(
        'should match local and contract owner id for $label',
        ({ secret }) => {
          const sk = { bytes: secret };
          const pk = ownable._deriveOwnerPublicKey(sk);
          const nonce = ownable._deriveOwnerNonce(sk);
          const ownerId = ownable._computeOwnerId(pk, nonce);
          expect(ownerId).toEqual(createIdFromSecret(secret));
        },
      );
    });

    describe('_deriveOwnerPublicKey / _deriveOwnerNonce', () => {
      it('should match off-chain derivations', () => {
        const secret = getRandomValues(new Uint8Array(32));
        const sk = { bytes: secret };
        expect(ownable._deriveOwnerPublicKey(sk).bytes).toEqual(
          deriveOwnerPk(secret),
        );
        expect(ownable._deriveOwnerNonce(sk)).toEqual(deriveOwnerNonce(secret));
      });

      it('should domain-separate pk and nonce for the same secret', () => {
        const sk = { bytes: OWNER_SECRET };
        expect(ownable._deriveOwnerPublicKey(sk).bytes).not.toEqual(
          ownable._deriveOwnerNonce(sk),
        );
      });
    });

    describe('_transferOwnership', () => {
      it('should transfer ownership', () => {
        const id = createIdFromSecret(OWNER_SECRET);
        ownable._transferOwnership(id);

        const expCommitment = buildCommitmentFromId(
          id,
          INSTANCE_SALT,
          INIT_COUNTER + 1n,
        );
        expect(ownable.owner()).toEqual(expCommitment);
      });

      it('should bump the counter with each transfer', () => {
        const nTransfers = 10;
        // Count starts at 2 because the constructor bumps it to 1.
        for (let i = 2; i <= nTransfers; i++) {
          const id = createIdFromSecret(padTo32(`Id${i}`));
          ownable._transferOwnership(id);
          expect(ownable.getPublicState().ZOwnablePK__counter).toEqual(
            BigInt(i),
          );
        }
      });

      it('should allow anyone to call the internal transfer', () => {
        const id = createIdFromSecret(OWNER_SECRET);
        expect(() => {
          ownable._transferOwnership(id);
        }).not.toThrow();

        ownable.privateState.injectSecret(UNAUTHORIZED_SECRET);
        expect(() => {
          ownable._transferOwnership(id);
        }).not.toThrow();
      });
    });
  });
});
