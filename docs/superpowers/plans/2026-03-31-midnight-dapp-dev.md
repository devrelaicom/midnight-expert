# midnight-dapp-dev Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Claude Code plugin that scaffolds Midnight DApp frontends (Vite + React 19 + shadcn + Tailwind v4) with wallet integration and a TypeScript API layer.

**Architecture:** Plugin with 2 skills (`core` for knowledge + templates, `init` for scaffolding), 1 agent (`dev` for ongoing development). The init skill runs a bash script that copies a flat template tree and does `sed`-based `{{PLACEHOLDER}}` substitution. Templates produce two workspace packages: a UI app and an API SDK layer.

**Tech Stack:** Vite, React 19, shadcn, Tailwind CSS v4, RxJS, `@midnight-ntwrk/*` SDK, Vitest + Testing Library, Pino, Bash

**Spec:** `docs/superpowers/specs/2026-03-31-midnight-dapp-dev-design.md`

---

## File Map

### Plugin Scaffold

```
plugins/midnight-dapp-dev/
  .claude-plugin/plugin.json
```

### Core Skill

```
plugins/midnight-dapp-dev/skills/core/
  SKILL.md
  references/
    provider-patterns.md
    state-management.md
    testing-patterns.md
    vite-config.md
```

### Templates — API Package

```
plugins/midnight-dapp-dev/skills/core/templates/api/
  package.json
  tsconfig.json
  src/
    index.ts
    types.ts
    private-state.ts
```

### Templates — UI Package

```
plugins/midnight-dapp-dev/skills/core/templates/ui/
  package.json
  vite.config.ts
  tsconfig.json
  tsconfig.app.json
  tsconfig.node.json
  components.json
  index.html
  vitest.config.ts
  src/
    index.css
    main.tsx
    App.tsx
    vite-env.d.ts
    lib/
      utils.ts
    providers/
      wallet-context.tsx
      midnight-providers.tsx
    hooks/
      use-wallet.ts
      use-contract-state.ts
    components/
      wallet-widget.tsx
      network-badge.tsx
      proof-server-status.tsx
      ui/
        button.tsx
        card.tsx
        badge.tsx
    __tests__/
      setup.ts
      App.test.tsx
      wallet-context.test.tsx
      midnight-providers.test.tsx
```

### Init Skill

```
plugins/midnight-dapp-dev/skills/init/
  SKILL.md
  scripts/
    init.sh
```

### Agent

```
plugins/midnight-dapp-dev/agents/
  dev.md
```

---

## Tasks

### Task 1: Plugin Scaffold + plugin.json

**Files:**
- Create: `plugins/midnight-dapp-dev/.claude-plugin/plugin.json`

- [ ] **Step 1: Create plugin directory structure**

```bash
mkdir -p plugins/midnight-dapp-dev/.claude-plugin
mkdir -p plugins/midnight-dapp-dev/skills/core/references
mkdir -p plugins/midnight-dapp-dev/skills/core/templates/ui
mkdir -p plugins/midnight-dapp-dev/skills/core/templates/api
mkdir -p plugins/midnight-dapp-dev/skills/init/scripts
mkdir -p plugins/midnight-dapp-dev/agents
```

- [ ] **Step 2: Write plugin.json**

Write `plugins/midnight-dapp-dev/.claude-plugin/plugin.json`:

```json
{
  "name": "midnight-dapp-dev",
  "version": "0.1.0",
  "description": "Scaffold and build Midnight DApp frontends — Vite + React 19 + shadcn + Tailwind v4 templates, wallet integration, provider architecture, and a development agent for ongoing UI work.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "dapp",
    "react",
    "vite",
    "shadcn",
    "tailwind",
    "wallet",
    "lace",
    "scaffold",
    "template",
    "frontend"
  ]
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-dapp-dev/.claude-plugin/plugin.json
git commit -m "feat(midnight-dapp-dev): add plugin scaffold with plugin.json

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: API Package Template

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/api/package.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/api/tsconfig.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/api/src/types.ts`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/api/src/private-state.ts`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/api/src/index.ts`

- [ ] **Step 1: Write api/package.json**

Write `plugins/midnight-dapp-dev/skills/core/templates/api/package.json`:

```json
{
  "name": "{{API_PACKAGE_NAME}}",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "vitest run"
  },
  "dependencies": {
    "@midnight-ntwrk/midnight-js-contracts": "^3.0.0",
    "@midnight-ntwrk/midnight-js-types": "^3.0.0",
    "@midnight-ntwrk/midnight-js-network-id": "^3.0.0",
    "@midnight-ntwrk/midnight-js-indexer-public-data-provider": "^3.0.0",
    "@midnight-ntwrk/midnight-js-fetch-zk-config-provider": "^3.0.0",
    "@midnight-ntwrk/midnight-js-http-client-proof-provider": "^3.0.0",
    "@midnight-ntwrk/dapp-connector-api": "^4.0.0",
    "rxjs": "^7.8.1"
  },
  "peerDependencies": {
    "{{CONTRACT_PACKAGE}}": "*"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "vitest": "^3.2.0"
  }
}
```

- [ ] **Step 2: Write api/tsconfig.json**

Write `plugins/midnight-dapp-dev/skills/core/templates/api/tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "dist",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "composite": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

- [ ] **Step 3: Write api/src/types.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/api/src/types.ts`:

```typescript
import type { MidnightProviders } from "@midnight-ntwrk/midnight-js-types";

/**
 * Replace these placeholder types with your contract's actual types.
 *
 * ContractState — the shape of your contract's public ledger state,
 *   parsed from the indexer via YourContract.ledger(state.data).
 *
 * PrivateState — the shape of your off-chain state stored locally,
 *   typically containing secret keys or user-specific data.
 *
 * DerivedState — the combined view your UI components consume,
 *   computed from ContractState + PrivateState.
 */

// TODO: Replace with your contract's impure circuit key union
// e.g., "increment" | "transfer" | "mint"
export type ImpureCircuitKeys = string;

// TODO: Replace with your contract's private state identifier
export const PRIVATE_STATE_ID = "privateState" as const;

// TODO: Replace with your contract's public ledger state shape
export interface ContractState {
  // e.g., round: bigint;
}

// TODO: Replace with your contract's private state shape
export interface PrivateState {
  // e.g., secretKey: Uint8Array;
}

// Combined state for UI consumption
export interface DerivedState {
  contractState: ContractState | null;
  privateState: PrivateState | null;
}

export type AppProviders = MidnightProviders<
  ImpureCircuitKeys,
  typeof PRIVATE_STATE_ID,
  PrivateState
>;
```

- [ ] **Step 4: Write api/src/private-state.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/api/src/private-state.ts`:

```typescript
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
```

- [ ] **Step 5: Write api/src/index.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/api/src/index.ts`:

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";
import type {
  WalletProvider,
  MidnightProvider,
} from "@midnight-ntwrk/midnight-js-types";
import { combineLatest, map, retry, type Observable } from "rxjs";
import { inMemoryPrivateStateProvider } from "./private-state.js";
import type {
  AppProviders,
  ContractState,
  DerivedState,
  ImpureCircuitKeys,
  PrivateState,
} from "./types.js";
import { PRIVATE_STATE_ID } from "./types.js";

