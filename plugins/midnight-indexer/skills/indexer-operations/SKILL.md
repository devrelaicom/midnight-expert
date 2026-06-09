---
name: midnight-indexer:indexer-operations
description: This skill should be used when the user asks about running, monitoring, or troubleshooting the Midnight indexer — health checks, the /live and /ready endpoints, Prometheus metrics, OpenTelemetry tracing, node reconnection and recovery, wallet session lifecycle, caught-up status, NATS failure handling, indexer logs, or indexer deployment operations. Covers "is my indexer healthy", "why is the indexer behind the node", "indexer metrics", "indexer not catching up", and "monitoring the indexer in production".
version: 0.1.0
---

# Indexer Operations

Operational guide for running, health-checking, monitoring, and troubleshooting the Midnight indexer. For starting and stopping the local Docker stack, see `midnight-tooling:devnet`. For the full observability and troubleshooting reference, see `references/monitoring-and-troubleshooting.md` in this skill.

## Deployment Recap

The indexer ships in two deployment shapes. For full detail see `midnight-indexer:indexer-architecture` → `references/deployment-and-crates.md`.

| Shape | Services | Storage | Bus |
|-------|----------|---------|-----|
| Standalone | Single binary (`indexer-standalone`) | SQLite | In-process |
| Cloud | 4 services: `chain-indexer`, `wallet-indexer`, `indexer-api`, `spo-indexer` | PostgreSQL | NATS |

**Default port:** 8088 (GraphQL + health probes on the same listener).

## Health Checks

The indexer exposes two HTTP probes on the GraphQL port (default **8088**). Both are served by the same Axum router as the GraphQL endpoint.

| Endpoint | Kubernetes role | Returns |
|----------|----------------|---------|
| `GET /live` | Liveness | `200 OK` — always, as long as the async runtime is responsive |
| `GET /ready` | Readiness | `200 OK` when caught up with the node; `503 Service Unavailable` with body `"indexer has not yet caught up with the node"` otherwise |

Source: `indexer-api/src/infra/api.rs:295–309`.

```bash
# Liveness — is the process alive?
curl -sf http://localhost:8088/live

# Readiness — has it caught up with the node?
curl -o - -w "\nHTTP %{http_code}\n" http://localhost:8088/ready
```

The `/live` handler runs in the async task executor; if a storage-layer deadlock parks the runtime, the liveness probe times out rather than returning 200, which lets Kubernetes terminate and recreate the pod.

### Docker / Kubernetes Patterns

The official Docker **Compose** stack defines a `HEALTHCHECK` for each service that tests a running-file: the entrypoint creates `/var/run/<component>/running` on startup and removes it on exit (via `trap … EXIT`), and the healthcheck command is `cat /var/run/<component>/running`. The image Dockerfiles themselves embed no `HEALTHCHECK`. For Kubernetes — or to gate traffic on actual readiness rather than liveness — prefer the HTTP probes:

```yaml
# Kubernetes
livenessProbe:
  httpGet:
    path: /live
    port: 8088
  initialDelaySeconds: 15
  periodSeconds: 30
readinessProbe:
  httpGet:
    path: /ready
    port: 8088
  initialDelaySeconds: 30
  periodSeconds: 10
```

```yaml
# Docker Compose
healthcheck:
  test: ["CMD", "curl", "-sf", "http://localhost:8088/ready"]
  interval: 30s
  timeout: 5s
  retries: 3
  start_period: 60s
```

## Caught-Up Status

"Caught up" governs whether `/ready` returns 200 and whether the `indexer_caught_up` gauge is 1.

| Config key | Default | Meaning |
|-----------|---------|---------|
| `caught_up_max_distance` | `10` | Max blocks behind the node before `caught_up = false` |
| `caught_up_leeway` | `5` | Hysteresis — must catch within this distance before `caught_up` flips back to `true` |

The formula: `caught_up = (node_height − indexed_height) ≤ caught_up_max_distance`, with `caught_up_leeway` preventing rapid oscillation at the threshold. A 503 from `/ready` during initial sync is **normal and expected** — the indexer must process all historical blocks before it reports ready.

Configuration keys live under `APP__` in environment or in `config.yaml`. See `midnight-indexer:indexer-architecture` → `references/configuration-reference.md` for the full key listing.

## Metrics and Tracing

Both are **disabled by default** in standalone and cloud deployments. Enable them via environment variables or `config.yaml`.

### Prometheus Metrics

```bash
# Enable via environment
APP__TELEMETRY__METRICS__ENABLED=true   # required
APP__TELEMETRY__METRICS__ADDRESS=0.0.0.0
APP__TELEMETRY__METRICS__PORT=9000      # default
```

Scrape endpoint: `http://<host>:9000/metrics`

| Metric | Type | Description |
|--------|------|-------------|
| `indexer_block_height` | counter | Highest block the indexer has processed |
| `indexer_node_block_height` | counter | Latest block height reported by the node |
| `indexer_caught_up` | gauge | 1 = caught up, 0 = behind |
| `indexer_transaction_count` | counter | Total transactions indexed |
| `indexer_wallets_connected` | gauge | Active wallet sessions |
| `indexer_subscriptions_active` | gauge | Active GraphQL subscriptions |
| `indexer_subscriptions_rejected_total` | counter | Subscriptions rejected by quota |

For the full metric catalog and example Grafana queries, see `references/monitoring-and-troubleshooting.md`.

### OpenTelemetry Tracing

```bash
APP__TELEMETRY__TRACING__ENABLED=true
APP__TELEMETRY__TRACING__OTLP_EXPORTER_ENDPOINT=http://localhost:4317  # default
APP__TELEMETRY__TRACING__SERVICE_NAME=indexer
```

