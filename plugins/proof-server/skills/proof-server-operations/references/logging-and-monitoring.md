# Proof Server Logging and Monitoring

The proof server emits structured logs via `tracing` and actix access logs. There is no Prometheus or metrics endpoint — monitoring relies on `/ready` polling and access-log latency.

## Log Surface

| Pattern | Level | When emitted |
|---------|-------|--------------|
| `%a %r; took %Ts` | ACCESS | Every HTTP request; actix access log — `%a` = remote IP, `%r` = request line, `%T` = elapsed seconds. Produced by `Logger::new("%a %r; took %Ts")` in `lib.rs`. |
| `Starting to process request for /k...` | INFO | Entry to the `/k` handler before processing (`endpoints.rs:160`). |
| `Starting to process request for /check...` | INFO | Entry to the `/check` handler (`endpoints.rs:177`). |
| `Starting to process request for /prove...` | INFO | Entry to the `/prove` handler (`endpoints.rs:250`). |
| `Starting to process request for /prove-tx...` | INFO | Entry to the `/prove-tx` handler (`endpoints.rs:333`). |
| `Received request: {}` | DEBUG | Raw hex-encoded request body, emitted immediately after each of the four handlers above. Only visible when `--verbose` is passed. |
| `Ensuring zswap key material is available...` | INFO | Startup, before fetching public parameters (`main.rs:65`). Suppressed when `--no-fetch-params` is set. |

The `zkir` tracing target is forced **OFF** regardless of `--verbose`. `init_logging` sets the default level to `DEBUG` when `--verbose` is supplied, otherwise `INFO`. All other targets follow the default level.

## No Metrics Endpoint

The proof server ships **no Prometheus or metrics endpoint**. There is no `prometheus`, `metrics`, or `opentelemetry` dependency in `Cargo.toml`.

Monitor the server using two complementary signals:

**1. `/ready` polling — utilization and queue depth**

`GET /ready` returns JSON with live worker-pool state even under load:

```text
{"status":"ok","jobsProcessing":1,"jobsPending":0,"jobCapacity":0}
```

| Field | Meaning |
|-------|---------|
| `status` | `"ok"` (200) or `"busy"` (503 when queue is full) |
| `jobsProcessing` | Workers currently proving |
| `jobsPending` | Jobs queued but not yet picked up |
| `jobCapacity` | Configured max queue depth; `0` = unlimited |

Utilization ≈ `jobsProcessing / num-workers` (pass `--workers N` at startup; default = logical CPU count).

**2. Access-log latency — proving-time trends**

Each request produces a line such as:

```text
127.0.0.1 POST /prove HTTP/1.1; took 4s
```

The `took <T>s` value reflects wall-clock proving time per request. Stream or tail the server log and track this field to detect proof-time regressions after toolchain upgrades.

## Alerting Recipe (Without Metrics)

Scrape `/ready` on a fixed interval (e.g. every 15 s) and alert on:

- **503 response** — the job queue is at capacity (`--job-capacity > 0` only; with the default of `0` the queue is unlimited and 503 is never returned).
- **`jobsPending` growing monotonically** — backlog is building faster than workers can drain it; add workers or scale horizontally.
- **`jobsProcessing` == `num-workers` sustained** — server is saturated; new requests will queue.
- **`took <T>s` rising** — parse access logs for the `/prove` and `/prove-tx` lines and alert when median latency exceeds a baseline (e.g. 2× the p50 at last release).

No scraping agent is bundled; use any HTTP-capable monitoring tool (curl cron job, Datadog synthetics, Prometheus blackbox exporter against `/ready`).

## Cross-references

- `proof-server:proof-server-operations` — troubleshooting guide, `/ready` response interpretation, worker-pool tuning
- `proof-server:proof-server-api` — full endpoint documentation including `/ready` JSON schema and status codes