export { inMemoryPrivateStateProvider } from "./private-state.js";
export type {
  AppProviders,
  ContractState,
  DerivedState,
  ImpureCircuitKeys,
  PrivateState,
} from "./types.js";
export { PRIVATE_STATE_ID } from "./types.js";

function deriveProofServerUri(substrateNodeUri: string): string {
  try {
    const url = new URL(substrateNodeUri);
    url.port = "6300";
    url.pathname = "";
    return url.toString().replace(/\/$/, "");
  } catch {
    return "http://localhost:6300";
  }
}

export async function createProviders(
  api: ConnectedAPI,
): Promise<AppProviders> {
  const config = await api.getConfiguration();
  setNetworkId(config.networkId);

  const publicDataProvider = indexerPublicDataProvider(
    config.indexerUri,
    config.indexerWsUri,
  );

  const privateStateProvider = inMemoryPrivateStateProvider<
    typeof PRIVATE_STATE_ID,
    PrivateState
  >();

  const zkConfigProvider = new FetchZkConfigProvider<ImpureCircuitKeys>(
    window.location.origin,
    fetch.bind(window),
  );

  const proofServerUri = deriveProofServerUri(config.substrateNodeUri);
  const proofProvider = httpClientProofProvider<ImpureCircuitKeys>(
    proofServerUri,
    zkConfigProvider,
  );

  const { shieldedCoinPublicKey, shieldedEncryptionPublicKey } =
    await api.getShieldedAddresses();

  const walletProvider: WalletProvider = {
    getCoinPublicKey: () => shieldedCoinPublicKey,
    getEncryptionPublicKey: () => shieldedEncryptionPublicKey,
    balanceTx: async (tx, newCoins, ttl) => {
      const result = await api.balanceUnsealedTransaction(tx, {
        newCoins,
        ttl,
      });
      return result.tx;
    },
  };

  const midnightProvider: MidnightProvider = {
    submitTx: async (tx) => {
      await api.submitTransaction(tx);
      return tx.txId;
    },
  };

  return {
    privateStateProvider,
    publicDataProvider,
    zkConfigProvider,
    proofProvider,
    walletProvider,
    midnightProvider,
  };
}

// TODO: Import your compiled contract and implement deploy/join.
//
// Example deployment pattern:
//
//   import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";
//   import { CompiledContract } from "@midnight-ntwrk/compact-js";
//   import { MyContract } from "{{CONTRACT_PACKAGE}}";
//   import { witnesses } from "{{CONTRACT_PACKAGE}}/witnesses";
//
//   export async function deploy(providers: AppProviders) {
//     const compiledContract = CompiledContract.make("myContract", MyContract.Contract).pipe(
//       CompiledContract.withWitnesses(witnesses),
//       CompiledContract.withFetchedFileAssets(window.location.origin),
//     );
//     return deployContract(providers, {
//       compiledContract,
//       privateStateId: PRIVATE_STATE_ID,
//       initialPrivateState: { secretKey: crypto.getRandomValues(new Uint8Array(32)) },
//     });
//   }
//
// Example join pattern:
//
//   import { findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";
//
//   export async function join(providers: AppProviders, contractAddress: string) {
//     return findDeployedContract(providers, {
//       contractAddress,
//       compiledContract,
//       privateStateId: PRIVATE_STATE_ID,
//       initialPrivateState: { secretKey: crypto.getRandomValues(new Uint8Array(32)) },
//     });
//   }

export function createStateObservable(
  publicDataProvider: AppProviders["publicDataProvider"],
  privateStateProvider: AppProviders["privateStateProvider"],
  contractAddress: string,
  parseLedger: (data: Uint8Array) => ContractState,
): Observable<DerivedState> {
  const public$ = publicDataProvider
    .contractStateObservable(contractAddress, { type: "latest" })
    .pipe(map((state) => parseLedger(state.data)));

  const private$ = new Observable<PrivateState | null>((subscriber) => {
    privateStateProvider
      .get(PRIVATE_STATE_ID)
      .then((s) => subscriber.next(s))
      .catch((err) => subscriber.error(err));
  });

  return combineLatest([public$, private$]).pipe(
    map(([contractState, privateState]) => ({ contractState, privateState })),
    retry({ delay: 500 }),
  );
}
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/api/
git commit -m "feat(midnight-dapp-dev): add API package template

Includes provider factory, placeholder types, in-memory private state,
and state observable helper with combineLatest pattern.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: UI Template — Config Files

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/package.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/vite.config.ts`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.app.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.node.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/components.json`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/index.html`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/vitest.config.ts`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/vite-env.d.ts`

- [ ] **Step 1: Write ui/package.json**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/package.json`:

```json
{
  "name": "{{UI_PACKAGE_NAME}}",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "test": "vitest run",
    "test:watch": "vitest",
    "copy-contract-keys": "echo 'TODO: Configure contract key paths. Example: cp -r ../contract/dist/managed/*/keys/* ./public/keys && cp -r ../contract/dist/managed/*/zkir/* ./public/zkir'"
  },
  "dependencies": {
    "{{API_PACKAGE_NAME}}": "workspace:*",
    "@midnight-ntwrk/dapp-connector-api": "^4.0.0",
    "@midnight-ntwrk/midnight-js-types": "^3.0.0",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "lucide-react": "^0.525.0",
    "pino": "^9.7.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "rxjs": "^7.8.1",
    "tailwind-merge": "^3.0.0"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.1.0",
    "@testing-library/jest-dom": "^6.6.0",
    "@testing-library/react": "^16.3.0",
    "@types/react": "^19.1.0",
    "@types/react-dom": "^19.1.0",
    "@types/node": "^22.0.0",
    "@vitejs/plugin-react": "^4.5.0",
    "@originjs/vite-plugin-commonjs": "^1.0.3",
    "jsdom": "^26.1.0",
    "tailwindcss": "^4.1.0",
    "typescript": "^5.8.0",
    "vite": "^7.0.0",
    "vite-plugin-node-polyfills": "^0.23.0",
    "vite-plugin-top-level-await": "^1.5.0",
    "vite-plugin-wasm": "^3.4.1",
    "vitest": "^3.2.0"
  }
}
```

- [ ] **Step 2: Write ui/vite.config.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/vite.config.ts`:

```typescript
import path from "path";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import wasm from "vite-plugin-wasm";
import topLevelAwait from "vite-plugin-top-level-await";
import { nodePolyfills } from "vite-plugin-node-polyfills";
import commonjs from "@originjs/vite-plugin-commonjs";

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    wasm(),
    topLevelAwait(),
    commonjs(),
    nodePolyfills({
      include: ["buffer", "process", "util", "crypto", "stream"],
    }),
  ],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    target: "esnext",
    minify: false,
  },
});
```

- [ ] **Step 3: Write ui/tsconfig.json, tsconfig.app.json, tsconfig.node.json**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.json`:

```json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.app.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.node.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "skipLibCheck": true,
    "allowImportingTsExtensions": true,
    "noEmit": true
  },
  "include": ["vite.config.ts", "vitest.config.ts"]
}
```

- [ ] **Step 4: Write ui/components.json**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/components.json`:

```json
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "new-york",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/index.css",
    "baseColor": "zinc",
    "cssVariables": true
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "iconLibrary": "lucide"
}
```

- [ ] **Step 5: Write ui/index.html**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{{PROJECT_NAME}}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

- [ ] **Step 6: Write ui/vitest.config.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/vitest.config.ts`:

```typescript
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/__tests__/setup.ts"],
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

- [ ] **Step 7: Write ui/src/vite-env.d.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/vite-env.d.ts`:

```typescript
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
```

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/package.json \
       plugins/midnight-dapp-dev/skills/core/templates/ui/vite.config.ts \
       plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.json \
       plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.app.json \
       plugins/midnight-dapp-dev/skills/core/templates/ui/tsconfig.node.json \
       plugins/midnight-dapp-dev/skills/core/templates/ui/components.json \
       plugins/midnight-dapp-dev/skills/core/templates/ui/index.html \
       plugins/midnight-dapp-dev/skills/core/templates/ui/vitest.config.ts \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/vite-env.d.ts
git commit -m "feat(midnight-dapp-dev): add UI template config files

Vite + React 19 + Tailwind v4 + shadcn + Midnight SDK polyfills.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: UI Template — Styles and shadcn Utils

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/index.css`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/lib/utils.ts`

- [ ] **Step 1: Write ui/src/index.css**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/index.css`:

```css
@import "tailwindcss";

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-destructive-foreground: var(--destructive-foreground);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
}

:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --destructive-foreground: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --radius: 0.625rem;
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.145 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.145 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.985 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --secondary: oklch(0.269 0 0);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.396 0.141 25.723);
  --destructive-foreground: oklch(0.637 0.237 25.331);
  --border: oklch(0.269 0 0);
  --input: oklch(0.269 0 0);
  --ring: oklch(0.439 0 0);
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
```

- [ ] **Step 2: Write ui/src/lib/utils.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/lib/utils.ts`:

```typescript
import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/index.css \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/lib/utils.ts
git commit -m "feat(midnight-dapp-dev): add Tailwind v4 CSS and shadcn utils

CSS-based Tailwind config with oklch color tokens for light/dark themes.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: UI Template — shadcn Primitives

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/button.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/card.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/badge.tsx`

- [ ] **Step 1: Write button.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/button.tsx`:

```typescript
import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0",
  {
    variants: {
      variant: {
        default:
          "bg-primary text-primary-foreground shadow hover:bg-primary/90",
        destructive:
          "bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90",
        outline:
          "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
        secondary:
          "bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80",
        ghost: "hover:bg-accent hover:text-accent-foreground",
        link: "text-primary underline-offset-4 hover:underline",
      },
      size: {
        default: "h-9 px-4 py-2",
        sm: "h-8 rounded-md px-3 text-xs",
        lg: "h-10 rounded-md px-8",
        icon: "h-9 w-9",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  },
);

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean;
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, ...props }, ref) => {
    const Comp = asChild ? Slot : "button";
    return (
      <Comp
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  },
);
Button.displayName = "Button";

export { Button, buttonVariants };
```

Note: this requires adding `@radix-ui/react-slot` to the UI package.json dependencies. Update `plugins/midnight-dapp-dev/skills/core/templates/ui/package.json` to include `"@radix-ui/react-slot": "^1.2.0"` in dependencies.

- [ ] **Step 2: Write card.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/card.tsx`:

```typescript
import * as React from "react";
import { cn } from "@/lib/utils";

const Card = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn(
      "rounded-xl border bg-card text-card-foreground shadow",
      className,
    )}
    {...props}
  />
));
Card.displayName = "Card";

const CardHeader = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn("flex flex-col space-y-1.5 p-6", className)}
    {...props}
  />
));
CardHeader.displayName = "CardHeader";

const CardTitle = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn("font-semibold leading-none tracking-tight", className)}
    {...props}
  />
));
CardTitle.displayName = "CardTitle";

const CardDescription = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn("text-sm text-muted-foreground", className)}
    {...props}
  />
));
CardDescription.displayName = "CardDescription";

const CardContent = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div ref={ref} className={cn("p-6 pt-0", className)} {...props} />
));
CardContent.displayName = "CardContent";

const CardFooter = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement>
>(({ className, ...props }, ref) => (
  <div
    ref={ref}
    className={cn("flex items-center p-6 pt-0", className)}
    {...props}
  />
));
CardFooter.displayName = "CardFooter";

export {
  Card,
  CardHeader,
  CardFooter,
  CardTitle,
  CardDescription,
  CardContent,
};
```

- [ ] **Step 3: Write badge.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/badge.tsx`:

```typescript
import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-primary text-primary-foreground shadow hover:bg-primary/80",
        secondary:
          "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
        destructive:
          "border-transparent bg-destructive text-destructive-foreground shadow hover:bg-destructive/80",
        outline: "text-foreground",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  );
}

export { Badge, badgeVariants };
```

- [ ] **Step 4: Update ui/package.json to add @radix-ui/react-slot**

Edit `plugins/midnight-dapp-dev/skills/core/templates/ui/package.json` — add `"@radix-ui/react-slot": "^1.2.0"` to the `dependencies` section.

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/ui/ \
       plugins/midnight-dapp-dev/skills/core/templates/ui/package.json
git commit -m "feat(midnight-dapp-dev): add shadcn button, card, badge primitives

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: UI Template — Wallet Provider

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/providers/wallet-context.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/hooks/use-wallet.ts`