Spans are exported via gRPC OTLP to the configured endpoint. Logs are correlated with traces — when a log record is emitted inside a span, the trace ID is included in the JSON log output.

## Node Connection and Recovery

The indexer connects to the Midnight node via subxt with a built-in reconnecting RPC client using exponential backoff.

| Config key | Default | Notes |
|-----------|---------|-------|
| `reconnect_max_delay` | `10s` | Backoff ceiling; steps are 10ms → 100ms → 1s → 10s |
| `reconnect_max_attempts` | `30` | ≈ 5 minutes of retries before the process exits |
| `subscription_recovery_timeout` | `30s` | If no valid block arrives after a reconnect or duplicate event within this window, the subscription is torn down and re-established |

When the node disconnects, a `WARN` log line `"node disconnected, reconnecting"` is emitted. After `reconnect_max_attempts` failures the process exits so the container orchestrator can restart it.

Config keys live under `APP__INFRA__NODE__` (the standalone binary also has a separate `APP__INFRA__SPO_NODE__` for its Cardano-side connection). See `midnight-indexer:indexer-architecture` → `references/configuration-reference.md`.

## Wallet Session Lifecycle

Wallet sessions let the indexer scan shielded transactions for a specific viewing key without exposing that key on-chain.

```text
connect(viewingKey)
  → viewing key encrypted at rest (ChaCha20-Poly1305, key from APP__INFRA__SECRET)
  → wallet-indexer scans blocks for relevant transactions
  → client subscribes via shieldedTransactions(sessionId)

disconnect(sessionId)
  → session ends, resources released
```

| Config key | Default | Meaning |
|-----------|---------|---------|
| `active_wallets_ttl` | `30m` | Idle sessions are evicted after this duration |
| `keep_wallet_alive_interval` | `1m` | Heartbeat interval to keep long-running catch-up sessions alive |

`APP__INFRA__SECRET` must be set to a hex-encoded 32-byte key before the indexer will accept `connect` mutations. Missing or invalid `SECRET` causes startup failure or decryption errors at session creation time.

For the GraphQL mutations (`connect`, `disconnect`) and the `shieldedTransactions` subscription, see `midnight-indexer:indexer-graphql-api`.

## NATS Failure Handling (Cloud)

In cloud mode, `chain-indexer` → `wallet-indexer` and `chain-indexer` → `indexer-api` communication flows through NATS (core pub-sub — the server runs with `-js` but the indexer creates no JetStream streams or consumers). Publisher and subscriber components log `WARN` on `Event::ServerError` and `Event::ClientError` from the NATS client library; a startup `ConnectError` causes the service to exit so the orchestrator can retry.

For subjects, consumer groups, and failure modes, see `midnight-indexer:indexer-architecture` → `references/nats-messaging.md`.

## Troubleshooting

Quick-reference for common failure modes. Full diagnostic procedures and log patterns are in `references/monitoring-and-troubleshooting.md`.

| Symptom | Likely cause | First action |
|---------|-------------|--------------|
| `/ready` returns 503 continuously | Initial sync not complete, or node unreachable | Check `indexer_block_height` vs `indexer_node_block_height`; confirm node is reachable |
| `indexer_caught_up` stuck at 0 | Block processing stalled or node connection lost | Check logs for `"node disconnected"` or DB errors |
| `connect` mutation fails | `APP__INFRA__SECRET` missing or malformed | Verify the env var is set to a valid 64-char hex string |
| NATS startup failure (cloud) | NATS server not reachable at startup | Check `APP__INFRA__PUB_SUB__URL`; verify NATS container is healthy |
| DB migration errors | Schema version mismatch after upgrade | Check logs for `sqlx` migration errors; ensure the DB is accessible |
| Wallet sessions evicted unexpectedly | `active_wallets_ttl` too short for catch-up duration | Increase `active_wallets_ttl` or ensure the client heartbeats within the TTL |
| Blockfrost 402 errors (SPO indexer) | Blockfrost plan limit reached or invalid `BLOCKFROST_ID` | Verify `APP__INFRA__SPO_NODE__BLOCKFROST_ID` and plan quota |

```bash
# Diagnostic checklist
# 1. Is the process alive?
curl -sf http://localhost:8088/live && echo "LIVE"

# 2. Has it caught up with the node?
curl -o - -w "\nHTTP %{http_code}\n" http://localhost:8088/ready

# 3. What metrics show?
curl -s http://localhost:9000/metrics | grep -E "indexer_(block_height|node_block_height|caught_up)"

# 4. Recent log output (standalone Docker)
docker logs --tail 50 indexer-standalone

# 5. Follow logs in real time
docker logs -f indexer-standalone
```

## References

| Name | Description | When used |
|------|-------------|-----------|
| `references/monitoring-and-troubleshooting.md` | Full metric catalog, log pattern reference, Grafana queries, and detailed diagnostic procedures | Setting up production monitoring or investigating deep operational issues |
| `examples/running-standalone.md` | Step-by-step: run the standalone indexer with health checks and metrics enabled | Getting the standalone binary operational end-to-end |

## Cross-References

| Skill / Resource | Relevance |
|-----------------|-----------|
| `midnight-tooling:devnet` | Starting and stopping the full local Docker stack (node + indexer + proof server) |
| `midnight-indexer:indexer-architecture` | Deployment modes, crate layout, and full configuration-reference / nats-messaging / deployment-and-crates references |
| `midnight-indexer:indexer-graphql-api` | `connect` / `disconnect` mutations and the `shieldedTransactions` subscription |
| `midnight-indexer:indexer-data-model` | What gets indexed, database schema, and block/transaction data shapes |
