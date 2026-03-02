# compact-deployment Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the `compact-deployment` skill for the compact-core plugin, covering the full deployment pipeline from compiled Compact artifacts to a live contract on a Midnight network.

**Architecture:** Single skill with SKILL.md entry point and 4 reference files (network-and-providers.md, wallet-setup.md, deployment-lifecycle.md, troubleshooting.md). Follows the same patterns as existing compact-core skills: YAML frontmatter, quick reference tables, inline code snippets, and reference routing.

**Tech Stack:** Markdown documentation, TypeScript code examples, Midnight SDK APIs

---

### Task 1: Create SKILL.md

**Files:**
- Create: `plugins/compact-core/skills/compact-deployment/SKILL.md`

**Step 1: Create the directory structure**

Run: `mkdir -p plugins/compact-core/skills/compact-deployment/references`

**Step 2: Write SKILL.md**

Write the following content to `plugins/compact-core/skills/compact-deployment/SKILL.md`:

````markdown
---
name: compact-deployment
description: This skill should be used when the user asks about deploying Compact contracts to a Midnight network, configuring providers (indexer, node, proof server), setting up wallets (WalletFacade, HD wallet, shielded/unshielded/dust wallets), connecting to Midnight networks (undeployed, preview, preprod), using deployContract or findDeployedContract, configuring the proof server, managing contract addresses, calling deployed circuits via callTx, reading ledger state from an indexer, the deployment lifecycle from compilation to live contract, or troubleshooting deployment errors.
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
| **Ledger** | `@midnight-ntwrk/ledger` | ^4.0.0 |
| **Utilities** | `ws` | ^8.19.0 |

## Network Endpoints Quick Reference

| Service | Local / Undeployed | Preview | Preprod |
|---------|-------------------|---------|---------|
| **Node RPC** | `http://localhost:9944` | `https://rpc.preview.midnight.network` | `https://rpc.preprod.midnight.network` |
| **Indexer (GraphQL)** | `http://localhost:8088/api/v3/graphql` | `https://indexer.preview.midnight.network/api/v3/graphql` | `https://indexer.preprod.midnight.network/api/v3/graphql` |
| **Indexer (WebSocket)** | `ws://localhost:8088/api/v3/graphql/ws` | `wss://indexer.preview.midnight.network/api/v3/graphql/ws` | `wss://indexer.preprod.midnight.network/api/v3/graphql/ws` |
| **Proof Server** | `http://localhost:6300` | `http://localhost:6300` | `http://localhost:6300` |
| **Faucet** | N/A | `https://faucet.preview.midnight.network` | `https://faucet.preprod.midnight.network` |

The proof server always runs locally (to protect private data). The local network uses the `undeployed` network ID with the `dev` node preset. The local ports match the Lace wallet's "Undeployed" network settings — no custom endpoint configuration required.

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
| `ContractAddress` | `ledger` | Hex-encoded contract address string |
| `FinalizedDeployTxData<C>` | `midnight-js-contracts` | Deployment result (contractAddress, txId, blockHeight) |
| `FinalizedCallTxData` | `midnight-js-contracts` | Circuit call result (txId, blockHeight, status) |
| `WalletProvider` | `midnight-js-types` | balanceTx, getCoinPublicKey, getEncryptionPublicKey |
| `MidnightProvider` | `midnight-js-types` | submitTx |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `globalThis.WebSocket = WebSocket` in Node.js | Add at top of entry point before any SDK imports |
| Proof server not running | Start with `docker run -p 6300:6300 midnightntwrk/proof-server:7.0.0 -- midnight-proof-server -v` |
| Wrong or missing `setNetworkId()` call | Call once at startup before creating providers; must match the network you're connecting to |
| Wallet not funded (DUST balance zero) | Fund with tNight from faucet, then wait for DUST generation from staked NIGHT |
| Using `contract` instead of `compiledContract` in deploy options | Use `compiledContract` (created via `CompiledContract.make().pipe(...)`) |

## Reference Files

| Topic | Reference File |
|-------|---------------|
| Network IDs, environment endpoints, all 6 providers, provider construction, browser differences | `references/network-and-providers.md` |
| HD wallet creation, key derivation, 3 sub-wallets, WalletFacade, funding, DUST mechanics | `references/wallet-setup.md` |
| CompiledContract prep, deployContract, findDeployedContract, callTx, ledger queries, constructor args | `references/deployment-lifecycle.md` |
| WebSocket polyfill, proof server issues, signing workaround, error types, common failures | `references/troubleshooting.md` |
````

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-deployment/SKILL.md
git commit -m "feat(compact-core): add SKILL.md for compact-deployment"
```

---

### Task 2: Create network-and-providers.md

**Files:**
- Create: `plugins/compact-core/skills/compact-deployment/references/network-and-providers.md`

**Step 1: Write network-and-providers.md**

Write the following content to `plugins/compact-core/skills/compact-deployment/references/network-and-providers.md`:

````markdown
# Network Configuration & Providers

Reference for configuring Midnight network connections and assembling the provider objects required for deployment and interaction. For wallet creation, see `references/wallet-setup.md`. For using providers in deployment, see `references/deployment-lifecycle.md`.

## Network ID Configuration

The network ID must be set **once at startup** before creating any providers or wallet components. It configures cryptographic parameters for the target network:

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

setNetworkId("undeployed"); // Local development
setNetworkId("preview");    // Preview testnet
setNetworkId("preprod");    // Pre-production testnet
```

