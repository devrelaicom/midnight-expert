# DUST Generation and SPO Data Model

Two largely independent subsystems share the same database: the DUST-generation pipeline, which tracks cNIGHT→DUST conversion, and the SPO (stake pool operator) pipeline, which tracks Cardano validators eligible to produce Midnight blocks.

For the full table catalog see `references/database-schema.md`. This file covers the *data flow and semantics* of each subsystem.

---

## Part A — DUST Generation

### Background (brief)

DUST is the fee-resource produced by locking NIGHT UTXOs on Midnight. Its economics (generation rate, capacity, decay) are defined by the ledger (`midnight-ledger`) and the on-chain DUST parameters, not by the indexer. For the token model and economic rationale see `core-concepts:tokenomics`; this file covers only the indexer's storage representation.

### A1 — `cnight_registrations` — Cardano Stake Key → Midnight Address

cNIGHT is a Cardano native token that signals intent to participate in DUST generation. A Cardano stake key must be registered against a Midnight DUST address before any NIGHT UTXO it controls can seed a generation.

The `cnight_registrations` table is populated by events from the **`pallet_cnight_observation`** (CNightObservation) pallet, decoded by the chain-indexer's subxt runtime layer.
(`chain-indexer/src/domain/dust.rs:16–46`, `chain-indexer/src/infra/subxt_node/runtimes/v0_22_0.rs:119–154`)

| Column | Type | Meaning |
|---|---|---|
| `id` | BIGSERIAL PK | Surrogate key |
| `cardano_stake_key` | BYTEA | Cardano reward address (raw bytes) |
| `dust_address` | BYTEA | Midnight DUST public key |
| `valid` | BOOLEAN | `true` after `Registration` event; `false` after `Deregistration` |
| `registered_at` | BIGINT | Block timestamp (ms) when first registered |
| `removed_at` | BIGINT? | Block timestamp (ms) of `Deregistration`, NULL if active |
| `block_id` | BIGINT FK | Most recent block that changed this row |
| `utxo_tx_hash` | BYTEA? | Cardano UTXO tx hash from `MappingAdded`, NULL until added |
| `utxo_output_index` | BIGINT? | Output index of the UTXO, NULL until added |

Unique constraint: `(cardano_stake_key, dust_address)`.

Four domain events update this table (`chain-indexer/src/infra/storage.rs:924–1033`):

```text
Registration    → INSERT / re-activate (valid=true, removed_at=NULL)
Deregistration  → UPDATE valid=false, removed_at=block_timestamp
MappingAdded    → UPDATE utxo_tx_hash, utxo_output_index
MappingRemoved  → UPDATE utxo_tx_hash=NULL, utxo_output_index=NULL
```

Genesis-block registrations are bootstrapped from pallet storage rather than events (the genesis block produces no events for pre-existing state):
(`chain-indexer/src/infra/subxt_node.rs:212–216`, `chain-indexer/src/infra/subxt_node/runtimes.rs:125–135`)

### A2 — `dust_generation_info` — NIGHT-UTXO-backed Generation Records

Each NIGHT UTXO that enters DUST generation creates one row. The table was introduced in `001_initial.sql` and extended by `002_dust_generations_qdo_fields.sql`.

#### Base columns (migration `001_initial.sql:161–174`)

| Column | Type | Meaning |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `night_utxo_hash` | BYTEA | Hash identifying the backing NIGHT UTXO |
| `value` | BYTEA | NIGHT UTXO value (u128 big-endian bytes) |
| `owner` | BYTEA | DUST public key of the owner |
| `nonce` | BYTEA | Nonce from `DustGenerationInfo` |
| `ctime` | BIGINT | Creation time (seconds) — when NIGHT was locked |
| `merkle_index` | BIGINT | Position in the DUST generation Merkle tree (`QualifiedDustOutput.mt_index`) |
| `dtime` | BIGINT? | Decay time (seconds) — when the backing NIGHT was spent; NULL until spent |
| `transaction_id` | BIGINT FK? | Transaction that created or last updated this row |

#### QDO columns added by migration `002_dust_generations_qdo_fields.sql`

**QDO = QualifiedDustOutput** — the richer per-UTXO descriptor from the ledger that carries the initial value and the backing NIGHT nonce separately from the generation-level info. Migration 002 exposes these fields so the `dustGenerations` subscription can deliver the full `QualifiedDustOutput` payload to wallets without a second query.

All three columns are added `NULLABLE` so the migration runs on populated databases. Pre-migration rows have `NULL` for all three and are automatically excluded from the `dustGenerations` subscription's `WHERE generation_index >= $cursor` clause (NULL fails the integer comparison).
(`002_dust_generations_qdo_fields.sql:1–15`)

