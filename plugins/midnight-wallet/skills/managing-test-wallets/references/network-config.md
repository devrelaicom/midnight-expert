# Network configuration

`DefaultConfiguration` is the configuration object passed to
`WalletFacade.init`. The shape is the same across networks; only the
URLs and the `networkId` change.

## Per-network endpoints

### `undeployed` (local devnet)

```typescript
import { InMemoryTransactionHistoryStorage } from '@midnight-ntwrk/wallet-sdk-abstractions';
import { WalletEntrySchema, type DefaultConfiguration } from '@midnight-ntwrk/wallet-sdk-facade';

const configuration: DefaultConfiguration = {
  networkId: 'undeployed',
  costParameters: { feeBlocksMargin: 5 },
  relayURL: new URL('ws://localhost:9944'),
  provingServerUrl: new URL('http://localhost:6300'),
  indexerClientConnection: {
    indexerHttpUrl: 'http://localhost:8088/api/v3/graphql',
    indexerWsUrl: 'ws://localhost:8088/api/v3/graphql/ws',
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
};
```

### `preprod`

```typescript
const configuration: DefaultConfiguration = {
  networkId: 'preprod',
  costParameters: { feeBlocksMargin: 5 },
  relayURL: new URL('wss://rpc.preprod.midnight.network'),
  provingServerUrl: new URL('http://localhost:6300'),  // proof server runs locally
  indexerClientConnection: {
    indexerHttpUrl: 'https://indexer.preprod.midnight.network/api/v3/graphql',
    indexerWsUrl: 'wss://indexer.preprod.midnight.network/api/v3/graphql/ws',
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
};
```

### `preview`

```typescript
const configuration: DefaultConfiguration = {
  networkId: 'preview',
  costParameters: { feeBlocksMargin: 5 },
  relayURL: new URL('wss://rpc.preview.midnight.network'),
  provingServerUrl: new URL('http://localhost:6300'),
  indexerClientConnection: {
    indexerHttpUrl: 'https://indexer.preview.midnight.network/api/v3/graphql',
    indexerWsUrl: 'wss://indexer.preview.midnight.network/api/v3/graphql/ws',
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
};
```

## Node WebSocket polyfill

Node 20 lacks a global `WebSocket`; the SDK requires one for indexer
subscriptions. Add the polyfill at the top of any Node script:

```typescript
import WebSocket from 'ws';
(globalThis as any).WebSocket = WebSocket;
```

This is unnecessary in browsers.

## ESM project requirement

The `@midnight-ntwrk/wallet-sdk-*` packages are published as ESM. Your
`package.json` must include `"type": "module"`. CommonJS consumers fail
with `ERR_PACKAGE_PATH_NOT_EXPORTED`.

## Network ID setter (DApp SDK)

If your project also uses `@midnight-ntwrk/midnight-js-network-id`, call
`setNetworkId(networkId)` once at startup so the DApp SDK's helpers know
which network they are operating against.
