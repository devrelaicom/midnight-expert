// SPDX-License-Identifier: MIT
// OpenZeppelin Compact Contracts v0.0.1-alpha.1 (token/witnesses/MultiTokenWitnesses.ts)
//
// SECURE PATTERN — witness-derived identity.
// The MultiToken module now derives caller identity from a single 32-byte
// private secret (`userSecretKey`) via the `getUserSecret` witness, instead of
// the bypassable `ownPublicKey()`. The private state therefore carries that
// secret; the test harness swaps it to simulate different callers.

// The single 32-byte identity secret. Switching the value held here is how a
// test "acts as" a different caller.
export type MultiTokenPrivateState = {
  readonly userSecretKey: Uint8Array;
};

// Default secret used when no caller is specified (all-zero is fine for a
// default; tests override it per-caller). Must be exactly 32 bytes.
export const MultiTokenPrivateState: MultiTokenPrivateState = {
  userSecretKey: new Uint8Array(32),
};

export const MultiTokenWitnesses = () => ({
  getUserSecret: (
    context: { privateState: MultiTokenPrivateState },
  ): [MultiTokenPrivateState, { bytes: Uint8Array }] => {
    const { privateState } = context;
    if (
      !privateState.userSecretKey ||
      privateState.userSecretKey.length !== 32
    ) {
      throw new Error("getUserSecret: userSecretKey is missing or wrong length");
    }
    return [privateState, { bytes: privateState.userSecretKey }];
  },
});
