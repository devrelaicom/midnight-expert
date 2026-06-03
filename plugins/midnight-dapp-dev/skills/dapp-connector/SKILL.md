---
name: midnight-dapp-dev:dapp-connector
description: >-
  This skill should be used when the user asks about connecting a browser-based
  DApp to a Midnight wallet extension (Lace or any other Midnight wallet) using
  the DApp Connector API. Covers the full connection lifecycle (InitialAPI,
  ConnectedAPI, WalletConnectedAPI), multi-wallet detection and enumeration via
  window.midnight, error handling with DAppConnectorAPIError, React 19.x and
  Next.js 16.x wallet integration patterns, building MidnightProviders from the
  DApp Connector, FetchZkConfigProvider, balanceUnsealedTransaction,
  getConfiguration, shielded and unshielded addresses, Lace setup and funding,
  and wallet-delegated proving.
version: 0.1.0
---

# DApp Connector API v4.0.1

This skill covers the Midnight DApp Connector API for browser-based wallet integration: connecting to the Lace wallet extension, using the ConnectedAPI for transactions and balances, handling errors, and building React 19.x / Next.js 16.x DApps. For Node.js CLI deployment with WalletFacade and HD keys, see `midnight-dapp-dev:midnight-sdk`. For contract runtime and witness types, see `compact-core:compact-witness-ts`. For local development network setup, see `midnight-tooling:devnet`.

## Connection Lifecycle

```
window.midnight[walletId]  ->  InitialAPI.connect(networkId)  ->  ConnectedAPI
   (injected per wallet)                                         (WalletConnectedAPI & HintUsage)
```

1. **Detect** -- Enumerate `Object.values(window.midnight)` and match by `name`/`rdns`. Each wallet installs its `InitialAPI` under its own key (a UUID — the API is CAIP-372-compatible), so do not assume a fixed key. Lace also exposes a convenience alias at `window.midnight.mnLace`, but relying on it alone misses other wallets. See the `findWallets()` helper and window augmentation in `references/connector-api-types.md`.
2. **Connect** -- Call `connect(networkId)` with the target network (`"undeployed"`, `"preview"`, or `"preprod"`)
3. **Interact** -- Use the returned `ConnectedAPI` for addresses, balances, transfers, and proving

## InitialAPI

Each wallet extension injects an `InitialAPI` object under its own key in `window.midnight` — a per-wallet UUID, since the API is CAIP-372-compatible. Discover wallets by enumerating and matching on `name`/`rdns`, not by assuming a key. Lace also installs a convenience alias at `window.midnight.mnLace` (Lace-specific, not part of the normative spec):

```typescript
import type { InitialAPI } from "@midnight-ntwrk/dapp-connector-api";

// Robust: enumerate every injected wallet (see findWallets() in references/connector-api-types.md)
const wallets: InitialAPI[] = Object.values(window.midnight ?? {}).filter(
  (w): w is InitialAPI => w != null && typeof w.connect === "function",
);
// Then match by rdns/name or present a wallet picker. Lace-only shortcut:
// const wallet = window.midnight?.mnLace;
```

| Property | Type | Description |
|----------|------|-------------|
| `name` | `string` | Wallet display name |
| `icon` | `string` | Wallet icon URL |
| `apiVersion` | `string` | Semver version of the connector API |
| `rdns` | `string` | Reverse DNS identifier for the wallet |
| `connect(networkId)` | `(networkId: string) => Promise<ConnectedAPI>` | Initiates the connection handshake |

Calling `connect()` triggers the Lace authorization prompt. The user chooses "Always" (persistent across sessions) or "Only once" (single-session permission).

## ConnectedAPI

`ConnectedAPI` is the intersection of `WalletConnectedAPI` and `HintUsage`:

```typescript
type ConnectedAPI = WalletConnectedAPI & HintUsage;
```

### HintUsage

```typescript
interface HintUsage {
  hintUsage(methodNames: Array<keyof WalletConnectedAPI>): Promise<void>;
}
```

Call `hintUsage` to pre-declare which methods the DApp intends to use. This allows the wallet to optimize permission prompts.

