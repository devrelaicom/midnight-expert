# Chain Spec and Network Presets

The node uses a two-level configuration for network selection: a **TOML preset** selects the environment, and a set of **JSON genesis files** supplies the per-network identity and on-chain parameters. These two layers are independent; knowing how both work avoids the most common mis-configuration (`--chain preview` silently resolving to a missing file path).

## The 11 Configuration Presets

All presets live in `res/cfg/` at the repository root (`res/src/lib.rs:25` defines `CFG_PATH = "res/cfg/"`). At `node-1.0.0` there are exactly 11 TOML files:

| Preset name | `chainspec_name` | `chainspec_id` | `chain_type` | Purpose |
|---|---|---|---|---|
| `default` | _(base layer only — no name/id)_ | _(none)_ | _(none)_ | Supplies default values layered under every other preset; never used alone |
| `dev` | `Midnight Undeployed` | `midnight_undeployed` | `local` | Local development; mocks the main-chain follower; passes `--dev` and archive-pruning flags; points to undeployed genesis |
| `devnet` | `Midnight devnet` | `midnight_devnet` | `live` | Internal shared development network anchored to Cardano pre-production |
| `ddosnet` | `Midnight Ddosnet` | `midnight_ddosnet` | `live` | DDoS-resistance testing network |
| `govnet` | `Midnight GovNet` | `midnight_govnet` | `live` | Governance feature testing network |
| `guardnet` | `Midnight Guardnet` | `midnight_guardnet` | `live` | Security / guardian node testing network |
| `mainnet` | `Midnight Mainnet` | `midnight` | `live` | Production mainnet (Cardano mainnet epoch params) |
| `perfnet` | `Midnight Perfnet` | `midnight_perfnet` | `live` | Performance / load testing network |
| `preprod` | `Midnight Preprod` | `midnight_preprod` | `live` | Pre-production staging anchored to Cardano pre-production |
| `preview` | `Midnight Preview` | `midnight_preview` | `live` | Public testnet anchored to Cardano preview |
| `qanet` | `Midnight QANet` | `midnight_qanet` | `live` | QA regression network |

Sources: `res/cfg/*.toml` (all 11 files read at `node-1.0.0`).

`default.toml` is always loaded first by `Cfg::get_all_config` (`node/src/cfg/mod.rs:427`); the chosen preset is then layered on top, overriding only the keys it sets. `list_configs()` in `res/src/lib.rs:42–57` explicitly excludes `default` from the enumeration of selectable presets.

## `CFG_PRESET` vs `--chain`: How Network Selection Actually Works

### `CFG_PRESET` — the correct knob

The active preset is read from the environment variable `CFG_PRESET`. The default value is `"dev"`.

```rust
// node/src/command.rs:322-324
fn get_cfg_preset() -> String {
    std::env::var("CFG_PRESET").unwrap_or_else(|_| "dev".to_string())
}
```

`MetaCfg` deserialization picks up this value through `Cfg::get_env_source()`, which wraps `config::Environment::default()` (`node/src/cfg/mod.rs:360–365`). `CfgPreset::load_config` then calls `get_config(name)` in `res/src/lib.rs:59–75`, which reads `res/cfg/<name>.toml` from disk.

```bash
# Run the node against the preview testnet
CFG_PRESET=preview ./midnight-node

# Run a local development node (default if CFG_PRESET is unset)
CFG_PRESET=dev ./midnight-node
```

### `--chain` — a Substrate flag with a narrow contract

`--chain` is a Substrate `RunCmd` flag. The node implements `load_spec` as part of `SubstrateCli for Cfg` (`node/src/cfg/mod.rs:104`). Its match arms are:

```rust
// node/src/cfg/mod.rs:108-293
let maybe_chain_spec = match id {
    "" => {
        // Deployed network: reads all chainspec_* keys and builds a CustomNetwork
        chain_config(network)
    },
    "local" | "dev" => chain_config(UndeployedNetwork),   // built-in undeployed genesis
    path => crate::chain_spec::ChainSpec::from_json_file(  // treats id as a file path
        std::path::PathBuf::from(path)
    )…,
};
```

| `--chain` value | Result |
|---|---|
| _(omitted / `""`)_ | Reads `chainspec_*` env vars from the active preset; builds a `CustomNetwork` |
| `local` | Uses the built-in `UndeployedNetwork` genesis (same as `CFG_PRESET=dev` without custom config) |
| `dev` | Same as `local` — resolves to `UndeployedNetwork` |
| Any other string | Treated as a **file path** to a chain-spec JSON; fails if the file does not exist |

