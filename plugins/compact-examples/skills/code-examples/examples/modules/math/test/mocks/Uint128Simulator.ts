import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin/compact-tools-simulator';
import type {
  DivResultU128,
  U128,
  U256,
  Witnesses,
} from '@src/artifacts/math/test/mocks/contracts/Uint128.mock/contract/index.js';
import {
  Contract,
  ledger,
} from '@src/artifacts/math/test/mocks/contracts/Uint128.mock/contract/index.js';
import { wit_divU128 } from '@src/math/witnesses/wit_divU128.js';
import { wit_divUint128 } from '@src/math/witnesses/wit_divUint128.js';
import { wit_sqrtU128 } from '@src/math/witnesses/wit_sqrtU128.js';

/**
 * @description Represents the private state of the Uint128 module.
 * @remarks No persistent state is needed beyond what's computed on-demand, so this is minimal.
 */
export type Uint128PrivateState = Record<string, never>;

/**
 * @description Utility object for managing the private state of the Uint128 module.
 */
export const Uint128PrivateState = {
  /**
   * @description Generates a new private state.
   * @returns A fresh Uint128PrivateState instance (empty for now).
   */
  generate: (): Uint128PrivateState => {
    return {};
  },
};

/**
 * @description Factory function creating witness implementations for Uint128 module operations.
 */
export const Uint128Witnesses = (): Witnesses<Uint128PrivateState> => ({
  wit_sqrtU128(_context, radicand) {
    return [{}, wit_sqrtU128(radicand)];
  },

  wit_divU128(_context, a, b) {
    return [{}, wit_divU128(a, b)];
  },

  wit_divUint128(_context, a, b) {
    return [{}, wit_divUint128(a, b)];
  },
});

/**
 * Base simulator for Uint128 mock contract
 */
const Uint128SimulatorBase = createSimulator<
  Uint128PrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof Uint128Witnesses>,
  Contract<Uint128PrivateState>,
  readonly []
>({
  contractFactory: (witnesses) => new Contract<Uint128PrivateState>(witnesses),
  defaultPrivateState: () => Uint128PrivateState.generate(),
  contractArgs: () => [],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => Uint128Witnesses(),
});

/**
 * @description A simulator implementation for testing Uint128 math operations.
 */
export class Uint128Simulator extends Uint128SimulatorBase {
  constructor(
    options: BaseSimulatorOptions<
      Uint128PrivateState,
      ReturnType<typeof Uint128Witnesses>
    > = {},
  ) {
    super([], options);
  }

  ////////////////////////////////////////////////////////////////
  // Constants
  ////////////////////////////////////////////////////////////////

  public MODULUS(): bigint {
    return this.circuits.impure.MODULUS();
  }

  public ZERO_U128(): U128 {
    return this.circuits.impure.ZERO_U128();
  }

  public MAX_U128(): U128 {
    return this.circuits.impure.MAX_U128();
  }

  public MAX_UINT128(): bigint {
    return this.circuits.impure.MAX_UINT128();
  }

  ////////////////////////////////////////////////////////////////
  // Conversions
  ////////////////////////////////////////////////////////////////

  public toU128(value: bigint): U128 {
    return this.circuits.impure.toU128(value);
  }

  public toUint128(value: U128): bigint {
    return this.circuits.impure.toUint128(value);
  }

  ////////////////////////////////////////////////////////////////
  // Comparisons
  ////////////////////////////////////////////////////////////////

  public eq(a: bigint, b: bigint): boolean {
    return this.circuits.impure.eq(a, b);
  }

  public eqU128(a: U128, b: U128): boolean {
    return this.circuits.impure.eqU128(a, b);
  }

  public lt(a: bigint, b: bigint): boolean {
    return this.circuits.impure.lt(a, b);
  }

  public lte(a: bigint, b: bigint): boolean {
    return this.circuits.impure.lte(a, b);
  }

  public ltU128(a: U128, b: U128): boolean {
    return this.circuits.impure.ltU128(a, b);
  }

