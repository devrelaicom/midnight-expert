# Integration Testing Reference

## What is integration testing here?

Integration tests sit at Layer 2 of the Midnight DApp testing stack. They test **React
components calling Compact circuits through the contract simulator** — no real network, no
browser, no wallet extension.

The key distinction from E2E tests:

- **E2E (Playwright):** full browser, real DOM, mocked wallet extension
- **Integration (Vitest):** jsdom, React Testing Library, simulator replaces the network

The point of this layer is to verify that components correctly call circuits, handle the
returned state, and re-render with the right output — all without the cost and
non-determinism of a live blockchain. The simulator provides identical circuit semantics to
the real contract, so a test that passes here is a strong signal the UI is correct.

---

## Mocking `ContractProvider`

The Midnight SDK's `ContractProvider` is the bridge between frontend components and the
blockchain. In integration tests, replace it with a test mock that wraps the contract
simulator instead of dispatching to a live network.

The mock must satisfy the same interface as the real `ContractProvider` so components
receive it through the same React context without modification.

```typescript
// tests/integration/setup/mockContractProvider.ts
import { vi } from 'vitest';
import { MyContractSimulator } from '../simulators/MyContractSimulator';

export type MockContractProvider = ReturnType<typeof createMockContractProvider>;

export function createMockContractProvider(simulator?: MyContractSimulator) {
  const sim = simulator ?? new MyContractSimulator(/* default args */);

  return {
    // callCircuit routes directly to the simulator's circuit proxies.
    // 'transfer' -> simulator.circuits.impure.transfer(args)
    callCircuit: vi.fn(async (circuit: string, args: unknown[]) => {
      const fn = (sim.circuits.impure as Record<string, (...a: unknown[]) => unknown>)[circuit];
      if (!fn) throw new Error(`Unknown circuit: ${circuit}`);
      return fn(...args);
    }),

    // queryState returns the current public ledger state from the simulator
    queryState: vi.fn(async () => sim.getPublicState()),

    // Expose the underlying simulator so tests can inspect state directly
    _simulator: sim,
  };
}
```

Usage in a component test:

```typescript
// tests/integration/TransferForm.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ContractContext } from '../../src/context/ContractContext';
import { createMockContractProvider } from './setup/mockContractProvider';
import { TransferForm } from '../../src/components/TransferForm';

describe('TransferForm', () => {
  let provider: MockContractProvider;

  beforeEach(() => {
    provider = createMockContractProvider();
  });

  it('calls transfer circuit with correct args on submit', async () => {
    render(
      <ContractContext.Provider value={provider}>
        <TransferForm />
      </ContractContext.Provider>,
    );

    await userEvent.type(screen.getByLabelText(/recipient/i), '0xabc123');
    await userEvent.type(screen.getByLabelText(/amount/i), '50');
    await userEvent.click(screen.getByRole('button', { name: /transfer/i }));

    expect(provider.callCircuit).toHaveBeenCalledWith('transfer', [
      '0xabc123',
      50n,
    ]);
  });
});
```

The circuit name passed to `callCircuit` (`'transfer'`) routes to
`simulator.circuits.impure.transfer(args)`. The mock does not need to know the full
circuit list at construction time — it resolves the circuit name dynamically at call time.

---

## Testing Error Boundaries

Make the simulator (or the mock provider) throw to verify that React error boundaries
render the correct fallback UI.

```typescript
// tests/integration/ErrorBoundary.test.tsx
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi } from 'vitest';
import { ContractContext } from '../../src/context/ContractContext';
import { createMockContractProvider } from './setup/mockContractProvider';
import { TransferForm } from '../../src/components/TransferForm';
import { ContractErrorBoundary } from '../../src/components/ContractErrorBoundary';

describe('ContractErrorBoundary', () => {
  it('renders error message when circuit throws', async () => {
    const provider = createMockContractProvider();

    // Make the mock throw a domain error from the simulator
    provider.callCircuit.mockRejectedValueOnce(
      new Error('Insufficient balance'),
    );

    render(
      <ContractContext.Provider value={provider}>
        <ContractErrorBoundary>
          <TransferForm />
        </ContractErrorBoundary>
      </ContractContext.Provider>,
    );

    await userEvent.click(screen.getByRole('button', { name: /transfer/i }));

    expect(
      await screen.findByText(/insufficient balance/i),
    ).toBeInTheDocument();
  });

  it('renders generic fallback for unexpected errors', async () => {
    const provider = createMockContractProvider();

    provider.callCircuit.mockRejectedValueOnce(new Error('Unexpected failure'));

    render(
      <ContractContext.Provider value={provider}>
        <ContractErrorBoundary>
          <TransferForm />
        </ContractErrorBoundary>
      </ContractContext.Provider>,
    );

    await userEvent.click(screen.getByRole('button', { name: /transfer/i }));

    expect(
      await screen.findByRole('alert'),
    ).toBeInTheDocument();
  });
});
```

