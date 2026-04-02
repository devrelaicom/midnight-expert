# Testing Patterns

This reference covers testing strategies for Midnight DApp frontends using
Vitest and Testing Library. It addresses the unique challenges of testing
wallet-connected applications, provider assembly, and RxJS observable
subscriptions in the browser.

## Why Testing Matters for Midnight DApps

Every Midnight DApp repository analyzed during the development of this
plugin — bboard, zkloan, kitties, starter-template, midnight-apps,
midnight-rwa, midnight-seabattle — contained zero frontend tests. No unit
tests, no integration tests, no component tests. This is remarkable for an
ecosystem where incorrect UI behavior can result in failed transactions
and lost tokens.

The absence of tests is understandable: the SDK is complex, wallet mocking
is non-obvious, and there were no established patterns to follow. This
template changes that by providing tested patterns from the start.

## Vitest + Testing Library Setup

### vitest.config.ts

A separate Vitest config is needed because the test environment differs
from the Vite build environment. Tests run in jsdom (not a real browser),
and they should not include Tailwind, WASM, or CommonJS plugins:

```typescript
import { defineConfig } from 'vitest/config';
import path from 'path';

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    include: ['src/**/*.test.{ts,tsx}'],
    css: false,
  },
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});
```

Key settings:

- **environment: 'jsdom'** — Provides a DOM implementation for component tests.
- **globals: true** — Makes `describe`, `it`, `expect` available without imports.
- **setupFiles** — Runs before each test file.
- **css: false** — Disables CSS processing in tests (Tailwind is not needed).

### Setup File (src/test/setup.ts)

```typescript
import '@testing-library/jest-dom/vitest';
```

This single import adds custom matchers like `toBeInTheDocument()`,
`toHaveTextContent()`, and `toBeDisabled()` to Vitest's `expect`.

### Required Dependencies

```json
{
  "devDependencies": {
    "vitest": "^3.0.0",
    "@testing-library/react": "^16.0.0",
    "@testing-library/jest-dom": "^6.0.0",
    "@testing-library/user-event": "^14.0.0",
    "jsdom": "^25.0.0"
  }
}
```

## Mocking window.midnight

The Lace wallet extension injects `window.midnight.mnLace` into the page.
In tests, this global does not exist, so you must mock it.

### Creating a Mock InitialAPI

```typescript
import { vi } from 'vitest';
import type { InitialAPI, ConnectedAPI, Configuration } from '@midnight-ntwrk/dapp-connector-api';

export const mockConfiguration: Configuration = {
  indexerUri: 'http://localhost:8080',
  indexerWsUri: 'ws://localhost:8080/ws',
  substrateNodeUri: 'ws://localhost:9944',
  networkId: 'testnet',
};

export function createMockConnectedApi(
  overrides?: Partial<ConnectedAPI>,
): ConnectedAPI {
  return {
    getConfiguration: vi.fn().mockResolvedValue(mockConfiguration),
    getShieldedAddresses: vi.fn().mockResolvedValue(['mock-shielded-address']),
    getUnshieldedAddress: vi.fn().mockResolvedValue('mock-unshielded-address'),
    getDustAddress: vi.fn().mockResolvedValue('mock-dust-address'),
    getShieldedBalances: vi.fn().mockResolvedValue([]),
    getUnshieldedBalances: vi.fn().mockResolvedValue([]),
    getDustBalance: vi.fn().mockResolvedValue({ amount: 0n }),
    balanceUnsealedTransaction: vi.fn().mockResolvedValue({ balanced: true }),
    submitTransaction: vi.fn().mockResolvedValue('mock-tx-id'),
    signData: vi.fn().mockResolvedValue({ signature: 'mock-sig' }),
    getProvingProvider: vi.fn().mockResolvedValue(null),
    ...overrides,
  };
}

export function createMockInitialApi(
  connectedApi?: ConnectedAPI,
): InitialAPI {
  const api = connectedApi ?? createMockConnectedApi();
  return {
    name: 'Mock Lace',
    icon: 'data:image/png;base64,mock',
    apiVersion: '1.0.0',
    rdns: 'com.mock.lace',
    connect: vi.fn().mockResolvedValue(api),
  };
}
```

### Installing the Mock

Set up and tear down the mock in `beforeEach` / `afterEach`:

```typescript
describe('WalletConnection', () => {
  let mockApi: InitialAPI;

  beforeEach(() => {
    mockApi = createMockInitialApi();
    (window as any).midnight = { mnLace: mockApi };
  });

  afterEach(() => {
    delete (window as any).midnight;
    localStorage.clear();
  });
});
```

