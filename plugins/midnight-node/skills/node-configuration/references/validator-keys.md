# Validator Key Material Reference

Midnight validators use exactly **three** cryptographic session keys loaded from seed files, plus a separate libp2p node-identity key. This document covers the key types, how they are loaded, and how to manage them. All claims are sourced from the `node-1.0.0` tag of `midnight-node`.

---

## The Three Validator Session Keys

| Config key | Env var | Algorithm | KeyTypeId | Purpose |
|------------|---------|-----------|-----------|---------|
| `aura_seed_file` | `AURA_SEED_FILE` | Sr25519 | `aura` | Block production — AURA slot assignment and authoring |
| `grandpa_seed_file` | `GRANDPA_SEED_FILE` | Ed25519 | `gran` | Finality voting — GRANDPA BFT finality gadget |
| `cross_chain_seed_file` | `CROSS_CHAIN_SEED_FILE` | ECDSA (secp256k1) | `crch` | Partner-chain message signing — cross-chain key |

Sources:
- Key definitions (scheme, `key_type`): `partner-chains/toolkit/partner-chains-cli/src/keystore.rs:19–26`
- Env var names: `README.md:280–282` and `node/src/cfg/midnight_cfg/mod.rs:32–42`
- Runtime wiring with KeyTypeId bytes: `node/src/command.rs:218` (`b"aura"`), `233` (`b"gran"`), `248` (`b"crch"`)

### Runtime Key Definitions (source)

```rust
// partner-chains/toolkit/partner-chains-cli/src/keystore.rs:19–26
pub const AURA: KeyDefinition<'static> =
    KeyDefinition { name: "AURA", scheme: "sr25519", key_type: "aura" };

pub const GRANDPA: KeyDefinition<'static> =
    KeyDefinition { name: "Grandpa", scheme: "ed25519", key_type: "gran" };

pub const CROSS_CHAIN: KeyDefinition<'static> =
    KeyDefinition { name: "Cross-chain", scheme: "ecdsa", key_type: "crch" };
```

---

## BEEFY Is NOT a Fourth Session Key

BEEFY (`pallet_beefy`) runs as an active consensus layer and produces compact bridge proofs, but the BEEFY key is **not included in the `SessionKeys` struct** as of `node-1.0.0`. The code is explicit:

```rust
// runtime/src/lib.rs:221–228
impl_opaque_keys! {
    #[derive(MaxEncodedLen, PartialOrd, Ord)]
    pub struct SessionKeys {
        pub aura: Aura,
        pub grandpa: Grandpa,
        // todo: add the beefy
        // pub beefy: Beefy,
    }
}
```

The companion TODO in the CLI confirms:

```rust
// node/src/cli.rs:491–492
fn key_definitions() -> Vec<KeyDefinition<'static>> {
    // TODO: BEEFY(follow up pr)
    vec![AURA, GRANDPA, CROSS_CHAIN]
}
```

Practical effect: the BEEFY gadget uses whatever ECDSA key is in the keystore, but that key is not rotated through the session-key mechanism. Validators configure exactly **three** session keys; there is no BEEFY seed file to provision.

See `references/consensus-and-finality.md` (under `midnight-node:node-architecture`) for the full BEEFY pallet runtime configuration.

---

## SessionKeys Struct

The `SessionKeys` struct is defined in the `opaque` module of the runtime. It drives `impl_opaque_keys!`, which generates the `OpaqueKeys` implementation used by `pallet_session` for key rotation:

```rust
// runtime/src/lib.rs:221–228
impl_opaque_keys! {
    pub struct SessionKeys {
        pub aura: Aura,      // Sr25519
        pub grandpa: Grandpa, // Ed25519
        // beefy NOT wired — see above
    }
}
```

`pallet_session` is wired to use `opaque::SessionKeys`:

```rust
// runtime/src/lib.rs:531–532
type SessionHandler = <opaque::SessionKeys as OpaqueKeys>::KeyTypeIdProviders;
type Keys = opaque::SessionKeys;
```

`CrossChainKey` (the ECDSA/`crch` key) is defined as a *separate* opaque-keys struct rather than a field in `SessionKeys`:

```rust
// runtime/src/lib.rs:256–260
impl_opaque_keys! {
    pub struct CrossChainKey {
        pub account: CrossChainPublic,
    }
}
```

This means the cross-chain key is managed outside `pallet_session`'s rotation cycle and is loaded directly into the keystore from the seed file on each node start.

---

## How Seed Files Are Read at Boot

On startup, `node/src/command.rs` reads each seed-file path from the resolved configuration (`MidnightCfg`), reads the file contents, derives the keypair using the appropriate scheme, and inserts the key directly into the local keystore:

```rust
// node/src/command.rs:208–221 — AURA
if let Some(seed_file) = &cfg.midnight_cfg.aura_seed_file {
    let seed = std::fs::read_to_string(seed_file)...?;
    let seed = seed.trim();
    let (keypair, _) = sp_core::sr25519::Pair::from_string_with_seed(seed, None)...?;
    keystore
        .insert(KeyTypeId(*b"aura"), seed, &keypair.public().to_raw_vec())
        .unwrap();
    log::info!("AURA pubkey: {}", &keypair.public())
}

// node/src/command.rs:223–236 — GRANDPA
if let Some(seed_file) = &cfg.midnight_cfg.grandpa_seed_file {
    let seed = std::fs::read_to_string(seed_file)...?;
    let seed = seed.trim();
    let (keypair, _) = sp_core::ed25519::Pair::from_string_with_seed(seed, None)...?;
    keystore
        .insert(KeyTypeId(*b"gran"), seed, &keypair.public().to_raw_vec())
        .unwrap();
}

// node/src/command.rs:238–251 — CROSS_CHAIN
if let Some(seed_file) = &cfg.midnight_cfg.cross_chain_seed_file {
    let seed = std::fs::read_to_string(seed_file)...?;
    let seed = seed.trim();
    let (keypair, _) = sp_core::ecdsa::Pair::from_string_with_seed(seed, None)...?;
    keystore
        .insert(KeyTypeId(*b"crch"), seed, &keypair.public().to_raw_vec())
        .unwrap();
}
```

