# Consensus and Finality Deep-Dive

Midnight uses a three-protocol layered consensus stack built on Polkadot SDK: AURA for block production, GRANDPA for deterministic finality, and BEEFY+MMR for compact bridge proofs. All claims here are sourced from the `node-1.0.0` tag of `midnight-node`.

## Stack Overview

```text
┌────────────────────────────────────────────────────────────────┐
│                        Light Clients                           │
│             (verify chain state without full sync)             │
│                               ↑                                │
│              BEEFY justifications + MMR inclusion proofs       │
├────────────────────────────────────────────────────────────────┤
│                   BEEFY (bridge protocol)                      │
│   ECDSA (secp256k1) · pallet_beefy + pallet_beefy_mmr         │
│   Compact finality proofs backed by stake-weighted MMR roots   │
│   ⚠ NOT yet wired as a validator session key (see below)       │
├────────────────────────────────────────────────────────────────┤
│                  MMR (Merkle Mountain Range)                    │
│   pallet_mmr · Keccak-256 · append-only leaf log              │
│   Leaf data provided by pallet_beefy_mmr (BeefyMmrLeaf)        │
├────────────────────────────────────────────────────────────────┤
│                   GRANDPA (finality gadget)                    │
│   Ed25519 · Byzantine deterministic finality                   │
│   Justification every 512 blocks                               │
├────────────────────────────────────────────────────────────────┤
│                 AURA (block production)                         │
│   Sr25519 · round-robin slot assignment                        │
│   6 s/slot · 300 slots/epoch (30 min)                         │
└────────────────────────────────────────────────────────────────┘
```

---

## AURA — Block Production

AURA (Authority Round) assigns each slot to one validator in round-robin order. A validator holds the slot for 6 seconds; if it fails to produce a block the slot is skipped.

| Parameter | Value | Source |
|-----------|-------|--------|
| Key scheme | Sr25519 (`sp_consensus_aura::sr25519`) | `runtime/src/lib.rs:72` |
| Slot duration | 6 000 ms (6 s) | `runtime/src/lib.rs:300` |
| Multiple blocks per slot | disabled (`ConstBool<false>`) | `runtime/src/lib.rs:391` |
| Slots per epoch | 300 (= 30 min) | `runtime/src/lib.rs:117` |
| `SlotDuration` type | `ConstU64<SLOT_DURATION>` | `runtime/src/lib.rs:392` |
| Max authorities | 10 000 | `runtime/src/lib.rs:538` |

### Runtime Config

```rust
// runtime/src/lib.rs:300
pub const SLOT_DURATION: u64 = 6 * 1000;

// runtime/src/lib.rs:117
pub const SLOTS_PER_EPOCH: u32 = 300;

// runtime/src/lib.rs:387–393
impl pallet_aura::Config for Runtime {
    type AuthorityId = AuraId;                         // sr25519
    type DisabledValidators = ();
    type MaxAuthorities = MaxAuthorities;              // 10 000
    type AllowMultipleBlocksPerSlot = ConstBool<false>;
    type SlotDuration = ConstU64<SLOT_DURATION>;       // 6 000 ms
}
```

### Service Wiring

The AURA authoring task is registered as an essential Tokio task in `node/src/service.rs`. It uses `sc_partner_chains_consensus_aura::start_aura` (the Partner Chains variant) with `AuraPair` (`sp_consensus_aura::sr25519::AuthorityPair`) and a block-proposal slot portion of 2/3 (`node/src/service.rs:689–732`).

Timestamp resolution routes through `pallet_timestamp`, whose `MinimumPeriod` is set to `SLOT_DURATION / 2 = 3 000 ms` (`runtime/src/lib.rs:478`), ensuring timestamp increments stay within the slot boundary.

---

## GRANDPA — Deterministic Finality

GRANDPA (GHOST-based Recursive ANcestor Deriving Prefix Agreement) provides Byzantine fault-tolerant finality. It finalizes *chains* of blocks in a single round rather than finalizing each block individually, providing liveness under network partitions and safety under asynchrony.

| Parameter | Value | Source |
|-----------|-------|--------|
| Key scheme | Ed25519 (`pallet_grandpa::AuthorityId`) | `runtime/src/lib.rs:59` |
| Justification period | 512 blocks | `node/src/service.rs:240` |
| Max authorities | 10 000 (`MaxAuthorities`) | `runtime/src/lib.rs:401` |
| Max nominators | 5 | `runtime/src/lib.rs:402` |
| Max set-id session entries | 0 (disabled) | `runtime/src/lib.rs:403` |
| Equivocation reporting | disabled (`()`) | `runtime/src/lib.rs:406` |

### Runtime Config

```rust
// runtime/src/lib.rs:397–407
impl pallet_grandpa::Config for Runtime {
    type RuntimeEvent = RuntimeEvent;
    type WeightInfo = weights::pallet_grandpa::WeightInfo<Runtime>;
    type MaxAuthorities = MaxAuthorities;   // 10 000
    type MaxNominators = ConstU32<5>;
    type MaxSetIdSessionEntries = ConstU64<0>;
    type KeyOwnerProof = sp_core::Void;
    type EquivocationReportSystem = ();
}
```

