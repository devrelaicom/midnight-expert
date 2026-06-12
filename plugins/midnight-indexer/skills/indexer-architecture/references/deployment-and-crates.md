# Deployment Modes and Component Crates

The indexer workspace (`4.3.3`, edition 2024) contains seven Cargo members. Each crate has a `cloud` and/or `standalone` Cargo feature that drives conditional compilation; neither feature is a default — the correct one must be passed at build time (`--features cloud` or `--features standalone`). A binary whose feature is absent compiles to `unimplemented!()` in `main`.

## Workspace Members at a Glance

(`Cargo.toml` workspace `members` array, lines 3–11)

| Crate | Kind | Shipped binary | Feature gates |
|---|---|---|---|
| `indexer-common` | Library (no `main.rs`) | — | `cloud`, `standalone` |
| `chain-indexer` | Binary | `chain-indexer` | `cloud` only |
| `wallet-indexer` | Binary | `wallet-indexer` | `cloud` only |
| `indexer-api` | Binary + helper bin | `indexer-api`, `indexer-api-cli` | `cloud` only |
| `indexer-standalone` | Binary | `indexer-standalone` | `standalone` only |
| `spo-indexer` | Binary | `spo-indexer` | `cloud` **and** `standalone` |
| `indexer-tests` | Binary (test harness) | `indexer-tests` | `cloud`, `standalone` |

## Crate Descriptions

### `indexer-common`

Shared library. No `main.rs`. Provides:

- **Domain types** — `BlockIndexed`, `WalletIndexed`, `UnshieldedUtxoIndexed`, `LedgerState`, transaction types, `NetworkId`, viewing-key types (`indexer-common/src/domain/`).
- **Pub-sub abstraction** — the `Publisher` and `Subscriber` traits (`indexer-common/src/domain/pub_sub.rs`) with two concrete implementations selected by feature: `in_mem` (standalone) and `nats` (cloud) (`indexer-common/src/infra/pub_sub.rs`).
- **Storage infrastructure** — SQLite and Postgres pool wrappers, SQLx helpers, migration runners (`indexer-common/src/infra/pool/`, `indexer-common/src/infra/migrations/`).
- **Ledger DB** — the `LedgerDb` struct and `init` function (`indexer-common/src/infra/ledger_db.rs`) that back the `midnight-storage-core` content-addressed store.
- **Telemetry** — logforth, fastrace, OpenTelemetry, Prometheus metrics setup.

`cloud` feature activates `async-nats`, `serde_with`, and `sqlx/postgres`. `standalone` activates `sqlx/sqlite` (`indexer-common/Cargo.toml`, features block).

### `chain-indexer`

Connects to a Midnight Node over WebSocket (`subxt`) and writes blocks and transactions to the storage DB. Publishes a `BlockIndexed` event after each block is committed so that downstream components can react.

**Cloud binary only.** `main.rs` is `#[cfg(feature = "cloud")]`; without `--features cloud` the binary compiles to `unimplemented!()` (`chain-indexer/src/main.rs:14–36`).

At startup it creates a `PostgresPool`, runs Postgres migrations, initialises `LedgerDb` against the same pool, then constructs a `NatsPublisher` and calls `application::run` (`chain-indexer/src/main.rs:39–117`).

Default config: `ws://localhost:9944`, Postgres on `localhost:5432`, NATS on `localhost:4222` (`chain-indexer/config.yaml`).

### `wallet-indexer`

Consumes `BlockIndexed` events from the message bus, then resolves which registered wallets have relevant transactions in that block and stores per-wallet state. Publishes `WalletIndexed` events so `indexer-api` can push live updates.

**Cloud binary only.** `main.rs` is `#[cfg(feature = "cloud")]` (`wallet-indexer/src/main.rs:14`). Creates both a `NatsPublisher` and a `NatsSubscriber` (`wallet-indexer/src/main.rs:92–96`).

### `indexer-api`

Serves the GraphQL API (queries, mutations, subscriptions) over HTTP/2 via axum and async-graphql. Subscribes to `BlockIndexed` and `WalletIndexed` events to push live subscription updates to connected clients.

**Cloud binary only** for the main binary. Also ships a helper binary `indexer-api-cli` (built unconditionally) that exposes a single subcommand, `print-api-schema-v4`, for introspecting the GraphQL schema without running the full service (`indexer-api/src/bin/indexer-api-cli.rs`).

