// SPDX-License-Identifier: MIT
//
// SECURE PATTERN — witness-derived identity.
// Ownable test simulator. Drives the compiled MockOwnable contract through
// @midnight-ntwrk/compact-runtime via the shared SecureSim harness. Each actor is
// a 32-byte secret; `as(secret)` authorizes the next call as that actor.
//
// Build the contract first:
//   compact compile modules/access/test/mocks/MockOwnable.compact \
//     modules/access/test/managed/MockOwnable

import {
  Contract as MockOwnable,
  ledger,
  pureCircuits,
  type Ledger,
  type Identity_AdminPublicKey,
} from "../managed/MockOwnable/contract/index.js";
import { SecureSim } from "../../../test-utils/secure-identity-sim.js";

export class OwnableSimulator extends SecureSim<MockOwnable, Ledger> {
  constructor(deployerSecret: Uint8Array, isInit: boolean) {
    super(MockOwnable, ledger, deployerSecret, isInit);
  }

  /** Off-chain derivation of an actor's admin key (matches the in-circuit hash). */
  static adminKey(secret: Uint8Array): Identity_AdminPublicKey {
    return pureCircuits.Identity_deriveAdminPublicKey({ bytes: secret });
  }

  owner(): Identity_AdminPublicKey {
    return this.read("owner");
  }

  transferOwnership(newOwner: Identity_AdminPublicKey): void {
    this.call("transferOwnership", newOwner);
  }

  renounceOwnership(): void {
    this.call("renounceOwnership");
  }

  assertOnlyOwner(): void {
    this.call("assertOnlyOwner");
  }

  _transferOwnership(newOwner: Identity_AdminPublicKey): void {
    this.call("_transferOwnership", newOwner);
  }
}