**Consequence:** `--chain preview` does not select the `preview` preset. It looks for a file named `preview` in the working directory and fails. To run against the preview testnet, set `CFG_PRESET=preview` and omit `--chain` (or pass `--chain ""`).

The `chain_id` passed to `load_spec` is derived from `run_cmd.shared_params().chain_id(run_cmd.shared_params().is_dev())` at `node/src/command.rs:190`. When `--chain` is not passed and `--dev` is not set, `chain_id` is the empty string `""`, which routes to the deployed-network branch that reads all `chainspec_*` config keys.

## `UndeployedNetwork` — the Local / Dev Built-in

`UndeployedNetwork` is a hard-coded Rust struct defined in `res/src/networks/definitions.rs:25`. It embeds the genesis files at compile time via `include_bytes!`:

```rust
// res/src/networks/definitions.rs:25-53
pub struct UndeployedNetwork;
impl MidnightNetwork for UndeployedNetwork {
    fn name(&self) -> &str { "undeployed1" }
    fn id(&self)   -> &str { "undeployed" }
    fn genesis_state(&self) -> &[u8] {
        include_bytes!("../../genesis/genesis_state_undeployed.mn")
    }
    fn genesis_block(&self) -> &[u8] {
        include_bytes!("../../genesis/genesis_block_undeployed.mn")
    }
    fn chain_type(&self) -> sc_service::ChainType { sc_service::ChainType::Local }
    fn initial_authorities(&self) -> Vec<InitialAuthorityData> {
        vec![InitialAuthorityData::new_from_uri("//Alice")]
    }
    fn cnight_genesis(&self) -> CNightGenesis {
        serde_json::from_str(…include_bytes!("../../dev/cnight-config.json")…).unwrap()
    }
    …
}
```