### WalletConnectedAPI (16 methods)

| Method | Returns | Purpose |
|--------|---------|---------|
| `getConfiguration()` | `Configuration` | `indexerUri`, `indexerWsUri`, `substrateNodeUri`, `networkId` |
| `getConnectionStatus()` | `ConnectionStatus` | `connected` or `disconnected` |
| `getShieldedAddresses()` | `{shieldedAddress, shieldedCoinPublicKey, shieldedEncryptionPublicKey}` | All Bech32m-encoded |
| `getUnshieldedAddress()` | `{unshieldedAddress}` | Bech32m-encoded |
| `getDustAddress()` | `{dustAddress}` | Bech32m-encoded |
| `getShieldedBalances()` | `Record<string, bigint>` | Token type to balance mapping |
| `getUnshieldedBalances()` | `Record<string, bigint>` | Token type to balance mapping |
| `getDustBalance()` | `{balance, cap}` | Current balance and max cap from NIGHT staking |
| `getTxHistory(page, size)` | `HistoryEntry[]` | `txHash`, `txStatus` per entry |
| `makeTransfer(outputs, options?)` | `{tx}` | Create a balanced transfer transaction |
| `makeIntent(inputs, outputs, options)` | `{tx}` | Create an unbalanced intent for swaps |
| `balanceUnsealedTransaction(tx, options?)` | `{tx}` | Balance a transaction from a contract call |
| `balanceSealedTransaction(tx, options?)` | `{tx}` | Balance a sealed transaction for swap completion |
| `submitTransaction(tx)` | `void` | Submit a balanced and proven transaction |
| `signData(data, options)` | `Signature` | Sign arbitrary data with the unshielded key |
| `getProvingProvider(keyMaterialProvider)` | `ProvingProvider` | Delegate ZK proving to the wallet |

> All WalletConnectedAPI methods are async and return `Promise<...>` wrappers around the types shown above.

### Configuration Object

`getConfiguration()` returns the network endpoints the wallet is connected to:

```typescript
interface Configuration {
  indexerUri: string;       // GraphQL HTTP endpoint
  indexerWsUri: string;     // GraphQL WebSocket endpoint
  substrateNodeUri: string; // Substrate node RPC
  networkId: string;        // "undeployed", "preview", or "preprod"
}
```

Use these values to configure SDK providers instead of hardcoding endpoints. This respects the user's network selection and is the recommended privacy-preserving approach.

## Error Handling

All DApp Connector errors use a discriminated type (not class instances):

```typescript
interface APIError {
  type: "DAppConnectorAPIError";
  code: ErrorCode;
  reason: string;
}

type ErrorCode =
  | "Disconnected"
  | "InternalError"
  | "InvalidRequest"
  | "PermissionRejected"
  | "Rejected";
```

Check errors by type field, not `instanceof`:

```typescript
try {
  const api = await wallet.connect("preview");
} catch (error: unknown) {
  if (
    typeof error === "object" &&
    error !== null &&
    "type" in error &&
    (error as APIError).type === "DAppConnectorAPIError"
  ) {
    const apiError = error as APIError;
    switch (apiError.code) {
      case "PermissionRejected":
        console.error("User rejected the connection request");
        break;
      case "Disconnected":
        console.error("Wallet disconnected");
        break;
      case "InternalError":
        console.error("Wallet internal error:", apiError.reason);
        break;
      case "InvalidRequest":
        console.error("Invalid request:", apiError.reason);
        break;
      case "Rejected":
        console.error("Request rejected:", apiError.reason);
        break;
    }
  }
}
```

**Never use `instanceof` for DApp Connector errors.** The error objects are plain objects serialized across the extension boundary, so `instanceof` checks always fail.

## Lace Wallet Setup

### Installation

1. Install the Lace wallet extension from the Chrome Web Store
2. If using Brave, disable Brave Shields for the DApp origin (shields interfere with extension injection)
3. Open Lace and create a new wallet
4. Save the seed phrase securely -- this is the only way to recover the wallet
5. Set a spending password

### Network Selection

Lace supports three networks:

