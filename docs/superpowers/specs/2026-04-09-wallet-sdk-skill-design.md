# Wallet SDK Skill Design

**Date:** 2026-04-09
**Plugin:** midnight-wallet
**Branch:** wallet-sdk

## Problem

Agents struggle to find information about the `@midnight-ntwrk/wallet-sdk-*` packages — WalletFacade, WalletBuilder, HD derivation, the three-wallet architecture, transaction balancing, and infrastructure clients. The existing wallet-related skills cover the CLI tool (`midnight-wallet:wallet-cli`), DApp-side providers (`midnight-dapp-dev:midnight-sdk`), and testing (`midnight-cq:wallet-testing`), but none cover the SDK packages themselves. Some wallet SDK content exists in `compact-cli-dev:core/references/wallet-management.md`, but it's buried in the wrong plugin and scoped to CLI usage patterns.

## Audience

Other agents (compact-cli-dev, midnight-dapp-dev, etc.) that need to construct and use wallets programmatically. Not end-user documentation.

## Design Decisions

1. **Coexist with existing content** — The compact-cli-dev wallet-management reference stays as-is (CLI-focused). The new skill is the comprehensive SDK reference. Cross-references added to both directions.
2. **Progressive disclosure** — SKILL.md is a routing file with an inlined quick-start for the most common task (wallet construction). Reference files cover one task each. Example files hold complete runnable code.
3. **Organized by task, not package** — Reference files are named for what the developer is trying to do, not which package they wrap.
4. **SDK boundary only** — Does not cover the DApp Connector API (handled by `midnight-dapp-dev:dapp-connector`) or the CLI tool (handled by `midnight-wallet:wallet-cli`).

## File Structure

```
plugins/midnight-wallet/skills/wallet-sdk/
├── SKILL.md
├── references/
│   ├── quick-reference.md
│   ├── key-derivation.md
│   ├── wallet-construction.md
│   ├── state-and-balances.md
│   ├── transactions.md
│   └── infrastructure-clients.md
└── examples/
    ├── basic-wallet-setup.ts
    ├── transfer-flow.ts
    ├── dust-registration.ts
    └── state-observation.ts
```

## SKILL.md

Acts as a router. Contains:
- Trigger-rich description covering natural phrases and key type names
- Inlined quick-start section for wallet construction (the most common task)
- Routing table: "what are you trying to do?" → reference file
- Related skills table pointing to dapp-connector, midnight-sdk, wallet-cli, wallet-testing, compact-cli-dev:core

```yaml
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
```

Quick start section covers:
- The construction flow: `Seed → HDWallet → selectRoles → deriveKeysAt → WalletFacade.init`
- Key packages table (hd, facade, shielded, unshielded, dust)
- Pointer to `examples/basic-wallet-setup.ts` and `references/wallet-construction.md`

## Reference Files

### quick-reference.md — The Cheat Sheet

Package map table (all 12 packages with npm names and key exports), HD roles table with derivation path explanation, address types with Bech32m encoding explanation and example address format, and common type lookups table. Each section includes brief contextual explanation (what HD stands for, what Bech32m is, why dust balances are time-dependent) and pointers to detailed references.

### key-derivation.md

Seed generation (random and from BIP-39 mnemonic), the full derivation flow with code (`HDWallet.fromSeed → selectAccount → selectRoles → deriveKeysAt`), result type discrimination (`seedOk`/`seedError`, `keysDerived`/`derivationError`), and security notes (clearing key material, never logging seeds).

### wallet-construction.md

Key conversion (raw bytes → ZswapSecretKeys, keystore, DustSecretKey), DefaultConfiguration shape with infrastructure URLs, WalletFacade.init with factory pattern explanation, starting the wallet and sync, TransactionHistoryStorage options (InMemory vs custom), lifecycle methods (init/start/stop), and WebSocket polyfill note for Node.js.

### state-and-balances.md

FacadeState interface shape, subscribing via RxJS Observable, waitForSyncedState for one-shot reads, balance shapes per wallet type (unshielded, shielded, dust), dust's time-dependent balance, SyncProgress interface with isStrictlyComplete/isCompleteWithin, and UtxoWithMeta metadata.

### transactions.md

Transaction lifecycle overview (create → balance → sign → prove → submit) with stage table, creating transfers with transferTransaction, balancing methods for each transaction stage, signing with signRecipe callback, proving with finalizeRecipe/finalizeTransaction, submission with submitTransaction, fee estimation (calculateTransactionFee/estimateTransactionFee), dust registration and deregistration flow, reverting transactions, swap initialization, and transaction history queries.

### infrastructure-clients.md

Architecture overview (indexer, node, proof server with protocols and default URLs), indexer client (GraphQL WebSocket + HTTP, configured through wallet config, not used directly), node client (PolkadotNodeClient with sendMidnightTransaction returning Observable\<SubmissionEvent\>), prover client (HttpProverClient + WASM alternative), and address encoding/decoding with MidnightBech32m and createKeystore.

## Example Files

All examples are complete TypeScript files with doc comments explaining purpose and prerequisites.

| File | Covers | Assumes |
|------|--------|---------|
| `basic-wallet-setup.ts` | Seed → keys → config → WalletFacade.init → sync → cleanup | Nothing — fully self-contained |
| `transfer-flow.ts` | Create transfer → sign → prove → submit | Wallet constructed and synced |
| `dust-registration.ts` | Estimate → register → deregister | Wallet constructed and synced |
| `state-observation.ts` | One-shot balance read + continuous subscription + sync progress | Wallet constructed and started |

## Cross-References

One-line additions to 4 existing files to create discovery paths:

| File | Addition |
|------|----------|
| `compact-cli-dev:core/references/wallet-management.md` | Note at top: "For comprehensive Wallet SDK API reference, see `midnight-wallet:wallet-sdk`" |
| `midnight-dapp-dev:midnight-sdk` SKILL.md | Related skills row for wallet SDK packages |
| `midnight-cq:wallet-testing` SKILL.md | Related skills row for wallet SDK API reference |
| `midnight-verify:verify-wallet-sdk` SKILL.md | Entry in "Hints from Existing Skills" section |

## Source Material

The wallet SDK source was reviewed from https://github.com/midnightntwrk/midnight-wallet (cloned to `/tmp/midnight-wallet`). Key packages examined: facade, runtime, abstractions, hd, capabilities, shielded-wallet, unshielded-wallet, dust-wallet, address-format, indexer-client, node-client, prover-client, and docs-snippets.

## Plugin Metadata

The `plugin.json` description currently focuses on the CLI tool. Update it to mention the SDK reference:

```json
"description": "Wallet management for Midnight Network development — wraps the midnight-wallet-cli MCP server for balance checking, transfers, airdrop, and dust registration, plus comprehensive Wallet SDK package reference for programmatic wallet construction and transaction operations.",
"keywords": [
  "midnight", "wallet", "wallet-sdk", "night-tokens", "dust-tokens",
  "transfer", "airdrop", "balance", "mcp", "test-wallets", "devnet",
  "funding", "bip39", "mnemonic", "wallet-facade", "hd-wallet"
]
```

## Out of Scope

- DApp Connector API (covered by `midnight-dapp-dev:dapp-connector`)
- Wallet CLI MCP tools (covered by `midnight-wallet:wallet-cli`)
- Wallet SDK testing patterns (covered by `midnight-cq:wallet-testing`)
- WalletBuilder/runtime advanced usage (variant registration, protocol version migration) — could be a future addition if agents need it
