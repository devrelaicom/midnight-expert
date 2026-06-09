# Metadata Endpoint Examples

Runnable `curl` examples for every proof server metadata and health endpoint. All examples target a local server on the default port; replace `http://localhost:6300` with your server's address as needed.

Responses shown are the exact output captured from a live `midnightntwrk/proof-server:8.1.0` instance.

For proving endpoints (`/prove`, `/prove-tx`, `/check`, `/k`) that require a binary `IrSource` request body, see `examples/constructing-a-prove-request.md`.

For HTTP status code semantics, see `proof-server:proof-server-api` and its status-codes reference.

---

## `GET /`

Alias for `/health`. Returns liveness status as JSON.

```bash
curl -s http://localhost:6300/
```

```json
{"status":"ok","timestamp":"2026-06-09 07:04:11.226863336 +00:00:00"}
```

---

## `GET /health`

Primary liveness check. Returns 200 as soon as the HTTP listener is ready, even while key material is still being pre-fetched in the background.

```bash
curl -s http://localhost:6300/health
```

```json
{"status":"ok","timestamp":"2026-06-09 07:04:11.234322127 +00:00:00"}
```

---

## `GET /version`

Returns the proof server version as plain text (no JSON wrapper).

```bash
curl -s http://localhost:6300/version
```

```text
8.1.0
```

---

## `GET /proof-versions`

Returns the list of supported ZKIR proof versions as a plain-text JSON array.

```bash
curl -s http://localhost:6300/proof-versions
```

```text
["V2"]
```

The response is plain text, not a JSON `Content-Type` response. V2 is the current production default; V3 is behind an experimental feature flag and will not appear here unless enabled.

---

## `GET /ready`

Readiness check with worker pool utilization. Returns 200 when the server can accept work; returns 503 when the job queue has reached capacity (only possible when `--job-capacity > 0`).

```bash
curl -s http://localhost:6300/ready
```

```json
{"status":"ok","jobsProcessing":0,"jobsPending":0,"jobCapacity":0,"timestamp":"2026-06-09 07:04:11.253857461 +00:00:00"}
```

| Field | Description |
|-------|-------------|
| `status` | `"ok"` when accepting work; `"busy"` when job queue is full |
| `jobsProcessing` | Jobs currently being proved by workers |
| `jobsPending` | Jobs waiting in the queue |
| `jobCapacity` | Maximum queue depth (0 = unlimited, the default) |
| `timestamp` | UTC timestamp |

When `jobCapacity` is `0`, the queue is unlimited and the server never returns 503 from this endpoint.

---

## `GET /fetch-params/{k}` — success

Pre-warm the public parameter cache for a specific k-value (0–25). Returns `success` as plain text when the parameters are fetched or already cached.

```bash
curl -s http://localhost:6300/fetch-params/13
```

```text
success
```

Status code: `200`. The first call for a k-value that has not been cached may take several seconds while parameters are downloaded. Subsequent calls return immediately.

> **Note:** This route is only registered when the server was started **without** `--no-fetch-params`. When that flag is set, the route is never registered and requests to `/fetch-params/{k}` return **404**. In that mode, parameters are fetched on-demand when the first `/prove` request for each k-value arrives.

---

## `GET /fetch-params/{k}` — k out of range

```bash
curl -s -w ' [HTTP %{http_code}]' http://localhost:6300/fetch-params/99
```

```text
k=99 out of range [HTTP 400]
```

Valid k-values are integers from 0 to 25 inclusive. Any value outside that range returns 400 with the plain-text message `k=<n> out of range`.

---

## Wrong HTTP method — `GET /prove-tx`

The proving endpoints (`/prove`, `/prove-tx`, `/check`, `/k`) only accept `POST`. Sending a `GET` request returns 404 — there is no registered handler for `GET` on those paths.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:6300/prove-tx
```

```text
404
```

The same 404 is returned for any unknown route or method combination. There is no `405 Method Not Allowed` — the router simply has no handler for the route.

---

## Cross-references

- `proof-server:proof-server-api` — full endpoint reference including binary proving endpoints and request/response formats
- `proof-server:proof-server-api` status-codes reference — complete HTTP status code catalog with per-endpoint applicability table
