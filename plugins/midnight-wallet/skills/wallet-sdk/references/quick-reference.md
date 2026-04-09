# Wallet SDK Quick Reference

Fast lookup tables for the Midnight Wallet SDK. Every claim in this file is verified against the wallet SDK source code.

---

## Package Map

The wallet SDK is split into focused packages under the `@midnight-ntwrk` scope.

| Package directory | npm name | Purpose | Key exports |
|---|---|---|---|
| `abstractions` | `@midnight-ntwrk/wallet-sdk-abstractions` | Core interfaces and domain types | `WalletState`, `WalletSeed`, `SyncProgress`, `ProtocolVersion`, `ProtocolState`, `NetworkId`, `SerializedTransaction`, `TransactionHistoryStorage` |
| `address-format` | `@midnight-ntwrk/wallet-sdk-address-format` | Bech32m address encoding/decoding | `MidnightBech32m`, `ShieldedAddress`, `UnshieldedAddress`, `DustAddress`, `Bech32mCodec`, `ShieldedCoinPublicKey`, `ShieldedEncryptionPublicKey` |
| `capabilities` | `@midnight-ntwrk/wallet-sdk-capabilities` | Wallet capability definitions | Capability interfaces |
| `dust-wallet` | `@midnight-ntwrk/wallet-sdk-dust-wallet` | DUST token wallet variant | `DustWallet` |
| `facade` | `@midnight-ntwrk/wallet-sdk-facade` | High-level wallet API | `WalletFacade`, `FacadeState`, `BalancingRecipe` |
| `hd` | `@midnight-ntwrk/wallet-sdk-hd` | HD key derivation | `HDWallet`, `Roles`, `AccountKey`, `RoleKey`, `CompositeRoleKey`, `generateMnemonicWords`, `validateMnemonic`, `generateRandomSeed`, `joinMnemonicWords`, `mnemonicToWords` |
| `indexer-client` | `@midnight-ntwrk/wallet-sdk-indexer-client` | Indexer API client | Indexer connection utilities |
| `node-client` | `@midnight-ntwrk/wallet-sdk-node-client` | Node RPC client | Node connection utilities |
| `prover-client` | `@midnight-ntwrk/wallet-sdk-prover-client` | Proof server client | Prover connection utilities |
| `runtime` | `@midnight-ntwrk/wallet-sdk-runtime` | Runtime for wallet variants | Runtime orchestration |
| `shielded-wallet` | `@midnight-ntwrk/wallet-sdk-shielded` | Shielded (private) wallet variant | `ShieldedWallet` |
| `unshielded-wallet` | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | Unshielded (transparent) wallet variant | `UnshieldedWallet`, `createKeystore`, `PublicKey` |
| `utilities` | `@midnight-ntwrk/wallet-sdk-utilities` | Domain-agnostic utilities | Common operations and types |

> **Common mistake:** `createKeystore` and `PublicKey` are exported from `@midnight-ntwrk/wallet-sdk-unshielded-wallet`, not from `address-format`. The shielded wallet package is `@midnight-ntwrk/wallet-sdk-shielded` (not `shielded-wallet`).

---

## HD Key Derivation

HD (Hierarchical Deterministic) wallets derive an entire tree of cryptographic keys from a single master seed. The wallet SDK follows the BIP-32 derivation standard with BIP-39 mnemonic encoding.

### Roles

The `Roles` constant defines five key roles:

| Role | Value | Description | Used in standard construction? |
|---|---|---|---|
| `NightExternal` | `0` | External NIGHT receive keys | Yes |
| `NightInternal` | `1` | Internal NIGHT change keys | No (reserved) |
| `Dust` | `2` | DUST token keys | Yes |
| `Zswap` | `3` | Shielded transfer (Zswap) keys | Yes |
| `Metadata` | `4` | Metadata signing keys | No (reserved) |

Standard wallet construction uses three roles: `NightExternal` (0), `Dust` (2), and `Zswap` (3).

### Derivation Path

```
m / 44' / 2400' / {account}' / {role} / {index}
```

