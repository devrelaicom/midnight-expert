# Indexer Configuration Reference

Complete `APP__*` environment variable and YAML key reference for all indexer components (v4.3.3). Covers every configurable field, grouped by config section, with defaults sourced from `config.yaml` files or `#[serde(default = …)]` impls.

## Environment-Variable Mapping Rule

All configuration can be set via environment variables. The rules are:

1. Prefix every key with `APP__`.
2. Replace each `.` (YAML nesting level) with `__` (double underscore).
3. Uppercase the entire name.

```text
YAML path                    → ENV VAR
─────────────────────────────────────────────────────────────
application.network_id       → APP__APPLICATION__NETWORK_ID
infra.api.port               → APP__INFRA__API__PORT
infra.storage.host           → APP__INFRA__STORAGE__HOST
infra.pub_sub.password       → APP__INFRA__PUB_SUB__PASSWORD
telemetry.tracing.enabled    → APP__TELEMETRY__TRACING__ENABLED
```

### Loader Library and Precedence

The loader is **[figment](https://docs.rs/figment)** (`figment::Figment`). The load sequence is:

```text
config.yaml (base)
  then merged with
APP__* environment variables (overlay — wins on conflict)
```

Source: `indexer-common/src/config.rs:36–39`

```rust
Figment::new()
    .merge(config_file)         // YAML file (base)
    .merge(Env::prefixed("APP__").split("__"))  // env overlay
    .extract()
```

The YAML file path defaults to `config.yaml` in the working directory. Override it by setting the `CONFIG_FILE` environment variable to an absolute path (`indexer-common/src/config.rs:21–34`).

---

## Per-Binary Config Scope

Each binary reads its own `config.yaml`. Not all sections exist in every binary.

| Section | `indexer-standalone` | `chain-indexer` | `wallet-indexer` | `indexer-api` | `spo-indexer` |
|---|---|---|---|---|---|
| `thread_stack_size` | yes | yes | — | yes | — |
| `application` | yes | yes (subset) | yes (subset) | yes (subset) | yes (different) |
| `spo` | yes | — | — | — | — |
| `infra.run_migrations` | yes | yes (cloud) | yes (cloud) | yes (cloud) | yes (top-level) |
| `infra.storage` | SQLite | Postgres | Postgres | Postgres | Postgres/SQLite |
| `infra.ledger_db` | yes | yes | yes | yes | — |
| `infra.node` | yes | yes | — | — | as `infra.spo_node` |
| `infra.spo_node` | yes | — | — | — | — |
| `infra.pub_sub` | — | yes (cloud) | yes (cloud) | yes (cloud) | — |
| `infra.api` | yes | — | — | yes | — |
| `infra.secret` | yes | — | yes (cloud) | yes (cloud) | — |
| `telemetry` | yes | yes | yes | yes | yes |

---

## `thread_stack_size`

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__THREAD_STACK_SIZE` | `thread_stack_size` | `"24MiB"` | Tokio thread stack size; parsed with `byte_unit_serde` |

Source: `indexer-standalone/config.yaml:1`, `chain-indexer/config.yaml:1`, `indexer-api/config.yaml:1`.

---

## `application` Section

Used by `indexer-standalone`, `chain-indexer` (subset), `wallet-indexer` (subset), and `indexer-api` (subset). The `application` section in `spo-indexer` is structurally different — see the `spo` section below.

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__APPLICATION__NETWORK_ID` | `application.network_id` | `"undeployed"` | Network identifier string; e.g. `"testnet-02"` |
| `APP__APPLICATION__BLOCKS_BUFFER` | `application.blocks_buffer` | `10` | In-memory ring buffer size for block pipeline backpressure |
| `APP__APPLICATION__CAUGHT_UP_MAX_DISTANCE` | `application.caught_up_max_distance` | `10` | Block distance from tip before service reports itself as caught up |
| `APP__APPLICATION__CAUGHT_UP_LEEWAY` | `application.caught_up_leeway` | `5` | Hysteresis leeway for the caught-up state machine |
| `APP__APPLICATION__ACTIVE_WALLETS_QUERY_DELAY` | `application.active_wallets_query_delay` | `"500ms"` | How long wallet-indexer sleeps between active-wallet polls |
| `APP__APPLICATION__ACTIVE_WALLETS_TTL` | `application.active_wallets_ttl` | `"30m"` | Time after which an idle wallet is evicted from the active set |
| `APP__APPLICATION__TRANSACTION_BATCH_SIZE` | `application.transaction_batch_size` | `50` | Number of transactions per indexing batch per wallet |
| `APP__APPLICATION__CONCURRENCY_LIMIT` | `application.concurrency_limit` | see below | Max concurrent wallet-indexing tasks |

**`concurrency_limit` defaults** differ by binary:
- `indexer-standalone`: `NonZeroUsize::MIN` (= 1) — `indexer-standalone/src/config.rs:173–174`
- `wallet-indexer` (cloud): `std::thread::available_parallelism().unwrap_or(NonZeroUsize::MIN)` (number of logical CPUs) — `wallet-indexer/src/application.rs:353–354`
- The YAML comment in `wallet-indexer/config.yaml:6` states: `# Number of cores by default.`

**Per-binary presence of `application` fields:**

- `blocks_buffer`, `caught_up_max_distance`, `caught_up_leeway` — used by `chain-indexer` and `indexer-standalone`; absent from `wallet-indexer/config.yaml`.
- `active_wallets_*`, `transaction_batch_size`, `concurrency_limit` — used by `wallet-indexer` and `indexer-standalone`; absent from `chain-indexer/config.yaml`.
- `network_id` — used by all except `wallet-indexer` directly (it passes through from the merged config in standalone).

Sources: `indexer-standalone/config.yaml:3–12`, `chain-indexer/config.yaml:3–8`, `wallet-indexer/config.yaml:1–7`.

---

## `spo` Section

Used only by `indexer-standalone`. The `spo-indexer` binary uses equivalent keys under `application` in its own config (a structural difference — see note).

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__SPO__INTERVAL` | `spo.interval` | `5000` | Poll interval in milliseconds between SPO epoch cycles |
| `APP__SPO__STAKE_REFRESH__PERIOD_SECS` | `spo.stake_refresh.period_secs` | `900` | Seconds between stake-snapshot refreshes (15 minutes) |
| `APP__SPO__STAKE_REFRESH__PAGE_SIZE` | `spo.stake_refresh.page_size` | `100` | Pool count per Blockfrost page during stake refresh |
| `APP__SPO__STAKE_REFRESH__MAX_RPS` | `spo.stake_refresh.max_rps` | `2` | Max Blockfrost requests per second to avoid HTTP 402 errors |

The `#[serde(default)]` on `SpoApplicationConfig` in `indexer-standalone/src/config.rs:33` provides the code-level defaults; the YAML values in `indexer-standalone/config.yaml:14–19` match them exactly.

For `spo-indexer` standalone binary, all SPO fields live under `application.interval`, `application.stake_refresh.*` (`spo-indexer/config.yaml`).

---

## `infra.run_migrations`

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__RUN_MIGRATIONS` | `infra.run_migrations` | `true` | Run SQLx database migrations at startup |

Present in all cloud binaries under `infra`. Exception: `spo-indexer` places `run_migrations` at the **top level** of its config (not under `infra`) — `spo-indexer/src/config.rs:18`, `spo-indexer/config.yaml:1`.

---

## `infra.storage` — Standalone vs Cloud

This section has a **different shape** depending on the deployment mode.

### Standalone (SQLite) — `indexer-standalone` only

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__STORAGE__CNN_URL` | `infra.storage.cnn_url` | `"/data/indexer.sqlite"` | SQLite file path or `sqlite::memory:` for in-memory |

Struct: `indexer-common/src/infra/pool/sqlite.rs:64–66`. The `create_if_missing(true)` flag is applied automatically; the file is created if it does not exist (`sqlite.rs:71–73`).

### Cloud (PostgreSQL) — `chain-indexer`, `wallet-indexer`, `indexer-api`

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__STORAGE__HOST` | `infra.storage.host` | `"localhost"` | PostgreSQL hostname |
| `APP__INFRA__STORAGE__PORT` | `infra.storage.port` | `5432` | PostgreSQL port |
| `APP__INFRA__STORAGE__DBNAME` | `infra.storage.dbname` | `"indexer"` | Database name |
| `APP__INFRA__STORAGE__USER` | `infra.storage.user` | `"indexer"` | Database user |
| `APP__INFRA__STORAGE__PASSWORD` | `infra.storage.password` | — **required** | Database password; no default |
| `APP__INFRA__STORAGE__SSLMODE` | `infra.storage.sslmode` | `"prefer"` | PostgreSQL SSL mode (`disable`, `prefer`, `require`, `verify-ca`, `verify-full`) |
| `APP__INFRA__STORAGE__MAX_CONNECTIONS` | `infra.storage.max_connections` | `25` (api/wallet), `10` (chain) | Connection pool ceiling |
| `APP__INFRA__STORAGE__IDLE_TIMEOUT` | `infra.storage.idle_timeout` | `"1m"` | Idle connection lifetime |
| `APP__INFRA__STORAGE__MAX_LIFETIME` | `infra.storage.max_lifetime` | `"5m"` | Maximum connection lifetime regardless of activity |

`max_connections` differs between crates: `wallet-indexer/config.yaml:14` and `indexer-api/config.yaml:14` both use `25`; `chain-indexer/config.yaml:10` uses `10`.

Struct: `indexer-common/src/infra/pool/postgres.rs:81–103`. `password` is a `SecretString`; it is never logged.

---

## `infra.ledger_db`

Configures the content-addressed ledger state store backed by `midnight-storage-core-v1`.

| ENV VAR | YAML key | Default | Deployment | Purpose |
|---|---|---|---|---|
| `APP__INFRA__LEDGER_DB__CACHE_SIZE` | `infra.ledger_db.cache_size` | `"1kiB"` | both | In-memory LRU cache for ledger storage items; parsed with `byte_unit_serde` |
| `APP__INFRA__LEDGER_DB__CNN_URL` | `infra.ledger_db.cnn_url` | `"/data/ledger-db.sqlite"` | **standalone only** | SQLite file for the ledger DB; absent from cloud configs |

`cnn_url` is gated with `#[cfg(feature = "standalone")]` in the struct — `indexer-common/src/infra/ledger_db.rs:56`. Cloud mode uses the same PostgreSQL pool as `infra.storage`.

Sources: `indexer-standalone/config.yaml:27–29`, `chain-indexer/config.yaml:19–20`.

---

## `infra.node`

WebSocket connection to the Midnight Node (subxt). Used by `chain-indexer` and `indexer-standalone`.

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__NODE__URL` | `infra.node.url` | `"ws://localhost:9944"` | Node WebSocket endpoint |
| `APP__INFRA__NODE__RECONNECT_MAX_DELAY` | `infra.node.reconnect_max_delay` | `"10s"` | Exponential back-off ceiling; sequence is 10ms → 100ms → 1s → 10s |
| `APP__INFRA__NODE__RECONNECT_MAX_ATTEMPTS` | `infra.node.reconnect_max_attempts` | `30` | Max reconnect attempts before the binary exits (~5 minutes with full back-off) |
| `APP__INFRA__NODE__SUBSCRIPTION_RECOVERY_TIMEOUT` | `infra.node.subscription_recovery_timeout` | `"30s"` | If no block arrives within this window after a reconnect or duplicate, the subscription is torn down and re-established |

`subscription_recovery_timeout` has a code-level default of `Duration::from_secs(30)` via `#[serde(default = "default_subscription_recovery_timeout")]` — `chain-indexer/src/infra/subxt_node.rs:498–507`. It is also explicit in the config files.

Sources: `indexer-standalone/config.yaml:31–35`, `chain-indexer/config.yaml:30–34`.

---

## `infra.spo_node`

Cardano-side node connection for SPO data. Used by `indexer-standalone` only.

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__SPO_NODE__URL` | `infra.spo_node.url` | `"ws://localhost:9944"` | SPO node WebSocket endpoint |
| `APP__INFRA__SPO_NODE__BLOCKFROST_ID` | `infra.spo_node.blockfrost_id` | — **required** | Blockfrost project ID; must be a non-empty string |
| `APP__INFRA__SPO_NODE__RECONNECT_MAX_DELAY` | `infra.spo_node.reconnect_max_delay` | `"10s"` | Reconnect back-off ceiling |
| `APP__INFRA__SPO_NODE__RECONNECT_MAX_ATTEMPTS` | `infra.spo_node.reconnect_max_attempts` | `30` | Max reconnect attempts |

`blockfrost_id` has no default and no `Option<>` wrapper; figment will error at startup if it is absent. The comment in `indexer-standalone/config.yaml:41–44` notes that any non-empty placeholder (e.g. `dummy-not-using-spo`) is accepted if you are not exercising SPO features.

The `blockfrost_id` accepts either the format `previewXXX…` or `mainnetXXX…`; the SPO client derives the Blockfrost API base URL from the prefix — `spo-indexer/src/infra/spo_client.rs:350–362`.

Sources: `indexer-standalone/config.yaml:37–44`, `indexer-standalone/src/config.rs:152–160`.

---

## `infra.pub_sub`

NATS message bus for inter-process event delivery. **Cloud deployment only** — absent from `indexer-standalone` (which uses in-memory channels).

Used by `chain-indexer`, `wallet-indexer`, and `indexer-api`.

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__PUB_SUB__URL` | `infra.pub_sub.url` | `"localhost:4222"` | NATS server address (host:port, no scheme) |
| `APP__INFRA__PUB_SUB__USERNAME` | `infra.pub_sub.username` | `"indexer"` | NATS username |
| `APP__INFRA__PUB_SUB__PASSWORD` | `infra.pub_sub.password` | — **required** | NATS password; no default |
| `APP__INFRA__PUB_SUB__MAX_RECONNECTS` | `infra.pub_sub.max_reconnects` | `4` | Maximum NATS reconnection attempts before the connection is abandoned |

Struct: `indexer-common/src/infra/pub_sub/nats.rs:23–29`. `password` is a `SecretString`.

Sources: `chain-indexer/config.yaml:25–28`, `wallet-indexer/config.yaml:21–24`, `indexer-api/config.yaml:22–25`.

---

## `infra.api`

GraphQL API server settings. Used by `indexer-api` and `indexer-standalone`.

### Core HTTP Settings

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__API__ADDRESS` | `infra.api.address` | `"0.0.0.0"` | TCP bind address |
| `APP__INFRA__API__PORT` | `infra.api.port` | `8088` | TCP listen port |
| `APP__INFRA__API__REQUEST_BODY_LIMIT` | `infra.api.request_body_limit` | `"1MiB"` | Maximum HTTP request body size; parsed with `byte_unit_serde`; returns HTTP 413 if exceeded |
| `APP__INFRA__API__MAX_COMPLEXITY` | `infra.api.max_complexity` | `200` | async-graphql query complexity limit |
| `APP__INFRA__API__MAX_DEPTH` | `infra.api.max_depth` | `15` | async-graphql query depth limit |

### Subscription Batch Sizes

Each subscription type has a `batch_size` that controls how many events are sent in a single WebSocket push.

| ENV VAR | YAML key | Default | Subscription |
|---|---|---|---|
| `APP__INFRA__API__SUBSCRIPTION__BLOCKS__BATCH_SIZE` | `infra.api.subscription.blocks.batch_size` | `20` | `blocks` |
| `APP__INFRA__API__SUBSCRIPTION__CONTRACT_ACTIONS__BATCH_SIZE` | `infra.api.subscription.contract_actions.batch_size` | `20` | `contractActions` |
| `APP__INFRA__API__SUBSCRIPTION__DUST_GENERATIONS__BATCH_SIZE` | `infra.api.subscription.dust_generations.batch_size` | `20` | `dustGenerations` |
| `APP__INFRA__API__SUBSCRIPTION__DUST_LEDGER_EVENTS__BATCH_SIZE` | `infra.api.subscription.dust_ledger_events.batch_size` | `20` | `dustLedgerEvents` |
| `APP__INFRA__API__SUBSCRIPTION__DUST_NULLIFIER_TRANSACTIONS__BATCH_SIZE` | `infra.api.subscription.dust_nullifier_transactions.batch_size` | `20` | `dustNullifierTransactions` |
| `APP__INFRA__API__SUBSCRIPTION__SHIELDED_NULLIFIER_TRANSACTIONS__BATCH_SIZE` | `infra.api.subscription.shielded_nullifier_transactions.batch_size` | `20` | `shieldedNullifierTransactions` |
| `APP__INFRA__API__SUBSCRIPTION__SHIELDED_TRANSACTIONS__BATCH_SIZE` | `infra.api.subscription.shielded_transactions.batch_size` | `20` | `shieldedTransactions` |
| `APP__INFRA__API__SUBSCRIPTION__UNSHIELDED_TRANSACTIONS__BATCH_SIZE` | `infra.api.subscription.unshielded_transactions.batch_size` | `20` | `unshieldedTransactions` |
| `APP__INFRA__API__SUBSCRIPTION__ZSWAP_LEDGER_EVENTS__BATCH_SIZE` | `infra.api.subscription.zswap_ledger_events.batch_size` | `20` | `zswapLedgerEvents` |

### Wallet-Subscription Timing

Two subscriptions carry additional timing fields (`shieldedTransactions` and `unshieldedTransactions`):

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__API__SUBSCRIPTION__SHIELDED_TRANSACTIONS__PROGRESS_UPDATE_INTERVAL` | `infra.api.subscription.shielded_transactions.progress_update_interval` | `"30s"` | How often a catch-up progress event is emitted while replaying historical shielded transactions |
| `APP__INFRA__API__SUBSCRIPTION__SHIELDED_TRANSACTIONS__KEEP_WALLET_ALIVE_INTERVAL` | `infra.api.subscription.shielded_transactions.keep_wallet_alive_interval` | `"1m"` | Heartbeat interval sent to wallet-indexer to prevent wallet session expiry during long catch-ups |
| `APP__INFRA__API__SUBSCRIPTION__UNSHIELDED_TRANSACTIONS__PROGRESS_UPDATE_INTERVAL` | `infra.api.subscription.unshielded_transactions.progress_update_interval` | `"30s"` | How often a catch-up progress event is emitted while replaying historical unshielded transactions |

Structs: `indexer-api/src/infra/api.rs:196–213`.

### Subscription Quota

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__API__QUOTA__MAX_CONCURRENT_PER_CONNECTION` | `infra.api.quota.max_concurrent_per_connection` | `20` | Maximum simultaneous active subscriptions per WebSocket connection |
| `APP__INFRA__API__QUOTA__MAX_SESSION_SUBSCRIPTIONS_PER_MINUTE` | `infra.api.quota.max_session_subscriptions_per_minute` | `10` | Token-bucket rate cap for new `shieldedTransactions` subscriptions per `session_id` per minute |

The per-connection cap applies across all nine subscription types. The per-session rate limit applies only to `shieldedTransactions` (which accept a `session_id` argument). Quota violations return an `ApiError::client` with the WebSocket connection kept open — `indexer-api/src/infra/api/quota.rs:87–118`.

Sources: `indexer-standalone/config.yaml:46–76`, `indexer-api/config.yaml:27–57`.

---

## `infra.secret`

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__INFRA__SECRET` | `infra.secret` | — **required** | 32-byte (minimum) hex-encoded key used to encrypt wallet viewing keys at rest via ChaCha20-Poly1305 |

The value must decode from hex to at least 32 bytes; only the first 32 bytes are used as the ChaCha20-Poly1305 key — `indexer-common/src/cipher.rs:18–29`. Generate with:

```bash
openssl rand -hex 32
```

This field is required in `indexer-standalone` (`indexer-standalone/src/config.rs:149`), `indexer-api` (`indexer-api/src/infra.rs:37`), and `wallet-indexer` (`wallet-indexer/src/infra.rs:34`). `chain-indexer` and `spo-indexer` do not use a secret.

---

## `telemetry` Section

Used by all binaries. Service name defaults differ per crate (see table).

### `telemetry.tracing`

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__TELEMETRY__TRACING__ENABLED` | `telemetry.tracing.enabled` | `false` | Enable OpenTelemetry tracing via OTLP/gRPC exporter |
| `APP__TELEMETRY__TRACING__SERVICE_NAME` | `telemetry.tracing.service_name` | see table | Service name tag in traces |
| `APP__TELEMETRY__TRACING__OTLP_EXPORTER_ENDPOINT` | `telemetry.tracing.otlp_exporter_endpoint` | `"http://localhost:4317"` | gRPC OTLP collector endpoint |

Service name defaults by binary (from `config.yaml` files):

| Binary | `telemetry.tracing.service_name` default |
|---|---|
| `indexer-standalone` | `"indexer"` |
| `chain-indexer` | `"chain-indexer"` |
| `wallet-indexer` | `"wallet-indexer"` |
| `indexer-api` | `"indexer-api"` |
| `spo-indexer` | `"spo-indexer"` |

The struct also exposes two advanced fields (struct-level defaults, not in config.yaml):

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__TELEMETRY__TRACING__INSTRUMENTATION_SCOPE_NAME` | `telemetry.tracing.instrumentation_scope_name` | Cargo package name | OTEL instrumentation scope name |
| `APP__TELEMETRY__TRACING__INSTRUMENTATION_SCOPE_VERSION` | `telemetry.tracing.instrumentation_scope_version` | `v{CARGO_PKG_VERSION}` | OTEL instrumentation scope version |

Source: `indexer-common/src/telemetry.rs:64–83`.

### `telemetry.metrics`

| ENV VAR | YAML key | Default | Purpose |
|---|---|---|---|
| `APP__TELEMETRY__METRICS__ENABLED` | `telemetry.metrics.enabled` | `false` | Enable Prometheus metrics HTTP exporter |
| `APP__TELEMETRY__METRICS__ADDRESS` | `telemetry.metrics.address` | `"0.0.0.0"` | Prometheus scrape endpoint bind address |
| `APP__TELEMETRY__METRICS__PORT` | `telemetry.metrics.port` | `9000` | Prometheus scrape port |

Sources: `indexer-standalone/config.yaml:78–87`, `chain-indexer/config.yaml:36–44`.

---

## Standalone vs Cloud: Key Structural Differences

```text
Standalone (indexer-standalone binary)          Cloud (chain-indexer + wallet-indexer + indexer-api)
──────────────────────────────────────────────  ────────────────────────────────────────────────────
infra.storage  = SQLite (cnn_url)               infra.storage  = PostgreSQL (host/port/dbname/…)
infra.ledger_db.cnn_url  present                infra.ledger_db.cnn_url  absent (shares PG pool)
no infra.pub_sub section                        infra.pub_sub  required (NATS)
spo.*  in a separate top-level spo block        spo-indexer has its own binary with different layout
```

The feature flag (`cloud` vs `standalone`) is a **compile-time** switch. You cannot flip it at runtime; the correct binary must be built. See `references/deployment-and-crates.md` for the full feature-gate matrix.

---

## Required Values (no default, will error at startup)

| ENV VAR | Used by |
|---|---|
| `APP__INFRA__STORAGE__PASSWORD` | cloud `chain-indexer`, `wallet-indexer`, `indexer-api` |
| `APP__INFRA__PUB_SUB__PASSWORD` | cloud `chain-indexer`, `wallet-indexer`, `indexer-api` |
| `APP__INFRA__SECRET` | `indexer-standalone`, `indexer-api` (cloud), `wallet-indexer` (cloud) |
| `APP__INFRA__SPO_NODE__BLOCKFROST_ID` | `indexer-standalone` |

---

## Quick-Start Minimal Override Set

### Standalone

```bash
# Minimal required overrides for a non-default environment
APP__APPLICATION__NETWORK_ID=testnet-02
APP__INFRA__SECRET=<openssl rand -hex 32>
APP__INFRA__SPO_NODE__BLOCKFROST_ID=dummy-not-using-spo   # if SPO not needed
```

### Cloud (`chain-indexer`)

```bash
APP__APPLICATION__NETWORK_ID=testnet-02
APP__INFRA__STORAGE__HOST=postgres-svc
APP__INFRA__STORAGE__PASSWORD=<secret>
APP__INFRA__PUB_SUB__URL=nats-svc:4222
APP__INFRA__PUB_SUB__PASSWORD=<secret>
APP__INFRA__NODE__URL=ws://midnight-node:9944
```

---

## Cross-references

- `midnight-indexer:indexer-architecture` — deployment modes, crate overview, feature flags
- `references/deployment-and-crates.md` — workspace member table, feature-gate matrix
- `references/nats-messaging.md` — NATS topic topology and message types
- `midnight-tooling:devnet` — running a local indexer stack via Docker Compose (node, NATS, Postgres)
