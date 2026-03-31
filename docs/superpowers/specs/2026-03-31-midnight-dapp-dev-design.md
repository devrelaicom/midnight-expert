# midnight-dapp-dev Plugin Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Author:** Aaron Bassett + Claude

## Overview

A Claude Code plugin that scaffolds and helps build Midnight DApp frontends. It provides a flat template tree for a Vite + React 19 + shadcn + Tailwind v4 UI package and a TypeScript API package, an init skill that copies and configures templates via shell script, a development agent for ongoing work, and reference documentation covering Midnight DApp patterns.

## Plugin Structure

```
plugins/midnight-dapp-dev/
  .claude-plugin/plugin.json
  skills/
    core/
      SKILL.md
      references/
        provider-patterns.md
        state-management.md
        testing-patterns.md
        vite-config.md
      templates/
        ui/
          ...
        api/
          ...
    init/
      SKILL.md
      scripts/
        init.sh
  agents/
    dev/
      AGENT.md
```

## Components

### 1. Skill: `midnight-dapp-dev:core`

The knowledge base. SKILL.md covers:

- The 6-provider architecture pattern (privateStateProvider, publicDataProvider, zkConfigProvider, proofProvider, walletProvider, midnightProvider)
- Wallet-driven configuration via `getConfiguration()` — all endpoints sourced from Lace, no hardcoded URLs
- State management: RxJS `combineLatest` of public ledger state + private state, derived state, React hook integration
- Transaction lifecycle: build → prove → balance → sign → submit
- Testing patterns for Midnight DApps (Vitest + Testing Library)
- Vite configuration requirements (WASM, polyfills, Tailwind v4 with `@tailwindcss/vite`)

Reference files in `references/` provide deeper detail on each topic, keeping SKILL.md lean.

The `templates/` directory contains the flat file tree used by the init skill (see Sections 4 and 5).

### 2. Skill: `midnight-dapp-dev:init`

Scaffolding skill. SKILL.md instructs Claude to run `${CLAUDE_SKILL_ROOT}/scripts/init.sh`.

**Trigger phrases:** "scaffold a Midnight DApp", "initialize a DApp UI", "add a frontend to my Midnight project", "create a DApp UI package", "set up a Midnight web app", or `/midnight-dapp-dev:init`.

**init.sh behavior:**

**Step 1 — Derive values from project context:**
- Read `name` from root `package.json` → derive project name
- Scan for directories containing `.compact` files or `managed/` output → derive contract package name from its `package.json`
- Check for existing `workspaces` config in root `package.json` → derive where to place `ui/` and `api/` directories
- Detect package manager from lockfile presence (`package-lock.json` → npm, `yarn.lock` → yarn, `pnpm-lock.yaml` → pnpm)

**Step 2 — Confirm with user (interactive prompts):**

Each prompt shows the derived value as default. User presses enter to accept or types an override. If a value cannot be derived, the prompt requests it directly.

```
Detected project: "my-midnight-dapp"
  Project name: my-midnight-dapp [enter to confirm, or type new value]
  UI directory: ui [enter to confirm]
  API directory: api [enter to confirm]
  Contract package: @my-midnight-dapp/contract [enter to confirm]
  Package manager: npm [enter to confirm]
```

**Step 3 — Copy template tree + substitute:**
- Copy `templates/ui/` and `templates/api/` to the target locations (resolved relative to the core skill via `../core/templates/`)
- Run `sed`-based placeholder substitution across all copied files
- If a value was empty (e.g., no contract package), leave `// TODO:` comments instead of broken imports

**Step 4 — Post-scaffold:**
- Add `ui/` and `api/` to root `package.json` workspaces if the project uses workspaces
- Print next steps to stdout

**What the script does NOT do:**
- Install dependencies
- Run `shadcn init` (pre-configured in template via `components.json`)
- Start dev servers

### 3. Agent: `midnight-dapp-dev:dev`

Development agent for building and maintaining Midnight DApp frontends.

**Skills:**
- `midnight-dapp-dev:core`
- `devs:typescript-core` (from aaronbassett/agent-foundry)
- `devs:react-core` (from aaronbassett/agent-foundry)
- `devs:react-components` (from aaronbassett/agent-foundry)

**Can invoke:** `/midnight-dapp-dev:init`

**Capabilities:**
- Detect whether UI/API packages exist in the current project
- Invoke init if scaffolding is needed
- Wire up a contract to the API layer (import compiled contract, fill type stubs, create circuit call wrappers)
- Build new React components that interact with contracts (forms, status displays, transaction buttons)
- Add new hooks for contract-specific state subscriptions
- Write and update tests
- Debug wallet connection, provider assembly, or transaction flow issues