| Network | Network ID | Use Case |
|---------|-----------|----------|
| Undeployed | `undeployed` | Local development with Docker containers |
| Preview | `preview` | Public testnet for integration testing |
| Preprod | `preprod` | Pre-production testing |

Select the network in Lace settings. The "Undeployed" network connects to `localhost` endpoints matching the local Docker stack.

### Funding

1. Copy the unshielded address from Lace
2. Navigate to the network faucet (e.g., `https://faucet.preview.midnight.network`)
3. Request tDUST tokens
4. Delegate NIGHT tokens in Lace to begin DUST generation
5. Wait for DUST to accumulate (used for transaction fees)

### Authorization Modes

When a DApp calls `connect()`, Lace prompts the user:

- **Always** -- Persistent authorization across browser sessions for this DApp origin
- **Only once** -- Single-session authorization; re-prompts after page refresh or browser restart

## React 19.x Integration Pattern

### Wallet Connection Hook

```typescript
"use client";
import { useState, useCallback, useEffect } from "react";
import type { InitialAPI, ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";

interface WalletState {
  connectedApi: ConnectedAPI | null;
  isConnecting: boolean;
  error: string | null;
}

export function useWalletConnection() {
  const [state, setState] = useState<WalletState>({
    connectedApi: null,
    isConnecting: false,
    error: null,
  });

  const connect = useCallback(async (networkId: string) => {
    setState((prev) => ({ ...prev, isConnecting: true, error: null }));

    const wallet: InitialAPI | undefined = Object.values(
      window.midnight ?? {},
    ).find((w): w is InitialAPI => w != null && typeof w.connect === "function");
    if (!wallet) {
      setState((prev) => ({
        ...prev,
        isConnecting: false,
        error: "No Midnight wallet extension found. Install a Midnight wallet (e.g. Lace) to continue.",
      }));
      return;
    }

    try {
      const api = await wallet.connect(networkId);
      setState({ connectedApi: api, isConnecting: false, error: null });
    } catch (err: unknown) {
      const message =
        typeof err === "object" && err !== null && "reason" in err
          ? (err as { reason: string }).reason
          : "Failed to connect to wallet";
      setState((prev) => ({ ...prev, isConnecting: false, error: message }));
    }
  }, []);

  const disconnect = useCallback(() => {
    setState({ connectedApi: null, isConnecting: false, error: null });
  }, []);

  return { ...state, connect, disconnect };
}
```

### Wallet Balance Component

```typescript
"use client";
import { useState, useEffect } from "react";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";

export function WalletBalances({ api }: { api: ConnectedAPI }) {
  const [shielded, setShielded] = useState<Record<string, bigint>>({});
  const [unshielded, setUnshielded] = useState<Record<string, bigint>>({});

  useEffect(() => {
    const fetchBalances = async () => {
      const [s, u] = await Promise.all([
        api.getShieldedBalances(),
        api.getUnshieldedBalances(),
      ]);
      setShielded(s);
      setUnshielded(u);
    };
    fetchBalances();
  }, [api]);

  return (
    <div>
      <h3>Shielded</h3>
      {Object.entries(shielded).map(([token, balance]) => (
        <p key={token}>{token}: {balance.toString()}</p>
      ))}
      <h3>Unshielded</h3>
      {Object.entries(unshielded).map(([token, balance]) => (
        <p key={token}>{token}: {balance.toString()}</p>
      ))}
    </div>
  );
}
```

## Next.js 16.x Patterns

### Client-Only Wallet Access

The `window` object is undefined during server-side rendering. All wallet access must be in Client Components:

```typescript
"use client";

import { useEffect, useState } from "react";

function WalletDetector() {
  const [walletAvailable, setWalletAvailable] = useState(false);

  useEffect(() => {
    // window.midnight is only available in the browser; enumerate injected wallets
    setWalletAvailable(
      Object.values(window.midnight ?? {}).some(
        (w) => w != null && typeof w.connect === "function",
      ),
    );
  }, []);

  if (!walletAvailable) {
    return <p>Install a Midnight wallet (e.g. Lace) to continue.</p>;
  }

  return <p>Midnight wallet detected.</p>;
}
```