  public lteU128(a: U128, b: U128): boolean {
    return this.circuits.impure.lteU128(a, b);
  }

  public gt(a: bigint, b: bigint): boolean {
    return this.circuits.impure.gt(a, b);
  }

  public gtU128(a: U128, b: U128): boolean {
    return this.circuits.impure.gtU128(a, b);
  }

  public gte(a: bigint, b: bigint): boolean {
    return this.circuits.impure.gte(a, b);
  }

  public gteU128(a: U128, b: U128): boolean {
    return this.circuits.impure.gteU128(a, b);
  }

  ////////////////////////////////////////////////////////////////
  // Arithmetic
  ////////////////////////////////////////////////////////////////

  public add(a: bigint, b: bigint): U256 {
    return this.circuits.impure.add(a, b);
  }

  public addU128(a: U128, b: U128): U256 {
    return this.circuits.impure.addU128(a, b);
  }

  public addChecked(a: bigint, b: bigint): bigint {
    return this.circuits.impure.addChecked(a, b);
  }

  public addCheckedU128(a: U128, b: U128): bigint {
    return this.circuits.impure.addCheckedU128(a, b);
  }

  public sub(a: bigint, b: bigint): bigint {
    return this.circuits.impure.sub(a, b);
  }

  public subU128(a: U128, b: U128): U128 {
    return this.circuits.impure.subU128(a, b);
  }

  public mul(a: bigint, b: bigint): U256 {
    return this.circuits.impure.mul(a, b);
  }

  public mulU128(a: U128, b: U128): U256 {
    return this.circuits.impure.mulU128(a, b);
  }

  public mulChecked(a: bigint, b: bigint): bigint {
    return this.circuits.impure.mulChecked(a, b);
  }

  public mulCheckedU128(a: U128, b: U128): bigint {
    return this.circuits.impure.mulCheckedU128(a, b);
  }

  ////////////////////////////////////////////////////////////////
  // Division
  ////////////////////////////////////////////////////////////////

  public div(a: bigint, b: bigint): bigint {
    return this.circuits.impure.div(a, b);
  }

  public divU128(a: U128, b: U128): U128 {
    return this.circuits.impure.divU128(a, b);
  }

  public rem(a: bigint, b: bigint): bigint {
    return this.circuits.impure.rem(a, b);
  }

  public remU128(a: U128, b: U128): U128 {
    return this.circuits.impure.remU128(a, b);
  }

  public divRem(a: bigint, b: bigint): DivResultU128 {
    return this.circuits.impure.divRem(a, b);
  }

  public divRemU128(a: U128, b: U128): DivResultU128 {
    return this.circuits.impure.divRemU128(a, b);
  }

  ////////////////////////////////////////////////////////////////
  // Square Root
  ////////////////////////////////////////////////////////////////

  public sqrt(radicand: bigint): bigint {
    return this.circuits.impure.sqrt(radicand);
  }

  public sqrtU128(radicand: U128): bigint {
    return this.circuits.impure.sqrtU128(radicand);
  }

  ////////////////////////////////////////////////////////////////
  // Utilities
  ////////////////////////////////////////////////////////////////

  public isZero(value: bigint): boolean {
    return this.circuits.impure.isZero(value);
  }

  public isZeroU128(value: U128): boolean {
    return this.circuits.impure.isZeroU128(value);
  }

  public isMultiple(value: bigint, divisor: bigint): boolean {
    return this.circuits.impure.isMultiple(value, divisor);
  }

  public isMultipleU128(value: U128, divisor: U128): boolean {
    return this.circuits.impure.isMultipleU128(value, divisor);
  }

  public min(a: bigint, b: bigint): bigint {
    return this.circuits.impure.min(a, b);
  }

  public minU128(a: U128, b: U128): U128 {
    return this.circuits.impure.minU128(a, b);
  }

  public max(a: bigint, b: bigint): bigint {
    return this.circuits.impure.max(a, b);
  }

  public maxU128(a: U128, b: U128): U128 {
    return this.circuits.impure.maxU128(a, b);
  }
}
