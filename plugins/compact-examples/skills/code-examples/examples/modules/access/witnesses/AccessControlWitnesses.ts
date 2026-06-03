// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts v0.0.1-alpha.1 (access/witnesses/AccessControlWitnesses.ts)
//
// SECURE PATTERN — witness-derived identity.
// The AccessControl module itself declares NO witnesses: `assertOnlyRole`,
// `grantRole`, `revokeRole`, and `renounceRole` take an already-derived
// `UserPublicKey` as an explicit `caller` parameter. The single
// `getUserSecret()` witness lives in the TOP-LEVEL composing contract (e.g.
// AccessControlledToken), which derives the caller from the secret and passes it
// in. This module therefore has an empty private state and no witnesses.

export type AccessControlPrivateState = Record<string, never>;
export const AccessControlPrivateState: AccessControlPrivateState = {};
export const AccessControlWitnesses = () => ({});
