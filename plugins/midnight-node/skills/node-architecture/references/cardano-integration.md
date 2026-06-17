# Cardano Integration Deep-Dive

The Midnight node is a Cardano partner chain. It follows the Cardano mainchain via `db-sync` and a PostgreSQL read replica rather than a direct peer connection. All cross-chain data — validator candidates, governance membership, cNIGHT UTXO events, and NIGHT bridge transfers — flows through that single PostgreSQL source.

## Architecture Diagram

```text
Cardano Node ──→ db-sync ──→ PostgreSQL ←── Midnight Node
                                              (main chain follower)
                                              ├── CandidatesDataSourceImpl
                                              ├── MidnightCNightObservationDataSourceImpl
                                              ├── FederatedAuthorityObservationDataSourceImpl
                                              └── CachedTokenBridgeDataSourceImpl
```

Each data source opens its own connection pool to the same PostgreSQL instance. Pools are opened concurrently during node start-up. See `node/src/main_chain_follower.rs` for the pool configuration constants (`CANDIDATES_POOL_CFG`, `CNIGHT_OBSERVATION_POOL_CFG`, etc.).

## Main-Chain Follower Mode

| Config key | Type | Default | Meaning |
|------------|------|---------|---------|
| `use_main_chain_follower_mock` | `bool` | `false` | Skip all PostgreSQL data sources; use in-memory mocks instead |
| `mock_registrations_file` | `Option<String>` | — | Required when mock is enabled; path to a registrations JSON file |

Source: `node/src/cfg/midnight_cfg/mod.rs:45-49`

When `use_main_chain_follower_mock = false` (the production path), the validator `main_chain_follower_vars` enforces that `db_sync_postgres_connection_string`, `cardano_security_parameter`, `cardano_active_slots_coeff`, and `block_stability_margin` are all set (`node/src/cfg/midnight_cfg/mod.rs:109-136`).

When `use_main_chain_follower_mock = true`, the node starts `AuthoritySelectionDataSourceMock`, `CNightObservationDataSourceMock`, and `FederatedAuthorityObservationDataSourceMock`; no PostgreSQL connection is opened and `mock_registrations_file` must be supplied (`node/src/main_chain_follower.rs:88-109`).

## PostgreSQL Connection and SSL Modes

The node uses `sqlx::postgres::PgPoolOptions` for every data-source pool. SSL behaviour is controlled by two keys.

| Config key | Type | Default |
|------------|------|---------|
| `allow_non_ssl` | `bool` | `false` |
| `ssl_root_cert` | `Option<String>` | — |

SSL mode selection logic (`node/src/main_chain_follower.rs:423-431`):

| `allow_non_ssl` | `ssl_root_cert` | `PgSslMode` applied | Notes |
|-----------------|-----------------|---------------------|-------|
| `true` | any | `Disable` | Plaintext — no encryption. Not recommended for production. |
| `false` | set | `VerifyFull` | Full mutual TLS; certificate validated against `ssl_root_cert`. |
| `false` | not set | `Require` | Encrypted but no certificate validation (MITM-vulnerable). A warning is logged. |

`db_sync_postgres_connection_string` is tagged `#[doc_tag(secret)]` and is never written to logs or config dumps (`node/src/cfg/midnight_cfg/mod.rs:68-69`).

## Cardano Epoch and Block Stability Parameters

These parameters control how the node interprets the Cardano chain timeline.

| Config key | Type | Default | Meaning |
|------------|------|---------|---------|
| `cardano_security_parameter` | `u32` | `432` | Number of Cardano blocks (`k`) for finality — data older than `k` blocks is considered stable |
| `cardano_active_slots_coeff` | `f64` | `0.05` | Cardano active-slot coefficient `f` (Shelley genesis parameter) |
| `block_stability_margin` | `u32` | `10` | Extra margin on top of `k` used by `DbSyncBlockDataSourceConfig` |

Source: `res/cfg/default.toml:20-22`

