import type { Witnesses } from '@src/artifacts/structs/test/mocks/contracts/Queue.mock/contract/index.js';

// This is how we type an empty object.
export type QueueContractPrivateState = Record<string, never>;

/**
 * @description Utility object for managing the private state of the Queue module.
 */
export const QueueContractPrivateState = {
  /**
   * @description Generates a new private state.
   * @returns A fresh QueueContractPrivateState instance (empty).
   */
  generate: (): QueueContractPrivateState => {
    return {};
  },
};

/**
 * @description Factory function creating witness implementations for Queue operations.
 */
export const QueueWitnesses = (): Witnesses<QueueContractPrivateState> => ({});
