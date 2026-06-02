import type { PrivateStateProvider } from "@midnight-ntwrk/midnight-js-types";
import type { ContractAddress, SigningKey } from "@midnight-ntwrk/compact-runtime";

/**
 * Session-scoped, in-memory implementation of the full PrivateStateProvider
 * interface. Browser DApps cannot use LevelDB, so private state and signing
 * keys live in plain Maps for the lifetime of the page.
 *
 * This implements the complete 13-method PrivateStateProvider<PSI, PS>
 * contract. The export/import methods are not meaningful for an ephemeral
 * in-memory store, so they reject — swap in an encrypting persistent provider
 * (e.g. IndexedDB) if you need cross-session private state or real exports.
 */
export function inMemoryPrivateStateProvider<
  PSI extends string,
  PS,
>(): PrivateStateProvider<PSI, PS> {
  const states = new Map<PSI, PS>();
  const signingKeys = new Map<ContractAddress, SigningKey>();

  return {
    // Contract-address scoping is a no-op for this flat in-memory store; the
    // private state IDs are already unique within a single browser session.
    setContractAddress: (_address: ContractAddress) => {},

    set: async (id: PSI, state: PS) => {
      states.set(id, state);
    },
    get: async (id: PSI) => states.get(id) ?? null,
    remove: async (id: PSI) => {
      states.delete(id);
    },
    clear: async () => {
      states.clear();
    },

    setSigningKey: async (address: ContractAddress, signingKey: SigningKey) => {
      signingKeys.set(address, signingKey);
    },
    getSigningKey: async (address: ContractAddress) =>
      signingKeys.get(address) ?? null,
    removeSigningKey: async (address: ContractAddress) => {
      signingKeys.delete(address);
    },
    clearSigningKeys: async () => {
      signingKeys.clear();
    },

    exportPrivateStates: async () => {
      throw new Error(
        "inMemoryPrivateStateProvider does not support exportPrivateStates; " +
          "use a persistent encrypting provider for exports.",
      );
    },
    importPrivateStates: async () => {
      throw new Error(
        "inMemoryPrivateStateProvider does not support importPrivateStates; " +
          "use a persistent encrypting provider for imports.",
      );
    },
    exportSigningKeys: async () => {
      throw new Error(
        "inMemoryPrivateStateProvider does not support exportSigningKeys; " +
          "use a persistent encrypting provider for exports.",
      );
    },
    importSigningKeys: async () => {
      throw new Error(
        "inMemoryPrivateStateProvider does not support importSigningKeys; " +
          "use a persistent encrypting provider for imports.",
      );
    },
  };
}