Calling `setNetworkId` after providers are created leads to cryptographic mismatches. Always call it first.

## Environment Endpoints

### Local / Undeployed

The local network runs three Docker containers on fixed ports:

| Service | Container | URL |
|---------|-----------|-----|
| Midnight Node | `midnight-node` | `http://localhost:9944` |
| Indexer (GraphQL) | `midnight-indexer` | `http://localhost:8088/api/v3/graphql` |
| Indexer (WebSocket) | `midnight-indexer` | `ws://localhost:8088/api/v3/graphql/ws` |
| Proof Server | `midnight-proof-server` | `http://localhost:6300` |

These ports match the Lace wallet extension's "Undeployed" network settings. Select "Undeployed" in Lace and it connects to `localhost:9944`, `localhost:8088`, and `localhost:6300` automatically.

Network ID: `undeployed`. Node preset: `dev`.

### Preview

| Service | URL |
|---------|-----|
| Node RPC | `https://rpc.preview.midnight.network` |
| Indexer (GraphQL) | `https://indexer.preview.midnight.network/api/v3/graphql` |
| Indexer (WebSocket) | `wss://indexer.preview.midnight.network/api/v3/graphql/ws` |
| Proof Server | `http://localhost:6300` (always local) |
| Faucet | `https://faucet.preview.midnight.network` |

### Preprod

| Service | URL |
|---------|-----|
| Node RPC | `https://rpc.preprod.midnight.network` |
| Indexer (GraphQL) | `https://indexer.preprod.midnight.network/api/v3/graphql` |
| Indexer (WebSocket) | `wss://indexer.preprod.midnight.network/api/v3/graphql/ws` |
| Proof Server | `http://localhost:6300` (always local) |
| Faucet | `https://faucet.preprod.midnight.network` |

### Configuration Object Pattern

A common pattern for managing environment-specific endpoints:

```typescript
export interface NetworkConfig {
  readonly indexer: string;
  readonly indexerWS: string;
  readonly node: string;
  readonly proofServer: string;
}

const standaloneConfig: NetworkConfig = {
  indexer: "http://127.0.0.1:8088/api/v3/graphql",
  indexerWS: "ws://127.0.0.1:8088/api/v3/graphql/ws",
  node: "http://127.0.0.1:9944",
  proofServer: "http://127.0.0.1:6300",
};

const previewConfig: NetworkConfig = {
  indexer: "https://indexer.preview.midnight.network/api/v3/graphql",
  indexerWS: "wss://indexer.preview.midnight.network/api/v3/graphql/ws",
  node: "https://rpc.preview.midnight.network",
  proofServer: "http://127.0.0.1:6300",
};

const preprodConfig: NetworkConfig = {
  indexer: "https://indexer.preprod.midnight.network/api/v3/graphql",
  indexerWS: "wss://indexer.preprod.midnight.network/api/v3/graphql/ws",
  node: "https://rpc.preprod.midnight.network",
  proofServer: "http://127.0.0.1:6300",
};
```

## The MidnightProviders Object

Deployment and interaction require a `MidnightProviders` bundle containing 6 providers:

```typescript
import type { MidnightProviders } from "@midnight-ntwrk/midnight-js-types";

const providers: MidnightProviders<MyCircuits, typeof PrivateStateId, MyPrivateState> = {
  privateStateProvider,  // Persists off-chain contract state locally
  publicDataProvider,    // Fetches on-chain state from the indexer
  zkConfigProvider,      // Loads ZK circuit configurations from compiled assets
  proofProvider,         // Communicates with the proof server to generate proofs
  walletProvider,        // Handles transaction balancing and signing
  midnightProvider,      // Submits finalized transactions to the node
};
```

### privateStateProvider

Manages local off-chain state that witnesses access. Uses LevelDB for persistence:

```typescript
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";

const privateStateProvider = levelPrivateStateProvider<typeof PrivateStateId, MyPrivateState>({
  privateStateStoreName: "my-contract-private-state",
  signingKeyStoreName: "my-contract-signing-keys",
  privateStoragePasswordProvider: () => "your-encryption-password",
});
```

The `privateStateStoreName` creates a LevelDB database on disk. Each contract type should use a unique store name. The `privateStoragePasswordProvider` encrypts the stored state.

