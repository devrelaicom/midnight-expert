# SDK Package Reference

Detailed exports, constructor signatures, and configuration for the Midnight.js SDK packages (v4.1.1; all `@midnight-ntwrk/midnight-js-*` packages move in lockstep). For high-level usage patterns, see the main `midnight-sdk` skill. For the transaction lifecycle, see `references/transaction-lifecycle.md`.

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
  providers: MidnightProviders<PCK, PSI, PS>,
  options: {
    compiledContract: CompiledContract;
    privateStateId: PSI;
    initialPrivateState: PS;
    // `args` is REQUIRED when the contract's constructor takes parameters
    // (its type is `Contract.InitializeParameters<C>`); for a no-argument
    // constructor the `args` field is omitted from the options type entirely.
    args: ConstructorArgs;
    signingKey?: SigningKey;  // optional; a fresh CMA signing key is sampled if omitted
  },
);

// Find an existing contract by address
const found: FoundContract<C> = await findDeployedContract(
  providers: MidnightProviders<PCK, PSI, PS>,
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
  getCoinPublicKey(): CoinPublicKey;
  getEncryptionPublicKey(): EncPublicKey;
  // Balances a proven (unbound) transaction; returns a finalized transaction.
  balanceTx(tx: UnboundTransaction, ttl?: Date): Promise<FinalizedTransaction>;
}

interface MidnightProvider {
  submitTx(tx: FinalizedTransaction): Promise<TransactionId>;
}

interface PublicDataProvider {
  queryContractState(
    address: ContractAddress,
    config?: BlockHeightConfig | BlockHashConfig,
  ): Promise<ContractState | null>;
  // Resolves once when the deployment tx appears on-chain (a Promise, not an Observable):
  watchForDeployTxData(address: ContractAddress): Promise<FinalizedTxData>;
  watchForTxData(txId: TransactionId): Promise<FinalizedTxData>;
  contractStateObservable(
    address: ContractAddress,
    config: ContractStateObservableConfig,
  ): Observable<ContractState>;
  unshieldedBalancesObservable(
    address: ContractAddress,
    config: ContractStateObservableConfig,
  ): Observable<UnshieldedBalances>;
  // ...also queryZSwapAndContractState, queryDeployContractState,
  // queryUnshieldedBalances, watchForContractState, watchForUnshieldedBalances
}

interface PrivateStateProvider<PSI extends string, PS> {
  get(id: PSI): Promise<PS | null>;
  set(id: PSI, state: PS): Promise<void>;
  remove(id: PSI): Promise<void>;
}

// Abstract class, not a plain interface.
abstract class ZKConfigProvider<K extends string> {
  abstract getZKIR(circuitId: K): Promise<ZKIR>;
  abstract getProverKey(circuitId: K): Promise<ProverKey>;
  abstract getVerifierKey(circuitId: K): Promise<VerifierKey>;
  get(circuitId: K): Promise<ZKConfig<K>>;
}

interface ProofProvider {
  proveTx(
    unprovenTx: UnprovenTransaction,
    proveTxConfig?: ProveTxConfig,
  ): Promise<UnboundTransaction>;
}
```

`ContractStateObservableConfig` is required:
`{ type: "latest" }`, `{ type: "all" }`, `{ type: "txId"; txId }`,
`{ type: "blockHeight"; blockHeight }`, or `{ type: "blockHash"; blockHash }`.
As of v4.1.1 the `blockHeight` / `blockHash` configurations emit the state at that block.

### MidnightProviders Bundle

```typescript
interface MidnightProviders<
  PCK extends AnyProvableCircuitId = AnyProvableCircuitId,
  PSI extends PrivateStateId = PrivateStateId,
  PS = any,
