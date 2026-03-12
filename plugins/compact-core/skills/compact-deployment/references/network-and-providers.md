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
