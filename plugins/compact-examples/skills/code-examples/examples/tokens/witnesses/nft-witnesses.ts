/**
 * @file NFT witness types and utilities (SECURE PATTERN — witness-derived identity)
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

import { Ledger } from "../managed/nft/contract/index.js";
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

// Each browser/CLI instance carries a single 32-byte user secret in private
// state. ALL identity in the contract — per-user ownership AND the admin role —
// derives from this one secret via domain-separated persistentHash INSIDE the
// ZK circuit (deriveUserPublicKey / deriveAdminPublicKey). `ownPublicKey()` is
// never consulted: it returns a prover-claimed value with no cryptographic
// binding to the transaction signer. Whoever's deriveAdminPublicKey(secret) was
// pinned into `contractAdmin` at deploy holds the admin role; everyone else
// fails the equality assertion inside the proof. A caller can only act as the
// identity whose secret they hold.
export type NftPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Factory for the private state. The secret must be exactly 32 bytes.
export const createNftPrivateState = (
  userSecretKey: Uint8Array
): NftPrivateState => {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error("createNftPrivateState: userSecretKey must be 32 bytes");
  }
  return { userSecretKey };
};

export const witnesses = {
  getUserSecret: ({
    privateState
  }: WitnessContext<Ledger, NftPrivateState>): [
    NftPrivateState,
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
