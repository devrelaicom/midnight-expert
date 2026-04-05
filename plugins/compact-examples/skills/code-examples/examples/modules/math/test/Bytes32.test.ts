import type { U256 } from '@src/artifacts/math/test/mocks/contracts/Bytes32.mock/contract/index.js';
import { Bytes32Simulator } from '@src/math/test/mocks/Bytes32Simulator.js';
import {
  MAX_UINT64,
  MAX_UINT128,
  MAX_UINT256,
} from '@src/math/utils/consts.js';
import { beforeEach, describe, expect, test } from 'vitest';

let bytes32Simulator: Bytes32Simulator;

const setup = () => {
  bytes32Simulator = new Bytes32Simulator();
};

/**
 * Create 32-element vector from bigint (little-endian bytes).
 */
const toVec32 = (value: bigint): bigint[] => {
  const vec = new Array<bigint>(32).fill(0n);
  for (let i = 0; i < 32; i++) {
    vec[i] = (value >> (8n * BigInt(i))) & 0xffn;
  }
  return vec;
};

const fromU256 = (u: U256): bigint =>
  u.low.low +
  (u.low.high << 64n) +
  (u.high.low << 128n) +
  (u.high.high << 192n);

/** Bytes<32> from bigint (little-endian). */
const toBytes = (value: bigint): Uint8Array =>
  bytes32Simulator.pack(toVec32(value));

// TODO: Create reusable test fixture for math modules - https://github.com/OpenZeppelin/midnight-apps/issues/297

