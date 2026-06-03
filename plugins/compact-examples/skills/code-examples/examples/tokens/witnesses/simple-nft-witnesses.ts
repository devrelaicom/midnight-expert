/**
 * @file SimpleNonFungibleToken witness types and utilities
 *       (SECURE PATTERN — witness-derived identity)
 *
 * Each browser/CLI instance carries a single 32-byte user secret in private
 * state. ALL identity in the contract — per-user ownership AND the admin/minter
 * role — derives from this one secret via domain-separated persistentHash INSIDE
 * the ZK circuit (NonFungibleToken_deriveUserPublicKey /
 * NonFungibleToken_deriveAdminPublicKey). `ownPublicKey()` is never consulted: it
 * returns a prover-claimed value with no cryptographic binding to the transaction
 * signer. Whoever's deriveAdminPublicKey(secret) was pinned into `contractAdmin`
 * at deploy holds the admin role; everyone else fails the equality assertion
 * inside the proof. A caller can only act as the identity whose secret they hold.
 *
 * SPDX-License-Identifier: MIT
 */

import type { Ledger } from "../../managed/SimpleNonFungibleToken/contract/index.js";
import type { WitnessContext } from "@midnight-ntwrk/compact-runtime";

// The private state for the NFT contract: a single 32-byte secret.
export type SimpleNftPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Factory for the private state. The secret must be exactly 32 bytes.
export const createSimpleNftPrivateState = (
  userSecretKey: Uint8Array,
): SimpleNftPrivateState => {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error(
      "createSimpleNftPrivateState: userSecretKey must be 32 bytes",
    );
  }
  return { userSecretKey };
};

export const witnesses = {
  getUserSecret: ({
    privateState,
  }: WitnessContext<Ledger, SimpleNftPrivateState>): [
    SimpleNftPrivateState,
    { bytes: Uint8Array },
  ] => {
    if (
      !privateState.userSecretKey ||
      privateState.userSecretKey.length !== 32
    ) {
      throw new Error(
        "getUserSecret: userSecretKey is missing or wrong length",
      );
    }
    return [privateState, { bytes: privateState.userSecretKey }];
  },
};
