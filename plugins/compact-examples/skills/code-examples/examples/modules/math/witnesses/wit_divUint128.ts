import { type DivResultU128, toU128 } from './types.js';

/**
 * @description Computes the quotient and remainder of dividing two Uint<128> values (bigint).
 * @param a - The dividend as bigint.
 * @param b - The divisor as bigint.
 * @returns An object containing the quotient and remainder as U128 structs.
 *
 * @remarks
 * This witness function is shared between Uint128 and Uint256 contracts.
 */
export const wit_divUint128 = (a: bigint, b: bigint): DivResultU128 => {
  const quotient = a / b;
  const remainder = a - quotient * b;
  return {
    quotient: toU128(quotient),
    remainder: toU128(remainder),
  };
};