These values flow into `DbSyncBlockDataSourceConfig` (`node/src/main_chain_follower.rs:174-184`) and are used by all block data sources to determine which Cardano blocks are safe to consume as finalized input.

## cNIGHT Observation — "CNight Generates Dust"

`pallet_cnight_observation` (`pallets/cnight-observation/src/lib.rs`) observes Cardano UTXOs for cNIGHT token movements and converts them into Midnight ledger system transactions via `LedgerApi::construct_cnight_generates_dust_system_tx`.

The module-level doc comment names the design intent explicitly:

> "This pallet provides mechanisms for tracking all registrations for cNIGHT generates DUST from Cardano, as well as observation of all cNIGHT utxos of valid registrants of cNIGHT generates DUST."

Source: `pallets/cnight-observation/src/lib.rs:15-17`

### Throughput constants

| Constant | Value | Meaning |
|----------|-------|---------|
| `DEFAULT_CARDANO_TX_CAPACITY_PER_BLOCK` | `200` | Max Cardano transactions processed per Midnight block |
| `UTXO_PER_TX_OVERESTIMATE` | `64` | Overestimate factor — each Cardano tx may contain up to this many UTXOs |
| `MAX_UTXO_COUNT` (derived) | `200 × 64 = 12,800` | Worst-case UTXO upper bound used for weight declaration |

Source: `pallets/cnight-observation/src/lib.rs:67-75`

The `process_tokens` inherent enforces `utxo_count <= CardanoTxCapacityPerBlock * UTXO_PER_TX_OVERESTIMATE` and rejects with `TooManyUtxos` if exceeded (`pallets/cnight-observation/src/lib.rs:556-561`). `CardanoTxCapacityPerBlock` and `CardanoBlockWindowSize` are runtime-adjustable storage values, not hard-coded constants; their defaults come from `DEFAULT_CARDANO_TX_CAPACITY_PER_BLOCK = 200` and `INITIAL_CARDANO_BLOCK_WINDOW_SIZE = 1000`.

### cnight-config.json

The chain-spec config key `chainspec_cnight_genesis` points to the "CNight Generates Dust config file" (e.g. `res/devnet/cnight-config.json`). This file provides the `CNightGenesis` struct — the Cardano script addresses, cNIGHT policy ID/asset name, auth token asset name, initial UTXO ownership mappings, and starting `NextCardanoPosition`.

Source: `node/src/cfg/chain_spec_cfg/mod.rs:54-57`

This is **not** the bridge config. The bridge is separately configured via `chainspec_reserve_config` and the ICS bridge (`pallet_partner_chains_bridge`).

### Registration model

A Cardano address can register a Midnight DUST public key by creating a UTXO at the mapping validator contract address on Cardano. The pallet maintains a `Mappings` store: `CardanoRewardAddressBytes → Vec<MappingEntry>`. A registration is considered valid if and only if exactly one mapping entry exists for the address. Multiple entries deregister the holder.

Source: `pallets/cnight-observation/src/lib.rs:361-369`

## NIGHT Bridge — pallet_partner_chains_bridge

The `pallet_partner_chains_bridge` (runtime type alias `Bridge`) handles **NIGHT token transfers from Cardano** initiated by ICS (illiquid circulating supply) contract UTXOs. This is a separate pathway from cNIGHT observation.

```text
parameter_types! {
    pub const BridgeMaxTransfersPerBlock: u32 = 256;
}

impl pallet_partner_chains_bridge::Config for Runtime {
    type MaxTransfersPerBlock = BridgeMaxTransfersPerBlock;
    ...
}
```

Source: `runtime/src/lib.rs:876-894`

The 256 per-block limit applies to incoming NIGHT bridge transfers (ICS → Midnight), not to cNIGHT UTXO observations. The `MidnightTokenTransferHandler` routes each transfer to `LedgerApi::construct_distribute_night_cardano_bridge_system_tx` (user), `construct_distribute_reserve_system_tx` (reserve), or `construct_distribute_treasury_system_tx` (invalid/treasury). Source: `runtime/src/c2m_bridge.rs:28-90`.

