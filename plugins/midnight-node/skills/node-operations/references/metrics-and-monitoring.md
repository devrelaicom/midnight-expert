# Node Metrics and Monitoring

The node exposes metrics via a standard Substrate Prometheus scrape endpoint and optionally pushes them to a remote-write receiver. Two resource monitors — memory and storage — provide proactive graceful-shutdown protection. This reference covers the pull endpoint, push configuration, resource monitors, and the Midnight-specific metrics added in node 1.0.0.

## Prometheus Scrape Endpoint

The node embeds Substrate's Prometheus registry. The scrape endpoint is:

```
http://<node-host>:9615/metrics
```

By default the endpoint binds to `127.0.0.1`. Expose it externally with:

```bash
# CLI flag
--prometheus-external --prometheus-port 9615

# Or via config file / append_args
append_args = ["--prometheus-external"]
```

`--prometheus-external` is a standard Substrate/polkadot-sdk CLI flag passed through via `argv`/`append_args`; it is documented in `docs/configuration-guide.md:367` and confirmed in `res/cfg/dev.toml:24`.

> **Dependency note:** `--prometheus-port` must be set (or left at the default `9615`) for any metrics to be collected. Without a Prometheus registry, the push task cannot start — the node logs a warning at `node/src/service.rs:857`.

## Key Substrate Metrics

These are **upstream Polkadot-SDK / Substrate metrics** inherited by the node through its Substrate runtime. They are not defined in midnight-node source; the names are well-established in the Substrate ecosystem. They are listed here because operators routinely watch them.

| Metric name | Type | What it measures |
|---|---|---|
| `substrate_block_height` | Gauge | Current best-block number (label `status=best`) and highest known block (`status=sync_target`) |
| `substrate_block_height{status="finalized"}` | Gauge | Finalized block number |
| `substrate_sub_libp2p_peers_count` | Gauge | Connected peer count (**correct name** — not `substrate_peers_count`) |
| `substrate_ready_transactions_number` | Gauge | Transactions in the ready queue of the transaction pool |
| `substrate_number_leaves` | Gauge | Number of known chain leaves (i.e. competing chain tips / forks) — **not** state-trie leaves |
| `substrate_sync_is_major_syncing` | Gauge | `1` while the node is doing initial sync, `0` once caught up |
| `substrate_block_verification_and_import_time` | Histogram | Wall-clock time to verify and import a block |

All names with the `substrate_` prefix originate in the polkadot-sdk codebase (primarily `client/` sub-crates). They are not redefined in midnight-node source.

## Midnight-Specific Metric

One Midnight-specific histogram is registered in node 1.0.0:

| Metric name | Type | Labels | What it measures |
|---|---|---|---|
| `midnight_data_source_query_time_elapsed` | Histogram | `query_name` | Elapsed time (seconds) for each individual SQL query run by the Cardano data-source adapters (cNight observation, federated authority, candidates) |

Source: `primitives/mainchain-follower/src/data_source/metrics.rs:31`. This metric is registered against the Substrate Prometheus registry at `node/src/service.rs:287` and scraped at `:9615/metrics`.

## Prometheus Remote Write (Push)

For environments where pull-based scraping is impractical, the node ships a background task that pushes all metrics to a **Prometheus Remote Write** receiver. This is **not** Pushgateway — it uses the Remote Write protocol (Protobuf + Snappy, HTTP POST, header `X-Prometheus-Remote-Write-Version: 0.1.0`) and targets receivers such as Thanos Receive, Cortex, or Grafana Mimir.

Source: `node/src/metrics_push.rs:14–23` (module doc), `node/src/metrics_push.rs:271–279` (HTTP POST), `node/src/command.rs:274–289` (config wiring).

### Configuration

All three keys live under the `midnight_cfg` namespace in the configuration layer (`node/src/cfg/midnight_cfg/mod.rs:94–106`). They are set via environment variable or TOML config file — there are no corresponding CLI flags.

| Config key | Environment variable | Default | Description |
|---|---|---|---|
| `prometheus_push_endpoint` | `PROMETHEUS_PUSH_ENDPOINT` | _(unset)_ | Full URL of the remote-write endpoint, e.g. `https://thanos.example.com/api/v1/receive`. Required to enable push. |
| `prometheus_push_interval_secs` | `PROMETHEUS_PUSH_INTERVAL_SECS` | `15` | Seconds between pushes (`node/src/command.rs:278`). |
| `prometheus_push_job_name` | `PROMETHEUS_PUSH_JOB_NAME` | `midnight-node` | Value of the `job` label attached to every pushed metric (`node/src/command.rs:282–284`). |

