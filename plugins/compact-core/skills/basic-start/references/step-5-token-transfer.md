> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.

## Step 5: Token Transfer

### What this verifies

Programmatic NIGHT token transfers between wallets using the WalletFacade SDK.

### Procedure

1. Create a second wallet using the `midnight_wallet_generate` MCP tool:
   - `name`: `"alice"`
   - `network`: `"undeployed"`

2. Check deployer balance using the `midnight_balance` MCP tool with `wallet: "deployer"`.

3. Add the address format package to dependencies:

```bash
npm install @midnight-ntwrk/wallet-sdk-address-format@3.1.0
```

4. Write `src/transfer.ts` with the following complete content:

```typescript
import { WebSocket } from "ws";
// @ts-expect-error WebSocket polyfill for apollo client
globalThis.WebSocket = WebSocket;

import { setNetworkId, getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
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
import { MidnightBech32m, UnshieldedAddress } from "@midnight-ntwrk/wallet-sdk-address-format";
import * as Rx from "rxjs";

// --- Config ---
const NETWORK_ID = "undeployed";
const INDEXER_HTTP = "http://127.0.0.1:8088/api/v3/graphql";
const INDEXER_WS = "ws://127.0.0.1:8088/api/v3/graphql/ws";
const NODE_URL = "ws://127.0.0.1:9944";
const PROOF_SERVER = "http://127.0.0.1:6300";

// --- Parse args ---
const SENDER_SEED = process.argv[2];
const RECIPIENT_ADDRESS = process.argv[3];
const AMOUNT = process.argv[4];

if (!SENDER_SEED || !RECIPIENT_ADDRESS || !AMOUNT) {
  console.error("Usage: node --import tsx src/transfer.ts <sender-seed> <recipient-address> <amount-night>");
  process.exit(1);
}

const amountMicroNight = BigInt(Math.round(parseFloat(AMOUNT) * 1_000_000));

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
  console.log(`Transferring ${AMOUNT} NIGHT to ${RECIPIENT_ADDRESS.slice(0, 30)}...`);

  setNetworkId(NETWORK_ID);
  const networkId = getNetworkId();

  const keys = deriveKeys(SENDER_SEED);
  const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys.zswap);
  const dustSecretKey = ledger.DustSecretKey.fromSeed(keys.dust);
  const keystore = createKeystore(keys.nightExternal, networkId);

  console.log("Initializing wallet...");
  const facade = await WalletFacade.init({
    configuration: {
      networkId,
      indexerClientConnection: {
        indexerHttpUrl: INDEXER_HTTP,
        indexerWsUrl: INDEXER_WS,
      },
      provingServerUrl: new URL(PROOF_SERVER),
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
    console.log("Starting and syncing wallet...");
    await facade.start(shieldedSecretKeys, dustSecretKey);
    const state = await Rx.firstValueFrom(
      facade.state().pipe(
        Rx.filter((s) => s.isSynced),
        Rx.timeout(120_000),
      ),
    );

    // Check balance
    const token = ledger.unshieldedToken().raw;
    const balance = state.unshielded?.balances?.[token] ?? 0n;
    const balanceNight = Number(balance) / 1_000_000;
    console.log(`  Sender balance: ${balanceNight} NIGHT`);

    if (balance < amountMicroNight) {
      throw new Error(`Insufficient balance: ${balanceNight} NIGHT, need ${AMOUNT} NIGHT`);
    }

    // Decode bech32m address to raw unshielded address
    const decodedAddress = MidnightBech32m.parse(RECIPIENT_ADDRESS).decode(UnshieldedAddress, NETWORK_ID);

    // Build transfer transaction
    console.log("Building transfer transaction...");
    const ttl = new Date(Date.now() + 10 * 60 * 1000);
    const recipe = await facade.transferTransaction(
      [
        {
          type: "unshielded",
          outputs: [
            {
              amount: amountMicroNight,
              receiverAddress: decodedAddress,
              type: token,
            },
          ],
        },
      ],
      {
        shieldedSecretKeys,
        dustSecretKey,
      },
      { ttl, payFees: true },
    );

    // Sign the transaction
    console.log("Signing transaction...");
    const signed = await facade.signRecipe(recipe, (msg: Uint8Array) =>
      keystore.signData(msg),
    );

    // Finalize and submit
    console.log("Finalizing and submitting...");
    const finalized = await facade.finalizeRecipe(signed);
    const txHash = await facade.submitTransaction(finalized);

    console.log(`\nTransfer successful!`);
    console.log(`  TX Hash: ${txHash}`);
    console.log(`  Amount:  ${AMOUNT} NIGHT`);
    console.log(`  To:      ${RECIPIENT_ADDRESS}`);
  } finally {
    await facade.stop();
  }
}

main().catch((err) => {
  console.error("Transfer failed:", err);
  process.exit(1);
});
```

Key points to note:

- Bech32m addresses must be decoded before passing to `transferTransaction`: `MidnightBech32m.parse(address).decode(UnshieldedAddress, "undeployed")`
- Transfer amounts are in micro-NIGHT (1 NIGHT = 1,000,000 micro-NIGHT) as bigint
- The flow is: `transferTransaction` -> `signRecipe` -> `finalizeRecipe` -> `submitTransaction`

5. Run the transfer (replace `<deployer-seed>` with the seed from step 3, and `<alice-address>` with alice's undeployed address):

```bash
node --import tsx src/transfer.ts <deployer-seed> <alice-address> 25
```

Use `node --import tsx` not `npx tsx` — some `@midnight-ntwrk/wallet-sdk-*` packages have ESM export issues with tsx's CJS loader.

6. Verify both balances using `midnight_balance` MCP tool for both `deployer` and `alice`. Deployer should be down by 25, alice should have 25 NIGHT.

### Expected output

Transfer tx hash printed. Deployer balance decreased by 25 NIGHT. Alice balance is 25 NIGHT.

> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.