Always delete `window.midnight` between tests to ensure test isolation.
Always clear `localStorage` because some wallet connection state may be
persisted there.

## Testing Wallet Connection States

A wallet connection has four states: disconnected, connecting, connected,
and error. Test all four:

```typescript
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { WalletProvider } from '@/providers/wallet-provider';

function TestConsumer() {
  const { status, connect, address } = useWallet();
  return (
    <div>
      <span data-testid="status">{status}</span>
      <span data-testid="address">{address ?? 'none'}</span>
      <button onClick={connect}>Connect</button>
    </div>
  );
}

describe('wallet connection states', () => {
  it('starts in disconnected state', () => {
    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );
    expect(screen.getByTestId('status')).toHaveTextContent('disconnected');
  });

  it('transitions to connected after successful connect', async () => {
    const user = userEvent.setup();
    const mockApi = createMockInitialApi();
    (window as any).midnight = { mnLace: mockApi };

    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );

    await user.click(screen.getByRole('button', { name: /connect/i }));

    await waitFor(() => {
      expect(screen.getByTestId('status')).toHaveTextContent('connected');
    });
    expect(mockApi.connect).toHaveBeenCalledWith('undeployed');
  });

  it('shows error when wallet extension is not found', async () => {
    const user = userEvent.setup();
    // Do not set window.midnight — wallet is not installed

    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );

    await user.click(screen.getByRole('button', { name: /connect/i }));

    await waitFor(() => {
      expect(screen.getByTestId('status')).toHaveTextContent('error');
    });
  });

  it('handles user rejection gracefully', async () => {
    const user = userEvent.setup();
    const mockApi = createMockInitialApi();
    mockApi.connect = vi.fn().mockRejectedValue({
      type: 'DAppConnectorAPIError',
      code: 'UserRejected',
      reason: 'User declined connection',
    });
    (window as any).midnight = { mnLace: mockApi };

    render(
      <WalletProvider>
        <TestConsumer />
      </WalletProvider>,
    );

    await user.click(screen.getByRole('button', { name: /connect/i }));

    await waitFor(() => {
      expect(screen.getByTestId('status')).toHaveTextContent('error');
    });
  });
});
```

## Testing Provider Assembly

Test that `createProviders()` correctly assembles all 6 providers from a
`ConnectedAPI`:

```typescript
import { createProviders } from '@/lib/providers';

describe('createProviders', () => {
  it('assembles all 6 providers from ConnectedAPI', async () => {
    const connectedApi = createMockConnectedApi();
    const providers = await createProviders(connectedApi);

    expect(providers.publicDataProvider).toBeDefined();
    expect(providers.zkConfigProvider).toBeDefined();
    expect(providers.proofProvider).toBeDefined();
    expect(providers.walletProvider).toBeDefined();
    expect(providers.midnightProvider).toBeDefined();
    expect(providers.privateStateProvider).toBeDefined();
  });

  it('derives proof server URI from substrate node URI', async () => {
    const connectedApi = createMockConnectedApi();
    const providers = await createProviders(connectedApi);

    // Verify the proof server was configured with port 6300
    expect(connectedApi.getConfiguration).toHaveBeenCalled();
  });
});
```

## Testing Components with Context

Components that consume wallet or provider context must be wrapped in the
appropriate providers during testing. Use the TestConsumer pattern.

The mock factories below follow the same pattern as `createMockConnectedApi()` — each returns
an object matching the corresponding provider interface from `@midnight-ntwrk/midnight-js-types`:

