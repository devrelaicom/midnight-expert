# Pallet Inventory — node-1.0.0 Runtime

The node-1.0.0 runtime (`spec_version = 001_000_000`) composes **28 pallets** in its `#[frame_support::runtime]` block. This file enumerates every entry with its pallet index, crate name, runtime alias, origin (Midnight-local vs. upstream), and role. For the 8 Midnight-local pallets it also summarises key calls and storage items, sourced from `pallets/*/src/lib.rs`.

> **Version note.** The unreleased 2.0.0-alpha line adds a 29th pallet and raises `spec_version` to `2_000_000`. Everything below is specific to tag `node-1.0.0`.

---

## 28-Pallet Master Table

| Index | Runtime alias | Crate | Origin | Functional group |
|------:|---------------|-------|--------|-----------------|
| 0 | `System` | `frame_system` | Substrate | Core/System |
| 1 | `Timestamp` | `pallet_timestamp` | Substrate | Core/System |
| 2 | `Aura` | `pallet_aura` | Substrate | Consensus |
| 3 | `Grandpa` | `pallet_grandpa` | Substrate | Consensus |
| 4 | `Sidechain` | `pallet_sidechain` | Partner-Chains | Partner-Chains / Session |
| 5 | `Midnight` | `pallet_midnight` | Midnight-local | Midnight-Specific |
| 6 | `MidnightSystem` | `pallet_midnight_system` | Midnight-local | Midnight-Specific |
| 8 | `SessionCommitteeManagement` | `pallet_session_validator_management` | Partner-Chains | Partner-Chains / Session |
| 11 | `NodeVersion` | `pallet_version` | Midnight-local | Core/System |
| 13 | `CNightObservation` | `pallet_cnight_observation` | Midnight-local | Midnight-Specific |
| 15 | `Preimage` | `pallet_preimage` | Substrate | Utility |
| 16 | `MultiBlockMigrations` | `pallet_migrations` | Substrate | Utility |
| 17 | `PalletSession` | `pallet_session` | Substrate | Partner-Chains / Session |
| 18 | `Scheduler` | `pallet_scheduler` | Substrate | Utility |
| 19 | `TxPause` | `pallet_tx_pause` | Substrate | Core/System |
| 21 | `Beefy` | `pallet_beefy` | Substrate | Consensus |
| 22 | `Mmr` | `pallet_mmr` | Substrate | Consensus |
| 23 | `BeefyMmrLeaf` | `pallet_beefy_mmr` | Substrate | Consensus |
| 30 | `Session` | `pallet_partner_chains_session` | Partner-Chains | Partner-Chains / Session |
| 32 | `Bridge` | `pallet_partner_chains_bridge` | Partner-Chains | Partner-Chains / Session |
| 40 | `Council` | `pallet_collective` (Instance1) | Substrate | Governance |
| 41 | `CouncilMembership` | `pallet_membership` (Instance1) | Substrate | Governance |
| 42 | `TechnicalCommittee` | `pallet_collective` (Instance2) | Substrate | Governance |
| 43 | `TechnicalCommitteeMembership` | `pallet_membership` (Instance2) | Substrate | Governance |
| 44 | `FederatedAuthority` | `pallet_federated_authority` | Midnight-local | Governance |
| 45 | `FederatedAuthorityObservation` | `pallet_federated_authority_observation` | Midnight-local | Governance |
| 50 | `SystemParameters` | `pallet_system_parameters` | Midnight-local | Midnight-Specific |
| 51 | `Throttle` | `pallet_throttle` | Midnight-local | Midnight-Specific |

Source: `runtime/src/lib.rs` lines 897–1001 (the `#[frame_support::runtime] mod runtime { … }` block).

**Indices are sparse.** Slots 7, 9, 10, 12, 14, 20, 24–29, 31, 33–39, 46–49 are unoccupied. Commented-out entries for `BlockRewards` (9) and `SafeMode` (20) appear in the source but are not compiled in.

---

## Grouped View

### Core / System (4 pallets)

```text
 0  System          frame_system            — account/nonce/event/block management
 1  Timestamp       pallet_timestamp        — on-chain UNIX millisecond clock
11  NodeVersion     pallet_version          — broadcasts spec_version in block digest
19  TxPause         pallet_tx_pause         — root-gated call-level circuit breaker
```

`TxPause` is wired as `frame_system::Config::BaseCallFilter` (`runtime/src/lib.rs:329`), making it the runtime-wide call filter for all dispatchables.

### Consensus (5 pallets)

