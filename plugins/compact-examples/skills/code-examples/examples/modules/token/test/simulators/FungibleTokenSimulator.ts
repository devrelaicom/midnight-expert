// SPDX-License-Identifier: MIT
//
// SECURE PATTERN — witness-derived identity.
// FungibleToken test simulator. Drives the compiled MockFungibleToken contract
// through @midnight-ntwrk/compact-runtime via the shared SecureSim harness. Each
// actor is a 32-byte secret; `as(secret)` authorizes the next call as that actor
// (used as the owner/spender for transfer/approve/transferFrom).
//
// Build the contract first:
//   compact compile modules/token/test/mocks/MockFungibleToken.compact \
//     modules/token/test/managed/MockFungibleToken

import {
  Contract as MockFungibleToken,
  ledger,
  pureCircuits,
  type Ledger,
  type Identity_UserPublicKey,
} from "../managed/MockFungibleToken/contract/index.js";
import { SecureSim } from "../../../test-utils/secure-identity-sim.js";

export class FungibleTokenSimulator extends SecureSim<MockFungibleToken, Ledger> {
  constructor(
    deployerSecret: Uint8Array,
    name: string,
    symbol: string,
    decimals: bigint,
    init: boolean
  ) {
    super(MockFungibleToken, ledger, deployerSecret, name, symbol, decimals, init);
  }

  /** Off-chain derivation of an actor's user key (matches the in-circuit hash). */
  static userKey(secret: Uint8Array): Identity_UserPublicKey {
    return pureCircuits.Identity_deriveUserPublicKey({ bytes: secret });
  }

  name(): string {
    return this.read("name");
  }
  symbol(): string {
    return this.read("symbol");
  }
  decimals(): bigint {
    return this.read("decimals");
  }
  totalSupply(): bigint {
    return this.read("totalSupply");
  }
  balanceOf(account: Identity_UserPublicKey): bigint {
    return this.read("balanceOf", account);
  }
  allowance(
    owner: Identity_UserPublicKey,
    spender: Identity_UserPublicKey
  ): bigint {
    return this.read("allowance", owner, spender);
  }

  transfer(to: Identity_UserPublicKey, value: bigint): boolean {
    return this.call("transfer", to, value);
  }
  transferFrom(
    fromAccount: Identity_UserPublicKey,
    to: Identity_UserPublicKey,
    value: bigint
  ): boolean {
    return this.call("transferFrom", fromAccount, to, value);
  }
  approve(spender: Identity_UserPublicKey, value: bigint): boolean {
    return this.call("approve", spender, value);
  }

  // Internal circuits (no caller gate).
  _approve(
    owner: Identity_UserPublicKey,
    spender: Identity_UserPublicKey,
    value: bigint
  ): void {
    this.call("_approve", owner, spender, value);
  }
  _transfer(
    fromAccount: Identity_UserPublicKey,
    to: Identity_UserPublicKey,
    value: bigint
  ): void {
    this.call("_transfer", fromAccount, to, value);
  }
  _mint(account: Identity_UserPublicKey, value: bigint): void {
    this.call("_mint", account, value);
  }
  _burn(account: Identity_UserPublicKey, value: bigint): void {
    this.call("_burn", account, value);
  }
  _spendAllowance(
    owner: Identity_UserPublicKey,
    spender: Identity_UserPublicKey,
    value: bigint
  ): void {
    this.call("_spendAllowance", owner, spender, value);
  }
}
