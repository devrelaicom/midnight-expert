---
name: midnight-wallet:wallet-sdk
description: >-
  This skill should be used when the user asks about the Midnight Wallet SDK
  packages (@midnight-ntwrk/wallet-sdk-*), how to construct a wallet with
  WalletFacade, HD key derivation from seeds or mnemonics,
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

    Seed (64 hex chars)
      → HDWallet.fromSeed() → selectAccount(0) → selectRoles() → deriveKeysAt(0)
        → ShieldedWallet (Zswap role)
        → UnshieldedWallet (NightExternal role)
        → DustWallet (Dust role)
          → WalletFacade.init({ shielded, unshielded, dust, configuration })

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
