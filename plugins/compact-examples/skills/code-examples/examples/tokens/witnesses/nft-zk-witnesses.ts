/**
 * @file NFT-ZK witness types and utilities (SECURE PATTERN — witness-derived identity)
 * @author Ricardo Rius
 * @license GPL-3.0
 *
 * Copyright (C) 2025 Ricardo Rius
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * DISCLAIMER: This software is provided "as is" without any warranty.
 * Use at your own risk. The author assumes no responsibility for any
 * damages or losses arising from the use of this software.
 */

import { Ledger } from "../managed/nft-zk/contract/index.js";
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

// Each browser/CLI instance carries THREE 32-byte secrets in private state:
//
//   * userSecretKey — the IDENTITY secret. ALL authorization in the contract —
//     per-user ownership AND the admin role — derives from this one secret via
//     domain-separated persistentHash INSIDE the ZK circuit
//     (deriveUserPublicKey / deriveAdminPublicKey). `ownPublicKey()` is never
//     consulted: it returns a prover-claimed value with no cryptographic binding
//     to the transaction signer. Whoever's deriveAdminPublicKey(userSecretKey)
//     was pinned into `contractAdmin` at deploy holds the admin role; everyone
//     else fails the equality assertion inside the proof.
//
//   * localSecret / sharedSecret — the PRIVACY secrets (unchanged from the
//     original design). They blind the on-chain ownership keys: the derived
//     UserPublicKey is hashed together with one of these secrets via
//     generateHashKey, so the ledger stores a Field hash rather than a raw key.
//     localSecret is used for self-queries, sharedSecret for peer queries.
//
// A caller can only act as the identity whose userSecretKey they hold.
export type NftZkPrivateState = {
  readonly userSecretKey: Uint8Array;
  readonly localSecret: Uint8Array;
  readonly sharedSecret: Uint8Array;
};

// Factory for the private state. All three secrets must be exactly 32 bytes.
export const createNftZkPrivateState = (
  userSecretKey: Uint8Array,
  localSecret: Uint8Array,
  sharedSecret: Uint8Array
): NftZkPrivateState => {
  for (const [name, value] of [
    ["userSecretKey", userSecretKey],
    ["localSecret", localSecret],
    ["sharedSecret", sharedSecret]
  ] as const) {
    if (!value || value.length !== 32) {
      throw new Error(`createNftZkPrivateState: ${name} must be 32 bytes`);
    }
  }
  return { userSecretKey, localSecret, sharedSecret };
};

export const witnesses = {
  // IDENTITY: the sole source of caller identity for authorization. The circuit
  // derives the caller's UserPublicKey / AdminPublicKey from this secret.
  getUserSecret: ({
    privateState
  }: WitnessContext<Ledger, NftZkPrivateState>): [
    NftZkPrivateState,
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
  },

  // PRIVACY: blinding secret for self-queries (hashed-key ownership lookups).
  getLocalSecret: ({
    privateState
  }: WitnessContext<Ledger, NftZkPrivateState>): [
    NftZkPrivateState,
    Uint8Array
  ] => {
    if (!privateState.localSecret || privateState.localSecret.length !== 32) {
      throw new Error("getLocalSecret: localSecret is missing or wrong length");
    }
    return [privateState, privateState.localSecret];
  },

  // PRIVACY: blinding secret for peer queries / approvals.
  getSharedSecret: ({
    privateState
  }: WitnessContext<Ledger, NftZkPrivateState>): [
    NftZkPrivateState,
    Uint8Array
  ] => {
    if (!privateState.sharedSecret || privateState.sharedSecret.length !== 32) {
      throw new Error(
        "getSharedSecret: sharedSecret is missing or wrong length"
      );
    }
    return [privateState, privateState.sharedSecret];
  }
};