`UndeployedNetwork` does **not** require any `chainspec_*` env vars; all data is baked into the binary. It is selected by `--chain local` or `--chain dev` at the `load_spec` level, and also indirectly by `CFG_PRESET=dev` (via `dev.toml`'s `args = ["--dev", …]` which causes `is_dev()` to return true).

Deployed presets (`devnet`, `preview`, `mainnet`, etc.) all use `chainspec_chain_type = "live"` and require the full set of `chainspec_*` env vars to be populated — either directly or by loading the preset TOML.

## Genesis JSON Files

When `--chain ""` (or no `--chain`) is used with a deployed preset, `load_spec` reads these JSON files. The config key names come from `ChainSpecCfg` (`node/src/cfg/chain_spec_cfg/mod.rs`); the file names are set by the preset TOML.

| Config key | Typical file name | Rust type | Purpose |
|---|---|---|---|
| `chainspec_pc_chain_config` | `pc-chain-config.json` | `serde_json::Value` | Partner Chain config: contains `chain_parameters.genesis_utxo` identifying the sidechain anchor UTxO on Cardano |
| `chainspec_cnight_genesis` | `cnight-config.json` | `CNightGenesis` | **CNight Generates Dust** genesis — seeds the on-chain DUST generation mechanism by providing the cNIGHT redemption validator address and related Cardano script parameters |
| `chainspec_ics_config` | `ics-config.json` | `IcsConfig` | **Illiquid Circulation Supply** — provides the address and policy ID of the ICS Cardano validator; the node observes this validator to track locked NIGHT supply |
| `chainspec_reserve_config` | `reserve-config.json` | `ReserveConfig` | Reserve contract config — cNIGHT reserve validator address, asset identifier, and initial UTxO snapshot used to bootstrap reserve observation |
| `chainspec_federated_authority_config` | `federated-authority-config.json` | `FederatedAuthorityObservationConfig` | Initial membership of the Council and TechnicalCommittee governance bodies |
| `chainspec_system_parameters_config` | `system-parameters-config.json` | `SystemParametersConfig` | Initial D-parameter (decentralisation) and Terms & Conditions hash |
| `chainspec_permissioned_candidates_config` | `permissioned-candidates-config.json` | `PermissionedCandidatesConfig` | Initial set of permissioned block-producer candidates and their cross-chain keys |
| `chainspec_registered_candidates_addresses` | `registered-candidates-addresses.json` | `RegisteredCandidatesAddresses` | Cardano on-chain addresses used to observe registered candidates |
| `chainspec_genesis_state` | `genesis_state_<network>.mn` | raw bytes | Serialised initial ledger state (hex-encoded in chain spec properties) |
| `chainspec_genesis_block` | `genesis_block_<network>.mn` | raw bytes | Serialised genesis block header |
| `chainspec_message_config` | `message-config.json` | `MessageConfig` | Optional genesis remark; if absent, no System::remark extrinsic is added. Currently only `mainnet.toml` sets this key. |

Sources: `node/src/cfg/chain_spec_cfg/mod.rs:20–100` (field definitions and doc-comments), `node/src/cfg/mod.rs:128–290` (load_spec deserialisation calls).

### `cnight-config.json` vs `reserve-config.json`

These are frequently confused:

- **`cnight-config.json`** (`chainspec_cnight_genesis`, type `CNightGenesis`) — the genesis config for the **CNight Generates Dust** pallet. It points to the Cardano validators that observe cNIGHT redemptions and trigger DUST minting. The "bridge" concept here is the cNIGHT → DUST conversion mechanism, not a cross-chain token bridge in the Wormhole/LayerZero sense.

- **`reserve-config.json`** (`chainspec_reserve_config`, type `ReserveConfig`) — points to the **reserve contract** on Cardano that holds locked cNIGHT tokens, with the UTxO snapshot used to initialise reserve observation. This is the token-reserve aspect of the NIGHT tokenomics, not DUST generation.

Source: `primitives/reserve-observation/src/lib.rs:14–63` (crate-level doc comment + `ReserveConfig` struct).

## `default.toml` — Annotated

```toml
# res/cfg/default.toml (node-1.0.0) — base layer loaded by every preset

wipe_chain_state = false            # if true, deletes chain DB on startup
use_main_chain_follower_mock = false # dev.toml overrides this to true
show_config = false                 # print resolved config to stderr at startup
show_secrets = false                # include secret values in show_config output
validator = false                   # marks this node as a validator

# DO NOT SET THE BASE_PATH HERE — set via Earthfile or CLI --base-path
# base_path = "/node/chain"

# Cardano epoch / slot timing defaults (Cardano pre-production / devnet values)
cardano_security_parameter = 432
cardano_active_slots_coeff = 0.05
block_stability_margin = 10

mc__first_epoch_timestamp_millis = 1666656000000
mc__first_epoch_number = 0
mc__epoch_duration_millis = 86400000      # 1 day (pre-production)
mc__first_slot_number = 0
mc__slot_duration_millis = 1000           # 1 s per slot

allow_non_ssl = false                     # require TLS for external connections

# Memory monitor (MiB); 0 = disabled
memory_threshold = 0
memory_polling_period = 1

# Storage monitor thresholds (GiB free / polling seconds)
threshold = 512
polling_period = 5

# Storage cache (ledger trie nodes); 0 = unlimited (risks OOM)
storage_cache_size = 10000
trie_cache_size = 1073741824              # 1 GiB

argv = []        # full argv replacement (set by substrate_cfg)
args = []        # extra args appended to Substrate RunCmd
append_args = [] # further args appended after args
bootnodes = []

unsafe_allow_symlinks = false             # reject symlinks in config file paths
```

`mainnet.toml` and `preprod.toml` override `cardano_security_parameter = 2160` and the `mc__*` fields to match Cardano mainnet / pre-production epoch timing; all other deployed presets inherit the defaults.

## Loading Order

```text
Config::builder()
  .add_source(default.toml)          ← always first
  .add_source(<CFG_PRESET>.toml)     ← if CFG_PRESET is set; overrides defaults
  .add_source(Environment::default()) ← env vars override TOML; no prefix required
  .add_source(CLI args)               ← highest precedence
```

Source: `Cfg::get_all_config`, `node/src/cfg/mod.rs:419–435`.

`SHOW_CONFIG=1` (or `show_config = true` in TOML) prints the fully resolved config to stderr at startup, including which source each value came from — useful for debugging layering issues.

## Cross-references

- `references/configuration-reference.md` — full list of all `MidnightCfg`, `SubstrateCfg`, and `MetaCfg` keys with types and defaults, including the env-var mapping for `CFG_PRESET`, `SHOW_CONFIG`, and `show_secrets`
- `core-concepts:tokenomics` — NIGHT/DUST dual-token model and the cNIGHT → DUST redemption mechanism described by `cnight-config.json`
