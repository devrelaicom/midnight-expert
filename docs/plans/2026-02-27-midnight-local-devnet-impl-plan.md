# Midnight Local Devnet MCP Server — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone MCP server + CLI tool (`midnight-devnet`) for managing a local Midnight development network with Docker Compose, wallet SDK integration, and test account generation.

**Architecture:** Fresh TypeScript codebase with three layers: `src/core/` (transport-agnostic business logic), `src/mcp/` (MCP tool/resource definitions), `src/cli/` (commander-based CLI). Docker Compose managed via `child_process.execFile`, wallet operations via `@midnight-ntwrk/wallet-sdk-*`.

**Tech Stack:** TypeScript, `@modelcontextprotocol/sdk`, `@midnight-ntwrk/wallet-sdk-*`, `commander`, `zod`, `pino`, `vitest`

**Design doc:** `docs/plans/2026-02-27-midnight-local-devnet-mcp-design.md`

**Note:** This project lives in its own standalone repository, **not** inside midnight-expert. Create a new repo `midnight-local-devnet` at the same directory level.

---

### Task 1: Project Scaffold

**Files:**
- Create: `package.json`
- Create: `tsconfig.json`
- Create: `.gitignore`
- Create: `docker/standalone.yml`
- Create: `docker/standalone.env`
- Create: `src/core/types.ts`
- Create: `src/core/config.ts`

**Step 1: Initialize repository**

```bash
mkdir -p ../midnight-local-devnet
cd ../midnight-local-devnet
git init
```

**Step 2: Create package.json**

```json
{
  "name": "midnight-local-devnet",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22.0.0"
  },
  "bin": {
    "midnight-devnet": "./dist/cli.js"
  },
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch",
    "start:mcp": "node --enable-source-maps dist/index.js",
    "start:cli": "node --enable-source-maps dist/cli.js",
    "test": "vitest run",
    "test:watch": "vitest"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.12.1",
    "@midnight-ntwrk/ledger-v7": "7.0.0",
    "@midnight-ntwrk/midnight-js-network-id": "3.1.0",
    "@midnight-ntwrk/wallet-sdk-abstractions": "1.0.0",
    "@midnight-ntwrk/wallet-sdk-address-format": "3.0.0",
    "@midnight-ntwrk/wallet-sdk-dust-wallet": "1.0.0",
    "@midnight-ntwrk/wallet-sdk-facade": "1.0.0",
    "@midnight-ntwrk/wallet-sdk-hd": "3.0.0",
    "@midnight-ntwrk/wallet-sdk-shielded": "1.0.0",
    "@midnight-ntwrk/wallet-sdk-unshielded-wallet": "1.0.0",
    "@scure/bip39": "^2.0.1",
    "commander": "^13.1.0",
    "pino": "^10.1.0",
    "pino-pretty": "^13.1.3",
    "rxjs": "^7.8.1",
    "ws": "^8.18.3",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/ws": "^8.18.1",
    "typescript": "^5.9.3",
    "vitest": "^3.1.0"
  },
  "resolutions": {
    "@midnight-ntwrk/ledger-v7": "7.0.0",
    "@midnight-ntwrk/midnight-js-network-id": "3.1.0"
  }
}
```

**Step 3: Create tsconfig.json**

```json
{
  "include": ["src/**/*.ts"],
  "compilerOptions": {
    "outDir": "dist",
    "declaration": true,
    "lib": ["ESNext"],
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "node",
    "forceConsistentCasingInFileNames": true,
    "noImplicitAny": true,
    "strict": true,
    "isolatedModules": true,
    "sourceMap": true,
    "resolveJsonModule": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  }
}
```

**Step 4: Create .gitignore**

```
node_modules/
dist/
logs/
.env
*.tgz
```

**Step 5: Create docker/standalone.yml**

Copy the Docker Compose file from the reference repo (see design doc, Docker Services section). The file defines three services: `midnight-node` (port 9944), `indexer` (port 8088), `proof-server` (port 6300), all using `undeployed` network ID with `dev` preset.

```yaml
services:
  proof-server:
    container_name: 'midnight-proof-server'
    image: 'midnightntwrk/proof-server:7.0.0'
    command: ['midnight-proof-server -v']
    ports:
      - '6300:6300'
    environment:
      RUST_BACKTRACE: 'full'
    healthcheck:
      test: ['CMD', 'curl', '-f', 'http://localhost:6300/version']
      interval: 10s
      timeout: 5s
      retries: 20
      start_period: 10s

  indexer:
    container_name: 'midnight-indexer'
    image: 'midnightntwrk/indexer-standalone:3.0.0'
    env_file: standalone.env
    ports:
      - '8088:8088'
    environment:
      RUST_LOG: 'indexer=info,chain_indexer=info,indexer_api=info,wallet_indexer=info,indexer_common=info,fastrace_opentelemetry=off,info'
      APP__APPLICATION__NETWORK_ID: 'undeployed'
    healthcheck:
      test: ['CMD-SHELL', 'cat /var/run/indexer-standalone/running']
      interval: 10s
      timeout: 5s
      retries: 20
      start_period: 10s
    depends_on:
      node:
        condition: service_healthy

  node:
    image: 'midnightntwrk/midnight-node:0.20.0'
    container_name: 'midnight-node'
    ports:
      - '9944:9944'
    healthcheck:
      test: ['CMD', 'curl', '-f', 'http://localhost:9944/health']
      interval: 2s
      timeout: 5s
      retries: 20
      start_period: 20s
    environment:
      CFG_PRESET: 'dev'
      SIDECHAIN_BLOCK_BENEFICIARY: '04bcf7ad3be7a5c790460be82a713af570f22e0f801f6659ab8e84a52be6969e'
```

**Step 6: Create docker/standalone.env**

```
APP__INFRA__NODE__URL=ws://node:9944
APP__INFRA__STORAGE__PASSWORD=indexer
APP__INFRA__PUB_SUB__PASSWORD=indexer
APP__INFRA__LEDGER_STATE_STORAGE__PASSWORD=indexer
APP__INFRA__SECRET=303132333435363738393031323334353637383930313233343536373839303132
```

**Step 7: Create src/core/types.ts**

```typescript
export interface NetworkConfig {
  readonly indexer: string;
  readonly indexerWS: string;
  readonly node: string;
  readonly proofServer: string;
  readonly networkId: string;
}

export type NetworkStatus = 'stopped' | 'starting' | 'running' | 'stopping';

export type ServiceName = 'node' | 'indexer' | 'proof-server';

export interface ServiceStatus {
  name: ServiceName;
  containerName: string;
  status: 'running' | 'stopped' | 'unhealthy' | 'unknown';
  port: number;
  url: string;
}

export interface NetworkState {
  status: NetworkStatus;
  services: ServiceStatus[];
}

export interface WalletBalances {
  unshielded: bigint;
  shielded: bigint;
  dust: bigint;
  total: bigint;
}

export interface FundedAccount {
  name: string;
  address: string;
  amount: bigint;
  hasDust: boolean;
}

export interface GeneratedAccount {
  name: string;
  mnemonic?: string;
  privateKey?: string;
  address: string;
}

export interface AccountsFileFormat {
  accounts: Array<{
    name: string;
    mnemonic?: string;
    privateKey?: string;
  }>;
}

export class DevnetError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly suggestion?: string,
  ) {
    super(message);
    this.name = 'DevnetError';
  }
}
```

**Step 8: Create src/core/config.ts**

```typescript
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { setNetworkId } from '@midnight-ntwrk/midnight-js-network-id';
import type { NetworkConfig } from './types.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const DOCKER_COMPOSE_DIR = path.resolve(__dirname, '../../docker');
export const DOCKER_COMPOSE_FILE = 'standalone.yml';

export const GENESIS_SEED = '0000000000000000000000000000000000000000000000000000000000000001';
export const DEFAULT_NIGHT_AMOUNT = 50_000n * 10n ** 6n; // 50,000 NIGHT in smallest unit
export const MAX_ACCOUNTS_PER_BATCH = 10;

export const DOCKER_IMAGES = {
  node: 'midnightntwrk/midnight-node:0.20.0',
  indexer: 'midnightntwrk/indexer-standalone:3.0.0',
  proofServer: 'midnightntwrk/proof-server:7.0.0',
} as const;

export const defaultConfig: NetworkConfig = {
  indexer: 'http://127.0.0.1:8088/api/v3/graphql',
  indexerWS: 'ws://127.0.0.1:8088/api/v3/graphql/ws',
  node: 'http://127.0.0.1:9944',
  proofServer: 'http://127.0.0.1:6300',
  networkId: 'undeployed',
};

export function initNetworkId(): void {
  setNetworkId(defaultConfig.networkId);
}
```

**Step 9: Run npm install**

```bash
npm install
```

**Step 10: Verify build compiles**

```bash
npx tsc --noEmit
```

Expected: Success (no errors).

**Step 11: Commit**

