// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts v0.0.1-alpha.1 (token/witnesses/NonFungibleToken.ts)
//
// SECURE PATTERN — witness-derived identity.
//
// The contract derives every caller identity from a single 32-byte secret held
// in private state (see `getUserSecret` / `deriveUserPublicKey` /
// `deriveAdminPublicKey`). `ownPublicKey()` is never consulted. Tests select the
// acting caller by swapping `userSecretKey` (the analogue of the simulator's
// `as(...)` caller switch), since identity now comes from the secret rather than
// the prover-supplied coin public key.

import type { Ledger } from '../test/artifacts/MockNonFungibleToken/contract/index.js';
import type { WitnessContext } from '@midnight-ntwrk/compact-runtime';

/** Private state: a single 32-byte user secret. */
export type NonFungibleTokenPrivateState = {
  readonly userSecretKey: Uint8Array;
};

/** Factory for the private state. The secret must be exactly 32 bytes. */
export const createNonFungibleTokenPrivateState = (
  userSecretKey: Uint8Array,
): NonFungibleTokenPrivateState => {
  if (!userSecretKey || userSecretKey.length !== 32) {
    throw new Error(
      'createNonFungibleTokenPrivateState: userSecretKey must be 32 bytes',
    );
  }
  return { userSecretKey };
};

/**
 * Default private state. A fixed, non-zero 32-byte secret so the simulator has a
 * deterministic deployer/caller. Tests override per-caller via {@link
 * createNonFungibleTokenPrivateState}.
 */
export const NonFungibleTokenPrivateState: NonFungibleTokenPrivateState = {
  userSecretKey: new Uint8Array(32).fill(1),
};

export const NonFungibleTokenWitnesses = () => ({
  getUserSecret: ({
    privateState,
  }: WitnessContext<Ledger, NonFungibleTokenPrivateState>): [
    NonFungibleTokenPrivateState,
    { bytes: Uint8Array },
  ] => {
    if (
      !privateState.userSecretKey ||
      privateState.userSecretKey.length !== 32
    ) {
      throw new Error('getUserSecret: userSecretKey is missing or wrong length');
    }
    return [privateState, { bytes: privateState.userSecretKey }];
  },
});
