# Provider Setup Reference

Covers the 6-provider bundle, factory functions, network configuration, and how `walletProvider` and `midnightProvider` relate.

---

## The 6-Provider Bundle

Midnight contract operations require six providers. The `Providers` interface bundles them:

```typescript
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";
import type { MidnightProvider, WalletProvider } from "@midnight-ntwrk/midnight-js-types";

export interface Providers {
  privateStateProvider: ReturnType<typeof levelPrivateStateProvider>;
  publicDataProvider: ReturnType<typeof indexerPublicDataProvider>;
  zkConfigProvider: NodeZkConfigProvider<string>;
  proofProvider: ReturnType<typeof httpClientProofProvider>;
  walletProvider: WalletProvider & MidnightProvider;
  midnightProvider: WalletProvider & MidnightProvider;
}
```

| Provider | Package | Purpose |
|----------|---------|---------|
| `privateStateProvider` | `midnight-js-level-private-state-provider` | LevelDB-backed storage for contract private state |
| `publicDataProvider` | `midnight-js-indexer-public-data-provider` | GraphQL client for indexer queries and subscriptions |
| `zkConfigProvider` | `midnight-js-node-zk-config-provider` | Locates compiled ZK circuit files on disk |
| `proofProvider` | `midnight-js-http-client-proof-provider` | HTTP client for the proof server |
| `walletProvider` | Built from `WalletFacade` | balanceTx, getCoinPublicKey, getEncryptionPublicKey |
| `midnightProvider` | Same object as `walletProvider` | submitTx (transaction submission) |

---

## `createProviders()` Factory

The main factory builds all six providers from a `WalletContext`:

```typescript
export async function createProviders(
  facade: WalletFacade,
  shieldedSecretKeys: ledger.ZswapSecretKeys,
  dustSecretKey: ledger.DustSecretKey,
  keystore: UnshieldedKeystore,
  privateStateStoreName: string,
): Promise<Providers> {
  const walletProvider = await createWalletProvider(
    facade, shieldedSecretKeys, dustSecretKey, keystore,
  );

  const zkConfigProvider = new NodeZkConfigProvider(ZK_CONFIG_PATH);

  return {
    privateStateProvider: levelPrivateStateProvider({ privateStateStoreName }),
    publicDataProvider: indexerPublicDataProvider(
      DEVNET_CONFIG.indexer, DEVNET_CONFIG.indexerWS,
    ),
    zkConfigProvider,
    proofProvider: httpClientProofProvider(DEVNET_CONFIG.proofServer, zkConfigProvider),
    walletProvider,
    midnightProvider: walletProvider,
  };
}
```

Usage in a command:

```typescript
const ctx = await buildFacade(walletData.seed);
const providers = await createProviders(
  ctx.facade,
  ctx.shieldedSecretKeys,
  ctx.dustSecretKey,
  ctx.keystore,
  `${CONTRACT_NAME}-private-state`,
);
```

---

## `createWalletProvider()`

Builds the combined `WalletProvider & MidnightProvider` from a synced `WalletFacade`:

```typescript
export async function createWalletProvider(
  facade: WalletFacade,
  shieldedSecretKeys: ledger.ZswapSecretKeys,
  dustSecretKey: ledger.DustSecretKey,
  keystore: UnshieldedKeystore,
): Promise<WalletProvider & MidnightProvider> {
  const state = await Rx.firstValueFrom(facade.state().pipe(Rx.filter((s) => s.isSynced)));

  return {
    getCoinPublicKey: () => state.shielded.coinPublicKey.toHexString(),
    getEncryptionPublicKey: () => state.shielded.encryptionPublicKey.toHexString(),
    async balanceTx(tx, ttl) {
      const recipe = await facade.balanceUnboundTransaction(
        tx,
        { shieldedSecretKeys, dustSecretKey },
        { ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
      );
      return await facade.finalizeRecipe(recipe);
    },
    submitTx: (tx) => facade.submitTransaction(tx),
  } as WalletProvider & MidnightProvider;
}
```

The function waits for the wallet facade to sync before constructing the provider. The `balanceTx` method handles transaction balancing (selecting inputs and computing fees) and finalization.

---

## Network Configuration

All endpoints are hardcoded to the local devnet via `DEVNET_CONFIG`:

```typescript
export const DEVNET_CONFIG: NetworkConfig = {
  indexer: "http://127.0.0.1:8088/api/v3/graphql",
  indexerWS: "ws://127.0.0.1:8088/api/v3/graphql/ws",
  node: "http://127.0.0.1:9944",
  proofServer: "http://127.0.0.1:6300",
  networkId: "undeployed",
};
```

The network ID is set once at command startup via `initializeNetwork()`:

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

export function initializeNetwork(): void {
  setNetworkId(DEVNET_CONFIG.networkId);
}
```

This is called automatically by `BaseCommand.init()`. The `"undeployed"` network ID corresponds to the local devnet and must match the network the wallet was created on.

---

## `walletProvider` and `midnightProvider`

Both fields point to the **same object**. The Midnight SDK requires a `WalletProvider` (for `balanceTx`, `getCoinPublicKey`, `getEncryptionPublicKey`) and a `MidnightProvider` (for `submitTx`). In this CLI template, a single object satisfies both interfaces:

```typescript
return {
  // ...
  walletProvider,
  midnightProvider: walletProvider, // Same object
};
```

This is the standard pattern for Node.js CLIs where one wallet handles both balancing and submission.
