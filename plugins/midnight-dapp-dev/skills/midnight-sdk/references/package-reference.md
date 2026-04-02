# SDK Package Reference

Detailed exports, constructor signatures, and configuration for all 10 Midnight.js SDK packages. For high-level usage patterns, see the main `midnight-sdk` skill. For the transaction lifecycle, see `references/transaction-lifecycle.md`.

## @midnight-ntwrk/midnight-js-contracts

The primary contract interaction package. Handles deployment, discovery, circuit calls, and maintenance.

### Contract Deployment & Discovery

```typescript
import {
  deployContract,
  findDeployedContract,
} from "@midnight-ntwrk/midnight-js-contracts";

// Deploy a new contract
const deployed: DeployedContract<C> = await deployContract(
  providers: MidnightProviders<ICK, PSI, PS>,
  options: {
    compiledContract: CompiledContract;
    privateStateId: PSI;
    initialPrivateState: PS;
    args?: unknown[];  // Constructor arguments
  },
);

// Find an existing contract by address
const found: FoundContract<C> = await findDeployedContract(
  providers: MidnightProviders<ICK, PSI, PS>,
  options: {
    contractAddress: ContractAddress;
    compiledContract: CompiledContract;
    privateStateId: PSI;
    initialPrivateState: PS;
  },
);
```

### Circuit Call Functions

```typescript
import {
  callTx,
  submitCallTx,
  submitCallTxAsync,
  createUnprovenCallTx,
} from "@midnight-ntwrk/midnight-js-contracts";

// High-level: build, prove, balance, submit, finalize
const result: FinalizedCallTxData<C, ICK> = await deployed.callTx.circuitName(args);

// Mid-level: explicit unproven tx creation + submission
const unproven = await createUnprovenCallTx(deployed, providers, "circuitName", [args]);
const result = await submitCallTx(providers, unproven);

// Fire-and-forget: return after submission without waiting for finalization
const txId: TransactionId = await submitCallTxAsync(providers, unproven);
```

### Transaction Submission

```typescript
import { submitTxAsync } from "@midnight-ntwrk/midnight-js-contracts";

// Submit a pre-built transaction without waiting for finalization
const txId: TransactionId = await submitTxAsync(providers, finalizedTx);
```

### State Queries

```typescript
import {
  getStates,
  getPublicStates,
  getUnshieldedBalances,
  verifyContractState,
} from "@midnight-ntwrk/midnight-js-contracts";

// Both public and private state
const { publicState, privateState } = await getStates(deployed, providers);

// Public state only (on-chain via indexer)
const publicState = await getPublicStates(deployed, providers);

// Wallet unshielded balances
const balances: Record<string, bigint> = await getUnshieldedBalances(providers);

// Verify on-chain state integrity
const valid: boolean = await verifyContractState(deployed, providers);
```

### Contract Maintenance

```typescript
import {
  submitInsertVerifierKeyTx,
  submitRemoveVerifierKeyTx,
  submitReplaceAuthorityTx,
  replaceAuthority,
} from "@midnight-ntwrk/midnight-js-contracts";

// Add a verifier key for a circuit
await submitInsertVerifierKeyTx(providers, {
  contractAddress: ContractAddress,
  circuitId: string,
  verifierKey: Uint8Array,
});

// Remove a verifier key
await submitRemoveVerifierKeyTx(providers, {
  contractAddress: ContractAddress,
  circuitId: string,
});

// Replace the contract authority
await submitReplaceAuthorityTx(providers, {
  contractAddress: ContractAddress,
  newAuthority: Uint8Array,
});

// Alternative authority replacement via contract reference
const result = await replaceAuthority(deployed, providers, newAuthorityPublicKey);
```

### Error Types

```typescript
import {
  DeployTxFailedError,
  CallTxFailedError,
} from "@midnight-ntwrk/midnight-js-contracts";

// Deployment failure (transaction submitted but failed on-chain)
try {
  await deployContract(providers, options);
} catch (e) {
  if (e instanceof DeployTxFailedError) { /* handle */ }
}

// Circuit call failure
try {
  await deployed.callTx.myCircuit();
} catch (e) {
  if (e instanceof CallTxFailedError) { /* handle */ }
}
```

### Return Types

```typescript
// DeployedContract<C>
interface DeployedContract<C> {
  callTx: Record<string, (...args: unknown[]) => Promise<FinalizedCallTxData<C, string>>>;
  deployTxData: FinalizedDeployTxData<C>;
}

// FoundContract<C> -- same interface as DeployedContract
interface FoundContract<C> {
  callTx: Record<string, (...args: unknown[]) => Promise<FinalizedCallTxData<C, string>>>;
  deployTxData: FinalizedDeployTxData<C>;
}

// FinalizedDeployTxData<C>
interface FinalizedDeployTxData<C> {
  public: {
    contractAddress: ContractAddress;
    txId: TransactionId;
    txHash: string;
    blockHeight: bigint;
  };
  private: {
    signingKey: Uint8Array;
    initialPrivateState: unknown;
  };
}

// FinalizedCallTxData<C, ICK>
interface FinalizedCallTxData<C, ICK> {
  public: {
    txId: TransactionId;
    txHash: string;
    blockHeight: bigint;
  };
}
```

