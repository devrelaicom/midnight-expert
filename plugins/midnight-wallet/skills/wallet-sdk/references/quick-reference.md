# Wallet SDK Quick Reference

Fast lookup tables for the Midnight Wallet SDK. Every claim in this file is verified against the wallet SDK source code.

---

## Package Map

The wallet SDK is split into focused packages under the `@midnight-ntwrk` scope. A **meta-package** (`@midnight-ntwrk/wallet-sdk` v1.0.0) re-exports all sub-packages through named sub-paths so you can depend on a single package.

### Meta-package sub-paths (`@midnight-ntwrk/wallet-sdk`)

| Sub-path | Wraps |
|---|---|
| `.` (root) | All packages combined |
| `./address-format` | `@midnight-ntwrk/wallet-sdk-address-format` |
| `./capabilities` | `@midnight-ntwrk/wallet-sdk-capabilities` |
| `./dust` | `@midnight-ntwrk/wallet-sdk-dust-wallet` |
| `./facade` | `@midnight-ntwrk/wallet-sdk-facade` |
| `./hd` | `@midnight-ntwrk/wallet-sdk-hd` |
| `./proving` | `@midnight-ntwrk/wallet-sdk-prover-client` (proving surface) |
| `./shielded` | `@midnight-ntwrk/wallet-sdk-shielded` |
| `./testing` | Testing utilities (across packages) |
| `./unshielded` | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` |

Example: `import { WalletFacade } from '@midnight-ntwrk/wallet-sdk/facade'`

### Individual packages

| Package directory | npm name | Sub-exports | Purpose | Key exports |
|---|---|---|---|---|
| `abstractions` | `@midnight-ntwrk/wallet-sdk-abstractions` | — | Core interfaces and domain types | `WalletState`, `WalletSeed`, `SyncProgress`, `ProtocolVersion`, `ProtocolState`, `NetworkId`, `SerializedTransaction`, `TransactionHistoryStorage` |
| `address-format` | `@midnight-ntwrk/wallet-sdk-address-format` | — | Bech32m address encoding/decoding | `MidnightBech32m`, `ShieldedAddress`, `UnshieldedAddress`, `DustAddress`, `Bech32mCodec`, `ShieldedCoinPublicKey`, `ShieldedEncryptionPublicKey` |
| `capabilities` | `@midnight-ntwrk/wallet-sdk-capabilities` | `./balancer`, `./submission`, `./pendingTransactions`, `./proving`, `./simulation` | Wallet capability definitions and service factories | Capability interfaces; see `capabilities-deep-dive.md` |
| `dust-wallet` | `@midnight-ntwrk/wallet-sdk-dust-wallet` | `./v1` | DUST token wallet variant | `DustWallet` |
| `facade` | `@midnight-ntwrk/wallet-sdk-facade` | — | High-level wallet API | `WalletFacade`, `FacadeState`, `BalancingRecipe`, `Clock`, `systemClock`, `TermsAndConditions`, `FetchTermsAndConditionsConfiguration` |
| `hd` | `@midnight-ntwrk/wallet-sdk-hd` | — | HD key derivation | `HDWallet`, `Roles`, `AccountKey`, `RoleKey`, `CompositeRoleKey`, `generateMnemonicWords`, `validateMnemonic`, `generateRandomSeed`, `joinMnemonicWords`, `mnemonicToWords` |
| `indexer-client` | `@midnight-ntwrk/wallet-sdk-indexer-client` | `./effect` | Indexer API client | Indexer connection utilities; `./effect` exposes the raw Effect-ts API |
| `node-client` | `@midnight-ntwrk/wallet-sdk-node-client` | `./effect`, `./testing` | Node RPC client | Node connection utilities; `./effect` for Effect-ts API, `./testing` for test stubs |
| `prover-client` | `@midnight-ntwrk/wallet-sdk-prover-client` | `./effect` | Proof server client | `HttpProverClient`; `./effect` exposes the raw Effect-ts API |
| `runtime` | `@midnight-ntwrk/wallet-sdk-runtime` | `./abstractions` | Runtime for wallet variants | Runtime orchestration; `./abstractions` for runtime interface types |
| `shielded-wallet` | `@midnight-ntwrk/wallet-sdk-shielded` | `./v1` | Shielded (private) wallet variant | `ShieldedWallet`; `./v1` for the v1 implementation |
| `unshielded-wallet` | `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | `./v1` | Unshielded (transparent) wallet variant | `UnshieldedWallet`, `createKeystore`, `PublicKey`; `./v1` for the v1 implementation |
| `utilities` | `@midnight-ntwrk/wallet-sdk-utilities` | `./networking`, `./types`, `./testing` | Domain-agnostic utilities | `ArrayOps`, `BlobOps`, `DateOps`, `EitherOps`, `Fluent`, `HList`, `LedgerOps`, `ObservableOps`, `Poly`, `RecordOps`, `SafeBigInt`; `./networking` for `HttpURL`/`WsURL`; `./types` for type-level utilities; `./testing` for test helpers |

> **Common mistake:** `createKeystore` and `PublicKey` are exported from `@midnight-ntwrk/wallet-sdk-unshielded-wallet`, not from `address-format`. The shielded wallet package is `@midnight-ntwrk/wallet-sdk-shielded` (not `shielded-wallet`).
>
> **Sub-exports:** When importing from a sub-path (e.g. `./effect`), use the full scoped name: `import { ... } from '@midnight-ntwrk/wallet-sdk-node-client/effect'`.

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
| `Clock` | `@midnight-ntwrk/wallet-sdk-facade` | `{ readonly now: () => Date }` — injectable time source for time-sensitive operations. Use `systemClock` (the default) or supply a deterministic clock in tests |
| `TermsAndConditions` | `@midnight-ntwrk/wallet-sdk-facade` | Terms-and-conditions payload type. Fetched via the static `WalletFacade.fetchTermsAndConditions()` method |
| `FetchTermsAndConditionsConfiguration` | `@midnight-ntwrk/wallet-sdk-facade` | Minimal config accepted by `WalletFacade.fetchTermsAndConditions()` |
| `Simulator` | `@midnight-ntwrk/wallet-sdk-capabilities/simulation` | In-process blockchain simulator for testing. Constructed with a `SimulatorConfig`; start with `immediateBlockProducer` for instant finality |
| `SimulatorState` | `@midnight-ntwrk/wallet-sdk-capabilities/simulation` | Read-only snapshot of the simulator's blockchain state (blocks, mempool, etc.) |

> **See also:** [state-and-balances.md](state-and-balances.md) for how `FacadeState` and `SyncProgress` are used in practice. [transactions.md](transactions.md) for `BalancingRecipe` usage. [capabilities-deep-dive.md](capabilities-deep-dive.md) for `Simulator` and `SimulatorState` usage.
