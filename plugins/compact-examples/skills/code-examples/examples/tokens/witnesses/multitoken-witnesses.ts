// SPDX-License-Identifier: MIT
// MultiToken witness types and utilities (SECURE PATTERN — witness-derived identity)

import { Ledger } from "../managed/multitoken/contract/index.js";
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

// Each browser/CLI instance carries a single 32-byte user secret in private
// state. ALL identity in the contract — per-account balances/operator approvals
// AND the admin role — derives from this one secret via domain-separated
// persistentHash INSIDE the ZK circuit (deriveUserPublicKey /
// deriveAdminPublicKey). `ownPublicKey()` is never consulted: it returns a
// prover-claimed value with no cryptographic binding to the transaction signer.
// Whoever's deriveAdminPublicKey(secret) was pinned into `contractAdmin` at
// deploy holds the admin role; everyone else fails the equality assertion inside
// the proof. A caller can only act as the identity whose secret they hold.
export type MultiTokenPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Factory for the private state. The secret must be exactly 32 bytes.
export const createMultiTokenPrivateState = (
  userSecretKey: Uint8Array
): MultiTokenPrivateState => {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error("createMultiTokenPrivateState: userSecretKey must be 32 bytes");
  }
  return { userSecretKey };
};

export const witnesses = {
  // IDENTITY: the sole source of caller identity for authorization. The circuit
  // derives the caller's UserPublicKey / AdminPublicKey from this secret.
  getUserSecret: ({
    privateState
  }: WitnessContext<Ledger, MultiTokenPrivateState>): [
    MultiTokenPrivateState,
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
