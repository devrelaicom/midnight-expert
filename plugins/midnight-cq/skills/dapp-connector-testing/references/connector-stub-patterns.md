# DApp Connector Stub Patterns

Complete test double implementations for `InitialAPI` and `ConnectedAPI`.

## API Error Factory

```typescript
type ErrorCode = 'InternalError' | 'Rejected' | 'InvalidRequest' | 'PermissionRejected' | 'Disconnected';

function createAPIError(code: ErrorCode, reason?: string): Error & { type: string; code: ErrorCode; reason: string } {
  const error = new Error(reason ?? code) as Error & { type: string; code: ErrorCode; reason: string };
  error.type = 'DAppConnectorAPIError';
  error.code = code;
  error.reason = reason ?? code;
  return error;
}
```

## Stub Configuration

```typescript
interface StubConfig {
  // Balance data
  shieldedBalances: Record<string, bigint>;
  unshieldedBalances: Record<string, bigint>;
  dustBalance: { cap: bigint; balance: bigint };

  // Address data
  shieldedAddresses: {
    shieldedAddress: string;
    shieldedCoinPublicKey: string;
    shieldedEncryptionPublicKey: string;
  };
  unshieldedAddress: { unshieldedAddress: string };
  dustAddress: { dustAddress: string };

  // Configuration
  configuration: {
    indexerUri: string;
    indexerWsUri: string;
    substrateNodeUri: string;
    networkId: string;
  };
  connectionStatus: { status: 'connected'; networkId: string } | { status: 'disconnected' };

  // Identity overrides
  name?: string;
  icon?: string;
  apiVersion?: string;

  // Error injection (per method)
  connectError?: ErrorCode;
  errors?: Partial<Record<keyof ConnectedAPI, ErrorCode>>;

  // Transaction behavior
  onSubmit?: (tx: string) => void;
}

const defaultConfig: StubConfig = {
  shieldedBalances: {},
  unshieldedBalances: {},
  dustBalance: { cap: 5000000000000000n, balance: 1000000000000000n },
  shieldedAddresses: {
    shieldedAddress: 'mn_shield-addr1...',
    shieldedCoinPublicKey: 'mn_shield-cpk1...',
    shieldedEncryptionPublicKey: 'mn_shield-epk1...',
  },
  unshieldedAddress: { unshieldedAddress: 'mn_addr1...' },
  dustAddress: { dustAddress: 'mn_dust1...' },
  configuration: {
    indexerUri: 'http://localhost:6300/api/v3/graphql',
    indexerWsUri: 'ws://localhost:6300/api/v3/graphql/ws',
    substrateNodeUri: 'ws://localhost:9944',
    networkId: 'undeployed',
  },
  connectionStatus: { status: 'connected', networkId: 'undeployed' },
};
```

## InitialAPI Stub

```typescript
function createWalletStub(config?: Partial<StubConfig>): InitialAPI {
  const cfg: StubConfig = { ...defaultConfig, ...config };

  return Object.freeze({
    rdns: 'com.test.wallet',
    name: cfg.name ?? 'Test Wallet',
    icon: cfg.icon ?? 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    apiVersion: cfg.apiVersion ?? '1.0.0',
    connect: async (networkId: string) => {
      if (cfg.connectError) throw createAPIError(cfg.connectError);
      return createConnectedStub(cfg);
    },
  });
}
```

## ConnectedAPI Stub

