> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.

## Step 4: Counter Contract

### What this verifies
The full Compact smart contract lifecycle works — write, compile, deploy to devnet, call circuits, and read on-chain state.

### Procedure

**4.1. Write the contract**

Create `src/counter.compact`:

```compact
pragma language_version >= 0.22;

import CompactStandardLibrary;

export ledger counter: Counter;

witness get_increment_amount(): Uint<16>;

export circuit increment(): [] {
  counter.increment(disclose(get_increment_amount()));
}

export circuit read(): Uint<64> {
  return counter.read();
}
```

This contract has:
- A `Counter` ledger field (on-chain state)
- A `get_increment_amount()` witness that provides the increment value from off-chain
- `disclose()` wraps the witness value because it flows to a ledger operation
- `Counter.increment()` takes `Uint<16>`, not `Uint<64>`

**4.2. Compile (fast, no ZK keys)**

```bash
mkdir -p src/managed/counter
compact compile -- --skip-zk src/counter.compact src/managed/counter
```

Note: flags go after `--` and before file paths. `--skip-zk` skips ZK proving key generation for faster iteration.

**4.3. Write the witness**

Create `src/witnesses.ts`:

```typescript
import { WitnessContext } from "@midnight-ntwrk/compact-runtime";
import { Ledger, Witnesses } from "./managed/counter/contract/index.js";

export const witnesses: Witnesses<undefined> = {
  get_increment_amount: (
    context: WitnessContext<Ledger, undefined>
  ): [undefined, bigint] => [undefined, 1n],
};
```

Every witness returns `[updatedPrivateState, returnValue]`. We use `undefined` for private state since this contract doesn't need any.

**4.4. Full compile (with ZK keys)**

```bash
compact compile -- src/counter.compact src/managed/counter
```

This generates ZK proving/verifying keys in `keys/`. Required for deployment.

**4.5. Set up the Node.js project**

Create `package.json`:

```json
{
  "name": "midnight-basic-start",
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "compile": "compact compile -- --skip-zk src/counter.compact src/managed/counter",
    "compile:full": "compact compile -- src/counter.compact src/managed/counter",
    "deploy": "node --import tsx src/deploy.ts"
  },
  "dependencies": {
    "@midnight-ntwrk/compact-js": "2.5.0",
    "@midnight-ntwrk/compact-runtime": "0.15.0",
    "@midnight-ntwrk/ledger-v8": "8.0.3",
    "@midnight-ntwrk/midnight-js-contracts": "4.0.4",
    "@midnight-ntwrk/midnight-js-http-client-proof-provider": "4.0.4",
    "@midnight-ntwrk/midnight-js-indexer-public-data-provider": "4.0.4",
    "@midnight-ntwrk/midnight-js-level-private-state-provider": "4.0.4",
    "@midnight-ntwrk/midnight-js-network-id": "4.0.4",
    "@midnight-ntwrk/midnight-js-node-zk-config-provider": "4.0.4",
    "@midnight-ntwrk/midnight-js-types": "4.0.4",
    "@midnight-ntwrk/wallet-sdk-dust-wallet": "3.0.0",
    "@midnight-ntwrk/wallet-sdk-facade": "3.0.0",
    "@midnight-ntwrk/wallet-sdk-hd": "3.0.1",
    "@midnight-ntwrk/wallet-sdk-shielded": "2.1.0",
    "@midnight-ntwrk/wallet-sdk-unshielded-wallet": "2.1.0",
    "rxjs": "^7.8.0",
    "ws": "^8.18.0"
  },
  "devDependencies": {
    "tsx": "^4.0.0",
    "typescript": "^5.5.0",
    "@types/ws": "^8.5.0"
  }
}
```

Create `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src/**/*.ts"],
  "exclude": ["node_modules"]
}
```

Install dependencies:

```bash
npm install
```

**4.6. Write the deploy script**

Create `src/deploy.ts`. Replace `DEPLOYER_SEED` with the seed saved from Step 3:

```typescript
import { WebSocket } from "ws";
// @ts-expect-error WebSocket polyfill for apollo client
globalThis.WebSocket = WebSocket;

import { setNetworkId, getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { deployContract } from "@midnight-ntwrk/midnight-js-contracts";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
  createKeystore,
  InMemoryTransactionHistoryStorage,
  PublicKey,
  UnshieldedWallet,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import * as ledger from "@midnight-ntwrk/ledger-v8";
import * as Rx from "rxjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { Contract } from "./managed/counter/contract/index.js";
import { witnesses } from "./witnesses.js";

// --- Config ---
const NETWORK_ID = "undeployed"; // MUST be lowercase — "Undeployed" causes error 166 (InvalidNetworkId)
const INDEXER_HTTP = "http://127.0.0.1:8088/api/v3/graphql";
const INDEXER_WS = "ws://127.0.0.1:8088/api/v3/graphql/ws";
const NODE_URL = "ws://127.0.0.1:9944"; // MUST be ws://, not http://
const PROOF_SERVER = "http://127.0.0.1:6300";

// Replace with the seed from your deployer wallet (Step 3)
const DEPLOYER_SEED = "YOUR_DEPLOYER_SEED_HERE";

function deriveKeys(seed: string) {
  const hdWallet = HDWallet.fromSeed(Buffer.from(seed, "hex"));
  if (hdWallet.type !== "seedOk") throw new Error("Invalid seed");
  const result = hdWallet.hdWallet
    .selectAccount(0)
    .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
    .deriveKeysAt(0);
  if (result.type !== "keysDerived") throw new Error("Key derivation failed");
  hdWallet.hdWallet.clear();
  return {
    zswap: result.keys[Roles.Zswap],
    nightExternal: result.keys[Roles.NightExternal],
    dust: result.keys[Roles.Dust],
  };
}

async function main() {
  console.log("Setting up network...");
  setNetworkId(NETWORK_ID);
  const networkId = getNetworkId();

  console.log("Deriving wallet keys...");
  const keys = deriveKeys(DEPLOYER_SEED);
  const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys.zswap);
  const dustSecretKey = ledger.DustSecretKey.fromSeed(keys.dust);
  const keystore = createKeystore(keys.nightExternal, networkId);

  console.log("Initializing wallet facade...");
  const facade = await WalletFacade.init({
    configuration: {
      networkId,
      indexerClientConnection: {
        indexerHttpUrl: INDEXER_HTTP,
        indexerWsUrl: INDEXER_WS,
      },
      provingServerUrl: new URL(PROOF_SERVER), // MUST be a URL object, not a string
      relayURL: new URL(NODE_URL),
      costParameters: {
        additionalFeeOverhead: 300_000_000_000_000n,
        feeBlocksMargin: 5,
      },
      txHistoryStorage: new InMemoryTransactionHistoryStorage(),
    },
    shielded: (cfg) => ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
    unshielded: (cfg) =>
      UnshieldedWallet({
        ...cfg,
        txHistoryStorage: new InMemoryTransactionHistoryStorage(),
      }).startWithPublicKey(PublicKey.fromKeyStore(keystore)),
    dust: (cfg) =>
      DustWallet(cfg).startWithSecretKey(
        dustSecretKey,
        ledger.LedgerParameters.initialParameters().dust,
      ),
  });

  try {
    // MUST call facade.start() after init — without this, isSynced stays false forever
    console.log("Starting wallet facade (connecting to node and indexer)...");
    await facade.start(shieldedSecretKeys, dustSecretKey);

    console.log("Waiting for wallet to sync...");
    const state = await Rx.firstValueFrom(
      facade.state().pipe(
        Rx.filter((s) => s.isSynced),
        Rx.timeout(120_000),
      ),
    );
    console.log("Wallet synced!");

    const walletAndMidnightProvider = {
      getCoinPublicKey: () => state.shielded.coinPublicKey.toHexString(),
      getEncryptionPublicKey: () => state.shielded.encryptionPublicKey.toHexString(),
      async balanceTx(tx: any, ttl?: Date) {
        const recipe = await facade.balanceUnboundTransaction(
          tx,
          { shieldedSecretKeys, dustSecretKey },
          { ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
        );
        return await facade.finalizeRecipe(recipe);
      },
      submitTx: (tx: any) => facade.submitTransaction(tx),
    };

    const __dirname = path.dirname(fileURLToPath(import.meta.url));
    const zkConfigPath = path.resolve(__dirname, "managed/counter");
    const zkConfigProvider = new NodeZkConfigProvider(zkConfigPath);

    const providers = {
      walletProvider: walletAndMidnightProvider,
      midnightProvider: walletAndMidnightProvider,
      publicDataProvider: indexerPublicDataProvider(INDEXER_HTTP, INDEXER_WS),
      privateStateProvider: levelPrivateStateProvider({
        privateStateStoreName: "counter-private-state",
        // Password MUST meet complexity requirements: uppercase + lowercase + digits + special chars (at least 3 of 4)
        privateStoragePasswordProvider: () => "Counter-Dev-Pa55word!",
        accountId: "deployer",
      }),
      zkConfigProvider,
      proofProvider: httpClientProofProvider(PROOF_SERVER, zkConfigProvider),
    };

    console.log("Loading compiled contract...");
    // CompiledContract.make() takes the Contract CLASS, not an instance
    // Use .withWitnesses() to attach witnesses, not .withVacantWitnesses
    const compiledContract = CompiledContract.make("counter", Contract).pipe(
      CompiledContract.withWitnesses(witnesses),
      CompiledContract.withCompiledFileAssets(zkConfigPath),
    );

    console.log("Deploying contract (this may take a minute)...");
    const deployed = await deployContract(providers, {
      compiledContract,
      privateStateId: "counter-private-state",
      initialPrivateState: undefined,
    });

    console.log("\nContract deployed successfully!");
    console.log(`  Address:     ${deployed.deployTxData.public.contractAddress}`);
    console.log(`  TX ID:       ${deployed.deployTxData.public.txId}`);
    console.log(`  Block:       ${deployed.deployTxData.public.blockHeight}`);
  } finally {
    await facade.stop();
  }
}

main().catch((err) => {
  console.error("Deployment failed:", err);
  process.exit(1);
});
```

