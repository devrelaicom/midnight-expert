# Indexer Database Schema Reference

Complete table catalog derived from the migration files in
`indexer-common/migrations/` at tag 4.3.3. Every table, its columns, primary
key, notable indexes, and foreign-key relationships are enumerated here. The
SKILL.md gives a conceptual overview; this file is the authoritative DDL
reference.

---

## Migration order

### Postgres (`indexer-common/migrations/postgres/`)

| # | File | What it does |
|---|------|--------------|
| 0 | `000_ledger_db.sql` | Creates `ledger_db_nodes` and `ledger_db_roots` |
| 1 | `001_initial.sql` | Creates all 24 application tables, types, and indexes |
| 2 | `002_dust_generations_qdo_fields.sql` | Adds `generation_index`, `backing_night`, `initial_value` to `dust_generation_info` |
| 3 | `003_block_tree_end_indexes.sql` | Adds `zswap_end_index`, `dust_commitment_end_index`, `dust_generation_end_index` to `blocks`; backfills from `regular_transactions` |

### SQLite (`indexer-common/migrations/sqlite/` + `sqlite-ledger-db/`)

| # | File | What it does |
|---|------|--------------|
| 0 | `sqlite-ledger-db/000_ledger_db.sql` | Creates `ledger_db_nodes` and `ledger_db_roots` (separate DB) |
| 1 | `sqlite/001_initial.sql` | Creates all application tables including `transaction_identifiers` (SQLite-only); no ENUM types |
| 2 | `sqlite/002_dust_generations_qdo_fields.sql` | Same three columns added to `dust_generation_info` as Postgres migration 2 |
| 3 | `sqlite/003_spo_stake_integer.sql` | **SQLite-only.** Rebuilds `spo_stake_snapshot` and `spo_stake_history`, changing stake columns from `REAL` to `INTEGER` to avoid IEEE-754 f64 precision loss on large lovelace values |
| 4 | `sqlite/004_block_tree_end_indexes.sql` | Same block-tree end-index columns as Postgres migration 3 |

SQLite has one extra migration (003) with no Postgres equivalent.
Postgres migration 3 corresponds to SQLite migration 4.

---

## Table catalog

### Ledger-DB tables (separate database)

These two tables live in their own database file / connection and store the
Merkle-tree nodes used by the indexer's state-key mechanism. They have no
foreign keys to the application tables.

#### `ledger_db_nodes`

Source: `postgres/000_ledger_db.sql:4`, `sqlite-ledger-db/000_ledger_db.sql:4`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `key` | `BYTEA` | `BLOB` | **PK** |
| `object` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Serialized node payload |

#### `ledger_db_roots`

Source: `postgres/000_ledger_db.sql:8`, `sqlite-ledger-db/000_ledger_db.sql:8`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `key` | `BYTEA` | `BLOB` | **PK** |
| `count` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Monotonic counter; indexed |

---

### Core chain tables

#### `blocks`

