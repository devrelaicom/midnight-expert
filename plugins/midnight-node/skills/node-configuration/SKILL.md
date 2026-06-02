---
name: midnight-node:node-configuration
description: This skill should be used when the user asks about configuring a Midnight node, including CLI flags, environment variables, TOML presets, chain spec files, network selection (qanet, preview, preprod, perfnet, devnet), validator key setup (AURA seed, GRANDPA seed, BEEFY key, cross-chain seed), Substrate pruning and RPC flags, or debugging configuration with SHOW_CONFIG.
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
SHOW_CONFIG=1 midnight-node --chain preview
```

## Key Parameters

| Parameter | Env Var / Config Key | Default | Description |
|-----------|---------------------|---------|-------------|
| `validator` | `--validator` | `false` | Run as a block-producing validator node |
| `cardano_security_parameter` | Config file | Network-specific | Cardano security parameter (k) for finality assumptions |
| `block_stability_margin` | Config file | Network-specific | Number of blocks before a Cardano block is considered stable |
| `ssl_root_cert` | Config file | (optional) | Path to the SSL root certificate for Cardano db-sync PostgreSQL connections. When set, connections use full certificate + hostname validation (`PgSslMode::VerifyFull`); when absent, connections are encrypted but unverified (`PgSslMode::Require`) |
| `allow_non_ssl` | Config file | `false` | **Deprecated and ignored.** Plaintext database connections are no longer permitted — all connections now use TLS. The flag is retained for backward compatibility and will be removed in a future release |
| `memory_threshold` | Config file | (optional) | Memory usage percentage that triggers graceful shutdown |
| `storage_cache_size` | `--db-cache` | `1024` | Database cache size in MiB |
| `trie_cache_size` | `--trie-cache-size` | `67108864` (64 MiB) | State trie cache size in bytes |
| `use_main_chain_follower_mock` | Config file | `false` | Use mock Cardano mainchain follower (for dev/testing) |

## Validator Keys

Validator nodes require four cryptographic keys, each loaded from a seed file via environment variable.

| Env Var | Key Type | Algorithm | Purpose |
|---------|----------|-----------|---------|
| `AURA_SEED_FILE` | Block production | Sr25519 | AURA slot assignment and block authoring |
| `GRANDPA_SEED_FILE` | Finality | Ed25519 | GRANDPA finality voting |
| `CROSS_CHAIN_SEED_FILE` | Partner chain | — | Cross-chain message signing |
| `BEEFY_KEY_FILE` | Bridge | ECDSA (secp256k1) | BEEFY finality proofs for light clients |

Each environment variable points to a file containing the seed phrase or secret key material.

```bash
export AURA_SEED_FILE=/keys/aura.seed
export GRANDPA_SEED_FILE=/keys/grandpa.seed
export CROSS_CHAIN_SEED_FILE=/keys/cross-chain.seed
export BEEFY_KEY_FILE=/keys/beefy.key
```

## Available Networks

| Network | Chain Spec | Purpose |
|---------|-----------|---------|
| `local` / `dev` | Built-in | Local development and testing |
| `qanet` | `res/cfg/qanet.toml` | Internal QA testing |
| `preview` | `res/cfg/preview.toml` | Public preview network (testnet) |
| `preprod` | `res/cfg/preprod.toml` | Pre-production network |
| `perfnet` | `res/cfg/perfnet.toml` | Performance testing network |
| `undeployed` | `res/cfg/undeployed.toml` | Default for local devnet |

## Chain Spec Files

The node loads multiple configuration files that define the chain's genesis state and operational parameters.

| File | Purpose |
|------|---------|
| `pc-chain-config.json` | Partner chain configuration — sidechain parameters, Cardano connection |
| `cnight-config.json` | cNIGHT token bridging configuration |
| `ics-config.json` | Inter-chain staking configuration |
| `federated-authority-config.json` | Initial governance body membership (Council + TechnicalCommittee) |
| `system-parameters-config.json` | Initial system parameters — D-parameter, Terms & Conditions |

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
midnight-node --chain preview

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
midnight-node --chain preview --state-pruning archive --blocks-pruning archive

# Pruned node — keep last 1000 states
midnight-node --chain preview --state-pruning 1000
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
midnight-node --chain preview \
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

## Cross-References

- `midnight-node:node-architecture` — Runtime pallets and consensus mechanisms configured by these parameters
- `midnight-node:node-operations` — Operational guidance for running configured nodes
- `midnight-tooling:devnet` — Local development stack that auto-configures node settings