```bash
git add -A
git commit -m "feat: project scaffold with types, config, and docker compose"
```

---

### Task 2: Core Docker Module

**Files:**
- Create: `src/core/docker.ts`
- Create: `src/core/__tests__/docker.test.ts`

**Step 1: Write the failing test**

```typescript
// src/core/__tests__/docker.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { execFile } from 'node:child_process';

// Mock child_process before importing the module
vi.mock('node:child_process', () => ({
  execFile: vi.fn(),
}));

const mockExecFile = vi.mocked(execFile);

// Helper to make mockExecFile resolve
function mockExecSuccess(stdout: string, stderr = '') {
  mockExecFile.mockImplementation((_cmd, _args, _opts, callback: any) => {
    if (typeof _opts === 'function') {
      callback = _opts;
    }
    callback(null, stdout, stderr);
    return {} as any;
  });
}

function mockExecFailure(error: Error) {
  mockExecFile.mockImplementation((_cmd, _args, _opts, callback: any) => {
    if (typeof _opts === 'function') {
      callback = _opts;
    }
    callback(error, '', '');
    return {} as any;
  });
}

describe('docker', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe('isDockerRunning', () => {
    it('returns true when docker info succeeds', async () => {
      mockExecSuccess('Docker version 24.0.0');
      const { isDockerRunning } = await import('../docker.js');
      const result = await isDockerRunning();
      expect(result).toBe(true);
    });

    it('returns false when docker info fails', async () => {
      mockExecFailure(new Error('Cannot connect to Docker'));
      const { isDockerRunning } = await import('../docker.js');
      const result = await isDockerRunning();
      expect(result).toBe(false);
    });
  });

  describe('composeUp', () => {
    it('calls docker compose up -d with correct file path', async () => {
      mockExecSuccess('');
      const { composeUp } = await import('../docker.js');
      await composeUp({ pull: false });
      expect(mockExecFile).toHaveBeenCalledWith(
        'docker',
        expect.arrayContaining(['compose', 'up', '-d']),
        expect.any(Object),
        expect.any(Function),
      );
    });

    it('pulls images first when pull option is true', async () => {
      mockExecSuccess('');
      const { composeUp } = await import('../docker.js');
      await composeUp({ pull: true });
      // First call should be pull, second should be up
      expect(mockExecFile).toHaveBeenCalledTimes(2);
    });
  });

  describe('composeDown', () => {
    it('calls docker compose down', async () => {
      mockExecSuccess('');
      const { composeDown } = await import('../docker.js');
      await composeDown({ removeVolumes: false });
      expect(mockExecFile).toHaveBeenCalledWith(
        'docker',
        expect.arrayContaining(['compose', 'down']),
        expect.any(Object),
        expect.any(Function),
      );
    });

    it('passes -v flag when removeVolumes is true', async () => {
      mockExecSuccess('');
      const { composeDown } = await import('../docker.js');
      await composeDown({ removeVolumes: true });
      expect(mockExecFile).toHaveBeenCalledWith(
        'docker',
        expect.arrayContaining(['-v']),
        expect.any(Object),
        expect.any(Function),
      );
    });
  });

  describe('composePs', () => {
    it('parses docker compose ps --format json output', async () => {
      const psOutput = JSON.stringify([
        { Name: 'midnight-node', State: 'running', Status: 'Up 5 minutes' },
        { Name: 'midnight-indexer', State: 'running', Status: 'Up 3 minutes' },
        { Name: 'midnight-proof-server', State: 'running', Status: 'Up 4 minutes' },
      ]);
      mockExecSuccess(psOutput);
      const { composePs } = await import('../docker.js');
      const result = await composePs();
      expect(result).toHaveLength(3);
      expect(result[0].containerName).toBe('midnight-node');
      expect(result[0].status).toBe('running');
    });
  });

  describe('composeLogs', () => {
    it('returns logs for a specific service', async () => {
      mockExecSuccess('2026-02-27 log line 1\n2026-02-27 log line 2');
      const { composeLogs } = await import('../docker.js');
      const logs = await composeLogs({ service: 'node', lines: 50 });
      expect(logs).toContain('log line 1');
    });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npx vitest run src/core/__tests__/docker.test.ts
```

Expected: FAIL — `../docker.js` does not exist.

**Step 3: Write minimal implementation**

```typescript
// src/core/docker.ts
import { execFile as execFileCb } from 'node:child_process';
import { promisify } from 'node:util';
import { DOCKER_COMPOSE_DIR, DOCKER_COMPOSE_FILE } from './config.js';
import { DevnetError, type ServiceStatus, type ServiceName } from './types.js';

const execFile = promisify(execFileCb);

const COMPOSE_ARGS = [
  'compose',
  '-f',
  `${DOCKER_COMPOSE_DIR}/${DOCKER_COMPOSE_FILE}`,
];

const CONTAINER_TO_SERVICE: Record<string, { name: ServiceName; port: number; url: string }> = {
  'midnight-node': { name: 'node', port: 9944, url: 'http://127.0.0.1:9944' },
  'midnight-indexer': { name: 'indexer', port: 8088, url: 'http://127.0.0.1:8088/api/v3/graphql' },
  'midnight-proof-server': { name: 'proof-server', port: 6300, url: 'http://127.0.0.1:6300' },
};

export async function isDockerRunning(): Promise<boolean> {
  try {
    await execFile('docker', ['info'], { timeout: 5000 });
    return true;
  } catch {
    return false;
  }
}

function assertDocker(): Promise<void> {
  return isDockerRunning().then((running) => {
    if (!running) {
      throw new DevnetError(
        'Docker is not running.',
        'DOCKER_NOT_RUNNING',
        'Please start Docker Desktop.',
      );
    }
  });
}

export async function composeUp(opts: { pull: boolean }): Promise<void> {
  await assertDocker();
  if (opts.pull) {
    await execFile('docker', [...COMPOSE_ARGS, 'pull'], { timeout: 300_000 });
  }
  await execFile('docker', [...COMPOSE_ARGS, 'up', '-d', '--wait'], { timeout: 300_000 });
}

export async function composeDown(opts: { removeVolumes: boolean }): Promise<void> {
  const args = [...COMPOSE_ARGS, 'down'];
  if (opts.removeVolumes) {
    args.push('-v');
  }
  await execFile('docker', args, { timeout: 60_000 });
}

export async function composePs(): Promise<ServiceStatus[]> {
  const { stdout } = await execFile(
    'docker',
    [...COMPOSE_ARGS, 'ps', '--format', 'json'],
    { timeout: 10_000 },
  );

  let containers: Array<{ Name: string; State: string; Status: string }>;
  try {
    containers = JSON.parse(stdout);
  } catch {
    // docker compose ps --format json may output one JSON object per line
    containers = stdout
      .trim()
      .split('\n')
      .filter(Boolean)
      .map((line) => JSON.parse(line));
  }

  return containers.map((c) => {
    const svc = CONTAINER_TO_SERVICE[c.Name];
    return {
      name: svc?.name ?? (c.Name as ServiceName),
      containerName: c.Name,
      status: c.State === 'running' ? 'running' as const : 'stopped' as const,
      port: svc?.port ?? 0,
      url: svc?.url ?? '',
    };
  });
}

export async function composeLogs(opts: {
  service?: ServiceName;
  lines?: number;
}): Promise<string> {
  const args = [...COMPOSE_ARGS, 'logs', '--tail', String(opts.lines ?? 50)];
  if (opts.service) {
    args.push(opts.service);
  }
  const { stdout } = await execFile('docker', args, { timeout: 10_000 });
  return stdout;
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/core/__tests__/docker.test.ts
```

Expected: PASS (all tests green).

**Step 5: Commit**

```bash
git add src/core/docker.ts src/core/__tests__/docker.test.ts
git commit -m "feat: core docker module with compose lifecycle management"
```

---

### Task 3: Core Wallet Module

**Files:**
- Create: `src/core/wallet.ts`
- Create: `src/core/__tests__/wallet.test.ts`

This module wraps the Midnight wallet SDK. Integration tests require a running network, so we write unit tests for the structural parts and mark integration tests.

**Step 1: Write the test file**

```typescript
// src/core/__tests__/wallet.test.ts
import { describe, it, expect } from 'vitest';
import { GENESIS_SEED } from '../config.js';

describe('wallet', () => {
  describe('GENESIS_SEED', () => {
    it('is a 64-character hex string', () => {
      expect(GENESIS_SEED).toMatch(/^[0-9a-f]{64}$/);
    });
  });

  // Integration tests (require running network) are tagged
  // Run with: npx vitest run --testPathPattern wallet.integration
  describe('wallet module exports', () => {
    it('exports the expected functions', async () => {
      const wallet = await import('../wallet.js');
      expect(typeof wallet.initMasterWallet).toBe('function');
      expect(typeof wallet.getWalletBalances).toBe('function');
      expect(typeof wallet.mnemonicToSeed).toBe('function');
      expect(typeof wallet.initWalletFromSeed).toBe('function');
      expect(typeof wallet.initWalletFromMnemonic).toBe('function');
      expect(typeof wallet.registerDust).toBe('function');
      expect(typeof wallet.closeWallet).toBe('function');
    });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npx vitest run src/core/__tests__/wallet.test.ts
```