### Dynamic Import for Wallet Modules

For modules that reference `window` at import time, use `next/dynamic` with SSR disabled:

```typescript
import dynamic from "next/dynamic";

const WalletPanel = dynamic(() => import("./WalletPanel"), { ssr: false });
```

### Using getConfiguration() for Provider Endpoints

Instead of hardcoding network endpoints, read them from the wallet's configuration. This ensures the DApp uses the same network the user selected in Lace:

```typescript
"use client";

import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";

async function createProvidersFromWallet(api: ConnectedAPI) {
  const config = await api.getConfiguration();

  const publicDataProvider = indexerPublicDataProvider(
    config.indexerUri,
    config.indexerWsUri,
  );

  // Use config.substrateNodeUri for node connections
  // Use config.networkId for setNetworkId()
  return { publicDataProvider, networkId: config.networkId };
}
```

## Building MidnightProviders from DApp Connector

In the browser, the DApp Connector replaces the Node.js WalletFacade. The `ConnectedAPI` provides the wallet and midnight provider capabilities:

```typescript
import type { WalletProvider, MidnightProvider } from "@midnight-ntwrk/midnight-js-types";
import type { ConnectedAPI } from "@midnight-ntwrk/dapp-connector-api";
import { toHex, fromHex } from "@midnight-ntwrk/midnight-js-utils";
import { Transaction } from "@midnight-ntwrk/ledger-v8";

async function createWalletProvider(api: ConnectedAPI): Promise<WalletProvider> {
  const { shieldedCoinPublicKey, shieldedEncryptionPublicKey } =
    await api.getShieldedAddresses();

  return {
    getCoinPublicKey: () => shieldedCoinPublicKey,
    getEncryptionPublicKey: () => shieldedEncryptionPublicKey,
    // WalletProvider.balanceTx is (tx: UnboundTransaction, ttl?: Date) =>
    // Promise<FinalizedTransaction>. balanceUnsealedTransaction takes/returns
    // serialized hex strings, so serialize in and deserialize out.
    // options is `{ payFees?: boolean }`; an empty `{}` uses the defaults.
    balanceTx: async (tx, _ttl) => {
      const { tx: balancedHex } = await api.balanceUnsealedTransaction(
        toHex(tx.serialize()),
        {},
      );
      return Transaction.deserialize(
        "signature",
        "proof",
        "binding",
        fromHex(balancedHex),
      );
    },
  };
}

function createMidnightProvider(api: ConnectedAPI): MidnightProvider {
  return {
    submitTx: async (tx) => {
      // submitTransaction takes a serialized hex string and returns void;
      // recover the tx id from the transaction's identifiers().
      await api.submitTransaction(toHex(tx.serialize()));
      return tx.identifiers()[0];
    },
  };
}
```

For the complete browser provider assembly including `FetchZkConfigProvider` and in-memory private state, see `references/browser-providers.md`. For the full type reference of all DApp Connector interfaces, see `references/connector-api-types.md`.

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Accessing `window.midnight` during SSR | Guard with `"use client"` directive and `useEffect` or `typeof window !== "undefined"` checks |
| Using `instanceof` for error checking | Check `error.type === "DAppConnectorAPIError"` instead |
| Hardcoding network endpoints | Use `getConfiguration()` to read the wallet's active endpoints |
| Not handling `PermissionRejected` | Users can deny the connection prompt; always handle this error code |
| Forgetting to fund the wallet | Transfer tDUST from faucet and delegate NIGHT for DUST generation before transacting |
| Using Brave without disabling shields | Brave Shields blocks extension injection; disable for the DApp origin |

## Reference Files

| Topic | Reference File |
|-------|---------------|
| Complete type definitions for InitialAPI, ConnectedAPI, WalletConnectedAPI, all method signatures, Configuration, ErrorCode | `references/connector-api-types.md` |
| Full browser provider assembly pattern, FetchZkConfigProvider, in-memory private state, wallet-to-SDK bridge | `references/browser-providers.md` |
