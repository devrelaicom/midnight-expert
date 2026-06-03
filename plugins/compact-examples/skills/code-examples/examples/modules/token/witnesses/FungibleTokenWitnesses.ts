// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts v0.0.1-alpha.1 (token/witnesses/FungibleTokenWitnesses.ts)
//
// SECURE PATTERN — witness-derived identity.
// The FungibleToken module itself declares NO witnesses: its identity-sensitive
// circuits take an already-derived `UserPublicKey` as an explicit `caller`
// parameter. The single `getUserSecret()` witness lives in the TOP-LEVEL
// composing contract (e.g. FungibleTokenMintablePausableOwnable,
// AccessControlledToken), which derives the caller from the secret and passes
// it in. This module therefore has an empty private state and no witnesses.

export type FungibleTokenPrivateState = Record<string, never>;
export const FungibleTokenPrivateState: FungibleTokenPrivateState = {};
export const FungibleTokenWitnesses = () => ({});