The seed value in each file can be any of: BIP-39 mnemonic phrase, hex-encoded secret, or an ss58-compatible string (e.g. `//Alice` for dev). The node trims whitespace before parsing (`node/src/command.rs:214, 229, 244`). The field docs in `node/src/cfg/midnight_cfg/mod.rs:33–44` confirm the accepted formats and link to the polkadot-sdk `AddressUri` documentation.

### Configuration path

The three config keys (`aura_seed_file`, `grandpa_seed_file`, `cross_chain_seed_file`) are fields on `MidnightCfg` (`node/src/cfg/midnight_cfg/mod.rs:32–42`). The config system resolves them from environment variables via `Environment::default()` (`node/src/cfg/mod.rs:362`), which maps uppercase underscored env var names directly to the snake_case field names — so `AURA_SEED_FILE` sets `aura_seed_file`. Config files (TOML presets) can also set these fields by their snake_case names.

---

## The Node Key (libp2p Identity)

The node key is **distinct** from the three validator session keys. It identifies the node on the libp2p peer-to-peer network but plays no role in consensus or finality signing.

| Item | Detail | Source |
|------|--------|--------|
| Config key | `node_key_file` | `node/src/cfg/substrate_cfg/mod.rs:39–40` |
| Env var | `NODE_KEY_FILE` | `README.md:288` |
| Generation command | `midnight-node key generate-node-key --file <path>` | `partner-chains/toolkit/partner-chains-cli/src/generate_keys/mod.rs:167` |
| Storage location | `<base_path>/network/secret_ed25519` | `generate_keys/mod.rs:49–50` |
| Passing raw key at CLI | `--node-key "0x..."` (not recommended) | `node/src/cfg/substrate_cfg/mod.rs:71` |

The `generate-keys` wizard generates the network key automatically if none is present (`generate_keys/mod.rs:117–150`).

---

## Key Generation and Insertion

### Generating keys with `key generate`

```bash
# Generate a key with a specific scheme and print as JSON
midnight-node key generate --scheme sr25519 --output-type json

# Generate an sr25519 (AURA) seed
midnight-node key generate --scheme sr25519

# Generate an ed25519 (GRANDPA) seed
midnight-node key generate --scheme ed25519

# Generate an ecdsa (CROSS_CHAIN) seed
midnight-node key generate --scheme ecdsa
```

The `generate-keys` wizard calls this pattern internally for each key type (`partner-chains/toolkit/partner-chains-cli/src/generate_keys/mod.rs:115–134`).

### Inserting a key with `author_insertKey` (RPC)

`author_insertKey` inserts a key directly into the node's keystore via the RPC endpoint. It is marked unsafe and requires the `--rpc-methods=Unsafe` flag.

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "id": 1, "jsonrpc": "2.0",
    "method": "author_insertKey",
    "params": ["aura", "//Alice", "<sr25519-pubkey-hex>"]
  }' \
  http://127.0.0.1:9944
```

Parameters are `[keyType, suri, publicKey]`. Use the `key_type` values from the table above (`aura`, `gran`, `crch`). Source: `node/src/openrpc.rs:461, 501`.

### Rotating keys with `author_rotateKeys` (RPC)

`author_rotateKeys` generates a new set of session keys in the keystore and returns the concatenated public keys as a hex blob. This is the standard Substrate mechanism for key rotation on live validators, also marked unsafe.

```bash
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"id": 1, "jsonrpc": "2.0", "method": "author_rotateKeys", "params": []}' \
  http://127.0.0.1:9944
```

The returned hex blob can be submitted on-chain as the new session keys. Source: `node/src/openrpc.rs:462, 502`.

> Note: `author_rotateKeys` generates keys for the `SessionKeys` struct fields only (`aura` + `grandpa`). The `crch` key is not part of `SessionKeys` and must be managed separately via the seed-file mechanism or `author_insertKey`.

---

## Quick-Reference: Multi-Node Dev Setup

```bash
# Write a seed file (mnemonic or dev path)
echo "//Alice" > /tmp/alice-seed

# Start a validator node with all three seed files
CFG_PRESET=dev \
  AURA_SEED_FILE=/tmp/alice-seed \
  GRANDPA_SEED_FILE=/tmp/alice-seed \
  CROSS_CHAIN_SEED_FILE=/tmp/alice-seed \
  BASE_PATH=/tmp/node-1 CHAIN=local VALIDATOR=true \
  midnight-node
```

Source: `README.md:298–300`.

For production, use distinct seed files for each key type and store them with restrictive permissions.

---

## Cross-References

- `midnight-node:node-architecture` → `references/consensus-and-finality.md` — full AURA/GRANDPA/BEEFY pallet configuration, justification periods, BEEFY session-key TODO detail
- `midnight-node:node-configuration` — configuration hierarchy, TOML presets, `SHOW_CONFIG` debugging, full env var table
- `midnight-node:node-validator` — end-to-end validator operator workflow: key provisioning, session-key registration on-chain, candidate registration
- `midnight-node:node-rpc-api` — `author_insertKey`, `author_rotateKeys`, `author_hasSessionKeys`, `author_hasKey` RPC method signatures
