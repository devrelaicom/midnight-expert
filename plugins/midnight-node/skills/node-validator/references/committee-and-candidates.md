# Committee Selection and Candidate Model

Each Midnight epoch the block-producing committee is assembled from two distinct candidate pools according to the D-parameter. The node reads pool membership from Cardano (via db-sync PostgreSQL) or from a local mock file, then the runtime's Ariadne algorithm blends the two pools and stores the result in pallet storage.

---

## Two Candidate Pools

| Pool | How declared | Where consumed | Source |
|------|-------------|----------------|--------|
| **Permissioned** (federated) | Chain config file `permissioned-candidates-config.json` — parsed into `PermissionedCandidatesConfig` | Genesis genesis and each `AuthoritySelectionInputs` inherent | `res/src/networks/mod.rs:122-126`, `node/src/cfg/chain_spec_cfg/mod.rs:87` |
| **Registered** (staked) | Cardano transaction at `committee_candidate_address` (from `registered-candidates-addresses.json`); read each epoch via db-sync PostgreSQL | Each `AuthoritySelectionInputs` inherent | `res/src/networks/mod.rs:116-118`, `node/src/cfg/chain_spec_cfg/mod.rs:93` |

### Permissioned candidates

`PermissionedCandidatesConfig` (`res/src/networks/mod.rs:122`) holds:
- `permissioned_candidates_policy_id` — Cardano policy ID used to identify the on-chain token that carries the permissioned candidate list
- `initial_permissioned_candidates` — seed committee for genesis

The config file path is set in `ChainSpecCfg.chainspec_permissioned_candidates_config` (`node/src/cfg/chain_spec_cfg/mod.rs:87`). At chain-spec build time the file is deserialised with `serde_json` and stored in `MainChainScripts.permissioned_candidates_policy_id` (`res/src/networks/mod.rs:138-146`).

Permissioned candidates have **uniform weight 1** in the Ariadne selection; staking is not involved (`partner-chains/toolkit/committee-selection/selection/src/ariadne_v2.rs:35-36`).

### Registered candidates

`RegisteredCandidatesAddresses` (`res/src/networks/mod.rs:116`) holds a single field:
- `committee_candidates_address` — Cardano address where candidate registration UTXOs are posted