### publicDataProvider

Connects to the indexer for on-chain state queries and event subscriptions:

```typescript
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";

const publicDataProvider = indexerPublicDataProvider(
  config.indexer,   // GraphQL HTTP URL
  config.indexerWS, // GraphQL WebSocket URL
);
```

This provider enables:
- `queryContractState(address)` — fetch current contract state
- `watchForDeployTxData(...)` — wait for deployment confirmation
- `contractStateObservable(address)` — subscribe to state changes

### zkConfigProvider

Loads ZK circuit configurations from the compiled contract assets:

```typescript
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";

// Points to the managed/<contract-name> directory
const zkConfigProvider = new NodeZkConfigProvider<MyCircuits>(
  "src/managed/mycontract",
);
```

The type parameter `MyCircuits` is a union of circuit key strings (e.g., `"increment" | "decrement"`). Use the `ImpureCircuitId` type from `@midnight-ntwrk/compact-js` for type safety:

```typescript
import type { ImpureCircuitId } from "@midnight-ntwrk/compact-js";
import { MyContract } from "./managed/mycontract/contract/index.js";

type MyCircuits = ImpureCircuitId<MyContract.Contract<MyPrivateState>>;
```

### proofProvider

Communicates with the proof server to generate ZK proofs:

```typescript
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";

const proofProvider = httpClientProofProvider(config.proofServer, zkConfigProvider);
```

The proof server must be running before any deployment or circuit call. It exposes `/check` and `/prove` endpoints on port 6300.

### walletProvider & midnightProvider

These two providers handle transaction lifecycle — balancing (adding fee inputs/outputs) and submission. They share the same underlying wallet object:

```typescript
interface WalletProvider {
  getCoinPublicKey(): string;
  getEncryptionPublicKey(): string;
  balanceTx(
    tx: UnprovenTransaction,
    newCoins?: ShieldedCoinInfo[],
    ttl?: Date,
  ): Promise<BalancedProvingRecipe>;
}

interface MidnightProvider {
  submitTx(tx: FinalizedTransaction): Promise<TransactionId>;
}
```

These are typically built from the `WalletFacade` — see `references/wallet-setup.md` for the full wallet-to-provider bridge.

## Provider Construction Pattern

The canonical pattern assembles all providers from a wallet context and network config:

```typescript
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";

export const configureProviders = async (
  walletAndMidnightProvider: WalletProvider & MidnightProvider,
  config: NetworkConfig,
): Promise<MidnightProviders<MyCircuits, typeof PrivateStateId, MyPrivateState>> => {
  const zkConfigProvider = new NodeZkConfigProvider<MyCircuits>("src/managed/mycontract");

  return {
    privateStateProvider: levelPrivateStateProvider({
      privateStateStoreName: "my-contract-private-state",
      signingKeyStoreName: "my-contract-signing-keys",
      privateStoragePasswordProvider: () => "encryption-password",
    }),
    publicDataProvider: indexerPublicDataProvider(config.indexer, config.indexerWS),
    zkConfigProvider,
    proofProvider: httpClientProofProvider(config.proofServer, zkConfigProvider),
    walletProvider: walletAndMidnightProvider,
    midnightProvider: walletAndMidnightProvider,
  };
};
```

## Browser Differences

For browser-based DApps (with Lace wallet), the following providers change:

| Provider | Node.js | Browser |
|----------|---------|---------|
| `zkConfigProvider` | `NodeZkConfigProvider` (filesystem) | `FetchZkConfigProvider` (HTTP fetch) |
| `privateStateProvider` | `levelPrivateStateProvider` (LevelDB) | In-memory or IndexedDB provider |
| `walletProvider` / `midnightProvider` | Built from `WalletFacade` | Built from Lace DApp connector API |

Browser ZK config provider:

```typescript
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";

const zkConfigProvider = new FetchZkConfigProvider<MyCircuits>(
  window.location.origin,
  fetch.bind(window),
);
```

Browser wallet connection (via Lace DApp connector):

