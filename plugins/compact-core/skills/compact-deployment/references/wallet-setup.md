# Wallet Setup

Reference for creating and configuring Midnight wallets for contract deployment. The wallet handles key management, transaction balancing, signing, and fee payment. For provider assembly, see `references/network-and-providers.md`. For using the wallet in deployment, see `references/deployment-lifecycle.md`.

## Wallet Architecture

Midnight uses a composite wallet made of three sub-wallets, combined via `WalletFacade`:

| Sub-Wallet | Package | Purpose |
|------------|---------|---------|
| `ShieldedWallet` | `@midnight-ntwrk/wallet-sdk-shielded` | Manages shielded (private) coin UTXOs, ZSwap operations |
| `UnshieldedWallet` | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | Manages unshielded (public) NIGHT token balances |
| `DustWallet` | `@midnight-ntwrk/wallet-sdk-dust-wallet` | Manages DUST generated from staked NIGHT |

`WalletFacade` from `@midnight-ntwrk/wallet-sdk-facade` composes these into a unified wallet that handles transaction balancing across all three token types.

## Seed Management

### Generating a New Seed

```typescript
import { generateRandomSeed } from "@midnight-ntwrk/wallet-sdk-hd";

const seed: string = generateRandomSeed(); // Returns hex-encoded seed string
```

**Store the seed securely.** It derives all wallet keys. Loss of the seed means loss of funds.

### Restoring from Existing Seed

```typescript
const seed = "your-saved-hex-seed-string";
```

## HD Key Derivation

Midnight uses hierarchical deterministic (HD) key derivation to produce separate keys for each wallet role:

```typescript
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";

const hdWallet = HDWallet.fromSeed(Buffer.from(seed, "hex"));

const derivedKeys = hdWallet.hdWallet
  .selectAccount(0)
  .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
  .deriveKeysAt(0);

const keys = derivedKeys.keys;
// keys[Roles.Zswap]          -> Uint8Array (shielded wallet key material)
// keys[Roles.NightExternal]  -> Uint8Array (unshielded wallet key material)
// keys[Roles.Dust]           -> Uint8Array (dust wallet key material)
```

The three roles correspond to the three sub-wallets:
- **`Roles.Zswap`** — Derives shielded coin keys (coin public key, encryption key)
- **`Roles.NightExternal`** — Derives the unshielded NIGHT wallet keystore
- **`Roles.Dust`** — Derives the DUST key

## Secret Key Construction

Each sub-wallet requires keys derived from the HD wallet:

```typescript
import * as ledger from "@midnight-ntwrk/ledger";
import { createKeystore } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

// Shielded wallet keys (ZSwap coin operations)
const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys[Roles.Zswap]);

// Dust wallet key (fee token)
const dustSecretKey = ledger.DustSecretKey.fromSeed(keys[Roles.Dust]);

// Unshielded wallet keystore (NIGHT token)
const unshieldedKeystore = createKeystore(keys[Roles.NightExternal], getNetworkId());
```

## Sub-Wallet Configuration

### ShieldedWallet

Manages private coin UTXOs and ZSwap operations:

```typescript
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";

const shieldedWallet = ShieldedWallet({
  networkId: getNetworkId(),
  indexerClientConnection: {
    indexerHttpUrl: config.indexer,
    indexerWsUrl: config.indexerWS,
  },
  provingServerUrl: new URL(config.proofServer),
  relayURL: new URL(config.node.replace(/^http/, "ws")),
}).startWithSecretKeys(shieldedSecretKeys);
```

### UnshieldedWallet

Manages public NIGHT token balances:

```typescript
import {
  UnshieldedWallet,
  PublicKey,
  InMemoryTransactionHistoryStorage,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";

const unshieldedWallet = UnshieldedWallet({
  networkId: getNetworkId(),
  indexerClientConnection: {
    indexerHttpUrl: config.indexer,
    indexerWsUrl: config.indexerWS,
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(),
}).startWithPublicKey(PublicKey.fromKeyStore(unshieldedKeystore));
```

