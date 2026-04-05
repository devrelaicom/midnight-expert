/**
 * @file witnesses.ts
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
  Witnesses
} from "./managed/kitties/contract/index.cjs";

import { WitnessContext } from "@midnight-ntwrk/compact-runtime";

// Declare console and TextDecoder for browser environment
// declare const console: {
//   log: (..._data: any[]) => void;
// };
// declare const TextDecoder: {
//   new (encoding?: string): {
//     decode(_input?: Uint8Array): string;
//   };
// };

export type Contract<T, W extends Witnesses<T> = Witnesses<T>> = ContractType<
  T,
  W
>;

// This is how we type an empty object.
export type KittiesPrivateState = {};

export function createKittiesPrivateState(): KittiesPrivateState {
  return {};
}

export const witnesses = {
  createRandomNumber: ({
    privateState
  }: WitnessContext<any, KittiesPrivateState>): [
    KittiesPrivateState,
    Uint8Array
  ] => {
    // Generate 32 random bytes using Math.random()
    const randomBytes = new Uint8Array(32);
    for (let i = 0; i < 32; i++) {
      randomBytes[i] = Math.floor(Math.random() * 256);
    }
    return [privateState, randomBytes];
  }
};
