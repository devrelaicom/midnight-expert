# Proof Server HTTP Status Codes

Proving endpoints (`/prove`, `/prove-tx`, `/check`, `/k`) return **plain-text** error messages — the normal success body is binary. `/health` and `/ready` return **JSON**; `/version` and `/proof-versions` return **plain text**.

## Status Code Catalog

| Code | Meaning | When it occurs | Source |
|------|---------|----------------|--------|
| `200 OK` | Success | Request processed normally | — |
| `400 Bad Request` | Invalid input | `WorkError::BadInput` (malformed or undeserializable binary body); `WorkerPoolError::JobNotPending` (job exists but is not in pending state); `/fetch-params/{k}` with k outside 0–25 | `worker_pool.rs` `From<WorkError>` / `From<WorkerPoolError>` impls; `endpoints.rs` `fetch_k` |
| `404 Not Found` | Unknown route or unregistered handler | Unknown route, wrong HTTP method (e.g. `GET /prove-tx`), or `/fetch-params/{k}` when the server was started with `--no-fetch-params` (route is never registered) | `lib.rs` conditional `app.service(fetch_k)`; `integration_tests.rs` `rejects_get_requests`, `not_available_by_default` |
| `428 Precondition Required` | Job not found | `WorkerPoolError::JobMissing` — the referenced job UUID does not exist in the pool (defined in the error mapping; not reachable through the current public endpoints, which all use `submit_and_subscribe`) | `worker_pool.rs` `From<WorkerPoolError>` impl |
| `429 Too Many Requests` | Queue capacity reached | `WorkerPoolError::JobQueueFull` — only possible when the server was started with `--job-capacity > 0`; with the default of 0 (unlimited) this code is never returned | `worker_pool.rs` `From<WorkerPoolError>` impl |
| `500 Internal Server Error` | Server-side failure | `WorkError::InternalError`, `WorkError::CancelledUnexpectedly`, `WorkError::JoinError`; `WorkerPoolError::ChannelClosed` | `worker_pool.rs` `From<WorkError>` / `From<WorkerPoolError>` impls |
| `503 Service Unavailable` | Server busy | `GET /ready` when the job queue is full (`Status::Busy`); the JSON body still contains full utilization data | `endpoints.rs` `Status::Busy` → `StatusCode::SERVICE_UNAVAILABLE` |

## Error Message Strings

400 responses from proving endpoints include a plain-text description:

```text
expected header tag '<tag>', got ''
```

Returned when the request body is empty or cannot be deserialized — `<tag>` is the expected binary frame tag for the endpoint and the trailing quotes show what was actually received (empty here). Confirmed by `integration_tests.rs` `rejects_empty_body` test (line 341) and the format string in `serialize/src/deserializable.rs:109`.

```text
k=<n> out of range
```

Returned by `/fetch-params/{k}` when k is not in the range 0–25. Confirmed by `endpoints.rs` line 83 and `integration_tests.rs` `rejects_invalid_k` test (line 911).

## Per-Endpoint Applicability

| Endpoint | 200 | 400 | 404 | 428 | 429 | 500 | 503 |
|----------|-----|-----|-----|-----|-----|-----|-----|
| `POST /prove` | yes | yes | — | — | yes* | yes | — |
| `POST /prove-tx` | yes | yes | — | — | yes* | yes | — |
| `POST /check` | yes | yes | — | — | yes* | yes | — |
| `POST /k` | yes | yes | — | — | — | — | — |
| `GET /fetch-params/{k}` | yes | yes | yes† | — | — | — | — |
| `GET /ready` | yes | — | — | — | — | — | yes |
| `GET /health`, `GET /` | yes | — | — | — | — | — | — |
| Unknown route / wrong method | — | — | yes | — | — | — | — |

\* 429 only when `--job-capacity > 0` (default 0 = unlimited, so 429 is never returned by default).

† 404 when route is unregistered because server started with `--no-fetch-params`.

## Cross-references

- `proof-server:proof-server-api` — full endpoint documentation with request/response formats
- `proof-server:proof-server-operations` — troubleshooting guide for proof server errors
- `midnight-status-codes:status-codes` — full Midnight ecosystem error code reference