Source: `postgres/001_initial.sql:18`, `sqlite/001_initial.sql:4`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `hash` | `BYTEA NOT NULL UNIQUE` | `BLOB NOT NULL UNIQUE` | Block hash |
| `height` | `BIGINT NOT NULL UNIQUE` | `INTEGER NOT NULL` | Chain height; NOT UNIQUE in SQLite |
| `protocol_version` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `parent_hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `author` | `BYTEA` | `BLOB` | Nullable; block producer |
| `timestamp` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Unix ms |
| `zswap_merkle_tree_root` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `ledger_parameters` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Serialized |
| `ledger_state_key` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Key into `ledger_db_roots` |
| `zswap_end_index` | `BIGINT NOT NULL DEFAULT 0` | `INTEGER NOT NULL DEFAULT 0` | Added by migration 3/4 |
| `dust_commitment_end_index` | `BIGINT NOT NULL DEFAULT 0` | `INTEGER NOT NULL DEFAULT 0` | Added by migration 3/4 |
| `dust_generation_end_index` | `BIGINT NOT NULL DEFAULT 0` | `INTEGER NOT NULL DEFAULT 0` | Added by migration 3/4 |

The three `*_end_index` columns are chain-aligned upper bounds for their
respective Merkle trees as of this block. On Postgres they are backfilled by
migration 3 using a window-function running-max over `regular_transactions`.

Note: in SQLite `height` has no `UNIQUE` constraint (`001_initial.sql:7`
omits it, while Postgres `001_initial.sql:22` declares `UNIQUE`).

#### `transactions`

Source: `postgres/001_initial.sql:33`, `sqlite/001_initial.sql:19`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `block_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `blocks(id)`** |
| `variant` | `TRANSACTION_VARIANT NOT NULL` | `TEXT CHECK(...) NOT NULL` | `'Regular'` or `'System'`; Postgres uses enum type, SQLite uses CHECK constraint |
| `hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `protocol_version` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `raw` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Full serialized transaction bytes |

Indexes: `(block_id)`, `(hash)`, `(variant, id)`.

#### `regular_transactions`

Source: `postgres/001_initial.sql:47`, `sqlite/001_initial.sql:33`

One row per transaction of variant `'Regular'`. Shares its PK with
`transactions` (1-to-1 extension via shared PK).

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGINT` | `INTEGER` | **PK + FK → `transactions(id)`** |
| `transaction_result` | `JSONB NOT NULL` | `TEXT NOT NULL` | Postgres uses JSONB with GIN index; SQLite uses TEXT |
| `zswap_merkle_tree_root` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Root after this tx |
| `zswap_start_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Inclusive lower bound |
| `zswap_end_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Exclusive upper bound |
| `dust_commitment_start_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `dust_commitment_end_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `dust_generation_start_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `dust_generation_end_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `paid_fees` | `BYTEA` | `BLOB` | Nullable |
| `estimated_fees` | `BYTEA` | `BLOB` | Nullable |
| `identifiers` | `BYTEA[] NOT NULL` | — | **Postgres only.** Array of identifier bytes. In SQLite this is normalized into `transaction_identifiers` |

Indexes: `(transaction_result)` + GIN `(transaction_result)` on Postgres,
`(zswap_start_index)`, `(zswap_end_index)`.

#### `transaction_identifiers` (SQLite only)

Source: `sqlite/001_initial.sql:52`

SQLite cannot store arrays, so `regular_transactions.identifiers` is
normalized into this table. No equivalent exists in Postgres.

| Column | SQLite type | Notes |
|--------|-------------|-------|
| `id` | `INTEGER` | **PK** |
| `transaction_id` | `INTEGER NOT NULL` | **FK → `regular_transactions(id)`** |
| `identifier` | `BLOB NOT NULL` | One identifier per row |

Indexes: `(transaction_id)`, `(identifier)`.

---

### Contract tables

#### `contract_actions`

Source: `postgres/001_initial.sql:68`, `sqlite/001_initial.sql:62`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `transaction_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `transactions(id)`** — not `regular_transactions` (`postgres/001_initial.sql:70`) |
| `variant` | `CONTRACT_ACTION_VARIANT NOT NULL` | `TEXT CHECK(...) NOT NULL` | `'Deploy'`, `'Call'`, or `'Update'` |
| `address` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Contract address |
| `state` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Post-action ledger state |
| `zswap_state` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Post-action Zswap state |
| `attributes` | `JSONB NOT NULL` | `TEXT NOT NULL` | Action-specific metadata |

Indexes: `(transaction_id)`, `(address)`, `(id, address)`.

#### `contract_balances`

Source: `postgres/001_initial.sql:122`, `sqlite/001_initial.sql:123`

Token balances recorded per contract action. The only application table with
a direct FK to `contract_actions`.

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `contract_action_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `contract_actions(id)`** (`postgres/001_initial.sql:124`) |
| `token_type` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Serialized `TokenType` |
| `amount` | `BYTEA NOT NULL` | `BLOB NOT NULL` | u128 as bytes |

