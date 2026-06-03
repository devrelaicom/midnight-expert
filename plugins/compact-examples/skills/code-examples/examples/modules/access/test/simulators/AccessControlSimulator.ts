// SPDX-License-Identifier: MIT
//
// SECURE PATTERN — witness-derived identity.
// AccessControl test simulator. Drives the compiled MockAccessControl contract
// through @midnight-ntwrk/compact-runtime via the shared SecureSim harness. Each
// actor is a 32-byte secret; `as(secret)` authorizes the next call as that actor.
// The deployer is granted DEFAULT_ADMIN_ROLE under their derived key at deploy.
//
// Build the contract first:
//   compact compile modules/access/test/mocks/MockAccessControl.compact \
//     modules/access/test/managed/MockAccessControl

import {
  Contract as MockAccessControl,
  ledger,
  pureCircuits,
  type Ledger,
  type Identity_UserPublicKey,
} from "../managed/MockAccessControl/contract/index.js";
import { SecureSim } from "../../../test-utils/secure-identity-sim.js";

export class AccessControlSimulator extends SecureSim<MockAccessControl, Ledger> {
  constructor(deployerSecret: Uint8Array) {
    super(MockAccessControl, ledger, deployerSecret);
  }

  /** Off-chain derivation of an actor's user key (matches the in-circuit hash). */
  static userKey(secret: Uint8Array): Identity_UserPublicKey {
    return pureCircuits.Identity_deriveUserPublicKey({ bytes: secret });
  }

  hasRole(roleId: Uint8Array, account: Identity_UserPublicKey): boolean {
    return this.read("hasRole", roleId, account);
  }

  assertOnlyRole(roleId: Uint8Array): void {
    this.call("assertOnlyRole", roleId);
  }

  getRoleAdmin(roleId: Uint8Array): Uint8Array {
    return this.read("getRoleAdmin", roleId);
  }

  grantRole(roleId: Uint8Array, account: Identity_UserPublicKey): void {
    this.call("grantRole", roleId, account);
  }

  revokeRole(roleId: Uint8Array, account: Identity_UserPublicKey): void {
    this.call("revokeRole", roleId, account);
  }

  renounceRole(roleId: Uint8Array): void {
    this.call("renounceRole", roleId);
  }

  _setRoleAdmin(roleId: Uint8Array, adminRole: Uint8Array): void {
    this.call("_setRoleAdmin", roleId, adminRole);
  }

  _grantRole(roleId: Uint8Array, account: Identity_UserPublicKey): boolean {
    return this.call("_grantRole", roleId, account);
  }

  _revokeRole(roleId: Uint8Array, account: Identity_UserPublicKey): boolean {
    return this.call("_revokeRole", roleId, account);
  }
}
