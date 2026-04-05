import { type DivResultU128, toBigint, toU128, type U128 } from './types.js';

/**
 * @description Computes the quotient and remainder of dividing two U128 values.
 * @param a - The dividend as U128.
 * @param b - The divisor as U128.
 * @returns An object containing the quotient and remainder as U128 structs.
 */
export const wit_divU128 = (a: U128, b: U128): DivResultU128 => {
  const aValue = toBigint(a);
  const bValue = toBigint(b);
  const quotient = aValue / bValue;
  const remainder = aValue - quotient * bValue;
  return {
    quotient: toU128(quotient),
    remainder: toU128(remainder),
  };
};
