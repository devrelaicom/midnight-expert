---
name: midnight-node:node-validator
description: This skill should be used when the user asks about running a Midnight validator end-to-end — generating validator session keys, becoming a permissioned (federated) or registered (staked) candidate, how the committee is selected via the D-parameter and Ariadne, committee rotation per Cardano epoch, producing blocks with --validator, and testing a validator locally with the mock main-chain follower. Covers "how do I run a validator", "become a block producer", "permissioned vs registered candidate", "validator committee selection", "validator not producing blocks", and "register as a Midnight validator".
version: 0.1.0
---

# Running a Midnight Validator

End-to-end operator journey: provision keys → join a candidate pool → get selected into the committee by Ariadne → produce blocks.

This skill **owns** the candidate model and committee-selection narrative. Operational flags live in `midnight-node:node-operations`; key provisioning details are in `midnight-node:node-configuration` → `references/validator-keys.md`; the full committee-selection deep-dive is in `references/committee-and-candidates.md` (this skill's own reference file). For the local Docker stack see `midnight-tooling:devnet`.

---

## Journey Overview

```text
1. Provision keys
   AURA_SEED_FILE  (Sr25519 / aura)
   GRANDPA_SEED_FILE (Ed25519 / gran)
   CROSS_CHAIN_SEED_FILE (ECDSA / crch)
          │
          ▼
2. Join a candidate pool
   ┌──────────────────┬──────────────────────────────┐
   │ Permissioned     │ Registered                   │
   │ (federated)      │ (staked)                     │
   │ declared in      │ posted as Cardano UTXO;      │
   │ chain config     │ read via main-chain follower  │
   └──────────────────┴──────────────────────────────┘
          │
          ▼
3. Ariadne selection (once per Cardano epoch)
   D-parameter (num_permissioned, num_registered)
   from pallet_system_parameters
          │
          ▼
4. Committee stored in pallet_session_validator_management
   current_committee_storage() / next_committee_storage()
          │
          ▼
5. Block production
   midnight-node --validator
   (AURA assigns slots to committee members)
```

---

## Step 1 — Validator Keys

Midnight validators require exactly **three** session keys. BEEFY is NOT a fourth key — it is commented out with a TODO in `SessionKeys` (`runtime/src/lib.rs:221-228`) and is not provisioned at `node-1.0.0`.

| Key | Algorithm | KeyTypeId | Env var | Purpose |
|-----|-----------|-----------|---------|---------|
| AURA | Sr25519 | `aura` | `AURA_SEED_FILE` | Block-slot assignment and authoring |
| GRANDPA | Ed25519 | `gran` | `GRANDPA_SEED_FILE` | BFT finality voting |
| CROSS_CHAIN | ECDSA (secp256k1) | `crch` | `CROSS_CHAIN_SEED_FILE` | Partner-chain cross-chain message signing |

Sources: `runtime/src/lib.rs:162,183`; `partner-chains/toolkit/partner-chains-cli/src/keystore.rs:19-26`.

```bash
# Generate seed files (one per key type in production)
midnight-node key generate --scheme sr25519   # AURA
midnight-node key generate --scheme ed25519   # GRANDPA
midnight-node key generate --scheme ecdsa     # CROSS_CHAIN

# Dev shortcut — all three from the same dev path
echo "//Alice" > /tmp/alice-seed
AURA_SEED_FILE=/tmp/alice-seed \
GRANDPA_SEED_FILE=/tmp/alice-seed \
CROSS_CHAIN_SEED_FILE=/tmp/alice-seed \
CFG_PRESET=dev midnight-node --validator
```

For full key-generation options, `author_insertKey` / `author_rotateKeys` RPC calls, and production security guidance, see `midnight-node:node-configuration` → `references/validator-keys.md`.

---

## Step 2 — Become a Candidate

There are two distinct candidate pools. A node must appear in at least one pool to be eligible for committee selection.

| Pool | Declaration | Source |
|------|-------------|--------|
| **Permissioned** (federated) | Chain config file (`permissioned-candidates-config.json`), parsed into `PermissionedCandidatesConfig` / `chainspec_permissioned_candidates_config` | `node/src/cfg/chain_spec_cfg/mod.rs:87` |
| **Registered** (staked) | Cardano transaction posted to `committee_candidate_address`; read each epoch from db-sync by `CandidatesDataSourceImpl` | `node/src/cfg/chain_spec_cfg/mod.rs:93` |

**Key point:** candidate registration for the staked pool is a **Cardano-side / partner-chains framework action**, not a Midnight node extrinsic. The midnight-node binary contains no `register_candidate` extrinsic — it only *reads* registrations from the Cardano chain via the main-chain follower.

For the full candidate-pool mechanics, weight calculation, and Ariadne inputs, see `references/committee-and-candidates.md`.

---

## Step 3 — Committee Selection

Once per Cardano epoch the runtime selects the next committee using Ariadne.

**D-parameter** `(num_permissioned, num_registered)` controls how many seats each pool gets. It is authoritative in `pallet_system_parameters` storage (`pallets/system-parameters/src/lib.rs:86`).

```rust
// runtime/src/lib.rs:541-549
fn select_authorities_optionally_overriding(
    mut input: AuthoritySelectionInputs,
    sidechain_epoch: ScEpochNumber,
) -> Option<BoundedVec<CommitteeMember<CrossChainPublic, SessionKeys>, MaxAuthorities>> {
    let d_parameter = SystemParameters::get_d_parameter();
    input.d_parameter.num_permissioned_candidates = d_parameter.num_permissioned_candidates;
    input.d_parameter.num_registered_candidates   = d_parameter.num_registered_candidates;
    select_authorities(Sidechain::genesis_utxo(), input, sidechain_epoch)
}
```

The function **overrides** the D-parameter in the inherent data with the live on-chain value, then forwards to `select_authorities` from the partner-chains framework. Ariadne v2 blends the two pools with weighted proportional selection, backfilling empty pools.

| D-parameter value | Effect |
|------------------|--------|
| `(N, 0)` | Fully federated — permissioned candidates only |
| `(0, N)` | Fully staked — registered candidates only |
| `(P, R)` | Mixed committee of size P+R |

To update the D-parameter via on-chain governance, see `midnight-node:node-governance`.

---

## Step 4 — Committee Rotation

`pallet_session_validator_management` (aliased `SessionCommitteeManagement` at `runtime/src/lib.rs:934`) stores the active and pending committees.

| Storage | Description | Source |
|---------|-------------|--------|
| `current_committee_storage()` | Active committee for the current epoch | `runtime/src/lib.rs:1594` |
| `next_committee_storage()` | Pre-computed committee for the next epoch, or `None` | `runtime/src/lib.rs:1597` |

Rotation timing: `ValidatorManagementSessionManager` promotes `next_committee` → `current_committee` at each Cardano epoch boundary and increments `pallet_session::pallet::CurrentIndex`. A committee computed for epoch N takes effect at epoch N+1 for AURA/GRANDPA authority lists.

For the full rotation flow and `SessionValidatorManagementApi` runtime API, see `references/committee-and-candidates.md`.

---

## Step 5 — Produce Blocks

Start the node with `--validator` to activate block production. The AURA consensus assigns each slot to a committee member by rotating through the AURA public keys in the current committee list.

```bash
CFG_PRESET=preview midnight-node \
  --validator \
  --name "my-validator"
```

The node must have:
- All three seed files resolved (AURA, GRANDPA, CROSS_CHAIN)
- Membership in the current committee (check via `current_committee_storage()`)
- Sufficient peers and stable uptime

For `--validator` flag details, monitoring, and diagnostic RPC calls, see `midnight-node:node-operations`. For AURA slot assignment and GRANDPA finality internals, see `midnight-node:node-architecture` → `references/consensus-and-finality.md`.

---

## Local Validator Testing (Mock Main-Chain Follower)

To run a full validator committee locally without a Cardano node or db-sync instance, enable the mock main-chain follower in `midnight.toml`:

```toml
use_main_chain_follower_mock = true
mock_registrations_file = "/path/to/mock-registrations.json"
```

| Config key | Type | Required when |
|------------|------|---------------|
| `use_main_chain_follower_mock` | `bool` | — (default `false`) |
| `mock_registrations_file` | path string | `use_main_chain_follower_mock = true` |

Source: `node/src/cfg/midnight_cfg/mod.rs:45-49`; validation at lines 116-119.

`mock_registrations_file` is a JSON file that substitutes for Cardano registration UTXOs. It supplies the `AuthoritySelectionDataSourceMock` used by the inherent provider.

For the full mock data-source mechanics, see `references/committee-and-candidates.md` → Data Sources section. For local stack management, see `midnight-tooling:devnet`.

---

## Troubleshooting

| Symptom | Likely cause | First action |
|---------|-------------|--------------|
| Node not appearing in committee | Not in a candidate pool, or D-parameter leaves no seats for that pool | Verify pool membership; check D-parameter via `midnight-node:node-governance` |
| In candidate pool but never selected | D-parameter `(num_permissioned, num_registered)` = 0 for your pool | Update D-parameter — see `midnight-node:node-governance` |
| In committee but not producing blocks | AURA key not loaded, or committee slot assignment mismatch | Verify `AURA_SEED_FILE`; check AURA pubkey matches committee entry; see `midnight-node:node-operations` |
| Registration not seen by node | Main-chain follower behind, or Cardano-side registration not yet stable | Check db-sync sync status; verify `block_stability_margin` setting; see `midnight-node:node-configuration` |
| Mock follower: node fails to start | `mock_registrations_file` not set when `use_main_chain_follower_mock = true` | Set `mock_registrations_file` in config |

---

## References

| Name | Description | When used |
|------|-------------|-----------|
| `references/committee-and-candidates.md` | Deep-dive: two candidate pools, D-parameter struct, Ariadne v2 algorithm, committee storage, rotation timing, live vs mock data sources | Investigating selection failures, understanding weight and backfill logic, reading committee storage |

## Cross-References

| Skill / Resource | Relevance |
|-----------------|-----------|
| `midnight-node:node-configuration` → `references/validator-keys.md` | Generating, inserting, and rotating AURA, GRANDPA, and CROSS_CHAIN keys; `author_insertKey` / `author_rotateKeys` RPC |
| `midnight-node:node-operations` | `--validator` flag, monitoring, diagnostic RPC commands, troubleshooting block production |
| `midnight-node:node-governance` | Updating the D-parameter on-chain via governance extrinsics |
| `midnight-node:node-architecture` → `references/consensus-and-finality.md` | AURA slot assignment, GRANDPA finality, BEEFY pallet configuration |
| `midnight-node:node-architecture` → `references/cardano-integration.md` | Main-chain follower wiring, db-sync PostgreSQL setup, inherent data provider pipeline |
| `midnight-tooling:devnet` | Starting and stopping the full local Docker stack (node + indexer + proof server) |