Unique constraint: `(contract_action_id, token_type)`.  
Indexes: `(contract_action_id)`, `(token_type)`, `(contract_action_id, token_type)`.

---

### Token and UTXO tables

#### `unshielded_utxos`

Source: `postgres/001_initial.sql:83`, `sqlite/001_initial.sql:77`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `creating_transaction_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `transactions(id)`** — not `contract_actions` (`postgres/001_initial.sql:85`) |
| `spending_transaction_id` | `BIGINT` | `INTEGER` | **FK → `transactions(id)`**, nullable; NULL while unspent (`postgres/001_initial.sql:86`) |
| `owner` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `token_type` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `value` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `intent_hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `output_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `ctime` | `BIGINT` | `INTEGER` | Nullable; creation timestamp |
| `initial_nonce` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `registered_for_dust_generation` | `BOOLEAN NOT NULL` | `INTEGER NOT NULL` | SQLite stores as 0/1 |

Unique constraint: `(intent_hash, output_index)`.  
Indexes: `(creating_transaction_id)`, `(spending_transaction_id)`, `(owner)`,
`(creating_transaction_id, owner)`, `(spending_transaction_id, owner)`,
`(token_type)`.

#### `ledger_events`

Source: `postgres/001_initial.sql:106`, `sqlite/001_initial.sql:98`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `transaction_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `transactions(id)`** |
| `variant` | `LEDGER_EVENT_VARIANT NOT NULL` | `TEXT CHECK(...) NOT NULL` | `ZswapInput`, `ZswapOutput`, `ParamChange`, `DustInitialUtxo`, `DustGenerationDtimeUpdate`, `DustSpendProcessed` |
| `grouping` | `LEDGER_EVENT_GROUPING NOT NULL` | `TEXT CHECK(...) NOT NULL` | `'Zswap'` or `'Dust'` |
| `raw` | `BYTEA NOT NULL` | `BYTEA NOT NULL` | Serialized event bytes |
| `attributes` | `JSONB NOT NULL` | `TEXT NOT NULL` | |

Indexes: `(transaction_id)`, `(variant)`, `(grouping)`, `(id, grouping)`,
`(transaction_id, grouping)`.

#### `dust_generation_info`

