# Provider Patterns

Every Midnight browser DApp assembles exactly 6 providers before it can deploy
or interact with a contract. These providers are the bridge between the browser
environment, the Lace wallet extension, the Midnight indexer, and the proof
server. This document is the authoritative reference for how they work, how they
are configured, and how they differ between browser and Node.js environments.

## The 6 Providers

### 1. publicDataProvider

**Purpose:** Reads on-chain contract state from the Midnight indexer.

**Interface:** `PublicDataProvider` from `@midnight-ntwrk/midnight-js-types`.

**Browser implementation:** Created via `indexerPublicDataProvider()` from
`@midnight-ntwrk/midnight-js-indexer-public-data-provider`. Takes two
arguments: `indexerUri` (HTTP endpoint for queries) and `indexerWsUri`
(WebSocket endpoint for real-time state subscriptions).

```typescript
import { indexerPublicDataProvider } from '@midnight-ntwrk/midnight-js-indexer-public-data-provider';

const publicDataProvider = indexerPublicDataProvider(
  config.indexerUri,
  config.indexerWsUri,
);
```

The WebSocket connection enables `contractStateObservable()`, which pushes
state updates whenever a transaction modifies the contract's public ledger.
This is the primary mechanism for keeping the UI in sync with on-chain state.

### 2. zkConfigProvider

**Purpose:** Loads the zero-knowledge circuit configuration (`.zkir` files)
needed to construct and verify proofs.

**Interface:** `ZkConfigProvider` from `@midnight-ntwrk/midnight-js-types`.

**Browser implementation:** Created via `FetchZkConfigProvider` from
`@midnight-ntwrk/midnight-js-fetch-zk-config-provider`. In the browser,
circuit files are served as static assets from the application's origin.

```typescript
import { FetchZkConfigProvider } from '@midnight-ntwrk/midnight-js-fetch-zk-config-provider';

const zkConfigProvider = new FetchZkConfigProvider<ContractCircuits>(
  window.location.origin,
  fetch,
);
```

The generic type parameter corresponds to your contract's circuit identifiers.
The provider fetches `.zkir` files from the application's public directory at
runtime.

### 3. proofProvider

**Purpose:** Generates zero-knowledge proofs for transactions by communicating
with a proof server.

**Interface:** `ProofProvider` from `@midnight-ntwrk/midnight-js-types`.

**Browser implementation:** Created via `httpClientProofProvider()` from
`@midnight-ntwrk/midnight-js-http-client-proof-provider`. Takes the proof
server URI and a `zkConfigProvider` instance.

```typescript
import { httpClientProofProvider } from '@midnight-ntwrk/midnight-js-http-client-proof-provider';

const proofProvider = httpClientProofProvider(proofServerUri, zkConfigProvider);
```

The proof server is a separate process that performs the computationally
intensive ZK proof generation. In the browser, proof generation is delegated
to this server via HTTP requests rather than running locally.

### 4. walletProvider

**Purpose:** Provides cryptographic keys and transaction balancing. This is
the provider that bridges the Lace wallet's signing capabilities into the
Midnight SDK's transaction pipeline.

**Interface:** `WalletProvider` from `@midnight-ntwrk/midnight-js-types`.

**Browser implementation:** Assembled manually from the `ConnectedAPI`
returned by the Lace wallet extension.

```typescript
const walletProvider: WalletProvider = {
  getCoinPublicKey: () => connectedApi.getShieldedAddresses().then((addrs) => addrs[0]),
  getEncryptionPublicKey: () => connectedApi.getShieldedAddresses().then((addrs) => addrs[0]),
  balanceTx: (tx, newCoins) =>
    connectedApi.balanceUnsealedTransaction(serialize(tx), newCoins),
};
```

The `balanceTx` method is critical: it takes an unbalanced transaction, sends
it to Lace, which adds the necessary coin inputs to cover fees and signs the
transaction. The `serialize` call converts the SDK's internal transaction
representation to the format Lace expects.

### 5. midnightProvider

**Purpose:** Submits signed, balanced, proven transactions to the Midnight
network.

