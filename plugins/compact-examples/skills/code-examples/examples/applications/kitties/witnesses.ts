/**
 * @file Kitties witness types and utilities (SECURE PATTERN — witness-derived identity)
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

import {
  Contract as ContractType,
  Witnesses,
  Ledger
} from "./managed/kitties/contract/index.cjs";

import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

export type Contract<T, W extends Witnesses<T> = Witnesses<T>> = ContractType<
  T,
  W
>;

// Each browser/CLI instance carries a single 32-byte user secret in private
// state. ALL caller identity in the contract — kitty ownership, buy-offer
// authorship, sale approval, and breeding authorization — derives from this one
// secret via a domain-separated persistentHash INSIDE the ZK circuit
// (deriveUserPublicKey / deriveAdminPublicKey). `ownPublicKey()` is never
// consulted: it returns a prover-claimed value with no cryptographic binding to
// the transaction signer. A caller can only act as the kitty owner whose secret
// they hold; supplying someone else's public key as an argument does not let
// them pass the in-circuit ownership assertion.
export type KittiesPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Factory for the private state. The secret must be exactly 32 bytes.
export function createKittiesPrivateState(
  userSecretKey: Uint8Array
): KittiesPrivateState {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error("createKittiesPrivateState: userSecretKey must be 32 bytes");
  }
  return { userSecretKey };
}

export const witnesses = {
  // Supplies the prover's 32-byte secret. The circuit derives the caller's
  // public key from this value; it never leaves the prover's machine.
  getUserSecret: ({
    privateState
  }: WitnessContext<Ledger, KittiesPrivateState>): [
    KittiesPrivateState,
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

  // Supplies 32 bytes of randomness for DNA generation and breeding. This is an
  // untrusted witness value; the contract treats it as a seed, not a secret.
  createRandomNumber: ({
    privateState
  }: WitnessContext<Ledger, KittiesPrivateState>): [
    KittiesPrivateState,
    Uint8Array
  ] => {
    const randomBytes = new Uint8Array(32);
    for (let i = 0; i < 32; i++) {
      randomBytes[i] = Math.floor(Math.random() * 256);
    }
    return [privateState, randomBytes];
  }
};
