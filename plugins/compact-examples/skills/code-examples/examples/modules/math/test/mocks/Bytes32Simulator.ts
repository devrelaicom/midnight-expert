import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin/compact-tools-simulator';
import type { Witnesses } from '@src/artifacts/math/test/mocks/contracts/Bytes32.mock/contract/index.js';
import {
  Contract,
  ledger,
  type U256,
} from '@src/artifacts/math/test/mocks/contracts/Bytes32.mock/contract/index.js';
import { wit_unpackBytes } from '@src/math/witnesses/wit_unpackBytes.js';

export type Bytes32PrivateState = Record<string, never>;

export const Bytes32Witnesses = (): Witnesses<Bytes32PrivateState> => ({
  wit_unpackBytes(_context, bytes) {
    return [{}, wit_unpackBytes(bytes)];
  },
});

/**
 * Base simulator for Bytes32 mock contract
 */
const Bytes32SimulatorBase = createSimulator<
  Bytes32PrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof Bytes32Witnesses>,
  Contract<Bytes32PrivateState>,
  readonly []
>({
  contractFactory: (witnesses) => new Contract<Bytes32PrivateState>(witnesses),
  defaultPrivateState: () => ({}),
  contractArgs: () => [],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => Bytes32Witnesses(),
});

/**
 * @description A simulator implementation for testing Bytes32 conversion operations.
 */
export class Bytes32Simulator extends Bytes32SimulatorBase {
  constructor(
    options: BaseSimulatorOptions<
      Bytes32PrivateState,
      ReturnType<typeof Bytes32Witnesses>
    > = {},
  ) {
    super([], options);
  }

  ////////////////////////////////////////////////////////////////
  // Conversions
  ////////////////////////////////////////////////////////////////

  public pack(vec: bigint[]): Uint8Array {
    return this.circuits.impure.pack(vec);
  }

  public unpack(bytes: Uint8Array): bigint[] {
    return this.circuits.impure.unpack(bytes);
  }

  public vectorToU256(vec: bigint[]): U256 {
    return this.circuits.impure.vectorToU256(vec);
  }

  public bytesToU256(bytes: Uint8Array): U256 {
    return this.circuits.impure.bytesToU256(bytes);
  }

  ////////////////////////////////////////////////////////////////
  // Comparisons
  ////////////////////////////////////////////////////////////////

  public eq(a: Uint8Array, b: Uint8Array): boolean {
    return this.circuits.impure.eq(a, b);
  }

  public lt(a: Uint8Array, b: Uint8Array): boolean {
    return this.circuits.impure.lt(a, b);
  }

  public lte(a: Uint8Array, b: Uint8Array): boolean {
    return this.circuits.impure.lte(a, b);
  }

  public gt(a: Uint8Array, b: Uint8Array): boolean {
    return this.circuits.impure.gt(a, b);
  }

  public gte(a: Uint8Array, b: Uint8Array): boolean {
    return this.circuits.impure.gte(a, b);
  }

  ////////////////////////////////////////////////////////////////
  // Utilities
  ////////////////////////////////////////////////////////////////

  public isZero(a: Uint8Array): boolean {
    return this.circuits.impure.isZero(a);
  }
}