```text
 2  Aura            pallet_aura             — slot-based block authorship (sr25519)
 3  Grandpa         pallet_grandpa          — GRANDPA finality (ed25519)
21  Beefy           pallet_beefy            — BEEFY gadget (ecdsa), feeds MMR bridge proofs
22  Mmr             pallet_mmr              — Merkle Mountain Range leaf accumulation
23  BeefyMmrLeaf    pallet_beefy_mmr        — constructs MMR leaves from BEEFY authority sets
```

`BeefyMmrLeaf` must sit after `Session` in block execution order so its leaf's `next_auth_set` refers to the correct block (see inline comment at `runtime/src/lib.rs:967`).

### Partner-Chains / Session (4 pallets)

```text
 4  Sidechain                    pallet_sidechain                       — epoch/slot tracking, Cardano sidechain integration
 8  SessionCommitteeManagement   pallet_session_validator_management    — permissioned-candidate + registered-candidate committee selection
17  PalletSession                pallet_session                         — Substrate session storage (CurrentIndex etc.) — stub only; writes driven by SessionCommitteeManagement
30  Session                      pallet_partner_chains_session          — partner-chains session adapter; wires ValidatorManagementSessionManager
32  Bridge                       pallet_partner_chains_bridge           — Cardano-to-Midnight token bridge ingestion
```

`pallet_session` (index 17) is a stub implementation; the meaningful session logic lives in `pallet_partner_chains_session` (index 30) and `pallet_session_validator_management` (index 8). The `impl_pallet_session_config!` macro call at `runtime/src/lib.rs:395` generates the glue.

### Midnight-Specific (5 pallets)

```text
 5  Midnight          pallet_midnight          — ledger state, transaction submission
 6  MidnightSystem    pallet_midnight_system   — privileged system-transaction execution
13  CNightObservation pallet_cnight_observation — Cardano UTXO observation → DUST minting
50  SystemParameters  pallet_system_parameters — D-parameter + terms-and-conditions governance
51  Throttle          pallet_throttle          — per-account byte/tx rate limiter
```

### Governance (6 pallets)

```text
40  Council                        pallet_collective (Instance1)  — on-chain Council collective (≤10 members, 2/3 approval)
41  CouncilMembership              pallet_membership (Instance1)  — Council member roster management
42  TechnicalCommittee             pallet_collective (Instance2)  — Technical Committee collective (≤10 members, 2/3 approval)
43  TechnicalCommitteeMembership   pallet_membership (Instance2)  — Technical Committee member roster management
44  FederatedAuthority             pallet_federated_authority     — multi-body motion approval/revoke
45  FederatedAuthorityObservation  pallet_federated_authority_observation — main-chain member observation (inherent)
```

### Utility (3 pallets)

```text
15  Preimage             pallet_preimage    — on-chain preimage registration for governance proposals
16  MultiBlockMigrations pallet_migrations  — multi-block runtime migration service (MBM)
18  Scheduler            pallet_scheduler   — on-chain call scheduling
```

---

## Absent Pallets (confirmed zero source hits)

The following pallets are **not** present in node-1.0.0 despite appearing in many Substrate templates:

| Pallet | Why absent |
|--------|-----------|
| `pallet_balances` | Token accounting is handled by the Midnight ledger, not a Substrate fungible-token pallet |
| `pallet_transaction_payment` | Fee flow goes through `pallet_throttle` + ledger DUST; no weight-to-fee conversion pallet |
| `pallet_sudo` | No privileged sudo account; privilege is root origin or collective-governed |
| `pallet_utility` | No batch-call utility; all calls are direct |

Verified by `grep` across `runtime/src/lib.rs` — zero matches.

---

## Midnight-Local Pallets — Detail

### `pallet_midnight` (index 5) — Ledger State & Transaction Submission

Source: `pallets/midnight/src/lib.rs`

**Storage** (`runtime/src/lib.rs:929`):

| Item | Type | Purpose |
|------|------|---------|
| `StateKey` | `StorageValue<Vec<u8>>` | Encoded ledger state root key |
| `ParentTimestamp` | `StorageValue<u64>` | Previous block timestamp (ms) |
| `NetworkId` | `StorageValue<BoundedString>` | Chain network identifier |
| `ConfigurableTransactionSizeWeight` | `StorageValue<Weight>` | Per-byte weight for transactions |
| `ConfigurableOnInitializeWeight` | `StorageValue<Weight>` | Weight budget for `on_initialize` |
| `ConfigurableOnRuntimeUpgradeWeight` | `StorageValue<Weight>` | Weight budget for `on_runtime_upgrade` |
| `MaxSkippedSlots` | `StorageValue<u8>` | Max consecutive skipped slots allowed |

**Key calls** (`pallets/midnight/src/lib.rs:361`):