**Interface:** `MidnightProvider` from `@midnight-ntwrk/midnight-js-types`.

**Browser implementation:** Delegates directly to the Lace wallet's
`submitTransaction` method.

```typescript
const midnightProvider: MidnightProvider = {
  submitTx: (tx) => connectedApi.submitTransaction(serialize(tx)),
};
```

After the proof server generates the ZK proof and Lace balances the
transaction, `submitTx` broadcasts it to the Substrate node via Lace. The
wallet handles the actual network communication.

### 6. privateStateProvider

**Purpose:** Stores the DApp's private (off-chain) state. This is state that
is known only to the current user and is never published on-chain.

**Interface:** `PrivateStateProvider` from `@midnight-ntwrk/midnight-js-types`.

**Browser implementation:** A simple in-memory `Map`. Browser DApps do not
persist private state across sessions — when the user refreshes the page,
private state is reconstructed from the contract's public ledger where
possible.

```typescript
const privateStateProvider: PrivateStateProvider = {
  get: async (contractAddress: ContractAddress) =>
    privateStates.get(contractAddress) ?? null,
  set: async (contractAddress: ContractAddress, state: PrivateState) => {
    privateStates.set(contractAddress, state);
  },
};
```

## DApp Connector API Types

The Lace wallet extension exposes the DApp Connector API through
`window.midnight.mnLace`. The API surface is defined in
`@midnight-ntwrk/dapp-connector-api` (v4).

### InitialAPI

The entry point for wallet interaction. Available before the user approves
the connection.

| Property     | Type                                      | Description                                  |
| ------------ | ----------------------------------------- | -------------------------------------------- |
| `name`       | `string`                                  | Wallet display name (e.g., "Lace")           |
| `icon`       | `string`                                  | Base64 or data URI of the wallet icon         |
| `apiVersion` | `string`                                  | DApp Connector API version (e.g., "1.0.0")   |
| `rdns`       | `string`                                  | Reverse DNS identifier                       |
| `connect`    | `(purpose: string) => Promise<ConnectedAPI>` | Requests user approval and returns connected API |

The `connect()` method prompts the user to approve the DApp in the Lace
extension popup. The `purpose` parameter is typically `"undeployed"` for new
DApps or a contract address for existing deployments.

### ConnectedAPI

The full API surface available after the user approves the connection.

| Method                          | Return Type                      | Description                                          |
| ------------------------------- | -------------------------------- | ---------------------------------------------------- |
| `getConfiguration()`           | `Promise<Configuration>`        | Returns all network endpoints                        |
| `getShieldedAddresses()`       | `Promise<string[]>`             | Shielded (private) addresses for the connected wallet |
| `getUnshieldedAddress()`       | `Promise<string>`               | Unshielded (public) address                          |
| `getDustAddress()`             | `Promise<string>`               | Address for dust collection                          |
| `getShieldedBalances()`        | `Promise<Balance[]>`            | Shielded token balances                              |
| `getUnshieldedBalances()`      | `Promise<Balance[]>`            | Unshielded token balances                            |
| `getDustBalance()`             | `Promise<Balance>`              | Dust balance                                         |
| `balanceUnsealedTransaction()` | `Promise<BalancedTransaction>`  | Adds coin inputs and signs                           |
| `submitTransaction()`          | `Promise<TransactionId>`        | Broadcasts to the network                            |
| `signData()`                   | `Promise<SignedData>`           | Signs arbitrary data                                 |
| `getProvingProvider()`         | `Promise<ProvingProvider>`      | Returns the wallet's proving provider (if available) |

### Configuration

Returned by `getConfiguration()`. Contains all network endpoints needed to
assemble the 6 providers.

```typescript
interface Configuration {
  indexerUri: string;       // HTTP endpoint for the indexer (queries)
  indexerWsUri: string;     // WebSocket endpoint for the indexer (subscriptions)
  substrateNodeUri: string; // Substrate node RPC endpoint
  networkId: string;        // Network identifier (e.g., "testnet")
}
```

### APIError

Errors from the DApp Connector API are plain objects, not class instances.
This is a critical distinction for error handling.

