# Design: compact-deployment Skill

**Date:** 2026-02-28
**Plugin:** compact-core
**Status:** Approved

## Problem

The compact-core plugin covers the Compact language comprehensively (7 skills), and the most recent skill (`compact-witness-ts`) explicitly scoped out "DApp infrastructure (wallet setup, providers, proof server, indexer)" and "Contract deployment and interaction (deployContract, findDeployedContract, callTx)" as a separate future skill. This is that skill.

Developers who have compiled a Compact contract and implemented their TypeScript witnesses currently have no skill guidance for the next step: getting their contract onto a running Midnight network. This gap covers provider configuration, wallet creation, network selection, contract deployment, and post-deployment interaction.

## Scope

**In scope:**
- Network configuration (`setNetworkId`, endpoint URLs for undeployed/preview/preprod)
- The MidnightProviders object and all 6 provider implementations
- Wallet creation (HD wallet, key derivation, 3 sub-wallets, WalletFacade)
- Wallet funding (faucet, DUST token mechanics)
- CompiledContract preparation (`CompiledContract.make`, withWitnesses, withCompiledFileAssets)
- Contract deployment (`deployContract`, options, return types)
- Joining existing contracts (`findDeployedContract`)
- Post-deployment interaction (`callTx`, ledger state queries, observables)
- Contract address management
- Constructor arguments for sealed fields
- Common errors and troubleshooting

**Out of scope:**
- Compact language syntax (covered by compact-structure, compact-language-ref)
- Writing witness functions (covered by compact-witness-ts)
- Privacy patterns (covered by compact-privacy-disclosure)
- Token operations at the Compact level (covered by compact-tokens)
- Building full DApp UIs (React integration, routing, etc.)
- CI/CD deployment pipelines

## Approach: Deployment Pipeline

Organized around the linear deployment pipeline that mirrors the developer's workflow:

**Compile → Configure Providers → Deploy Contract → Interact**

SKILL.md gives the overview with quick references; 4 reference files provide depth on each concern.

## Skill Identity

- **Name:** `compact-deployment`
- **Location:** `plugins/compact-core/skills/compact-deployment/`
- **Trigger description:** "This skill should be used when the user asks about deploying Compact contracts, configuring providers, setting up wallets, connecting to Midnight networks, using deployContract or findDeployedContract, configuring proof servers or indexers, managing contract addresses, or the deployment lifecycle from compilation to live contract."

## File Structure

```
plugins/compact-core/skills/compact-deployment/
├── SKILL.md
└── references/
    ├── network-and-providers.md
    ├── wallet-setup.md
    ├── deployment-lifecycle.md
    └── troubleshooting.md
```

## SKILL.md Content

1. **Opening paragraph** — One-sentence positioning: bridges compiled artifacts to a live contract
2. **Deployment Pipeline Overview** — Visual of 4-stage pipeline (Compile → Configure → Deploy → Interact) with one-line descriptions
3. **Required Packages Table** — ~15 NPM packages grouped by purpose (contract SDK, providers, wallet SDK, utilities)
4. **Network Endpoints Quick Reference** — Three-column table (Local/Undeployed | Preview | Preprod) for all services (node, indexer GraphQL, indexer WS, proof server, faucet)
5. **Core Deployment Pattern** — Minimal but complete ~20-30 line code example showing the happy path
6. **Key Types Quick Reference** — Table of important types (MidnightProviders, DeployedContract, FoundContract, CompiledContract, ContractAddress, FinalizedDeployTxData, FinalizedCallTxData)
7. **Common Mistakes** — 3-5 bullets (missing WebSocket polyfill, proof server not running, wrong network ID, unfunded wallet)
8. **Reference Routing Table** — Which reference file covers which topics
9. **Cross-references** — Links to compact-witness-ts and compact-structure

## Reference Files

### network-and-providers.md

Infrastructure configuration covering:
- Network ID configuration — `setNetworkId()`, valid IDs, when to call
- Environment endpoints — Full URLs for all 3 environments (local, preview, preprod)
- The MidnightProviders interface — All 6 providers with their purposes
- Individual provider setup:
  - `privateStateProvider` — levelPrivateStateProvider config
  - `publicDataProvider` — indexerPublicDataProvider with GraphQL/WS URLs
  - `zkConfigProvider` — NodeZkConfigProvider pointing to compiled assets
  - `proofProvider` — httpClientProofProvider connecting to proof server
  - `walletProvider` — Interface (getCoinPublicKey, getEncryptionPublicKey, balanceTx)
  - `midnightProvider` — Interface (submitTx)