## @midnight-ntwrk/midnight-js-types

Core type definitions used across all SDK packages.

### Provider Interfaces

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

interface PublicDataProvider {
  queryContractState(address: ContractAddress): Promise<ContractState | null>;
  watchForDeployTxData(address: ContractAddress): Observable<DeployTxData>;
  contractStateObservable(
    address: ContractAddress,
    options?: { type: "latest" },
  ): Observable<ContractState>;
}

interface PrivateStateProvider<PSI extends string, PS> {
  get(id: PSI): Promise<PS | null>;
  set(id: PSI, state: PS): Promise<void>;
  remove(id: PSI): Promise<void>;
}

interface ZkConfigProvider<ICK extends string> {
  getZkConfig(circuitId: ICK): Promise<ZkConfig>;
}

interface ProofProvider<ICK extends string> {
  prove(circuitId: ICK, inputs: ProveInputs): Promise<Proof>;
}
```

### MidnightProviders Bundle

```typescript
interface MidnightProviders<ICK extends string, PSI extends string, PS> {
  walletProvider: WalletProvider;
  midnightProvider: MidnightProvider;
  publicDataProvider: PublicDataProvider;
  privateStateProvider: PrivateStateProvider<PSI, PS>;
  zkConfigProvider: ZkConfigProvider<ICK>;
  proofProvider: ProofProvider<ICK>;
}
```

## @midnight-ntwrk/midnight-js-network-id

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

/**
 * Set the active network. Must be called once before creating any providers.
 * Configures cryptographic parameters for the target network.
 * @param networkId - "undeployed", "preview", or "preprod"
 */
setNetworkId(networkId: string): void;
```

## @midnight-ntwrk/midnight-js-indexer-public-data-provider

```typescript
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";

/**
 * Create a PublicDataProvider connected to the Midnight indexer.
 * @param httpUrl - Indexer GraphQL HTTP endpoint
 * @param wsUrl - Indexer GraphQL WebSocket endpoint
 * @returns PublicDataProvider instance
 */
indexerPublicDataProvider(httpUrl: string, wsUrl: string): PublicDataProvider;
```

## @midnight-ntwrk/midnight-js-http-client-proof-provider

```typescript
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";

/**
 * Create a ProofProvider that communicates with a proof server via HTTP.
 * @param proofServerUrl - Proof server base URL (e.g., "http://localhost:6300")
 * @param zkConfigProvider - ZK config provider for circuit configurations
 * @returns ProofProvider instance
 */
httpClientProofProvider<ICK extends string>(
  proofServerUrl: string,
  zkConfigProvider: ZkConfigProvider<ICK>,
): ProofProvider<ICK>;
```

## @midnight-ntwrk/midnight-js-level-private-state-provider

Node.js only. Uses LevelDB for persistent off-chain state storage.

```typescript
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";

/**
 * Create a PrivateStateProvider backed by LevelDB.
 * @param options.privateStateStoreName - LevelDB database name for state
 * @param options.signingKeyStoreName - LevelDB database name for signing keys
 * @param options.privateStoragePasswordProvider - Function returning the encryption password
 * @returns PrivateStateProvider instance
 */
levelPrivateStateProvider<PSI extends string, PS>(options: {
  privateStateStoreName: string;
  signingKeyStoreName: string;
  privateStoragePasswordProvider: () => string;
}): PrivateStateProvider<PSI, PS>;
```

## @midnight-ntwrk/midnight-js-node-zk-config-provider

Node.js only. Loads ZK circuit configurations from the local filesystem.

```typescript
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";

/**
 * Create a ZkConfigProvider that reads from the filesystem.
 * @param basePath - Path to the managed/<contract> directory
 */
new NodeZkConfigProvider<ICK extends string>(basePath: string): ZkConfigProvider<ICK>;
```

## @midnight-ntwrk/midnight-js-fetch-zk-config-provider

Browser only. Loads ZK circuit configurations via HTTP fetch.

```typescript
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";

/**
 * Create a ZkConfigProvider that fetches via HTTP.
 * @param baseUrl - Base URL for ZK asset files (e.g., window.location.origin)
 * @param fetchFn - Fetch function (use fetch.bind(window) in browser)
 */
new FetchZkConfigProvider<ICK extends string>(
  baseUrl: string,
  fetchFn: typeof fetch,
): ZkConfigProvider<ICK>;
```

## @midnight-ntwrk/midnight-js-logger-provider

Optional structured logging for SDK operations.

```typescript
import { loggerProvider } from "@midnight-ntwrk/midnight-js-logger-provider";

/**
 * Create a logger provider for SDK diagnostic output.
 * Attach to providers for operation tracing.
 */
const logger = loggerProvider();
```

## @midnight-ntwrk/midnight-js-utils

Utility functions used across the SDK.

```typescript
import { toHex } from "@midnight-ntwrk/midnight-js-utils";

/**
 * Convert a Uint8Array to a hex string.
 * @param bytes - Input bytes
 * @returns Hex-encoded string (no "0x" prefix)
 */
toHex(bytes: Uint8Array): string;
```