Expected: FAIL — `../wallet.js` does not exist.

**Step 3: Write the wallet module**

Reference the original `src/wallet.ts` from `hbulgarini/midnight-local-network` for exact SDK usage patterns. Key functions:

```typescript
// src/core/wallet.ts
import { HDWallet, Roles } from '@midnight-ntwrk/wallet-sdk-hd';
import { WalletFacade } from '@midnight-ntwrk/wallet-sdk-facade';
import { ShieldedWallet } from '@midnight-ntwrk/wallet-sdk-shielded';
import { DustWallet } from '@midnight-ntwrk/wallet-sdk-dust-wallet';
import {
  createKeystore,
  InMemoryTransactionHistoryStorage,
  PublicKey as UnshieldedPublicKey,
  type UnshieldedKeystore,
  UnshieldedWallet,
} from '@midnight-ntwrk/wallet-sdk-unshielded-wallet';
import * as ledger from '@midnight-ntwrk/ledger-v7';
import { generateMnemonic, mnemonicToSeedSync } from '@scure/bip39';
import { wordlist as english } from '@scure/bip39/wordlists/english.js';
import { WebSocket } from 'ws';
import { Buffer } from 'buffer';
import type { NetworkConfig, WalletBalances } from './types.js';
import { GENESIS_SEED, initNetworkId } from './config.js';
import { firstValueFrom } from 'rxjs';
import { filter } from 'rxjs/operators';
import type { Logger } from 'pino';

// Required for wallet SDK WebSocket support
// @ts-expect-error: Needed to enable WebSocket usage through apollo
globalThis.WebSocket = WebSocket;

export interface WalletContext {
  wallet: WalletFacade;
  shieldedSecretKeys: ledger.ZswapSecretKeys;
  dustSecretKey: ledger.DustSecretKey;
  unshieldedKeystore: UnshieldedKeystore;
}

let logger: Logger | null = null;

export function setLogger(l: Logger): void {
  logger = l;
}

export function mnemonicToSeed(mnemonic: string): Buffer {
  return Buffer.from(mnemonicToSeedSync(mnemonic));
}

export async function initWalletFromSeed(
  seed: Buffer,
  config: NetworkConfig,
): Promise<WalletContext> {
  initNetworkId();
  const hdWallet = HDWallet.fromSeed(seed);
  const shieldedSecretKeys = hdWallet.deriveKeys(Roles.SHIELD);
  const dustSecretKey = hdWallet.deriveDustKey();
  const coinPublicKey = hdWallet.deriveKey(Roles.COIN);
  const unshieldedKeystore = createKeystore(
    coinPublicKey,
    new UnshieldedPublicKey(coinPublicKey),
    new InMemoryTransactionHistoryStorage(),
  );

  const shieldedWallet = new ShieldedWallet(shieldedSecretKeys);
  const dustWallet = new DustWallet(dustSecretKey);
  const unshieldedWallet = new UnshieldedWallet(unshieldedKeystore);

  const wallet = new WalletFacade(
    unshieldedWallet,
    shieldedWallet,
    dustWallet,
    config.indexer,
    config.indexerWS,
    config.node,
    config.proofServer,
  );

  wallet.start();
  logger?.info('Waiting for wallet to sync...');
  await waitForSync(wallet);
  logger?.info('Wallet synced');

  return { wallet, shieldedSecretKeys, dustSecretKey, unshieldedKeystore };
}

export async function initWalletFromMnemonic(
  mnemonic: string,
  config: NetworkConfig,
): Promise<WalletContext> {
  const seed = mnemonicToSeed(mnemonic);
  return initWalletFromSeed(seed, config);
}

export async function initMasterWallet(config: NetworkConfig): Promise<WalletContext> {
  logger?.info('Initializing master wallet from genesis seed...');
  const seed = Buffer.from(GENESIS_SEED, 'hex');
  return initWalletFromSeed(seed, config);
}

async function waitForSync(wallet: WalletFacade): Promise<void> {
  await firstValueFrom(
    wallet.state().pipe(filter((state: any) => state.syncProgress === 'synced')),
  );
}

export async function waitForFunds(wallet: WalletFacade): Promise<void> {
  await firstValueFrom(
    wallet.state().pipe(filter((state: any) => (state.balances?.unshielded ?? 0n) > 0n)),
  );
}

export async function getWalletBalances(ctx: WalletContext): Promise<WalletBalances> {
  const state = await firstValueFrom(ctx.wallet.state());
  const balances = (state as any).balances ?? {};
  return {
    unshielded: balances.unshielded ?? 0n,
    shielded: balances.shielded ?? 0n,
    dust: balances.dust ?? 0n,
    total: (balances.unshielded ?? 0n) + (balances.shielded ?? 0n),
  };
}

export async function registerDust(ctx: WalletContext): Promise<boolean> {
  logger?.info('Registering NIGHT for DUST...');
  try {
    await ctx.wallet.registerForDust();
    // Wait for dust balance to appear
    await firstValueFrom(
      ctx.wallet.state().pipe(filter((state: any) => (state.balances?.dust ?? 0n) > 0n)),
    );
    logger?.info('DUST registration complete');
    return true;
  } catch (err) {
    logger?.error({ err }, 'DUST registration failed');
    return false;
  }
}

export async function closeWallet(ctx: WalletContext): Promise<void> {
  try {
    ctx.wallet.stop();
  } catch {
    // Ignore stop errors
  }
}

export function generateNewMnemonic(): string {
  return generateMnemonic(english, 256);
}
```

> **Important:** The exact wallet SDK API calls (`WalletFacade`, `HDWallet.fromSeed`, `wallet.registerForDust`, `wallet.state()`) are based on the reference repo. The wallet SDK may have slightly different method signatures — verify against the installed SDK types during implementation. Adjust `waitForSync` and `getWalletBalances` to match the actual `WalletFacade.state()` observable shape.

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/core/__tests__/wallet.test.ts
```

Expected: PASS.

**Step 5: Commit**

```bash
git add src/core/wallet.ts src/core/__tests__/wallet.test.ts
git commit -m "feat: core wallet module wrapping Midnight wallet SDK"
```

---

### Task 4: Core Funding Module

**Files:**
- Create: `src/core/funding.ts`
- Create: `src/core/__tests__/funding.test.ts`

**Step 1: Write the test file**

```typescript
// src/core/__tests__/funding.test.ts
import { describe, it, expect } from 'vitest';
import { DEFAULT_NIGHT_AMOUNT, MAX_ACCOUNTS_PER_BATCH } from '../config.js';