Source (base columns): `postgres/001_initial.sql:161`, `sqlite/001_initial.sql:163`  
Source (added columns): `postgres/002_dust_generations_qdo_fields.sql:12–15`,
`sqlite/002_dust_generations_qdo_fields.sql:12–15`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `night_utxo_hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Hash of source NIGHT UTXO |
| `value` | `BYTEA NOT NULL` | `BLOB NOT NULL` | DUST amount |
| `owner` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Recipient address |
| `nonce` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `ctime` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Creation time |
| `merkle_index` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Position in generation tree |
| `dtime` | `BIGINT` | `INTEGER` | Nullable; distribution time |
| `transaction_id` | `BIGINT` | `INTEGER` | **FK → `transactions(id)`**, nullable |
| `generation_index` | `BIGINT` | `INTEGER` | Nullable; added by migration 2 — position in the generation-tree for subscriptions |
| `backing_night` | `BYTEA` | `BLOB` | Nullable; added by migration 2 |
| `initial_value` | `BYTEA` | `BLOB` | Nullable; added by migration 2 |

Indexes: `(owner)`, `(night_utxo_hash)`, `(transaction_id)`,
`(owner, generation_index)` (added by migration 2).

#### `dust_nullifiers`

Source: `postgres/001_initial.sql:175`, `sqlite/001_initial.sql:176`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `nullifier` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `commitment` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `transaction_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `transactions(id)`** |
| `block_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `blocks(id)`** |

Indexes: `(nullifier)`, `(transaction_id)`, `(block_id)`.

#### `zswap_nullifiers`

Source: `postgres/001_initial.sql:186`, `sqlite/001_initial.sql:187`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `transaction_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `transactions(id)`** |
| `block_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `blocks(id)`** |
| `nullifier` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |

Indexes: `(nullifier)`, `(transaction_id)`, `(block_id)`.

#### `cnight_registrations`

Source: `postgres/001_initial.sql:197`, `sqlite/001_initial.sql:197`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `cardano_stake_key` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `dust_address` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `valid` | `BOOLEAN NOT NULL` | `BOOLEAN NOT NULL` | |
| `registered_at` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `removed_at` | `BIGINT` | `INTEGER` | Nullable |
| `block_id` | `BIGINT` | `INTEGER` | **FK → `blocks(id)`**, nullable |
| `utxo_tx_hash` | `BYTEA` | `BLOB` | Nullable; Cardano UTXO reference |
| `utxo_output_index` | `BIGINT` | `INTEGER` | Nullable |

Unique constraint: `(cardano_stake_key, dust_address)`.  
Indexes: `(cardano_stake_key)`, `(dust_address)`, `(block_id)`.

---

### Wallet tables

#### `wallets`

Source: `postgres/001_initial.sql:135`, `sqlite/001_initial.sql:136`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `UUID` | `BLOB` | **PK**; Postgres uses native UUID, SQLite stores as BLOB |
| `viewing_key_hash` | `BYTEA NOT NULL UNIQUE` | `BLOB NOT NULL UNIQUE` | Fast lookup key |
| `viewing_key` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Ciphertext + nonce; comment notes no longer unique |
| `wanted_start_index` | `BIGINT NOT NULL DEFAULT 0` | `INTEGER NOT NULL DEFAULT 0` | |
| `first_indexed_transaction_id` | `BIGINT NOT NULL DEFAULT 0` | `INTEGER NOT NULL DEFAULT 0` | |
| `last_indexed_transaction_id` | `BIGINT NOT NULL DEFAULT 0` | `INTEGER NOT NULL DEFAULT 0` | |
| `last_active` | `TIMESTAMPTZ NOT NULL` | `INTEGER NOT NULL` | Postgres uses timestamptz; SQLite stores as INTEGER (unix ms) |
| `session_id` | `BYTEA UNIQUE` | `BLOB UNIQUE` | Nullable; per-session auth token |

Indexes: `(viewing_key_hash)`, `(last_indexed_transaction_id DESC)`.

#### `relevant_transactions`

Source: `postgres/001_initial.sql:150`, `sqlite/001_initial.sql:151`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `wallet_id` | `UUID NOT NULL` | `BLOB NOT NULL` | **FK → `wallets(id)`** |
| `transaction_id` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | **FK → `transactions(id)`** |

Unique constraint: `(wallet_id, transaction_id)`.

---

### Governance and system-parameter tables

#### `system_parameters_d`

Source: `postgres/001_initial.sql:220`, `sqlite/001_initial.sql:221`

Holds only the D-parameter (permissioned/registered candidate counts).
One row per parameter-change event.

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `block_height` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `block_hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `timestamp` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `num_permissioned_candidates` | `INTEGER NOT NULL` | `INTEGER NOT NULL` | |
| `num_registered_candidates` | `INTEGER NOT NULL` | `INTEGER NOT NULL` | |

Index: `(block_height DESC)`.

#### `system_parameters_terms_and_conditions`

Source: `postgres/001_initial.sql:211`, `sqlite/001_initial.sql:212`

