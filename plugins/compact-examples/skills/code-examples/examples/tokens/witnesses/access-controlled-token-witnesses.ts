// SPDX-License-Identifier: MIT
// Witnesses for AccessControlledToken (SECURE PATTERN — witness-derived identity)
//
// Each browser/CLI instance carries a single 32-byte user secret in private
// state. ALL identity in the contract — per-user balances AND role membership —
// derives from this one secret via a domain-separated persistentHash INSIDE the
// ZK circuit (Identity_deriveUserPublicKey). `ownPublicKey()` is never consulted:
// it returns a prover-claimed value with no cryptographic binding to the
// transaction signer. At deploy the deployer's derived user key is granted
// DEFAULT_ADMIN_ROLE; only that secret holder can grant/revoke roles. A holder of
// MINTER_ROLE / BURNER_ROLE (under their derived key) can mint/burn; everyone
// else fails the role assertion inside the proof.

import { Ledger } from "../managed/AccessControlledToken/contract/index.js";
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

export type AccessControlledTokenPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Factory for the private state. The secret must be exactly 32 bytes.
export const createAccessControlledTokenPrivateState = (
  userSecretKey: Uint8Array
): AccessControlledTokenPrivateState => {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error(
      "createAccessControlledTokenPrivateState: userSecretKey must be 32 bytes"
    );
  }
  return { userSecretKey };
};

export const witnesses = {
  getUserSecret: ({
    privateState
  }: WitnessContext<Ledger, AccessControlledTokenPrivateState>): [
    AccessControlledTokenPrivateState,
    { bytes: Uint8Array }
  ] => {
    if (
      !privateState.userSecretKey ||
      privateState.userSecretKey.length !== 32
    ) {
      throw new Error(
        "getUserSecret: userSecretKey is missing or wrong length"
      );
    }
    return [privateState, { bytes: privateState.userSecretKey }];
  }
};