describe('funding', () => {
  describe('constants', () => {
    it('DEFAULT_NIGHT_AMOUNT is 50,000 NIGHT in smallest unit', () => {
      expect(DEFAULT_NIGHT_AMOUNT).toBe(50_000n * 10n ** 6n);
    });

    it('MAX_ACCOUNTS_PER_BATCH is 10', () => {
      expect(MAX_ACCOUNTS_PER_BATCH).toBe(10);
    });
  });

  describe('funding module exports', () => {
    it('exports the expected functions', async () => {
      const funding = await import('../funding.js');
      expect(typeof funding.transferNight).toBe('function');
      expect(typeof funding.fundAccount).toBe('function');
      expect(typeof funding.fundAccountFromMnemonic).toBe('function');
      expect(typeof funding.fundAccountsFromFile).toBe('function');
    });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npx vitest run src/core/__tests__/funding.test.ts
```

Expected: FAIL — `../funding.js` does not exist.

**Step 3: Write the funding module**

```typescript
// src/core/funding.ts
import { readFile } from 'node:fs/promises';
import type { Logger } from 'pino';
import type {
  NetworkConfig,
  FundedAccount,
  AccountsFileFormat,
} from './types.js';
import { DevnetError } from './types.js';
import { DEFAULT_NIGHT_AMOUNT, MAX_ACCOUNTS_PER_BATCH } from './config.js';
import {
  type WalletContext,
  initWalletFromMnemonic,
  waitForFunds,
  registerDust,
  closeWallet,
  getWalletBalances,
} from './wallet.js';

let logger: Logger | null = null;

export function setLogger(l: Logger): void {
  logger = l;
}

export async function transferNight(
  masterWallet: WalletContext,
  receiverAddress: string,
  amount: bigint,
): Promise<string> {
  logger?.info({ receiverAddress, amount: amount.toString() }, 'Transferring NIGHT...');
  const tx = await masterWallet.wallet.transferUnshielded(receiverAddress, amount);
  logger?.info({ txHash: tx }, 'Transfer complete');
  return String(tx);
}

export async function fundAccount(
  masterWallet: WalletContext,
  address: string,
  amount: bigint = DEFAULT_NIGHT_AMOUNT,
): Promise<FundedAccount> {
  // Check master wallet has sufficient balance
  const balances = await getWalletBalances(masterWallet);
  if (balances.unshielded < amount) {
    throw new DevnetError(
      `Insufficient master wallet balance: ${balances.unshielded} < ${amount}`,
      'INSUFFICIENT_BALANCE',
      'The master wallet does not have enough NIGHT to fund this account.',
    );
  }

  const txHash = await transferNight(masterWallet, address, amount);
  logger?.info({ address, txHash }, 'Account funded');

  return {
    name: address.slice(0, 12) + '...',
    address,
    amount,
    hasDust: false,
  };
}

export async function fundAccountFromMnemonic(
  masterWallet: WalletContext,
  name: string,
  mnemonic: string,
  config: NetworkConfig,
  amount: bigint = DEFAULT_NIGHT_AMOUNT,
): Promise<FundedAccount> {
  // Derive wallet from mnemonic to get address
  logger?.info({ name }, 'Deriving wallet from mnemonic...');
  const recipientCtx = await initWalletFromMnemonic(mnemonic, config);
  const recipientState = await recipientCtx.wallet.state().pipe().toPromise();
  const address = String((recipientState as any).address ?? 'unknown');

  // Transfer NIGHT from master
  await transferNight(masterWallet, address, amount);

  // Wait for recipient to see funds
  logger?.info({ name }, 'Waiting for recipient to sync funds...');
  await waitForFunds(recipientCtx.wallet);

  // Register DUST
  const hasDust = await registerDust(recipientCtx);

  // Close recipient wallet
  await closeWallet(recipientCtx);

  return { name, address, amount, hasDust };
}

export async function fundAccountsFromFile(
  masterWallet: WalletContext,
  filePath: string,
  config: NetworkConfig,
): Promise<FundedAccount[]> {
  const raw = await readFile(filePath, 'utf-8');
  let accountsFile: AccountsFileFormat;
  try {
    accountsFile = JSON.parse(raw);
  } catch {
    throw new DevnetError(
      `Invalid JSON in accounts file: ${filePath}`,
      'INVALID_ACCOUNTS_FILE',
    );
  }

  if (!accountsFile.accounts || !Array.isArray(accountsFile.accounts)) {
    throw new DevnetError(
      'Accounts file must contain an "accounts" array',
      'INVALID_ACCOUNTS_FILE',
    );
  }

  if (accountsFile.accounts.length > MAX_ACCOUNTS_PER_BATCH) {
    throw new DevnetError(
      `Maximum ${MAX_ACCOUNTS_PER_BATCH} accounts per batch. Got ${accountsFile.accounts.length}.`,
      'TOO_MANY_ACCOUNTS',
    );
  }

  const funded: FundedAccount[] = [];
  for (const account of accountsFile.accounts) {
    if (account.mnemonic) {
      const result = await fundAccountFromMnemonic(
        masterWallet,
        account.name,
        account.mnemonic,
        config,
      );
      funded.push(result);
    } else {
      throw new DevnetError(
        `Account "${account.name}" has no mnemonic or privateKey`,
        'INVALID_ACCOUNT_ENTRY',
      );
    }
  }

  return funded;
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/core/__tests__/funding.test.ts
```

Expected: PASS.

**Step 5: Commit**

```bash
git add src/core/funding.ts src/core/__tests__/funding.test.ts
git commit -m "feat: core funding module for NIGHT transfers and DUST registration"
```

---

### Task 5: Core Account Generation Module

**Files:**
- Create: `src/core/accounts.ts`
- Create: `src/core/__tests__/accounts.test.ts`

**Step 1: Write the failing test**

```typescript
// src/core/__tests__/accounts.test.ts
import { describe, it, expect, vi } from 'vitest';

describe('accounts', () => {
  describe('generateAccounts', () => {
    it('generates the requested number of accounts with mnemonics', async () => {
      const { generateAccounts } = await import('../accounts.js');
      const accounts = await generateAccounts({ format: 'mnemonic', count: 3 });
      expect(accounts).toHaveLength(3);
      accounts.forEach((a, i) => {
        expect(a.name).toBe(`Account ${i + 1}`);
        expect(a.mnemonic).toBeDefined();
        expect(a.mnemonic!.split(' ')).toHaveLength(24);
        expect(a.privateKey).toBeUndefined();
      });
    });

    it('defaults to count=1', async () => {
      const { generateAccounts } = await import('../accounts.js');
      const accounts = await generateAccounts({ format: 'mnemonic' });
      expect(accounts).toHaveLength(1);
    });
  });

  describe('writeAccountsFile', () => {
    it('writes accounts in the expected JSON format', async () => {
      const { writeAccountsFile } = await import('../accounts.js');
      const fs = await import('node:fs/promises');
      const writeSpy = vi.spyOn(fs, 'writeFile').mockResolvedValue();

      await writeAccountsFile('/tmp/test-accounts.json', [
        { name: 'Account 1', mnemonic: 'word '.repeat(24).trim(), address: 'mn1q...' },
      ]);

      expect(writeSpy).toHaveBeenCalledOnce();
      const written = JSON.parse(writeSpy.mock.calls[0][1] as string);
      expect(written.accounts).toHaveLength(1);
      expect(written.accounts[0].name).toBe('Account 1');
      expect(written.accounts[0].mnemonic).toBeDefined();

      writeSpy.mockRestore();
    });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npx vitest run src/core/__tests__/accounts.test.ts
```

Expected: FAIL — `../accounts.js` does not exist.

**Step 3: Write the accounts module**

```typescript
// src/core/accounts.ts
import { writeFile } from 'node:fs/promises';
import type { GeneratedAccount, AccountsFileFormat, NetworkConfig, FundedAccount } from './types.js';
import {
  generateNewMnemonic,
  initWalletFromMnemonic,
  registerDust,
  closeWallet,
} from './wallet.js';
import { fundAccount } from './funding.js';
import type { WalletContext } from './wallet.js';
import { DEFAULT_NIGHT_AMOUNT } from './config.js';
import type { Logger } from 'pino';

let logger: Logger | null = null;

export function setLogger(l: Logger): void {
  logger = l;
}

export interface GenerateOptions {
  format: 'mnemonic' | 'privateKey';
  count?: number;
}

export async function generateAccounts(opts: GenerateOptions): Promise<GeneratedAccount[]> {
  const count = opts.count ?? 1;
  const accounts: GeneratedAccount[] = [];

  for (let i = 0; i < count; i++) {
    const mnemonic = generateNewMnemonic();
    accounts.push({
      name: `Account ${i + 1}`,
      mnemonic: opts.format === 'mnemonic' ? mnemonic : undefined,
      // For privateKey format, we'd derive the key from the mnemonic
      // and return the hex seed instead. For now, mnemonic is the source.
      privateKey: opts.format === 'privateKey' ? mnemonic : undefined,
      address: '', // Address is derived when wallet is initialized on-chain
    });
  }

  return accounts;
}

export async function generateAndFundAccounts(
  masterWallet: WalletContext,
  config: NetworkConfig,
  opts: GenerateOptions & { fund?: boolean; registerDust?: boolean },
): Promise<(GeneratedAccount & { funded?: boolean; dustRegistered?: boolean })[]> {
  const accounts = await generateAccounts(opts);
  const results = [];

  for (const account of accounts) {
    const mnemonic = account.mnemonic ?? account.privateKey;
    if (!mnemonic) continue;

    if (opts.fund) {
      logger?.info({ name: account.name }, 'Funding account...');
      const ctx = await initWalletFromMnemonic(mnemonic, config);
      const state = await ctx.wallet.state().pipe().toPromise();
      const address = String((state as any).address ?? 'unknown');
      account.address = address;

      await fundAccount(masterWallet, address, DEFAULT_NIGHT_AMOUNT);

      if (opts.registerDust) {
        const dustOk = await registerDust(ctx);
        results.push({ ...account, funded: true, dustRegistered: dustOk });
      } else {
        results.push({ ...account, funded: true, dustRegistered: false });
      }

      await closeWallet(ctx);
    } else {
      results.push({ ...account, funded: false, dustRegistered: false });
    }
  }

  return results;
}

export async function writeAccountsFile(
  filePath: string,
  accounts: GeneratedAccount[],
): Promise<void> {
  const fileContent: AccountsFileFormat = {
    accounts: accounts.map((a) => ({
      name: a.name,
      ...(a.mnemonic ? { mnemonic: a.mnemonic } : {}),
      ...(a.privateKey ? { privateKey: a.privateKey } : {}),
    })),
  };
  await writeFile(filePath, JSON.stringify(fileContent, null, 2) + '\n', 'utf-8');
  logger?.info({ filePath, count: accounts.length }, 'Accounts file written');
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/core/__tests__/accounts.test.ts
```

Expected: PASS.

**Step 5: Commit**

```bash
git add src/core/accounts.ts src/core/__tests__/accounts.test.ts
git commit -m "feat: core account generation with file output"
```

---

### Task 6: Core Health Check Module

**Files:**
- Create: `src/core/health.ts`
- Create: `src/core/__tests__/health.test.ts`

**Step 1: Write the failing test**

```typescript
// src/core/__tests__/health.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock global fetch
const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

describe('health', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  describe('checkServiceHealth', () => {
    it('returns healthy when all services respond', async () => {
      mockFetch.mockResolvedValue({ ok: true, text: () => Promise.resolve('OK') });
      const { checkAllHealth } = await import('../health.js');
      const result = await checkAllHealth();
      expect(result.node.healthy).toBe(true);
      expect(result.indexer.healthy).toBe(true);
      expect(result.proofServer.healthy).toBe(true);
    });

    it('returns unhealthy when a service fails', async () => {
      mockFetch
        .mockResolvedValueOnce({ ok: true, text: () => Promise.resolve('OK') })  // node
        .mockRejectedValueOnce(new Error('Connection refused'))                     // indexer
        .mockResolvedValueOnce({ ok: true, text: () => Promise.resolve('1.0') }); // proof-server
      const { checkAllHealth } = await import('../health.js');
      const result = await checkAllHealth();
      expect(result.node.healthy).toBe(true);
      expect(result.indexer.healthy).toBe(false);
      expect(result.proofServer.healthy).toBe(true);
    });
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npx vitest run src/core/__tests__/health.test.ts
```

Expected: FAIL — `../health.js` does not exist.

**Step 3: Write the health module**

```typescript
// src/core/health.ts
import { defaultConfig } from './config.js';

export interface ServiceHealth {
  healthy: boolean;
  responseTime?: number;
  error?: string;
}

export interface HealthReport {
  node: ServiceHealth;
  indexer: ServiceHealth;
  proofServer: ServiceHealth;
  allHealthy: boolean;
}

async function checkEndpoint(url: string): Promise<ServiceHealth> {
  const start = Date.now();
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(5000) });
    return {
      healthy: response.ok,
      responseTime: Date.now() - start,
    };
  } catch (err) {
    return {
      healthy: false,
      responseTime: Date.now() - start,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

export async function checkAllHealth(): Promise<HealthReport> {
  const [node, indexer, proofServer] = await Promise.all([
    checkEndpoint(`${defaultConfig.node}/health`),
    checkEndpoint(defaultConfig.indexer),
    checkEndpoint(`${defaultConfig.proofServer}/version`),
  ]);

  return {
    node,
    indexer,
    proofServer,
    allHealthy: node.healthy && indexer.healthy && proofServer.healthy,
  };
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/core/__tests__/health.test.ts
```

Expected: PASS.

**Step 5: Commit**

```bash
git add src/core/health.ts src/core/__tests__/health.test.ts
git commit -m "feat: core health check module for service endpoints"
```

---

### Task 7: MCP Server with Network Tools

**Files:**
- Create: `src/mcp/server.ts`
- Create: `src/mcp/tools/network.ts`
- Create: `src/mcp/tools/health.ts`
- Create: `src/mcp/resources/config.ts`
- Create: `src/index.ts`

**Step 1: Create the MCP server setup**

```typescript
// src/mcp/server.ts
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { registerNetworkTools } from './tools/network.js';
import { registerHealthTools } from './tools/health.js';
import { registerWalletTools } from './tools/wallet.js';
import { registerFundingTools } from './tools/funding.js';
import { registerAccountTools } from './tools/accounts.js';
import { registerResources } from './resources/config.js';

export function createServer(): McpServer {
  const server = new McpServer(
    {
      name: 'midnight-local-devnet',
      version: '0.1.0',
    },
    {
      capabilities: {
        logging: {},
        resources: {},
        tools: {},
      },
    },
  );

  registerNetworkTools(server);
  registerHealthTools(server);
  registerWalletTools(server);
  registerFundingTools(server);
  registerAccountTools(server);
  registerResources(server);

  return server;
}
```

**Step 2: Create the network tools**

```typescript
// src/mcp/tools/network.ts
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { composeUp, composeDown, composePs, composeLogs } from '../../core/docker.js';
import { initMasterWallet, registerDust, closeWallet, type WalletContext } from '../../core/wallet.js';
import { defaultConfig } from '../../core/config.js';
import type { NetworkStatus } from '../../core/types.js';

// Module-level state
let networkStatus: NetworkStatus = 'stopped';
let masterWallet: WalletContext | null = null;

export function getMasterWallet(): WalletContext | null {
  return masterWallet;
}

export function getNetworkStatus(): NetworkStatus {
  return networkStatus;
}

export function registerNetworkTools(server: McpServer): void {
  server.registerTool(
    'start-network',
    {
      title: 'Start Local Devnet',
      description:
        'Start the local Midnight development network (node, indexer, proof-server). ' +
        'Initializes the genesis master wallet and registers DUST.',
      inputSchema: z.object({
        pull: z.boolean().optional().describe('Pull latest Docker images before starting'),
      }),
    },
    async ({ pull }) => {
      if (networkStatus === 'running') {
        return { content: [{ type: 'text', text: 'Network is already running.' }] };
      }

      networkStatus = 'starting';
      try {
        await composeUp({ pull: pull ?? false });
        masterWallet = await initMasterWallet(defaultConfig);
        await registerDust(masterWallet);
        networkStatus = 'running';

        const services = await composePs();
        return {
          content: [{
            type: 'text',
            text: JSON.stringify({
              status: 'running',
              services: services.map((s) => ({ name: s.name, url: s.url, port: s.port })),
              masterWalletAddress: 'initialized',
              config: defaultConfig,
            }, null, 2),
          }],
        };
      } catch (err) {
        networkStatus = 'stopped';
        throw err;
      }
    },
  );

  server.registerTool(
    'stop-network',
    {
      title: 'Stop Local Devnet',
      description: 'Stop the local Midnight development network and close all wallets.',
      inputSchema: z.object({
        removeVolumes: z.boolean().optional().describe('Remove volumes and containers (clean slate)'),
      }),
    },
    async ({ removeVolumes }) => {
      networkStatus = 'stopping';
      try {
        if (masterWallet) {
          await closeWallet(masterWallet);
          masterWallet = null;
        }
        await composeDown({ removeVolumes: removeVolumes ?? false });
        networkStatus = 'stopped';
        return { content: [{ type: 'text', text: 'Network stopped.' }] };
      } catch (err) {
        networkStatus = 'stopped';
        throw err;
      }
    },
  );

  server.registerTool(
    'restart-network',
    {
      title: 'Restart Local Devnet',
      description: 'Restart the network. With removeVolumes, performs a clean-slate restart.',
      inputSchema: z.object({
        pull: z.boolean().optional().describe('Pull latest Docker images'),
        removeVolumes: z.boolean().optional().describe('Remove volumes for clean restart'),
      }),
    },
    async ({ pull, removeVolumes }) => {
      // Stop
      if (masterWallet) {
        await closeWallet(masterWallet);
        masterWallet = null;
      }
      await composeDown({ removeVolumes: removeVolumes ?? false });

      // Start
      networkStatus = 'starting';
      await composeUp({ pull: pull ?? false });
      masterWallet = await initMasterWallet(defaultConfig);
      await registerDust(masterWallet);
      networkStatus = 'running';

      const services = await composePs();
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            status: 'running',
            services: services.map((s) => ({ name: s.name, url: s.url, port: s.port })),
          }, null, 2),
        }],
      };
    },
  );

  server.registerTool(
    'network-status',
    {
      title: 'Network Status',
      description: 'Get current network status including per-service container status.',
      inputSchema: z.object({}),
    },
    async () => {
      if (networkStatus === 'stopped') {
        return {
          content: [{ type: 'text', text: JSON.stringify({ status: 'stopped', services: [] }) }],
        };
      }
      const services = await composePs();
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ status: networkStatus, services }, null, 2),
        }],
      };
    },
  );

  server.registerTool(
    'network-logs',
    {
      title: 'Network Logs',
      description: 'Get recent logs from network services.',
      inputSchema: z.object({
        service: z.enum(['node', 'indexer', 'proof-server']).optional().describe('Specific service'),
        lines: z.number().optional().describe('Number of log lines (default: 50)'),
      }),
    },
    async ({ service, lines }) => {
      const logs = await composeLogs({ service, lines });
      return { content: [{ type: 'text', text: logs }] };
    },
  );
}
```

**Step 3: Create the health tools**

```typescript
// src/mcp/tools/health.ts
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { checkAllHealth } from '../../core/health.js';
import { defaultConfig, DOCKER_IMAGES } from '../../core/config.js';

export function registerHealthTools(server: McpServer): void {
  server.registerTool(
    'health-check',
    {
      title: 'Health Check',
      description: 'Check health of all network services by hitting their endpoints.',
      inputSchema: z.object({}),
    },
    async () => {
      const health = await checkAllHealth();
      return {
        content: [{ type: 'text', text: JSON.stringify(health, null, 2) }],
      };
    },
  );

  server.registerTool(
    'get-network-config',
    {
      title: 'Get Network Config',
      description: 'Get all endpoint URLs, network ID, and Docker image versions for connecting a DApp.',
      inputSchema: z.object({}),
    },
    async () => {
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({ ...defaultConfig, images: DOCKER_IMAGES }, null, 2),
        }],
      };
    },
  );
}
```

**Step 4: Create stub files for wallet, funding, and account tools**

Create empty registration functions that will be implemented in the next tasks:

```typescript
// src/mcp/tools/wallet.ts
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
export function registerWalletTools(_server: McpServer): void {
  // Implemented in Task 8
}

// src/mcp/tools/funding.ts
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
export function registerFundingTools(_server: McpServer): void {
  // Implemented in Task 8
}

// src/mcp/tools/accounts.ts
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
export function registerAccountTools(_server: McpServer): void {
  // Implemented in Task 8
}
```

**Step 5: Create MCP resources**

```typescript
// src/mcp/resources/config.ts
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { defaultConfig, DOCKER_IMAGES } from '../../core/config.js';
import { getNetworkStatus } from '../tools/network.js';
import { composePs } from '../../core/docker.js';

export function registerResources(server: McpServer): void {
  server.registerResource(
    'devnet-config',
    'devnet://config',
    {
      title: 'Devnet Configuration',
      description: 'Current network configuration including endpoints and image versions.',
      mimeType: 'application/json',
    },
    async (uri) => ({
      contents: [{
        uri: uri.href,
        text: JSON.stringify({ ...defaultConfig, images: DOCKER_IMAGES }, null, 2),
      }],
    }),
  );

  server.registerResource(
    'devnet-status',
    'devnet://status',
    {
      title: 'Devnet Status',
      description: 'Live network status including services and health.',
      mimeType: 'application/json',
    },
    async (uri) => {
      const status = getNetworkStatus();
      let services: any[] = [];
      if (status !== 'stopped') {
        try {
          services = await composePs();
        } catch {
          // Network might be partially up
        }
      }
      return {
        contents: [{
          uri: uri.href,
          text: JSON.stringify({ status, services }, null, 2),
        }],
      };
    },
  );
}
```

**Step 6: Create the MCP entry point**

```typescript
// src/index.ts
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { createServer } from './mcp/server.js';

async function main() {
  const server = createServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
```

**Step 7: Verify build compiles**

```bash
npx tsc --noEmit
```

Expected: Success (may need minor type adjustments).

**Step 8: Commit**

```bash
git add src/mcp/ src/index.ts
git commit -m "feat: MCP server with network, health tools and resources"
```

---

### Task 8: MCP Wallet, Funding, and Account Tools

**Files:**
- Modify: `src/mcp/tools/wallet.ts`
- Modify: `src/mcp/tools/funding.ts`
- Modify: `src/mcp/tools/accounts.ts`

**Step 1: Implement wallet tools**

```typescript
// src/mcp/tools/wallet.ts
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { getWalletBalances } from '../../core/wallet.js';
import { getMasterWallet, getNetworkStatus } from './network.js';
import { DevnetError } from '../../core/types.js';

function requireRunning() {
  if (getNetworkStatus() !== 'running' || !getMasterWallet()) {
    throw new DevnetError(
      'Network is not running. Call start-network first.',
      'NETWORK_NOT_RUNNING',
    );
  }
}

export function registerWalletTools(server: McpServer): void {
  server.registerTool(
    'get-wallet-balances',
    {
      title: 'Get Master Wallet Balances',
      description: 'Get current NIGHT and DUST balances of the genesis master wallet.',
      inputSchema: z.object({}),
    },
    async () => {
      requireRunning();
      const balances = await getWalletBalances(getMasterWallet()!);
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            unshielded: balances.unshielded.toString(),
            shielded: balances.shielded.toString(),
            dust: balances.dust.toString(),
            total: balances.total.toString(),
          }, null, 2),
        }],
      };
    },
  );
}
```

**Step 2: Implement funding tools**

```typescript
// src/mcp/tools/funding.ts
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { fundAccount, fundAccountFromMnemonic, fundAccountsFromFile } from '../../core/funding.js';
import { defaultConfig } from '../../core/config.js';
import { getMasterWallet, getNetworkStatus } from './network.js';
import { DevnetError } from '../../core/types.js';