| Column | Type | Source in domain types | Meaning |
|---|---|---|---|
| `generation_index` | BIGINT? | `LedgerEventAttributes::DustInitialUtxo.generation_index` | Position in the DUST-generation tree at the time of insertion; used as a cursor by the `dustGenerations` subscription |
| `backing_night` | BYTEA? | `QualifiedDustOutput.backing_night` | Nonce of the backing NIGHT UTXO (distinct from the generation-level `DustGenerationInfo.nonce`) |
| `initial_value` | BYTEA? | `QualifiedDustOutput.initial_value` (u128) | The face value of the DUST UTXO at creation, stored as big-endian bytes |

A composite index `(owner, generation_index)` is added by the same migration to support owner-scoped cursor queries.

Domain types: `indexer-common/src/domain/dust.rs:QualifiedDustOutput` (lines 19–40) and `DustGenerationInfo` (lines 52–71).

### A3 — The `dtime` Model (Decay-Time)

`dtime` is the second in which the backing NIGHT UTXO was spent. It is the point after which the generation stops accumulating DUST (the DUST "decays" back to zero once the NIGHT is gone).

In domain terms (`DustGenerationInfo.dtime`): a value of `u64::MAX` means "not yet decayed" — the backing NIGHT is still locked. The storage layer converts `u64::MAX` to SQL `NULL`:

```rust
// chain-indexer/src/infra/storage.rs:732–736
let dtime = if generation_info.dtime == u64::MAX {
    None
} else {
    Some(generation_info.dtime as i64)
};
```

Two ledger event variants touch `dtime`:

| Variant | Effect on `dust_generation_info` |
|---|---|
| `DustInitialUtxo` | INSERT with `dtime = NULL` (NIGHT just locked; `u64::MAX` sentinel) |
| `DustGenerationDtimeUpdate` | UPDATE `SET dtime = $1 WHERE night_utxo_hash = $2` (NIGHT spent) |

(`chain-indexer/src/infra/storage.rs:710–776`)

The ledger-side `DustGenerationDtimeUpdate` event also carries a `TreeInsertionPath` (`tree_insertion_path: SerializedDustTreeInsertionPath`) stored verbatim in `ledger_events.raw`. Wallets use this path to call `generating_tree.update_from_evidence(...)` locally. The `dtime_update` event is surfaced at the GraphQL layer under `midnight-indexer:indexer-graphql-api` → `references/dust-beta-api.md`.
(`indexer-common/src/domain.rs:328–335`)

### A4 — DUST Ledger Events in `ledger_events`

All DUST-related ledger events are stored in the `ledger_events` table with `grouping = 'Dust'` (`LEDGER_EVENT_GROUPING` enum). The `variant` column identifies the specific event type.
(`001_initial.sql:5–13`, `001_initial.sql:106–118`)

| `variant` | `grouping` | What it records |
|---|---|---|
| `DustInitialUtxo` | `Dust` | A new NIGHT UTXO registered for DUST generation; triggers INSERT into `dust_generation_info` |
| `DustGenerationDtimeUpdate` | `Dust` | The backing NIGHT was spent; triggers UPDATE of `dtime` in `dust_generation_info`; carries `tree_insertion_path` in `raw` for wallet Merkle-tree sync |
| `DustSpendProcessed` | `Dust` | A DUST UTXO was spent; inserts a row into `dust_nullifiers`; does NOT update `dust_generation_info` |
| `ParamChange` | `Dust` | DUST economic parameter update (serialized ledger event stored in `raw`) |
| `ZswapInput` | `Zswap` | Shielded spend (nullifier recorded in `zswap_nullifiers`) |
| `ZswapOutput` | `Zswap` | Shielded output |

(`indexer-common/src/domain.rs:313–341`, `chain-indexer/src/infra/storage.rs:663–776`)

`DustSpendProcessed` stores `(nullifier, commitment)` in `dust_nullifiers`; it does not modify `dust_generation_info` because DUST spend and NIGHT spend are separate events. Both system and regular transactions can carry DUST events — `save_system_transaction` calls `save_ledger_events` and `save_dust_generation_info` for system transactions too:
(`chain-indexer/src/infra/storage.rs:451–462`)

### A5 — Generation-Tree Index Model

The DUST-generation Merkle tree position for a generation is tracked at two granularities:

**Transaction level** (`regular_transactions` columns, `001_initial.sql:47–60`):

| Column | Meaning |
|---|---|
| `dust_generation_start_index` | Index of first DUST generation added in this transaction |
| `dust_generation_end_index` | Index of last DUST generation added in this transaction (exclusive upper bound) |

The same pair exists for the zswap and dust-commitment trees: `zswap_start_index/end_index` and `dust_commitment_start_index/end_index`.

**Block level** (`blocks` columns, migration `003_block_tree_end_indexes.sql`):

