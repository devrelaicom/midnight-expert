import { getRandomValues } from 'node:crypto';
import type { WitnessContext } from '@midnight-ntwrk/compact-runtime';
import type { Ledger } from '../../../artifacts/MockZOwnablePK/contract/index.js';

/**
 * @description SECURE PATTERN — witness-derived identity.
 *
 * Each instance carries a single 32-byte secret in private state. ALL identity
 * in the contract — the owner's derived public key AND the unlinkability nonce —
 * derives from this one secret via domain-separated `persistentHash` INSIDE the
 * ZK circuit (`_deriveOwnerPublicKey` / `_deriveOwnerNonce`). `ownPublicKey()`
 * is never consulted: it returns a prover-claimed value with no cryptographic
 * binding to the transaction signer. Whoever's derived owner key was committed
 * at deploy/transfer holds the owner role; everyone else fails the equality
 * assertion inside the proof.
 */

/**
 * @description Interface defining the witness methods for ZOwnablePK operations.
 * @template P - The private state type.
 */
export interface IZOwnablePKWitnesses<P> {
  /**
   * Retrieves the single 32-byte user secret from the private state.
   * @param context - The witness context containing the private state.
   * @returns A tuple of the private state and the secret as `{ bytes: Uint8Array }`.
   */
  getUserSecret(context: WitnessContext<Ledger, P>): [P, { bytes: Uint8Array }];
}

/**
 * @description Represents the private state of a ZOwnablePK contract, storing a
 * single 32-byte user secret. The derived owner public key and nonce are
 * computed in-circuit from this secret.
 */
export type ZOwnablePKPrivateState = {
  /** @description The single 32-byte witness secret from which all identity derives. */
  userSecretKey: Uint8Array;
};

/**
 * @description Utility object for managing the private state of a ZOwnablePK contract.
 */
export const ZOwnablePKPrivateState = {
  /**
   * @description Generates a new private state with a random 32-byte secret.
   * @returns A fresh ZOwnablePKPrivateState instance.
   */
  generate: (): ZOwnablePKPrivateState => {
    return { userSecretKey: getRandomValues(new Uint8Array(32)) };
  },

  /**
   * @description Generates a new private state with a user-defined 32-byte secret.
   * Useful for deterministic identity in tests.
   *
   * @param secret - The 32-byte user secret to use.
   * @returns A fresh ZOwnablePKPrivateState instance with the provided secret.
   *
   * @example
   * ```typescript
   * const secret = myDeterministicScheme(...);
   * const privateState = ZOwnablePKPrivateState.withSecret(secret);
   * ```
   */
  withSecret: (secret: Uint8Array): ZOwnablePKPrivateState => {
    if (secret.length !== 32) {
      throw new Error(
        `withSecret: expected 32-byte secret, received ${secret.length} bytes`,
      );
    }
    return { userSecretKey: Uint8Array.from(secret) };
  },
};

/**
 * @description Factory function creating witness implementations for ZOwnablePK.
 * @returns An object implementing the Witnesses interface for ZOwnablePKPrivateState.
 */
export const ZOwnablePKWitnesses =
  (): IZOwnablePKWitnesses<ZOwnablePKPrivateState> => ({
    getUserSecret(
      context: WitnessContext<Ledger, ZOwnablePKPrivateState>,
    ): [ZOwnablePKPrivateState, { bytes: Uint8Array }] {
      const { userSecretKey } = context.privateState;
      if (!userSecretKey || userSecretKey.length !== 32) {
        throw new Error(
          'getUserSecret: userSecretKey is missing or not 32 bytes',
        );
      }
      return [context.privateState, { bytes: userSecretKey }];
    },
  });
