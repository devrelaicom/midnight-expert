# Building MidnightProviders from DApp Connector in Browser

Reference for assembling the full `MidnightProviders` object in a browser-based DApp using the Lace wallet's DApp Connector API. For the DApp Connector type reference, see `references/connector-api-types.md`. For the Node.js provider pattern using WalletFacade, see `compact-core:compact-deployment`.

## Browser vs Node.js Provider Differences

| Provider | Node.js (CLI) | Browser (DApp Connector) |
|----------|---------------|--------------------------|
| `walletProvider` | Built from `WalletFacade` | Built from `ConnectedAPI` methods |
| `midnightProvider` | Built from `WalletFacade` | Built from `ConnectedAPI.submitTransaction` |
| `zkConfigProvider` | `NodeZkConfigProvider` (filesystem) | `FetchZkConfigProvider` (HTTP fetch) |
| `privateStateProvider` | `levelPrivateStateProvider` (LevelDB) | In-memory or IndexedDB implementation |
| `publicDataProvider` | Same (`indexerPublicDataProvider`) | Same (`indexerPublicDataProvider`) |
| `proofProvider` | Same (`httpClientProofProvider`) | Same, or use `getProvingProvider()` for wallet-delegated proving |

## Complete Browser Provider Assembly

```typescript
"use client";

import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import type {
  MidnightProviders,
  WalletProvider,
  MidnightProvider,
  PrivateStateProvider,
} from "@midnight-ntwrk/midnight-js-types";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";

export async function createBrowserProviders<ICK extends string, PSI extends string, PS>(
  api: ConnectedAPI,
  privateStateProvider: PrivateStateProvider<PSI, PS>,
): Promise<MidnightProviders<ICK, PSI, PS>> {
  // 1. Read configuration from wallet (respects user's network choice)
  const config = await api.getConfiguration();
  setNetworkId(config.networkId);

  // 2. Build public data provider from wallet-provided endpoints
  const publicDataProvider = indexerPublicDataProvider(
    config.indexerUri,
    config.indexerWsUri,
  );

  // 3. Build ZK config provider for browser (fetches via HTTP)
  const zkConfigProvider = new FetchZkConfigProvider<ICK>(
    window.location.origin,
    fetch.bind(window),
  );

  // 4. Build proof provider
  const proofProvider = httpClientProofProvider(
    config.substrateNodeUri.replace(/\/rpc$/, "").replace(/:9944$/, ":6300"),
    zkConfigProvider,
  );

  // 5. Build wallet provider from DApp Connector
  const { shieldedCoinPublicKey, shieldedEncryptionPublicKey } =
    await api.getShieldedAddresses();

  const walletProvider: WalletProvider = {
    getCoinPublicKey: () => shieldedCoinPublicKey,
    getEncryptionPublicKey: () => shieldedEncryptionPublicKey,
    balanceTx: async (tx, newCoins, ttl) => {
      const result = await api.balanceUnsealedTransaction(tx, { newCoins, ttl });
      return result.tx;
    },
  };

  // 6. Build midnight provider from DApp Connector
  const midnightProvider: MidnightProvider = {
    submitTx: async (tx) => {
      await api.submitTransaction(tx);
      // submitTransaction returns void; the txId is already known from the balanced tx
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
```

## FetchZkConfigProvider

In the browser, ZK circuit configurations are loaded via HTTP fetch instead of the filesystem:

```typescript
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";

const zkConfigProvider = new FetchZkConfigProvider<MyCircuits>(
  window.location.origin,  // Base URL for fetching ZK assets
  fetch.bind(window),       // Bound fetch function
);
```

The compiled contract assets (`keys/`, `zkir/`) must be served as static files from the web application. In Next.js 16.x, place them in the `public/` directory:

```
public/
  managed/
    mycontract/
      keys/          # ZK proving/verifying keys
      zkir/          # ZK intermediate representation
      compiler/      # Compiler metadata
```

The `FetchZkConfigProvider` constructs URLs relative to the base URL to load these assets at runtime.

## In-Memory Private State Provider

Browser DApps cannot use LevelDB. Use an in-memory provider for session-scoped private state:

```typescript
import type { PrivateStateProvider } from "@midnight-ntwrk/midnight-js-types";

function inMemoryPrivateStateProvider<PSI extends string, PS>(): PrivateStateProvider<PSI, PS> {
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

For persistent storage across browser sessions, use IndexedDB:

```typescript
import { openDB } from "idb";
import type { PrivateStateProvider } from "@midnight-ntwrk/midnight-js-types";

async function indexedDBPrivateStateProvider<PSI extends string, PS>(
  dbName: string,
): Promise<PrivateStateProvider<PSI, PS>> {
  const db = await openDB(dbName, 1, {
    upgrade(db) {
      db.createObjectStore("privateState");
    },
  });

  return {
    get: async (id: PSI) => {
      const value = await db.get("privateState", id);
      return value ?? null;
    },
    set: async (id: PSI, state: PS) => {
      await db.put("privateState", state, id);
    },
    remove: async (id: PSI) => {
      await db.delete("privateState", id);
    },
  };
}
```

## Wallet-Delegated Proving

Instead of running a local proof server, the wallet can generate proofs:

```typescript
const provingProvider = await api.getProvingProvider({
  getKeyMaterial: async (circuitId: string) => {
    // Return the ZK key material for the given circuit
    const response = await fetch(`/managed/mycontract/keys/${circuitId}.bzkir`);
    return new Uint8Array(await response.arrayBuffer());
  },
});
```

This delegates proof generation to the Lace wallet extension, removing the need for a separate proof server connection from the browser. The wallet manages proving internally.

## Full Integration Example

Combining the DApp Connector with contract deployment in a React 19.x component:

```typescript
"use client";

import { useCallback } from "react";
import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import { MyContract } from "../managed/mycontract/contract/index.js";
import { witnesses } from "../witnesses.js";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";
import { createBrowserProviders, inMemoryPrivateStateProvider } from "../providers.js";

function useContractDeployment(api: ConnectedAPI) {
  const deploy = useCallback(async (initialSecret: Uint8Array) => {
    const privateStateProvider = inMemoryPrivateStateProvider();
    const providers = await createBrowserProviders(api, privateStateProvider);

    const compiledContract = CompiledContract.make("mycontract", MyContract.Contract).pipe(
      CompiledContract.withWitnesses(witnesses),
      CompiledContract.withFetchedFileAssets(window.location.origin),
    );

    const deployed = await deployContract(providers, {
      compiledContract,
      privateStateId: "myContractState",
      initialPrivateState: { secretKey: initialSecret },
    });

    return deployed;
  }, [api]);

  return { deploy };
}
```

## Proof Server Considerations

For browser DApps, the proof server must be accessible from the browser:

| Scenario | Proof Server URL | Notes |
|----------|-----------------|-------|
| Local development | `http://localhost:6300` | Docker proof server on local machine |
| Preview/Preprod | `https://lace-proof-pub.{network}.midnight.network` | Public proof server (shares proof data with server) |
| Privacy-sensitive | `http://localhost:6300` | Run proof server locally even for testnet DApps |

The public proof servers on Preview and Preprod expose proof inputs to the server operator. For production DApps handling sensitive data, run the proof server locally or use wallet-delegated proving via `getProvingProvider()`.
