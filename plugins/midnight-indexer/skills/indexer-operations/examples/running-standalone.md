# Running the Standalone Indexer

Worked, executed example of inspecting the indexer running in **standalone mode**. The local Midnight devnet runs the indexer as the single `indexer-standalone` binary (SQLite storage, in-process bus), so it is the easiest place to observe standalone behaviour end-to-end.

> **Captured against:** the local devnet's indexer image `midnightntwrk/indexer-standalone:4.2.1` (node `0.22.5`, proof-server `8.1.0`), 2026-06. The devnet image (`4.2.1`) is one minor behind the `4.3.3` source documented in the reference files; one behavioural difference is called out below (`/live`). The GraphQL schema shape used here is stable across both. To start the stack, see `midnight-tooling:devnet`.

## 1. Confirm the standalone container is up

The devnet runs exactly one indexer container (standalone), not the four cloud services:

```text
$ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' | grep -E 'NAMES|indexer'
NAMES                IMAGE                                     STATUS
midnight-indexer     midnightntwrk/indexer-standalone:4.2.1    Up 34 minutes (healthy)
```

`(healthy)` comes from the Docker Compose `HEALTHCHECK`, which runs `cat /var/run/indexer-standalone/running` — a file the entrypoint creates on start and removes on exit. It is a **liveness** signal (the process is up), not a readiness signal.

## 2. Health probes

The standalone binary serves health routes on the same listener as the GraphQL API (port **8088**):

```text
$ curl -s -w '\n[HTTP %{http_code}]\n' http://127.0.0.1:8088/ready
[HTTP 200]                       # caught up with the node → ready

$ curl -s -w '\n[HTTP %{http_code}]\n' http://127.0.0.1:8088/live
[HTTP 404]                       # NOTE: /live does not exist on 4.2.1
```

- `GET /ready` returns **200** when the chain-indexer has caught up with the node, **503** with body `"indexer has not yet caught up with the node"` while still syncing. Both bodies are empty on 200.
- `GET /live` is **added in 4.3.3** (always-200 liveness probe); on the older `4.2.1` devnet image it is **not registered** and returns **404**. On 4.3.3+, use `/live` for Kubernetes liveness and `/ready` for readiness. On 4.2.1, only `/ready` exists — use the Docker running-file (or any cheap GraphQL query) for liveness.

See `references/monitoring-and-troubleshooting.md` for the full health-check matrix.

## 3. A basic query

The standalone API answers the same GraphQL as cloud mode. Fetch the latest block:

```text
$ curl -s http://127.0.0.1:8088/api/v4/graphql \
    -X POST -H 'content-type: application/json' \
    -d '{"query":"{ block { height hash protocolVersion timestamp author } }"}'
{"data":{"block":{
  "height":63428,
  "hash":"a80331cd15247a06ee28facb52d9aefe2def40b175943a8175fd386ecd7b8c88",
  "protocolVersion":22000,
  "timestamp":1781002746002,
  "author":"d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d"}}}
```

Note `timestamp` is `1781002746002` — a raw Substrate moment in **milliseconds**, not seconds (divide by 1000 for a UNIX-seconds timestamp). The `protocolVersion` `22000` corresponds to the devnet's node line.

The `v3` path is kept as a backwards-compatibility alias for `v4`:

```text
$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/api/v3/graphql \
    -X POST -H 'content-type: application/json' -d '{"query":"{ block { height } }"}'
200
```

## 4. Metrics are off by default

The Prometheus exporter (port 9000) is **disabled** unless `APP__TELEMETRY__METRICS__ENABLED=true`. On the default devnet it is not enabled, so port 9000 is not listening:

```text
$ curl -s -o /dev/null -w 'HTTP %{http_code}\n' --max-time 4 http://127.0.0.1:9000/metrics
HTTP 000                         # connection refused — exporter not started / port not published
```

To enable metrics you set the env var **and** publish port 9000 from the container. See `references/monitoring-and-troubleshooting.md` for the metric catalog.

## 5. Errors and transport rules

Unknown fields produce a standard GraphQL error envelope (no `extensions.code`):

```text
$ curl -s http://127.0.0.1:8088/api/v4/graphql \
    -X POST -H 'content-type: application/json' -d '{"query":"{ invalidField }"}'
{"data":null,"errors":[{"message":"Unknown field \"invalidField\" on type \"Query\".",
                        "locations":[{"line":1,"column":3}]}]}
```

Subscriptions are **WebSocket-only** — sending one over HTTP POST is rejected:

```text
$ curl -s http://127.0.0.1:8088/api/v4/graphql \
    -X POST -H 'content-type: application/json' \
    -d '{"query":"subscription { zswapLedgerEvents(id:0){ id } }"}'
{"data":null,"errors":[{"message":"Subscriptions are not supported on this transport."}]}
```

For executed subscription walkthroughs over WebSocket, see `midnight-indexer:indexer-graphql-api` → `examples/subscription-examples.md`.

## What this shows about standalone mode

| Observation | Implication |
|-------------|-------------|
| One container, `(healthy)` via a running-file | Standalone bundles chain/wallet/api/spo into one process; the Docker healthcheck is liveness-only |
| `/ready` 200, `/live` 404 (on 4.2.1) | Readiness reflects caught-up state; `/live` is a 4.3.3 addition — check your image version |
| `timestamp` in ms | `Block.timestamp` is the raw Substrate millisecond value |
| Port 9000 refused | Telemetry is opt-in; no metrics without `APP__TELEMETRY__METRICS__ENABLED=true` |
| HTTP rejects subscriptions | Use the `/api/v4/graphql/ws` WebSocket endpoint for streaming |

## Cross-references

- `midnight-tooling:devnet` — starting/stopping the local devnet stack that runs this standalone indexer
- `references/monitoring-and-troubleshooting.md` — health, metrics, logs, and failure modes in depth
- `midnight-indexer:indexer-architecture` → `references/deployment-and-crates.md` — standalone vs cloud topology and the binary layout
- `midnight-indexer:indexer-architecture` → `references/configuration-reference.md` — the `APP__*` keys that configure the standalone binary
- `midnight-indexer:indexer-graphql-api` → `examples/subscription-examples.md` — executed WebSocket subscription examples
