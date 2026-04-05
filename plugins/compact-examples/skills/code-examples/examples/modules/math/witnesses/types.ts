/**
 * @description Represents a 128-bit unsigned integer as two 64-bit components.
 */
export type U128 = {
  low: bigint;
  high: bigint;
};

/**
 * @description Represents a 256-bit unsigned integer as two U128 components.
 */
export type U256 = {
  low: U128;
  high: U128;
};

/**
 * @description Division result for 64-bit operations.
 */
export type DivResultU64 = {
  quotient: bigint;
  remainder: bigint;
};

/**
 * @description Division result for 128-bit operations (U128 struct).
 */
export type DivResultU128 = {
  quotient: U128;
  remainder: U128;
};

/**
 * @description Division result for 256-bit operations (U256 struct).
 */
export type DivResultU256 = {
  quotient: U256;
  remainder: U256;
};

// Constants
export const UINT64_MASK = 0xffff_ffff_ffff_ffffn;
export const UINT128_MASK = (1n << 128n) - 1n;

// Conversion helpers
export const toU128 = (value: bigint): U128 => ({
  low: value & UINT64_MASK,
  high: value >> 64n,
});

export const toBigint = (value: U128): bigint =>
  (BigInt(value.high) << 64n) + BigInt(value.low);

export const toU256 = (value: bigint): U256 => {
  const low = value & UINT128_MASK;
  const high = value >> 128n;
  return {
    low: toU128(low),
    high: toU128(high),
  };
};
