---
name: midnight-dapp-dev:core
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
Vite + React 19 + shadcn + Tailwind v4. This skill is the authoritative
reference for DApp Connector API usage, SDK provider patterns, and
frontend architecture for Midnight.

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

- **`references/provider-patterns.md`** — The 6-provider pattern, wallet-driven config, browser vs Node.js differences, DApp Connector API types
- **`references/state-management.md`** — RxJS combineLatest, derived state, useContractState hook, observable patterns
- **`references/testing-patterns.md`** — Vitest + Testing Library patterns, mocking wallet, testing providers
- **`references/vite-config.md`** — Required plugins, polyfills, Tailwind v4 CSS setup, path aliases
