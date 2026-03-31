/// <reference types="vite/client" />

import type { InitialAPI } from "@midnight-ntwrk/dapp-connector-api";

declare global {
  interface Window {
    midnight?: {
      mnLace?: InitialAPI;
      [key: string]: InitialAPI | undefined;
    };
  }
}