Main binary entrypoint is `#[cfg(feature = "cloud")]`; creates a `NatsSubscriber` and an `AxumApi` (`indexer-api/src/main.rs:14–120`). Listens on `0.0.0.0:8088` by default.

### `indexer-standalone`

Single binary that runs all four indexing components — chain-indexer, wallet-indexer, indexer-api, and spo-indexer — in a shared Tokio runtime within one process.

**Standalone feature only.** `main.rs` is `#[cfg(feature = "standalone")]` (`indexer-standalone/src/main.rs:17`). The `run()` function:

1. Creates a single `SqlitePool` for the main storage DB.
2. Calls `ledger_db::init(ledger_db_config)` to open the separate SQLite ledger DB.
3. Creates an `InMemPubSub` (Tokio broadcast channels).
4. Spawns four `tokio::task::spawn` handles — one per component — sharing the same pool and pub-sub factory (`indexer-standalone/src/main.rs:135–183`).
5. Uses `tokio::select!` so that if any component task exits or panics the process exits (`indexer-standalone/src/main.rs:185–190`).

The crate's own `config.rs` aggregates all four component configs into a unified `Config` struct and delegates each sub-config to the appropriate `From` impl (`indexer-standalone/src/config.rs`).

The Docker image is built with `cargo build -p indexer-standalone --features standalone` and the entrypoint script in `bin/entrypoint.sh` forwards SIGTERM/SIGINT and writes a `/var/run/indexer-standalone/running` file used by Docker's healthcheck.

### `spo-indexer`

Indexes Stake Pool Operator (SPO) data — pool registrations, epoch performance, committee membership, and Blockfrost-sourced stake snapshots. Uses `subxt` for on-chain data and the `blockfrost` crate for stake data queries.

**Supports both `cloud` and `standalone` features.** `main.rs` is `#[cfg(any(feature = "cloud", feature = "standalone"))]` (`spo-indexer/src/main.rs:14`). Unlike the other cloud services, `spo-indexer` does **not** participate in the NATS pub-sub bus in either mode (`spo-indexer/Cargo.toml` has no `async-nats` dependency). In cloud mode it uses `PostgresPool`; in standalone mode it uses the same `SqlitePool` passed from `indexer-standalone` (`spo-indexer/src/main.rs:79–103`).

Default cloud config points at `wss://rpc.preview.midnight.network` and requires a `blockfrost_id` API key (`spo-indexer/config.yaml`). The key can be any non-empty placeholder in standalone mode if SPO features are not needed (`indexer-standalone/config.yaml`, comment on `spo_node.blockfrost_id`).

### `indexer-tests`

End-to-end test harness. Produces a `indexer-tests` binary (no Docker-profile restriction) that accepts `--network-id`, `--host`, `--port`, and `--secure` flags and runs GraphQL/WebSocket e2e scenarios against a live indexer-api endpoint (`indexer-tests/src/main.rs`). Not a runtime component; used in CI and manual QA against both standalone and cloud deployments.

## Deployment Modes

### Standalone Mode

```text
  ┌─────────────────────────────────────────────────────────┐
  │               indexer-standalone binary                 │
  │                                                         │
  │  chain-indexer task ──publishes──▶ InMemPubSub          │
  │  spo-indexer task                      │                │
  │  wallet-indexer task ◀──subscribes─────┤                │
  │  indexer-api task   ◀──subscribes──────┘                │
  │                                                         │
  │  SqlitePool: /data/indexer.sqlite  (main storage DB)    │
  │  SqlitePool: /data/ledger-db.sqlite (ledger DB)         │
  └─────────────────────────────────────────────────────────┘
           │ ws://…:9944
        Midnight Node
```

One process, one Docker image (`midnightntwrk/indexer-standalone`). The pub-sub bus is `InMemPubSub` — three `tokio::sync::broadcast` channels (capacity 42 each) for `BlockIndexed`, `WalletIndexed`, and `UnshieldedUtxoIndexed` topics (`indexer-common/src/infra/pub_sub/in_mem.rs:27–43`). No external message broker is required.

### Cloud Mode