## Committee Selection — Ariadne (pallet_session_validator_management)

Validator set rotation is driven by Cardano epochs via `pallet_session_validator_management`. Each epoch, the node reads candidate registrations from PostgreSQL (via `CandidatesDataSourceImpl`) and passes them to `select_authorities_optionally_overriding`, which reads the current D-parameter from `pallet_system_parameters` and calls into the Ariadne selection algorithm.

```rust
// runtime/src/lib.rs:541-550
fn select_authorities_optionally_overriding(
    mut input: AuthoritySelectionInputs,
    sidechain_epoch: ScEpochNumber,
) -> Option<BoundedVec<...>> {
    let d_parameter = SystemParameters::get_d_parameter();
    input.d_parameter.num_permissioned_candidates = d_parameter.num_permissioned_candidates;
    input.d_parameter.num_registered_candidates  = d_parameter.num_registered_candidates;
    select_authorities(Sidechain::genesis_utxo(), input, sidechain_epoch)
}
```

Source: `runtime/src/lib.rs:541-550`

### D-parameter

The D-parameter is a `(u16, u16)` tuple defined in `sidechain_domain`:

```rust
// partner-chains/toolkit/sidechain/domain/src/lib.rs:1165-1170
pub struct DParameter {
    pub num_permissioned_candidates: u16,
    pub num_registered_candidates:  u16,
}
```

| Field | Meaning |
|-------|---------|
| `num_permissioned_candidates` | Slots reserved for permissioned (federated) candidates |
| `num_registered_candidates` | Slots open to registered (staked) candidates |

Source: `partner-chains/toolkit/sidechain/domain/src/lib.rs:1165-1170`

A higher permissioned share makes block production more federated; a higher registered share shifts it toward permissionless. The D-parameter is stored on-chain via `pallet_system_parameters` and is updated through the federated authority governance process.

For D-parameter governance mechanics, query RPC method, and change workflow see `midnight-node:node-governance`. For the candidate model (permissioned vs registered) and the validator operator journey see `midnight-node:node-validator`.

## Governance Sync — pallet_federated_authority_observation

Council and TechnicalCommittee membership is read from Cardano mainchain UTXOs by `pallet_federated_authority_observation`. The pallet stores Cardano script addresses and policy IDs for each body:

| Storage item | Purpose |
|--------------|---------|
| `MainChainCouncilAddress` | Cardano script address managing Council membership |
| `MainChainCouncilPolicyId` | Cardano policy ID for Council auth tokens |
| `MainChainTechnicalCommitteeAddress` | Cardano script address for TechnicalCommittee |
| `MainChainTechnicalCommitteePolicyId` | Policy ID for TechnicalCommittee auth tokens |

Source: `pallets/federated-authority-observation/src/lib.rs:56-70`

On each Midnight block, an inherent produced by `FederatedAuthorityObservationDataSourceImpl` provides the current member sets. The `reset_members` call updates `CouncilMainchainMembers` and `TechnicalCommitteeMainchainMembers`, then signals `CouncilMembershipHandler` and `TechnicalCommitteeMembershipHandler` to propagate the change to `pallet_membership`. Source: `pallets/federated-authority-observation/src/lib.rs:186-260`.

Membership in production is set only via `ResetOrigin = EnsureNone` (inherent). Individual add/remove/swap origins are disabled (`NeverEnsureOrigin`) outside of benchmarks. Source: `runtime/src/lib.rs:723-800`.

For the full two-body governance model, approval thresholds, and motion lifecycle see `midnight-node:node-governance`.

## Cross-References

- `midnight-node:node-governance` — D-parameter governance workflow, Council + TechnicalCommittee model, motion lifecycle, approval thresholds
- `midnight-node:node-validator` — Candidate model, permissioned vs registered validators, committee selection, and the validator operator journey
- `midnight-node:node-configuration` — Full `MidnightCfg` reference, all config keys with types, validation rules, and environment-variable mapping
- `references/pallet-inventory.md` — Full runtime pallet list with indices