```typescript
function createMockPublicDataProvider(): PublicDataProvider {
  return { contractStateObservable: vi.fn().mockReturnValue(new BehaviorSubject(null)) };
}

function createMockZkConfigProvider(): ZkConfigProvider {
  return { getZkConfig: vi.fn().mockResolvedValue({ circuit: new Uint8Array() }) };
}

function createMockProofProvider(): ProofProvider {
  return { prove: vi.fn().mockResolvedValue(new Uint8Array()) };
}

function createMockWalletProvider(): WalletProvider {
  return {
    getCoinPublicKey: vi.fn().mockReturnValue(new Uint8Array(32)),
    getEncryptionPublicKey: vi.fn().mockReturnValue(new Uint8Array(32)),
    balanceTx: vi.fn().mockImplementation(async (tx) => tx),
  };
}

function createMockMidnightProvider(): MidnightProvider {
  return { submitTx: vi.fn().mockResolvedValue('mock-tx-id') };
}

function createMockPrivateStateProvider(): PrivateStateProvider {
  return {
    get: vi.fn().mockResolvedValue(null),
    set: vi.fn().mockResolvedValue(undefined),
  };
}

function renderWithProviders(ui: React.ReactElement) {
  const mockConnectedApi = createMockConnectedApi();
  const mockProviders = {
    publicDataProvider: createMockPublicDataProvider(),
    zkConfigProvider: createMockZkConfigProvider(),
    proofProvider: createMockProofProvider(),
    walletProvider: createMockWalletProvider(),
    midnightProvider: createMockMidnightProvider(),
    privateStateProvider: createMockPrivateStateProvider(),
  };

  return render(
    <WalletProvider initialState={{ status: 'connected', api: mockConnectedApi }}>
      <MidnightProvidersProvider value={mockProviders}>
        {ui}
      </MidnightProvidersProvider>
    </WalletProvider>,
  );
}

it('renders contract state', async () => {
  renderWithProviders(<ContractDisplay />);
  await waitFor(() => {
    expect(screen.getByTestId('contract-state')).toBeInTheDocument();
  });
});
```

## Testing RxJS Observable Subscriptions

Test that hooks correctly subscribe to observables and update state:

```typescript
import { BehaviorSubject, Subject, throwError } from 'rxjs';

describe('useContractState', () => {
  it('updates state when observable emits', async () => {
    const subject = new BehaviorSubject({ count: 0 });

    function TestComponent() {
      const { state, error } = useContractState(subject.asObservable());
      return (
        <div>
          <span data-testid="count">{state?.count ?? 'loading'}</span>
          <span data-testid="error">{error?.message ?? 'none'}</span>
        </div>
      );
    }

    render(<TestComponent />);

    await waitFor(() => {
      expect(screen.getByTestId('count')).toHaveTextContent('0');
    });

    // Emit a new value
    subject.next({ count: 42 });

    await waitFor(() => {
      expect(screen.getByTestId('count')).toHaveTextContent('42');
    });
  });

  it('handles observable errors', async () => {
    const subject = new Subject();

    function TestComponent() {
      const { state, error } = useContractState(subject.asObservable());
      return <span data-testid="error">{error?.message ?? 'none'}</span>;
    }

    render(<TestComponent />);

    subject.error(new Error('WebSocket disconnected'));

    await waitFor(() => {
      expect(screen.getByTestId('error')).toHaveTextContent('WebSocket disconnected');
    });
  });

  it('unsubscribes on unmount', () => {
    const subject = new BehaviorSubject({ count: 0 });
    const spy = vi.spyOn(subject, 'subscribe');

    function TestComponent() {
      useContractState(subject.asObservable());
      return <div>test</div>;
    }

    const { unmount } = render(<TestComponent />);
    unmount();

    // The subscription returned by subscribe should have been cleaned up
    // Verify no further emissions cause errors
    expect(() => subject.next({ count: 1 })).not.toThrow();
  });
});
```

## userEvent for Interaction Tests

Use `@testing-library/user-event` for realistic user interactions. Unlike
`fireEvent`, `userEvent` simulates full interaction sequences (focus, keydown,
keyup, click):

```typescript
import userEvent from '@testing-library/user-event';

it('connects wallet on button click', async () => {
  const user = userEvent.setup();

  render(
    <WalletProvider>
      <ConnectButton />
    </WalletProvider>,
  );

  const button = screen.getByRole('button', { name: /connect wallet/i });
  await user.click(button);

  await waitFor(() => {
    expect(screen.getByText(/connected/i)).toBeInTheDocument();
  });
});
```

Always call `userEvent.setup()` before using it. This creates a user event
instance with proper timing and sequencing.

## Cleanup Between Tests

Proper cleanup prevents test pollution:

```typescript
afterEach(() => {
  // Remove wallet mock
  delete (window as any).midnight;

  // Clear any persisted state
  localStorage.clear();
  sessionStorage.clear();

  // Reset all mocks
  vi.restoreAllMocks();
});
```

Critical cleanup actions:

1. **Delete `window.midnight`** — Ensures each test controls whether the
   wallet extension "exists."
2. **Clear localStorage** — Some wallet providers persist connection state.
3. **Restore mocks** — Prevents mock leakage between tests.

Testing Library's `render` automatically cleans up the DOM between tests
when using Vitest with the `@testing-library/react` cleanup integration.