History of T&C changes. A separate table from `system_parameters_d` — not
a combined "system parameters" row.

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `block_height` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `block_hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | |
| `timestamp` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `hash` | `BYTEA NOT NULL` | `BLOB NOT NULL` | Content hash of the T&C document |
| `url` | `TEXT NOT NULL` | `TEXT NOT NULL` | Link to T&C document |

Index: `(block_height DESC)`.

#### `epochs`

Source: `postgres/001_initial.sql:232`, `sqlite/001_initial.sql:233`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `epoch_no` | `BIGINT` | `INTEGER` | **PK** |
| `starts_at` | `TIMESTAMPTZ NOT NULL` | `TEXT NOT NULL` | Postgres uses timestamptz; SQLite stores as TEXT |
| `ends_at` | `TIMESTAMPTZ NOT NULL` | `TEXT NOT NULL` | Same |

---

### SPO (Stake Pool Operator) tables

#### `pool_metadata_cache`

Source: `postgres/001_initial.sql:241`, `sqlite/001_initial.sql:242`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `pool_id` | `VARCHAR` | `TEXT` | **PK** |
| `hex_id` | `VARCHAR UNIQUE` | `TEXT UNIQUE` | Hex-encoded pool ID |
| `name` | `TEXT` | `TEXT` | Nullable |
| `ticker` | `TEXT` | `TEXT` | Nullable |
| `homepage_url` | `TEXT` | `TEXT` | Nullable |
| `updated_at` | `TIMESTAMPTZ` | `TEXT` | Nullable |
| `url` | `TEXT` | `TEXT` | Nullable; metadata URL |

#### `spo_identity`

Source: `postgres/001_initial.sql:252`, `sqlite/001_initial.sql:254`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `spo_sk` | `VARCHAR` | `TEXT` | **PK** |
| `sidechain_pubkey` | `VARCHAR UNIQUE` | `TEXT UNIQUE` | Nullable |
| `pool_id` | `VARCHAR` | `TEXT` | **FK → `pool_metadata_cache(pool_id)`**, nullable |
| `mainchain_pubkey` | `VARCHAR UNIQUE` | `TEXT UNIQUE` | Nullable |
| `aura_pubkey` | `VARCHAR UNIQUE` | `TEXT UNIQUE` | Nullable |

Index: `(pool_id, sidechain_pubkey, aura_pubkey)`.

#### `committee_membership`

Source: `postgres/001_initial.sql:263`, `sqlite/001_initial.sql:264`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `spo_sk` | `VARCHAR` | `TEXT` | No FK declared |
| `sidechain_pubkey` | `VARCHAR` | `TEXT` | No FK declared |
| `epoch_no` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Part of composite **PK** |
| `position` | `INT NOT NULL` | `INTEGER NOT NULL` | Part of composite **PK** |
| `expected_slots` | `INT NOT NULL` | `INTEGER NOT NULL` | |

PK: `(epoch_no, position)`. Index: `(epoch_no)`.

#### `spo_epoch_performance`

Source: `postgres/001_initial.sql:274`, `sqlite/001_initial.sql:277`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `spo_sk` | `VARCHAR` | `TEXT` | Part of composite **PK**; **FK → `spo_identity(spo_sk)`** |
| `identity_label` | `VARCHAR` | `TEXT` | Nullable |
| `epoch_no` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | Part of composite **PK** |
| `expected_blocks` | `INT NOT NULL` | `INTEGER NOT NULL` | |
| `produced_blocks` | `INT NOT NULL` | `INTEGER NOT NULL` | |

PK: `(epoch_no, spo_sk)`. Indexes: `(epoch_no, identity_label)`, `(epoch_no)`.

#### `spo_history`

Source: `postgres/001_initial.sql:288`, `sqlite/001_initial.sql:289`

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `spo_hist_sk` | `BIGSERIAL` | `INTEGER` | **PK** (auto-increment) |
| `spo_sk` | `VARCHAR` | `TEXT` | **FK → `spo_identity(spo_sk)`**, nullable |
| `epoch_no` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `status` | `TEXT NOT NULL` | `TEXT NOT NULL` | |
| `valid_from` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |
| `valid_to` | `BIGINT NOT NULL` | `INTEGER NOT NULL` | |

Unique constraint: `(spo_sk, epoch_no)`. Index: `(epoch_no)`.

#### `spo_stake_snapshot`

Source: `postgres/001_initial.sql:302`, `sqlite/001_initial.sql:303`

After SQLite migration 003, stake columns change from `REAL` to `INTEGER`.

| Column | Postgres type | SQLite type (final) | Notes |
|--------|--------------|---------------------|-------|
| `pool_id` | `VARCHAR` | `TEXT` | **PK**; **FK → `pool_metadata_cache(pool_id)` ON DELETE CASCADE** |
| `live_stake` | `NUMERIC` | `INTEGER` | Nullable; lovelace; SQLite was `REAL` before migration 003 |
| `active_stake` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |
| `live_delegators` | `INT` | `INTEGER` | Nullable |
| `live_saturation` | `DOUBLE PRECISION` | `REAL` | Nullable; fraction — below 2^53 concern |
| `declared_pledge` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |
| `live_pledge` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |
| `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | `TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP` | |