Migration 003 adds `zswap_end_index`, `dust_commitment_end_index`, and `dust_generation_end_index` to `blocks`. These are the chain's `*_first_free` values as of the block boundary — i.e., the next available slot in each tree after all transactions in the block have been applied.
(`003_block_tree_end_indexes.sql:1–19`)

Purpose: lets API clients determine the current tree upper bound from a single `Block` row without scanning `regular_transactions`. For the GraphQL `@beta` surface that uses these, see `midnight-indexer:indexer-graphql-api` → `references/dust-beta-api.md`.

**Row level** (`dust_generation_info.generation_index`, migration 002):

The per-row `generation_index` column is the position of that specific generation in the DUST-generation tree. It serves as the cursor field for the `dustGenerations` subscription: `WHERE generation_index >= $cursor`.

---

## Part B — SPO Data

### B1 — Pipeline Overview

The `spo-indexer` service ingests SPO data from two sources:

```text
┌─────────────────────┐     subxt RPC     ┌──────────────────────────────┐
│  Midnight node      │──────────────────→│  spo-indexer application     │
│  (substrate-based)  │  systemParameters_│  process_next_epoch()        │
│                     │  getAriadneParams  │  → spo_identity              │
│                     │  sidechain_        │  → committee_membership      │
│                     │  getEpochCommittee │  → spo_epoch_performance     │
└─────────────────────┘                   │  → spo_history               │
                                          │  → epochs                     │
┌─────────────────────┐   Blockfrost API  │                               │
│  Cardano mainchain  │──────────────────→│  refresh_stake_snapshots()   │
│  (via Blockfrost)   │  GET /pools/{id}  │  → spo_stake_snapshot        │
│                     │                   │  → spo_stake_history         │
└─────────────────────┘                   └──────────────────────────────┘
```

(`spo-indexer/src/application.rs:54–88`)

The two loops run independently: epoch processing polls via subxt; stake refresh runs on a background `tokio::spawn` ticker.

### B2 — `spo_identity`

One row per unique SPO (stake pool operator) seen in candidate registrations. Populated by `systemParameters_getAriadneParameters` RPC calls.
(`001_initial.sql:252–259`, `spo-indexer/src/infra/storage.rs:112–140`)

| Column | Type | Meaning |
|---|---|---|
| `spo_sk` | VARCHAR PK | Sidechain secret-key fingerprint (hex, `0x` prefix stripped) |
| `sidechain_pubkey` | VARCHAR UNIQUE | Sidechain public key (in practice equals `spo_sk` as stored) |
| `pool_id` | VARCHAR FK→`pool_metadata_cache` | Cardano pool ID (bech32), derived via Blake2b-224 of mainchain pubkey |
| `mainchain_pubkey` | VARCHAR UNIQUE | Cardano cold key (hex) |
| `aura_pubkey` | VARCHAR UNIQUE | Aura session key (block production) |

Insert guard: a `SELECT … WHERE NOT EXISTS` prevents duplicate registration if any unique key already exists in the table.
(`spo-indexer/src/infra/storage.rs:112–139`)

`pool_id` in `spo_identity` is a foreign key into `pool_metadata_cache`, which is populated via Blockfrost `pools_metadata`:
(`spo-indexer/src/infra/spo_client.rs:311–323`)

### B3 — `committee_membership`

Records which SPOs were in the active committee for each epoch and their ordered position.
(`001_initial.sql:263–271`)

| Column | Type | Meaning |
|---|---|---|
| `spo_sk` | VARCHAR | SPO fingerprint (FK to `spo_identity` by value, not a hard FK constraint) |
| `sidechain_pubkey` | VARCHAR | Same as `spo_sk` in practice |
| `epoch_no` | BIGINT | Midnight epoch |
| `position` | INT | 0-based index in the committee (determines slot assignment) |
| `expected_slots` | INT | Slots expected for this position (`slots_per_epoch / committee_size`, with leftover distributed to lower positions) |

Primary key is `(epoch_no, position)`. Re-insertion is silently discarded with `ON CONFLICT DO NOTHING`.

`expected_slots` is computed by the indexer, not fetched from the node:
(`spo-indexer/src/application.rs:335–363`)

### B4 — `epochs`

Epoch boundary records written once per epoch by the SPO indexer.
(`001_initial.sql:232–236`)

| Column | Type | Meaning |
|---|---|---|
| `epoch_no` | BIGINT PK | Epoch number |
| `starts_at` | TIMESTAMPTZ | Epoch start (derived from `sidechain_getStatus` timestamps) |
| `ends_at` | TIMESTAMPTZ | Epoch end |

The spo-indexer derives past epoch boundaries by back-calculating from the current epoch timestamp, using a fixed `SLOT_DURATION = 6000 ms` and the `slots_per_epoch` value read from on-chain storage:
(`spo-indexer/src/infra/spo_client.rs:44`, `spo-indexer/src/application.rs:367–390`)

