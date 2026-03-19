# DApp Connector API Type Reference

Complete type definitions for the Midnight DApp Connector API v4.0.1. For usage patterns and React/Next.js integration, see the main `dapp-connector` skill. For building SDK providers from these types, see `references/browser-providers.md`.

## Core Types

### InitialAPI

Injected by the wallet extension at `window.midnight.{walletId}`:

```typescript
interface InitialAPI {
  /** Wallet display name */
  readonly name: string;

  /** Wallet icon URL (data URI or HTTPS) */
  readonly icon: string;

  /** Semver version of the DApp Connector API */
  readonly apiVersion: string;

  /** Reverse DNS identifier (e.g., "io.midnight.lace") */
  readonly rdns: string;

  /**
   * Initiate wallet connection.
   * @param networkId - Target network: "undeployed", "preview", or "preprod"
   * @returns ConnectedAPI on success
   * @throws APIError with code "PermissionRejected" if user denies
   */
  connect(networkId: string): Promise<ConnectedAPI>;
}
```

### ConnectedAPI

Union type returned by `connect()`:

```typescript
type ConnectedAPI = WalletConnectedAPI & HintUsage;
```

### HintUsage

```typescript
interface HintUsage {
  /**
   * Pre-declare methods the DApp intends to use.
   * Allows the wallet to batch permission prompts.
   * @param methodNames - Array of WalletConnectedAPI method names
   */
  hintUsage(methodNames: string[]): void;
}
```

### WalletConnectedAPI

```typescript
interface WalletConnectedAPI {
  /**
   * Get the wallet's network configuration.
   * Returns endpoints matching the user's selected network in Lace.
   */
  getConfiguration(): Promise<Configuration>;

  /**
   * Check if the wallet is still connected.
   */
  getConnectionStatus(): Promise<ConnectionStatus>;

  /**
   * Get all shielded (private) addresses and keys.
   * All values are Bech32m-encoded strings.
   */
  getShieldedAddresses(): Promise<ShieldedAddresses>;

  /**
   * Get the unshielded (transparent) address.
   * Bech32m-encoded string.
   */
  getUnshieldedAddress(): Promise<UnshieldedAddress>;

  /**
   * Get the dust collection address.
   * Bech32m-encoded string.
   */
  getDustAddress(): Promise<DustAddress>;

  /**
   * Get balances for all token types in the shielded pool.
   * Keys are token type identifiers, values are bigint balances.
   */
  getShieldedBalances(): Promise<Record<string, bigint>>;

  /**
   * Get balances for all token types in the unshielded pool.
   * Keys are token type identifiers, values are bigint balances.
   */
  getUnshieldedBalances(): Promise<Record<string, bigint>>;

  /**
   * Get the current dust balance and generation cap.
   */
  getDustBalance(): Promise<DustBalance>;

  /**
   * Get paginated transaction history.
   * @param page - Zero-based page index
   * @param size - Number of entries per page
   */
  getTxHistory(page: number, size: number): Promise<HistoryEntry[]>;

  /**
   * Create a balanced transfer transaction.
   * @param outputs - Transfer output specifications
   * @param options - Optional transfer parameters
   */
  makeTransfer(outputs: TransferOutput[], options?: TransferOptions): Promise<{ tx: Transaction }>;

  /**
   * Create an unbalanced intent for atomic swaps.
   * @param inputs - Intent inputs
   * @param outputs - Intent outputs
   * @param options - Intent options
   */
  makeIntent(
    inputs: IntentInput[],
    outputs: IntentOutput[],
    options: IntentOptions,
  ): Promise<{ tx: Transaction }>;

  /**
   * Balance an unsealed transaction (from a contract call).
   * Adds fee inputs/outputs to make the transaction valid.
   * @param tx - The unbalanced transaction from contract interaction
   * @param options - Optional balancing parameters
   */
  balanceUnsealedTransaction(
    tx: UnbalancedTransaction,
    options?: BalanceOptions,
  ): Promise<{ tx: BalancedTransaction }>;

  /**
   * Balance a sealed transaction (for completing a swap).
   * @param tx - The sealed transaction to balance
   * @param options - Optional balancing parameters
   */
  balanceSealedTransaction(
    tx: SealedTransaction,
    options?: BalanceOptions,
  ): Promise<{ tx: BalancedTransaction }>;

  /**
   * Submit a balanced and proven transaction to the network.
   * @param tx - The finalized transaction to submit
   */
  submitTransaction(tx: FinalizedTransaction): Promise<void>;

  /**
   * Sign arbitrary data with the unshielded signing key.
   * @param data - Data to sign
   * @param options - Signing options
   */
  signData(data: Uint8Array, options: SignDataOptions): Promise<Signature>;

  /**
   * Get a proving provider that delegates ZK proof generation to the wallet.
   * @param keyMaterialProvider - Provides ZK key material for proof generation
   */
  getProvingProvider(
    keyMaterialProvider: KeyMaterialProvider,
  ): Promise<ProvingProvider>;
}
```