### Justification Period

The justification period is set in the node service, not the runtime pallet:

```rust
// node/src/service.rs:238–240
/// The minimum period of blocks on which justifications will be
/// imported and generated.
const GRANDPA_JUSTIFICATION_PERIOD: u32 = 512;
```

It is passed directly to `sc_consensus_grandpa::block_import` at `node/src/service.rs:402–404`. A GRANDPA justification (finality proof) is generated and stored for at least every 512nd finalized block; light clients and bridge protocols consume these to prove finality without replaying the full vote history.

### Warp Sync

GRANDPA provides the warp-sync proof provider (`sc_consensus_grandpa::warp_proof::NetworkProvider`) used during fast-sync; light clients download only GRANDPA authority-set change proofs and the latest finalized state rather than all intermediate headers (`node/src/service.rs:549–551`).

---

## BEEFY — Bridge Protocol

BEEFY (Bridge Efficiency Enabling Finality Yielder) produces compact finality proofs designed for on-chain light clients and cross-chain bridges. It operates one finality step *after* GRANDPA: only blocks already finalized by GRANDPA can receive a BEEFY justification.

| Parameter | Value | Source |
|-----------|-------|--------|
| Key scheme | ECDSA (`ecdsa_crypto::AuthorityId`) | `runtime/src/lib.rs:75` |
| Curve | secp256k1 (substrate `ecdsa_crypto`) | `runtime/src/lib.rs:73–75` |
| Min block delta | 8 blocks between BEEFY rounds | `node/src/service.rs:758` |
| Max authorities | 10 000 | `runtime/src/lib.rs:411` |
| `OnNewValidatorSet` hook | `BeefyMmrLeaf` (updates MMR authority sets) | `runtime/src/lib.rs:414` |
| `AncestryHelper` | `BeefyMmrLeaf` | `runtime/src/lib.rs:415` |
| Equivocation reporting | disabled (`()`) | `runtime/src/lib.rs:418` |

### Runtime Config

```rust
// runtime/src/lib.rs:409–419
impl pallet_beefy::Config for Runtime {
    type BeefyId = BeefyId;                          // ecdsa_crypto::AuthorityId
    type MaxAuthorities = MaxAuthorities;
    type MaxNominators = ConstU32<5>;
    type MaxSetIdSessionEntries = ConstU64<0>;
    type OnNewValidatorSet = BeefyMmrLeaf;
    type AncestryHelper = BeefyMmrLeaf;
    type WeightInfo = ();
    type KeyOwnerProof = sp_core::Void;
    type EquivocationReportSystem = ();
}
```

### BEEFY Is NOT Wired as a Session Key

`pallet_beefy` is present and the BEEFY gadget runs as an essential service (`node/src/service.rs:766–772`), but the BEEFY key is **not yet included in the `SessionKeys` struct**. The comment in the code is explicit:

```rust
// runtime/src/lib.rs:221–228
impl_opaque_keys! {
    pub struct SessionKeys {
        pub aura: Aura,
        pub grandpa: Grandpa,
        // todo: add the beefy
        // pub beefy: Beefy,
    }
}
```

The downstream consequences are consistent across the codebase:

- `key_definitions()` in `node/src/cli.rs:490–493` lists only `[AURA, GRANDPA, CROSS_CHAIN]` with the comment `// TODO: BEEFY(follow up pr)`.
- The local-environment keystore (`local-environment/src/lib/keystore.ts:40–41, 67`) comments out the BEEFY key type with `// TODO: Support BEEFY key files in pods.` and `// TODO: BEEFY`.
- `MaybeFromCandidateKeys` and `From<SessionKeys>` (both at `runtime/src/lib.rs:231–253`) handle only `aura` and `grandpa` keys.

The practical effect: validators do not yet rotate BEEFY keys through the session-key mechanism. The BEEFY gadget uses whatever ECDSA keys are present in the keystore, not session-managed keys.

### Custom Stake-Weighted Authority Sets

Midnight replaces the default BEEFY authority set with a custom implementation in `runtime/src/beefy.rs`. The `AuthoritiesProvider::on_new_validator_set` hook (`beefy.rs:90–116`) computes stake-weighted `BeefyAuthoritySet` structures using the `SessionValidatorManagement` committee. Each authority set is a Merkle root (`binary_merkle_tree` with Keccak-256) over `(beefy_id_bytes || stake_le_bytes)` tuples, stored in `pallet_beefy_mmr::BeefyAuthorities` and `BeefyNextAuthorities`. Current stake values are uniform (all `1`) pending a richer staking integration (`beefy.rs:139–143`).

---

## MMR — Merkle Mountain Range

The MMR is an append-only authenticated data structure. Every finalized block appends a leaf; the running Merkle root is recorded in the block header digest. Light clients can prove inclusion of any historical leaf with an O(log n) proof.