Indexes: `(updated_at DESC)`, `(COALESCE(live_stake, 0) DESC)`.

#### `spo_stake_history`

Source: `postgres/001_initial.sql:317`, `sqlite/001_initial.sql:317`

After SQLite migration 003, stake columns change from `REAL` to `INTEGER`.

| Column | Postgres type | SQLite type (final) | Notes |
|--------|--------------|---------------------|-------|
| `id` | `BIGSERIAL` | `INTEGER` | **PK** |
| `pool_id` | `VARCHAR NOT NULL` | `TEXT NOT NULL` | **FK → `pool_metadata_cache(pool_id)` ON DELETE CASCADE** |
| `recorded_at` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | `TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP` | |
| `mainchain_epoch` | `INTEGER` | `INTEGER` | Nullable |
| `live_stake` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |
| `active_stake` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |
| `live_delegators` | `INTEGER` | `INTEGER` | Nullable |
| `live_saturation` | `DOUBLE PRECISION` | `REAL` | Nullable |
| `declared_pledge` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |
| `live_pledge` | `NUMERIC` | `INTEGER` | Nullable; SQLite was `REAL` before migration 003 |

Indexes: `(pool_id, recorded_at DESC)`, `(mainchain_epoch)`.

#### `spo_stake_refresh_state`

Source: `postgres/001_initial.sql:333`, `sqlite/001_initial.sql:334`

Singleton control table for the stake-refresh worker. Seeded with one row on
creation (`id = TRUE` / `1`).

| Column | Postgres type | SQLite type | Notes |
|--------|--------------|-------------|-------|
| `id` | `BOOLEAN PRIMARY KEY DEFAULT TRUE` | `INTEGER PRIMARY KEY DEFAULT 1` | Always one row |
| `last_pool_id` | `VARCHAR` | `TEXT` | Nullable; last pool processed in current sweep |
| `updated_at` | `TIMESTAMPTZ NOT NULL DEFAULT NOW()` | `TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP` | |

---

## Foreign-key map

```text
blocks (id)
  ←── transactions.block_id                    [001_initial.sql:35]
  ←── dust_nullifiers.block_id                 [001_initial.sql:180]
  ←── zswap_nullifiers.block_id                [001_initial.sql:189]
  ←── cnight_registrations.block_id (nullable) [001_initial.sql:203]

transactions (id)
  ←── regular_transactions.id (PK+FK)          [001_initial.sql:48]
  ←── contract_actions.transaction_id          [001_initial.sql:70]  ← FK to transactions, not regular_transactions
  ←── unshielded_utxos.creating_transaction_id [001_initial.sql:85]  ← FK to transactions, not contract_actions
  ←── unshielded_utxos.spending_transaction_id [001_initial.sql:86]  ← FK to transactions, not contract_actions
  ←── ledger_events.transaction_id             [001_initial.sql:108]
  ←── relevant_transactions.transaction_id     [001_initial.sql:153]
  ←── dust_generation_info.transaction_id      [001_initial.sql:170]
  ←── dust_nullifiers.transaction_id           [001_initial.sql:179]
  ←── zswap_nullifiers.transaction_id          [001_initial.sql:188]

contract_actions (id)
  ←── contract_balances.contract_action_id     [001_initial.sql:124]  ← only table FK'd to contract_actions

wallets (id)
  ←── relevant_transactions.wallet_id          [001_initial.sql:152]

pool_metadata_cache (pool_id)
  ←── spo_identity.pool_id (nullable)          [001_initial.sql:255]
  ←── spo_stake_snapshot.pool_id (CASCADE)     [001_initial.sql:302]
  ←── spo_stake_history.pool_id (CASCADE)      [001_initial.sql:318]

spo_identity (spo_sk)
  ←── spo_epoch_performance.spo_sk             [001_initial.sql:276]
  ←── spo_history.spo_sk (nullable)            [001_initial.sql:291]

regular_transactions (id)
  ←── transaction_identifiers.transaction_id   [sqlite/001_initial.sql:54]  ← SQLite only
```

