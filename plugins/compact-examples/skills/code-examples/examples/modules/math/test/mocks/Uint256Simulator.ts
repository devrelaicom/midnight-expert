import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin/compact-tools-simulator';
import type { Witnesses } from '@src/artifacts/math/test/mocks/contracts/Uint256.mock/contract/index.js';
import {
  Contract,
  ledger,
  type U256,
} from '@src/artifacts/math/test/mocks/contracts/Uint256.mock/contract/index.js';
import { wit_uint64ToUnpackedBytes } from '@src/math/witnesses/wit_uint64ToUnpackedBytes.js';

export type Uint256PrivateState = Record<string, never>;

export const Uint256PrivateState = {
  generate: (): Uint256PrivateState => {
    return {};
  },
};

export const Uint256Witnesses = (): Witnesses<Uint256PrivateState> => ({
  wit_uint64ToUnpackedBytes(_context, value) {
    return [{}, wit_uint64ToUnpackedBytes(value)];
  },
});

/**
 * Base simulator for Uint256 mock contract
 */
const Uint256SimulatorBase = createSimulator<
  Uint256PrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof Uint256Witnesses>,
  Contract<Uint256PrivateState>,
  readonly []
>({
  contractFactory: (witnesses) => new Contract<Uint256PrivateState>(witnesses),
  defaultPrivateState: () => Uint256PrivateState.generate(),
  contractArgs: () => [],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => Uint256Witnesses(),
});

/**
 * @description A simulator implementation for testing Uint256 math operations.
 */
export class Uint256Simulator extends Uint256SimulatorBase {
  constructor(
    options: BaseSimulatorOptions<
      Uint256PrivateState,
      ReturnType<typeof Uint256Witnesses>
    > = {},
  ) {
    super([], options);
  }

  ////////////////////////////////////////////////////////////////
  // Constants
  ////////////////////////////////////////////////////////////////

  public ZERO_U256(): U256 {
    return this.circuits.impure.ZERO_U256();
  }

  public MAX_U256(): U256 {
    return this.circuits.impure.MAX_U256();
  }

  ////////////////////////////////////////////////////////////////
  // Conversions
  ////////////////////////////////////////////////////////////////

  public toUnpackedBytes(value: U256): bigint[] {
    return this.circuits.impure.toUnpackedBytes(value);
  }

  public toBytes(value: U256): Uint8Array {
    return this.circuits.impure.toBytes(value);
  }

  ////////////////////////////////////////////////////////////////
  // Comparisons
  ////////////////////////////////////////////////////////////////

  public eq(a: U256, b: U256): boolean {
    return this.circuits.impure.eq(a, b);
  }

  public lt(a: U256, b: U256): boolean {
    return this.circuits.impure.lt(a, b);
  }

  public lte(a: U256, b: U256): boolean {
    return this.circuits.impure.lte(a, b);
  }

  public gt(a: U256, b: U256): boolean {
    return this.circuits.impure.gt(a, b);
  }

  public gte(a: U256, b: U256): boolean {
    return this.circuits.impure.gte(a, b);
  }
}
