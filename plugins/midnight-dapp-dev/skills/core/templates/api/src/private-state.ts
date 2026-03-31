import type { PrivateStateProvider } from "@midnight-ntwrk/midnight-js-types";

export function inMemoryPrivateStateProvider<
  PSI extends string,
  PS,
>(): PrivateStateProvider<PSI, PS> {
  const store = new Map<string, PS>();

  return {
    get: async (id: PSI) => store.get(id) ?? null,
    set: async (id: PSI, state: PS) => {
      store.set(id, state);
    },
    remove: async (id: PSI) => {
      store.delete(id);
    },
  };
}
