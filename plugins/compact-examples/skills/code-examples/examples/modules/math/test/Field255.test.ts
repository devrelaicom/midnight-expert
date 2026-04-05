import { MAX_FIELD } from '@midnight-ntwrk/compact-runtime';
import type { U256 } from '@src/artifacts/math/test/mocks/contracts/Field255.mock/contract/index.js';
import { Field255Simulator } from '@src/math/test/mocks/Field255Simulator.js';
import { beforeEach, describe, expect, test } from 'vitest';

let field255Simulator: Field255Simulator;

const setup = () => {
  field255Simulator = new Field255Simulator();
};

/**
 * Boundary values for comprehensive testing.
 */
const BOUNDARY_VALUES = [0n, 1n, 2n, MAX_FIELD - 1n, MAX_FIELD];

/**
 * Powers of 2 for testing.
 */
const POWERS_OF_2 = [
  1n, // 2^0
  2n, // 2^1
  4n, // 2^2
  256n, // 2^8
  65536n, // 2^16
  2n ** 32n, // 2^32
  2n ** 64n, // 2^64
  2n ** 128n, // 2^128
  2n ** 192n, // 2^192
  2n ** 254n, // 2^254 (close to MAX_FIELD)
];

/**
 * Helper to convert U256 struct to bigint.
 */
const fromU256 = (value: U256): bigint => {
  return (
    (value.high.high << 192n) +
    (value.high.low << 128n) +
    (value.low.high << 64n) +
    value.low.low
  );
};

/**
 * Helper to convert little-endian Uint8Array to bigint.
 */
const bytesLEToBigint = (bytes: Uint8Array): bigint => {
  let result = 0n;
  for (let i = bytes.length - 1; i >= 0; i--) {
    result = (result << 8n) | BigInt(bytes[i]);
  }
  return result;
};