- Provider construction pattern — Canonical `configureProviders()` function
- Browser differences — FetchZkConfigProvider, DApp connector wallet, in-memory state

### wallet-setup.md

Wallet creation and key management covering:
- Wallet architecture — 3 sub-wallets (Shielded, Unshielded, Dust) via WalletFacade
- Seed management — generateRandomSeed(), storage, restoration
- HD key derivation — HDWallet.fromSeed(), account/role selection, deriveKeysAt()
- Secret key construction — ZswapSecretKeys, DustSecretKey, createKeystore
- Sub-wallet configuration and start — Config objects, start methods
- WalletFacade composition — Construction, starting, sync waiting
- Wallet-to-provider bridge — Building walletProvider/midnightProvider from facade, signTransactionIntents workaround
- Funding — Balance checks, faucet usage, DUST mechanics (NIGHT staking → DUST generation)

### deployment-lifecycle.md

Deploy-and-interact workflow covering:
- CompiledContract preparation — CompiledContract.make(), withWitnesses/withVacantWitnesses, withCompiledFileAssets, zkConfigPath convention
- Type aliases — CounterCircuits, CounterProviders, DeployedCounterContract patterns
- deployContract() — Full signature, options, return type, contractAddress access
- findDeployedContract() — Joining by address, options, how it watches blockchain
- Calling circuits — callTx.<name>(), passing arguments, return type
- Reading ledger state — queryContractState(), parsing with ledger(), observables
- Constructor arguments — Sealed fields → deploy args mapping
- Contract address management — Type, saving/loading, validation

### troubleshooting.md

Common errors and solutions covering:
- WebSocket polyfill — `globalThis.WebSocket = WebSocket` in Node.js
- Proof server not running — Connection refused, Docker start command
- Transaction signing bug — signTransactionIntents workaround code
- Wrong network ID — Symptoms, verification
- Insufficient funds — DUST errors, faucet URLs, dust generation wait
- Deployment timeout — Indexer subscription issues
- Contract not found — findDeployedContract failures, address format
- Error types reference — Table of SDK errors with causes and fixes

## Plugin Integration

**Keywords to add to plugin.json:** `"deploy"`, `"deployment"`, `"deployContract"`, `"findDeployedContract"`, `"providers"`, `"MidnightProviders"`, `"wallet-setup"`, `"WalletFacade"`, `"proof-server"`, `"indexer-provider"`, `"network-id"`, `"contract-address"`, `"callTx"`, `"preprod"`, `"preview"`, `"undeployed-network"`

**Cross-references from this skill:**
- `compact-witness-ts` — for understanding compiled artifacts and witness implementations
- `compact-structure` — for constructors and sealed fields that affect deployment args

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Single skill for full pipeline | Deployment is one workflow; splitting fractures the mental model |
| Classic `deployContract` API primary | All official examples use it; Effect API mentioned briefly |
| Node.js primary, browser noted | CLI is the first deployment experience; browser variants noted in providers reference |
| Inline code snippets only | Deployment is procedural; inline annotated code teaches better than separate example files |
| 4 reference files | Clean separation: infrastructure, wallet, lifecycle, troubleshooting |
| Pipeline-organized SKILL.md | Mirrors the developer's actual workflow post-compilation |

## Research Sources

- Official Midnight docs: deploy-mn-app guide, environment endpoints, SDK reference
- Example DApps: counter (counter-cli/src/api.ts, config.ts), bboard (bboard-cli/src/index.ts)
- Midnight testkit: testkit-js/src/contract/providers.ts
- SDK packages: midnight-js-contracts, midnight-js-types, compact-js, wallet-sdk-facade
- Midnight MCP server: TypeScript search, docs search, example listings
- Counter example: CompiledContract patterns, ImpureCircuitId types
- Wallet SDK: HDWallet, ShieldedWallet, UnshieldedWallet, DustWallet composition
