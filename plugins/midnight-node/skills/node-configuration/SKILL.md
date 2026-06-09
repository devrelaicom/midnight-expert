---
name: midnight-node:node-configuration
description: This skill should be used when the user asks about configuring a Midnight node, including CLI flags, environment variables, TOML presets, chain spec files, network selection (qanet, preview, preprod, perfnet, devnet), validator key setup (AURA seed, GRANDPA seed, cross-chain seed), Substrate pruning and RPC flags, or debugging configuration with SHOW_CONFIG.
version: 0.1.0
---

# Node Configuration

Complete reference for configuring the Midnight node. Configuration follows a layered hierarchy where each level overrides the previous.

## Configuration Hierarchy

```text
Defaults (compiled into binary)
    ↓ overridden by
Presets (res/cfg/*.toml)
    ↓ overridden by
Environment Variables
    ↓ overridden by
CLI Arguments
```

Use `SHOW_CONFIG=1` when starting the node to print the fully resolved configuration to stdout for debugging.

```bash
SHOW_CONFIG=1 CFG_PRESET=preview midnight-node
```

## Key Parameters

| Parameter | Env Var / Config Key | Default | Description |
|-----------|---------------------|---------|-------------|
| `validator` | `--validator` | `false` | Run as a block-producing validator node |
| `cardano_security_parameter` | Config file | Network-specific (testnet `default.toml`: `432`) | Cardano security parameter (k) for finality assumptions. Required when the mainchain follower is not mocked |
| `block_stability_margin` | Config file | Network-specific (testnet `default.toml`: `10`) | Number of blocks before a Cardano block is considered stable. Required when the mainchain follower is not mocked |
| `ssl_root_cert` | Config file | (optional) | Path to the SSL root certificate for Cardano db-sync PostgreSQL connections. When set, connections use full certificate + hostname validation (`PgSslMode::VerifyFull`); when absent, connections are encrypted but unverified (`PgSslMode::Require`) |
| `allow_non_ssl` | Config file | `false` | When `true`, the Cardano db-sync PostgreSQL connection runs **plaintext** with no TLS (`PgSslMode::Disable`). When `false` (default), the connection uses TLS: `PgSslMode::VerifyFull` if `ssl_root_cert` is set, otherwise `PgSslMode::Require` (encrypted but unverified, with a startup warning). Use `true` only for trusted local/dev databases. |
| `memory_threshold` | Config file | `0` | Required available memory in MiB (a floor). The node gracefully shuts down when available memory drops below it; `0` disables monitoring |
| `storage_cache_size` | Config file | `10000` | Size of the ledger storage cache (number of storage nodes) |
| `trie_cache_size` | `--trie-cache-size` | `1073741824` (1 GiB) | State trie cache size in bytes |
| `use_main_chain_follower_mock` | Config file | `false` | Use mock Cardano mainchain follower (for dev/testing) |

> **Full catalog:** these are the most-used keys. For **every** config key across all cfg modules (meta, midnight, substrate, memory-monitor, storage-monitor, chain-spec) with types, defaults, and the env-var mapping, see `references/configuration-reference.md`.

## Validator Keys

Validator nodes require three cryptographic keys, each loaded from a seed file via environment variable.

| Env Var | Key Type | Algorithm | Purpose |
|---------|----------|-----------|---------|
| `AURA_SEED_FILE` | Block production | Sr25519 | AURA slot assignment and block authoring |
| `GRANDPA_SEED_FILE` | Finality | Ed25519 | GRANDPA finality voting |
| `CROSS_CHAIN_SEED_FILE` | Partner chain | ECDSA (secp256k1) | Cross-chain message signing |

Each environment variable points to a file containing the seed phrase or secret key material.

```bash
export AURA_SEED_FILE=/keys/aura.seed
export GRANDPA_SEED_FILE=/keys/grandpa.seed
export CROSS_CHAIN_SEED_FILE=/keys/cross-chain.seed
```

> **Deep dive:** `references/validator-keys.md` — the KeyTypeIds (`aura`/`gran`/`crch`), the `SessionKeys` struct (BEEFY commented out — so exactly 3 keys), `author_insertKey`/`author_rotateKeys`, and the separate libp2p node-key. For the validator operator journey, see `midnight-node:node-validator`.

## Available Networks

Network/preset selection is via the `CFG_PRESET` environment variable. `local`/`dev` map to the built-in `UndeployedNetwork` via `--chain local|dev`, while `qanet`/`preview`/`preprod`/`perfnet` are `CFG_PRESET` presets (`res/cfg/<name>.toml`). The `--chain` flag only accepts `""`, `local`, or `dev` — anything else is treated as a chain-spec JSON file path.

| Network | Selection | Purpose |
|---------|-----------|---------|
| `local` / `dev` | `--chain local\|dev` (built-in `UndeployedNetwork`) | Local development and testing |
| `qanet` | `CFG_PRESET=qanet` (`res/cfg/qanet.toml`) | Internal QA testing |
| `preview` | `CFG_PRESET=preview` (`res/cfg/preview.toml`) | Public preview network (testnet) |
| `preprod` | `CFG_PRESET=preprod` (`res/cfg/preprod.toml`) | Pre-production network |
| `perfnet` | `CFG_PRESET=perfnet` (`res/cfg/perfnet.toml`) | Performance testing network |