describe('Field255', () => {
  beforeEach(setup);

  describe('constants', () => {
    describe('MAX_FIELD', () => {
      test('should return BLS12-381 scalar field prime minus 1', () => {
        const result = field255Simulator.MAX_FIELD();
        expect(result).toBe(MAX_FIELD);
      });
    });
  });

  describe('conversions', () => {
    describe('toBytes', () => {
      test('should convert zero Field to zero bytes', () => {
        const result = field255Simulator.toBytes(0n);
        expect(result).toEqual(new Uint8Array(32).fill(0));
      });

      test('should convert small Field to bytes with correct first byte', () => {
        const result = field255Simulator.toBytes(123n);
        expect(result[0]).toBe(123);
        expect(result.slice(1)).toEqual(new Uint8Array(31).fill(0));
      });

      test('should convert large Field to bytes and back correctly', () => {
        const value = 123456789012345678901234567890n;
        const bytes = field255Simulator.toBytes(value);
        const backToValue = bytesLEToBigint(bytes);
        expect(backToValue).toBe(value);
      });

      test('should convert powers of 2 to bytes and back correctly', () => {
        for (const value of POWERS_OF_2) {
          const bytes = field255Simulator.toBytes(value);
          const backToValue = bytesLEToBigint(bytes);
          expect(backToValue).toBe(value);
        }
      });

      test('should convert MAX_FIELD to bytes and back correctly', () => {
        const bytes = field255Simulator.toBytes(MAX_FIELD);
        const backToValue = bytesLEToBigint(bytes);
        expect(backToValue).toBe(MAX_FIELD);
      });

      test('should convert MAX_FIELD - 1 to bytes and back correctly', () => {
        const bytes = field255Simulator.toBytes(MAX_FIELD - 1n);
        const backToValue = bytesLEToBigint(bytes);
        expect(backToValue).toBe(MAX_FIELD - 1n);
      });
    });

    describe('toU256', () => {
      test('should convert zero Field to zero U256', () => {
        const result = field255Simulator.toU256(0n);
        expect(fromU256(result)).toBe(0n);
      });

      test('should convert one to U256 with only low.low set', () => {
        const u256 = field255Simulator.toU256(1n);
        expect(u256.low.low).toBe(1n);
        expect(u256.low.high).toBe(0n);
        expect(u256.high.low).toBe(0n);
        expect(u256.high.high).toBe(0n);
      });

      test('should convert small Field to U256', () => {
        const result = field255Simulator.toU256(123n);
        expect(fromU256(result)).toBe(123n);
      });

      test('should convert large Field to U256', () => {
        const value = 123456789012345678901234567890n;
        const result = field255Simulator.toU256(value);
        expect(fromU256(result)).toBe(value);
      });

      test('should convert powers of 2 to U256 and back correctly', () => {
        for (const value of POWERS_OF_2) {
          const u256 = field255Simulator.toU256(value);
          expect(fromU256(u256)).toBe(value);
        }
      });

      test('should convert MAX_FIELD to U256 and back correctly', () => {
        const u256 = field255Simulator.toU256(MAX_FIELD);
        expect(fromU256(u256)).toBe(MAX_FIELD);
      });

      test('should fail when witness returns bad unpack result', () => {
        field255Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        expect(() => field255Simulator.toU256(1n)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });
  });

  describe('comparisons', () => {
    describe('eq', () => {
      test('should return true for equal small values', () => {
        expect(field255Simulator.eq(123n, 123n)).toBe(true);
      });

      test('should return true for zero equals zero', () => {
        expect(field255Simulator.eq(0n, 0n)).toBe(true);
      });

      test('should return true for MAX_FIELD equals MAX_FIELD', () => {
        expect(field255Simulator.eq(MAX_FIELD, MAX_FIELD)).toBe(true);
      });

      test('should return false for adjacent values', () => {
        expect(field255Simulator.eq(123n, 124n)).toBe(false);
      });

      test('should return false for zero and one', () => {
        expect(field255Simulator.eq(0n, 1n)).toBe(false);
        expect(field255Simulator.eq(1n, 0n)).toBe(false);
      });

      test('should correctly compare all boundary value combinations', () => {
        for (const a of BOUNDARY_VALUES) {
          for (const b of BOUNDARY_VALUES) {
            expect(field255Simulator.eq(a, b)).toBe(a === b);
          }
        }
      });
    });

    describe('lt', () => {
      test('should return true when first value is smaller', () => {
        expect(field255Simulator.lt(5n, 10n)).toBe(true);
      });

      test('should return false when first value is larger', () => {
        expect(field255Simulator.lt(10n, 5n)).toBe(false);
      });

      test('should return false for equal values', () => {
        expect(field255Simulator.lt(5n, 5n)).toBe(false);
      });

      test('should return true for zero compared to one', () => {
        expect(field255Simulator.lt(0n, 1n)).toBe(true);
      });

      test('should return false for zero compared to zero', () => {
        expect(field255Simulator.lt(0n, 0n)).toBe(false);
      });

      test('should return false for one compared to zero', () => {
        expect(field255Simulator.lt(1n, 0n)).toBe(false);
      });

      test('should return true for MAX_FIELD - 1 compared to MAX_FIELD', () => {
        expect(field255Simulator.lt(MAX_FIELD - 1n, MAX_FIELD)).toBe(true);
      });

      test('should return false for MAX_FIELD compared to MAX_FIELD', () => {
        expect(field255Simulator.lt(MAX_FIELD, MAX_FIELD)).toBe(false);
      });

      test('should return false for MAX_FIELD compared to MAX_FIELD - 1', () => {
        expect(field255Simulator.lt(MAX_FIELD, MAX_FIELD - 1n)).toBe(false);
      });

      test('should correctly compare all boundary value combinations', () => {
        for (const a of BOUNDARY_VALUES) {
          for (const b of BOUNDARY_VALUES) {
            expect(field255Simulator.lt(a, b)).toBe(a < b);
          }
        }
      });

      test('should be transitive: if a < b and b < c then a < c', () => {
        const a = 10n;
        const b = 100n;
        const c = 1000n;

        expect(field255Simulator.lt(a, b)).toBe(true);
        expect(field255Simulator.lt(b, c)).toBe(true);
        expect(field255Simulator.lt(a, c)).toBe(true);
      });

      test('should be inverse of gt: a < b iff b > a', () => {
        const pairs = [
          [0n, 1n],
          [1n, 2n],
          [100n, MAX_FIELD],
          [2n ** 64n, 2n ** 128n],
        ];
        for (const [a, b] of pairs) {
          expect(field255Simulator.lt(a, b)).toBe(field255Simulator.gt(b, a));
          expect(field255Simulator.gt(a, b)).toBe(field255Simulator.lt(b, a));
        }
      });

      test('should fail when witness returns bad unpack result', () => {
        field255Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        expect(() => field255Simulator.lt(1n, 2n)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('lte', () => {
      test('should return true when first value is smaller', () => {
        expect(field255Simulator.lte(5n, 10n)).toBe(true);
      });

      test('should return false when first value is larger', () => {
        expect(field255Simulator.lte(10n, 5n)).toBe(false);
      });

      test('should return true for equal values', () => {
        expect(field255Simulator.lte(5n, 5n)).toBe(true);
      });

      test('should return true for zero compared to one', () => {
        expect(field255Simulator.lte(0n, 1n)).toBe(true);
      });

      test('should return true for zero compared to zero', () => {
        expect(field255Simulator.lte(0n, 0n)).toBe(true);
      });

      test('should return false for one compared to zero', () => {
        expect(field255Simulator.lte(1n, 0n)).toBe(false);
      });

      test('should correctly compare all boundary value combinations', () => {
        for (const a of BOUNDARY_VALUES) {
          for (const b of BOUNDARY_VALUES) {
            expect(field255Simulator.lte(a, b)).toBe(a <= b);
          }
        }
      });

      test('should be inverse of gte: a <= b iff b >= a', () => {
        const pairs = [
          [0n, 0n],
          [0n, 1n],
          [1n, 1n],
          [100n, MAX_FIELD],
        ];
        for (const [a, b] of pairs) {
          expect(field255Simulator.lte(a, b)).toBe(field255Simulator.gte(b, a));
          expect(field255Simulator.gte(a, b)).toBe(field255Simulator.lte(b, a));
        }
      });

      test('should fail when witness returns bad unpack result', () => {
        field255Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        expect(() => field255Simulator.lte(1n, 2n)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('gt', () => {
      test('should return true when first value is larger', () => {
        expect(field255Simulator.gt(10n, 5n)).toBe(true);
      });

      test('should return false when first value is smaller', () => {
        expect(field255Simulator.gt(5n, 10n)).toBe(false);
      });

      test('should return false for equal values', () => {
        expect(field255Simulator.gt(5n, 5n)).toBe(false);
      });

      test('should return true for one compared to zero', () => {
        expect(field255Simulator.gt(1n, 0n)).toBe(true);
      });

      test('should return false for zero compared to zero', () => {
        expect(field255Simulator.gt(0n, 0n)).toBe(false);
      });

      test('should return false for zero compared to one', () => {
        expect(field255Simulator.gt(0n, 1n)).toBe(false);
      });

      test('should correctly compare all boundary value combinations', () => {
        for (const a of BOUNDARY_VALUES) {
          for (const b of BOUNDARY_VALUES) {
            expect(field255Simulator.gt(a, b)).toBe(a > b);
          }
        }
      });

      test('should fail when witness returns bad unpack result', () => {
        field255Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        expect(() => field255Simulator.gt(2n, 1n)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });

    describe('gte', () => {
      test('should return true when first value is larger', () => {
        expect(field255Simulator.gte(10n, 5n)).toBe(true);
      });

      test('should return false when first value is smaller', () => {
        expect(field255Simulator.gte(5n, 10n)).toBe(false);
      });

      test('should return true for equal values', () => {
        expect(field255Simulator.gte(5n, 5n)).toBe(true);
      });

      test('should return true for one compared to zero', () => {
        expect(field255Simulator.gte(1n, 0n)).toBe(true);
      });

      test('should return true for zero compared to zero', () => {
        expect(field255Simulator.gte(0n, 0n)).toBe(true);
      });

      test('should return false for zero compared to one', () => {
        expect(field255Simulator.gte(0n, 1n)).toBe(false);
      });

      test('should correctly compare all boundary value combinations', () => {
        for (const a of BOUNDARY_VALUES) {
          for (const b of BOUNDARY_VALUES) {
            expect(field255Simulator.gte(a, b)).toBe(a >= b);
          }
        }
      });

      test('should fail when witness returns bad unpack result', () => {
        field255Simulator.overrideWitness(
          'wit_unpackBytes',
          (context, _bytes) => [
            context.privateState,
            new Array<bigint>(32).fill(0n),
          ],
        );
        expect(() => field255Simulator.gte(2n, 1n)).toThrow(
          'failed assert: Pack: unpack verification failed',
        );
      });
    });
  });

  describe('utilities', () => {
    describe('isZero', () => {
      test('should return true for zero', () => {
        expect(field255Simulator.isZero(0n)).toBe(true);
      });

      test('should return false for one', () => {
        expect(field255Simulator.isZero(1n)).toBe(false);
      });

      test('should return false for arbitrary non-zero values', () => {
        expect(field255Simulator.isZero(123n)).toBe(false);
      });

      test('should return false for MAX_FIELD - 1', () => {
        expect(field255Simulator.isZero(MAX_FIELD - 1n)).toBe(false);
      });

      test('should return false for MAX_FIELD', () => {
        expect(field255Simulator.isZero(MAX_FIELD)).toBe(false);
      });
    });
  });
});