```typescript
const midnight = window.midnight?.mnLace;
if (!midnight) throw new Error("Lace wallet extension not found");

const walletState = await midnight.enable();
// walletState provides coinPublicKey, encryptionPublicKey, balanceTransaction, submitTransaction
```
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-deployment/references/network-and-providers.md
git commit -m "feat(compact-core): add network-and-providers reference for compact-deployment"
```

---

### Task 3: Create wallet-setup.md

**Files:**
- Create: `plugins/compact-core/skills/compact-deployment/references/wallet-setup.md`

**Step 1: Write wallet-setup.md**

Write the following content to `plugins/compact-core/skills/compact-deployment/references/wallet-setup.md`:

````markdown
# Wallet Setup

Reference for creating and configuring Midnight wallets for contract deployment. The wallet handles key management, transaction balancing, signing, and fee payment. For provider assembly, see `references/network-and-providers.md`. For using the wallet in deployment, see `references/deployment-lifecycle.md`.

## Wallet Architecture

Midnight uses a composite wallet made of three sub-wallets, combined via `WalletFacade`:

| Sub-Wallet | Package | Purpose |
|------------|---------|---------|
| `ShieldedWallet` | `@midnight-ntwrk/wallet-sdk-shielded` | Manages shielded (private) coin UTXOs, ZSwap operations |
| `UnshieldedWallet` | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | Manages unshielded (public) NIGHT token balances |
| `DustWallet` | `@midnight-ntwrk/wallet-sdk-dust-wallet` | Manages DUST fee tokens generated from staked NIGHT |

`WalletFacade` from `@midnight-ntwrk/wallet-sdk-facade` composes these into a unified wallet that handles transaction balancing across all three token types.

## Seed Management

### Generating a New Seed

```typescript
import { generateRandomSeed } from "@midnight-ntwrk/wallet-sdk-hd";

const seed: string = generateRandomSeed(); // Returns hex-encoded seed string
```

**Store the seed securely.** It derives all wallet keys. Loss of the seed means loss of funds.

### Restoring from Existing Seed

```typescript
const seed = "your-saved-hex-seed-string";
```

## HD Key Derivation

Midnight uses hierarchical deterministic (HD) key derivation to produce separate keys for each wallet role:

```typescript
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";

const hdWallet = HDWallet.fromSeed(Buffer.from(seed, "hex"));

const derivedKeys = hdWallet.hdWallet
  .selectAccount(0)
  .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
  .deriveKeysAt(0);

const keys = derivedKeys.keys;
// keys[Roles.Zswap]          -> Uint8Array (shielded wallet key material)
// keys[Roles.NightExternal]  -> Uint8Array (unshielded wallet key material)
// keys[Roles.Dust]           -> Uint8Array (dust wallet key material)
```

The three roles correspond to the three sub-wallets:
- **`Roles.Zswap`** — Derives shielded coin keys (coin public key, encryption key)
- **`Roles.NightExternal`** — Derives the unshielded NIGHT wallet keystore
- **`Roles.Dust`** — Derives the DUST fee token key

## Secret Key Construction

Each sub-wallet requires keys derived from the HD wallet:

```typescript
import * as ledger from "@midnight-ntwrk/ledger";
import { createKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

// Shielded wallet keys (ZSwap coin operations)
const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys[Roles.Zswap]);

// Dust wallet key (fee token)
const dustSecretKey = ledger.DustSecretKey.fromSeed(keys[Roles.Dust]);

// Unshielded wallet keystore (NIGHT token)
const unshieldedKeystore = createKeystore(keys[Roles.NightExternal], getNetworkId());
```

## Sub-Wallet Configuration

### ShieldedWallet

Manages private coin UTXOs and ZSwap operations:

```typescript
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";