```typescript
interface APIError {
  type: "DAppConnectorAPIError";
  code: ErrorCode;
  reason: string;
}
```

**Never use `instanceof` to check for API errors.** The error objects are
serialized across the extension boundary and lose their prototype chain. Always
check the `type` property:

```typescript
try {
  const api = await initialApi.connect("undeployed");
} catch (error: unknown) {
  if (
    typeof error === "object" &&
    error !== null &&
    "type" in error &&
    (error as APIError).type === "DAppConnectorAPIError"
  ) {
    const apiError = error as APIError;
    switch (apiError.code) {
      case ErrorCode.UserRejected:
        // User declined the connection in Lace
        break;
      case ErrorCode.InternalError:
        // Something went wrong inside Lace
        break;
    }
  }
}
```

### ErrorCode Enum

| Code              | Meaning                                          |
| ----------------- | ------------------------------------------------ |
| `UserRejected`    | User declined the action in the Lace popup       |
| `InternalError`   | Internal wallet error                            |
| `InvalidRequest`  | Malformed request to the wallet                  |
| `Unauthorized`    | DApp not authorized or connection expired        |
| `NetworkError`    | Network connectivity issue                       |

## Wallet-Driven Configuration

All network endpoints originate from the Lace wallet's `getConfiguration()`
method. This is a deliberate design decision in the Midnight ecosystem: the
wallet is the single source of truth for which network the user is connected
to.

**Why this matters:**

1. **No hardcoded URLs.** The DApp does not contain any network endpoints in
   its source code or environment variables. The user selects a network in
   Lace's settings, and the DApp automatically connects to the correct
   indexer, node, and proof server.

2. **Network switching is seamless.** If the user switches from testnet to
   another network in Lace, re-connecting the DApp picks up the new
   endpoints automatically.

3. **Deployment simplicity.** The same DApp build works on any network
   without configuration changes.

## Proof Server URI Derivation

The proof server URI is not included in `getConfiguration()`. It must be
derived from `substrateNodeUri`:

```typescript
function deriveProofServerUri(substrateNodeUri: string): string {
  const url = new URL(substrateNodeUri);
  url.port = "6300";
  return url.toString();
}
```

The convention is that the proof server runs on the same host as the Substrate
node but on port 6300 (the node itself typically uses port 9944). Some
deployments provide a `serviceUriConfig().proverServerUri` — if available, use
that instead of deriving from the node URI.

## The createProviders() Factory Pattern

The recommended pattern is a single factory function that takes a
`ConnectedAPI` and returns all 6 providers ready for use:

```typescript
import { type ConnectedAPI, type Configuration } from '@midnight-ntwrk/dapp-connector-api';
import { indexerPublicDataProvider } from '@midnight-ntwrk/midnight-js-indexer-public-data-provider';
import { FetchZkConfigProvider } from '@midnight-ntwrk/midnight-js-fetch-zk-config-provider';
import { httpClientProofProvider } from '@midnight-ntwrk/midnight-js-http-client-proof-provider';
import type {
  MidnightProviders,
  WalletProvider,
  MidnightProvider,
  PrivateStateProvider,
} from '@midnight-ntwrk/midnight-js-types';
import { setNetworkId } from '@midnight-ntwrk/midnight-js-network-id';

export async function createProviders<PS, C>(
  connectedApi: ConnectedAPI,
): Promise<MidnightProviders<PS, C>> {
  const config = await connectedApi.getConfiguration();
  setNetworkId(config.networkId);

  const proofServerUri = deriveProofServerUri(config.substrateNodeUri);

  const privateStates = new Map<string, PS>();

  const publicDataProvider = indexerPublicDataProvider(
    config.indexerUri,
    config.indexerWsUri,
  );

  const zkConfigProvider = new FetchZkConfigProvider<C>(
    window.location.origin,
    fetch,
  );

  const proofProvider = httpClientProofProvider(proofServerUri, zkConfigProvider);

  const walletProvider: WalletProvider = {
    getCoinPublicKey: () =>
      connectedApi.getShieldedAddresses().then((addrs) => addrs[0]),
    getEncryptionPublicKey: () =>
      connectedApi.getShieldedAddresses().then((addrs) => addrs[0]),
    balanceTx: (tx, newCoins) =>
      connectedApi.balanceUnsealedTransaction(serialize(tx), newCoins),
  };

  const midnightProvider: MidnightProvider = {
    submitTx: (tx) => connectedApi.submitTransaction(serialize(tx)),
  };

  const privateStateProvider: PrivateStateProvider<PS> = {
    get: async (contractAddress) =>
      privateStates.get(contractAddress) ?? null,
    set: async (contractAddress, state) => {
      privateStates.set(contractAddress, state);
    },
  };

  return {
    publicDataProvider,
    zkConfigProvider,
    proofProvider,
    walletProvider,
    midnightProvider,
    privateStateProvider,
  };
}
```

