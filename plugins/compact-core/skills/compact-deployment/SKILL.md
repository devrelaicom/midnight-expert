---
name: compact-deployment
description: This skill should be used when the user asks about deploying Compact contracts to a Midnight network, configuring providers (indexer, node, proof server) and MidnightProviders, setting up wallets (WalletFacade, HD wallet, shielded/unshielded/dust wallets), connecting to Midnight networks (undeployed, preview, preprod), using deployContract or findDeployedContract, configuring the proof server, managing contract addresses, calling deployed circuits via callTx, reading ledger state from an indexer, the deployment lifecycle from compilation to live contract, or troubleshooting deployment errors.
version: 0.1.0
---

# Compact Contract Deployment

This skill covers taking compiled Compact artifacts to a live contract on a Midnight network: provider configuration, wallet setup, contract deployment, and post-deployment interaction. For writing Compact contracts, see `compact-structure`. For TypeScript witness implementation and compiler output, see `compact-witness-ts`.

## Deployment Pipeline

```
Compile          Configure         Deploy            Interact
  |                 |                |                  |
  v                 v                v                  v
compact compile  setNetworkId()   deployContract()   callTx.<name>()
  -> managed/    + 6 providers    -> contractAddress  -> FinalizedTxData
     directory   + wallet setup   findDeployedContract()
```

1. **Compile** — `compact compile` produces `managed/` with contract code, ZK keys, and zkir
2. **Configure** — Set network ID, create wallet, assemble 6 providers
3. **Deploy** — `deployContract()` submits the contract and returns the address
4. **Interact** — `callTx.<circuitName>()` calls circuits; `ledger()` reads state

## Required Packages

| Purpose | Package | Version |
|---------|---------|---------|
| **Contract SDK** | `@midnight-ntwrk/midnight-js-contracts` | 3.0.0 |
| | `@midnight-ntwrk/midnight-js-types` | 3.0.0 |
| | `@midnight-ntwrk/compact-runtime` | 0.14.0 |
| | `@midnight-ntwrk/compact-js` | (match SDK) |
| **Providers** | `@midnight-ntwrk/midnight-js-indexer-public-data-provider` | 3.0.0 |
| | `@midnight-ntwrk/midnight-js-node-zk-config-provider` | 3.0.0 |
| | `@midnight-ntwrk/midnight-js-http-client-proof-provider` | 3.0.0 |
| | `@midnight-ntwrk/midnight-js-level-private-state-provider` | 3.0.0 |
| | `@midnight-ntwrk/midnight-js-network-id` | 3.0.0 |
| **Wallet SDK** | `@midnight-ntwrk/wallet-sdk-facade` | 1.0.0 |
| | `@midnight-ntwrk/wallet-sdk-hd` | 3.0.0 |
| | `@midnight-ntwrk/wallet-sdk-shielded` | 1.0.0 |
| | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | 1.0.0 |
| | `@midnight-ntwrk/wallet-sdk-dust-wallet` | 1.0.0 |
| | `@midnight-ntwrk/wallet-sdk-address-format` | 3.0.0 |
| **Ledger** | `@midnight-ntwrk/ledger` | ^4.0.0 |
| **Utilities** | `ws` | ^8.19.0 |

## Network Endpoints Quick Reference

| Service | Local / Undeployed | Preview | Preprod |
|---------|-------------------|---------|---------|
| **Node RPC** | `http://localhost:9944` | `https://rpc.preview.midnight.network` | `https://rpc.preprod.midnight.network` |
| **Indexer (GraphQL)** | `http://localhost:8088/api/v3/graphql` | `https://indexer.preview.midnight.network/api/v3/graphql` | `https://indexer.preprod.midnight.network/api/v3/graphql` |
| **Indexer (WebSocket)** | `ws://localhost:8088/api/v3/graphql/ws` | `wss://indexer.preview.midnight.network/api/v3/graphql/ws` | `wss://indexer.preprod.midnight.network/api/v3/graphql/ws` |
| **Proof Server** | `http://localhost:6300` | `https://lace-proof-pub.preview.midnight.network` | `https://lace-proof-pub.preprod.midnight.network` |
| **Faucet** | N/A | `https://faucet.preview.midnight.network` | `https://faucet.preprod.midnight.network` |