const shieldedWallet = ShieldedWallet({
  networkId: getNetworkId(),
  indexerClientConnection: {
    indexerHttpUrl: config.indexer,
    indexerWsUrl: config.indexerWS,
  },
  provingServerUrl: new URL(config.proofServer),
  relayURL: new URL(config.node.replace(/^http/, "ws")),
}).startWithSecretKeys(shieldedSecretKeys);
```

### UnshieldedWallet

Manages public NIGHT token balances:

```typescript
import {
  UnshieldedWallet,
  PublicKey,
  InMemoryTransactionHistoryStorage,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";

const unshieldedWallet = UnshieldedWallet({
  networkId: getNetworkId(),
  indexerClientConnection: {
    indexerHttpUrl: config.indexer,
    indexerWsUrl: config.indexerWS,
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(),
}).startWithPublicKey(PublicKey.fromKeyStore(unshieldedKeystore));
```

### DustWallet

Manages DUST fee tokens generated from staked NIGHT:

```typescript
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";

const dustWallet = DustWallet({
  networkId: getNetworkId(),
  costParameters: {
    additionalFeeOverhead: 300_000_000_000_000n,
    feeBlocksMargin: 5,
  },
  indexerClientConnection: {
    indexerHttpUrl: config.indexer,
    indexerWsUrl: config.indexerWS,
  },
  provingServerUrl: new URL(config.proofServer),
  relayURL: new URL(config.node.replace(/^http/, "ws")),
}).startWithSecretKey(dustSecretKey, ledger.LedgerParameters.initialParameters().dust);
```

The `costParameters` control fee estimation:
- `additionalFeeOverhead` — Extra fee buffer (in smallest units) to prevent underpayment
- `feeBlocksMargin` — Number of blocks ahead to estimate fees for

## WalletFacade Composition

Combine the three sub-wallets into a unified wallet:

```typescript
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";

const wallet = new WalletFacade(shieldedWallet, unshieldedWallet, dustWallet);
await wallet.start(shieldedSecretKeys, dustSecretKey);
```

After `start()`, the wallet synchronizes with the blockchain. Wait for sync before deploying:

```typescript
// Wait for wallet to sync with blockchain state
await wallet.waitForSync();
```

## Wallet-to-Provider Bridge

The `walletProvider` and `midnightProvider` are built from the wallet facade. Both interfaces are typically implemented by the same object:

```typescript
const walletAndMidnightProvider = {
  // WalletProvider interface
  getCoinPublicKey: () =>
    shieldedSecretKeys.coinPublicKey.toHexString(),

  getEncryptionPublicKey: () =>
    shieldedSecretKeys.encryptionPublicKey.toHexString(),

  balanceTx: async (
    tx: UnprovenTransaction,
    newCoins?: ShieldedCoinInfo[],
    ttl?: Date,
  ): Promise<BalancedProvingRecipe> => {
    const recipe = await wallet.balanceUnboundTransaction(
      tx,
      { shieldedSecretKeys, dustSecretKey },
      { ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
    );

    // Workaround: sign transaction intents manually
    // (see references/troubleshooting.md for details)
    signTransactionIntents(recipe.baseTransaction, signFn, "proof");
    if (recipe.balancingTransaction) {
      signTransactionIntents(recipe.balancingTransaction, signFn, "pre-proof");
    }

    return wallet.finalizeRecipe(recipe);
  },

  // MidnightProvider interface
  submitTx: (tx: FinalizedTransaction): Promise<TransactionId> =>
    wallet.submitTransaction(tx),
};
```

The `signFn` comes from the unshielded keystore:

```typescript
const signFn = (payload: Uint8Array) =>
  unshieldedKeystore.signData(payload);
```

## Funding

### Test Network Funding

On Preview and Preprod, get tNight tokens from the faucet:

1. Get your wallet address from the unshielded wallet
2. Visit the faucet URL (see network endpoints in `references/network-and-providers.md`)
3. Request tNight tokens
4. Wait for the transaction to confirm

### DUST Token Mechanics

DUST is a non-transferable fee token. It is generated by staking NIGHT tokens:

1. **Receive NIGHT** — From faucet or another wallet
2. **NIGHT is automatically staked** — The wallet SDK handles registration
3. **DUST accrues over time** — Generated from staked NIGHT each block
4. **DUST pays transaction fees** — All contract deployments and circuit calls require DUST

Check DUST balance:

```typescript
const state = await wallet.state();
const dustBalance = state.dust.walletBalance(new Date());
```

If DUST balance is zero after receiving NIGHT, wait a few blocks for dust generation to begin.

### Local Network

On the local (`undeployed`) network, the dev node preset provides pre-funded accounts. Seed management and faucet funding are typically not needed for local development.
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-deployment/references/wallet-setup.md
git commit -m "feat(compact-core): add wallet-setup reference for compact-deployment"
```

---

### Task 4: Create deployment-lifecycle.md

**Files:**
- Create: `plugins/compact-core/skills/compact-deployment/references/deployment-lifecycle.md`

**Step 1: Write deployment-lifecycle.md**

Write the following content to `plugins/compact-core/skills/compact-deployment/references/deployment-lifecycle.md`:

````markdown
# Deployment Lifecycle

Reference for the contract deployment and interaction workflow: preparing compiled contracts, deploying them, joining existing deployments, and calling circuits. For provider setup, see `references/network-and-providers.md`. For wallet configuration, see `references/wallet-setup.md`.

## CompiledContract Preparation

Before deploying, wrap the compiler-generated Contract class with its ZK assets using `CompiledContract` from `@midnight-ntwrk/compact-js`:

```typescript
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import { MyContract } from "./managed/mycontract/contract/index.js";
import { witnesses } from "./witnesses.js";

const myCompiledContract = CompiledContract.make("mycontract", MyContract.Contract).pipe(
  CompiledContract.withWitnesses(witnesses),
  CompiledContract.withCompiledFileAssets("src/managed/mycontract"),
);
```

The pipeline:
1. **`CompiledContract.make(name, ContractClass)`** — Creates a compiled contract wrapper
2. **`.withWitnesses(witnesses)`** — Binds witness implementations (or use `.withVacantWitnesses` if the contract has no witnesses)
3. **`.withCompiledFileAssets(path)`** — Points to the `managed/<name>` directory containing `keys/`, `zkir/`, `compiler/`, and `contract/`

### Contracts Without Witnesses

If the contract has no `witness` declarations:

```typescript
const compiled = CompiledContract.make("mycontract", MyContract.Contract).pipe(
  CompiledContract.withVacantWitnesses,
  CompiledContract.withCompiledFileAssets("src/managed/mycontract"),
);
```

## Type Aliases

Define type aliases for type-safe provider and contract references:

```typescript
import type { ImpureCircuitId } from "@midnight-ntwrk/compact-js";
import type { MidnightProviders } from "@midnight-ntwrk/midnight-js-types";
import type { DeployedContract, FoundContract } from "@midnight-ntwrk/midnight-js-contracts";

// Circuit keys union type
type MyCircuits = ImpureCircuitId<MyContract.Contract<MyPrivateState>>;

// Provider type alias
type MyProviders = MidnightProviders<MyCircuits, typeof PrivateStateId, MyPrivateState>;

// Contract type alias (works for both deployed and found)
type DeployedMyContract = DeployedContract<MyContract.Contract<MyPrivateState>>
  | FoundContract<MyContract.Contract<MyPrivateState>>;
```

## deployContract()

Deploys a new contract to the network:

```typescript
import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";

const deployed = await deployContract(providers, {
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey: mySecretKey },
});
```

### Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `compiledContract` | `CompiledContract` | Yes | Prepared contract with witnesses and ZK assets |
| `privateStateId` | `string` | Yes | Key for the private state provider store |
| `initialPrivateState` | `PS` | Yes | Initial off-chain state for witnesses |

### Return Value

`deployContract` returns a `DeployedContract<C>` object:

```typescript
// Transaction metadata
deployed.deployTxData.public.contractAddress  // ContractAddress (hex string)
deployed.deployTxData.public.txId             // TransactionId
deployed.deployTxData.public.blockHeight      // bigint
deployed.deployTxData.public.txHash           // string

// Circuit call methods
deployed.callTx.myCircuit(arg1, arg2)         // Promise<FinalizedCallTxData>

// Private deployment data
deployed.deployTxData.private.signingKey       // Signing key for this contract
deployed.deployTxData.private.initialPrivateState  // The initial private state
```

### Error Handling

`deployContract` throws `DeployTxFailedError` if the transaction is submitted but fails on-chain:

```typescript
import { DeployTxFailedError } from "@midnight-ntwrk/midnight-js-contracts";

try {
  const deployed = await deployContract(providers, options);
} catch (error) {
  if (error instanceof DeployTxFailedError) {
    console.error("Deployment failed on-chain:", error.message);
  }
  throw error;
}
```

## findDeployedContract()

Joins an existing contract by its address. This subscribes to the indexer and watches until the contract is found:

```typescript
import { findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";

const found = await findDeployedContract(providers, {
  contractAddress: "0xabc123...",
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey: mySecretKey },
});
```

### Options

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `contractAddress` | `ContractAddress` | Yes | On-chain hex address of the deployed contract |
| `compiledContract` | `CompiledContract` | Yes | Same compiled contract used for deployment |
| `privateStateId` | `string` | Yes | Key for the private state provider store |
| `initialPrivateState` | `PS` | Yes | Initial off-chain state (each joiner has their own) |

### Return Value

Returns a `FoundContract<C>` with the same `callTx` interface as `DeployedContract`:

```typescript
found.callTx.myCircuit(arg1)  // Same interface as deployed
found.deployTxData.public.contractAddress
```

`findDeployedContract` is used when:
- A second user joins a contract deployed by someone else
- An application reconnects to a previously deployed contract
- Testing multi-party scenarios

## Calling Circuits

After deployment or joining, call exported circuits via the `callTx` object:

```typescript
// No arguments
const txData = await deployed.callTx.increment();

// With arguments
const txData = await deployed.callTx.transfer(recipientKey, 100n);

// Access result metadata
console.log(`Tx: ${txData.public.txId}`);
console.log(`Block: ${txData.public.blockHeight}`);
```

Each `callTx` method:
1. Constructs the circuit call transaction
2. Calls witnesses to provide private inputs
3. Generates a ZK proof via the proof server
4. Balances the transaction (adds fee inputs/outputs)
5. Submits to the node
6. Waits for on-chain confirmation

### Error Handling for Circuit Calls

```typescript
import { CallTxFailedError } from "@midnight-ntwrk/midnight-js-contracts";

try {
  const txData = await deployed.callTx.myCircuit();
} catch (error) {
  if (error instanceof CallTxFailedError) {
    console.error("Circuit call failed:", error.message);
  }
}
```

## Reading Ledger State

Query on-chain contract state through the indexer:

```typescript
import { MyContract } from "./managed/mycontract/contract/index.js";

// One-time query
const contractState = await providers.publicDataProvider.queryContractState(contractAddress);

if (contractState != null) {
  const ledgerState = MyContract.ledger(contractState.data);
  console.log(`Counter: ${ledgerState.counter}`);
  console.log(`Owner: ${Buffer.from(ledgerState.owner).toString("hex")}`);
}
```

### Observable State Changes

Subscribe to state updates in real-time:

```typescript
import { map } from "rxjs";

providers.publicDataProvider
  .contractStateObservable(contractAddress, { type: "latest" })
  .pipe(
    map((contractState) => MyContract.ledger(contractState.data)),
  )
  .subscribe((ledgerState) => {
    console.log(`Updated counter: ${ledgerState.counter}`);
  });
```

Only `export ledger` fields are visible through the `ledger()` function. Non-exported ledger fields are not accessible from TypeScript.

## Constructor Arguments

If a Compact contract has a `constructor`, its arguments are passed at deployment time. Constructors are used to initialize `sealed ledger` fields (immutable after deployment):

```compact
// Compact contract
export sealed ledger admin: Bytes<32>;
export ledger threshold: Uint<64>;

constructor(initial_threshold: Uint<64>) {
  admin = disclose(get_public_key(local_secret_key()));
  threshold = initial_threshold;
}
```

Constructor arguments are passed in the deployment options as additional positional arguments after the standard options:

```typescript
const deployed = await deployContract(providers, {
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey },
  args: [1000n],  // initial_threshold
});
```

## Contract Address Management

The contract address is a hex-encoded string returned after deployment:

```typescript
const address = deployed.deployTxData.public.contractAddress;

// Save for later use
import * as fs from "fs";
fs.writeFileSync("deployment.json", JSON.stringify({
  contractAddress: address,
  deployedAt: new Date().toISOString(),
  network: "preprod",
}, null, 2));

// Load and rejoin
const saved = JSON.parse(fs.readFileSync("deployment.json", "utf-8"));
const found = await findDeployedContract(providers, {
  contractAddress: saved.contractAddress,
  compiledContract: myCompiledContract,
  privateStateId: "myContractState",
  initialPrivateState: { secretKey },
});
```

Contract addresses are deterministic based on the deployment transaction. The same contract deployed twice produces different addresses.
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-deployment/references/deployment-lifecycle.md
git commit -m "feat(compact-core): add deployment-lifecycle reference for compact-deployment"
```

---

### Task 5: Create troubleshooting.md

**Files:**
- Create: `plugins/compact-core/skills/compact-deployment/references/troubleshooting.md`

**Step 1: Write troubleshooting.md**

Write the following content to `plugins/compact-core/skills/compact-deployment/references/troubleshooting.md`:

````markdown
# Deployment Troubleshooting

Common errors and their solutions when deploying and interacting with Compact contracts. For provider setup details, see `references/network-and-providers.md`. For wallet configuration, see `references/wallet-setup.md`.

## WebSocket Polyfill (Node.js)

**Symptom:** `ReferenceError: WebSocket is not defined` or indexer subscriptions fail silently.

**Cause:** Node.js does not have a built-in `WebSocket` global. The indexer provider uses GraphQL subscriptions over WebSocket.

**Fix:** Add at the top of your entry point, before any SDK imports:

```typescript
import { WebSocket } from "ws";
globalThis.WebSocket = WebSocket as unknown as typeof globalThis.WebSocket;
```

This is only needed in Node.js environments. Browsers have `WebSocket` natively.

## Proof Server Not Running

**Symptom:** `Error: connect ECONNREFUSED 127.0.0.1:6300` or proof generation hangs indefinitely.

**Cause:** The proof server Docker container is not running. All ZK proof generation requires the proof server.

**Fix:** Start the proof server:

```bash
docker run -p 6300:6300 midnightntwrk/proof-server:7.0.0 -- midnight-proof-server -v
```

Verify it is running:

```bash
curl http://localhost:6300/check
```

The proof server always runs locally, even when connecting to remote networks (Preview, Preprod). This protects private witness data from being transmitted over the network.

## Transaction Signing Workaround

**Symptom:** Transactions fail with signing-related errors, or `signRecipe` produces incorrect signatures for proven transactions.

**Cause:** A known issue in the wallet SDK where `signRecipe` hardcodes `'pre-proof'` as the proof marker instead of using `'proof'` for already-proven transactions.

**Fix:** Use the `signTransactionIntents` helper in your `balanceTx` implementation:

```typescript
import * as ledger from "@midnight-ntwrk/ledger";

function signTransactionIntents(
  tx: { intents?: Map<number, any> },
  signFn: (payload: Uint8Array) => ledger.Signature,
  proofMarker: "proof" | "pre-proof",
): void {
  if (!tx.intents || tx.intents.size === 0) return;

  for (const segment of tx.intents.keys()) {
    const intent = tx.intents.get(segment);
    if (!intent) continue;

    const cloned = ledger.Intent.deserialize<
      ledger.SignatureEnabled,
      ledger.Proofish,
      ledger.PreBinding
    >("signature", proofMarker, "pre-binding", intent.serialize());

    const sigData = cloned.signatureData(segment);
    const signature = signFn(sigData);

    // Sign all fallible and guaranteed unshielded offers
    for (const [offerIdx] of cloned.fallibleUnshieldedOffers.entries()) {
      cloned.signFallibleUnshieldedOffer(offerIdx, signature);
    }
    for (const [offerIdx] of cloned.guaranteedUnshieldedOffers.entries()) {
      cloned.signGuaranteedUnshieldedOffer(offerIdx, signature);
    }

    tx.intents.set(segment, cloned);
  }
}
```

Call this in your `balanceTx` implementation:

```typescript
// In the walletProvider.balanceTx implementation:
signTransactionIntents(recipe.baseTransaction, signFn, "proof");
if (recipe.balancingTransaction) {
  signTransactionIntents(recipe.balancingTransaction, signFn, "pre-proof");
}
```

## Wrong Network ID

**Symptom:** Cryptographic operations fail, transactions are rejected, or wallet sync produces garbage data.

**Cause:** `setNetworkId()` was called with the wrong value, or was not called before creating providers.

**Fix:** Ensure `setNetworkId()` is called **once, before any other SDK calls**:

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

// Must match the network you're connecting to
setNetworkId("undeployed"); // local Docker network
setNetworkId("preview");    // Preview testnet
setNetworkId("preprod");    // Pre-production testnet
```

Verify with:

```typescript
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
console.log(`Current network: ${getNetworkId()}`);
```

## Insufficient Funds

**Symptom:** `Error: Insufficient DUST balance` or transaction balancing fails.

**Cause:** The wallet does not have enough DUST tokens to pay transaction fees.

**Fix:**

1. **Get tNight from faucet** (test networks only):
   - Preview: `https://faucet.preview.midnight.network`
   - Preprod: `https://faucet.preprod.midnight.network`

2. **Wait for DUST generation:** DUST accrues from staked NIGHT over time. After receiving NIGHT, wait several blocks for DUST to begin accumulating.

3. **Check balance:**
   ```typescript
   const state = await wallet.state();
   const dustBalance = state.dust.walletBalance(new Date());
   console.log(`DUST balance: ${dustBalance}`);
   ```

## Deployment Timeout

**Symptom:** `deployContract` or `findDeployedContract` hangs indefinitely.

**Cause:** The indexer WebSocket subscription is not receiving events. Common causes:
- Incorrect indexer WebSocket URL
- Firewall blocking WebSocket connections
- Indexer service is down or not synced

**Fix:**

1. Verify the indexer is reachable:
   ```bash
   curl -X POST <indexer-graphql-url> \
     -H "Content-Type: application/json" \
     -d '{"query": "{ __typename }"}'
   ```

2. Check the WebSocket URL uses `ws://` (local) or `wss://` (remote), not `http://`

3. Ensure `globalThis.WebSocket` is set (see WebSocket Polyfill section above)

## Contract Not Found

**Symptom:** `findDeployedContract` never resolves or throws an error.

**Cause:** The contract address is incorrect, the contract was deployed on a different network, or the indexer has not yet indexed the deployment block.

**Fix:**

1. Verify the contract address is a valid hex string
2. Confirm you are connected to the same network where the contract was deployed
3. Ensure `setNetworkId()` matches the deployment network
4. Wait for the indexer to catch up — it may lag behind the node

## Error Types Reference

| Error Type | Package | Cause |
|-----------|---------|-------|
| `DeployTxFailedError` | `midnight-js-contracts` | Deployment transaction submitted but failed on-chain |
| `CallTxFailedError` | `midnight-js-contracts` | Circuit call transaction failed on-chain |
| `TxFailedError` | `midnight-js-contracts` | Base error class for transaction failures |
| `ContractTypeError` | `midnight-js-contracts` | Contract type mismatch between compiled and on-chain |
| `InsertVerifierKeyTxFailedError` | `midnight-js-contracts` | Verifier key submission failed |

All transaction errors include the `txId` and `blockHeight` where the failure occurred. Check the node logs or indexer for detailed failure reasons.
````

**Step 2: Commit**

```bash
git add plugins/compact-core/skills/compact-deployment/references/troubleshooting.md
git commit -m "feat(compact-core): add troubleshooting reference for compact-deployment"
```

---

### Task 6: Update plugin.json with deployment keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Add deployment keywords to plugin.json**

Add these keywords to the existing `keywords` array in `plugins/compact-core/.claude-plugin/plugin.json`:

```json
"deploy",
"deployment",
"deployContract",
"findDeployedContract",
"providers",
"MidnightProviders",
"wallet-setup",
"WalletFacade",
"proof-server",
"indexer-provider",
"network-id",
"contract-address",
"callTx",
"preprod",
"preview",
"undeployed-network"
```

**Step 2: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add deployment keywords to plugin.json"
```

---

### Task 7: Validate the plugin

**Step 1: Validate plugin structure**

Use the plugin-validator agent to check that:
- `plugin.json` is valid JSON with all required fields
- All skill directories have `SKILL.md` files
- All reference files exist and are properly linked
- YAML frontmatter in SKILL.md has `name` and `description`

**Step 2: Fix any validation issues found**

If the validator reports issues, fix them and amend the relevant commit.