**Out of scope for this agent:**
- Writing or modifying Compact contracts (compact-core's domain)
- Managing Docker/devnet infrastructure (midnight-tooling's domain)
- Contract compilation (compact-core:compact-deployment's domain)

**Trigger description:** Use when building or modifying a Midnight DApp frontend — scaffolding UI/API packages, wiring contracts to the browser, building React components for contract interaction, or debugging wallet/provider/transaction issues.

## Template: UI Package

The `templates/ui/` directory produces a working Vite + React 19 + shadcn + Tailwind v4 app with Midnight wallet integration.

### Build & Config Files

- **`package.json`** — Dependencies: React 19, `@midnight-ntwrk/*` SDK packages (dapp-connector-api, midnight-js-contracts, midnight-js-types, midnight-js-network-id, midnight-js-fetch-zk-config-provider, midnight-js-http-client-proof-provider, midnight-js-indexer-public-data-provider), `@tailwindcss/vite`, shadcn primitives, RxJS, Vitest + @testing-library/react. Scripts: `dev`, `build`, `test`, `copy-contract-keys`. The `copy-contract-keys` script is a placeholder that the developer configures with the path to their contract's compiled `keys/` and `zkir/` output (e.g., `cp -r ../contract/dist/managed/*/keys/* ./public/keys && cp -r ../contract/dist/managed/*/zkir/* ./public/zkir`).
- **`vite.config.ts`** — Plugins: `@vitejs/plugin-react`, `@tailwindcss/vite`, `vite-plugin-wasm`, `vite-plugin-top-level-await`, `vite-plugin-node-polyfills`, `@originjs/vite-plugin-commonjs`. Path alias: `@` → `./src`.
- **`tsconfig.json`** — Strict mode, `@/*` path mapping.
- **`components.json`** — shadcn config for Tailwind v4 CSS setup.
- **`index.html`** — Minimal shell.
- **`vitest.config.ts`** — jsdom environment, Testing Library setup.

### Styles

- **`src/index.css`** — `@import "tailwindcss";` plus shadcn CSS variables. No `tailwind.config.js` or `postcss.config.js` (Tailwind v4 CSS-based configuration).

### App Shell

- **`src/main.tsx`** — Renders `<App />`, sets up Pino logging.
- **`src/App.tsx`** — Provider nesting: `<WalletProvider>` → `<MidnightProvidersProvider>` → main layout with wallet widget.

### Providers

- **`src/providers/wallet-context.tsx`** — React context wrapping Lace connection. Polls `window.midnight.mnLace`, calls `connect("undeployed")`, exposes `ConnectedAPI`, connection status, addresses, error state. Auto-connect via localStorage flag.
- **`src/providers/midnight-providers.tsx`** — Builds the 6 MidnightProviders from wallet's `getConfiguration()`. All endpoints wallet-driven. Exposes providers via React context.

### Hooks

- **`src/hooks/use-wallet.ts`** — Convenience hook consuming WalletContext.
- **`src/hooks/use-contract-state.ts`** — Generic hook that subscribes to an RxJS `Observable<T>` and returns React state. Template pattern for contract state subscriptions.

### Components

- **`src/components/ui/`** — shadcn primitives (button, card, badge, etc.).
- **`src/components/wallet-widget.tsx`** — Connect/disconnect button, shows truncated address when connected.
- **`src/components/network-badge.tsx`** — Displays current network from wallet config.
- **`src/components/proof-server-status.tsx`** — Health check indicator for the proof server.

### Tests

- **`src/__tests__/App.test.tsx`** — Smoke test: app renders without crashing.
- **`src/__tests__/wallet-context.test.tsx`** — Tests wallet connection states (disconnected, connecting, connected, error).
- **`src/__tests__/midnight-providers.test.tsx`** — Tests provider assembly from mock wallet config.

### Intentionally Absent

- No contract interaction components (user plugs in their own)
- No routing (single page — user adds router when needed)
- No example pages beyond the shell with wallet widget

## Template: API Package

The `templates/api/` directory produces a thin TypeScript SDK layer bridging the wallet/providers to contract interaction.

### Files

- **`package.json`** — Dependencies: `@midnight-ntwrk/midnight-js-contracts`, `@midnight-ntwrk/midnight-js-types`, `@midnight-ntwrk/midnight-js-network-id`, `rxjs`. Peer dependency on `{{CONTRACT_PACKAGE}}`. Scripts: `build`, `test`.
- **`tsconfig.json`** — Strict mode, composite project references.
- **`src/index.ts`** — Main export:
  - `createProviders()` — Factory taking a `ConnectedAPI`, calling `getConfiguration()`, building all 6 providers, calling `setNetworkId()`.
  - `deployContract()` / `joinContract()` — Typed stubs with `// TODO:` comments showing the exact wiring pattern.
  - `createStateObservable()` — Generic helper returning an RxJS observable combining public ledger state with private state via `combineLatest`.
- **`src/types.ts`** — Placeholder types: `AppProviders`, `ContractState`, `PrivateState`, `DerivedState`. Empty interfaces the developer fills with their contract's shapes.
- **`src/private-state.ts`** — In-memory `PrivateStateProvider` implementation (Map-based). Ready to use, no placeholders.

## Placeholder Variables

| Placeholder | Derived From | Example |
|---|---|---|
| `{{PROJECT_NAME}}` | Root `package.json` `name` field | `my-midnight-dapp` |
| `{{UI_PACKAGE_NAME}}` | `{{PROJECT_NAME}}-ui` | `my-midnight-dapp-ui` |
| `{{API_PACKAGE_NAME}}` | `{{PROJECT_NAME}}-api` | `my-midnight-dapp-api` |
| `{{UI_DIR}}` | Workspace convention or default `ui` | `ui` |
| `{{API_DIR}}` | Workspace convention or default `api` | `api` |
| `{{CONTRACT_PACKAGE}}` | Scan for Compact `managed/` output, read its `package.json` | `@my-midnight-dapp/contract` |
| `{{PACKAGE_MANAGER}}` | Lockfile detection | `npm` |

If a value cannot be derived and the user provides no input, the substitution leaves `// TODO:` comments instead of broken imports.

## Network Support

**Undeployed only** (for now). The wallet is set to "Undeployed" in Lace settings, and `getConfiguration()` returns local endpoints. No network selector in the UI — the app displays the current network from wallet config but does not allow switching.

## Technology Stack

| Layer | Choice |
|---|---|
| Build tool | Vite |
| UI framework | React 19 |
| Component library | shadcn |
| Styling | Tailwind CSS v4 (`@tailwindcss/vite` plugin, CSS-based config) |
| State management | RxJS observables + React context |
| Testing | Vitest + @testing-library/react |
| Wallet | Lace (via `@midnight-ntwrk/dapp-connector-api`) |
| Logging | Pino |

## Vite Plugin Stack

Required for Midnight SDK browser compatibility:

1. `@vitejs/plugin-react`
2. `@tailwindcss/vite`
3. `vite-plugin-wasm`
4. `vite-plugin-top-level-await`
5. `vite-plugin-node-polyfills` (buffer, process, util, crypto, stream)
6. `@originjs/vite-plugin-commonjs`

## Runtime Architecture

```
Lace Wallet (window.midnight.mnLace)
    │
    ├── connect("undeployed") → ConnectedAPI
    │
    ├── getConfiguration() → { indexerUri, indexerWsUri, substrateNodeUri, networkId }
    │
    └── Provider Assembly:
        ├── publicDataProvider   ← indexerPublicDataProvider(indexerUri, indexerWsUri)
        ├── zkConfigProvider     ← FetchZkConfigProvider(window.location.origin)
        ├── proofProvider        ← httpClientProofProvider(proofServerUri, zkConfigProvider)
        │                          proofServerUri derived from substrateNodeUri (port 9944 → 6300)
        │                          or from serviceUriConfig().proverServerUri if available
        ├── walletProvider       ← { getCoinPublicKey, getEncryptionPublicKey, balanceTx }
        ├── midnightProvider     ← { submitTx }
        └── privateStateProvider ← in-memory Map
```

The proof server URI is not directly in `getConfiguration()`. The template derives it from `substrateNodeUri` (replacing port 9944 with 6300), consistent with the pattern observed across all analyzed DApp repos. If the connector API version provides `serviceUriConfig().proverServerUri`, that takes precedence.

## React Context Hierarchy

```
<WalletProvider>              — Lace connection, addresses, status, auto-connect
  <MidnightProvidersProvider> — 6 providers assembled from wallet config
    <App />                   — Layout, wallet widget, network badge, proof server status
```

## Transaction Lifecycle

```
Contract call (deployContract / callTx.circuitName)
    → UnprovenTransaction
    → proofProvider.proveTx()        [proof server generates ZK proof]
    → walletProvider.balanceTx()     [Lace adds coin inputs, signs]
    → midnightProvider.submitTx()    [Lace broadcasts to node]
    → publicDataProvider observable  [indexer confirms on-chain]
```

## Dependencies on Other Plugins

The `midnight-dapp-dev:dev` agent uses skills from `aaronbassett/agent-foundry`:
- `devs:typescript-core`
- `devs:react-core`
- `devs:react-components`

The plugin itself has no `extends-plugin.json` dependencies — the agent references external skills by qualified name.
