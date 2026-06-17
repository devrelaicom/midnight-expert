# Midnight Node Configuration Reference

Complete configuration key catalog for midnight-node **v1.0.0**. Covers every config field across all six cfg modules, grouped by module, with type, default, and purpose. Sourced from `res/cfg/default.toml` and the struct definitions in `node/src/cfg/**`.

---

## Configuration Layering

The node uses the **[config](https://docs.rs/config)** crate (`Config::builder`). Layers are applied in strict ascending-priority order — later layers win on conflict:

```text
1. res/cfg/default.toml           (built-in defaults, always applied)
2. Preset TOML  ← selected by CFG_PRESET env var
3. Environment variables          (uppercase key names, direct mapping)
4. CLI args / argv                (args/append_args array in SubstrateCfg)
```

Source: `node/src/cfg/mod.rs:419–434` (`get_all_config`).

### The `CFG_PRESET` Mechanism

`CFG_PRESET` is the primary network-selector. It is read directly from the OS environment before the config crate is initialized — only via `std::env::var("CFG_PRESET")`.

```text
CFG_PRESET value   → Preset TOML loaded
────────────────────────────────────────
(unset)            → "dev"  (the default)
dev                → res/cfg/dev.toml
devnet             → res/cfg/devnet.toml
preview            → res/cfg/preview.toml
preprod            → res/cfg/preprod.toml
mainnet            → res/cfg/mainnet.toml
guardnet           → res/cfg/guardnet.toml
qanet              → res/cfg/qanet.toml
perfnet            → res/cfg/perfnet.toml
govnet             → res/cfg/govnet.toml
ddosnet            → res/cfg/ddosnet.toml
/path/to/file.toml → loaded as a TOML file path
```

The preset value is stored in `MetaCfg.cfg_preset` (`node/src/cfg/meta_cfg/mod.rs:28`). The default `dev` preset mocks the main-chain follower and uses an undeployed genesis — suitable for local development only.

Source: `node/src/command.rs:322–324`.

### `--chain` vs `CFG_PRESET`

These are separate concerns. `--chain` (a Substrate CLI flag threaded through `SubstrateCfg.chain`) controls the Substrate chain-spec source. It accepts:

| `--chain` value | Behaviour |
|---|---|
| `""` (empty) or omitted | Builds chain spec from `chainspec_*` config keys |
| `local` | Uses built-in undeployed genesis |
| `dev` | Uses built-in undeployed genesis |
| Any other string | Treated as a file path to a JSON chain spec |

Source: `node/src/cfg/mod.rs:108–293` (`load_spec`). Do **not** pass a network name like `preview` to `--chain` — use `CFG_PRESET=preview` instead.

### Environment Variable Mapping

Environment variables are read case-insensitively and mapped directly to config key names (no prefix required). The `config` crate lowercases both the env var name and the config key before matching. Example mappings:

```text
Env var (any case)              → Config key
────────────────────────────────────────────────────────────
DB_SYNC_POSTGRES_CONNECTION_STRING → db_sync_postgres_connection_string
STORAGE_CACHE_SIZE              → storage_cache_size
MEMORY_THRESHOLD                → memory_threshold
SHOW_CONFIG                     → show_config
CFG_PRESET                      → (read separately before config init)
ARGS                            → args  (parsed as shell words)
APPEND_ARGS                     → append_args  (parsed as shell words)
BOOTNODES                       → bootnodes  (parsed as shell words)
MC__FIRST_EPOCH_TIMESTAMP_MILLIS → mc__first_epoch_timestamp_millis
```

Note: `args`, `append_args`, and `bootnodes` are handled by `ShellWordsEnvironment` (`node/src/cfg/shell_words_environment.rs`), which splits the env var value into an array using shell-word parsing before injection.

### `SHOW_CONFIG` — Startup Diagnostic

Set `SHOW_CONFIG=1` (or `show_config = true` in a TOML preset) to print the full configuration, with sources and current values, on startup. Secrets are hidden unless `SHOW_SECRETS=1` is also set.

Source: `node/src/command.rs:130–132`, `node/src/cfg/meta_cfg/mod.rs:31`.

---

## MetaCfg

Config-loader bootstrap parameters. Resolved early — before any preset TOML is loaded — using only `default.toml` plus environment variables.

Source: `node/src/cfg/meta_cfg/mod.rs`

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `cfg_preset` | `CFG_PRESET` | `Option<String>` | `"dev"` (code default) | Selects the network preset TOML; `None` = `dev`; can also be a file path |
| `show_config` | `SHOW_CONFIG` | `bool` | `false` | Print full config to stderr on startup |
| `show_secrets` | `SHOW_SECRETS` | `bool` | `false` | Include secret values in `show_config` output |
| `safe_read_max_size` | `SAFE_READ_MAX_SIZE` | `Option<u64>` | `10485760` (10 MiB) | Maximum file size for config file reads; `None` → use coded default |
| `unsafe_allow_symlinks` | `UNSAFE_ALLOW_SYMLINKS` | `bool` | `false` | Allow symlinks when loading config and key files |

Defaults source: `res/cfg/default.toml:11–13,57`, `node/src/cfg/validated_file.rs:18`.

---

## MidnightCfg

Parameters specific to Midnight — Cardano chain follower, database, caching, and monitoring integrations.

Source: `node/src/cfg/midnight_cfg/mod.rs`

### Chain State

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `wipe_chain_state` | `WIPE_CHAIN_STATE` | `bool` | `false` | Wipe the Substrate chain state on startup |

Source: `res/cfg/default.toml:9`.

### Main-Chain Follower (Ariadne)

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `use_main_chain_follower_mock` | `USE_MAIN_CHAIN_FOLLOWER_MOCK` | `bool` | `false` | Replace the real Cardano follower with a mock; required for `dev` preset |
| `mock_registrations_file` | `MOCK_REGISTRATIONS_FILE` | `Option<String>` | unset | Path to mock registrations JSON; **required** when `use_main_chain_follower_mock = true` |

Validation: if `use_main_chain_follower_mock = false`, then `db_sync_postgres_connection_string`, `cardano_security_parameter`, `cardano_active_slots_coeff`, and `block_stability_margin` must all be set. Source: `node/src/cfg/midnight_cfg/mod.rs:109–137`.

### Cardano Epoch Parameters

These describe the Cardano main chain's epoch geometry. Required when the follower is not mocked. The `mc__` prefix in the TOML key maps to a double-underscore in the serde rename.

| Key (TOML) | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `mc__first_epoch_timestamp_millis` | `MC__FIRST_EPOCH_TIMESTAMP_MILLIS` | `u64` | `1666656000000` | Unix epoch timestamp (ms) of Cardano epoch 0 |
| `mc__first_epoch_number` | `MC__FIRST_EPOCH_NUMBER` | `u32` | `0` | First Cardano epoch number observed |
| `mc__epoch_duration_millis` | `MC__EPOCH_DURATION_MILLIS` | `u64` | `86400000` (1 day) | Duration of a Cardano epoch in ms |
| `mc__first_slot_number` | `MC__FIRST_SLOT_NUMBER` | `u64` | `0` | Slot number corresponding to `first_epoch_timestamp_millis` |
| `mc__slot_duration_millis` | `MC__SLOT_DURATION_MILLIS` | `u64` | `1000` (1 s) | Duration of a Cardano slot in ms |

Source: `res/cfg/default.toml:24–28`.

Mainnet overrides these to match Shelley genesis (`mc__first_epoch_timestamp_millis = 1596059091000`, `mc__first_epoch_number = 208`, `mc__epoch_duration_millis = 432000000`, `mc__first_slot_number = 4492800`). Source: `res/cfg/mainnet.toml`.

### Cardano Sync Parameters

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `cardano_security_parameter` | `CARDANO_SECURITY_PARAMETER` | `Option<u32>` | `432` | Number of Cardano blocks constituting "finality"; affects candidate registration window |
| `cardano_active_slots_coeff` | `CARDANO_ACTIVE_SLOTS_COEFF` | `Option<f64>` | `0.05` | Fraction of Cardano slots that produce blocks (used in epoch config derivation) |
| `block_stability_margin` | `BLOCK_STABILITY_MARGIN` | `Option<u32>` | `10` | Extra block margin added to stability calculations |

Source: `res/cfg/default.toml:20–22`. Mainnet and preprod override `cardano_security_parameter` to `2160`.

### Database Connection

| Key | Env var | Type | Default | Notes |
|---|---|---|---|---|
| `db_sync_postgres_connection_string` | `DB_SYNC_POSTGRES_CONNECTION_STRING` | `Option<String>` | unset | PostgreSQL connection string for db-sync; **secret** — hidden in `show_config` output; required when follower is not mocked |
| `allow_non_ssl` | `ALLOW_NON_SSL` | `bool` | `false` | Controls PostgreSQL TLS mode (see table below) |
| `ssl_root_cert` | `SSL_ROOT_CERT` | `Option<String>` | unset | Path to PEM CA certificate for PostgreSQL TLS verification |

SSL mode selection (`node/src/main_chain_follower.rs:423–430`):

| `allow_non_ssl` | `ssl_root_cert` | `PgSslMode` | Security |
|---|---|---|---|
| `true` | any | `Disable` | Plaintext — no encryption |
| `false` | set | `VerifyFull` | Encrypted + certificate validated |
| `false` | unset | `Require` | Encrypted, certificate **not** validated; node logs a warning |

Source: `res/cfg/default.toml:29`, `node/src/main_chain_follower.rs:419–433`.

### Ledger Cache

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `storage_cache_size` | `STORAGE_CACHE_SIZE` | `usize` | `10000` | Ledger storage trie cache size in **number of nodes** (not bytes); `0` = unlimited (risk of OOM) |

This is a config-only key. There is no `--db-cache` flag. The default of `10000` is derived from `DEFAULT_CACHE_SIZE` in the `midnight-ledger` crate. Source: `res/cfg/default.toml:46`, `node/src/cfg/midnight_cfg/mod.rs:85`.

### Validator Key Files

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `aura_seed_file` | `AURA_SEED_FILE` | `Option<String>` | unset | Path to AURA seed file (phrase, hex, or SS58) |
| `grandpa_seed_file` | `GRANDPA_SEED_FILE` | `Option<String>` | unset | Path to GRANDPA seed file |
| `cross_chain_seed_file` | `CROSS_CHAIN_SEED_FILE` | `Option<String>` | unset | Path to cross-chain signing seed file |
| `federated_authority_config_file` | `FEDERATED_AUTHORITY_CONFIG_FILE` | `Option<String>` | unset | Path to federated authority config JSON (council and technical committee addresses) |

See `references/validator-keys.md` for seed format details.

### Prometheus Push Metrics

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `prometheus_push_endpoint` | `PROMETHEUS_PUSH_ENDPOINT` | `Option<String>` | unset | Remote-write endpoint URL (Thanos, Cortex, Mimir, etc.); if unset, only pull endpoint is exposed |
| `prometheus_push_interval_secs` | `PROMETHEUS_PUSH_INTERVAL_SECS` | `Option<u64>` | unset (code default `15`) | Interval in seconds between metric pushes |
| `prometheus_push_job_name` | `PROMETHEUS_PUSH_JOB_NAME` | `Option<String>` | unset (code default `"midnight-node"`) | `job` label on pushed metrics |

Source: `node/src/cfg/midnight_cfg/mod.rs:94–107`.

---

## SubstrateCfg

Wraps Substrate's `RunCmd` by assembling an argv array. Most Substrate behaviour is configured by embedding standard Substrate flags in `args`.

Source: `node/src/cfg/substrate_cfg/mod.rs`

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `argv` | `ARGV` | `Vec<String>` | `[]` | **Deprecated.** Use `args`. Validated to be empty — non-empty triggers an error. |
| `args` | `ARGS` | `Vec<String>` | `[]` | Substrate CLI flags passed as a shell-word array (do not include binary name) |
| `append_args` | `APPEND_ARGS` | `Vec<String>` | `[]` | Appended to `args` after any preset-supplied args |
| `base_path` | `BASE_PATH` | `Option<String>` | unset | Substrate `--base-path`; overridden by `--base-path` in `args` |
| `node_key_file` | `NODE_KEY_FILE` | `Option<String>` | unset | Path to file containing the libp2p node key (preferred over `--node-key` in args) |
| `chain` | `CHAIN` | `Option<String>` | unset | Substrate `--chain` value; see the `--chain` vs `CFG_PRESET` table above |
| `validator` | `VALIDATOR` | `bool` | `false` | Enable validator mode (`--validator` flag) |
| `bootnodes` | `BOOTNODES` | `Vec<MultiaddrWithPeerId>` | `[]` | Additional bootnodes; appended to any provided via `args` |
| `trie_cache_size` | `TRIE_CACHE_SIZE` | `Option<usize>` | `1073741824` (1 GiB) | Substrate trie cache size in bytes; preset default overrides the Substrate default of 67108864 (64 MiB) |

Source: `res/cfg/default.toml:49,51–54`, `node/src/cfg/substrate_cfg/mod.rs:24–49`.

The `trie_cache_size` default of **1073741824** is set in `default.toml` (line 49) and overrides the Substrate upstream default of 64 MiB. A `--trie-cache-size` flag in `args` takes precedence, except when set to the Substrate upstream default value (a known edge case; see `substrate_cfg/mod.rs:91–95`).

---

## MemoryMonitorCfg

OOM-prevention monitor. Spawns an essential background task that polls available memory and shuts the node down gracefully before the OS kills it.

Source: `node/src/cfg/memory_monitor_cfg/mod.rs`, `node/src/memory_monitor.rs`

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `memory_threshold` | `MEMORY_THRESHOLD` | `u64` | `0` | **Required available memory in MiB.** Node shuts down if available memory drops below this floor. `0` = monitoring disabled. |
| `memory_polling_period` | `MEMORY_POLLING_PERIOD` | `u32` | `1` | Polling interval in seconds; `0` = monitoring disabled |

Source: `res/cfg/default.toml:33–34`.

`memory_threshold` is a **floor in MiB of free memory**, not a percentage and not a usage cap. Available memory is read from (in order of preference on Linux): cgroup v2 (`memory.max`/`memory.current`), cgroup v1 (`memory.limit_in_bytes`/`memory.usage_in_bytes`), then `/proc/meminfo` `MemAvailable`. Memory monitoring is not supported on non-Linux platforms (silently disabled with a warning).

Source: `node/src/memory_monitor.rs:17–24,93–117`.

---

## StorageMonitorParamsCfg

Disk-space monitor. A duplicate of Substrate's `StorageMonitorParams` driven by env vars instead of CLI flags.

Source: `node/src/cfg/storage_monitor_params_cfg/mod.rs`

| Key | Env var | Type | Default | Purpose |
|---|---|---|---|---|
| `threshold` | `THRESHOLD` | `u64` | `512` | Required available disk space in MiB on the DB storage path; `0` = disabled |
| `polling_period` | `POLLING_PERIOD` | `u32` | `5` | Polling interval in seconds |

Source: `res/cfg/default.toml:37–38`. Note: these key names are short (`threshold`, `polling_period`) — not `storage_threshold`.

---

## ChainSpecCfg

File paths consumed when building a custom ("live") chain spec. All keys are `Option<String>` and default to unset. They are all-or-nothing: if any one is set, all required keys must be set (validated by `all_required`).

Source: `node/src/cfg/chain_spec_cfg/mod.rs`

| Key | Env var | Purpose |
|---|---|---|
| `chainspec_name` | `CHAINSPEC_NAME` | Human-readable network name (e.g. `"Midnight devnet"`) |
| `chainspec_id` | `CHAINSPEC_ID` | Machine-readable network ID (e.g. `"midnight_devnet"`) |
| `chainspec_chain_type` | `CHAINSPEC_CHAIN_TYPE` | Substrate chain type: `"local"`, `"development"`, `"live"` |
| `chainspec_genesis_state` | `CHAINSPEC_GENESIS_STATE` | Path to pre-built genesis state (`.mn` binary) |
| `chainspec_genesis_block` | `CHAINSPEC_GENESIS_BLOCK` | Path to pre-built genesis block (`.mn` binary) |
| `chainspec_pc_chain_config` | `CHAINSPEC_PC_CHAIN_CONFIG` | Path to partner-chains config JSON (contains `genesis_utxo`) |
| `chainspec_cnight_genesis` | `CHAINSPEC_CNIGHT_GENESIS` | Path to CNight genesis config JSON ("CNight Generates Dust") |
| `chainspec_ics_config` | `CHAINSPEC_ICS_CONFIG` | Path to Illiquid Circulation Supply config JSON |
| `chainspec_reserve_config` | `CHAINSPEC_RESERVE_CONFIG` | Path to reserve observation config JSON |
| `chainspec_federated_authority_config` | `CHAINSPEC_FEDERATED_AUTHORITY_CONFIG` | Path to federated authority config JSON (council + technical committee) |
| `chainspec_system_parameters_config` | `CHAINSPEC_SYSTEM_PARAMETERS_CONFIG` | Path to system parameters config JSON |
| `chainspec_permissioned_candidates_config` | `CHAINSPEC_PERMISSIONED_CANDIDATES_CONFIG` | Path to permissioned candidates config JSON |
| `chainspec_registered_candidates_addresses` | `CHAINSPEC_REGISTERED_CANDIDATES_ADDRESSES` | Path to registered candidates addresses JSON |
| `chainspec_message_config` | `CHAINSPEC_MESSAGE_CONFIG` | **Optional.** Path to genesis remark message config JSON; if unset, no `System::remark` is added to genesis |

The `dev` preset uses `chainspec_chain_type = "local"` and synthetic dev-mode values. Live network presets (`devnet`, `preview`, `mainnet`, etc.) set `chainspec_chain_type = "live"`. See `references/chain-spec-and-presets.md` for the full chain-spec and preset treatment.

Source: `res/cfg/dev.toml`, `res/cfg/devnet.toml`, `node/src/cfg/chain_spec_cfg/mod.rs`.

---

## Preset Quick-Reference

Each `CFG_PRESET` value selects a TOML file from `res/cfg/`. Key per-preset differences:

| Preset | `use_main_chain_follower_mock` | `cardano_security_parameter` | Notes |
|---|---|---|---|
| `dev` (default) | `true` | — (mocked) | In-process dev node; undeployed genesis; `--dev` in args |
| `devnet` | `false` | 432 (inherited) | Docker devnet; `chain-spec.json` from `res/devnet/` |
| `preview` | `false` | 432 (inherited) | Testnet; `chain-spec-raw.json` from `res/preview/` |
| `preprod` | `false` | `2160` | Cardano preprod testnet parameters |
| `mainnet` | `false` | `2160` | Production; Shelley epoch config |
| `guardnet` / `qanet` / `perfnet` / `govnet` / `ddosnet` | `false` | 432 (inherited) | Internal test networks |

Source: `res/cfg/*.toml`.

---

## Cross-references

- Chain-spec files and per-network presets: `references/chain-spec-and-presets.md`
- Validator key files (AURA, GRANDPA, cross-chain seed formats): `references/validator-keys.md`
- Local devnet Docker Compose setup: `midnight-tooling:devnet`
- Proof server configuration: `midnight-tooling:proof-server`