```text
  chain-indexer ──NATS──▶ wallet-indexer
        │                       │
        ▼                       ▼
    PostgreSQL  ◀───────── indexer-api ──▶ GraphQL clients
        ▲
  spo-indexer (no NATS)
```

Four separate Docker images, each built with `--features cloud`. All share a single PostgreSQL database (`indexer` db, `indexer` user by default). `chain-indexer`, `wallet-indexer`, and `indexer-api` connect to NATS (default `localhost:4222`) for event routing. `spo-indexer` writes directly to Postgres with no NATS involvement.

Docker profiles in `docker-compose.yaml`: `cloud` services — `chain-indexer`, `wallet-indexer`, `indexer-api`, `spo-indexer`, `postgres`, `nats`; `standalone` services — `indexer-standalone`. The `node` service is in both profiles (`docker-compose.yaml:143–177`). For running the local devnet see `midnight-tooling:devnet`.

## The Two Databases

Every deployment uses two logically distinct storage layers. Their relationship is:

| | Main storage DB | Ledger DB |
|---|---|---|
| Purpose | Application data — blocks, transactions, contract actions, wallet sessions, SPO records | Content-addressed node store for `midnight-storage-core`: ledger state Merkle tree nodes and root reference counts |
| Tables | `blocks`, `transactions`, `regular_transactions`, `contract_actions`, `wallets`, `spo_*`, … | `ledger_db_nodes`, `ledger_db_roots` |
| Standalone backend | SQLite at `infra.storage.cnn_url` (default `/data/indexer.sqlite`) | SQLite at `infra.ledger_db.cnn_url` (default `/data/ledger-db.sqlite`) |
| Cloud backend | Postgres — `infra.storage.*` host/port/dbname | Same Postgres database — `ledger_db_nodes`/`ledger_db_roots` tables are created by the `000_ledger_db.sql` migration, which runs as the first file in `migrations/postgres/` |
| Config key | `infra.storage` | `infra.ledger_db` |
| `cache_size` setting | N/A | Yes — controls the in-memory LRU cache size in front of the DB (default `"1kiB"` across all configs) |
| Separate `cnn_url` | Yes (standalone only) | Yes (standalone only — `infra.ledger_db.cnn_url`); cloud shares the Postgres pool |

### Why Two Databases?

The main storage DB holds queryable application records indexed and surfaced via the GraphQL API. The ledger DB backs the `midnight-storage-core` content-addressed arena used during block processing to materialise and verify ledger state. It is written and read internally during transaction application; its contents are not exposed through the GraphQL API. Keeping them separate in standalone mode allows the ledger DB to use different SQLite tuning (e.g. WAL mode, page size) and be wiped independently without affecting application data.

In standalone mode `ledger_db::init` opens a fresh SQLitePool against `cnn_url`, runs the `migrations/sqlite-ledger-db/` migrations (only `000_ledger_db.sql`), then registers the `LedgerDb` as the global `midnight_storage_core_v1` default storage (`indexer-common/src/infra/ledger_db.rs:31–47`).

In cloud mode `ledger_db::init` receives the existing `PostgresPool` — no `cnn_url` field exists in the cloud `Config` — and the `ledger_db_nodes`/`ledger_db_roots` tables are created by the standard Postgres migration run (`indexer-common/src/infra/ledger_db.rs:21–28`; `indexer-common/migrations/postgres/000_ledger_db.sql`).

## Pub-Sub Implementation Selection

The `indexer-common/src/infra/pub_sub.rs` module exposes either `in_mem` or `nats` depending on the active feature:

```rust
// indexer-common/src/infra/pub_sub.rs
#[cfg(feature = "standalone")]
pub mod in_mem;
#[cfg(feature = "cloud")]
pub mod nats;
```

`InMemPubSub` uses `tokio::sync::broadcast` channels. `NatsPublisher`/`NatsSubscriber` use `async-nats` (version 0.47). See `references/nats-messaging.md` for NATS subject naming, authentication, and JetStream configuration.

## Cross-references

- `midnight-indexer:indexer-architecture` — top-level skill covering the full data-flow model
- `references/nats-messaging.md` — NATS subject names, authentication, and JetStream details (cloud mode)
- `midnight-tooling:devnet` — running and managing the local devnet Docker Compose stack that includes `midnight-node`
