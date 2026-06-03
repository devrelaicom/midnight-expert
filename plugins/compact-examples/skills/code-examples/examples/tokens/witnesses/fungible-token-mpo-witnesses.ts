// SPDX-License-Identifier: MIT
// Witnesses for FungibleTokenMintablePausableOwnable (SECURE PATTERN — witness-derived identity)
//
// Each browser/CLI instance carries a single 32-byte user secret in private
// state. ALL identity in the contract — per-user balances/allowances AND the
// owner role — derives from this one secret via domain-separated persistentHash
// INSIDE the ZK circuit (Identity_deriveUserPublicKey / Identity_deriveAdminPublicKey).
// `ownPublicKey()` is never consulted: it returns a prover-claimed value with no
// cryptographic binding to the transaction signer. Whoever's
// deriveAdminPublicKey(secret) was pinned into Ownable's `_owner` at deploy holds
// the owner role; everyone else fails the equality assertion inside the proof. A
// caller can only act as the identity whose secret they hold.

import { Ledger } from "../managed/FungibleTokenMintablePausableOwnable/contract/index.js";
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

export type FungibleTokenMPOPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Factory for the private state. The secret must be exactly 32 bytes.
export const createFungibleTokenMPOPrivateState = (
  userSecretKey: Uint8Array
): FungibleTokenMPOPrivateState => {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error(
      "createFungibleTokenMPOPrivateState: userSecretKey must be 32 bytes"
    );
  }
  return { userSecretKey };
};

export const witnesses = {
  getUserSecret: ({
    privateState
  }: WitnessContext<Ledger, FungibleTokenMPOPrivateState>): [
    FungibleTokenMPOPrivateState,
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