All line numbers reference `postgres/001_initial.sql` unless prefixed.

---

## ER diagram

```text
┌─────────────────┐
│  ledger_db_nodes│  (separate DB)
│  ledger_db_roots│
└─────────────────┘

  ┌──────────────────────────────────────────────────────────────────┐
  │                           blocks                                 │
  │  id PK | hash | height | timestamp | ledger_state_key            │
  │  zswap_end_index | dust_commitment_end_index                     │
  │  dust_generation_end_index  (added migration 3/4)                │
  └────────┬─────────────────────────────────────────┬──────────────┘
           │ block_id                                 │ block_id
           ▼                                          │
  ┌──────────────────────────┐              ┌─────────┴──────────────┐
  │       transactions       │              │    dust_nullifiers      │
  │  id PK | variant | hash  │              │  (also → transactions) │
  └──┬──────────┬────────────┘              ├────────────────────────┤
     │ id (1:1) │                           │    zswap_nullifiers     │
     │          │                           │  (also → transactions) │
     ▼          ▼                           ├────────────────────────┤
  ┌──────────────────┐                      │  cnight_registrations  │
  │regular_transactions│                    └────────────────────────┘
  │  (extends tx 1:1) │
  │  identifiers[]    │──────────────── [SQLite only] ──────────────────┐
  └──────────────────┘                                                   │
                                                                         ▼
     transactions.id ◄──────────────────────────────── transaction_identifiers
                                                        (SQLite only)

     transactions.id ◄──────── contract_actions.transaction_id
                                        │
                                        │ contract_action_id
                                        ▼
                               contract_balances

     transactions.id ◄──────── unshielded_utxos.creating_transaction_id
     transactions.id ◄──────── unshielded_utxos.spending_transaction_id (nullable)

     transactions.id ◄──────── ledger_events.transaction_id

     transactions.id ◄──────── dust_generation_info.transaction_id (nullable)

  ┌────────────────────────┐
  │        wallets         │
  │  id PK (UUID / BLOB)   │
  └───────────┬────────────┘
              │ wallet_id
              ▼
  ┌─────────────────────────┐
  │  relevant_transactions  │
  │  → transactions(id)     │
  └─────────────────────────┘

  ┌─────────────────────────┐
  │   system_parameters_d   │  (D-parameter only)
  │   block_height | ...    │
  └─────────────────────────┘
  ┌──────────────────────────────────────────┐
  │ system_parameters_terms_and_conditions   │  (T&C history; separate table)
  │   block_height | hash | url | ...        │
  └──────────────────────────────────────────┘
  ┌───────────────────┐
  │      epochs       │
  │  epoch_no PK      │
  └───────────────────┘

  ┌────────────────────────┐
  │   pool_metadata_cache  │◄──── spo_identity.pool_id
  │   pool_id PK           │◄──── spo_stake_snapshot.pool_id (CASCADE)
  └────────────────────────┘◄──── spo_stake_history.pool_id  (CASCADE)

  ┌────────────────────────┐
  │     spo_identity       │◄──── spo_epoch_performance.spo_sk
  │     spo_sk PK          │◄──── spo_history.spo_sk (nullable)
  └────────────────────────┘

  ┌──────────────────────┐   ┌──────────────────────┐
  │  spo_stake_snapshot  │   │   spo_stake_history  │
  │  (one row / pool)    │   │  (time-series rows)  │
  └──────────────────────┘   └──────────────────────┘
  ┌──────────────────────┐
  │  spo_stake_refresh_  │
  │      state           │  (singleton)
  └──────────────────────┘
  ┌──────────────────────┐
  │ committee_membership │  (no declared FKs)
  └──────────────────────┘
```