| Call | Origin | Purpose |
|------|--------|---------|
| `send_mn_transaction` | unsigned/unsigned-validate | Submit a serialised Midnight ledger transaction; unsigned, validated by `validate_unsigned` |
| `set_tx_size_weight` | Root | Update the per-byte weight parameter |

**Runtime API.** `MidnightRuntimeApi` (impl at `runtime/src/lib.rs:1201`) exposes `get_contract_state`, `get_decoded_transaction`, `get_zswap_chain_state`, `get_network_id`, `get_ledger_version`, `get_unclaimed_amount`, `get_ledger_parameters`, `get_transaction_cost`, `get_zswap_state_root`, and `get_ledger_state_root` — all proxied to this pallet.

---

### `pallet_midnight_system` (index 6) — System Transaction Execution

Source: `pallets/midnight-system/src/lib.rs`

**Storage**:

| Item | Type | Purpose |
|------|------|---------|
| `ConfigurableSystemTxWeight` | `StorageValue<Weight>` | Per-byte weight for system transactions |

**Key calls** (`pallets/midnight-system/src/lib.rs:73`):

| Call | Origin | Purpose |
|------|--------|---------|
| `send_mn_system_transaction` | signed | Submit a privileged system transaction (e.g. cNight → DUST conversion events) |

System transactions bypass normal ledger validation. They are constructed by `CNightObservation` and submitted through this pallet's `execute_system_transaction` internal helper.

---

### `pallet_version` (index 11) — Runtime Version Digest

Source: `pallets/version/src/lib.rs`

No dispatchable calls and no on-chain storage. On every `on_initialize`, it deposits a `DigestItem::Consensus(VERSION_ID, spec_version.encode())` log with engine ID `b"MNSV"`. Clients and the indexer read this to confirm the runtime version in effect at each block without querying state.

---

### `pallet_cnight_observation` (index 13) — Cardano UTXO → DUST

Source: `pallets/cnight-observation/src/lib.rs`

**Storage**:

| Item | Type | Purpose |
|------|------|---------|
| `MainChainMappingValidatorAddress` | `StorageValue<BoundedCardanoAddress>` | Cardano address of the mapping-validator contract |
| `MainChainAuthTokenAssetName` | `StorageValue<BoundedVec<u8,32>>` | Asset name of the cNight authentication token |
| `Mappings` | `StorageMap<CardanoRewardAddress → Vec<MappingEntry>>` | cNight registration records |
| `UtxoOwners` | `StorageMap<Hash → DustPublicKeyBytes>` | UTXO → DUST public key mapping |
| `NextCardanoPosition` | `StorageValue<CardanoPosition>` | Watermark of last processed Cardano position |
| `CNightIdentifier` | `StorageValue<…>` | Policy/asset identifier for cNight |
| `CardanoBlockWindowSize` | `StorageValue<u32>` | Rolling observation window (blocks) |
| `CardanoTxCapacityPerBlock` | `StorageValue<u32>` | Max UTXOs processed per block |
| `InherentExecutedThisBlock` | `StorageValue<bool>` | Guard: prevents duplicate inherent per block |

**Key calls** (`pallets/cnight-observation/src/lib.rs:546`):

| Call | Index | Origin | Purpose |
|------|------:|--------|---------|
| `process_tokens` | 0 | None (inherent) | Process a batch of observed Cardano UTXOs; triggers DUST minting via `MidnightSystem` |
| `set_mapping_validator_contract_address` | 2 | Root | Update the Cardano mapping-validator contract address |

This pallet is an **inherent provider** — `process_tokens` is submitted automatically by the block author, not by end users.

---

### `pallet_federated_authority` (index 44) — Multi-Body Motion Governance

Source: `pallets/federated-authority/src/lib.rs`

**Storage**:

| Item | Type | Purpose |
|------|------|---------|
| `Motions` | `StorageMap<Hash → MotionInfo>` | Active governance motions awaiting approval |

**Key calls** (`pallets/federated-authority/src/lib.rs:131`):

| Call | Origin | Purpose |
|------|--------|---------|
| `motion_approve` | Council/TechnicalCommittee collective | Cast approval vote for a motion |
| `motion_revoke` | Council/TechnicalCommittee collective | Revoke approval for a motion |
| `motion_close` | Any | Close and execute (or expire) a completed motion |

Approval requires both `CouncilApproval` and `TechnicalCommitteeApproval` — each a 2/3 `EnsureProportionAtLeast` origin (`runtime/src/lib.rs:806–832`).

---

### `pallet_federated_authority_observation` (index 45) — Main-Chain Member Observation

Source: `pallets/federated-authority-observation/src/lib.rs`

**Storage**:

| Item | Type | Purpose |
|------|------|---------|
| `MainChainCouncilAddress` | `StorageValue<MainchainAddress>` | Cardano address of the on-chain Council NFT |
| `MainChainCouncilPolicyId` | `StorageValue<PolicyId>` | Policy ID of the Council NFT |
| `MainChainTechnicalCommitteeAddress` | `StorageValue<MainchainAddress>` | Cardano address of the Technical Committee NFT |
| `MainChainTechnicalCommitteePolicyId` | `StorageValue<PolicyId>` | Policy ID of the Technical Committee NFT |
| `CouncilMainchainMembers` | `StorageValue<BoundedVec<MainchainMember>>` | Current Council membership observed from Cardano |
| `TechnicalCommitteeMainchainMembers` | `StorageValue<BoundedVec<MainchainMember>>` | Current Technical Committee membership observed from Cardano |
| `InherentExecutedThisBlock` | `StorageValue<bool>` | Guard: prevents duplicate inherent per block |

**Key calls** (`pallets/federated-authority-observation/src/lib.rs:185`):

| Call | Index | Origin | Purpose |
|------|------:|--------|---------|
| `reset_members` | 0 | None (inherent) | Synchronise on-chain membership lists from observed Cardano state |
| `set_council_address` | — | Root | Update `MainChainCouncilAddress` |
| `set_technical_committee_address` | — | Root | Update `MainChainTechnicalCommitteeAddress` |
| `set_council_policy_id` | — | Root | Update `MainChainCouncilPolicyId` |
| `set_technical_committee_policy_id` | — | Root | Update `MainChainTechnicalCommitteePolicyId` |

`reset_members` is an **inherent**; it drives the `pallet_membership` instances that back `Council` and `TechnicalCommittee`.

---

### `pallet_system_parameters` (index 50) — D-Parameter & Terms

Source: `pallets/system-parameters/src/lib.rs`

**Storage**:

| Item | Type | Purpose |
|------|------|---------|
| `TermsAndConditionsStorage` | `StorageValue<TermsAndConditions<Hash>>` | Hash + metadata of current network T&Cs |
| `DParameterStorage` | `StorageValue<(u16, u16)>` | `(num_permissioned_candidates, num_registered_candidates)` — controls committee composition |

**Key calls** (`pallets/system-parameters/src/lib.rs:208`):

| Call | Origin | Purpose |
|------|--------|---------|
| `update_terms_and_conditions` | Root | Set a new terms-and-conditions hash |
| `update_d_parameter` | Root | Adjust the D-parameter for the next epoch's authority selection |

The D-parameter is read by `select_authorities_optionally_overriding` at `runtime/src/lib.rs:542` when `pallet_session_validator_management` selects the next committee.

---

### `pallet_throttle` (index 51) — Per-Account Rate Limiter

Source: `pallets/throttle/src/lib.rs`

**Storage**:

| Item | Type | Purpose |
|------|------|---------|
| `AccountUsage` | `StorageMap<AccountId → UsageStats>` | Rolling byte and transaction counts per account |

`UsageStats` records `{ bytes_used, txs_used, window_start }`. No dispatchable calls — throttle enforcement runs as a `TransactionExtension` (`CheckThrottle`) wired into `TxExtension` at `runtime/src/lib.rs:1020`. Limits (10 MB / 100 txs per `HOURS`-wide window) are set in `runtime/src/lib.rs:861–868`.

---

## Non-Pallet Runtime Crate

`sp_session_validator_management_query` is a **runtime-API / RPC query crate**, not a pallet. It exposes the `SessionValidatorManagementQueryApi` runtime API surface for off-chain tooling to inspect committee state without submitting extrinsics. It has no `pallet_index` entry and no on-chain storage.

---

## Pallet Count

**28 pallets** — indices 0, 1, 2, 3, 4, 5, 6, 8, 11, 13, 15, 16, 17, 18, 19, 21, 22, 23, 30, 32, 40, 41, 42, 43, 44, 45, 50, 51.

Indices are intentionally sparse; there are 28 occupied slots out of a non-contiguous range that reaches 51.

---

## Cross-references

- `midnight-node:node-architecture` — overview skill tying consensus, session, and ledger layers together
- `midnight-node:node-rpc-api` — the RPC surface these pallets expose (including `systemParameters_*` and `sidechain_*` methods)
- `core-concepts:architecture` — Midnight transaction structure, guaranteed/fallible phases, and the privacy model this runtime enforces
- `core-concepts:protocols` — Kachina / Zswap protocol details that `pallet_midnight` applies via `LedgerApi`
- `core-concepts:tokenomics` — NIGHT and DUST token economics; `pallet_cnight_observation` is the minting entry point
- `compact-core:compact-transaction-model` — how Compact circuits map to the `send_mn_transaction` call in `pallet_midnight`
