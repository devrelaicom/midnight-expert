# Wallet SDK Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a comprehensive `midnight-wallet:wallet-sdk` skill that documents the `@midnight-ntwrk/wallet-sdk-*` packages for agents building wallets programmatically.

**Architecture:** One skill with a SKILL.md routing table, 6 reference files organized by developer task, and 4 TypeScript example files. Cross-references added to 4 existing skills.

**Tech Stack:** Markdown skill files, TypeScript examples (non-runnable reference code)

**Spec:** `docs/superpowers/specs/2026-04-09-wallet-sdk-skill-design.md`

**Source reference:** Wallet SDK source at `/tmp/midnight-wallet/` (cloned from https://github.com/midnightntwrk/midnight-wallet)

**Verified package names (from source package.json files):**

| Directory | npm name |
|-----------|----------|
| facade | `@midnight-ntwrk/wallet-sdk-facade` |
| runtime | `@midnight-ntwrk/wallet-sdk-runtime` |
| abstractions | `@midnight-ntwrk/wallet-sdk-abstractions` |
| hd | `@midnight-ntwrk/wallet-sdk-hd` |
| capabilities | `@midnight-ntwrk/wallet-sdk-capabilities` |
| shielded-wallet | `@midnight-ntwrk/wallet-sdk-shielded` |
| unshielded-wallet | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` |
| dust-wallet | `@midnight-ntwrk/wallet-sdk-dust-wallet` |
| address-format | `@midnight-ntwrk/wallet-sdk-address-format` |
| indexer-client | `@midnight-ntwrk/wallet-sdk-indexer-client` |
| node-client | `@midnight-ntwrk/wallet-sdk-node-client` |
| prover-client | `@midnight-ntwrk/wallet-sdk-prover-client` |
| utilities | `@midnight-ntwrk/wallet-sdk-utilities` |

**Verified corrections from design phase (must be applied during implementation):**
1. Shielded package is `wallet-sdk-shielded` (NOT `wallet-sdk-shielded-wallet`)
2. `createKeystore` is exported from `@midnight-ntwrk/wallet-sdk-unshielded-wallet` (NOT `address-format`)
3. `TransactionHistoryStorage` uses `upsert()` method (NOT `put()`)
4. `DustWallet.startWithSecretKey` requires `DustParameters` as second param — obtained via `ledger.LedgerParameters.initialParameters().dust`
5. `PolkadotNodeClient` uses Effect-based `make()` static method (NOT `init()`); `sendMidnightTransaction` returns `Stream.Stream` (NOT `Observable`)
6. `HttpProverClient` uses Effect API (returns `Effect.Effect`, not `Promise`)
7. `signRecipe` callback signature is `(data: Uint8Array) => ledger.Signature` (synchronous, not async)
8. `PublicKey` and `createKeystore` are both in `@midnight-ntwrk/wallet-sdk-unshielded-wallet`
9. `ZswapSecretKeys` and `DustSecretKey` are from `@midnight-ntwrk/ledger` (the ledger package), not wallet SDK packages
10. `HDWallet.fromSeed` error variant is `{ type: 'seedError', error: unknown }` (has `error` field)
11. `deriveKeysAt` error variant is `{ type: 'keyOutOfBounds', roles: readonly Role[] }` (has `roles` field)

**Verification requirement:** Every claim about package names, type shapes, method signatures, and API behavior MUST be verified against the source at `/tmp/midnight-wallet/` before writing. Use `/midnight-verify:verify` for any claim you are uncertain about. If the source clone is stale, re-clone with `git clone --depth=1 https://github.com/midnightntwrk/midnight-wallet /tmp/midnight-wallet`.

**Plugin root:** `plugins/midnight-wallet/`

---

### Task 1: Create skill directory structure

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/SKILL.md`
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/` (directory)
- Create: `plugins/midnight-wallet/skills/wallet-sdk/examples/` (directory)

- [ ] **Step 1: Create the directory tree**

```bash
mkdir -p plugins/midnight-wallet/skills/wallet-sdk/references
mkdir -p plugins/midnight-wallet/skills/wallet-sdk/examples
```

- [ ] **Step 2: Verify directory exists**

```bash
ls -la plugins/midnight-wallet/skills/wallet-sdk/
```

Expected: `references/` and `examples/` directories visible.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/
git commit -m "feat(midnight-wallet): scaffold wallet-sdk skill directory structure"
```

Note: Git won't track empty directories. This commit may be empty — that's fine, the directories will be committed with their first files.

---

### Task 2: Write SKILL.md (router with quick-start)

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/SKILL.md`

- [ ] **Step 1: Verify the key package names against source before writing**

Before writing the SKILL.md, verify that the 5 packages referenced in the quick-start section exist with the correct names:

```bash
grep '"name"' /tmp/midnight-wallet/packages/hd/package.json
grep '"name"' /tmp/midnight-wallet/packages/facade/package.json
grep '"name"' /tmp/midnight-wallet/packages/shielded-wallet/package.json
grep '"name"' /tmp/midnight-wallet/packages/unshielded-wallet/package.json
grep '"name"' /tmp/midnight-wallet/packages/dust-wallet/package.json
```

Expected output must contain:
- `@midnight-ntwrk/wallet-sdk-hd`
- `@midnight-ntwrk/wallet-sdk-facade`
- `@midnight-ntwrk/wallet-sdk-shielded`
- `@midnight-ntwrk/wallet-sdk-unshielded-wallet`
- `@midnight-ntwrk/wallet-sdk-dust-wallet`

- [ ] **Step 2: Write SKILL.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/SKILL.md`:

```markdown
---
name: midnight-wallet:wallet-sdk
description: >-
  This skill should be used when the user asks about the Midnight Wallet SDK
  packages (@midnight-ntwrk/wallet-sdk-*), how to construct a wallet with
  WalletFacade or WalletBuilder, HD key derivation from seeds or mnemonics,
  the three-wallet architecture (shielded, unshielded, dust), observing wallet
  state and sync progress, transaction balancing and signing, proving and
  submission services, connecting to infrastructure (indexer client, node client,
  prover client), or Bech32m address formatting. Also covers ProtocolVersion,
  SyncProgress, FacadeState, and the wallet runtime
---

# Wallet SDK Reference

Reference for the `@midnight-ntwrk/wallet-sdk-*` packages.

## Quick Start: Wallet Construction

The most common task is constructing a `WalletFacade` from a seed. The flow is:

` ` `
Seed (64 hex chars)
  -> HDWallet.fromSeed() -> selectAccount(0) -> selectRoles() -> deriveKeysAt(0)
    -> ShieldedWallet (Zswap role)
    -> UnshieldedWallet (NightExternal role)
    -> DustWallet (Dust role)
      -> WalletFacade.init({ shielded, unshielded, dust, configuration })
` ` `

Key packages involved:

| Package | What it provides |
|---------|-----------------|
| `@midnight-ntwrk/wallet-sdk-hd` | `HDWallet`, `Roles`, `generateRandomSeed` |
| `@midnight-ntwrk/wallet-sdk-facade` | `WalletFacade` — unified API |
| `@midnight-ntwrk/wallet-sdk-shielded` | `ShieldedWallet` factory |
| `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | `UnshieldedWallet` factory, `createKeystore`, `PublicKey` |
| `@midnight-ntwrk/wallet-sdk-dust-wallet` | `DustWallet` factory |

For the full construction code, see `examples/basic-wallet-setup.ts`.
For configuration details, see `references/wallet-construction.md`.

## Deep Dive References

| Task | Reference |
|------|-----------|
| Look up a package name, import path, or key type | `references/quick-reference.md` |
| Generate keys from a seed or mnemonic | `references/key-derivation.md` |
| Construct and configure a WalletFacade | `references/wallet-construction.md` |
| Read wallet state, balances, or sync progress | `references/state-and-balances.md` |
| Create, balance, sign, prove, or submit a transaction | `references/transactions.md` |
| Connect to indexer, node, or proof server | `references/infrastructure-clients.md` |

## Related Skills

| Need | Skill |
|------|-------|
| DApp browser wallet integration (DApp Connector API) | `midnight-dapp-dev:dapp-connector` |
| DApp SDK providers (MidnightProviders, WalletProvider) | `midnight-dapp-dev:midnight-sdk` |
| Wallet CLI tools (balance, transfer, airdrop) | `midnight-wallet:wallet-cli` |
| Testing wallet SDK code | `midnight-cq:wallet-testing` |
| CLI wallet construction patterns | `compact-cli-dev:core` |
```

Note: Replace `` ` ` ` `` with proper triple-backtick fences (no spaces). The spaces are only in this plan to avoid markdown parsing issues.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/SKILL.md
git commit -m "feat(midnight-wallet): add wallet-sdk SKILL.md routing file with quick-start"
```

---

### Task 3: Write quick-reference.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md`

- [ ] **Step 1: Verify all package names against source**

Run verification for all 13 packages:

```bash
for dir in facade runtime abstractions hd capabilities shielded-wallet unshielded-wallet dust-wallet address-format indexer-client node-client prover-client utilities; do
  echo "=== $dir ==="
  grep '"name"' /tmp/midnight-wallet/packages/$dir/package.json
done
```

Confirm each name matches the package map in the plan header.

- [ ] **Step 2: Verify HD Roles enum values**

```bash
grep -A 7 'Roles =' /tmp/midnight-wallet/packages/hd/src/HDWallet.ts
```

Expected: `NightExternal: 0`, `NightInternal: 1`, `Dust: 2`, `Zswap: 3`, `Metadata: 4`

- [ ] **Step 3: Verify derivation path constants**

```bash
grep -E 'PURPOSE|COIN_TYPE' /tmp/midnight-wallet/packages/hd/src/HDWallet.ts
```

Expected: `PURPOSE = 44`, `COIN_TYPE = 2400`

- [ ] **Step 4: Write quick-reference.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md`:

```markdown
# Wallet SDK Quick Reference

Fast lookup for package names, types, and import paths. For detailed usage, follow the references linked in each section.

## Package Map

| Package | npm name | Key Exports |
|---------|----------|-------------|
| Facade | `@midnight-ntwrk/wallet-sdk-facade` | `WalletFacade`, `DefaultConfiguration`, `FacadeState` |
| Runtime | `@midnight-ntwrk/wallet-sdk-runtime` | `WalletBuilder` |
| Abstractions | `@midnight-ntwrk/wallet-sdk-abstractions` | `ProtocolVersion`, `WalletState`, `SyncProgress`, `TransactionHistoryStorage`, `InMemoryTransactionHistoryStorage` |
| HD | `@midnight-ntwrk/wallet-sdk-hd` | `HDWallet`, `Roles`, `generateRandomSeed`, `generateMnemonicWords`, `validateMnemonic` |
| Capabilities | `@midnight-ntwrk/wallet-sdk-capabilities` | `ProvingService`, `SubmissionService`, `PendingTransactionsService` |
| Shielded | `@midnight-ntwrk/wallet-sdk-shielded` | `ShieldedWallet`, `ShieldedWalletAPI`, `ShieldedWalletState` |
| Unshielded | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | `UnshieldedWallet`, `UnshieldedWalletAPI`, `UnshieldedWalletState`, `createKeystore`, `PublicKey` |
| Dust | `@midnight-ntwrk/wallet-sdk-dust-wallet` | `DustWallet`, `DustWalletAPI`, `DustWalletState` |
| Address Format | `@midnight-ntwrk/wallet-sdk-address-format` | `MidnightBech32m`, `UnshieldedAddress`, `ShieldedAddress`, `DustAddress` |
| Indexer Client | `@midnight-ntwrk/wallet-sdk-indexer-client` | GraphQL client for indexer sync |
| Node Client | `@midnight-ntwrk/wallet-sdk-node-client` | `PolkadotNodeClient` |
| Prover Client | `@midnight-ntwrk/wallet-sdk-prover-client` | `HttpProverClient` |
| Utilities | `@midnight-ntwrk/wallet-sdk-utilities` | Common operations and types shared across packages |

See `references/wallet-construction.md` for how these packages connect during wallet setup, and `references/infrastructure-clients.md` for client configuration.

## HD Key Derivation

HD (Hierarchical Deterministic) wallets derive an entire tree of cryptographic keys from a single seed, following the BIP-32 standard. A 24-word mnemonic phrase (BIP-39) can generate the seed, making backup and restoration possible from just those words.

Midnight uses three **roles**, each producing keys for a different wallet type:

| Role | Enum | Index | Wallet Type | Purpose |
|------|------|-------|-------------|---------|
| NightExternal | `Roles.NightExternal` | 0 | UnshieldedWallet | Public NIGHT token transfers and signing |
| Dust | `Roles.Dust` | 2 | DustWallet | DUST fee token management |
| Zswap | `Roles.Zswap` | 3 | ShieldedWallet | Privacy-preserving transactions with ZK proofs |

Two additional roles exist but are not used during standard wallet construction:
- `Roles.NightInternal` (index 1) — reserved for internal change addresses
- `Roles.Metadata` (index 4) — reserved for metadata operations

The **derivation path** follows `m/44'/2400'/{account}'/{role}/{index}` where:
- `44'` — BIP-44 purpose (multi-account hierarchy)
- `2400'` — Midnight's registered coin type
- `{account}'` — account number (typically `0`)
- `{role}` — one of the role indices above
- `{index}` — key index within that role (typically `0`)

The role index in the table is the value used in the `{role}` segment of the derivation path. For example, deriving the shielded key for the first account at index 0 uses path `m/44'/2400'/0'/3/0`.

See `references/key-derivation.md` for seed generation, mnemonic handling, and the full derivation code.

## Addresses and Bech32m Encoding

Midnight addresses use **Bech32m** encoding — a checksummed, human-readable format (the same standard used by Bitcoin Taproot addresses). All Midnight addresses start with the `mn` prefix followed by an address-type tag and the network ID.

Example: `mn_addr_undeployed1qpz8k3...` (an unshielded address on the local devnet)

The three address types correspond to the three wallet types:

| Type | Contains | Used for |
|------|----------|----------|
| `UnshieldedAddress` | Public key | Receiving public NIGHT transfers |
| `ShieldedAddress` | Coin public key + encryption public key | Receiving private/shielded transfers |
| `DustAddress` | Dust public key | Receiving DUST fee tokens |

Each address embeds a `NetworkId` so addresses are bound to a specific network (mainnet, testnet, local devnet). Decoding an address for the wrong network will fail.

See `references/infrastructure-clients.md` for address encoding/decoding with `MidnightBech32m`.

## Common Type Lookups

| Type | Package | Purpose |
|------|---------|---------|
| `FacadeState` | facade | Combined state snapshot of all three wallets + pending transactions. Has `isSynced` getter. |
| `SyncProgress` | abstractions | Tracks indexer sync status. Use `isStrictlyComplete()` to check if fully synced. |
| `ProtocolVersion` | abstractions | Branded `bigint` (via Effect's `Brand.nominal`) representing the protocol version (incremented at hard forks). |
| `BalancingRecipe` | facade | Discriminated union — `FinalizedTransactionRecipe`, `UnboundTransactionRecipe`, or `UnprovenTransactionRecipe`. |
| `UtxoWithMeta` | unshielded-wallet | A UTXO with metadata: `ctime` (creation time) and `registeredForDustGeneration` flag. |
| `WalletState` | abstractions | Branded `string` (serialized JSON) for wallet state persistence and migration. |
| `ZswapSecretKeys` | `@midnight-ntwrk/ledger` | Secret keys for the shielded wallet. Created via `ZswapSecretKeys.fromSeed(bytes)`. |
| `DustSecretKey` | `@midnight-ntwrk/ledger` | Secret key for the dust wallet. Created via `DustSecretKey.fromSeed(bytes)`. |

See `references/state-and-balances.md` for how to observe these types at runtime, and `references/transactions.md` for the balancing/recipe workflow.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md
git commit -m "feat(midnight-wallet): add wallet-sdk quick-reference cheat sheet"
```

---

### Task 4: Write key-derivation.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/key-derivation.md`

- [ ] **Step 1: Verify mnemonic function signatures**

```bash
grep -A 3 'export const generateMnemonicWords' /tmp/midnight-wallet/packages/hd/src/MnemonicUtils.ts
grep -A 3 'export const validateMnemonic' /tmp/midnight-wallet/packages/hd/src/MnemonicUtils.ts
grep -A 3 'export const generateRandomSeed' /tmp/midnight-wallet/packages/hd/src/MnemonicUtils.ts
grep -A 3 'export const joinMnemonicWords' /tmp/midnight-wallet/packages/hd/src/MnemonicUtils.ts
grep -A 3 'export const mnemonicToWords' /tmp/midnight-wallet/packages/hd/src/MnemonicUtils.ts
```

- [ ] **Step 2: Verify HDWallet.fromSeed return type**

```bash
grep -B 2 -A 10 'fromSeed' /tmp/midnight-wallet/packages/hd/src/HDWallet.ts
```

Expected: Returns `{ type: 'seedOk', hdWallet: HDWallet } | { type: 'seedError', error: unknown }`

- [ ] **Step 3: Verify deriveKeysAt return type**

```bash
grep -B 2 -A 10 'deriveKeysAt' /tmp/midnight-wallet/packages/hd/src/HDWallet.ts
```

Expected: Returns `{ type: 'keysDerived', keys: Record<...> } | { type: 'keyOutOfBounds', roles: readonly Role[] }`

- [ ] **Step 4: Write key-derivation.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/references/key-derivation.md`:

```markdown
# Key Derivation

How to generate seeds, derive keys, and handle mnemonics using `@midnight-ntwrk/wallet-sdk-hd`.

## Seed Generation

A seed is random bytes (default 256-bit / 32 bytes). Two ways to create one:

**Random seed:**
` ` `typescript
import { generateRandomSeed } from "@midnight-ntwrk/wallet-sdk-hd";

const seed: Uint8Array = generateRandomSeed(); // 256-bit by default
` ` `

**From a BIP-39 mnemonic (24 words):**
` ` `typescript
import {
  generateMnemonicWords,
  validateMnemonic,
  joinMnemonicWords,
} from "@midnight-ntwrk/wallet-sdk-hd";
import { mnemonicToSeedSync } from "@scure/bip39";
import { english } from "@scure/bip39/wordlists/english";

// Generate new mnemonic
const words: string[] = generateMnemonicWords(); // 24 words (256-bit strength)

// Validate an existing mnemonic
const isValid: boolean = validateMnemonic(joinMnemonicWords(words));

// Convert mnemonic to seed bytes
const seed: Uint8Array = mnemonicToSeedSync(joinMnemonicWords(words));
` ` `

The genesis wallet on devnet uses the fixed seed `0x0000...0001` (63 zeros followed by 1).

## Derivation Flow

From a seed, derive role-specific keys through the HD hierarchy:

` ` `typescript
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";

const hdResult = HDWallet.fromSeed(seed);
if (hdResult.type !== "seedOk") {
  throw new Error(`Invalid seed: ${hdResult.error}`);
}

const keys = hdResult.hdWallet
  .selectAccount(0)
  .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
  .deriveKeysAt(0);

if (keys.type !== "keysDerived") {
  throw new Error(`Key derivation failed for roles: ${keys.roles}`);
}

// keys.keys[Roles.Zswap]          -> Uint8Array for ShieldedWallet
// keys.keys[Roles.NightExternal]  -> Uint8Array for UnshieldedWallet
// keys.keys[Roles.Dust]           -> Uint8Array for DustWallet

// Clear sensitive key material when done
hdResult.hdWallet.clear();
` ` `

Each step in the chain narrows the derivation:
1. `HDWallet.fromSeed(seed)` — creates the root HD wallet from raw bytes
2. `.selectAccount(0)` — picks the account (most apps use account 0)
3. `.selectRoles([...])` — selects which key roles to derive
4. `.deriveKeysAt(0)` — derives keys at index 0 within each role

The result is a `Uint8Array` per role. These raw bytes are then converted to wallet-specific key types during construction (see `references/wallet-construction.md`).

## Result Types

Both `fromSeed` and `deriveKeysAt` return discriminated unions — always check the `type` field:

| Method | Success | Failure |
|--------|---------|---------|
| `HDWallet.fromSeed()` | `{ type: "seedOk", hdWallet: HDWallet }` | `{ type: "seedError", error: unknown }` |
| `.deriveKeysAt()` | `{ type: "keysDerived", keys: Record<Role, Uint8Array> }` | `{ type: "keyOutOfBounds", roles: readonly Role[] }` |

The single-role variant `deriveKeyAt` (on `RoleKey`) returns `{ type: "keyDerived", key: Uint8Array }` or `{ type: "keyOutOfBounds" }`.

## Security Notes

- Call `hdWallet.clear()` after derivation to zero out key material in memory
- Seeds and mnemonics are secrets — never log or persist them in plaintext
- The same seed always produces the same keys (deterministic), so backup = mnemonic backup

For the full wallet construction flow from these derived keys, see `references/wallet-construction.md`.
For a runnable example, see `examples/basic-wallet-setup.ts`.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/key-derivation.md
git commit -m "feat(midnight-wallet): add wallet-sdk key-derivation reference"
```

---

### Task 5: Write wallet-construction.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md`

- [ ] **Step 1: Verify factory method chains against source**

```bash
grep -A 5 'startWithSecretKeys' /tmp/midnight-wallet/packages/shielded-wallet/src/ShieldedWallet.ts | head -10
grep -A 5 'startWithPublicKey' /tmp/midnight-wallet/packages/unshielded-wallet/src/UnshieldedWallet.ts | head -10
grep -A 5 'startWithSecretKey' /tmp/midnight-wallet/packages/dust-wallet/src/DustWallet.ts | head -10
```

- [ ] **Step 2: Verify InitParams type**

```bash
grep -A 15 'InitParams' /tmp/midnight-wallet/packages/facade/src/index.ts
```

Expected: `shielded`, `unshielded`, `dust` factory functions plus optional `submissionService`, `pendingTransactionsService`, `provingService`.

- [ ] **Step 3: Verify DefaultConfiguration type**

```bash
grep -A 8 'DefaultConfiguration =' /tmp/midnight-wallet/packages/facade/src/index.ts
```

- [ ] **Step 4: Verify TransactionHistoryStorage interface**

```bash
grep -A 10 'interface TransactionHistoryStorage' /tmp/midnight-wallet/packages/abstractions/src/TransactionHistoryStorage.ts
```

Expected: `upsert`, `getAll`, `get`, `serialize` methods.

- [ ] **Step 5: Verify createKeystore location and signature**

```bash
grep -A 5 'export const createKeystore' /tmp/midnight-wallet/packages/unshielded-wallet/src/KeyStore.ts
```

- [ ] **Step 6: Verify docs-snippets for construction example**

```bash
grep -B 5 -A 30 'WalletFacade.init' /tmp/midnight-wallet/packages/docs-snippets/src/utils.ts
```

- [ ] **Step 7: Write wallet-construction.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md`:

```markdown
# Wallet Construction

How to build a fully configured `WalletFacade` from derived keys using the wallet SDK packages.

## Overview

Wallet construction has three phases:
1. **Convert derived keys** into wallet-specific secret keys and keystores
2. **Build configuration** that tells the wallet how to connect to infrastructure
3. **Initialize WalletFacade** with factories for each wallet type

## Key Conversion

Each wallet type needs its derived key in a specific format. The secret key types (`ZswapSecretKeys`, `DustSecretKey`) come from the `@midnight-ntwrk/ledger` package, not the wallet SDK:

` ` `typescript
import * as ledger from "@midnight-ntwrk/ledger";
import { createKeystore, PublicKey } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";

// Shielded — ZswapSecretKeys wraps the raw Zswap key
const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(derivedKeys.keys[Roles.Zswap]);

// Unshielded — needs a keystore (handles signing and address derivation)
const keystore = createKeystore(derivedKeys.keys[Roles.NightExternal], networkId);

// Dust — DustSecretKey wraps the raw Dust key
const dustSecretKey = ledger.DustSecretKey.fromSeed(derivedKeys.keys[Roles.Dust]);
` ` `

The `networkId` parameter binds the keystore to a specific network. On local devnet this is `"undeployed"`. The keystore is also used later for signing transactions.

## Configuration

`DefaultConfiguration` combines sub-configurations for each wallet type plus the shared services:

` ` `typescript
const configuration = {
  // Indexer — where the wallet syncs state from
  indexerWsUrl: "ws://localhost:8088/api/v1/graphql/websocket",
  indexerHttpUrl: "http://localhost:8088/api/v1/graphql",

  // Node — where transactions are submitted
  nodeUrl: "ws://localhost:9944",

  // Proof server — where ZK proofs are generated
  provingServerUrl: "http://localhost:6300",

  // Network
  networkId: "undeployed",
};
` ` `

The configuration object is a merge of several sub-configs:
- `DefaultShieldedConfiguration` — indexer URLs, sync parameters
- `DefaultUnshieldedConfiguration` — indexer URLs, node URL, transaction history
- `DefaultDustConfiguration` — indexer URLs, dust parameters
- `DefaultSubmissionConfiguration` — node URL for tx submission
- `DefaultPendingTransactionsServiceConfiguration` — pending tx tracking
- `DefaultProvingConfiguration` (partial) — proof server URL

In practice you pass a single flat object and the facade distributes the relevant fields to each sub-wallet.

See `references/infrastructure-clients.md` for details on what each URL connects to.

## WalletFacade Initialization

`WalletFacade.init()` takes factory functions for each wallet type. Each factory receives the full configuration and returns a wallet instance:

` ` `typescript
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import { UnshieldedWallet, createKeystore, PublicKey } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { InMemoryTransactionHistoryStorage } from "@midnight-ntwrk/wallet-sdk-abstractions";
import * as ledger from "@midnight-ntwrk/ledger";

const wallet = await WalletFacade.init({
  configuration,
  shielded: (cfg) =>
    ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
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
` ` `

Each factory follows the same pattern: `WalletType(config).startWith*(key)`. The factory approach means the facade controls when each wallet is constructed and started.

**DustParameters:** The dust wallet requires ledger parameters as a second argument to `startWithSecretKey`. Obtain them via `ledger.LedgerParameters.initialParameters().dust`.

**InitParams also accepts optional service overrides:**
- `submissionService` — custom transaction submission
- `pendingTransactionsService` — custom pending tx tracking
- `provingService` — custom proving backend (e.g., WASM instead of server)

## Starting the Wallet

After initialization, call `start()` to begin syncing with the indexer:

` ` `typescript
await wallet.start(shieldedSecretKeys, dustSecretKey);
` ` `

This kicks off indexer subscriptions for all three wallet types. The wallet will begin catching up with chain state. Use `waitForSyncedState()` to block until sync completes (see `references/state-and-balances.md`).

## Transaction History Storage

The unshielded wallet requires a `TransactionHistoryStorage` implementation. The SDK provides:

| Implementation | Package | Use case |
|---------------|---------|----------|
| `InMemoryTransactionHistoryStorage` | abstractions | Development and testing — state lost on restart |
| Custom implementation | — | Production — implement the `TransactionHistoryStorage` interface with persistent backing |

The interface:
` ` `typescript
interface TransactionHistoryStorage<T> {
  upsert(entry: T): Promise<void>;
  getAll(): AsyncIterableIterator<T>;
  get(hash: TransactionHash): Promise<T | undefined>;
  serialize(): Promise<SerializedTransactionHistory>;
}
` ` `

## Lifecycle

| Method | What it does |
|--------|-------------|
| `WalletFacade.init()` | Constructs wallet instances via factories |
| `wallet.start()` | Begins indexer sync for all three wallets |
| `wallet.stop()` | Stops sync, closes connections, cleans up resources |

Always call `stop()` when done to release WebSocket connections and subscriptions.

## WebSocket Polyfill

In Node.js environments, GraphQL subscriptions require a WebSocket implementation. Install the `ws` package and register it globally before constructing the wallet:

` ` `typescript
import WebSocket from "ws";
(globalThis as any).WebSocket = WebSocket;
` ` `

This is not needed in browser environments where `WebSocket` is available natively.

For a complete runnable example, see `examples/basic-wallet-setup.ts`.
For reading wallet state after construction, see `references/state-and-balances.md`.
```

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md
git commit -m "feat(midnight-wallet): add wallet-sdk wallet-construction reference"
```

---

### Task 6: Write state-and-balances.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md`

- [ ] **Step 1: Verify FacadeState class shape**

```bash
grep -A 20 'class FacadeState' /tmp/midnight-wallet/packages/facade/src/index.ts
```

Expected: `shielded`, `unshielded`, `dust`, `pending` fields plus `isSynced` getter.

- [ ] **Step 2: Verify ShieldedWalletState getters**

```bash
grep -E 'get (balances|totalCoins|availableCoins|pendingCoins|coinPublicKey|encryptionPublicKey|address|progress)' /tmp/midnight-wallet/packages/shielded-wallet/src/ShieldedWallet.ts
```

- [ ] **Step 3: Verify DustWalletState.balance method**

```bash
grep -A 3 'balance(time' /tmp/midnight-wallet/packages/dust-wallet/src/DustWallet.ts
```

- [ ] **Step 4: Verify SyncProgress interface**

```bash
grep -A 15 'interface SyncProgress' /tmp/midnight-wallet/packages/abstractions/src/SyncProgress.ts
```

- [ ] **Step 5: Write state-and-balances.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md`:

```markdown
# State and Balances

How to observe wallet state, check balances, and monitor sync progress.

## FacadeState

`WalletFacade` exposes a unified state stream that combines all three wallet types:

` ` `typescript
class FacadeState {
  readonly shielded: ShieldedWalletState;
  readonly unshielded: UnshieldedWalletState;
  readonly dust: DustWalletState;
  readonly pending: PendingTransactions<FinalizedTransaction>;

  get isSynced(): boolean;
}
` ` `

The `isSynced` getter returns `true` when all three wallets have caught up with the indexer. Never read balances before sync completes — they will be incomplete.

## Subscribing to State

State is delivered as an RxJS `Observable`. Subscribe to receive updates as the wallet syncs and as transactions are processed:

` ` `typescript
wallet.state().subscribe((state: FacadeState) => {
  console.log("Synced:", state.isSynced);
  console.log("Unshielded:", state.unshielded.balances);
  console.log("Shielded:", state.shielded.balances);
});
` ` `

For a one-shot read after sync, use `waitForSyncedState()`:

` ` `typescript
const state = await wallet.waitForSyncedState();
// state.isSynced is guaranteed true
` ` `

`waitForSyncedState()` returns a `Promise` that resolves once all three wallets report sync complete. Use this at startup before performing any operations.

## Balance Shapes

Each wallet type reports balances differently:

**Unshielded (via getters on UnshieldedWalletState):**
- `balances: Record<RawTokenType, bigint>` — token type to amount
- `totalCoins: readonly UtxoWithMeta[]` — all known UTXOs
- `availableCoins: readonly UtxoWithMeta[]` — spendable right now
- `pendingCoins: readonly UtxoWithMeta[]` — locked in pending transactions
- `address: UnshieldedAddress`
- `progress: SyncProgress`

`balances` is keyed by token type. For native NIGHT tokens, the key is the empty string `""`. The value is a `bigint` in the token's smallest unit (NIGHT has 6 decimal places, so `1_000_000n` = 1 NIGHT).

**Shielded (via getters on ShieldedWalletState):**
- `balances: Record<RawTokenType, bigint>`
- `totalCoins: readonly (AvailableCoin | PendingCoin)[]`
- `availableCoins: readonly AvailableCoin[]`
- `pendingCoins: readonly PendingCoin[]`
- `coinPublicKey: ShieldedCoinPublicKey`
- `encryptionPublicKey: ShieldedEncryptionPublicKey`
- `address: ShieldedAddress`
- `progress: SyncProgress`

Same balance structure as unshielded, but coins are privacy-preserving — amounts and ownership are hidden on-chain behind ZK proofs.

**Dust (via getters and methods on DustWalletState):**
- `totalCoins: readonly Dust[]`
- `availableCoins: readonly Dust[]`
- `pendingCoins: readonly Dust[]`
- `publicKey: DustPublicKey`
- `address: DustAddress`
- `progress: SyncProgress`
- `balance(time: Date): Balance` — **time-dependent** balance calculation
- `availableCoinsWithFullInfo(time: Date): readonly DustFullInfo[]`
- `estimateDustGeneration(nightUtxos, currentTime): readonly UtxoWithFullDustDetails[]`

Dust balances are **time-dependent** — DUST tokens expire, so `balance()` requires a `Date` parameter to calculate the currently valid amount. This is unique to the dust wallet.

## SyncProgress

Each wallet type includes a `progress` field for monitoring indexer sync:

` ` `typescript
interface SyncProgress {
  readonly appliedIndex: bigint;              // last block the wallet processed
  readonly highestIndex: bigint;              // latest block the indexer knows about
  readonly highestRelevantIndex: bigint;      // latest block relevant to this wallet
  readonly highestRelevantWalletIndex: bigint;
  readonly isConnected: boolean;              // whether the indexer connection is alive

  isStrictlyComplete(): boolean;     // true when fully caught up
  isCompleteWithin(maxGap?: bigint): boolean;  // true when within N blocks (default 50)
}
` ` `

Use `isStrictlyComplete()` for operations that need exact state (like balance checks before a transfer). Use `isCompleteWithin()` for more lenient checks where being a few blocks behind is acceptable.

## UTXO Metadata

UTXOs in the unshielded wallet carry metadata:

` ` `typescript
class UtxoWithMeta {
  readonly utxo: Utxo;
  readonly meta: UtxoMeta;
}

interface UtxoMeta {
  readonly ctime: Date;                          // when the UTXO was created
  readonly registeredForDustGeneration: boolean;  // whether it earns DUST
}
` ` `

The `registeredForDustGeneration` flag indicates whether a NIGHT UTXO has been registered to passively generate DUST tokens. See `references/transactions.md` for the dust registration flow.

For a runnable example of state observation, see `examples/state-observation.ts`.
For transaction operations that modify state, see `references/transactions.md`.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md
git commit -m "feat(midnight-wallet): add wallet-sdk state-and-balances reference"
```

---

### Task 7: Write transactions.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md`

- [ ] **Step 1: Verify WalletFacade transaction method signatures**

```bash
grep -E 'async (transferTransaction|balanceUnprovenTransaction|signRecipe|finalizeRecipe|finalizeTransaction|submitTransaction|calculateTransactionFee|estimateTransactionFee|registerNightUtxosForDustGeneration|deregisterFromDustGeneration|estimateRegistration|initSwap|revert|revertTransaction|queryTxHistoryByHash|getAllFromTxHistory)' /tmp/midnight-wallet/packages/facade/src/index.ts
```

- [ ] **Step 2: Verify signRecipe callback type**

```bash
grep -A 5 'signRecipe' /tmp/midnight-wallet/packages/facade/src/index.ts
```

Expected: `signSegment: (data: Uint8Array) => ledger.Signature` (synchronous callback).

- [ ] **Step 3: Write transactions.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md`:

```markdown
# Transactions

The full transaction lifecycle: creating transfers, balancing, signing, proving, and submitting.

## Transaction Lifecycle Overview

Every transaction follows the same pipeline:

` ` `
Create -> Balance -> Sign -> Prove -> Submit
` ` `

Each stage transforms the transaction into a more complete form:

| Stage | Input | Output | What happens |
|-------|-------|--------|-------------|
| Create | Transfer parameters | `UnprovenTransaction` | Builds the transaction structure |
| Balance | `UnprovenTransaction` | `UnprovenTransactionRecipe` | Adds fee inputs/outputs (DUST) |
| Sign | Recipe | Signed recipe | Signs relevant transaction segments |
| Prove | Signed recipe | `FinalizedTransaction` | Generates ZK proofs |
| Submit | `FinalizedTransaction` | `TransactionIdentifier` | Broadcasts to the network |

The facade provides convenience methods that handle multiple stages at once, or you can drive each stage individually for more control.

## Creating Transfers

The simplest path is `transferTransaction()`, which creates and balances in one call:

` ` `typescript
const recipe = await wallet.transferTransaction(
  [{ type: "unshielded", receiverAddress, amount: 5_000_000n }],
  { shieldedSecretKeys, dustSecretKey },
  { ttl: new Date(Date.now() + 5 * 60_000) }  // 5 minute TTL
);
` ` `

The `outputs` array accepts both shielded and unshielded transfers (typed as `CombinedTokenTransfer`). The `ttl` (time-to-live) sets the deadline — the transaction becomes invalid after this time.

Amount values are in the token's smallest unit. NIGHT has 6 decimal places, so `5_000_000n` = 5 NIGHT.

## Balancing

Balancing adds the DUST fee inputs and change outputs needed to make a transaction valid. Three methods are available depending on what stage the transaction is at:

| Method | Input type | Output type |
|--------|-----------|-------------|
| `balanceUnprovenTransaction()` | `UnprovenTransaction` | `UnprovenTransactionRecipe` |
| `balanceUnboundTransaction()` | `UnboundTransaction` | `UnboundTransactionRecipe` |
| `balanceFinalizedTransaction()` | `FinalizedTransaction` | `FinalizedTransactionRecipe` |

All three require secret keys for coin selection:

` ` `typescript
const recipe = await wallet.balanceUnprovenTransaction(
  tx,
  { shieldedSecretKeys, dustSecretKey },
  { ttl: new Date(Date.now() + 5 * 60_000) }
);
` ` `

The result is a `Recipe` — a transaction bundled with metadata about which segments need signing. The optional `tokenKindsToBalance` parameter (default `'all'`) controls which token types to balance.

## Signing

Recipes may contain segments that require a signature (typically from the unshielded keystore):

` ` `typescript
const signedRecipe = await wallet.signRecipe(
  recipe,
  (payload: Uint8Array) => keystore.signData(payload)
);
` ` `

The `signSegment` callback receives raw bytes and must return a `ledger.Signature` **synchronously**. The keystore created during wallet construction (see `references/wallet-construction.md`) provides the `signData` method.

For signing individual transactions (not wrapped in recipes):

` ` `typescript
const signedTx = await wallet.signUnprovenTransaction(tx, (payload) => keystore.signData(payload));
const signedUnbound = await wallet.signUnboundTransaction(tx, (payload) => keystore.signData(payload));
` ` `

## Proving

Proving generates the ZK proofs that make the transaction valid on-chain. This is the most computationally expensive step:

` ` `typescript
const finalizedTx = await wallet.finalizeRecipe(signedRecipe);
` ` `

For transactions that aren't wrapped in a recipe:

` ` `typescript
const finalizedTx = await wallet.finalizeTransaction(unprovenTx);
` ` `

Proving is performed by the proof server configured during wallet construction. See `references/infrastructure-clients.md` for proof server setup.

## Submission

Submit the finalized transaction to the network:

` ` `typescript
const txId = await wallet.submitTransaction(finalizedTx);
` ` `

The returned `TransactionIdentifier` can be used to track the transaction's progress through the pending transactions service.

## Fee Estimation

Estimate fees before committing to a transaction:

` ` `typescript
// Fee for an already-constructed transaction
const fee = await wallet.calculateTransactionFee(tx);

// Fee including balancing overhead
const totalFee = await wallet.estimateTransactionFee(
  tx,
  dustSecretKey,
  { ttl: new Date(Date.now() + 5 * 60_000) }
);
` ` `

Both return a `bigint` in DUST's smallest unit (15 decimal places).

## Dust Registration

NIGHT UTXOs can be registered to passively generate DUST tokens. This is required before a wallet can pay transaction fees:

` ` `typescript
const recipe = await wallet.registerNightUtxosForDustGeneration(
  nightUtxos,
  nightVerifyingKey,
  (payload) => keystore.signData(payload),
  dustReceiverAddress  // optional, defaults to own dust address
);

const finalizedTx = await wallet.finalizeRecipe(recipe);
await wallet.submitTransaction(finalizedTx);
` ` `

To check registration economics before committing:

` ` `typescript
const estimate = await wallet.estimateRegistration(nightUtxos);
// estimate.fee — cost of the registration transaction
// estimate.dustGenerationEstimations — projected DUST yield per UTXO
` ` `

To deregister:

` ` `typescript
const recipe = await wallet.deregisterFromDustGeneration(
  nightUtxos,
  nightVerifyingKey,
  (payload) => keystore.signData(payload)
);
` ` `

## Reverting Transactions

If a transaction fails or you need to unlock coins held in a pending transaction:

` ` `typescript
await wallet.revert(recipe);        // revert a recipe or transaction
await wallet.revertTransaction(tx); // revert a specific transaction
` ` `

This releases any UTXOs that were locked during balancing, making them available for new transactions.

## Swap Initialization

For atomic swaps between token types:

` ` `typescript
const recipe = await wallet.initSwap(
  desiredInputs,   // what you want to receive
  desiredOutputs,  // what you're offering
  { shieldedSecretKeys, dustSecretKey },
  { ttl: new Date(Date.now() + 10 * 60_000) }
);
` ` `

Swaps follow the same balance -> sign -> prove -> submit pipeline after initialization.

## Transaction History

Query past transactions (unshielded wallet only — depends on `TransactionHistoryStorage` from construction):

` ` `typescript
// By hash
const entry = await wallet.queryTxHistoryByHash(txHash);

// All history (async iterator)
for await (const entry of wallet.getAllFromTxHistory()) {
  console.log(entry);
}
` ` `

For a complete transfer example, see `examples/transfer-flow.ts`.
For dust registration, see `examples/dust-registration.ts`.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md
git commit -m "feat(midnight-wallet): add wallet-sdk transactions reference"
```

---

### Task 8: Write infrastructure-clients.md

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md`

- [ ] **Step 1: Verify PolkadotNodeClient API**

```bash
grep -A 10 'sendMidnightTransaction' /tmp/midnight-wallet/packages/node-client/src/effect/PolkadotNodeClient.ts
```

- [ ] **Step 2: Verify HttpProverClient API**

```bash
grep -A 10 'proveTransaction' /tmp/midnight-wallet/packages/prover-client/src/effect/HttpProverClient.ts
```

- [ ] **Step 3: Verify MidnightBech32m API**

```bash
grep -E 'static (encode|parse|prefix)' /tmp/midnight-wallet/packages/address-format/src/index.ts
grep -A 3 'decode<' /tmp/midnight-wallet/packages/address-format/src/index.ts
```

- [ ] **Step 4: Write infrastructure-clients.md**

Write to `plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md`:

```markdown
# Infrastructure Clients

How to connect to the indexer, node, and proof server — the three external services a wallet needs to operate.

## Architecture

A running wallet maintains connections to three infrastructure services:

| Service | Purpose | Protocol | Default URL |
|---------|---------|----------|-------------|
| Indexer | Sync chain state, watch for relevant transactions | GraphQL over WebSocket + HTTP | `ws://localhost:8088/api/v1/graphql/websocket` (WS), `http://localhost:8088/api/v1/graphql` (HTTP) |
| Node | Submit transactions to the network | Polkadot RPC over WebSocket | `ws://localhost:9944` |
| Proof Server | Generate ZK proofs for transactions | HTTP | `http://localhost:6300` |

These URLs are for local devnet. On testnet or mainnet, replace with the appropriate endpoints.

## Indexer Client

`@midnight-ntwrk/wallet-sdk-indexer-client` provides a GraphQL client that syncs wallet state from the Midnight indexer.

The wallet uses two connection types:
- **WebSocket** — for real-time subscriptions (new blocks, transaction confirmations)
- **HTTP** — for one-shot queries (historical data, catch-up sync)

Both URLs are passed through the wallet configuration:

` ` `typescript
const configuration = {
  indexerWsUrl: "ws://localhost:8088/api/v1/graphql/websocket",
  indexerHttpUrl: "http://localhost:8088/api/v1/graphql",
  // ...other config
};
` ` `

You don't interact with the indexer client directly — the wallet's internal sync engine manages the connection. Monitor sync progress through `SyncProgress` on each wallet's state (see `references/state-and-balances.md`).

## Node Client

`@midnight-ntwrk/wallet-sdk-node-client` provides `PolkadotNodeClient` for submitting transactions to a Midnight node via Polkadot RPC.

The node client uses Effect-ts internally. Key method:

- `sendMidnightTransaction(serializedTransaction)` — submits a serialized transaction and returns a stream of `SubmissionEvent` updates

In most cases you won't use the node client directly — `wallet.submitTransaction()` handles submission. Direct use is for advanced scenarios like monitoring individual submission events.

## Proof Server (Prover Client)

`@midnight-ntwrk/wallet-sdk-prover-client` provides `HttpProverClient` for communicating with the proof server to generate ZK proofs.

Key method:

- `proveTransaction(tx, costModel?)` — generates ZK proofs for a transaction

Proof generation is the most time-consuming step in the transaction lifecycle. The proof server runs heavy cryptographic computations and may take several seconds per transaction.

The SDK also supports alternative proving backends through the capabilities package:

` ` `typescript
import { makeWasmProvingServiceEffect } from "@midnight-ntwrk/wallet-sdk-capabilities/proving";
` ` `

WASM proving runs in-process and is significantly slower than the dedicated proof server. It's primarily useful for testing or environments where running a separate proof server isn't practical.

## Address Encoding

`@midnight-ntwrk/wallet-sdk-address-format` handles Bech32m encoding and decoding for Midnight addresses.

**Encoding:**
` ` `typescript
import { MidnightBech32m } from "@midnight-ntwrk/wallet-sdk-address-format";

const encoded = MidnightBech32m.encode(networkId, addressData);
// -> "mn_addr_undeployed1qpz8k3..."
` ` `

**Parsing and decoding:**
` ` `typescript
const parsed = MidnightBech32m.parse("mn_addr_undeployed1qpz8k3...");
const address = parsed.decode(expectedType, networkId);
` ` `

Parsing extracts the raw data; decoding validates the address type and network ID — it throws if either doesn't match. This prevents accidentally sending funds to the wrong network.

The `MidnightBech32m` class has a static `prefix` of `"mn"`. All Midnight addresses start with this prefix.

**Creating a keystore** (for unshielded wallet signing):
` ` `typescript
import { createKeystore, PublicKey } from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";

const keystore = createKeystore(derivedKeys.keys[Roles.NightExternal], networkId);
// keystore.signData(payload) — sign transaction segments
// keystore.getBech32Address() — get the Bech32m-encoded address
// keystore.getPublicKey() — get the signature verifying key
// PublicKey.fromKeyStore(keystore) — extract PublicKey for wallet construction
` ` `

The keystore binds a derived key to a network and provides signing capabilities. It's created once during wallet construction and reused for all signing operations.

For how these clients are configured during wallet construction, see `references/wallet-construction.md`.
For the proof server's role in the transaction lifecycle, see `references/transactions.md`.
For proof server management (starting, stopping, health checks), see `midnight-tooling:proof-server`.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md
git commit -m "feat(midnight-wallet): add wallet-sdk infrastructure-clients reference"
```

---

### Task 9: Write example files

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/examples/basic-wallet-setup.ts`
- Create: `plugins/midnight-wallet/skills/wallet-sdk/examples/transfer-flow.ts`
- Create: `plugins/midnight-wallet/skills/wallet-sdk/examples/dust-registration.ts`
- Create: `plugins/midnight-wallet/skills/wallet-sdk/examples/state-observation.ts`

- [ ] **Step 1: Verify the docs-snippets construction pattern**

```bash
cat /tmp/midnight-wallet/packages/docs-snippets/src/utils.ts
```

Use the patterns from docs-snippets as the ground truth for example code.

- [ ] **Step 2: Write basic-wallet-setup.ts**

Write to `plugins/midnight-wallet/skills/wallet-sdk/examples/basic-wallet-setup.ts`:

```typescript
/**
 * Complete wallet construction from seed to synced state.
 * Covers: seed generation, HD derivation, key conversion, configuration,
 * WalletFacade initialization, and waiting for sync.
 */
import WebSocket from "ws";
(globalThis as any).WebSocket = WebSocket;

import { HDWallet, Roles, generateRandomSeed } from "@midnight-ntwrk/wallet-sdk-hd";
import { WalletFacade } from "@midnight-ntwrk/wallet-sdk-facade";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
  UnshieldedWallet,
  createKeystore,
  PublicKey,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { InMemoryTransactionHistoryStorage } from "@midnight-ntwrk/wallet-sdk-abstractions";
import * as ledger from "@midnight-ntwrk/ledger";

// 1. Generate seed and derive keys
const seed = generateRandomSeed();
const hdResult = HDWallet.fromSeed(seed);
if (hdResult.type !== "seedOk") throw new Error("Invalid seed");

const keys = hdResult.hdWallet
  .selectAccount(0)
  .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust])
  .deriveKeysAt(0);
if (keys.type !== "keysDerived") throw new Error("Key derivation failed");

hdResult.hdWallet.clear();

// 2. Convert to wallet-specific key formats
const networkId = "undeployed";
const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(keys.keys[Roles.Zswap]);
const keystore = createKeystore(keys.keys[Roles.NightExternal], networkId);
const dustSecretKey = ledger.DustSecretKey.fromSeed(keys.keys[Roles.Dust]);

// 3. Configure infrastructure URLs (local devnet)
const configuration = {
  indexerWsUrl: "ws://localhost:8088/api/v1/graphql/websocket",
  indexerHttpUrl: "http://localhost:8088/api/v1/graphql",
  nodeUrl: "ws://localhost:9944",
  provingServerUrl: "http://localhost:6300",
  networkId,
};

// 4. Initialize WalletFacade with factories for each wallet type
const wallet = await WalletFacade.init({
  configuration,
  shielded: (cfg) =>
    ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
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

// 5. Start syncing and wait for completion
await wallet.start(shieldedSecretKeys, dustSecretKey);
const state = await wallet.waitForSyncedState();

console.log("Wallet synced");
console.log("Unshielded balance:", state.unshielded.balances);
console.log("Shielded balance:", state.shielded.balances);

// 6. Clean up when done
await wallet.stop();
```

- [ ] **Step 3: Write transfer-flow.ts**

Write to `plugins/midnight-wallet/skills/wallet-sdk/examples/transfer-flow.ts`:

```typescript
/**
 * Transfer NIGHT tokens between wallets.
 * Covers: creating a transfer, signing, proving, and submitting.
 * Assumes wallet is already constructed and synced (see basic-wallet-setup.ts).
 */

// Create and balance a transfer in one call
const recipe = await wallet.transferTransaction(
  [
    {
      type: "unshielded",
      receiverAddress: recipientAddress,
      amount: 5_000_000n, // 5 NIGHT (6 decimal places)
    },
  ],
  { shieldedSecretKeys, dustSecretKey },
  { ttl: new Date(Date.now() + 5 * 60_000) } // 5 minute TTL
);

// Sign the transaction segments (synchronous callback)
const signedRecipe = await wallet.signRecipe(
  recipe,
  (payload: Uint8Array) => keystore.signData(payload)
);

// Generate ZK proofs and finalize
const finalizedTx = await wallet.finalizeRecipe(signedRecipe);

// Submit to the network
const txId = await wallet.submitTransaction(finalizedTx);
console.log("Transaction submitted:", txId);
```

- [ ] **Step 4: Write dust-registration.ts**

Write to `plugins/midnight-wallet/skills/wallet-sdk/examples/dust-registration.ts`:

```typescript
/**
 * Register NIGHT UTXOs for passive DUST generation.
 * Covers: checking registration economics, registering, and deregistering.
 * Assumes wallet is already constructed and synced (see basic-wallet-setup.ts).
 */

// Check current unshielded UTXOs
const state = await wallet.waitForSyncedState();
const nightUtxos = state.unshielded.availableCoins;

// Estimate registration economics before committing
const estimate = await wallet.estimateRegistration(nightUtxos);
console.log("Registration fee:", estimate.fee);
console.log("Projected DUST yield:", estimate.dustGenerationEstimations);

// Get the verifying key from the keystore
const nightVerifyingKey = keystore.getPublicKey();

// Register UTXOs for dust generation
const recipe = await wallet.registerNightUtxosForDustGeneration(
  nightUtxos,
  nightVerifyingKey,
  (payload) => keystore.signData(payload)
);

const finalizedTx = await wallet.finalizeRecipe(recipe);
await wallet.submitTransaction(finalizedTx);
console.log("NIGHT UTXOs registered for DUST generation");

// Later: deregister if needed
const deregRecipe = await wallet.deregisterFromDustGeneration(
  nightUtxos,
  nightVerifyingKey,
  (payload) => keystore.signData(payload)
);
const deregTx = await wallet.finalizeRecipe(deregRecipe);
await wallet.submitTransaction(deregTx);
```

- [ ] **Step 5: Write state-observation.ts**

Write to `plugins/midnight-wallet/skills/wallet-sdk/examples/state-observation.ts`:

```typescript
/**
 * Subscribe to wallet state and monitor balances.
 * Covers: state streams, sync progress, and balance reading.
 * Assumes wallet is already constructed and started (see basic-wallet-setup.ts).
 */

// One-shot: wait for sync then read balances
const state = await wallet.waitForSyncedState();
console.log("Unshielded NIGHT:", state.unshielded.balances[""]);
console.log("Available UTXOs:", state.unshielded.availableCoins.length);
console.log("Shielded NIGHT:", state.shielded.balances[""]);

// Dust balance is time-dependent
console.log("DUST balance:", state.dust.balance(new Date()));

// Continuous: subscribe to state changes
const subscription = wallet.state().subscribe((s) => {
  if (!s.isSynced) {
    // Report sync progress per wallet type
    const progress = s.unshielded.progress;
    console.log(
      `Syncing: ${progress.appliedIndex}/${progress.highestIndex}`,
      `(connected: ${progress.isConnected})`
    );
    return;
  }

  console.log("Unshielded:", s.unshielded.balances);
  console.log("Shielded:", s.shielded.balances);
  console.log("Dust:", s.dust.balance(new Date()));
  console.log("Pending txs:", s.pending);
});

// Clean up subscription when done
subscription.unsubscribe();
```

- [ ] **Step 6: Commit all examples**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/examples/
git commit -m "feat(midnight-wallet): add wallet-sdk example files"
```

---

### Task 10: Add cross-references to existing skills

**Files:**
- Modify: `plugins/compact-cli-dev/skills/core/references/wallet-management.md` (line 1)
- Modify: `plugins/midnight-dapp-dev/skills/midnight-sdk/SKILL.md`
- Modify: `plugins/midnight-cq/skills/wallet-testing/SKILL.md`
- Modify: `plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md`

- [ ] **Step 1: Add cross-reference to compact-cli-dev wallet-management.md**

At the top of `plugins/compact-cli-dev/skills/core/references/wallet-management.md`, after the title line, add:

```markdown
> For comprehensive Wallet SDK API reference, see `midnight-wallet:wallet-sdk`. This document covers wallet construction patterns specific to the CLI context.
```

- [ ] **Step 2: Add cross-reference to midnight-dapp-dev midnight-sdk SKILL.md**

Find the appropriate location in `plugins/midnight-dapp-dev/skills/midnight-sdk/SKILL.md` (near the top where it cross-references other skills) and add a mention:

```markdown
For the underlying Wallet SDK packages (WalletFacade, HD derivation, three-wallet architecture), see `midnight-wallet:wallet-sdk`.
```

- [ ] **Step 3: Add cross-reference to midnight-cq wallet-testing SKILL.md**

In `plugins/midnight-cq/skills/wallet-testing/SKILL.md`, in the "When to Use This Skill" table, add a row:

```markdown
| Do I need the Wallet SDK API reference? | `midnight-wallet:wallet-sdk` |
```

- [ ] **Step 4: Add cross-reference to midnight-verify verify-wallet-sdk SKILL.md**

In `plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md`, in the "Hints from Existing Skills" section, add:

```markdown
- `midnight-wallet:wallet-sdk` skill — comprehensive wallet SDK package reference, API surface, construction patterns
```

- [ ] **Step 5: Commit cross-references**

```bash
git add plugins/compact-cli-dev/skills/core/references/wallet-management.md
git add plugins/midnight-dapp-dev/skills/midnight-sdk/SKILL.md
git add plugins/midnight-cq/skills/wallet-testing/SKILL.md
git add plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md
git commit -m "feat(midnight-wallet): add cross-references to wallet-sdk skill from related skills"
```

---

### Task 11: Update plugin.json

**Files:**
- Modify: `plugins/midnight-wallet/.claude-plugin/plugin.json`

- [ ] **Step 1: Update plugin description and keywords**

In `plugins/midnight-wallet/.claude-plugin/plugin.json`, update:

```json
{
  "description": "Wallet management for Midnight Network development — wraps the midnight-wallet-cli MCP server for balance checking, transfers, airdrop, and dust registration, plus comprehensive Wallet SDK package reference for programmatic wallet construction and transaction operations.",
  "keywords": [
    "midnight",
    "wallet",
    "wallet-sdk",
    "night-tokens",
    "dust-tokens",
    "transfer",
    "airdrop",
    "balance",
    "mcp",
    "test-wallets",
    "devnet",
    "funding",
    "bip39",
    "mnemonic",
    "wallet-facade",
    "hd-wallet"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/.claude-plugin/plugin.json
git commit -m "feat(midnight-wallet): update plugin.json with wallet-sdk description and keywords"
```

---

### Task 12: Final verification pass

- [ ] **Step 1: Verify all files exist**

```bash
find plugins/midnight-wallet/skills/wallet-sdk/ -type f | sort
```

Expected:
```
plugins/midnight-wallet/skills/wallet-sdk/SKILL.md
plugins/midnight-wallet/skills/wallet-sdk/examples/basic-wallet-setup.ts
plugins/midnight-wallet/skills/wallet-sdk/examples/dust-registration.ts
plugins/midnight-wallet/skills/wallet-sdk/examples/state-observation.ts
plugins/midnight-wallet/skills/wallet-sdk/examples/transfer-flow.ts
plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md
plugins/midnight-wallet/skills/wallet-sdk/references/key-derivation.md
plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md
plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md
plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md
plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md
```

- [ ] **Step 2: Verify cross-references were added**

```bash
grep -l 'midnight-wallet:wallet-sdk' plugins/compact-cli-dev/skills/core/references/wallet-management.md plugins/midnight-dapp-dev/skills/midnight-sdk/SKILL.md plugins/midnight-cq/skills/wallet-testing/SKILL.md plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md
```

Expected: All 4 files listed.

- [ ] **Step 3: Run /midnight-verify:verify on key claims**

Verify the following critical claims from the skill content:

1. `WalletFacade` is exported from `@midnight-ntwrk/wallet-sdk-facade`
2. `ShieldedWallet` is exported from `@midnight-ntwrk/wallet-sdk-shielded`
3. `HDWallet.fromSeed` returns a discriminated union with `seedOk` type
4. `Roles.Zswap` has value `3`
5. `createKeystore` is exported from `@midnight-ntwrk/wallet-sdk-unshielded-wallet`

Use `/midnight-verify:verify` for each claim.

- [ ] **Step 4: Verify no stale package names**

```bash
grep -rn 'wallet-sdk-shielded-wallet' plugins/midnight-wallet/skills/wallet-sdk/
```

Expected: No matches. The correct package name is `wallet-sdk-shielded` (without `-wallet` suffix).

- [ ] **Step 5: Final commit if any fixes needed**

If verification found issues, fix them and commit:

```bash
git add -A plugins/midnight-wallet/skills/wallet-sdk/
git commit -m "fix(midnight-wallet): correct wallet-sdk skill content after verification"
```