The proof server should run locally for DApp development (to protect private data). The local network uses the `undeployed` network ID. The local ports match the Lace wallet's "Undeployed" network settings — no custom endpoint configuration required.

## Core Deployment Pattern

```typescript
import { WebSocket } from "ws";
globalThis.WebSocket = WebSocket as unknown as typeof globalThis.WebSocket;

import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";

// 1. Set network (once at startup)
setNetworkId("undeployed"); // or "preview", "preprod"

// 2. Create wallet and providers (see references/wallet-setup.md, references/network-and-providers.md)
const wallet = await createWallet(seed);
const providers = await configureProviders(wallet, config);

// 3. Deploy
const deployed = await deployContract(providers, {
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey },
});

const contractAddress = deployed.deployTxData.public.contractAddress;
console.log(`Deployed at: ${contractAddress}`);

// 4. Call circuits
const txData = await deployed.callTx.myCircuit(arg1, arg2);
console.log(`Tx ${txData.public.txId} in block ${txData.public.blockHeight}`);
```

## Key Types Quick Reference

| Type | Package | Purpose |
|------|---------|---------|
| `MidnightProviders<ICK, PSI, PS>` | `midnight-js-types` | Bundle of all 6 providers |
| `DeployedContract<C>` | `midnight-js-contracts` | Deployed contract with `callTx` and `deployTxData` |
| `FoundContract<C>` | `midnight-js-contracts` | Joined contract (same as deployed but found by address) |
| `CompiledContract` | `compact-js` | Prepared contract with witnesses and ZK assets |
| `ImpureCircuitId<C>` | `compact-js` | Branded circuit key type for type-safe provider generics |
| `ContractAddress` | `compact-runtime` | Hex-encoded contract address string |
| `FinalizedDeployTxData<C>` | `midnight-js-contracts` | Deployment result (contractAddress, txId, blockHeight) |
| `FinalizedCallTxData<C, ICK>` | `midnight-js-contracts` | Circuit call result (txId, blockHeight, status) |
| `WalletProvider` | `midnight-js-types` | balanceTx, getCoinPublicKey, getEncryptionPublicKey |
| `MidnightProvider` | `midnight-js-types` | submitTx |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `globalThis.WebSocket = WebSocket` in Node.js | Add at top of entry point before any SDK imports |
| Proof server not running | Start with `docker run -p 6300:6300 midnightntwrk/proof-server:7.0.0 -- midnight-proof-server -v` |
| Wrong or missing `setNetworkId()` call | Call once at startup before creating providers; must match the network you're connecting to |
| Wallet not funded (DUST balance zero) | Fund with tNight from faucet, register NIGHT UTXOs via `registerForDustGeneration()`, then wait for DUST generation |
| Using `contract` instead of `compiledContract` in deploy options | Use `compiledContract` (created via `CompiledContract.make().pipe(...)`) |
| Using custom npm registry for `@midnight-ntwrk/*` | All `@midnight-ntwrk/*` packages are on **public npm**. Do not add `.npmrc`, `.yarnrc.yml`, or scoped registry config. The `.yarnrc.yml` files in SDK repos are for SDK contributors only — not consumers. |

## Reference Files

| Topic | Reference File |
|-------|---------------|
| Network IDs, environment endpoints, all 6 providers, provider construction, browser differences | `references/network-and-providers.md` |
| HD wallet creation, key derivation, 3 sub-wallets, WalletFacade, funding, DUST mechanics | `references/wallet-setup.md` |
| CompiledContract prep, deployContract, findDeployedContract, callTx, ledger queries, constructor args | `references/deployment-lifecycle.md` |
| WebSocket polyfill, proof server issues, signing workaround, error types, common failures | `references/troubleshooting.md` |
