---
name: proof-server:proof-server-api
description: This skill covers the proof server REST API and HTTP interface. Use it when the user asks about the prove, check, k-value, fetch-params, or proof-versions endpoints, the deprecated prove-tx endpoint, proof generation API, proof server health check, proof server readiness check, proof server port, worker utilization, queue capacity, request/response format, binary serialization format, status codes, CORS policy, or error codes.
version: 0.1.0
---

# Proof Server API Reference

Complete HTTP API reference for the Midnight proof server. The server listens on port 6300 by default. For basic setup and Docker usage, see `midnight-tooling:proof-server`. For internal architecture details, see `proof-server:proof-server-architecture`.

## Endpoint Summary

| Endpoint | Method | Purpose | Content Type |
|----------|--------|---------|-------------|
| `/` | GET | Health check (alias) | JSON |
| `/health` | GET | Health check | JSON |
| `/version` | GET | Server version | Plain text |
| `/ready` | GET | Readiness + utilization | JSON |
| `/proof-versions` | GET | Supported proof versions | Plain text |
| `/prove` | POST | Generate a single ZK proof | Binary |
| `/prove-tx` | POST | Prove entire transaction (DEPRECATED) | Binary |
| `/check` | POST | Validate proof preimage against IR | Binary |
| `/k` | POST | Get k-value for IR source | Binary |
| `/fetch-params/{k}` | GET | Fetch public params for k | Plain text |

## Health & Metadata Endpoints

### `GET /` and `GET /health`

Health check endpoint. Both routes return identical responses.

**Request:** None

**Response (200):**

```json
{"status": "ok", "timestamp": "2026-06-09 07:04:11.226 +00:00:00"}
```

Use this for basic liveness checks. The server returns 200 as soon as the HTTP listener is ready, even if key material is still being pre-fetched.

### `GET /version`

Returns the proof server version as a plain text string.

**Request:** None

**Response (200):**

```text
<version>
```

> Replace `<version>` with the version matching your target Midnight network. Check `midnight-tooling:release-notes` for current versions.

### `GET /ready`

Readiness check that includes worker pool utilization. Use this for load balancing and orchestration health checks.

**Request:** None

**Response (200 -- ready):**

```json
{
  "status": "ok",
  "jobsProcessing": 1,
  "jobsPending": 0,
  "jobCapacity": 10,
  "timestamp": "2026-06-09 07:04:11.226 +00:00:00"
}
```

**Response (503 -- busy):**

