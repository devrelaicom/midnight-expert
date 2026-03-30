# Playwright Configuration Reference

## Dependencies

```bash
npm install --save-dev @playwright/test
npx playwright install chromium
```

| Package | Purpose |
|---------|---------|
| `@playwright/test` | Playwright test runner and assertion library |

After installing, run `npx playwright install chromium` to download the browser binary. Only Chromium is needed -- Midnight DApps target modern browsers, and cross-browser testing adds CI time without catching Midnight-specific issues.

## playwright.config.ts Template

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: process.env.CI ? 1 : undefined,

  reporter: [['html'], ['list']],

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    headless: true, // Always headless. No exceptions. See "The Headless Rule" below.
    screenshot: 'only-on-failure',
    trace: 'on-first-retry',
    actionTimeout: 30_000, // 30s -- blockchain operations can be slow
  },

  timeout: 60_000, // 60s per test -- account for on-chain transactions

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120_000, // 2 minutes for dev server startup
  },
});
```

## Key Configuration Decisions

### Timeouts

Midnight DApp tests interact with blockchain operations that are slower than typical web requests:

- `actionTimeout: 30_000` (30 seconds) -- individual actions like clicking a button that triggers a transaction
- `timeout: 60_000` (60 seconds per test) -- the full test including setup, multiple actions, and assertions
- `webServer.timeout: 120_000` (2 minutes) -- dev server startup, which may need to compile assets

### Retries

`retries: 0` -- tests must be deterministic. If a test is flaky, fix the test. Retries mask real problems and slow CI.

### Reporter

`[['html'], ['list']]` -- the HTML reporter generates a browseable report in `playwright-report/` for debugging failures locally. The list reporter prints results to stdout for CI logs.

### Screenshot on Failure

`screenshot: 'only-on-failure'` -- captures the page state when a test fails. Stored in `test-results/` alongside trace files.

## Browser Configuration

Only Chromium is configured:

```typescript
projects: [
  {
    name: 'chromium',
    use: { ...devices['Desktop Chrome'] },
  },
],
```

Do not add Firefox or WebKit projects unless there is a specific, documented reason. Midnight DApps use the Midnight Lace wallet extension which is Chromium-based. Testing against other engines does not test realistic user scenarios and triples CI time.

## Web Server Configuration

```typescript
webServer: {
  command: 'npm run dev',
  url: 'http://localhost:3000',
  reuseExistingServer: !process.env.CI,
  timeout: 120_000,
},
```

- `command` -- starts the dev server before tests run
- `url` -- Playwright waits for this URL to respond before running tests
- `reuseExistingServer: !process.env.CI` -- in local development, reuse a running dev server to avoid restart delay. In CI, always start fresh to ensure a clean state.
- `timeout` -- allow up to 2 minutes for the dev server to start (Next.js and similar frameworks can be slow on first compile)

Adjust `command` and `url` to match your project's dev server setup. Common alternatives:

| Framework | Command | Default URL |
|-----------|---------|-------------|
| Next.js | `npm run dev` | `http://localhost:3000` |
| Vite | `npm run dev` | `http://localhost:5173` |
| Custom | `npm run start:dev` | Check your framework |

## The Headless Rule

The Playwright config always sets `headless: true`. This is not configurable through the config file. There are no flags, environment variables, or overrides that switch it to headed mode.

Why:

1. **CI compatibility** -- CI runners have no display. Headed mode fails immediately.
2. **Reproducibility** -- headed and headless rendering can differ subtly. One mode means one behavior.
3. **Speed** -- headless is faster. No window management, no GPU compositing overhead.
4. **Developer habit** -- if headed mode is easy to turn on, developers will leave it on and commit config that breaks CI.

When a developer needs to see the browser for debugging, they use the CLI flag directly:

```bash
npx playwright test --headed
```

Or use Playwright's UI mode for interactive debugging:

```bash
npx playwright test --ui
```

These are intentional, temporary, local overrides. They never enter the config file or version control.
