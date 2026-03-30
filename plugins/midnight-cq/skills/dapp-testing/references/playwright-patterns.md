# Playwright Patterns Reference

## Playwright Config Recap

Initial Playwright setup — installing the package, generating `playwright.config.ts`, and
configuring the `webServer` block — is covered by `midnight-cq:quality-init`. This file
covers **usage patterns** you apply once the config is in place.

One rule that never changes: `headless: true` in `playwright.config.ts`. Never set
`headless: false` in committed test code or CI configuration.

---

## Page Object Pattern for Midnight DApps

Every page object follows the same structure: locators are declared as `readonly` class
fields and initialised in the constructor; multi-step flows are named methods. Test blocks
never call `page.locator()` directly.

### `WalletPage`

```typescript
// tests/e2e/pages/WalletPage.ts
import { type Page, type Locator } from '@playwright/test';

export class WalletPage {
  readonly connectButton: Locator;
  readonly disconnectButton: Locator;
  readonly connectedBadge: Locator;
  readonly addressDisplay: Locator;

  constructor(private page: Page) {
    this.connectButton = page.getByRole('button', { name: /connect wallet/i });
    this.disconnectButton = page.getByRole('button', { name: /disconnect/i });
    this.connectedBadge = page.getByTestId('wallet-connected');
    this.addressDisplay = page.getByTestId('wallet-address');
  }

  async connect(): Promise<void> {
    await this.connectButton.click();
    await this.connectedBadge.waitFor({ state: 'visible' });
  }

  async disconnect(): Promise<void> {
    await this.disconnectButton.click();
    await this.connectButton.waitFor({ state: 'visible' });
  }

  async isConnected(): Promise<boolean> {
    return this.connectedBadge.isVisible();
  }

  async getConnectedAddress(): Promise<string> {
    return this.addressDisplay.innerText();
  }
}
```

### `TransactionPage`

```typescript
// tests/e2e/pages/TransactionPage.ts
import { type Page, type Locator, expect } from '@playwright/test';

export class TransactionPage {
  readonly submitButton: Locator;
  readonly pendingIndicator: Locator;
  readonly confirmationBanner: Locator;
  readonly errorMessage: Locator;

  constructor(private page: Page) {
    this.submitButton = page.getByRole('button', { name: /submit/i });
    this.pendingIndicator = page.getByTestId('tx-pending');
    this.confirmationBanner = page.getByTestId('tx-confirmed');
    this.errorMessage = page.getByTestId('tx-error');
  }

  async submitTransaction(): Promise<void> {
    await this.submitButton.click();
  }

  async waitForConfirmation(timeout = 30_000): Promise<void> {
    await this.confirmationBanner.waitFor({ state: 'visible', timeout });
  }

  async getTransactionStatus(): Promise<'pending' | 'confirmed' | 'error' | 'idle'> {
    if (await this.pendingIndicator.isVisible()) return 'pending';
    if (await this.confirmationBanner.isVisible()) return 'confirmed';
    if (await this.errorMessage.isVisible()) return 'error';
    return 'idle';
  }

  async getErrorMessage(): Promise<string> {
    await this.errorMessage.waitFor({ state: 'visible' });
    return this.errorMessage.innerText();
  }
}
```

### `DashboardPage`

```typescript
// tests/e2e/pages/DashboardPage.ts
import { type Page, type Locator } from '@playwright/test';

export class DashboardPage {
  readonly contractStateDisplay: Locator;
  readonly balanceDisplay: Locator;
  readonly refreshButton: Locator;

  constructor(private page: Page) {
    this.contractStateDisplay = page.getByTestId('contract-state');
    this.balanceDisplay = page.getByTestId('balance-display');
    this.refreshButton = page.getByRole('button', { name: /refresh/i });
  }

  async getContractStateDisplay(): Promise<string> {
    await this.contractStateDisplay.waitFor({ state: 'visible' });
    return this.contractStateDisplay.innerText();
  }

  async refreshState(): Promise<void> {
    await this.refreshButton.click();
    // Wait for the loading indicator to appear and then disappear
    await this.page.waitForSelector('[data-testid="state-loading"]', {
      state: 'hidden',
      timeout: 10_000,
    });
  }

  async getBalanceDisplay(): Promise<string> {
    await this.balanceDisplay.waitFor({ state: 'visible' });
    return this.balanceDisplay.innerText();
  }
}
```

---

## Mocking the DApp Connector

A real browser wallet extension is not available in CI. Inject a stub via
`page.addInitScript()` before any app code runs. The script runs in the browser context
before the first script tag, so `window.midnight` is defined when the DApp initialises.

```typescript
// tests/e2e/fixtures/walletMock.ts
import { test as base } from '@playwright/test';

export const test = base.extend({
  page: async ({ page }, use) => {
    await page.addInitScript(() => {
      // Stub the Midnight wallet connector that the DApp reads on load
      (window as any).midnight = {
        mnLace: {
          enable: async () => ({
            isEnabled: async () => true,
            state: async () => ({
              address: 'mn_test_addr_deadbeef',
              coinPublicKey: '0'.repeat(64),
            }),
            submitTransaction: async (_tx: unknown) => ({
              txHash: 'mock_tx_hash_' + Date.now(),
            }),
          }),
          apiVersion: '1.0.0',
          name: 'MockLace',
        },
      };
    });
    await use(page);
  },
});
```