## Data Types

### Configuration

```typescript
interface Configuration {
  /** Indexer GraphQL HTTP endpoint */
  indexerUri: string;

  /** Indexer GraphQL WebSocket endpoint */
  indexerWsUri: string;

  /** Substrate node RPC endpoint */
  substrateNodeUri: string;

  /** Active network identifier */
  networkId: string;
}
```

### ConnectionStatus

```typescript
type ConnectionStatus = "connected" | "disconnected";
```

### Address Types

```typescript
interface ShieldedAddresses {
  /** Bech32m-encoded shielded address */
  shieldedAddress: string;

  /** Bech32m-encoded shielded coin public key */
  shieldedCoinPublicKey: string;

  /** Bech32m-encoded shielded encryption public key */
  shieldedEncryptionPublicKey: string;
}

interface UnshieldedAddress {
  /** Bech32m-encoded unshielded (transparent) address */
  unshieldedAddress: string;
}

interface DustAddress {
  /** Bech32m-encoded dust collection address */
  dustAddress: string;
}
```

### Balance Types

```typescript
interface DustBalance {
  /** Current dust balance */
  balance: bigint;

  /** Maximum dust cap derived from NIGHT delegation */
  cap: bigint;
}
```

### Transaction History

```typescript
interface HistoryEntry {
  /** Transaction hash */
  txHash: string;

  /** Transaction status */
  txStatus: TransactionStatus;
}

type TransactionStatus = "pending" | "confirmed" | "failed";
```

### Transfer Types

```typescript
interface TransferOutput {
  /** Recipient address (Bech32m) */
  address: string;

  /** Amount to transfer */
  amount: bigint;

  /** Token type identifier */
  tokenType: string;
}

interface TransferOptions {
  /** Transaction time-to-live */
  ttl?: Date;
}
```

### Intent Types (Atomic Swaps)

```typescript
interface IntentInput {
  /** Token type to offer */
  tokenType: string;

  /** Amount to offer */
  amount: bigint;
}

interface IntentOutput {
  /** Token type to receive */
  tokenType: string;

  /** Amount to receive */
  amount: bigint;

  /** Recipient address */
  address: string;
}

interface IntentOptions {
  /** Expiration for the intent */
  ttl?: Date;
}
```

### Signature Types

```typescript
interface Signature {
  /** The signature bytes */
  signature: Uint8Array;

  /** The public key that produced the signature */
  publicKey: Uint8Array;
}

interface SignDataOptions {
  /** Which key to sign with */
  keyType: "unshielded";
}
```

## Error Types

### APIError

```typescript
interface APIError {
  /** Discriminant field -- always "DAppConnectorAPIError" */
  type: "DAppConnectorAPIError";

  /** Error classification */
  code: ErrorCode;

  /** Human-readable error description */
  reason: string;
}

type ErrorCode =
  | "Disconnected"       // Wallet connection lost
  | "InternalError"      // Wallet-side internal failure
  | "InvalidRequest"     // Malformed request from DApp
  | "PermissionRejected" // User denied the permission prompt
  | "Rejected";          // User rejected the specific operation
```

### Error Checking Pattern

```typescript
function isDAppConnectorError(error: unknown): error is APIError {
  return (
    typeof error === "object" &&
    error !== null &&
    "type" in error &&
    (error as APIError).type === "DAppConnectorAPIError"
  );
}

// Usage
try {
  await api.submitTransaction(tx);
} catch (error) {
  if (isDAppConnectorError(error)) {
    // Handle specific error codes
    if (error.code === "Disconnected") {
      // Reconnect flow
    }
  }
}
```

## Window Type Augmentation

To get TypeScript support for `window.midnight`, add a type declaration:

```typescript
// types/midnight.d.ts
import type { InitialAPI } from "@midnight-ntwrk/dapp-connector-api";

declare global {
  interface Window {
    midnight?: {
      mnLace?: InitialAPI;
      [walletId: string]: InitialAPI | undefined;
    };
  }
}
```

This provides autocompletion and type checking for `window.midnight.mnLace` throughout the project.