Key points:

- Use `mockRejectedValueOnce` to throw only for the specific test case; subsequent calls
  in other tests are unaffected.
- If the error boundary uses `componentDidCatch`, suppress the console error output in
  tests with a `beforeEach` that replaces `console.error` with `vi.fn()`.

---

## State Synchronization Testing

Verify that after a circuit call mutates the simulator's ledger state, the component
re-renders to display the new value.

The flow is: call circuit via mock provider → simulator state updates → component calls
`queryState` → component re-renders with new value.

```typescript
// tests/integration/BalanceDisplay.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { ContractContext } from '../../src/context/ContractContext';
import { createMockContractProvider } from './setup/mockContractProvider';
import { BalanceDisplay } from '../../src/components/BalanceDisplay';

describe('BalanceDisplay — state synchronization', () => {
  it('re-renders with updated balance after transfer', async () => {
    const provider = createMockContractProvider();

    render(
      <ContractContext.Provider value={provider}>
        <BalanceDisplay />
      </ContractContext.Provider>,
    );

    // Initial state from simulator
    expect(await screen.findByTestId('balance')).toHaveTextContent('100');

    // Trigger a transfer — routes through mock to simulator.circuits.impure.transfer
    await userEvent.click(screen.getByRole('button', { name: /transfer 10/i }));

    // Component calls queryState after the circuit call; simulator.getPublicState()
    // now reflects the mutation, so the component should re-render with 90
    await waitFor(() =>
      expect(screen.getByTestId('balance')).toHaveTextContent('90'),
    );
  });

  it('reflects state from simulator.getPublicState() on mount', async () => {
    const provider = createMockContractProvider();

    // Mutate the simulator before rendering so the component starts with known state
    provider._simulator.circuits.impure.mint('0xowner', 500n);

    render(
      <ContractContext.Provider value={provider}>
        <BalanceDisplay />
      </ContractContext.Provider>,
    );

    expect(await screen.findByTestId('balance')).toHaveTextContent('500');
  });
});
```

The synchronization contract: after `callCircuit` resolves, the component must call
`queryState` to pull the updated ledger. Tests that assert new UI state without waiting
for that re-render will race — always use `waitFor` or `findBy*` queries.

---

## Test Setup Pattern

Use `beforeEach` to create a fresh simulator, fresh mock provider, and a freshly-rendered
component tree for every test. Never share simulator or provider instances across tests.

```typescript
// tests/integration/MyComponent.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { vi, beforeEach, afterEach, describe, it, expect } from 'vitest';
import { cleanup } from '@testing-library/react';
import { ContractContext } from '../../src/context/ContractContext';
import { createMockContractProvider, type MockContractProvider } from './setup/mockContractProvider';
import { MyComponent } from '../../src/components/MyComponent';

describe('MyComponent — integration', () => {
  let provider: MockContractProvider;

  beforeEach(() => {
    // Fresh simulator + fresh mock provider per test
    provider = createMockContractProvider();

    render(
      <ContractContext.Provider value={provider}>
        <MyComponent />
      </ContractContext.Provider>,
    );
  });

  afterEach(() => {
    cleanup();        // unmount React tree
    vi.clearAllMocks(); // reset call counts on vi.fn() spies
  });

  it('displays initial contract state on mount', async () => {
    await waitFor(() =>
      expect(screen.getByTestId('contract-value')).toBeInTheDocument(),
    );
    expect(provider.queryState).toHaveBeenCalledOnce();
  });

  it('calls the correct circuit on user action', async () => {
    await userEvent.click(screen.getByRole('button', { name: /do something/i }));
    expect(provider.callCircuit).toHaveBeenCalledWith('doSomething', []);
  });

  it('re-renders after circuit mutation', async () => {
    await userEvent.click(screen.getByRole('button', { name: /increment/i }));

    await waitFor(() =>
      expect(screen.getByTestId('counter')).toHaveTextContent('1'),
    );
  });
});
```

### Why `beforeEach` — not `beforeAll`

The simulator is stateful: each circuit call mutates it. If two tests share a simulator,
the second test inherits the state mutations from the first, producing order-dependent
failures that are hard to diagnose. A fresh simulator in `beforeEach` keeps every test
hermetic.