Use this extended `test` fixture in your spec files:

```typescript
// tests/e2e/wallet-connection.spec.ts
import { expect } from '@playwright/test';
import { test } from './fixtures/walletMock';
import { WalletPage } from './pages/WalletPage';

test('connects wallet and displays address', async ({ page }) => {
  const wallet = new WalletPage(page);
  await page.goto('/');
  await wallet.connect();
  expect(await wallet.isConnected()).toBe(true);
  expect(await wallet.getConnectedAddress()).toContain('mn_test_addr');
});
```

To test rejection flows, override `enable` to throw:

```typescript
await page.addInitScript(() => {
  (window as any).midnight = {
    mnLace: {
      enable: async () => {
        throw new Error('User rejected the connection request.');
      },
    },
  };
});
```

---

## Handling Async Blockchain State

Blockchain state transitions are never synchronous. Use Playwright's built-in
auto-waiting mechanisms — never assert on immediately-resolved values.

### `expect.poll()` for repeated assertions

```typescript
// Poll until contract state equals expected value, with a 30s ceiling
await expect.poll(
  () => dashboard.getContractStateDisplay(),
  { timeout: 30_000 },
).toBe('42');
```

### `page.waitForSelector()`

```typescript
// Wait for the confirmation element to appear in the DOM
await page.waitForSelector('[data-testid="tx-confirmed"]', {
  state: 'visible',
  timeout: 30_000,
});
```

### Custom `waitForTransactionConfirmation()`

Encapsulate the polling logic in a helper so tests stay readable:

```typescript
// tests/e2e/helpers/waitForTransactionConfirmation.ts
import { type Page } from '@playwright/test';

export async function waitForTransactionConfirmation(
  page: Page,
  timeout = 30_000,
): Promise<string> {
  await page.waitForSelector('[data-testid="tx-confirmed"]', {
    state: 'visible',
    timeout,
  });
  const hash = await page
    .getByTestId('tx-hash')
    .innerText();
  return hash;
}
```

### Timeout reference

| Operation | Recommended timeout |
|-----------|-------------------|
| Transaction confirmation | 30 000 ms |
| Complex multi-step operations | 60 000 ms |
| Standard UI interaction | Playwright default (5 000 ms) |
| Page navigation | Playwright default (30 000 ms) |

---

## Screenshot on Failure

Configure automatic screenshots in `playwright.config.ts` so failures are self-documenting:

```typescript
// playwright.config.ts (excerpt)
export default defineConfig({
  use: {
    headless: true,
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['junit', { outputFile: 'test-results/results.xml' }],
  ],
});
```

In CI, upload the `playwright-report/` and `test-results/` directories as artifacts so
failures can be inspected without re-running the suite:

```yaml
# .github/workflows/e2e.yml (excerpt)
- name: Upload Playwright report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: playwright-report
    path: playwright-report/
    retention-days: 14

- name: Upload test results
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: test-results/
    retention-days: 14
```

---

## Parallel Execution

Playwright runs test files in parallel workers by default. Midnight DApp tests must be
written so each worker is fully independent.

### Each test gets its own browser context

Playwright creates a new `BrowserContext` per test automatically. Never share page or
context objects across tests via module-level variables.

```typescript
// GOOD — each test receives its own `page` from the fixture
test('wallet connects', async ({ page }) => { ... });
test('transaction flow', async ({ page }) => { ... });

// BAD — shared page breaks parallel execution
let sharedPage: Page;
test.beforeAll(async ({ browser }) => {
  sharedPage = await browser.newPage();
});
```

### Deploy own contract instance or use test-specific state

Each parallel worker must operate on isolated contract state. In CI, either:

1. **Deploy a fresh contract per test** using the wallet mock's `submitTransaction` stub
   wired to an in-memory registry, or
2. **Use test-specific initial state** by seeding a different contract address per worker
   via an environment variable or Playwright's `workerIndex`:

```typescript
// tests/e2e/fixtures/contractFixture.ts
import { test as base } from '@playwright/test';

export const test = base.extend<{ contractAddress: string }>({
  contractAddress: async ({ workerIndex }, use) => {
    // Each worker gets a deterministic but unique address
    const address = `0x${workerIndex.toString(16).padStart(40, '0')}`;
    await use(address);
  },
});
```

Inject the address into the page before the app loads so the DApp targets the correct
contract for that worker:

```typescript
test('shows contract state', async ({ page, contractAddress }) => {
  await page.addInitScript((addr) => {
    (window as any).__TEST_CONTRACT_ADDRESS__ = addr;
  }, contractAddress);
  await page.goto('/');
  // ...
});
```
