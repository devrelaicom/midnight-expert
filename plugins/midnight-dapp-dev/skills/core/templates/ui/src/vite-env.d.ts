/// <reference types="vite/client" />

import type { InitialAPI } from "@midnight-ntwrk/dapp-connector-api";

declare global {
  interface Window {
    // `@midnight-ntwrk/dapp-connector-api` already augments this on import; the
    // redeclaration keeps `window.midnight` typed project-wide. It must use the
    // SAME index signature as the package (`[key: string]: InitialAPI` — no
    // `| undefined` and no extra named keys) or TypeScript raises TS2717.
    // Each wallet is installed under its own key (a UUID); Lace also aliases
    // itself at `mnLace`.
    midnight?: { [key: string]: InitialAPI };
  }
}