- [ ] **Step 1: Write wallet-context.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/providers/wallet-context.tsx`:

```typescript
import {
  createContext,
  useCallback,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import type { ConnectedAPI, InitialAPI } from "@midnight-ntwrk/dapp-connector-api";

const STORAGE_KEY = "{{PROJECT_NAME}}_wallet_autoconnect";

export type WalletConnectionStatus =
  | "disconnected"
  | "connecting"
  | "connected"
  | "error";

export interface WalletState {
  status: WalletConnectionStatus;
  connectedApi: ConnectedAPI | null;
  shieldedAddress: string | null;
  coinPublicKey: string | null;
  encryptionPublicKey: string | null;
  networkId: string | null;
  error: string | null;
}

export interface WalletContextValue extends WalletState {
  connect: () => Promise<void>;
  disconnect: () => void;
}

export const WalletContext = createContext<WalletContextValue | null>(null);

function findWallet(): InitialAPI | undefined {
  if (typeof window === "undefined" || !window.midnight) return undefined;
  return window.midnight.mnLace ?? Object.values(window.midnight)[0];
}

export function WalletProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<WalletState>({
    status: "disconnected",
    connectedApi: null,
    shieldedAddress: null,
    coinPublicKey: null,
    encryptionPublicKey: null,
    networkId: null,
    error: null,
  });

  const connect = useCallback(async () => {
    setState((prev) => ({ ...prev, status: "connecting", error: null }));

    const wallet = findWallet();
    if (!wallet) {
      setState((prev) => ({
        ...prev,
        status: "error",
        error:
          "Lace wallet extension not found. Install it from the Chrome Web Store.",
      }));
      return;
    }

    try {
      const api = await wallet.connect("undeployed");
      const config = await api.getConfiguration();
      const addresses = await api.getShieldedAddresses();

      setState({
        status: "connected",
        connectedApi: api,
        shieldedAddress: addresses.shieldedAddress,
        coinPublicKey: addresses.shieldedCoinPublicKey,
        encryptionPublicKey: addresses.shieldedEncryptionPublicKey,
        networkId: config.networkId,
        error: null,
      });

      localStorage.setItem(STORAGE_KEY, "true");
    } catch (err: unknown) {
      const message =
        typeof err === "object" && err !== null && "reason" in err
          ? (err as { reason: string }).reason
          : "Failed to connect to wallet";
      setState((prev) => ({
        ...prev,
        status: "error",
        error: message,
      }));
    }
  }, []);

  const disconnect = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY);
    setState({
      status: "disconnected",
      connectedApi: null,
      shieldedAddress: null,
      coinPublicKey: null,
      encryptionPublicKey: null,
      networkId: null,
      error: null,
    });
  }, []);

  useEffect(() => {
    if (localStorage.getItem(STORAGE_KEY) === "true") {
      connect();
    }
  }, [connect]);

  return (
    <WalletContext.Provider value={{ ...state, connect, disconnect }}>
      {children}
    </WalletContext.Provider>
  );
}
```

- [ ] **Step 2: Write use-wallet.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/hooks/use-wallet.ts`:

```typescript
import { useContext } from "react";
import { WalletContext, type WalletContextValue } from "@/providers/wallet-context";

export function useWallet(): WalletContextValue {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error("useWallet must be used within a WalletProvider");
  }
  return context;
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/providers/wallet-context.tsx \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/hooks/use-wallet.ts
git commit -m "feat(midnight-dapp-dev): add wallet context provider and hook

Lace connection with auto-connect via localStorage, error handling,
and address/key state management.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: UI Template — Midnight Providers + Contract State Hook

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/providers/midnight-providers.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/hooks/use-contract-state.ts`

- [ ] **Step 1: Write midnight-providers.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/providers/midnight-providers.tsx`:

```typescript
import {
  createContext,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from "react";
import { createProviders, type AppProviders } from "{{API_PACKAGE_NAME}}";
import { useWallet } from "@/hooks/use-wallet";

interface MidnightProvidersContextValue {
  providers: AppProviders | null;
  isReady: boolean;
  error: string | null;
}

const MidnightProvidersContext =
  createContext<MidnightProvidersContextValue | null>(null);

export function MidnightProvidersProvider({
  children,
}: {
  children: ReactNode;
}) {
  const { connectedApi, status } = useWallet();
  const [providers, setProviders] = useState<AppProviders | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (status !== "connected" || !connectedApi) {
      setProviders(null);
      setError(null);
      return;
    }

    let cancelled = false;

    createProviders(connectedApi)
      .then((p) => {
        if (!cancelled) {
          setProviders(p);
          setError(null);
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(
            err instanceof Error ? err.message : "Failed to create providers",
          );
        }
      });

    return () => {
      cancelled = true;
    };
  }, [connectedApi, status]);

  return (
    <MidnightProvidersContext.Provider
      value={{ providers, isReady: providers !== null, error }}
    >
      {children}
    </MidnightProvidersContext.Provider>
  );
}

export function useMidnightProviders(): MidnightProvidersContextValue {
  const context = useContext(MidnightProvidersContext);
  if (!context) {
    throw new Error(
      "useMidnightProviders must be used within a MidnightProvidersProvider",
    );
  }
  return context;
}
```

- [ ] **Step 2: Write use-contract-state.ts**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/hooks/use-contract-state.ts`:

```typescript
import { useEffect, useState } from "react";
import type { Observable } from "rxjs";

export function useContractState<T>(observable: Observable<T> | null): {
  state: T | null;
  error: Error | null;
} {
  const [state, setState] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    if (!observable) {
      setState(null);
      setError(null);
      return;
    }

    const subscription = observable.subscribe({
      next: (value) => {
        setState(value);
        setError(null);
      },
      error: (err) => {
        setError(err instanceof Error ? err : new Error(String(err)));
      },
    });

    return () => subscription.unsubscribe();
  }, [observable]);

  return { state, error };
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/providers/midnight-providers.tsx \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/hooks/use-contract-state.ts
git commit -m "feat(midnight-dapp-dev): add Midnight providers context and contract state hook

Provider factory from wallet config, generic RxJS observable hook for
contract state subscriptions.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: UI Template — Components

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/wallet-widget.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/network-badge.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/proof-server-status.tsx`