### DustWallet

Manages DUST fee tokens generated from staked NIGHT:

```typescript
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";

const dustWallet = DustWallet({
  networkId: getNetworkId(),
  costParameters: {
    additionalFeeOverhead: 300_000_000_000_000n,
    feeBlocksMargin: 5,
  },
  indexerClientConnection: {
    indexerHttpUrl: config.indexer,
    indexerWsUrl: config.indexerWS,
  },
  provingServerUrl: new URL(config.proofServer),
  relayURL: new URL(config.node.replace(/^http/, "ws")),
}).startWithSecretKey(dustSecretKey, ledger.LedgerParameters.initialParameters().dust);
```

The `costParameters` control fee estimation:
- `additionalFeeOverhead` — Extra fee buffer (in smallest units) to prevent underpayment
- `feeBlocksMargin` — Number of blocks ahead to estimate fees for

## WalletFacade Composition

Combine the three sub-wallets into a unified wallet:

```typescript
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";

const wallet = new WalletFacade(shieldedWallet, unshieldedWallet, dustWallet);
await wallet.start(shieldedSecretKeys, dustSecretKey);
```

After `start()`, the wallet synchronizes with the blockchain. Wait for sync before deploying:

```typescript
// Wait for wallet to sync with blockchain state
await wallet.waitForSync();
```

## Wallet-to-Provider Bridge

The `walletProvider` and `midnightProvider` are built from the wallet facade. Both interfaces are typically implemented by the same object:

```typescript
const walletAndMidnightProvider = {
  // WalletProvider interface
  getCoinPublicKey: () =>
    shieldedSecretKeys.coinPublicKey.toHexString(),

  getEncryptionPublicKey: () =>
    shieldedSecretKeys.encryptionPublicKey.toHexString(),

  balanceTx: async (
    tx: UnprovenTransaction,
    newCoins?: ShieldedCoinInfo[],
    ttl?: Date,
  ): Promise<BalancedProvingRecipe> => {
    const recipe = await wallet.balanceUnboundTransaction(
      tx,
      { shieldedSecretKeys, dustSecretKey },
      { ttl: ttl ?? new Date(Date.now() + 30 * 60 * 1000) },
    );

    // Workaround: sign transaction intents manually
    // (see references/troubleshooting.md for details)
    signTransactionIntents(recipe.baseTransaction, signFn, "proof");
    if (recipe.balancingTransaction) {
      signTransactionIntents(recipe.balancingTransaction, signFn, "pre-proof");
    }

    return wallet.finalizeRecipe(recipe);
  },

  // MidnightProvider interface
  submitTx: (tx: FinalizedTransaction): Promise<TransactionId> =>
    wallet.submitTransaction(tx),
};
```

The `signFn` comes from the unshielded keystore:

```typescript
const signFn = (payload: Uint8Array) =>
  unshieldedKeystore.signData(payload);
```

## Funding

### Test Network Funding

On Preview and Preprod, get tNight tokens from the faucet:

1. Get your wallet address from the unshielded wallet
2. Visit the faucet URL (see network endpoints in `references/network-and-providers.md`)
3. Request tNight tokens
4. Wait for the transaction to confirm

### DUST Mechanics

DUST is a non-transferable fee resource. It is generated by staking NIGHT tokens:

1. **Receive NIGHT** — From faucet or another wallet
2. **NIGHT is automatically staked** — The wallet SDK handles registration
3. **DUST accrues over time** — Generated from staked NIGHT each block
4. **DUST pays transaction fees** — All contract deployments and circuit calls require DUST

Check DUST balance:

```typescript
const state = await wallet.state();
const dustBalance = state.dust.walletBalance(new Date());
```

If DUST balance is zero after receiving NIGHT, wait a few blocks for dust generation to begin.

### Local Network

On the local (`undeployed`) network, the dev node preset provides pre-funded accounts. Seed management and faucet funding are typically not needed for local development.
