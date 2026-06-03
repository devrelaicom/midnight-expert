// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts v0.0.1-alpha.1 (access/witnesses/OwnableWitnesses.ts)
//
// SECURE PATTERN — witness-derived identity.
// The Ownable module itself declares NO witnesses: `assertOnlyOwner` and the
// ownership-transfer circuits take an already-derived `AdminPublicKey` as an
// explicit `caller` parameter. The single `getUserSecret()` witness lives in the
// TOP-LEVEL composing contract, which derives the caller from the secret, pins
// the owner at deploy, and passes the caller in. This module therefore has an
// empty private state and no witnesses.

export type OwnablePrivateState = Record<string, never>;
export const OwnablePrivateState: OwnablePrivateState = {};
export const OwnableWitnesses = () => ({});