- [ ] **Step 1: Write wallet-widget.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/wallet-widget.tsx`:

```typescript
import { Wallet, LogOut, Loader2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { useWallet } from "@/hooks/use-wallet";

function truncateAddress(address: string): string {
  if (address.length <= 16) return address;
  return `${address.slice(0, 8)}...${address.slice(-8)}`;
}

export function WalletWidget() {
  const { status, shieldedAddress, error, connect, disconnect } = useWallet();

  if (status === "connecting") {
    return (
      <Button variant="outline" disabled>
        <Loader2 className="animate-spin" />
        Connecting...
      </Button>
    );
  }

  if (status === "connected" && shieldedAddress) {
    return (
      <div className="flex items-center gap-2">
        <span className="text-sm font-mono text-muted-foreground">
          {truncateAddress(shieldedAddress)}
        </span>
        <Button variant="ghost" size="icon" onClick={disconnect}>
          <LogOut />
        </Button>
      </div>
    );
  }

  return (
    <div className="flex flex-col items-end gap-1">
      <Button variant="outline" onClick={connect}>
        <Wallet />
        Connect Wallet
      </Button>
      {status === "error" && error && (
        <p className="text-xs text-destructive max-w-64 text-right">{error}</p>
      )}
    </div>
  );
}
```

- [ ] **Step 2: Write network-badge.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/network-badge.tsx`:

```typescript
import { Badge } from "@/components/ui/badge";
import { useWallet } from "@/hooks/use-wallet";

export function NetworkBadge() {
  const { networkId, status } = useWallet();

  if (status !== "connected" || !networkId) return null;

  return <Badge variant="secondary">{networkId}</Badge>;
}
```

- [ ] **Step 3: Write proof-server-status.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/proof-server-status.tsx`:

```typescript
import { useEffect, useState } from "react";
import { Badge } from "@/components/ui/badge";
import { useWallet } from "@/hooks/use-wallet";

export function ProofServerStatus() {
  const { connectedApi, status } = useWallet();
  const [isOnline, setIsOnline] = useState<boolean | null>(null);

  useEffect(() => {
    if (status !== "connected" || !connectedApi) {
      setIsOnline(null);
      return;
    }

    let cancelled = false;

    async function check() {
      try {
        const config = await connectedApi!.getConfiguration();
        const proofServerUrl = config.substrateNodeUri
          .replace(/\/rpc$/, "")
          .replace(/:9944/, ":6300");
        const response = await fetch(proofServerUrl, { mode: "no-cors" });
        if (!cancelled) setIsOnline(response.type === "opaque" || response.ok);
      } catch {
        if (!cancelled) setIsOnline(false);
      }
    }

    check();
    return () => {
      cancelled = true;
    };
  }, [connectedApi, status]);

  if (isOnline === null) return null;

  return (
    <Badge variant={isOnline ? "secondary" : "destructive"}>
      Proof Server: {isOnline ? "Online" : "Offline"}
    </Badge>
  );
}
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/wallet-widget.tsx \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/network-badge.tsx \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/components/proof-server-status.tsx
git commit -m "feat(midnight-dapp-dev): add wallet widget, network badge, proof server status

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: UI Template — App Shell

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/main.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/App.tsx`

- [ ] **Step 1: Write main.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/main.tsx`:

```typescript
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import "./index.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
```

- [ ] **Step 2: Write App.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/App.tsx`:

```typescript
import { WalletProvider } from "@/providers/wallet-context";
import { MidnightProvidersProvider } from "@/providers/midnight-providers";
import { WalletWidget } from "@/components/wallet-widget";
import { NetworkBadge } from "@/components/network-badge";
import { ProofServerStatus } from "@/components/proof-server-status";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";

export function App() {
  return (
    <WalletProvider>
      <MidnightProvidersProvider>
        <div className="min-h-screen bg-background">
          <header className="border-b">
            <div className="container mx-auto flex items-center justify-between px-4 py-3">
              <h1 className="text-lg font-semibold">{{PROJECT_NAME}}</h1>
              <div className="flex items-center gap-3">
                <NetworkBadge />
                <ProofServerStatus />
                <WalletWidget />
              </div>
            </div>
          </header>
          <main className="container mx-auto px-4 py-8">
            <Card>
              <CardHeader>
                <CardTitle>Welcome to {{PROJECT_NAME}}</CardTitle>
                <CardDescription>
                  Connect your Lace wallet to get started. Your contract
                  components go here.
                </CardDescription>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-muted-foreground">
                  This template provides wallet connection, Midnight provider
                  assembly, and reactive state management. Wire up your contract
                  in the API package to start building.
                </p>
              </CardContent>
            </Card>
          </main>
        </div>
      </MidnightProvidersProvider>
    </WalletProvider>
  );
}
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/main.tsx \
       plugins/midnight-dapp-dev/skills/core/templates/ui/src/App.tsx
git commit -m "feat(midnight-dapp-dev): add app shell with provider hierarchy

WalletProvider > MidnightProvidersProvider > App layout with header,
wallet widget, network badge, and proof server status.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: UI Template — Tests

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/setup.ts`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/App.test.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/wallet-context.test.tsx`
- Create: `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/midnight-providers.test.tsx`

- [ ] **Step 1: Write test setup**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/setup.ts`:

```typescript
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 2: Write App.test.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/App.test.tsx`:

```typescript
import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import { App } from "../App";

describe("App", () => {
  it("renders without crashing", () => {
    render(<App />);
    expect(screen.getByText("{{PROJECT_NAME}}")).toBeInTheDocument();
  });

  it("shows connect wallet button when disconnected", () => {
    render(<App />);
    expect(screen.getByText("Connect Wallet")).toBeInTheDocument();
  });
});
```

- [ ] **Step 3: Write wallet-context.test.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/wallet-context.test.tsx`:

```typescript
import { render, screen, act } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, it, expect, vi, beforeEach } from "vitest";
import { WalletProvider } from "../providers/wallet-context";
import { useWallet } from "../hooks/use-wallet";

function TestConsumer() {
  const { status, shieldedAddress, error, connect, disconnect } = useWallet();
  return (
    <div>
      <span data-testid="status">{status}</span>
      <span data-testid="address">{shieldedAddress ?? "none"}</span>
      <span data-testid="error">{error ?? "none"}</span>
      <button onClick={connect}>connect</button>
      <button onClick={disconnect}>disconnect</button>
    </div>
  );
}

describe("WalletContext", () => {
  beforeEach(() => {
    localStorage.clear();
    delete (window as Record<string, unknown>).midnight;
  });

  it("starts disconnected", () => {
    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );
    expect(screen.getByTestId("status")).toHaveTextContent("disconnected");
    expect(screen.getByTestId("address")).toHaveTextContent("none");
  });

  it("shows error when wallet not found", async () => {
    const user = userEvent.setup();
    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );

    await user.click(screen.getByText("connect"));

    expect(screen.getByTestId("status")).toHaveTextContent("error");
    expect(screen.getByTestId("error")).toHaveTextContent("Lace wallet");
  });

  it("connects successfully with mock wallet", async () => {
    const mockApi = {
      getConfiguration: vi.fn().mockResolvedValue({
        indexerUri: "http://localhost:8088/api/v3/graphql",
        indexerWsUri: "ws://localhost:8088/api/v3/graphql/ws",
        substrateNodeUri: "http://localhost:9944",
        networkId: "undeployed",
      }),
      getShieldedAddresses: vi.fn().mockResolvedValue({
        shieldedAddress: "mn_shield_test1abc123",
        shieldedCoinPublicKey: "coinpub123",
        shieldedEncryptionPublicKey: "encpub123",
      }),
    };

    (window as Record<string, unknown>).midnight = {
      mnLace: {
        name: "Lace",
        apiVersion: "4.0.0",
        icon: "",
        rdns: "lace",
        connect: vi.fn().mockResolvedValue(mockApi),
      },
    };

    const user = userEvent.setup();
    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );

    await user.click(screen.getByText("connect"));

    await vi.waitFor(() => {
      expect(screen.getByTestId("status")).toHaveTextContent("connected");
    });

    expect(screen.getByTestId("address")).toHaveTextContent(
      "mn_shield_test1abc123",
    );
  });

  it("disconnects and clears state", async () => {
    const user = userEvent.setup();
    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );

    await user.click(screen.getByText("disconnect"));

    expect(screen.getByTestId("status")).toHaveTextContent("disconnected");
    expect(screen.getByTestId("address")).toHaveTextContent("none");
  });
});
```

Note: add `@testing-library/user-event` to the UI package.json devDependencies: `"@testing-library/user-event": "^14.6.0"`.

- [ ] **Step 4: Write midnight-providers.test.tsx**

Write `plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/midnight-providers.test.tsx`:

```typescript
import { render, screen } from "@testing-library/react";
import { describe, it, expect, vi } from "vitest";
import { WalletProvider } from "../providers/wallet-context";
import {
  MidnightProvidersProvider,
  useMidnightProviders,
} from "../providers/midnight-providers";

vi.mock("{{API_PACKAGE_NAME}}", () => ({
  createProviders: vi.fn().mockRejectedValue(new Error("Not connected")),
}));

function TestConsumer() {
  const { isReady, error } = useMidnightProviders();
  return (
    <div>
      <span data-testid="ready">{isReady ? "yes" : "no"}</span>
      <span data-testid="error">{error ?? "none"}</span>
    </div>
  );
}

describe("MidnightProvidersProvider", () => {
  it("starts not ready when wallet is disconnected", () => {
    render(
      <WalletProvider>
        <MidnightProvidersProvider>
          <TestConsumer />
        </MidnightProvidersProvider>
      </WalletProvider>,
    );

    expect(screen.getByTestId("ready")).toHaveTextContent("no");
    expect(screen.getByTestId("error")).toHaveTextContent("none");
  });
});
```

- [ ] **Step 5: Update ui/package.json to add @testing-library/user-event**

Edit `plugins/midnight-dapp-dev/skills/core/templates/ui/package.json` — add `"@testing-library/user-event": "^14.6.0"` to devDependencies.

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/templates/ui/src/__tests__/ \
       plugins/midnight-dapp-dev/skills/core/templates/ui/package.json
git commit -m "feat(midnight-dapp-dev): add tests for App, wallet context, providers

Vitest + Testing Library with mock wallet, connection state tests,
and provider assembly tests.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 11: Init Skill + Script

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/init/SKILL.md`
- Create: `plugins/midnight-dapp-dev/skills/init/scripts/init.sh`

- [ ] **Step 1: Write init SKILL.md**

Write `plugins/midnight-dapp-dev/skills/init/SKILL.md`:

```markdown
---
name: init
description: >-
  This skill should be used when the user asks to "scaffold a Midnight DApp",
  "initialize a DApp UI", "add a frontend to my Midnight project",
  "create a DApp UI package", "set up a Midnight web app",
  "add a UI to my project", or invokes /midnight-dapp-dev:init.
version: 0.1.0
---

# Initialize Midnight DApp Frontend

Scaffold a Vite + React 19 + shadcn + Tailwind v4 UI package and a TypeScript
API package into the current project.

## Usage

Run the init script:

```bash
bash "${CLAUDE_SKILL_ROOT}/scripts/init.sh"
```

The script:
1. Reads the current project's `package.json` to derive the project name
2. Scans for Compact contract packages (directories with `managed/` output)
3. Detects the package manager from lockfile presence
4. Prompts to confirm or override each derived value
5. Copies the template tree from the core skill's `templates/` directory
6. Runs placeholder substitution across all copied files
7. Updates root `package.json` workspaces if applicable

## After Scaffolding

1. Install dependencies with the detected package manager
2. Configure the `copy-contract-keys` script in the UI `package.json` with the path to the contract's compiled `keys/` and `zkir/` output
3. Wire up the contract in the API package's `src/index.ts` and `src/types.ts`
4. Run `npm run dev` in the UI directory to start the dev server

## Placeholders

The template uses these `{{PLACEHOLDER}}` variables:

| Variable | Description |
|---|---|
| `{{PROJECT_NAME}}` | Project name from root package.json |
| `{{UI_PACKAGE_NAME}}` | UI package name (derived: `{project}-ui`) |
| `{{API_PACKAGE_NAME}}` | API package name (derived: `{project}-api`) |
| `{{UI_DIR}}` | UI directory name (default: `ui`) |
| `{{API_DIR}}` | API directory name (default: `api`) |
| `{{CONTRACT_PACKAGE}}` | Contract package name (scanned or prompted) |
| `{{PACKAGE_MANAGER}}` | Detected package manager |
```

- [ ] **Step 2: Write init.sh**

Write `plugins/midnight-dapp-dev/skills/init/scripts/init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../../core/templates" && pwd)"

if [ ! -d "$TEMPLATES_DIR/ui" ] || [ ! -d "$TEMPLATES_DIR/api" ]; then
  echo "Error: Templates not found at $TEMPLATES_DIR" >&2
  exit 1
fi

# --- Step 1: Derive values ---

PROJECT_NAME=""
if [ -f "package.json" ]; then
  PROJECT_NAME=$(python3 -c "import json; print(json.load(open('package.json')).get('name', ''))" 2>/dev/null || echo "")
fi

CONTRACT_PACKAGE=""
for dir in */src/managed/*/; do
  if [ -d "$dir" ]; then
    contract_pkg_dir=$(dirname "$(dirname "$(dirname "$dir")")")
    if [ -f "$contract_pkg_dir/package.json" ]; then
      CONTRACT_PACKAGE=$(python3 -c "import json; print(json.load(open('$contract_pkg_dir/package.json')).get('name', ''))" 2>/dev/null || echo "")
      break
    fi
  fi
done

UI_DIR="ui"
API_DIR="api"

PACKAGE_MANAGER="npm"
if [ -f "pnpm-lock.yaml" ]; then
  PACKAGE_MANAGER="pnpm"
elif [ -f "yarn.lock" ]; then
  PACKAGE_MANAGER="yarn"
elif [ -f "package-lock.json" ]; then
  PACKAGE_MANAGER="npm"
fi

# --- Step 2: Confirm with user ---

echo ""
echo "Midnight DApp Scaffold"
echo "======================"
echo ""

read -rp "Project name [${PROJECT_NAME:-my-midnight-dapp}]: " input
PROJECT_NAME="${input:-${PROJECT_NAME:-my-midnight-dapp}}"

read -rp "UI directory [$UI_DIR]: " input
UI_DIR="${input:-$UI_DIR}"

read -rp "API directory [$API_DIR]: " input
API_DIR="${input:-$API_DIR}"

read -rp "Contract package [${CONTRACT_PACKAGE:-@${PROJECT_NAME}/contract}]: " input
CONTRACT_PACKAGE="${input:-${CONTRACT_PACKAGE:-@${PROJECT_NAME}/contract}}"

read -rp "Package manager [$PACKAGE_MANAGER]: " input
PACKAGE_MANAGER="${input:-$PACKAGE_MANAGER}"

UI_PACKAGE_NAME="${PROJECT_NAME}-ui"
API_PACKAGE_NAME="${PROJECT_NAME}-api"

echo ""
echo "Scaffolding with:"
echo "  Project:    $PROJECT_NAME"
echo "  UI:         $UI_DIR/ ($UI_PACKAGE_NAME)"
echo "  API:        $API_DIR/ ($API_PACKAGE_NAME)"
echo "  Contract:   $CONTRACT_PACKAGE"
echo "  Pkg mgr:    $PACKAGE_MANAGER"
echo ""

# --- Step 3: Copy and substitute ---

if [ -d "$UI_DIR" ]; then
  echo "Error: Directory '$UI_DIR' already exists." >&2
  exit 1
fi

if [ -d "$API_DIR" ]; then
  echo "Error: Directory '$API_DIR' already exists." >&2
  exit 1
fi

cp -r "$TEMPLATES_DIR/ui" "$UI_DIR"
cp -r "$TEMPLATES_DIR/api" "$API_DIR"

# Run substitution across all files
find "$UI_DIR" "$API_DIR" -type f | while read -r file; do
  if file "$file" | grep -q text; then
    sed -i'' -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" "$file"
    sed -i'' -e "s|{{UI_PACKAGE_NAME}}|$UI_PACKAGE_NAME|g" "$file"
    sed -i'' -e "s|{{API_PACKAGE_NAME}}|$API_PACKAGE_NAME|g" "$file"
    sed -i'' -e "s|{{UI_DIR}}|$UI_DIR|g" "$file"
    sed -i'' -e "s|{{API_DIR}}|$API_DIR|g" "$file"
    sed -i'' -e "s|{{CONTRACT_PACKAGE}}|$CONTRACT_PACKAGE|g" "$file"
    sed -i'' -e "s|{{PACKAGE_MANAGER}}|$PACKAGE_MANAGER|g" "$file"
    # Clean up sed backup files on macOS
    rm -f "${file}-e"
  fi
done

# --- Step 4: Post-scaffold ---

# Add workspaces to root package.json if it exists and has workspaces
if [ -f "package.json" ]; then
  if python3 -c "import json; d=json.load(open('package.json')); exit(0 if 'workspaces' in d else 1)" 2>/dev/null; then
    python3 -c "
import json
with open('package.json', 'r') as f:
    data = json.load(f)
ws = data.get('workspaces', [])
if isinstance(ws, dict):
    ws = ws.get('packages', [])
for d in ['$UI_DIR', '$API_DIR']:
    if d not in ws:
        ws.append(d)
if isinstance(data.get('workspaces'), dict):
    data['workspaces']['packages'] = ws
else:
    data['workspaces'] = ws
with open('package.json', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null || echo "Note: Could not update workspaces in package.json. Add '$UI_DIR' and '$API_DIR' manually."
  fi
fi

echo ""
echo "Done! Next steps:"
echo ""
echo "  1. $PACKAGE_MANAGER install"
echo "  2. Configure copy-contract-keys in $UI_DIR/package.json"
echo "  3. Wire up your contract in $API_DIR/src/index.ts"
echo "  4. cd $UI_DIR && $PACKAGE_MANAGER run dev"
echo ""
```

- [ ] **Step 3: Make init.sh executable**

```bash
chmod +x plugins/midnight-dapp-dev/skills/init/scripts/init.sh
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/init/
git commit -m "feat(midnight-dapp-dev): add init skill with scaffolding script

Derives project config from package.json and lockfiles, confirms
interactively, copies template tree with sed substitution.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 12: Core Skill — SKILL.md + References

**Files:**
- Create: `plugins/midnight-dapp-dev/skills/core/SKILL.md`
- Create: `plugins/midnight-dapp-dev/skills/core/references/provider-patterns.md`
- Create: `plugins/midnight-dapp-dev/skills/core/references/state-management.md`
- Create: `plugins/midnight-dapp-dev/skills/core/references/testing-patterns.md`
- Create: `plugins/midnight-dapp-dev/skills/core/references/vite-config.md`

- [ ] **Step 1: Write core SKILL.md**

Write `plugins/midnight-dapp-dev/skills/core/SKILL.md`:

```markdown
---
name: core
description: >-
  This skill should be used when building a Midnight DApp frontend,
  "create a React component for contract interaction", "set up wallet
  connection", "add a contract state subscription", "configure Vite for
  Midnight", "write tests for a DApp component", "debug wallet connection",
  "provider assembly", "transaction flow in the browser", or working with
  Midnight SDK packages in a Vite + React project.
version: 0.1.0
---

# Midnight DApp Frontend Development

Guidance for building browser-based DApps on the Midnight blockchain using
Vite + React 19 + shadcn + Tailwind v4. For DApp Connector API types,
SDK package details, and provider patterns, consult the reference files
in this skill's `references/` directory.

## Architecture

Every Midnight browser DApp assembles 6 providers from the Lace wallet's
configuration. All network endpoints come from `getConfiguration()` — no
hardcoded URLs.

```
WalletProvider (React Context)
  → connect("undeployed") → ConnectedAPI
  → getConfiguration() → { indexerUri, indexerWsUri, substrateNodeUri, networkId }

MidnightProvidersProvider (React Context)
  → publicDataProvider   ← indexerPublicDataProvider(indexerUri, indexerWsUri)
  → zkConfigProvider     ← FetchZkConfigProvider(window.location.origin)
  → proofProvider        ← httpClientProofProvider(proofServerUri, zkConfigProvider)
  → walletProvider       ← { getCoinPublicKey, getEncryptionPublicKey, balanceTx }
  → midnightProvider     ← { submitTx }
  → privateStateProvider ← in-memory Map
```

The proof server URI is derived from `substrateNodeUri` by replacing port
9944 with 6300. If `serviceUriConfig().proverServerUri` is available, use
that instead.

## Transaction Lifecycle

```
Contract call → UnprovenTransaction
  → proofProvider.proveTx()       (proof server generates ZK proof)
  → walletProvider.balanceTx()    (Lace adds coin inputs, signs)
  → midnightProvider.submitTx()   (Lace broadcasts to node)
  → publicDataProvider observable (indexer confirms on-chain)
```

## Vite Configuration

Midnight SDK requires these Vite plugins for browser compatibility:

1. `@vitejs/plugin-react`
2. `@tailwindcss/vite` — Tailwind v4, CSS-based config (`@import "tailwindcss"`)
3. `vite-plugin-wasm` — WASM support for SDK
4. `vite-plugin-top-level-await`
5. `vite-plugin-node-polyfills` — buffer, process, util, crypto, stream
6. `@originjs/vite-plugin-commonjs`

For detailed configuration, see `references/vite-config.md`.

## State Management

Combine on-chain ledger state with local private state using RxJS
`combineLatest`, expose via React hooks. For patterns and examples,
see `references/state-management.md`.

## Testing

Test wallet connection states, provider assembly, and component rendering
with Vitest + Testing Library. Mock `window.midnight` for wallet tests.
For patterns, see `references/testing-patterns.md`.

## Scaffolding

To scaffold a new UI + API package, invoke `/midnight-dapp-dev:init`.
The init skill copies templates from this skill's `templates/` directory
and substitutes `{{PLACEHOLDER}}` values.

## Templates

The `templates/` directory contains the flat template tree:

- `templates/ui/` — Vite + React 19 + shadcn + Tailwind v4 app with wallet integration
- `templates/api/` — TypeScript SDK layer with provider factory and state observable

## Reference Files

- **`references/provider-patterns.md`** — The 6-provider pattern, wallet-driven config, browser vs Node.js differences
- **`references/state-management.md`** — RxJS combineLatest, derived state, useContractState hook
- **`references/testing-patterns.md`** — Vitest + Testing Library patterns, mocking wallet, testing providers
- **`references/vite-config.md`** — Required plugins, polyfills, Tailwind v4 CSS setup, path aliases
```

- [ ] **Step 2: Write references/provider-patterns.md**

Write `plugins/midnight-dapp-dev/skills/core/references/provider-patterns.md`. Content should cover:
- The 6 providers: what each does, browser vs Node.js implementations
- Wallet-driven configuration via `getConfiguration()`
- Proof server URI derivation from `substrateNodeUri`
- The `createProviders()` factory pattern from the API template
- How `WalletProvider` and `MidnightProvider` delegate to `ConnectedAPI`
- Include DApp Connector API type definitions (InitialAPI, ConnectedAPI, Configuration, ErrorCode) inline since this is the authoritative reference

Target: ~2,000 words. Draw content from the analysis of all 7 repos.

- [ ] **Step 3: Write references/state-management.md**

Write `plugins/midnight-dapp-dev/skills/core/references/state-management.md`. Content should cover:
- RxJS `combineLatest` pattern for public + private state
- The `createStateObservable()` helper from the API template
- `useContractState` hook pattern (subscribe to observable, return React state)
- `retry({ delay: 500 })` for auto-reconnection on WebSocket drops
- React Context nesting: WalletProvider → MidnightProvidersProvider → App
- When to use in-memory vs persistent private state
- Include SDK observable patterns inline (contractStateObservable, watchForDeployTxData)

Target: ~1,500 words.

- [ ] **Step 4: Write references/testing-patterns.md**

Write `plugins/midnight-dapp-dev/skills/core/references/testing-patterns.md`. Content should cover:
- Vitest + Testing Library setup (jsdom environment, setup file)
- Mocking `window.midnight` for wallet connection tests
- Testing connection states: disconnected, connecting, connected, error
- Testing provider assembly with mock `ConnectedAPI`
- Testing components that consume wallet/provider context
- Testing RxJS observable subscriptions in components
- Cross-reference to `devs:react-core` testing patterns

Target: ~1,500 words.

- [ ] **Step 5: Write references/vite-config.md**

Write `plugins/midnight-dapp-dev/skills/core/references/vite-config.md`. Content should cover:
- Full annotated `vite.config.ts` with each plugin explained
- Tailwind v4 setup: `@tailwindcss/vite` plugin, `@import "tailwindcss"` in CSS, no config files
- shadcn `components.json` setup for Tailwind v4
- Node.js polyfills required by Midnight SDK
- Path alias configuration (`@` → `./src`)
- Build target (`esnext`) and why minification is disabled in dev
- Common issues: WASM loading failures, missing polyfills, CommonJS interop

Target: ~1,000 words.

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-dapp-dev/skills/core/SKILL.md \
       plugins/midnight-dapp-dev/skills/core/references/
git commit -m "feat(midnight-dapp-dev): add core skill with reference docs

Provider patterns, state management, testing patterns, and Vite config
references for Midnight DApp frontend development.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 13: Agent

**Files:**
- Create: `plugins/midnight-dapp-dev/agents/dev.md`

- [ ] **Step 1: Write dev.md**

Write `plugins/midnight-dapp-dev/agents/dev.md`:

```markdown
---
name: dev
description: >-
  Use this agent when building or modifying a Midnight DApp frontend —
  scaffolding UI/API packages, wiring contracts to the browser, building
  React components for contract interaction, or debugging wallet/provider/
  transaction issues.

  Example 1: User wants to add a UI — "Add a frontend to my Midnight
  project." The dev agent checks if UI/API packages exist, invokes
  /midnight-dapp-dev:init if needed, then helps wire the contract.

  Example 2: User needs a component — "Create a form to call the mint
  circuit." The dev agent builds a React component with proper wallet
  state, transaction submission, and error handling.

  Example 3: User has a wallet issue — "My wallet won't connect." The
  dev agent debugs the connection flow: extension detection, network ID
  mismatch, authorization errors.

  Example 4: User wants contract wiring — "Wire up my counter contract
  to the API layer." The dev agent imports the compiled contract, fills
  type stubs, and creates circuit call wrappers.
model: sonnet
---

You are a Midnight DApp frontend developer. You build browser-based
applications that connect to Midnight smart contracts via the Lace wallet.

## Skills

Use these skills for domain knowledge:

- `/midnight-dapp-dev:core` — Provider architecture, state management,
  testing patterns, Vite config for Midnight DApps
- `/devs:typescript-core` — TypeScript best practices, strict typing
- `/devs:react-core` — React architecture, hooks, performance
- `/devs:react-components` — Component design, container/presenter,
  composition patterns

## Scaffolding

When a project needs a UI/API package and none exists:

1. Invoke `/midnight-dapp-dev:init` to scaffold the template
2. Report what was created
3. Offer to wire up the contract if one was detected

## Contract Wiring

When connecting a compiled contract to the API layer:

1. Read the contract's managed output to understand its circuits and
   ledger shape
2. Update `api/src/types.ts` with the contract's state types
3. Update `api/src/index.ts` to import the compiled contract and
   implement `deploy()` / `join()` functions
4. Create React hooks or components for each circuit the user needs

## Boundaries

Do NOT:
- Write or modify Compact contracts — defer to compact-core
- Manage Docker/devnet infrastructure — defer to midnight-tooling
- Handle contract compilation — defer to compact-core:compact-deployment
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-dapp-dev/agents/dev.md
git commit -m "feat(midnight-dapp-dev): add dev agent

Uses core, typescript, react-core, and react-components skills.
Can scaffold, wire contracts, build components, debug wallet issues.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 14: Final Validation

- [ ] **Step 1: Verify all files exist**

```bash
find plugins/midnight-dapp-dev -type f | sort
```

Expected output should list all files created in Tasks 1-13.

- [ ] **Step 2: Verify no unsubstituted placeholders in non-template files**

```bash
grep -r '{{' plugins/midnight-dapp-dev --include='*.md' --include='*.json' -l | grep -v templates/
```

Expected: Only `plugins/midnight-dapp-dev/skills/init/SKILL.md` (which documents the placeholders in a table). No other non-template files should contain `{{`.

- [ ] **Step 3: Verify init.sh is executable**

```bash
ls -la plugins/midnight-dapp-dev/skills/init/scripts/init.sh
```

Expected: `-rwxr-xr-x` permissions.

- [ ] **Step 4: Verify plugin.json is valid JSON**

```bash
python3 -c "import json; json.load(open('plugins/midnight-dapp-dev/.claude-plugin/plugin.json'))"
```

Expected: No output (valid JSON).

- [ ] **Step 5: Commit any fixes if needed**

If any issues found in steps 1-4, fix and commit.
