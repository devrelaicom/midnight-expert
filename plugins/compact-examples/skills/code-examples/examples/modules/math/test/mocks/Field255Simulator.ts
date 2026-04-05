import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin/compact-tools-simulator';
import type { Witnesses } from '@src/artifacts/math/test/mocks/contracts/Field255.mock/contract/index.js';
import {
  Contract,
  ledger,
  type U256,
} from '@src/artifacts/math/test/mocks/contracts/Field255.mock/contract/index.js';
import { wit_unpackBytes } from '@src/math/witnesses/wit_unpackBytes.js';

export type Field255PrivateState = Record<string, never>;

export const Field255PrivateState = {
  generate: (): Field255PrivateState => ({}),
};

export const Field255Witnesses = (): Witnesses<Field255PrivateState> => ({
  wit_unpackBytes(_context, bytes) {
    return [{}, wit_unpackBytes(bytes)];
  },
});

/**
 * Base simulator for Field255 mock contract
 */
const Field255SimulatorBase = createSimulator<
  Field255PrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof Field255Witnesses>,
  Contract<Field255PrivateState>,
  readonly []
>({
  contractFactory: (witnesses) => new Contract<Field255PrivateState>(witnesses),
  defaultPrivateState: () => Field255PrivateState.generate(),
  contractArgs: () => [],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => Field255Witnesses(),
});

/**
 * @description A simulator implementation for testing Field255 math operations.
 */
export class Field255Simulator extends Field255SimulatorBase {
  constructor(
    options: BaseSimulatorOptions<
      Field255PrivateState,
      ReturnType<typeof Field255Witnesses>
    > = {},
  ) {
    super([], options);
  }

  ////////////////////////////////////////////////////////////////
  // Constants
  ////////////////////////////////////////////////////////////////

  public MAX_FIELD(): bigint {
    return this.circuits.impure.MAX_FIELD();
  }

  ////////////////////////////////////////////////////////////////
  // Conversions
  ////////////////////////////////////////////////////////////////

  public toBytes(value: bigint): Uint8Array {
    return this.circuits.impure.toBytes(value);
  }

  public toU256(value: bigint): U256 {
    return this.circuits.impure.toU256(value);
  }

  ////////////////////////////////////////////////////////////////
  // Comparisons
  ////////////////////////////////////////////////////////////////

  public eq(a: bigint, b: bigint): boolean {
    return this.circuits.impure.eq(a, b);
  }

  public lt(a: bigint, b: bigint): boolean {
    return this.circuits.impure.lt(a, b);
  }

  public lte(a: bigint, b: bigint): boolean {
    return this.circuits.impure.lte(a, b);
  }

  public gt(a: bigint, b: bigint): boolean {
    return this.circuits.impure.gt(a, b);
  }

  public gte(a: bigint, b: bigint): boolean {
    return this.circuits.impure.gte(a, b);
  }

  ////////////////////////////////////////////////////////////////
  // Utilities
  ////////////////////////////////////////////////////////////////

  public isZero(a: bigint): boolean {
    return this.circuits.impure.isZero(a);
  }
}