```typescript
function createConnectedStub(cfg: StubConfig): ConnectedAPI {
  const maybeThrow = (method: keyof ConnectedAPI) => {
    const code = cfg.errors?.[method];
    if (code) throw createAPIError(code);
  };

  return {
    getShieldedBalances: async () => { maybeThrow('getShieldedBalances'); return cfg.shieldedBalances; },
    getUnshieldedBalances: async () => { maybeThrow('getUnshieldedBalances'); return cfg.unshieldedBalances; },
    getDustBalance: async () => { maybeThrow('getDustBalance'); return cfg.dustBalance; },

    getShieldedAddresses: async () => { maybeThrow('getShieldedAddresses'); return cfg.shieldedAddresses; },
    getUnshieldedAddress: async () => { maybeThrow('getUnshieldedAddress'); return cfg.unshieldedAddress; },
    getDustAddress: async () => { maybeThrow('getDustAddress'); return cfg.dustAddress; },

    getTxHistory: async (pageNumber: number, pageSize: number) => {
      maybeThrow('getTxHistory');
      return [];
    },

    makeTransfer: async (desiredOutputs, options) => {
      maybeThrow('makeTransfer');
      return { tx: 'mock-transfer-tx' };
    },
    makeIntent: async (desiredInputs, desiredOutputs, options) => {
      maybeThrow('makeIntent');
      return { tx: 'mock-intent-tx' };
    },

    balanceUnsealedTransaction: async (tx, options) => {
      maybeThrow('balanceUnsealedTransaction');
      return { tx: 'mock-balanced-tx' };
    },
    balanceSealedTransaction: async (tx, options) => {
      maybeThrow('balanceSealedTransaction');
      return { tx: 'mock-balanced-sealed-tx' };
    },

    submitTransaction: async (tx) => {
      maybeThrow('submitTransaction');
      cfg.onSubmit?.(tx);
    },

    signData: async (data, options) => {
      maybeThrow('signData');
      return { data, signature: 'mock-signature', verifyingKey: 'mock-key' };
    },

    getConfiguration: async () => { maybeThrow('getConfiguration'); return cfg.configuration; },
    getConnectionStatus: async () => { maybeThrow('getConnectionStatus'); return cfg.connectionStatus; },

    getProvingProvider: async (keyMaterialProvider) => {
      maybeThrow('getProvingProvider');
      return {
        check: async (serializedPreimage, keyLocation) => [0n],
        prove: async (serializedPreimage, keyLocation) => new Uint8Array([0]),
      };
    },

    hintUsage: async (methodNames) => { maybeThrow('hintUsage'); },
  };
}
```

## Factory Functions for Common Scenarios

```typescript
/** Wallet with funded balances */
function createFundedWallet(overrides?: Partial<StubConfig>) {
  return createWalletStub({
    shieldedBalances: { '0x00': 1000n },
    unshieldedBalances: { '0x00': 500n },
    dustBalance: { cap: 5000000000000000n, balance: 3000000000000000n },
    ...overrides,
  });
}

/** Wallet with zero balances */
function createEmptyWallet(overrides?: Partial<StubConfig>) {
  return createWalletStub({
    shieldedBalances: {},
    unshieldedBalances: {},
    dustBalance: { cap: 0n, balance: 0n },
    ...overrides,
  });
}

/** Wallet that disconnects immediately */
function createDisconnectedWallet() {
  return createWalletStub({ connectError: 'Disconnected' });
}

/** Wallet that rejects all permissions */
function createRestrictedWallet(methods: (keyof ConnectedAPI)[]) {
  const errors: Partial<Record<keyof ConnectedAPI, ErrorCode>> = {};
  for (const method of methods) {
    errors[method] = 'PermissionRejected';
  }
  return createWalletStub({ errors });
}
```

## Injecting Stubs

### Unit/Integration Tests (direct import)

```typescript
import { createFundedWallet } from '../stubs/wallet-stub';

let wallet: ConnectedAPI;

beforeEach(async () => {
  const stub = createFundedWallet();
  wallet = await stub.connect('undeployed');
});
```

### E2E Tests (Playwright addInitScript)

> **Warning:** `bigint` literals (e.g. `1000n`) inside `page.addInitScript()`
> can fail during Playwright serialization because the function body is
> serialized to a string and `bigint` values are not JSON-serializable.
> Use `BigInt(1000)` instead of `1000n` inside injected scripts, or pass
> bigint values via `page.addInitScript(fn, arg)` after converting them
> to strings.

```typescript
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    const stub = {
      rdns: 'com.test.wallet',
      name: 'Test Wallet',
      icon: 'data:image/png;base64,...',
      apiVersion: '1.0.0',
      connect: async () => ({
        getShieldedBalances: async () => ({ '0x00': BigInt(1000) }),
        getUnshieldedBalances: async () => ({}),
        getDustBalance: async () => ({ cap: BigInt(0), balance: BigInt(0) }),
        // ... minimal stub for E2E scenario
        submitTransaction: async () => {},
      }),
    };
    Object.defineProperty(window, 'midnight', {
      value: { [crypto.randomUUID()]: Object.freeze(stub) },
      writable: false,
      configurable: false,
    });
  });
});
```