> {
  readonly privateStateProvider: PrivateStateProvider<PSI, PS>;
  readonly publicDataProvider: PublicDataProvider;
  readonly zkConfigProvider: ZKConfigProvider<PCK>;
  readonly proofProvider: ProofProvider;
  readonly walletProvider: WalletProvider;
  readonly midnightProvider: MidnightProvider;
  readonly loggerProvider?: LoggerProvider;  // optional pino-backed logger
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
httpClientProofProvider<K extends string>(
  proofServerUrl: string,
  zkConfigProvider: ZKConfigProvider<K>,
): ProofProvider;
```

## @midnight-ntwrk/midnight-js-level-private-state-provider

Node.js only. Uses LevelDB for persistent off-chain state storage.

```typescript
import {
  levelPrivateStateProvider,
  StorageEncryption,
} from "@midnight-ntwrk/midnight-js-level-private-state-provider";

/**
 * Create a PrivateStateProvider backed by LevelDB.
 * @param config.privateStateStoreName - LevelDB store name for private state
 * @param config.signingKeyStoreName - LevelDB store name for signing keys
 * @param config.privateStoragePasswordProvider - Returns the encryption password
 *        (may be sync or async; passwords are subject to a strict policy)
 * @param config.accountId - required: scopes storage per account (hashed SHA-256);
 *        any unique id such as the wallet address
 * @param config.cryptoBackend - Optional: "webcrypto" | "noble" (e.g. React Native)
 * @param config.levelFactory - Optional: custom LevelDB factory (e.g. browser/RN)
 */
levelPrivateStateProvider<PSI extends string, PS = any>(config: {
  privateStateStoreName: string;
  signingKeyStoreName: string;
  privateStoragePasswordProvider: () => string | Promise<string>;
  accountId: string; // required: scopes storage per account (hashed SHA-256); any unique id such as the wallet address
  cryptoBackend?: "webcrypto" | "noble";
  levelFactory?: (dbName: string) => DatabaseLevel;
}): PrivateStateProvider<PSI, PS>;
```

As of v4.1.0 the storage encryption migrated to Web Crypto + PBKDF2 and
`StorageEncryption` is now **async**. There is no public `new StorageEncryption(pwd)`
constructor — construct via `await StorageEncryption.create(password, options?)`, and
`encrypt` / `decrypt` / `decryptWithPassword` / `verifyPassword` are all async. The salt
is supplied through the options object (`{ existingSalt }`), not a positional argument:

```typescript
const encryption = await StorageEncryption.create(password, {
  existingSalt,            // optional Buffer | Uint8Array
  cryptoBackend: "webcrypto",
});
const ciphertext = await encryption.encrypt(plaintext);
const recovered = await encryption.decrypt(ciphertext);
```

## @midnight-ntwrk/midnight-js-node-zk-config-provider

Node.js only. Loads ZK circuit configurations from the local filesystem.

```typescript
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";

/**
 * Create a ZKConfigProvider that reads from the filesystem.
 * @param basePath - Path to the managed/<contract> directory
 */
new NodeZkConfigProvider<K extends string>(basePath: string): ZKConfigProvider<K>;
```

## @midnight-ntwrk/midnight-js-fetch-zk-config-provider

Browser only. Loads ZK circuit configurations via HTTP fetch.

```typescript
import { FetchZkConfigProvider } from "@midnight-ntwrk/midnight-js-fetch-zk-config-provider";

/**
 * Create a ZKConfigProvider that fetches via HTTP.
 * @param baseUrl - Base URL for ZK asset files (e.g., window.location.origin)
 * @param fetchFn - Fetch function (use fetch.bind(window) in browser)
 */
new FetchZkConfigProvider<K extends string>(
  baseUrl: string,
  fetchFn: typeof fetch,
): ZKConfigProvider<K>;
```

## @midnight-ntwrk/midnight-js-logger-provider

Optional structured logging for SDK operations. Exports a `LoggerProvider` class (wrapping a `pino` logger) — there is no `loggerProvider()` factory. Pass an instance as the optional `loggerProvider` member of `MidnightProviders`.

```typescript
import { LoggerProvider } from "@midnight-ntwrk/midnight-js-logger-provider";
import pino from "pino";

/**
 * Wrap a pino logger for SDK diagnostic output.
 * The constructor requires a pino-compatible Logger instance.
 */
const loggerProvider = new LoggerProvider(pino());
// loggerProvider exposes info/error/warn/debug/trace/fatal and isLevelEnabled(level)
```

## @midnight-ntwrk/midnight-js-dapp-connector-proof-provider

Browser wallet-delegated proving. Builds a `ProofProvider` whose
`proveTx` delegates ZK proof generation to the connected Lace wallet via the DApp
Connector, removing the need for a separately reachable proof server in the browser.

```typescript
import { dappConnectorProofProvider } from "@midnight-ntwrk/midnight-js-dapp-connector-proof-provider";

/**
 * @param api - DApp Connector wallet API exposing `getProvingProvider`
 * @param zkConfigProvider - Supplies ZK artifacts / key material
 * @param costModel - Cost model applied during transaction proving
 * @returns Promise<ProofProvider>
 */
const proofProvider = await dappConnectorProofProvider(
  api,
  zkConfigProvider,
  costModel,
);
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