**4.7. Deploy**

```bash
node --import tsx src/deploy.ts
```

Use `node --import tsx` not `npx tsx` — some `@midnight-ntwrk/wallet-sdk-*` packages have ESM export issues with tsx's CJS loader.

Expected: wallet syncs, contract deploys, prints address + tx ID + block number. **Save the contract address** for the next sub-step.

**4.8. Write the interact script**

Create `src/interact.ts`. Replace `DEPLOYER_SEED` with the seed from Step 3:

```typescript
import { WebSocket } from "ws";
// @ts-expect-error WebSocket polyfill for apollo client
globalThis.WebSocket = WebSocket;

import { setNetworkId, getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
import { findDeployedContract } from "@midnight-ntwrk/midnight-js-contracts";
import { httpClientProofProvider } from "@midnight-ntwrk/midnight-js-http-client-proof-provider";
import { indexerPublicDataProvider } from "@midnight-ntwrk/midnight-js-indexer-public-data-provider";
import { levelPrivateStateProvider } from "@midnight-ntwrk/midnight-js-level-private-state-provider";
import { NodeZkConfigProvider } from "@midnight-ntwrk/midnight-js-node-zk-config-provider";
import { CompiledContract } from "@midnight-ntwrk/compact-js";
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
  createKeystore,
  InMemoryTransactionHistoryStorage,
  PublicKey,
  UnshieldedWallet,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import * as ledger from "@midnight-ntwrk/ledger-v8";
import * as Rx from "rxjs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { Contract, ledger as counterLedger } from "./managed/counter/contract/index.js";
import { witnesses } from "./witnesses.js";

const NETWORK_ID = "undeployed";
const INDEXER_HTTP = "http://127.0.0.1:8088/api/v3/graphql";
const INDEXER_WS = "ws://127.0.0.1:8088/api/v3/graphql/ws";
const NODE_URL = "ws://127.0.0.1:9944";
const PROOF_SERVER = "http://127.0.0.1:6300";

const DEPLOYER_SEED = "YOUR_DEPLOYER_SEED_HERE";

const CONTRACT_ADDRESS = process.argv[2];
if (!CONTRACT_ADDRESS) {
  console.error("Usage: node --import tsx src/interact.ts <contract-address>");
  process.exit(1);
}

function deriveKeys(seed: string) {
  const hdWallet = HDWallet.fromSeed(Buffer.from(seed, "hex"));
  if (hdWallet.type !== "seedOk") throw new Error("Invalid seed");
  const result = hdWallet.hdWallet
    .selectAccount(0)
    .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
    .deriveKeysAt(0);
  if (result.type !== "keysDerived") throw new Error("Key derivation failed");
  hdWallet.hdWallet.clear();
  return {
    zswap: result.keys[Roles.Zswap],
    nightExternal: result.keys[Roles.NightExternal],
    dust: result.keys[Roles.Dust],
  };
}

async function main() {
  console.log("Setting up network...");
  setNetworkId(NETWORK_ID);
  const networkId = getNetworkId();

  const keys = deriveKeys(DEPLOYER_SEED);
  const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys.zswap);
  const dustSecretKey = ledger.DustSecretKey.fromSeed(keys.dust);
  const keystore = createKeystore(keys.nightExternal, networkId);

  const facade = await WalletFacade.init({
    configuration: {
      networkId,
      indexerClientConnection: { indexerHttpUrl: INDEXER_HTTP, indexerWsUrl: INDEXER_WS },
      provingServerUrl: new URL(PROOF_SERVER),
      relayURL: new URL(NODE_URL),
      costParameters: { additionalFeeOverhead: 300_000_000_000_000n, feeBlocksMargin: 5 },
      txHistoryStorage: new InMemoryTransactionHistoryStorage(),
    },
    shielded: (cfg) => ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
    unshielded: (cfg) =>
      UnshieldedWallet({ ...cfg, txHistoryStorage: new InMemoryTransactionHistoryStorage() })
        .startWithPublicKey(PublicKey.fromKeyStore(keystore)),
    dust: (cfg) =>
      DustWallet(cfg).startWithSecretKey(dustSecretKey, ledger.LedgerParameters.initialParameters().dust),
  });

  try {
    await facade.start(shieldedSecretKeys, dustSecretKey);
    console.log("Waiting for wallet to sync...");
    await Rx.firstValueFrom(
      facade.state().pipe(Rx.filter((s) => s.isSynced), Rx.timeout(120_000)),
    );
    console.log("Wallet synced!");

    const state = await Rx.firstValueFrom(
      facade.state().pipe(Rx.filter((s) => s.isSynced)),
    );
    const walletAndMidnightProvider = {
      getCoinPublicKey: () => state.shielded.coinPublicKey.toHexString(),
      getEncryptionPublicKey: () => state.shielded.encryptionPublicKey.toHexString(),
      async balanceTx(tx: any, ttl?: Date) {
        const recipe = await facade.balanceUnboundTransaction(
          tx, { shieldedSecretKeys, dustSecretKey },
          { ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
        );
        return await facade.finalizeRecipe(recipe);
      },
      submitTx: (tx: any) => facade.submitTransaction(tx),
    };

    const __dirname = path.dirname(fileURLToPath(import.meta.url));
    const zkConfigPath = path.resolve(__dirname, "managed/counter");
    const zkConfigProvider = new NodeZkConfigProvider(zkConfigPath);

    const providers = {
      walletProvider: walletAndMidnightProvider,
      midnightProvider: walletAndMidnightProvider,
      publicDataProvider: indexerPublicDataProvider(INDEXER_HTTP, INDEXER_WS),
      privateStateProvider: levelPrivateStateProvider({
        privateStateStoreName: "counter-private-state",
        privateStoragePasswordProvider: () => "Counter-Dev-Pa55word!",
        accountId: "deployer",
      }),
      zkConfigProvider,
      proofProvider: httpClientProofProvider(PROOF_SERVER, zkConfigProvider),
    };

    const compiledContract = CompiledContract.make("counter", Contract).pipe(
      CompiledContract.withWitnesses(witnesses),
      CompiledContract.withCompiledFileAssets(zkConfigPath),
    );

    // For contracts with no private state, omit privateStateId and initialPrivateState
    console.log(`Finding deployed contract at ${CONTRACT_ADDRESS}...`);
    const contract = await findDeployedContract(providers, {
      contractAddress: CONTRACT_ADDRESS,
      compiledContract,
    });
    console.log("Contract found!");

    // Read on-chain state via publicDataProvider + generated ledger() function
    async function readCounter(): Promise<bigint> {
      const state = await providers.publicDataProvider.queryContractState(CONTRACT_ADDRESS);
      if (!state) throw new Error("Contract state not found");
      return counterLedger(state.data).counter;
    }

    console.log("\n--- Reading initial counter value ---");
    const initialValue = await readCounter();
    console.log(`  Counter value: ${initialValue}`);

    console.log("\n--- Calling increment() ---");
    const incResult = await contract.callTx.increment();
    console.log(`  Increment confirmed at block ${incResult.public.blockHeight}`);

    console.log("\n--- Reading counter after increment ---");
    const newValue = await readCounter();
    console.log(`  Counter value: ${newValue}`);

    console.log("\nDone!");
  } finally {
    await facade.stop();
  }
}

main().catch((err) => {
  console.error("Interaction failed:", err);
  process.exit(1);
});
```

Note: `callTx.read()` does NOT return the circuit's return value — it returns `FinalizedCallTxData` (txId, blockHeight). To read ledger state, query the indexer via `publicDataProvider.queryContractState()` and parse with the generated `ledger()` function.

**4.9. Interact with the deployed contract**

```bash
node --import tsx src/interact.ts <contract-address>
```

Replace `<contract-address>` with the address printed during deployment.

### Expected output

Contract deploys with an address, tx ID, and block number. Counter starts at 0, increment succeeds, counter reads as 1.

> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.
