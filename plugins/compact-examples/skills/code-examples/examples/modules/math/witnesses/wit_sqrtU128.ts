import { sqrtBigint } from '../utils/sqrtBigint.js';
import { toBigint, type U128 } from './types.js';

/**
 * @description Computes the square root of a 128-bit unsigned integer (U128 struct).
 * @param radicand - The U128 value to compute the square root of.
 * @returns The floor of the square root as a 64-bit result.
 */
export const wit_sqrtU128 = (radicand: U128): bigint => {
  const radicandBigInt = toBigint(radicand);
  return sqrtBigint(radicandBigInt);
};