### B5 — `spo_epoch_performance`, `spo_history`

**`spo_epoch_performance`** (`001_initial.sql:275–283`): Records `expected_blocks` and `produced_blocks` per SPO per epoch. An SPO only gets a row if it actually produced at least one block in the epoch (blocks are counted from the `candidate_registrations` response's UTXO-per-key tally). Only inserted if the SPO already exists in `spo_identity`.

**`spo_history`** (`001_initial.sql:288–297`): Tracks `Valid`/`Invalid` status per SPO per epoch. `valid_from` and `valid_to` are both set to `epoch_no` at insert time; they are updated on conflict. An SPO is "invalid" when `is_valid = false` in the `systemParameters_getAriadneParameters` registration response.

### B6 — Stake Snapshot Tables

Blockfrost supplies per-pool stake data. The SPO indexer uses the `blockfrost` crate plus a raw HTTP client (the crate doesn't expose all fields needed). Lovelace fields are parsed from Blockfrost's decimal-string format:
(`spo-indexer/src/infra/spo_client.rs:390–403`)

**`pool_metadata_cache`** (`001_initial.sql:241–248`): Human-readable pool metadata (name, ticker, homepage, URL). Upserted from Blockfrost `pools_metadata`. Acts as the foreign-key anchor for all stake tables.

**`spo_stake_snapshot`** (`001_initial.sql:300–312`): One row per pool; upserted on every stake-refresh cycle. Live snapshot only — history is in `spo_stake_history`.

**`spo_stake_history`** (`001_initial.sql:316–329`): Append-only stake history rows with `recorded_at` and `mainchain_epoch` (nullable; resolved from `sidechain_getStatus` at refresh time).

**`spo_stake_refresh_state`** (`001_initial.sql:333–342`): A single-row cursor table (primary key is `BOOLEAN DEFAULT TRUE`) that persists the `last_pool_id` processed by the cursor-based paging loop, enabling restart-safe incremental refresh.

#### SQLite-only migration `003_spo_stake_integer.sql`

The initial SQLite schema defined `live_stake`, `active_stake`, `declared_pledge`, and `live_pledge` as `REAL` (IEEE-754 f64). This is exact only up to 2⁵³ ≈ 9.0 × 10¹⁵ lovelace. Cardano's total supply is 4.5 × 10¹⁶ lovelace, and aggregate SUM queries can exceed 2⁵³, causing silent precision loss.

Migration `003_spo_stake_integer.sql` rebuilds both `spo_stake_snapshot` and `spo_stake_history` in SQLite (column-type changes require table rebuilds in SQLite — `ALTER COLUMN` is not supported). Individual per-pool values are already below 2⁵³ and are preserved exactly via `CAST(x AS INTEGER)`. PostgreSQL was not affected (its initial schema used `NUMERIC`).
(`sqlite/003_spo_stake_integer.sql:1–86`)

### B7 — Stake Refresh Cadence

| Parameter | Default | Config key |
|---|---|---|
| Refresh interval | 900 s (15 min) | `application.stake_refresh.period_secs` |
| Pools per cycle | 100 | `application.stake_refresh.page_size` |
| Max Blockfrost RPS | 2 | `application.stake_refresh.max_rps` |

(`spo-indexer/config.yaml:10–13`, `indexer-standalone/src/config.rs:181–185`)

The minimum effective ticker interval is `max(period_secs, 60)` seconds — the initial tick is consumed as a startup delay, preventing a burst on restart.
(`spo-indexer/src/application.rs:63–64`)

Paging is cursor-based: on each cycle the loop fetches `page_size` pool IDs alphabetically after the stored `last_pool_id` cursor, wrapping to the beginning when the end is reached. The cursor is persisted to `spo_stake_refresh_state` after each successful batch commit.
(`spo-indexer/src/application.rs:168–251`)

Rate limiting is implemented as a sleep of `1000 / max_rps` ms between Blockfrost requests:
(`spo-indexer/src/application.rs:202–205`)

---

## Cross-references

- Full table column listings: `references/database-schema.md`
- DUST GraphQL beta API (`dustGenerations` subscription, `dustGenerationStatus` query): `midnight-indexer:indexer-graphql-api` → `references/dust-beta-api.md`
- NIGHT/DUST token economics and the NIGHT→DUST conversion rationale: `core-concepts:tokenomics`
- SPO configuration knobs (`period_secs`, `page_size`, `max_rps`): `midnight-indexer:indexer-architecture` → `references/configuration-reference.md`
- Ledger event types and the EventDetailsV8/V9 variants: `indexer-common/src/domain/ledger/ledger_state.rs:914–970`