## Chain Spec Files

The node loads multiple configuration files that define the chain's genesis state and operational parameters.

| File | Purpose |
|------|---------|
| `pc-chain-config.json` | Partner chain configuration — sidechain parameters, Cardano connection |
| `cnight-config.json` | CNight Generates Dust — genesis config that seeds DUST generation from cNIGHT at genesis (the Cardano↔Midnight bridge config is a separate file) |
| `ics-config.json` | Illiquid Circulation Supply (ICS) configuration |
| `federated-authority-config.json` | Initial governance body membership (Council + TechnicalCommittee) |
| `system-parameters-config.json` | Initial system parameters — D-parameter, Terms & Conditions |

> **Deep dive:** `references/chain-spec-and-presets.md` — the 11 `res/cfg/*.toml` presets, all genesis JSON files, and why `CFG_PRESET=preview` works while `--chain preview` resolves to a missing file path.

## File Safety and Boot Validation

The node validates the configuration and genesis files it reads on startup. Misconfigured files fail loudly rather than being silently accepted.

| Option / Behavior | Config Key | Default | Description |
|-------------------|------------|---------|-------------|
| Symlink rejection | `unsafe_allow_symlinks` | `false` | Config and genesis files that are symlinks are rejected. Set `true` to allow symlinks (accepting the associated symlink-attack risk) |
| File size limit | `safe_read_max_size` | `10485760` (10 MB) | Maximum size in bytes for a config/genesis file read; larger files are rejected |
| Regular-file check | (automatic) | — | Files that are not regular files (e.g. directories, devices) are rejected |
| Network ID validation | (automatic) | — | On boot the node validates that the genesis state's network ID matches the configured chainspec network ID; a mismatch fails startup with `genesis state network id != configured chainspec network id` |

`show_config` (the `SHOW_CONFIG=1` mechanism above) and `show_secrets` are also meta-configuration keys that control how resolved configuration is displayed on startup.

## Network-Specific Presets

Presets are TOML files in `res/cfg/` that bundle configuration for a specific network. They set Cardano connection parameters, bootnodes, genesis state, and chain identity.

```bash
# Run node with preview preset
CFG_PRESET=preview midnight-node

# Run node with custom chain spec
midnight-node --chain /path/to/custom-chain-spec.json
```

## Substrate CLI Flags

The Midnight node inherits all standard Substrate CLI flags. Key flags for operations:

### Pruning

| Flag | Default | Description |
|------|---------|-------------|
| `--state-pruning` | `256` | Number of recent block states to keep (set `archive` for full state) |
| `--blocks-pruning` | `archive` | Block retention policy |

```bash
# Archive node — keep all state
CFG_PRESET=preview midnight-node --state-pruning archive --blocks-pruning archive

# Pruned node — keep last 1000 states
CFG_PRESET=preview midnight-node --state-pruning 1000
```

### RPC and Networking

| Flag | Default | Description |
|------|---------|-------------|
| `--rpc-external` | disabled | Listen for RPC connections on all interfaces (not just localhost) |
| `--rpc-port` | `9944` | WebSocket RPC port |
| `--rpc-cors` | `localhost` | Allowed CORS origins for RPC |
| `--prometheus-external` | disabled | Expose Prometheus metrics on all interfaces |
| `--prometheus-port` | `9615` | Prometheus metrics port |

```bash
# Expose RPC and Prometheus externally
CFG_PRESET=preview midnight-node \
  --rpc-external --rpc-cors all \
  --prometheus-external
```

### Development Mode

| Flag | Description |
|------|-------------|
| `--dev` | Run in single-node development mode with ephemeral state |
| `--tmp` | Use a temporary database directory (deleted on shutdown) |
| `--alice` / `--bob` | Use pre-defined development accounts for block production |

```bash
# Quick development node
midnight-node --dev --tmp
```

## References

| Name | Description | When used |
|------|-------------|-----------|
| `references/configuration-reference.md` | The complete config-key catalog from `node/src/cfg/**` + `res/cfg/default.toml`: every key with type, default, and the `CFG_PRESET`/env-var layering | When looking up any config key or its default |
| `references/chain-spec-and-presets.md` | The 11 `res/cfg` presets, the genesis JSON files, and the `CFG_PRESET` vs `--chain` selection mechanism | When choosing a network or assembling a chain spec |
| `references/validator-keys.md` | The 3 validator session keys (AURA/GRANDPA/CROSS_CHAIN), KeyTypeIds, `SessionKeys`, key insertion/rotation, and the BEEFY-not-wired status | When provisioning validator keys |

## Cross-References

- `midnight-node:node-architecture` — Runtime pallets and consensus mechanisms configured by these parameters
- `midnight-node:node-operations` — Operational guidance for running configured nodes
- `midnight-node:node-validator` — The validator operator journey that consumes these keys and candidate settings
- `midnight-tooling:devnet` — Local development stack that auto-configures node settings