```json
{
  "status": "busy",
  "jobsProcessing": 2,
  "jobsPending": 10,
  "jobCapacity": 10,
  "timestamp": "2026-06-09 07:04:11.226 +00:00:00"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | `"ok"` when accepting work, `"busy"` when job queue is full |
| `jobsProcessing` | number | Jobs currently being proved by workers |
| `jobsPending` | number | Jobs waiting in the queue for a worker |
| `jobCapacity` | number | Maximum queue depth (0 = unlimited) |
| `timestamp` | string | `OffsetDateTime`-style timestamp (`YYYY-MM-DD HH:MM:SS.ssssss +00:00:00`), not ISO-8601 `Z` format |

The HTTP status code reflects the readiness state: **200** when the server can accept new proving requests, **503** when the job queue has reached capacity.

### `GET /proof-versions`

Returns the list of supported ZKIR proof versions.

**Request:** None

**Response (200):**

```text
["V2"]
```

This is returned as plain text, not JSON. The current production default is V2 only. V3 is behind an experimental feature flag.

## Proving Endpoints

All proving endpoints use the custom tagged binary serialization format defined by the `midnight-serialize` crate. Requests and responses are **not JSON** -- they are binary-encoded cryptographic structures. See `references/binary-serialization.md` for the full tag table and per-endpoint request/response type definitions.

### `POST /prove`

Generate a single zero-knowledge proof. This is the primary proving endpoint used by DApps and the wallet SDK.

**Request body (binary):** Serialized tuple of `(ProofPreimageVersioned, Option<ProvingKeyMaterial>, Option<Fr>)`

| Field | Type | Description |
|-------|------|-------------|
| `ProofPreimageVersioned` | binary | The proof preimage containing circuit inputs and witness data |
| `Option<ProvingKeyMaterial>` | binary | Optional custom proving key (None = use built-in key) |
| `Option<Fr>` | binary | Optional field element for randomization |

**Response (200, binary):** Serialized `ProofVersioned` -- the generated ZK proof.

**Error responses:**

| Status | Meaning |
|--------|---------|
| 400 | Invalid request (malformed binary data, unsupported proof version) |
| 429 | Capacity limit reached (job queue full, `--job-capacity` is set) |
| 500 | Internal proving error |

### `POST /prove-tx` (DEPRECATED)

Prove an entire transaction by generating proofs for all its contract calls. **This endpoint is deprecated** -- use `/prove` for individual proofs instead.

**Request body (binary):** Serialized tuple of `(Transaction, HashMap<String, ProvingKeyMaterial>)`

| Field | Type | Description |
|-------|------|-------------|
| `Transaction` | binary | The full transaction to prove |
| `HashMap<String, ProvingKeyMaterial>` | binary | Map of circuit name to proving key for each contract call |

**Response (200, binary):** Serialized `Transaction` with all proofs filled in.

**Error responses:**

| Status | Meaning |
|--------|---------|
| 400 | Invalid request |
| 429 | Capacity limit reached (job queue full, `--job-capacity` is set) |
| 500 | Internal proving error |

### `POST /check`

Validate a proof preimage against its IR without generating a proof. Useful for debugging circuit issues before committing to the full proving computation.

**Request body (binary):** Serialized tuple of `(ProofPreimageVersioned, Option<WrappedIr>)`

| Field | Type | Description |
|-------|------|-------------|
| `ProofPreimageVersioned` | binary | The proof preimage to validate |
| `Option<WrappedIr>` | binary | Optional IR to check against (None = use embedded IR) |

**Response (200, binary):** Serialized `Vec<Option<u64>>` -- proving-prep information from running the circuit, **not** a per-constraint pass/fail validator. The vector has one entry per public-input "block" (each block corresponds to one VM instruction). An entry reports whether that block was omitted because its branch was not taken, and if so how many zero-padding elements are needed: roughly, `None` means the block is present, while `Some(n)` means the block was omitted and needs `n` zero-padding elements. This is the same branch-omission / zero-padding data the prover uses to assemble the final transcript -- it does not report which constraints were satisfied or violated, and there are no "failing values".

**Error responses:**

`/check` runs through the worker pool like `/prove`, so it is not limited to 400 errors:

| Status | Meaning |
|--------|---------|
| 400 | Invalid request (malformed binary data, unsupported proof version) |
| 429 | Capacity limit reached (job queue full, `--job-capacity` is set) |
| 500 | Internal proving error |

### `POST /k`

Get the k-value (circuit size parameter) for a given IR source. The k-value determines which public parameters are needed for proof generation.

**Request body (binary):** Serialized `IrSource`

**Response (200, plain text):** The k-value as a u8 integer (typically 10-17).

**Error responses:**

| Status | Meaning |
|--------|---------|
| 400 | Invalid IR source |

### `GET /fetch-params/{k}`

Trigger fetching of public parameters for the specified k-value. This route is only **registered** when the server was **not** started with `--no-fetch-params`. When `--no-fetch-params` is set the route is not registered at all, so requests to this path get an HTTP 404.

**Path parameter:** `k` -- integer from 0 to 25

**Response (200, plain text):**

```text
success
```

**Error responses:**

| Status | Meaning |
|--------|---------|
| 400 | k-value out of range (must be 0-25) |

This endpoint is useful for pre-warming the parameter cache for specific circuit sizes without waiting for a proving request to trigger the fetch.

> **Note:** This route is only registered when the server was started **without** `--no-fetch-params`. When `--no-fetch-params` is set, the route is never registered, so requests to `/fetch-params/{k}` get an HTTP 404 from the unregistered route (not a handler error). In that mode, parameters are fetched on-demand when the first `/prove` request for each k-value arrives. See `proof-server:proof-server-configuration` for details on the flag.

## CORS Policy

The proof server uses a permissive CORS policy -- all origins are allowed. This enables browser-based DApps to call the proof server directly during development. In production, the proof server typically runs behind a reverse proxy or is accessed server-side.

## Error Response Format

Health and metadata endpoints return JSON error responses. Proving endpoints return plain text error messages since the normal response format is binary. For a complete catalog of HTTP status codes returned by each endpoint (including the 428 Precondition Required response for version mismatches), see `references/status-codes.md`.

## Usage Patterns

### DApp Integration

DApps interact with the proof server through the Midnight wallet SDK, which handles binary serialization automatically. Direct API calls to proving endpoints require using the `midnight-serialize` crate or compatible serialization.

```text
DApp ──→ Wallet SDK ──→ Proof Server (/prove) ──→ ZK Proof
                                                      │
DApp ←── Wallet SDK ←── Proof (binary) ←──────────────┘
```

### Debugging Workflow

1. Check server health: `GET /health`
2. Check readiness and queue depth: `GET /ready`
3. Verify supported versions: `GET /proof-versions`
4. Validate circuit before proving: `POST /check`
5. Generate proof: `POST /prove`

### Pre-warming Parameters

If the server was started without `--no-fetch-params`, pre-warm parameters for expected circuit sizes:

```bash
# Fetch params for k-values 10 through 15
for k in $(seq 10 15); do
  curl -s http://localhost:6300/fetch-params/$k
done
```

## References

| Name | Description | When used |
|------|-------------|-----------|
| `references/binary-serialization.md` | Tagged binary wire format and per-endpoint request/response type definitions for the `midnight-serialize` crate | When constructing or parsing raw binary payloads for `/prove`, `/prove-tx`, `/check`, or `/k` |
| `references/status-codes.md` | Complete HTTP status code catalog for all endpoints, including 428 Precondition Required for version mismatches | When diagnosing unexpected HTTP responses or implementing error handling |

## Examples

| Name | Description | When used |
|------|-------------|-----------|
| `examples/metadata-endpoints.md` | Runnable curl commands for all metadata endpoints (`/health`, `/version`, `/ready`, `/proof-versions`, `/fetch-params`) | When verifying server health, checking readiness, or testing the metadata API |
| `examples/constructing-a-prove-request.md` | Worked, executed `/prove` request showing binary serialization end-to-end | When integrating the `/prove` endpoint directly or debugging proof generation issues |

## Cross-References

- `proof-server:proof-server-architecture` — Internal worker pool, queue, and caching architecture
- `proof-server:proof-server-configuration` — CLI flags including `--no-fetch-params`, `--job-capacity`, and network settings
- `midnight-tooling:proof-server` — Docker setup, version selection, and operational guidance