This factory is called once after wallet connection succeeds and stored in a
React Context so all components can access the providers.

## WalletProvider and balanceTx

The `walletProvider.balanceTx` method is the SDK's abstraction over Lace's
`balanceUnsealedTransaction`. When the SDK constructs a transaction (e.g.,
from `callTx`), the result is an `UnprovenTransaction`. After proof generation,
the transaction needs coin inputs to pay fees. `balanceTx` sends the
transaction to Lace, which:

1. Selects appropriate coin inputs from the user's wallet
2. Constructs change outputs if necessary
3. Signs the transaction with the user's private key
4. Returns the balanced, signed transaction

The `serialize` function converts the SDK's internal representation to the
wire format expected by Lace. Import it from the appropriate SDK package for
your contract.

## MidnightProvider and submitTx

The `midnightProvider.submitTx` method wraps Lace's `submitTransaction`. After
balancing and signing, the transaction is ready for broadcast. `submitTx` sends
it to Lace, which forwards it to the Substrate node. The method returns a
`TransactionId` that can be used to track confirmation via the indexer's
WebSocket subscription.

## Browser vs Node.js Differences

Several providers have different implementations depending on the runtime:

| Provider             | Browser                        | Node.js (CLI tools)               |
| -------------------- | ------------------------------ | --------------------------------- |
| `zkConfigProvider`   | `FetchZkConfigProvider` (HTTP) | `NodeZkConfigProvider` (file system) |
| `privateStateProvider` | In-memory `Map`              | LevelDB on disk                   |
| `walletProvider`     | Lace extension                 | Standalone key management         |
| `midnightProvider`   | Lace extension                 | Direct Substrate RPC              |
| `publicDataProvider` | Same (`indexerPublicDataProvider`) | Same                          |
| `proofProvider`      | Same (`httpClientProofProvider`)   | Same                          |

In the browser, the wallet extension handles key management and transaction
submission. In Node.js (CLI tools, integration tests), you manage keys
directly and submit transactions via Substrate RPC without Lace.

The `publicDataProvider` and `proofProvider` are identical in both
environments — they communicate with external services (indexer and proof
server) over HTTP/WebSocket regardless of runtime.

## Wallet Setup

Midnight uses the Lace wallet exclusively. The setup requirements are:

1. **Chrome browser.** Lace is a Chrome extension (Chromium-based browsers
   also work).
2. **Install Lace.** Available from the Chrome Web Store or the Midnight
   documentation portal.
3. **Select the Midnight network.** In Lace settings, switch to the
   appropriate Midnight network (testnet for development).
4. **Fund the wallet.** Use the Midnight testnet faucet to receive test
   tokens. The faucet URL is available in the Midnight documentation.
5. **Connect to the DApp.** When the DApp calls `connect()`, Lace shows a
   popup asking the user to approve the connection. The user must approve
   before the DApp can access `ConnectedAPI`.

The Lace extension injects `window.midnight.mnLace` into the page. The DApp
detects wallet availability by checking for this global:

```typescript
function isWalletAvailable(): boolean {
  return (
    typeof window !== "undefined" &&
    "midnight" in window &&
    "mnLace" in (window as any).midnight
  );
}
```

If the wallet is not available, the DApp should show an install prompt rather
than failing silently.
