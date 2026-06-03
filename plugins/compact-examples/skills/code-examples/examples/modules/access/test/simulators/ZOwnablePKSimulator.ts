import {
  type BaseSimulatorOptions,
  createSimulator,
} from '@openzeppelin-compact/contracts-simulator';
import {
  ledger,
  Contract as MockZOwnablePK,
  type ZOwnablePK_UserPublicKey,
  type ZOwnablePK_UserSecretKey,
} from '../../../../artifacts/MockZOwnablePK/contract/index.js';
import {
  ZOwnablePKPrivateState,
  ZOwnablePKWitnesses,
} from '../../witnesses/ZOwnablePKWitnesses.js';

/**
 * Type constructor args
 */
type ZOwnablePKArgs = readonly [
  ownerId: Uint8Array,
  instanceSalt: Uint8Array,
  isInit: boolean,
];

/**
 * Base simulator
 * @dev We deliberately use `any` as the base simulator type.
 * This workaround is necessary due to type inference and declaration filegen
 * in a monorepo environment. Attempting to fully preserve type information
 * turns into type gymnastics.
 *
 * `any` can be safely removed once the contract simulator is consumed
 * as a properly packaged dependency (outside the monorepo).
 */
const ZOwnablePKSimulatorBase: any = createSimulator<
  ZOwnablePKPrivateState,
  ReturnType<typeof ledger>,
  ReturnType<typeof ZOwnablePKWitnesses>,
  MockZOwnablePK<ZOwnablePKPrivateState>,
  ZOwnablePKArgs
>({
  contractFactory: (witnesses) =>
    new MockZOwnablePK<ZOwnablePKPrivateState>(witnesses),
  defaultPrivateState: () => ZOwnablePKPrivateState.generate(),
  contractArgs: (ownerId, instanceSalt, isInit) => {
    return [ownerId, instanceSalt, isInit];
  },
  ledgerExtractor: (state) => ledger(state),
  witnessesFactory: () => ZOwnablePKWitnesses(),
});

/**
 * ZOwnablePKSimulator
 *
 * SECURE PATTERN — witness-derived identity. The owner's identity is derived
 * in-circuit from a single 32-byte witness secret; `ownPublicKey()` is never
 * used for authorization.
 */
export class ZOwnablePKSimulator extends ZOwnablePKSimulatorBase {
  constructor(
    ownerId: Uint8Array,
    instanceSalt: Uint8Array,
    isInit: boolean,
    options: BaseSimulatorOptions<
      ZOwnablePKPrivateState,
      ReturnType<typeof ZOwnablePKWitnesses>
    > = {},
  ) {
    super([ownerId, instanceSalt, isInit], options);
  }

  /**
   * @description Returns the current commitment representing the contract owner.
   * The full commitment is: `SHA256(SHA256(pk, nonce), instanceSalt, counter, domain)`.
   * @returns The current owner's commitment.
   */
  public owner(): Uint8Array {
    return this.circuits.impure.owner();
  }

  /**
   * @description Transfers ownership to `newOwnerId`.
   * `newOwnerId` must be precalculated and given to the current owner off chain.
   * @param newOwnerId The new owner's unique identifier (`SHA256(pk, nonce)`).
   */
  public transferOwnership(newOwnerId: Uint8Array) {
    this.circuits.impure.transferOwnership(newOwnerId);
  }

  /**
   * @description Leaves the contract without an owner.
   * It will not be possible to call `assertOnlyOwner` circuits anymore.
   * Can only be called by the current owner.
   */
  public renounceOwnership() {
    this.circuits.impure.renounceOwnership();
  }

  /**
   * @description Throws if the caller's witness-derived id `SHA256(pk, nonce)`
   * does not match the stored owner commitment. Use this to only allow the
   * owner to call specific circuits.
   */
  public assertOnlyOwner() {
    this.circuits.impure.assertOnlyOwner();
  }

  /**
   * @description Derives the owner's public key from a witness secret.
   * @param sk - The user secret key.
   * @returns The derived owner public key.
   */
  public _deriveOwnerPublicKey(
    sk: ZOwnablePK_UserSecretKey,
  ): ZOwnablePK_UserPublicKey {
    return this.circuits.pure._deriveOwnerPublicKey(sk);
  }

  /**
   * @description Derives the unlinkability nonce from a witness secret.
   * @param sk - The user secret key.
   * @returns The derived secret nonce.
   */
  public _deriveOwnerNonce(sk: ZOwnablePK_UserSecretKey): Uint8Array {
    return this.circuits.pure._deriveOwnerNonce(sk);
  }

  /**
   * @description Computes the owner commitment from the given `id` and `counter`.
   * @param id - The unique identifier of the owner calculated by `SHA256(pk, nonce)`.
   * @param counter - The current counter or round. This increments by `1`
   * after every transfer to prevent duplicate commitments given the same `id`.
   * @returns The commitment derived from `id` and `counter`.
   */
  public _computeOwnerCommitment(id: Uint8Array, counter: bigint): Uint8Array {
    return this.circuits.impure._computeOwnerCommitment(id, counter);
  }

  /**
   * @description Computes the unique identifier (`id`) of the owner from their
   * derived public key and a secret nonce.
   * @param pk - The owner's derived public key.
   * @param nonce - The owner's derived secret nonce.
   * @returns The computed owner ID.
   */
  public _computeOwnerId(
    pk: ZOwnablePK_UserPublicKey,
    nonce: Uint8Array,
  ): Uint8Array {
    return this.circuits.pure._computeOwnerId(pk, nonce);
  }

  /**
   * @description Transfers ownership to owner id `newOwnerId` without
   * enforcing permission checks on the caller.
   * @param newOwnerId - The unique identifier of the new owner calculated by `SHA256(pk, nonce)`.
   */
  public _transferOwnership(newOwnerId: Uint8Array) {
    this.circuits.impure._transferOwnership(newOwnerId);
  }

  public readonly privateState = {
    /**
     * @description Contextually sets a new 32-byte secret into the private state.
     * The owner's derived identity changes with the secret.
     * @param newSecret The 32-byte user secret.
     * @returns The ZOwnablePK private state after setting the new secret.
     */
    injectSecret: (newSecret: Uint8Array): ZOwnablePKPrivateState => {
      if (newSecret.length !== 32) {
        throw new Error(
          `injectSecret: expected 32-byte secret, received ${newSecret.length} bytes`,
        );
      }
      const currentState =
        this.circuitContextManager.getContext().currentPrivateState;
      const updatedState = {
        ...currentState,
        userSecretKey: Uint8Array.from(newSecret),
      };
      this.circuitContextManager.updatePrivateState(updatedState);
      return updatedState;
    },

    /**
     * @description Returns the current 32-byte secret given the context.
     * @returns The user secret.
     */
    getCurrentSecret: (): Uint8Array => {
      return this.circuitContextManager.getContext().currentPrivateState
        .userSecretKey;
    },
  };
}