---

## Postgres vs SQLite differences

| Aspect | Postgres | SQLite |
|--------|----------|--------|
| Migration count | 4 files (000–003) | 5 files (000 in separate dir, 001–004) |
| Migration 003 | Block tree end-indexes | SPO stake REAL→INTEGER rebuild |
| Migration 4 (SQLite only) | — | Block tree end-indexes |
| ENUM types | `CONTRACT_ACTION_VARIANT`, `LEDGER_EVENT_VARIANT`, `LEDGER_EVENT_GROUPING`, `TRANSACTION_VARIANT` | Not supported; replaced with `TEXT CHECK(...)` constraints |
| `regular_transactions.identifiers` | `BYTEA[] NOT NULL` (array column) | No array support; normalized into `transaction_identifiers` join table |
| `blocks.height` | `BIGINT NOT NULL UNIQUE` | `INTEGER NOT NULL` (no UNIQUE — omitted) |
| `transaction_result` | `JSONB NOT NULL` with B-tree + GIN indexes | `TEXT NOT NULL` with B-tree index only |
| Timestamp columns | `TIMESTAMPTZ` (`wallets.last_active`, `epochs.*_at`, SPO timestamps) | Stored as `INTEGER` or `TEXT` |
| `wallets.id` | `UUID` | `BLOB` |
| `spo_stake_snapshot` / `spo_stake_history` stake columns | `NUMERIC` | Initially `REAL`; migration 003 rebuilds tables to `INTEGER` to avoid f64 precision loss on lovelace > 2^53 |
| Ledger-DB | Shared Postgres schema | Separate `sqlite-ledger-db/` migration dir and DB file |
| Auto-increment | `BIGSERIAL` / `SERIAL` | `INTEGER PRIMARY KEY` (SQLite autoincrement) |
| `spo_stake_refresh_state.id` | `BOOLEAN PRIMARY KEY DEFAULT TRUE` | `INTEGER PRIMARY KEY DEFAULT 1` |

---

## Table count

**Application DB:** 24 tables  
(blocks, transactions, regular_transactions, contract_actions, contract_balances,
unshielded_utxos, ledger_events, dust_generation_info, dust_nullifiers,
zswap_nullifiers, cnight_registrations, system_parameters_d,
system_parameters_terms_and_conditions, epochs, wallets, relevant_transactions,
pool_metadata_cache, spo_identity, committee_membership, spo_epoch_performance,
spo_history, spo_stake_snapshot, spo_stake_history, spo_stake_refresh_state)

**SQLite-only additional table:** 1  
(transaction_identifiers — normalizes `regular_transactions.identifiers[]`)

**Ledger DB (separate):** 2 tables  
(ledger_db_nodes, ledger_db_roots)

**Total across all schemas:** 27 tables (24 application + 1 SQLite-only + 2 ledger-DB)

---

## Cross-references

- `references/dust-and-spo-data.md` — deep-dive into the DUST generation
  lifecycle, cNIGHT registrations, SPO stake refresh flow, and
  `spo_stake_integer` precision rationale
- `indexer-data-model` SKILL.md — conceptual overview and query patterns built
  on this schema
- `compact-core:compact-transaction-model` — the guaranteed/fallible execution
  phases behind `regular_transactions.transaction_result`
  (SUCCESS / PARTIAL_SUCCESS / FAILURE)
- `midnight-indexer:indexer-graphql-api` — GraphQL surface that queries these
  tables (subscription cursors map directly to `*_start_index`/`*_end_index`
  columns on `regular_transactions` and `blocks`)