| Segment | Value | Meaning |
|---|---|---|
| `m` | — | Master key root |
| `44'` | Hardened | BIP-44 purpose (multi-account hierarchy) |
| `2400'` | Hardened | Midnight coin type (registered in SLIP-44) |
| `{account}'` | Hardened | Account index (0-based) |
| `{role}` | Unhardened | Role from the table above (0-4) |
| `{index}` | Unhardened | Key index within the role (0-based) |

The apostrophe (`'`) marks hardened derivation, which prevents child keys from being used to derive parent keys.

> **See also:** [key-derivation.md](key-derivation.md) for the full derivation flow with code examples and result type handling.

---

## Addresses and Bech32m Encoding

### What is Bech32m?

Bech32m is an improved address encoding format (BIP-350) that provides built-in error detection. Midnight uses Bech32m for all on-chain addresses with the `mn` prefix.

### Address Format

All Midnight addresses follow the pattern:

```
mn_{type}_{network}{encoded_data}
```

- **Prefix:** Always `mn`
- **Type segment:** Identifies the address kind (e.g., `addr`, `shield-addr`, `dust`)
- **Network segment:** Identifies the network (omitted for mainnet; e.g., `devnet`, `testnet`)
- **Encoded data:** Bech32m-encoded payload

Example (unshielded, devnet): `mn_addr_devnet1qpz...`

### Address Types

| Type | Bech32m type segment | Class | Key data |
|---|---|---|---|
| Unshielded | `addr` | `UnshieldedAddress` | 32-byte public key |
| Shielded | `shield-addr` | `ShieldedAddress` | Coin public key + encryption public key (concatenated) |
| DUST | `dust` | `DustAddress` | BLS scalar (SCALE-encoded bigint) |

### Network Binding

Addresses are network-bound. Encoding and decoding require a `NetworkId`. Decoding an address with a mismatched network throws an error:

```
Expected devnet address, got testnet one
```

The special `mainnet` symbol (exported as `mainnet` from `address-format`) represents the mainnet network, and mainnet addresses omit the network segment entirely.

> **See also:** [wallet-construction.md](wallet-construction.md) for how addresses are derived during wallet setup.

---

## Common Type Lookups

| Type | Package | Description |
|---|---|---|
| `FacadeState` | `@midnight-ntwrk/wallet-sdk-facade` | Composite state combining shielded, unshielded, and dust wallet states with pending transactions |
| `SyncProgress` | `@midnight-ntwrk/wallet-sdk-abstractions` | Tracks blockchain sync status. Has `isStrictlyComplete()` (gap = 0) and `isCompleteWithin(maxGap?)` (default gap = 50 blocks) methods |
| `ProtocolVersion` | `@midnight-ntwrk/wallet-sdk-abstractions` | Branded `bigint` via Effect `Brand.nominal<ProtocolVersion>()`. Represents the protocol version with range checking utilities |
| `BalancingRecipe` | `@midnight-ntwrk/wallet-sdk-facade` | Union of `FinalizedTransactionRecipe`, `UnboundTransactionRecipe`, and `UnprovenTransactionRecipe` |
| `UtxoWithMeta` | `@midnight-ntwrk/wallet-sdk-facade` | UTXO with metadata (`ctime` and `registeredForDustGeneration` flag). The facade re-exports this as the public type |
| `WalletState` | `@midnight-ntwrk/wallet-sdk-abstractions` | Branded `string` via Effect `Brand.nominal<WalletState>()`. Serialized wallet state for persistence |
| `ZswapSecretKeys` | `@midnight-ntwrk/ledger-v8` | Secret keys for shielded (Zswap) operations. From the ledger package, not the wallet SDK |
| `DustSecretKey` | `@midnight-ntwrk/ledger-v8` | Secret key for DUST operations. From the ledger package, not the wallet SDK |
| `PublicKey` | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | Object containing `publicKey` (SignatureVerifyingKey), `addressHex` (UserAddress), and `address` (Bech32m string). Created via `PublicKey.fromKeyStore()` |

> **See also:** [state-and-balances.md](state-and-balances.md) for how `FacadeState` and `SyncProgress` are used in practice. [transactions.md](transactions.md) for `BalancingRecipe` usage.