describe('Bytes32', () => {
  beforeEach(setup);

  describe('conversions', () => {
    describe('pack', () => {
      test('should convert zero vector to zero bytes', () => {
        const vec = toVec32(0n);
        const result = bytes32Simulator.pack(vec);
        expect(result).toEqual(new Uint8Array(32).fill(0));
      });

      test('should match vector elements as bytes', () => {
        const value = 1234567890123456789012345678901234567890n;
        const vec = toVec32(value);
        const result = bytes32Simulator.pack(vec);
        expect(result.length).toBe(32);
        for (let i = 0; i < 32; i++) {
          expect(result[i]).toBe(Number(vec[i]));
        }
      });

      test('should roundtrip with vectorToU256', () => {
        const value = MAX_UINT128 + (1n << 128n);
        const vec = toVec32(value);
        const u256 = bytes32Simulator.vectorToU256(vec);
        const bytes = bytes32Simulator.pack(vec);
        expect(fromU256(u256)).toBe(value);
        let back = 0n;
        for (let i = 0; i < 32; i++) {
          back += BigInt(bytes[i]) << (8n * BigInt(i));
        }
        expect(back).toBe(value);
      });
    });

    describe('unpack', () => {
      test('should unpack bytes to vector matching pack roundtrip', () => {
        const value = 0x0123456789abcdefn;
        const vec = toVec32(value);
        const bytes = bytes32Simulator.pack(vec);
        const unpacked = bytes32Simulator.unpack(bytes);
        expect(unpacked).toEqual(vec);
      });

      test('should unpack zero bytes to zero vector', () => {
        const bytes = new Uint8Array(32).fill(0);
        const unpacked = bytes32Simulator.unpack(bytes);
        expect(unpacked).toEqual(new Array(32).fill(0n));
      });

      test('should fail when witness returns pack(vec) != bytes', () => {
        bytes32Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        const bytes = new Uint8Array(32);
        bytes[0] = 1;
        expect(() => bytes32Simulator.unpack(bytes)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('vectorToU256', () => {
      test('should convert zero vector to zero U256', () => {
        const vec = toVec32(0n);
        const result = bytes32Simulator.vectorToU256(vec);
        expect(fromU256(result)).toBe(0n);
      });

      test('should convert small value in first limb only', () => {
        const vec = toVec32(0x0123456789abcdefn);
        const result = bytes32Simulator.vectorToU256(vec);
        expect(fromU256(result)).toBe(0x0123456789abcdefn);
      });

      test('should convert value spanning all 4 limbs', () => {
        const value = 1n + (2n << 64n) + (3n << 128n) + (4n << 192n);
        const vec = toVec32(value);
        const result = bytes32Simulator.vectorToU256(vec);
        expect(fromU256(result)).toBe(value);
      });

      test('should convert MAX_U256 all-0xFF vector', () => {
        const vec = new Array<bigint>(32).fill(255n);
        const result = bytes32Simulator.vectorToU256(vec);
        expect(result.low.low).toBe(MAX_UINT64);
        expect(result.low.high).toBe(MAX_UINT64);
        expect(result.high.low).toBe(MAX_UINT64);
        expect(result.high.high).toBe(MAX_UINT64);
        expect(fromU256(result)).toBe(MAX_UINT256);
      });

      test('should place byte at limb boundary (byte 8)', () => {
        const vec = new Array<bigint>(32).fill(0n);
        vec[8] = 1n;
        const result = bytes32Simulator.vectorToU256(vec);
        expect(fromU256(result)).toBe(1n << 64n);
      });

      test('should place byte at limb boundary (byte 16)', () => {
        const vec = new Array<bigint>(32).fill(0n);
        vec[16] = 1n;
        const result = bytes32Simulator.vectorToU256(vec);
        expect(fromU256(result)).toBe(1n << 128n);
      });

      test('should place byte at limb boundary (byte 24)', () => {
        const vec = new Array<bigint>(32).fill(0n);
        vec[24] = 1n;
        const result = bytes32Simulator.vectorToU256(vec);
        expect(fromU256(result)).toBe(1n << 192n);
      });
    });

    describe('bytesToU256', () => {
      test('should convert zero bytes to zero U256', () => {
        const bytes = new Uint8Array(32).fill(0);
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(fromU256(result)).toBe(0n);
      });

      test('should convert small value in first limb only', () => {
        const value = 0x0123456789abcdefn;
        const bytes = bytes32Simulator.pack(toVec32(value));
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(fromU256(result)).toBe(value);
      });

      test('should convert value spanning all 4 limbs', () => {
        const value = 1n + (2n << 64n) + (3n << 128n) + (4n << 192n);
        const bytes = bytes32Simulator.pack(toVec32(value));
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(fromU256(result)).toBe(value);
      });

      test('should convert MAX_U256 all-0xFF bytes', () => {
        const bytes = bytes32Simulator.pack(new Array<bigint>(32).fill(255n));
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(result.low.low).toBe(MAX_UINT64);
        expect(result.low.high).toBe(MAX_UINT64);
        expect(result.high.low).toBe(MAX_UINT64);
        expect(result.high.high).toBe(MAX_UINT64);
        expect(fromU256(result)).toBe(MAX_UINT256);
      });

      test('should place byte at limb boundary (byte 8)', () => {
        const vec = new Array<bigint>(32).fill(0n);
        vec[8] = 1n;
        const bytes = bytes32Simulator.pack(vec);
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(fromU256(result)).toBe(1n << 64n);
      });

      test('should place byte at limb boundary (byte 16)', () => {
        const vec = new Array<bigint>(32).fill(0n);
        vec[16] = 1n;
        const bytes = bytes32Simulator.pack(vec);
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(fromU256(result)).toBe(1n << 128n);
      });

      test('should place byte at limb boundary (byte 24)', () => {
        const vec = new Array<bigint>(32).fill(0n);
        vec[24] = 1n;
        const bytes = bytes32Simulator.pack(vec);
        const result = bytes32Simulator.bytesToU256(bytes);
        expect(fromU256(result)).toBe(1n << 192n);
      });

      test('should fail when witness returns pack(vec) != bytes', () => {
        bytes32Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        const bytes = new Uint8Array(32);
        bytes[0] = 1;
        expect(() => bytes32Simulator.bytesToU256(bytes)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });
  });

  describe('comparisons', () => {
    describe('eq', () => {
      test('should return true for equal values', () => {
        const a = toBytes(0x0123456789abcdefn);
        expect(bytes32Simulator.eq(a, a)).toBe(true);
      });

      test('should return true for zero equals zero', () => {
        const z = toBytes(0n);
        expect(bytes32Simulator.eq(z, z)).toBe(true);
      });

      test('should return true for MAX_UINT256 equals MAX_UINT256', () => {
        const m = toBytes(MAX_UINT256);
        expect(bytes32Simulator.eq(m, m)).toBe(true);
      });

      test('should return false for different values', () => {
        const a = toBytes(0n);
        const b = toBytes(1n);
        expect(bytes32Simulator.eq(a, b)).toBe(false);
        expect(bytes32Simulator.eq(b, a)).toBe(false);
      });

      test('should return false for zero and one', () => {
        expect(bytes32Simulator.eq(toBytes(0n), toBytes(1n))).toBe(false);
      });
    });

    describe('lt', () => {
      test('should return true when first value is smaller', () => {
        expect(bytes32Simulator.lt(toBytes(5n), toBytes(10n))).toBe(true);
      });

      test('should return false when first value is larger', () => {
        expect(bytes32Simulator.lt(toBytes(10n), toBytes(5n))).toBe(false);
      });

      test('should return false for equal values', () => {
        const a = toBytes(0x0123456789abcdefn);
        expect(bytes32Simulator.lt(a, a)).toBe(false);
      });

      test('should return true for zero compared to one', () => {
        expect(bytes32Simulator.lt(toBytes(0n), toBytes(1n))).toBe(true);
      });

      test('should return false for one compared to zero', () => {
        expect(bytes32Simulator.lt(toBytes(1n), toBytes(0n))).toBe(false);
      });

      test('should return true for MAX_UINT256 - 1 compared to MAX_UINT256', () => {
        expect(
          bytes32Simulator.lt(toBytes(MAX_UINT256 - 1n), toBytes(MAX_UINT256)),
        ).toBe(true);
      });

      test('should be inverse of gt: a < b iff b > a', () => {
        const pairs: [bigint, bigint][] = [
          [0n, 1n],
          [1n, 2n],
          [100n, MAX_UINT128],
          [2n ** 64n, 2n ** 128n],
        ];
        for (const [a, b] of pairs) {
          expect(bytes32Simulator.lt(toBytes(a), toBytes(b))).toBe(
            bytes32Simulator.gt(toBytes(b), toBytes(a)),
          );
        }
      });

      test('should fail when witness returns bad unpack result', () => {
        bytes32Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        const a = new Uint8Array(32);
        a[0] = 1;
        const b = new Uint8Array(32);
        expect(() => bytes32Simulator.lt(a, b)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('lte', () => {
      test('should return true when first value is smaller', () => {
        expect(bytes32Simulator.lte(toBytes(5n), toBytes(10n))).toBe(true);
      });

      test('should return false when first value is larger', () => {
        expect(bytes32Simulator.lte(toBytes(10n), toBytes(5n))).toBe(false);
      });

      test('should return true for equal values', () => {
        const a = toBytes(0x0123456789abcdefn);
        expect(bytes32Simulator.lte(a, a)).toBe(true);
      });

      test('should return true for zero compared to zero', () => {
        const z = toBytes(0n);
        expect(bytes32Simulator.lte(z, z)).toBe(true);
      });

      test('should be inverse of gte: a <= b iff b >= a', () => {
        const pairs: [bigint, bigint][] = [
          [0n, 0n],
          [0n, 1n],
          [1n, 1n],
          [100n, MAX_UINT256],
        ];
        for (const [a, b] of pairs) {
          expect(bytes32Simulator.lte(toBytes(a), toBytes(b))).toBe(
            bytes32Simulator.gte(toBytes(b), toBytes(a)),
          );
        }
      });

      test('should fail when witness returns bad unpack result', () => {
        bytes32Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        const a = new Uint8Array(32);
        a[0] = 1;
        const b = new Uint8Array(32);
        expect(() => bytes32Simulator.lte(a, b)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('gt', () => {
      test('should return true when first value is larger', () => {
        expect(bytes32Simulator.gt(toBytes(10n), toBytes(5n))).toBe(true);
      });

      test('should return false when first value is smaller', () => {
        expect(bytes32Simulator.gt(toBytes(5n), toBytes(10n))).toBe(false);
      });

      test('should return false for equal values', () => {
        const a = toBytes(0x0123456789abcdefn);
        expect(bytes32Simulator.gt(a, a)).toBe(false);
      });

      test('should return true for one compared to zero', () => {
        expect(bytes32Simulator.gt(toBytes(1n), toBytes(0n))).toBe(true);
      });

      test('should fail when witness returns bad unpack result', () => {
        bytes32Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        const a = new Uint8Array(32);
        a[0] = 1;
        const b = new Uint8Array(32);
        expect(() => bytes32Simulator.gt(a, b)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('gte', () => {
      test('should return true when first value is larger', () => {
        expect(bytes32Simulator.gte(toBytes(10n), toBytes(5n))).toBe(true);
      });

      test('should return false when first value is smaller', () => {
        expect(bytes32Simulator.gte(toBytes(5n), toBytes(10n))).toBe(false);
      });

      test('should return true for equal values', () => {
        const a = toBytes(0x0123456789abcdefn);
        expect(bytes32Simulator.gte(a, a)).toBe(true);
      });

      test('should return true for zero compared to zero', () => {
        const z = toBytes(0n);
        expect(bytes32Simulator.gte(z, z)).toBe(true);
      });

      test('should fail when witness returns bad unpack result', () => {
        bytes32Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        const a = new Uint8Array(32);
        a[0] = 1;
        const b = new Uint8Array(32);
        expect(() => bytes32Simulator.gte(a, b)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });
  });

  describe('utilities', () => {
    describe('isZero', () => {
      test('should return true for zero bytes', () => {
        expect(bytes32Simulator.isZero(toBytes(0n))).toBe(true);
      });

      test('should return false for one', () => {
        expect(bytes32Simulator.isZero(toBytes(1n))).toBe(false);
      });

      test('should return false for arbitrary non-zero values', () => {
        expect(bytes32Simulator.isZero(toBytes(0x0123456789abcdefn))).toBe(
          false,
        );
        expect(bytes32Simulator.isZero(toBytes(MAX_UINT256 - 1n))).toBe(false);
      });

      test('should return false for MAX_UINT256', () => {
        expect(bytes32Simulator.isZero(toBytes(MAX_UINT256))).toBe(false);
      });
    });
  });
});
