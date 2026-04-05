/**
 * @file NFT-ZK witness types and utilities
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
  Ledger,
  Witnesses
} from "../../../src/managed/nft-zk/contract/index.cjs";
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

export type Contract<T, W extends Witnesses<T> = Witnesses<T>> = ContractType<
  T,
  W
>;

export type NftZkPrivateState = {
  readonly local_secret: Uint8Array;
  readonly shared_secret: Uint8Array;
};

export function createNftZkPrivateState(
  local_secret: Uint8Array,
  shared_secret: Uint8Array
): NftZkPrivateState {
  return {
    local_secret,
    shared_secret
  };
}

export const witnesses = {
  getLocalSecret: ({
    privateState
  }: WitnessContext<Ledger, NftZkPrivateState>): [
    NftZkPrivateState,
    Uint8Array
  ] => {
    if (privateState.local_secret) {
      return [privateState, privateState.local_secret];
    } else {
      throw new Error("No local secret found.");
    }
  },
  getSharedSecret: ({
    privateState
  }: WitnessContext<Ledger, NftZkPrivateState>): [
    NftZkPrivateState,
    Uint8Array
  ] => {
    if (privateState.local_secret) {
      return [privateState, privateState.shared_secret];
    } else {
      throw new Error("No shared secret found.");
    }
  }
};