function requireRunning() {
  if (getNetworkStatus() !== 'running' || !getMasterWallet()) {
    throw new DevnetError(
      'Network is not running. Call start-network first.',
      'NETWORK_NOT_RUNNING',
    );
  }
}

export function registerFundingTools(server: McpServer): void {
  server.registerTool(
    'fund-account',
    {
      title: 'Fund Account',
      description: 'Transfer NIGHT tokens from master wallet to a Bech32 address. Default: 50,000 NIGHT.',
      inputSchema: z.object({
        address: z.string().describe('Bech32 address to fund'),
        amount: z.string().optional().describe('Amount in smallest unit (default: 50,000 NIGHT)'),
      }),
    },
    async ({ address, amount }) => {
      requireRunning();
      const result = await fundAccount(
        getMasterWallet()!,
        address,
        amount ? BigInt(amount) : undefined,
      );
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            address: result.address,
            amount: result.amount.toString(),
            hasDust: result.hasDust,
          }, null, 2),
        }],
      };
    },
  );

  server.registerTool(
    'fund-account-from-mnemonic',
    {
      title: 'Fund Account from Mnemonic',
      description: 'Derive wallet from mnemonic, transfer NIGHT, and register DUST. Full account setup.',
      inputSchema: z.object({
        name: z.string().describe('Display name for the account'),
        mnemonic: z.string().describe('BIP39 mnemonic phrase (24 words)'),
      }),
    },
    async ({ name, mnemonic }) => {
      requireRunning();
      const result = await fundAccountFromMnemonic(
        getMasterWallet()!,
        name,
        mnemonic,
        defaultConfig,
      );
      return {
        content: [{
          type: 'text',
          text: JSON.stringify({
            name: result.name,
            address: result.address,
            amount: result.amount.toString(),
            hasDust: result.hasDust,
          }, null, 2),
        }],
      };
    },
  );

  server.registerTool(
    'fund-accounts-from-file',
    {
      title: 'Fund Accounts from File',
      description: 'Batch fund accounts from an accounts.json file. Each gets 50,000 NIGHT + DUST.',
      inputSchema: z.object({
        filePath: z.string().describe('Path to accounts.json file'),
      }),
    },
    async ({ filePath }) => {
      requireRunning();
      const results = await fundAccountsFromFile(getMasterWallet()!, filePath, defaultConfig);
      return {
        content: [{
          type: 'text',
          text: JSON.stringify(
            results.map((r) => ({
              name: r.name,
              address: r.address,
              amount: r.amount.toString(),
              hasDust: r.hasDust,
            })),
            null,
            2,
          ),
        }],
      };
    },
  );
}
```

**Step 3: Implement account generation tools**

```typescript
// src/mcp/tools/accounts.ts
import { z } from 'zod';
import type { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { generateAccounts, generateAndFundAccounts, writeAccountsFile } from '../../core/accounts.js';
import { defaultConfig } from '../../core/config.js';
import { getMasterWallet, getNetworkStatus } from './network.js';
import { DevnetError } from '../../core/types.js';

export function registerAccountTools(server: McpServer): void {
  server.registerTool(
    'generate-test-account',
    {
      title: 'Generate Test Account',
      description:
        'Generate random test accounts with BIP39 mnemonics or private keys. ' +
        'Optionally fund them and register DUST. Use outputFile to write accounts.json format.',
      inputSchema: z.object({
        format: z.enum(['mnemonic', 'privateKey']).describe('Credential format'),
        count: z.number().optional().describe('Number of accounts to generate (default: 1)'),
        fund: z.boolean().optional().describe('Fund accounts from master wallet'),
        registerDust: z.boolean().optional().describe('Register DUST for funded accounts'),
        outputFile: z.string().optional().describe('Write accounts to file in accounts.json format'),
      }),
    },
    async ({ format, count, fund, registerDust: regDust, outputFile }) => {
      let accounts;

      if (fund) {
        if (getNetworkStatus() !== 'running' || !getMasterWallet()) {
          throw new DevnetError(
            'Network must be running to fund accounts. Call start-network first.',
            'NETWORK_NOT_RUNNING',
          );
        }
        accounts = await generateAndFundAccounts(
          getMasterWallet()!,
          defaultConfig,
          { format, count, fund: true, registerDust: regDust },
        );
      } else {
        accounts = await generateAccounts({ format, count });
      }

      if (outputFile) {
        await writeAccountsFile(outputFile, accounts);
      }

      return {
        content: [{
          type: 'text',
          text: JSON.stringify(accounts, null, 2),
        }],
      };
    },
  );
}
```

**Step 4: Verify build compiles**

```bash
npx tsc --noEmit
```

Expected: Success.

**Step 5: Commit**

```bash
git add src/mcp/tools/wallet.ts src/mcp/tools/funding.ts src/mcp/tools/accounts.ts
git commit -m "feat: MCP wallet, funding, and account generation tools"
```

---

### Task 9: CLI Entry Point and Commands

**Files:**
- Create: `src/cli.ts`
- Create: `src/cli/commands/network.ts`
- Create: `src/cli/commands/wallet.ts`
- Create: `src/cli/commands/accounts.ts`
- Create: `src/cli/interactive.ts`

**Step 1: Create the CLI entry point**

```typescript
// src/cli.ts
#!/usr/bin/env node
import { Command } from 'commander';
import { registerNetworkCommands } from './cli/commands/network.js';
import { registerWalletCommands } from './cli/commands/wallet.js';
import { registerAccountCommands } from './cli/commands/accounts.js';
import { startInteractiveMode } from './cli/interactive.js';

const program = new Command();

program
  .name('midnight-devnet')
  .description('Manage a local Midnight development network')
  .version('0.1.0');

registerNetworkCommands(program);
registerWalletCommands(program);
registerAccountCommands(program);

program
  .command('interactive')
  .description('Start interactive menu mode')
  .action(async () => {
    await startInteractiveMode();
  });

// No arguments = interactive mode
if (process.argv.length <= 2) {
  startInteractiveMode().catch(console.error);
} else {
  program.parse();
}
```

**Step 2: Create network CLI commands**

```typescript
// src/cli/commands/network.ts
import type { Command } from 'commander';
import { composeUp, composeDown, composePs, composeLogs } from '../../core/docker.js';
import { initMasterWallet, registerDust, closeWallet, type WalletContext } from '../../core/wallet.js';
import { checkAllHealth } from '../../core/health.js';
import { defaultConfig } from '../../core/config.js';

// CLI-level state (separate from MCP state)
let masterWallet: WalletContext | null = null;

export function getCliMasterWallet(): WalletContext | null {
  return masterWallet;
}

export function registerNetworkCommands(program: Command): void {
  program
    .command('start')
    .description('Start the local Midnight development network')
    .option('--pull', 'Pull latest Docker images before starting')
    .action(async (opts) => {
      console.log('Starting Midnight local devnet...');
      await composeUp({ pull: opts.pull ?? false });
      console.log('Containers started. Initializing master wallet...');
      masterWallet = await initMasterWallet(defaultConfig);
      await registerDust(masterWallet);
      console.log('Network is ready.');
      const services = await composePs();
      console.table(services.map((s) => ({ Service: s.name, Port: s.port, URL: s.url, Status: s.status })));
    });

  program
    .command('stop')
    .description('Stop the local Midnight development network')
    .option('--remove-volumes', 'Remove volumes and containers')
    .action(async (opts) => {
      if (masterWallet) {
        await closeWallet(masterWallet);
        masterWallet = null;
      }
      await composeDown({ removeVolumes: opts.removeVolumes ?? false });
      console.log('Network stopped.');
    });

  program
    .command('restart')
    .description('Restart the network')
    .option('--pull', 'Pull latest Docker images')
    .option('--remove-volumes', 'Remove volumes for clean restart')
    .action(async (opts) => {
      if (masterWallet) {
        await closeWallet(masterWallet);
        masterWallet = null;
      }
      await composeDown({ removeVolumes: opts.removeVolumes ?? false });
      await composeUp({ pull: opts.pull ?? false });
      masterWallet = await initMasterWallet(defaultConfig);
      await registerDust(masterWallet);
      console.log('Network restarted and ready.');
    });

  program
    .command('status')
    .description('Show network status')
    .action(async () => {
      try {
        const services = await composePs();
        console.table(services.map((s) => ({
          Service: s.name,
          Status: s.status,
          Port: s.port,
          URL: s.url,
        })));
      } catch {
        console.log('Network is not running.');
      }
    });

  program
    .command('logs')
    .description('Show network service logs')
    .option('--service <name>', 'Specific service (node, indexer, proof-server)')
    .option('--lines <n>', 'Number of lines', '50')
    .action(async (opts) => {
      const logs = await composeLogs({
        service: opts.service,
        lines: parseInt(opts.lines, 10),
      });
      console.log(logs);
    });

  program
    .command('health')
    .description('Check health of all services')
    .action(async () => {
      const health = await checkAllHealth();
      console.table({
        Node: { Healthy: health.node.healthy, 'Response (ms)': health.node.responseTime },
        Indexer: { Healthy: health.indexer.healthy, 'Response (ms)': health.indexer.responseTime },
        'Proof Server': { Healthy: health.proofServer.healthy, 'Response (ms)': health.proofServer.responseTime },
      });
    });
}
```

**Step 3: Create wallet CLI commands**

```typescript
// src/cli/commands/wallet.ts
import type { Command } from 'commander';
import { getWalletBalances } from '../../core/wallet.js';
import { fundAccount, fundAccountsFromFile } from '../../core/funding.js';
import { defaultConfig } from '../../core/config.js';
import { getCliMasterWallet } from './network.js';

export function registerWalletCommands(program: Command): void {
  program
    .command('balances')
    .description('Show master wallet balances')
    .action(async () => {
      const wallet = getCliMasterWallet();
      if (!wallet) {
        console.error('Network not started. Run: midnight-devnet start');
        process.exit(1);
      }
      const b = await getWalletBalances(wallet);
      console.table({
        Unshielded: b.unshielded.toString(),
        Shielded: b.shielded.toString(),
        DUST: b.dust.toString(),
        Total: b.total.toString(),
      });
    });

  program
    .command('fund <address>')
    .description('Fund an address with NIGHT tokens')
    .option('--amount <n>', 'Amount in NIGHT (default: 50000)')
    .action(async (address, opts) => {
      const wallet = getCliMasterWallet();
      if (!wallet) {
        console.error('Network not started. Run: midnight-devnet start');
        process.exit(1);
      }
      const amount = opts.amount ? BigInt(opts.amount) * 10n ** 6n : undefined;
      const result = await fundAccount(wallet, address, amount);
      console.log(`Funded ${result.address} with ${result.amount} NIGHT`);
    });

  program
    .command('fund-file <path>')
    .description('Fund accounts from an accounts.json file')
    .action(async (filePath) => {
      const wallet = getCliMasterWallet();
      if (!wallet) {
        console.error('Network not started. Run: midnight-devnet start');
        process.exit(1);
      }
      const results = await fundAccountsFromFile(wallet, filePath, defaultConfig);
      console.table(results.map((r) => ({
        Name: r.name,
        Address: r.address,
        Amount: r.amount.toString(),
        DUST: r.hasDust ? 'Yes' : 'No',
      })));
    });
}
```

**Step 4: Create account CLI commands**

```typescript
// src/cli/commands/accounts.ts
import type { Command } from 'commander';
import { generateAccounts, generateAndFundAccounts, writeAccountsFile } from '../../core/accounts.js';
import { defaultConfig } from '../../core/config.js';
import { getCliMasterWallet } from './network.js';

export function registerAccountCommands(program: Command): void {
  program
    .command('generate-accounts')
    .description('Generate random test accounts')
    .option('--count <n>', 'Number of accounts', '1')
    .option('--format <type>', 'mnemonic or privateKey', 'mnemonic')
    .option('--output <path>', 'Write to file in accounts.json format')
    .option('--fund', 'Fund accounts from master wallet')
    .option('--register-dust', 'Register DUST for funded accounts')
    .action(async (opts) => {
      const format = opts.format as 'mnemonic' | 'privateKey';
      const count = parseInt(opts.count, 10);

      let accounts;
      if (opts.fund) {
        const wallet = getCliMasterWallet();
        if (!wallet) {
          console.error('Network not started. Run: midnight-devnet start');
          process.exit(1);
        }
        accounts = await generateAndFundAccounts(wallet, defaultConfig, {
          format,
          count,
          fund: true,
          registerDust: opts.registerDust ?? false,
        });
      } else {
        accounts = await generateAccounts({ format, count });
      }

      if (opts.output) {
        await writeAccountsFile(opts.output, accounts);
        console.log(`Accounts written to ${opts.output}`);
      }

      console.table(accounts.map((a) => ({
        Name: a.name,
        Address: a.address || '(generated on fund)',
        ...(a.mnemonic ? { Mnemonic: a.mnemonic.split(' ').slice(0, 3).join(' ') + '...' } : {}),
      })));
    });
}
```

**Step 5: Create interactive mode**

```typescript
// src/cli/interactive.ts
import { stdin as input, stdout as output } from 'node:process';
import { createInterface } from 'node:readline/promises';
import { composeUp, composeDown, composePs } from '../core/docker.js';
import { initMasterWallet, registerDust, closeWallet, getWalletBalances, type WalletContext } from '../core/wallet.js';
import { fundAccount, fundAccountsFromFile } from '../core/funding.js';
import { generateAccounts, writeAccountsFile } from '../core/accounts.js';
import { defaultConfig } from '../core/config.js';

export async function startInteractiveMode(): Promise<void> {
  const rli = createInterface({ input, output });
  let masterWallet: WalletContext | null = null;

  console.log('Midnight Local Devnet — Interactive Mode');
  console.log('Starting network...\n');

  try {
    await composeUp({ pull: false });
    masterWallet = await initMasterWallet(defaultConfig);
    await registerDust(masterWallet);
    console.log('Network ready.\n');
  } catch (err) {
    console.error('Failed to start network:', err);
    process.exit(1);
  }

  const showMenu = () => {
    console.log('\nChoose an option:');
    console.log('  [1] Fund accounts from config file (NIGHT + DUST)');
    console.log('  [2] Fund account by address (NIGHT only)');
    console.log('  [3] Generate test accounts');
    console.log('  [4] Display master wallet balances');
    console.log('  [5] Show network status');
    console.log('  [6] Exit');
  };

  let running = true;
  while (running) {
    showMenu();
    const choice = await rli.question('> ');

    switch (choice.trim()) {
      case '1': {
        const path = await rli.question('Path to accounts JSON file: ');
        const results = await fundAccountsFromFile(masterWallet!, path.trim(), defaultConfig);
        console.table(results.map((r) => ({ Name: r.name, Address: r.address, DUST: r.hasDust })));
        break;
      }
      case '2': {
        const addr = await rli.question('Bech32 address: ');
        await fundAccount(masterWallet!, addr.trim());
        console.log('Funded.');
        break;
      }
      case '3': {
        const countStr = await rli.question('How many accounts? [1]: ');
        const count = parseInt(countStr.trim() || '1', 10);
        const accounts = await generateAccounts({ format: 'mnemonic', count });
        const outPath = await rli.question('Save to file? (path or empty to skip): ');
        if (outPath.trim()) {
          await writeAccountsFile(outPath.trim(), accounts);
        }
        console.table(accounts.map((a) => ({ Name: a.name, Mnemonic: a.mnemonic })));
        break;
      }
      case '4': {
        const b = await getWalletBalances(masterWallet!);
        console.table({ Unshielded: b.unshielded.toString(), Shielded: b.shielded.toString(), DUST: b.dust.toString() });
        break;
      }
      case '5': {
        const services = await composePs();
        console.table(services);
        break;
      }
      case '6':
        running = false;
        break;
      default:
        console.log('Invalid option.');
    }
  }

  console.log('\nShutting down...');
  if (masterWallet) await closeWallet(masterWallet);
  await composeDown({ removeVolumes: false });
  rli.close();
  console.log('Goodbye.');
}
```

**Step 6: Verify build compiles**

```bash
npx tsc --noEmit
```

Expected: Success.

**Step 7: Commit**

```bash
git add src/cli.ts src/cli/
git commit -m "feat: CLI with one-shot commands and interactive mode"
```

---

### Task 10: Logging Setup

**Files:**
- Create: `src/core/logger.ts`
- Modify: `src/index.ts` — add logger initialization
- Modify: `src/cli.ts` — add logger initialization

**Step 1: Create logger module**

```typescript
// src/core/logger.ts
import pino from 'pino';

export function createLogger(level: string = 'info'): pino.Logger {
  return pino({
    level,
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'SYS:standard',
        ignore: 'pid,hostname',
      },
    },
  });
}
```

**Step 2: Wire loggers into modules**

Update `src/index.ts` and `src/cli.ts` to create a logger and pass it to `setLogger()` on the wallet, funding, and accounts modules.

**Step 3: Verify build compiles**

```bash
npx tsc --noEmit
```

**Step 4: Commit**

```bash
git add src/core/logger.ts src/index.ts src/cli.ts
git commit -m "feat: pino logging throughout core modules"
```

---

### Task 11: README and Final Polish

**Files:**
- Create: `README.md`
- Create: `accounts.example.json`

**Step 1: Create README.md**

Write a README covering:
- What the tool does (one paragraph)
- Prerequisites (Node >= 22, Docker, Midnight npm registry access)
- Installation (`npm install`)
- Quick start (CLI: `npx midnight-devnet start`, MCP: add to `.mcp.json`)
- CLI command reference (table of all commands)
- MCP tool reference (table of all tools)
- MCP resource reference
- accounts.json format
- Docker services table
- Troubleshooting section

**Step 2: Create accounts.example.json**

```json
{
  "accounts": [
    {
      "name": "Alice",
      "mnemonic": "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
    },
    {
      "name": "Bob",
      "mnemonic": "zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo zoo vote"
    }
  ]
}
```

**Step 3: Commit**

```bash
git add README.md accounts.example.json
git commit -m "docs: README with CLI and MCP reference"
```

---

### Task 12: Integration Testing

**Files:**
- Create: `src/__tests__/integration.test.ts`

This test requires Docker running and exercises the full lifecycle.

**Step 1: Write the integration test**

```typescript
// src/__tests__/integration.test.ts
import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import { composeUp, composeDown, composePs } from '../core/docker.js';
import { initMasterWallet, getWalletBalances, registerDust, closeWallet } from '../core/wallet.js';
import { generateAccounts, writeAccountsFile } from '../core/accounts.js';
import { checkAllHealth } from '../core/health.js';
import { defaultConfig } from '../core/config.js';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { WalletContext } from '../core/wallet.js';