The push task also attaches `hostname`, `ip`, `node_name`, and `peer_id` labels to every time series (`node/src/metrics_push.rs:151–158`).

### What is pushed

The task calls `registry.gather()` on the same Substrate Prometheus registry that serves `:9615/metrics`, so every metric visible at the scrape endpoint — Substrate metrics, the `midnight_data_source_query_time_elapsed` histogram, and any other registered metrics — is included in each push.

Histograms are expanded into `_sum`, `_count`, and `_bucket` series on the client side before transmission (`node/src/metrics_push.rs:184–222`).

### Quick start

```bash
PROMETHEUS_PUSH_ENDPOINT=https://thanos.example.com/api/v1/receive \
PROMETHEUS_PUSH_INTERVAL_SECS=30 \
PROMETHEUS_PUSH_JOB_NAME=midnight-mainnet \
  midnight-node --prometheus-port 9615 ...
```

`--prometheus-port` is required; without it no registry is created and the push task emits a warning and does not start.

## Memory Monitor

Source: `node/src/memory_monitor.rs`, `node/src/cfg/memory_monitor_cfg/mod.rs`.

The memory monitor is a **Linux-only** essential task that polls available memory and triggers a graceful node shutdown before the OOM killer intervenes. On non-Linux platforms the monitor is silently disabled.

### Configuration

| Config key / CLI flag | Default | Description |
|---|---|---|
| `memory_threshold` / `--memory-threshold` | `0` (disabled) | Required available memory in MiB. Monitoring is disabled when `0`. Node shuts down gracefully if available memory drops below this value. |
| `memory_polling_period` / `--memory-polling-period` | `1` | Poll interval in seconds. If set to `0` with a non-zero threshold, monitoring is also disabled (with a warning). |

Default values confirmed in `res/cfg/default.toml:33–34`.

### Memory source detection

At startup the monitor probes for the first applicable source (`node/src/memory_monitor.rs:194–231`):

1. **cgroup v2** — `/sys/fs/cgroup/memory.max` + `/sys/fs/cgroup/memory.current` (Docker / Kubernetes with cgroup v2)
2. **cgroup v1** — `/sys/fs/cgroup/memory/memory.limit_in_bytes` + `memory.usage_in_bytes`
3. **`/proc/meminfo`** `MemAvailable` field — bare-metal or no cgroup limit

### Shutdown behaviour

The monitor logs at `WARN` when available memory drops below `2 × threshold`, and logs at `ERROR` and terminates when it drops below `threshold` (`node/src/memory_monitor.rs:163–169`). Because it is registered as an essential task, the node performs a graceful shutdown rather than a hard kill.

### Example

```toml
# config.toml — shut down gracefully when less than 512 MiB available
memory_threshold = 512
memory_polling_period = 5
```

## Storage Monitor

Source: `node/src/cfg/storage_monitor_params_cfg/mod.rs`, `node/src/service.rs:828–829`.

The storage monitor is a **Substrate upstream component** (`sc_storage_monitor::StorageMonitorService`) wired by the node. Midnight wraps its parameters in `StorageMonitorParamsCfg` and intentionally sets different defaults from the Substrate defaults (`node/src/cfg/storage_monitor_params_cfg/mod.rs:80–81`).

| Config key | Default | Description |
|---|---|---|
| `threshold` | `512` (MiB) | Required free space on the database storage volume. Node shuts down gracefully if available space drops below this value. `0` disables monitoring. |
| `polling_period` | `5` (seconds) | How often available space is polled. |

Default values confirmed in `res/cfg/default.toml:37–38`.

## Logs and Diagnostic RPCs

The node emits structured logs via the standard Substrate logging framework. Log verbosity is controlled with the `RUST_LOG` environment variable or `--log` CLI flag.

For live operational state — peer connectivity, sync progress, GRANDPA round status — use the JSON-RPC diagnostic methods (`system_health`, `system_peers`, `system_syncState`, `grandpa_roundState`). These return structured data without requiring a metrics stack.

See `midnight-node:node-rpc-api` for the full RPC method catalogue and response schemas, and `midnight-node:node-operations` for operational runbooks covering log interpretation and health checks.

## Cross-references

- `midnight-node:node-configuration` → `references/configuration-reference.md` — full table of all config keys including `prometheus_push_*`, `memory_threshold`, `threshold`, and `polling_period` with types and defaults
- `midnight-node:node-rpc-api` — `system_health`, `system_peers`, `system_syncState`, `grandpa_roundState` diagnostic RPCs
- `midnight-node:node-operations` — operational runbooks: log reading, health-check procedures, graceful shutdown
- `midnight-tooling:devnet` — local devnet stack; exposes the scrape endpoint at `http://localhost:9615/metrics` by default