The file path is set in `ChainSpecCfg.chainspec_registered_candidates_addresses` (`node/src/cfg/chain_spec_cfg/mod.rs:93`). At runtime `CandidatesDataSourceImpl` reads registration UTXOs from db-sync and attaches `StakeDelegation` (ADA delegated to the candidate's stake pool). That delegation amount becomes the Ariadne **weight** for proportional selection (`partner-chains/toolkit/committee-selection/authority-selection-inherents/src/filter_invalid_candidates.rs:120`; `Weight = u128` defined at `partner-chains/toolkit/committee-selection/selection/src/lib.rs:24`).

> **Cardano-side note.** The act of _registering_ a candidate — posting the registration UTXO and acquiring stake delegation — is a Cardano / partner-chains framework operation. The midnight-node tree does not contain any extrinsic for candidate registration; it only **consumes** registrations by querying them from db-sync. Cross-ref `midnight-node:node-architecture` → `references/cardano-integration.md` for the follower setup.

---

## The D-parameter — Selection Ratios

`DParameter` (`partner-chains/toolkit/sidechain/domain/src/lib.rs:1165-1170`):

```rust
pub struct DParameter {
    /// Expected number of permissioned candidates selected for a committee
    pub num_permissioned_candidates: u16,
    /// Expected number of registered candidates selected for a committee
    pub num_registered_candidates: u16,
}
```

`(num_permissioned_candidates, num_registered_candidates)` sets the *target committee composition*. The total committee size equals their sum. A value of `(3, 0)` means a fully federated committee; `(1, 5)` means mostly staked.

The D-parameter is authoritative in **`pallet_system_parameters` storage** (not read from Cardano at this layer — the mainchain D-parameter policy ID is zeroed in `res/src/networks/mod.rs:136`). On-chain governance updates it; selection always reads the live storage value. See `midnight-node:node-governance` for how the parameter is stored and updated.

---

## Ariadne Selection — `select_authorities_optionally_overriding`

```rust
// runtime/src/lib.rs:541-549
fn select_authorities_optionally_overriding(
    mut input: AuthoritySelectionInputs,
    sidechain_epoch: ScEpochNumber,
) -> Option<BoundedVec<CommitteeMember<CrossChainPublic, SessionKeys>, MaxAuthorities>> {
    let d_parameter = SystemParameters::get_d_parameter();
    input.d_parameter.num_permissioned_candidates = d_parameter.num_permissioned_candidates;
    input.d_parameter.num_registered_candidates = d_parameter.num_registered_candidates;
    select_authorities(Sidechain::genesis_utxo(), input, sidechain_epoch)
}
```

The function **overrides** whatever D-parameter arrived in the inherent data with the live on-chain value from `pallet_system_parameters`, then forwards to `select_authorities` from the `authority_selection_inherents` crate (`runtime/src/lib.rs:28`).

### What `select_authorities` does (partner-chains framework)

`select_authorities` (`partner-chains/toolkit/committee-selection/authority-selection-inherents/src/select_authorities.rs:16-30`) calls the inner `select_candidates` function, which:

1. Filters invalid permissioned candidates (bad keys, etc.) — `filter_invalid_permissioned_candidates`
2. Filters and validates registered candidates — `filter_trustless_candidates_registrations`, verifying Cardano stake pool signature and requiring positive `StakeDelegation`
3. Builds a 32-byte `random_seed` from the Cardano epoch nonce XOR-summed with the partner-chain epoch number (`select_authorities.rs:73-80`)
4. Calls `selection::ariadne_v2::select_authorities` with `registered_seats = d.num_registered_candidates`, `permissioned_seats = d.num_permissioned_candidates`

### Ariadne v2 blending

`ariadne_v2::select_authorities` (`partner-chains/toolkit/committee-selection/selection/src/ariadne_v2.rs:23-58`):

```text
total_seats = permissioned_seats + registered_seats

if both pools non-empty:
    registered_selected  = weighted_with_guaranteed_assignment(registered, registered_seats, rng)
    permissioned_selected = weighted_with_guaranteed_assignment(permissioned, permissioned_seats, rng)
    committee = registered_selected ++ permissioned_selected

else if registered pool empty:
    committee = weighted_with_guaranteed_assignment(permissioned, total_seats, rng)   # backfill

else (permissioned pool empty):
    committee = weighted_with_guaranteed_assignment(registered, total_seats, rng)     # backfill

committee.shuffle(rng)
```

`weighted_with_guaranteed_assignment` gives each candidate at least `floor(E_i)` seats, where `E_i = weight_i / total_weight * seats`. Remaining seats are filled pseudo-randomly using `ChaCha20Rng`. Permissioned candidates have weight 1; registered candidates use their ADA stake delegation as weight.

The `genesis_utxo` argument passed from `Sidechain::genesis_utxo()` is used to domain-separate registration signatures, preventing cross-chain replay.

---

## Committee Storage and the `SessionValidatorManagementApi`

The selected committee is held in `pallet_session_validator_management` (aliased `SessionCommitteeManagement` at `runtime/src/lib.rs:934`).

| Storage / method | Description | Source |
|-----------------|-------------|--------|
| `current_committee_storage()` | Returns `(ScEpochNumber, Vec<CommitteeMember>)` for the active epoch | `runtime/src/lib.rs:1594` |
| `next_committee_storage()` | Returns the pre-computed committee for the next epoch, or `None` if not yet set | `runtime/src/lib.rs:1597` |
| `get_next_unset_epoch_number()` | The earliest epoch for which no committee has been computed yet | `runtime/src/lib.rs:1600` |
| `calculate_committee(inputs, epoch)` | Off-chain dry-run via the runtime API | `runtime/src/lib.rs:1603` |
| `get_main_chain_scripts()` | Returns the Cardano addresses/policy IDs in use | `runtime/src/lib.rs:1606` |

These are exposed through the `SessionValidatorManagementApi` runtime API (`runtime/src/lib.rs:1587-1608`).

### Rotation timing

A new committee is submitted as an **inherent** once per Cardano epoch transition. `ValidatorManagementSessionManager` (from the partner-chains session pallet, wired in at `runtime/src/lib.rs:952-956`) promotes `next_committee` → `current_committee` and increments `pallet_session::pallet::CurrentIndex`. The comment at line 953 is explicit:

> "Only stub implementation of `pallet_session` should be wired. Partner Chains `session_manager ValidatorManagementSessionManager` writes to `pallet_session::pallet::CurrentIndex`."

Epoch boundaries in tests (`check_aura_authorities_rotation`, `check_grandpa_authorities_rotation`, `check_cross_chain_committee_rotation` at `runtime/src/lib.rs:1732-1838`) confirm that a committee set in epoch N takes effect at epoch N+1 for AURA/GRANDPA authority lists, and that the new committee can be set as late as the first block of the new epoch (though this extends the session by one block).

---

## Data Sources — Live vs Mock

### Live (production) path

`create_cached_data_sources` (`node/src/main_chain_follower.rs:165`) builds the `DataSources` struct used by the inherent provider. The `authority_selection` field is a `CandidatesDataSourceImpl` (`node/src/main_chain_follower.rs:211-212`):

```rust
let candidates_data_source =
    CandidatesDataSourceImpl::new(candidates_pool, midnight_metrics_opt.clone())
        .await?;
```

`CandidatesDataSourceImpl` (`primitives/mainchain-follower/src/data_source/candidates_data_source/mod.rs:55-63`) holds a `PgPool` (db-sync PostgreSQL). It implements `AuthoritySelectionDataSource`:
- `get_ariadne_parameters` — fetches the permissioned-candidates token UTXO from db-sync for the given Cardano epoch; returns a stub `DParameter{0,0}` because the live D-parameter comes from `pallet_system_parameters`, not the mainchain (`mod.rs:88-90`)
- `get_candidates` — fetches registration UTXOs and joins with `get_stake_distribution` to attach ADA delegation

The live path requires:
- `db_sync_postgres_connection_string`
- `cardano_security_parameter`
- `cardano_active_slots_coeff`
- `block_stability_margin`

(`node/src/cfg/midnight_cfg/mod.rs:124-136`)

### Mock path (local / testing)

Set `use_main_chain_follower_mock = true` in `midnight.toml` to bypass db-sync entirely. When the mock is active, `mock_registrations_file` **must** also be set (`node/src/cfg/midnight_cfg/mod.rs:44-49`, validation at lines 116-119).

```rust
// node/src/main_chain_follower.rs:93-96
let authority_selection_data_source_mock = AuthoritySelectionDataSourceMock {
    registrations_data: MockRegistrationsConfig::read_registrations(
        &cfg.mock_registrations_file.ok_or(missing("mock_registrations_file"))?,
    )?,
};
```

`MockRegistrationsConfig` (from `partner_chains_mock_data_sources`) reads a JSON file that substitutes for the Cardano registration UTXOs. This allows running a full local validator committee without a Cardano node or db-sync instance.

| Config key | Type | Required when |
|------------|------|---------------|
| `use_main_chain_follower_mock` | `bool` | — (default `false`) |
| `mock_registrations_file` | `Option<String>` (path) | `use_main_chain_follower_mock = true` |
| `db_sync_postgres_connection_string` | `Option<String>` (secret) | mock disabled |
| `cardano_security_parameter` | `Option<u32>` | mock disabled |
| `cardano_active_slots_coeff` | `Option<f64>` | mock disabled |
| `block_stability_margin` | `Option<u32>` | mock disabled |

Source: `node/src/cfg/midnight_cfg/mod.rs:45-136`.

---

## Selection Flow Summary

```text
Cardano epoch boundary detected
    │
    ▼
AriadneInherentDataProvider assembles AuthoritySelectionInputs {
    d_parameter:              (from mainchain — overridden below)
    permissioned_candidates:  Vec<PermissionedCandidateData>  ← from db-sync / mock
    registered_candidates:    Vec<CandidateRegistrations>     ← from db-sync / mock
    epoch_nonce:              Cardano epoch nonce
}
    │
    ▼  (block author includes inherent)
select_authorities_optionally_overriding(input, sc_epoch)
    │ overrides d_parameter from pallet_system_parameters storage
    │
    ▼
authority_selection_inherents::select_authorities(genesis_utxo, input, sc_epoch)
    │ filters invalid candidates
    │ builds ChaCha20 seed from (epoch_nonce, sc_epoch)
    │
    ▼
ariadne_v2::select_authorities(registered_seats, permissioned_seats, ...)
    │ weighted proportional blend with guaranteed floor seats
    │ final shuffle
    │
    ▼
SessionCommitteeManagement::next_committee_storage ← written
    │
    ▼ (epoch N+1 boundary)
ValidatorManagementSessionManager promotes next → current
pallet_session::CurrentIndex incremented
```

---

## Cross-references

- `midnight-node:node-governance` — D-parameter storage in `pallet_system_parameters` and the governance extrinsic to update it
- `midnight-node:node-architecture` → `references/cardano-integration.md` — mainchain follower wiring, db-sync PostgreSQL setup, and how inherent data providers attach to the block-authoring pipeline
- `midnight-node:node-configuration` → `references/validator-keys.md` — AURA, GRANDPA, and CROSS_CHAIN key material required for committee membership