| Parameter | Value | Source |
|-----------|-------|--------|
| Hash function | Keccak-256 | `runtime/src/lib.rs:423` |
| Leaf data provider | `pallet_beefy_mmr::Pallet<Runtime>` | `runtime/src/lib.rs:424` |
| Root deposit | `pallet_beefy_mmr::DepositBeefyDigest` | `runtime/src/lib.rs:425` |
| Indexing prefix | `mmr::INDEXING_PREFIX` | `runtime/src/lib.rs:422` |
| Leaf version | `(major=0, minor=0)` | `runtime/src/lib.rs:456` |

### Runtime Config

```rust
// runtime/src/lib.rs:421–430
impl pallet_mmr::Config for Runtime {
    const INDEXING_PREFIX: &'static [u8] = mmr::INDEXING_PREFIX;
    type Hashing = Keccak256;
    type LeafData = pallet_beefy_mmr::Pallet<Runtime>;
    type OnNewRoot = pallet_beefy_mmr::DepositBeefyDigest<Runtime>;
    type BlockHashProvider = pallet_mmr::DefaultBlockHashProvider<Runtime>;
    type WeightInfo = weights::pallet_mmr::WeightInfo<Runtime>;
}
```

### BeefyMmrLeaf Config

`pallet_beefy_mmr` constructs the content of each MMR leaf, encoding the current and next BEEFY authority sets alongside any extra data provided by the runtime.

```rust
// runtime/src/lib.rs:466–472
impl pallet_beefy_mmr::Config for Runtime {
    type LeafVersion = LeafVersion;               // (0, 0)
    type BeefyAuthorityToMerkleLeaf = RawBeefyId; // raw ECDSA pubkey bytes
    type LeafExtra = Vec<u8>;                     // runtime-specific extra data
    type BeefyDataProvider = ();                  // no additional data provider
    type WeightInfo = weights::pallet_beefy_mmr::WeightInfo<Runtime>;
}
```

The `LeafVersion` (major=0, minor=0) signals the leaf format is stable. Per the comments at `runtime/src/lib.rs:442–456`, `major` changes only on backward-incompatible format breaks; `minor` changes when new fields are appended in a backward-compatible way (SCALE encoding allows older readers to decode a subset).

### MMR Gadget

When offchain indexing is enabled, an `mmr-gadget` background task writes MMR leaves to offchain storage for retrieval via RPC (`node/src/service.rs:774–780`). The runtime-API `BeefyMmrApi` (implemented at `runtime/src/lib.rs:1434–1440`) exposes `authority_set_proof()` and `next_authority_set_proof()` for light client bootstrapping.

---

## SessionKeys — What Is Wired

The `SessionKeys` struct is defined in the `opaque` module and governs which cryptographic keys participate in the session rotation mechanism:

```rust
// runtime/src/lib.rs:221–228
impl_opaque_keys! {
    pub struct SessionKeys {
        pub aura: Aura,      // Sr25519 — block production
        pub grandpa: Grandpa, // Ed25519 — deterministic finality
        // todo: add the beefy
        // pub beefy: Beefy,  // ECDSA — bridge proofs (NOT YET WIRED)
    }
}
```

| Key | Algorithm | Role | Session-managed |
|-----|-----------|------|-----------------|
| `aura` | Sr25519 | Block production | Yes |
| `grandpa` | Ed25519 | Finality voting | Yes |
| `beefy` | ECDSA (secp256k1) | Bridge proofs | **No** (commented out) |

`MaxAuthorities` is shared across all three pallet configs (`pallet_aura`, `pallet_grandpa`, `pallet_beefy`) and caps the authority set at 10 000 (`runtime/src/lib.rs:538`).

---

## Parameter Quick-Reference

| Constant | Value | File:Line |
|----------|-------|-----------|
| `SLOT_DURATION` | 6 000 ms | `runtime/src/lib.rs:300` |
| `SLOTS_PER_EPOCH` | 300 | `runtime/src/lib.rs:117` |
| Epoch wall-clock | 30 min | derived |
| `GRANDPA_JUSTIFICATION_PERIOD` | 512 blocks | `node/src/service.rs:240` |
| BEEFY `min_block_delta` | 8 | `node/src/service.rs:758` |
| `MaxAuthorities` | 10 000 | `runtime/src/lib.rs:538` |
| MMR hash | Keccak-256 | `runtime/src/lib.rs:423` |
| `LeafVersion` | (0, 0) | `runtime/src/lib.rs:456` |

---

## Cross-References

- `midnight-node:node-architecture` — top-level pallet inventory and consensus summary diagram
- `midnight-node:node-configuration` — operator configuration for AURA keys, GRANDPA keys, and BEEFY key provisioning
- `midnight-node:node-rpc-api` — `grandpa_roundState`, `grandpa_proveFinality`, `grandpa_subscribeJustifications`, `beefy_subscribeJustifications`
- `core-concepts:architecture` — high-level Midnight network and privacy architecture
