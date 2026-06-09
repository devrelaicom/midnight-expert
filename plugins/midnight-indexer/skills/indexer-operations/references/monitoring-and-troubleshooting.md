# Indexer Monitoring and Troubleshooting

The indexer stack emits structured JSON logs, optional distributed traces via OpenTelemetry, and optional Prometheus metrics. Both telemetry systems are **disabled by default**; logging is always active.

---

## Logging

### Initialization

All indexer binaries call `telemetry::init_logging()` at startup before any other work. The function installs [Logforth](https://github.com/fast/logforth) with:

- **JSON output** to stdout (`JsonLayout::default()`).
- **`RUST_LOG` filter** via `EnvFilterBuilder::from_default_env()`.
- **Span correlation** via `FastraceDiagnostic` — when a log call occurs inside a `fastrace` span, the trace ID is injected into the log record automatically.
- **Span event forwarding** via `FastraceEvent` — log records inside spans are also added to the span as events.

Source: `indexer-common/src/telemetry.rs:107–117`

### Log Level Selection

Set the `RUST_LOG` environment variable. The reference compose values use:

```text
# chain-indexer (cloud)
RUST_LOG=chain_indexer=debug,indexer_common=debug,fastrace_opentelemetry=off,info

# indexer-standalone (all-in-one)
RUST_LOG=indexer_standalone=debug,chain_indexer=debug,indexer_api=debug,wallet_indexer=debug,indexer_common=debug,fastrace_opentelemetry=off,info
```

Source: `docker-compose.yaml:31,56,79,106,130`

The `fastrace_opentelemetry=off` segment suppresses noisy internal exporter logs when tracing is disabled.

### Structured Field Syntax

The codebase uses the `log` crate with the `kv` feature:

```rust
info!(hash:%, height; "block indexed")      // :% = Display
debug!(hash:%, height:?, parent_hash:%;     // :? = Debug
       "block received")
error!(error:% = error.as_chain();          // full error chain
       "process exited with ERROR")
```

Source: `indexer-common/src/telemetry.rs:18–22` (module-level doc)

### Startup Panic Hook

All binaries install a custom panic hook that logs at `ERROR` using structured logging before aborting. A panic produces a line with the `panic` field set to the panic message.

Source: `chain-indexer/src/main.rs:27`, `indexer-standalone/src/main.rs:30`

### NATS Event Log Levels

> NATS connection events are covered fully in `midnight-indexer:indexer-architecture` → `references/nats-messaging.md`. Summary only:

| NATS event | Level |
|---|---|
| `Connected` | DEBUG |
| `Disconnected`, `LameDuckMode`, `Draining`, `Closed`, `SlowConsumer` | WARN |
| `ServerError`, `ClientError` | WARN |

Source: `indexer-common/src/infra/pub_sub/nats/publisher.rs:43–50`, `subscriber.rs:47–54`

---

## Tracing (OpenTelemetry / fastrace)

Tracing is **disabled by default** (`telemetry.tracing.enabled = false`).

### Libraries

| Layer | Library |
|---|---|
| Span instrumentation | `fastrace` (`#[trace]` attribute, `Span::root`) |
| OTLP gRPC exporter | `fastrace-opentelemetry` + `opentelemetry-otlp` with Tonic |
| `tracing` crate bridge | `fastrace-tracing` (`FastraceCompatLayer`) |
| Optional console dump | `fastrace::collector::ConsoleReporter` (testing only) |

Source: `indexer-common/src/telemetry.rs:31–49`

### Configuration

| Key | Default | Description |
|---|---|---|
| `telemetry.tracing.enabled` | `false` | Must be `true` to start the OTLP exporter |
| `telemetry.tracing.service_name` | varies per binary | OTLP `service.name` resource attribute |
| `telemetry.tracing.otlp_exporter_endpoint` | `http://localhost:4317` | gRPC endpoint for the OTLP collector |
| `telemetry.tracing.console_reporter_enabled` | `false` | Print spans to stdout; for testing only |
| `telemetry.tracing.instrumentation_scope_name` | `$CARGO_PKG_NAME` | OTLP instrumentation scope |
| `telemetry.tracing.instrumentation_scope_version` | `v$CARGO_PKG_VERSION` | OTLP instrumentation scope version |

Source: `indexer-common/src/telemetry.rs:64–93`, `chain-indexer/config.yaml:37–40`

### Enabling

```bash
# Via env overrides
APP__TELEMETRY__TRACING__ENABLED=true
APP__TELEMETRY__TRACING__OTLP_EXPORTER_ENDPOINT=http://otel-collector:4317
```

If `enabled = false` no exporter is built and no `tracing::subscriber` is installed; the `fastrace` reporter is never set.

Source: `indexer-common/src/telemetry.rs:126–161`

---

## Metrics (Prometheus)

Metrics are **disabled by default** (`telemetry.metrics.enabled = false`).

### Library

`metrics-exporter-prometheus` (`PrometheusBuilder`). The `metrics` crate macros (`counter!`, `gauge!`) instrument application code. When enabled, the exporter starts an HTTP listener that serves the standard Prometheus text format.

Source: `indexer-common/src/telemetry.rs:43,171–184`

### Configuration

| Key | Default | Description |
|---|---|---|
| `telemetry.metrics.enabled` | `false` | Must be `true` to start the HTTP exporter |
| `telemetry.metrics.address` | `0.0.0.0` | Bind address for the Prometheus scrape endpoint |
| `telemetry.metrics.port` | `9000` | Bind port |

Source: `indexer-common/src/telemetry.rs:88–93`, `chain-indexer/config.yaml:41–44`

```bash
APP__TELEMETRY__METRICS__ENABLED=true
APP__TELEMETRY__METRICS__PORT=9000   # default
```

When enabled, metrics are available at `http://<address>:9000/metrics` (standard Prometheus scrape path provided by `metrics-exporter-prometheus`).

### Named Metrics

These metric names are registered in source and will appear in the Prometheus output when enabled.

**chain-indexer** (`chain-indexer/src/application/metrics.rs:35–41`):

| Metric | Type | Description |
|---|---|---|
| `indexer_block_height` | Counter (absolute) | Height of the last block processed by the chain-indexer |
| `indexer_node_block_height` | Counter (absolute) | Current finalized tip height observed on the node |
| `indexer_caught_up` | Gauge | `1.0` when caught up, `0.0` otherwise |
| `indexer_transaction_count` | Counter | Running total of transactions indexed |
| `indexer_contract_deploy_count` | Counter | Running total of contract deploy actions indexed |
| `indexer_contract_call_count` | Counter | Running total of contract call actions indexed |
| `indexer_contract_update_count` | Counter | Running total of contract update actions indexed |

**indexer-api** (`indexer-api/src/infra/api.rs:239`, `indexer-api/src/infra/api/quota.rs:194–200`):

| Metric | Type | Description |
|---|---|---|
| `indexer_wallets_connected` | Gauge | Active wallet subscriptions (incremented on start, decremented on end) |
| `indexer_subscriptions_active` | Gauge | Total active GraphQL subscriptions |
| `indexer_subscriptions_rejected_total{kind="per_connection"}` | Counter | Subscriptions rejected for exceeding `max_concurrent_per_connection` |
| `indexer_subscriptions_rejected_total{kind="per_session_rate"}` | Counter | Subscriptions rejected for exceeding `max_session_subscriptions_per_minute` |

No additional named metrics were found in `wallet-indexer` or `spo-indexer` source.

---

## Health Checks

### Running-file Liveness (all Docker images)

Every indexer Docker image uses the same pattern: the `entrypoint.sh` script creates a file at startup and removes it on exit. The Docker `HEALTHCHECK` tests for this file with `cat`.

| Component | File path | Healthcheck command |
|---|---|---|
| `chain-indexer` | `/var/run/chain-indexer/running` | `cat /var/run/chain-indexer/running` |
| `wallet-indexer` | `/var/run/wallet-indexer/running` | `cat /var/run/wallet-indexer/running` |
| `indexer-api` | `/var/run/indexer-api/running` | `cat /var/run/indexer-api/running` |
| `spo-indexer` | `/var/run/spo-indexer/running` | `cat /var/run/spo-indexer/running` (exits 0 on failure — soft check) |
| `indexer-standalone` | `/var/run/indexer-standalone/running` | `cat /var/run/indexer-standalone/running` |

The `trap 'rm ... running' EXIT` in each entrypoint ensures the file is removed when the process exits, causing the next health probe to fail.

Source: `indexer-standalone/bin/entrypoint.sh:3,7`, `chain-indexer/bin/entrypoint.sh:3,7`, `indexer-api/bin/entrypoint.sh:3,7`, `wallet-indexer/bin/entrypoint.sh:3,7`, `spo-indexer/bin/entrypoint.sh:5,9`, `docker-compose.yaml:38,63,86,113,136`

Docker healthcheck timing (same for all services):

```yaml
start_interval: "2s"
start_period:   "30s"
interval:       "5s"
timeout:        "2s"
retries:        2
```

Source: `docker-compose.yaml:39–43`

### HTTP Liveness Probe (`/live`)

The `indexer-api` (and `indexer-standalone`) exposes two HTTP probes on the GraphQL port (default `8088`):

| Route | Behaviour |
|---|---|
| `GET /live` | Always returns `200 OK` if the async runtime is not blocked. Designed as a Kubernetes liveness probe — a blocked runtime means the handler never runs and kubelet times out and restarts the pod. |
| `GET /ready` | Returns `200 OK` when the chain-indexer has caught up with the node; `503 Service Unavailable` with body `"indexer has not yet caught up with the node"` otherwise. |

Source: `indexer-api/src/infra/api.rs:277–309`

### Caught-up Signal

The chain-indexer computes a `caught_up` boolean after each indexed block:

```
distance = node_block_height − indexed_block_height
caught_up = distance ≤ caught_up_max_distance          (initial)
caught_up = distance ≤ caught_up_max_distance + caught_up_leeway  (hysteresis once caught up)
```

Defaults (`chain-indexer/config.yaml:7–8`): `caught_up_max_distance = 10`, `caught_up_leeway = 5`.

This flag is published in each `BlockIndexed` NATS message and drives the `GET /ready` response and the `indexer_caught_up` Prometheus gauge.

When the caught-up state transitions (either direction), a log line is emitted:

```text
INFO  caught_up=true; "caught-up status changed"   (or false)
```

Source: `chain-indexer/src/application.rs:444–447`, `chain-indexer/src/application.rs:474–480`

---

## Node Connection and Recovery

### Reconnecting WebSocket Client

The chain-indexer and SPO-indexer use `subxt`'s `ReconnectingRpcClient` with an exponential back-off policy.

| Parameter | Config key | Default | Notes |
|---|---|---|---|
| Initial back-off | — | 10 ms | Fixed start of `ExponentialBackoff::from_millis(10)` |
| Maximum back-off delay | `reconnect_max_delay` | `10s` | Sequence: 10 ms → 100 ms → 1 s → 10 s |
| Maximum reconnect attempts | `reconnect_max_attempts` | `30` | ≈ 5 minutes at max delay, then process exits |
| Subscription recovery timeout | `subscription_recovery_timeout` | `30s` | Re-subscribes if no block received in this window |

Source: `chain-indexer/src/infra/subxt_node.rs:87–96`, `chain-indexer/config.yaml:32–35`

### Disconnection Handling

When subxt detects a disconnect it yields a single `Err(DisconnectedWillReconnect(_))` item in the finalized-blocks stream. The indexer filters this error out, logs at WARN, and continues without propagating:

```text
WARN  "node disconnected, reconnecting"
```

Duplicate blocks that appear after a reconnect (same height as already processed) are also filtered and logged:

```text
WARN  hash=… height=… last_height=…; "received duplicate, possibly after reconnect"
```

Source: `chain-indexer/src/infra/subxt_node.rs:144–159`

### Subscription Recovery

If the block stream is connected but no block arrives within `subscription_recovery_timeout` (default 30 s), the indexer re-subscribes to finalized blocks and logs:

```text
WARN  last_yielded_height=… recovery_timeout=…; "subscription appears stuck, re-subscribing"
```

Source: `chain-indexer/src/infra/subxt_node.rs:417–425`

### Catch-up Logging

During initial catch-up (fetching historical blocks by height), a progress log is emitted every 1 000 blocks:

```text
INFO  highest_stored_height=… current_height=… first_finalized_height=…; "catching up by height"
```

Source: `chain-indexer/src/infra/subxt_node.rs:62,339–346` (`CATCH_UP_LOG_INTERVAL = 1_000`)

---

## Log Signals to Watch

The following log strings are confirmed in source. All logs are JSON; the quoted strings are the `message` field value.

| Message | Level | Source component | Meaning |
|---|---|---|---|
| `"starting indexing"` | INFO | chain-indexer | Indexer loop starting; `highest_block_height` field shows resume point. |
| `"catching up by height"` | INFO | chain-indexer | Historical catch-up in progress; emitted every 1 000 blocks. |
| `"caught-up status changed"` | INFO | chain-indexer | `caught_up` field is `true`/`false`; first `true` means ready to serve live queries. |
| `"block indexed"` | INFO | chain-indexer | One block fully processed; fields: `hash`, `height`, `distance`, `caught_up`. |
| `"highest finalized block on node"` | INFO | chain-indexer | Node tip tracker updated; fields: `hash`, `height`. |
| `"node disconnected, reconnecting"` | WARN | chain-indexer | Transient disconnect; reconnect in progress. |
| `"received duplicate, possibly after reconnect"` | WARN | chain-indexer | Duplicate block filtered after reconnect. |
| `"subscription appears stuck, re-subscribing"` | WARN | chain-indexer | No block in `subscription_recovery_timeout`; forced re-subscribe. |
| `"NATS client disconnected"` | WARN | any (pub-sub) | NATS link dropped; reconnect will follow if within `max_reconnects`. |
| `"NATS client closed"` | WARN | any (pub-sub) | NATS reconnect limit exhausted; further publishes will fail. |
| `"NATS server error"` / `"NATS client error"` | WARN | any (pub-sub) | Error detail in `error` field. |
| `"SIGTERM received"` | WARN | chain-indexer | Graceful shutdown initiated. |
| `"process exited with ERROR"` | ERROR | all | Fatal error; `error` and `backtrace` fields contain detail. |
| `"process panicked"` | ERROR | all | Unexpected panic; `panic` field contains location and message. |

---

## Common Failure Modes

| Failure | Symptom / log signal | Fix |
|---|---|---|
| **NATS unreachable at startup** (cloud mode) | `async_nats::ConnectError` wrapped as `"cannot create NATS based publisher/subscriber"` propagated to `"process exited with ERROR"`. Process exits immediately. | Ensure the NATS container is healthy before starting indexer services. In compose, add `depends_on: nats: condition: service_started` (already present in the reference compose). See `midnight-indexer:indexer-architecture` → `references/nats-messaging.md`. |
| **Node WebSocket unreachable** | Reconnect back-off begins (10 ms → 10 s). After 30 attempts (≈ 5 min) the subxt client is exhausted and the error propagates to `"process exited with ERROR"`. | Check `APP__INFRA__NODE__URL`. Verify the node container is reachable. See `midnight-indexer:indexer-architecture` → `references/configuration-reference.md`. |
| **Missing `APP__INFRA__SECRET`** (wallet-indexer / indexer-api / standalone) | Config deserialization fails; `"load configuration"` context in `"process exited with ERROR"`. | Set `APP__INFRA__SECRET` to a hex-encoded 32+ byte key. See `midnight-indexer:indexer-architecture` → `references/configuration-reference.md`. |
| **Empty or missing `APP__INFRA__SPO_NODE__BLOCKFROST_ID`** | `SPOClientError::MissingBlockfrostId` (`"blockfrost_id must be configured"`) returned from `SPOClient::new`, propagated to `"process exited with ERROR"`. | Set `APP__INFRA__SPO_NODE__BLOCKFROST_ID` to a valid Blockfrost project ID. For local dev without SPO features, any non-empty placeholder is accepted (e.g. `dummy-not-using-spo`). Source: `spo-indexer/src/infra/spo_client.rs:82–84`. |
| **Postgres unreachable / wrong credentials** | `sqlx` connection pool creation fails with a database error in the `"create DB pool for Postgres"` context. Process exits. | Check `APP__INFRA__STORAGE__HOST`, `APP__INFRA__STORAGE__PASSWORD`, and that the Postgres service is healthy. |
| **SQLite file not writable** (standalone) | `sqlx` fails to open the SQLite file; error in `"create DB pool for Sqlite"` context. | Check that `/data` is writable by `appuser` (uid 10001). The standalone Dockerfile creates `/data` with correct ownership. |
| **Migration failure** | `"cannot run migrations for postgres/sqlite"` (wrapping a `sqlx::MigrateError`) in the `"run Postgres/Sqlite migrations"` context. | Usually a schema version mismatch from running a newer indexer against an existing database without migration. Check if `infra.run_migrations = true`. If the database is corrupt, restore from backup or re-sync from genesis. Source: `indexer-common/src/infra/migrations/`. |
| **Blockfrost HTTP 4xx during stake refresh** | `SPOClientError::UnexpectedResponse("blockfrost GET /pools failed: <status> <body>")` logged; stake refresh skipped for that pool. The indexer continues running. | A non-success HTTP status (including 402 Payment Required for over-quota keys) produces this error. Check your Blockfrost project quota. The SPO-indexer applies a rudimentary `max_rps` rate limit (`spo.stake_refresh.max_rps`, default `2 req/s`) to reduce pressure. Source: `spo-indexer/src/infra/spo_client.rs:336–341`, `spo-indexer/src/application.rs:50`. |
| **Indexer behind node — `/ready` returns 503** | `GET /ready` returns `503` with body `"indexer has not yet caught up with the node"`. `indexer_caught_up` gauge is `0`. | Normal during initial sync. Wait for `"caught-up status changed"` INFO log with `caught_up=true`. If it never arrives, check node connectivity and chain-indexer logs. |
| **Runtime blocked / liveness timeout** | `GET /live` times out (Kubernetes liveness probe); pod is restarted. `"process exited with ERROR"` may appear in logs before or after restart. | A blocking call on the async runtime (e.g. a slow storage operation) can park all workers. Check for recent `ERROR` or `WARN` logs before the restart event. |

---

## Cross-references

- `midnight-indexer:indexer-architecture` → `references/nats-messaging.md` — NATS topic schema, NATS event log levels, `max_reconnects`
- `midnight-indexer:indexer-architecture` → `references/configuration-reference.md` — full config key reference, `APP__INFRA__SECRET`, `APP__INFRA__SPO_NODE__BLOCKFROST_ID`, node URLs
- `midnight-tooling:devnet` — starting and stopping the Docker Compose stack that hosts the indexer
- `midnight-tooling:troubleshooting` — general Midnight toolchain diagnostics
- `midnight-status-codes:status-codes` — looking up error codes and error types across Midnight components