// These tests require Docker and take several minutes
// Run with: npx vitest run src/__tests__/integration.test.ts --timeout 300000
describe.skip('integration', () => {
  let masterWallet: WalletContext;

  beforeAll(async () => {
    await composeUp({ pull: false });
    masterWallet = await initMasterWallet(defaultConfig);
    await registerDust(masterWallet);
  }, 300_000);

  afterAll(async () => {
    if (masterWallet) await closeWallet(masterWallet);
    await composeDown({ removeVolumes: true });
  }, 60_000);

  it('network services are all running', async () => {
    const services = await composePs();
    expect(services).toHaveLength(3);
    services.forEach((s) => expect(s.status).toBe('running'));
  });

  it('health check passes', async () => {
    const health = await checkAllHealth();
    expect(health.allHealthy).toBe(true);
  });

  it('master wallet has NIGHT balance', async () => {
    const balances = await getWalletBalances(masterWallet);
    expect(balances.unshielded).toBeGreaterThan(0n);
  });

  it('generates accounts and writes to file', async () => {
    const accounts = await generateAccounts({ format: 'mnemonic', count: 2 });
    expect(accounts).toHaveLength(2);

    const outPath = join(tmpdir(), 'test-accounts.json');
    await writeAccountsFile(outPath, accounts);

    const { readFile } = await import('node:fs/promises');
    const content = JSON.parse(await readFile(outPath, 'utf-8'));
    expect(content.accounts).toHaveLength(2);
  });
});
```

**Step 2: Run unit tests to verify nothing is broken**

```bash
npx vitest run --testPathPattern 'core/__tests__'
```

Expected: All unit tests pass.

**Step 3: Commit**

```bash
git add src/__tests__/integration.test.ts
git commit -m "test: integration test suite for full lifecycle"
```

---

## Summary

| Task | Description | Estimated Effort |
|---|---|---|
| 1 | Project scaffold, types, config, docker compose | 30 min |
| 2 | Core Docker module + unit tests | 45 min |
| 3 | Core wallet module + unit tests | 1 hour |
| 4 | Core funding module + unit tests | 45 min |
| 5 | Core account generation + unit tests | 30 min |
| 6 | Core health check + unit tests | 20 min |
| 7 | MCP server + network/health tools + resources | 1 hour |
| 8 | MCP wallet/funding/account tools | 45 min |
| 9 | CLI commands + interactive mode | 1 hour |
| 10 | Logging setup | 20 min |
| 11 | README + example files | 30 min |
| 12 | Integration test suite | 30 min |

**Total: ~7-8 hours of implementation time.**

> **Important notes for the implementer:**
>
> - The wallet SDK API signatures in this plan are based on the reference repo (`hbulgarini/midnight-local-network`). Verify method names and parameter types against the installed SDK version. The `WalletFacade`, `HDWallet`, state observable shape, and `registerForDust` methods may have slightly different signatures.
> - `@midnight-ntwrk/*` packages require access to the Midnight npm registry. Ensure `.npmrc` is configured.
> - Integration tests (Task 12) require Docker and pull ~2GB of images on first run.
> - The `docker compose ps --format json` output format varies between Docker Compose v2 versions. The parser in `docker.ts` handles both array and newline-delimited formats.
