// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts (token/test/simulators/MultiTokenSimulator.ts)
//
// SECURE PATTERN — witness-derived identity.
//
// Ported to the witness-derived identity API. Accounts are now
// `UserPublicKey` ({ bytes: Uint8Array }) derived from a 32-byte secret rather
// than `Either<ZswapCoinPublicKey, ContractAddress>`. "Acting as" a caller
// (`.as(secret)`) swaps the private-state `userSecretKey`, which is the SOLE
// source of caller identity — `ownPublicKey()` is no longer used for auth.
//
// NOTE: this file targets the upstream `@openzeppelin-compact/contracts-simulator`
// harness, which is not vendored into this examples tree. The runnable
// equivalent lives in `../MultiToken.test.ts`, which drives the compiled
// MockMultiToken directly via `@midnight-ntwrk/compact-runtime` (no extra
// packages required).

import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin-compact/contracts-simulator';
import {
  ledger,
  type Maybe,
  Contract as MockMultiToken,
  type MultiToken_UserPublicKey,
} from '../../../../artifacts/MockMultiToken/contract/index.js';
import {
  MultiTokenPrivateState,
  MultiTokenWitnesses,
} from '../../witnesses/MultiTokenWitnesses.js';

/**
 * Type constructor args
 */
type MultiTokenArgs = readonly [_uri: Maybe<string>];

const MultiTokenSimulatorBase = createSimulator<
  MultiTokenPrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof MultiTokenWitnesses>,
  MockMultiToken<MultiTokenPrivateState>,
  MultiTokenArgs
>({
  contractFactory: (witnesses) =>
    new MockMultiToken<MultiTokenPrivateState>(witnesses),
  defaultPrivateState: () => MultiTokenPrivateState,
  contractArgs: (_uri) => [_uri],
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => MultiTokenWitnesses(),
});

/**
 * MultiToken Simulator
 */
export class MultiTokenSimulator extends MultiTokenSimulatorBase {
  constructor(
    _uri: Maybe<string>,
    options: BaseSimulatorOptions<
      MultiTokenPrivateState,
      ReturnType<typeof MultiTokenWitnesses>
    > = {},
  ) {
    super([_uri], options);
  }

  /**
   * @description Switch the simulated caller by setting the private-state
   * identity secret. Returns `this` for chaining (mirrors the upstream `.as()`).
   * @param secret The 32-byte identity secret of the caller to act as.
   */
  public asSecret(secret: Uint8Array): this {
    this.setPrivateState({ userSecretKey: secret });
    return this;
  }

  /**
   * @description Initializes the contract. This is already executed in the
   * simulator constructor; this method lets tests assert it cannot be called again.
   */
  public initialize(uri: string) {
    this.circuits.impure.initialize(uri);
  }

  /** @description Returns the token URI. */
  public uri(id: bigint): string {
    return this.circuits.impure.uri(id);
  }

  /** @description Returns the amount of `id` tokens owned by `account`. */
  public balanceOf(account: MultiToken_UserPublicKey, id: bigint): bigint {
    return this.circuits.impure.balanceOf(account, id);
  }

  /** @description Queries if `operator` is an authorized operator for `account`. */
  public isApprovedForAll(
    account: MultiToken_UserPublicKey,
    operator: MultiToken_UserPublicKey,
  ): boolean {
    return this.circuits.impure.isApprovedForAll(account, operator);
  }

  /**
   * @description Enables or disables approval for `operator` to manage all of
   * the CALLER's assets. The caller is derived from the witness secret.
   */
  public setApprovalForAll(
    operator: MultiToken_UserPublicKey,
    approved: boolean,
  ) {
    this.circuits.impure.setApprovalForAll(operator, approved);
  }

  /**
   * @description Transfers `value` of token `id` from the CALLER to `to`.
   */
  public transfer(to: MultiToken_UserPublicKey, id: bigint, value: bigint) {
    this.circuits.impure.transfer(to, id, value);
  }

  /**
   * @description Transfers `value` of token `id` from `fromAddress` to `to`.
   * The caller (derived from the witness secret) must be `fromAddress` or an
   * approved operator of it.
   */
  public transferFromAuthorized(
    fromAddress: MultiToken_UserPublicKey,
    to: MultiToken_UserPublicKey,
    id: bigint,
    value: bigint,
  ) {
    this.circuits.impure.transferFromAuthorized(fromAddress, to, id, value);
  }

  // ---- test-only unauthenticated building blocks ----------------------------

  /** @description Unauthenticated transfer (test setup only). */
  public _transfer(
    fromAddress: MultiToken_UserPublicKey,
    to: MultiToken_UserPublicKey,
    id: bigint,
    value: bigint,
  ) {
    this.circuits.impure._transfer(fromAddress, to, id, value);
  }

  /** @description Sets a new URI for all token types. */
  public _setURI(newURI: string) {
    this.circuits.impure._setURI(newURI);
  }

  /** @description Unauthenticated mint (test setup only). */
  public _mint(to: MultiToken_UserPublicKey, id: bigint, value: bigint) {
    this.circuits.impure._mint(to, id, value);
  }

  /** @description Unauthenticated burn (test setup only). */
  public _burn(fromAddress: MultiToken_UserPublicKey, id: bigint, value: bigint) {
    this.circuits.impure._burn(fromAddress, id, value);
  }

  /** @description Unauthenticated operator approval (test setup only). */
  public _setApprovalForAll(
    owner: MultiToken_UserPublicKey,
    operator: MultiToken_UserPublicKey,
    approved: boolean,
  ) {
    this.circuits.impure._setApprovalForAll(owner, operator, approved);
  }
}
