---
name: proof-server-architecture
description: This skill covers proof server internals and how the proof server works. Use it when the user asks about architecture, worker pool, job queue, job lifecycle, proving pipeline, concurrency, capacity limiting, garbage collection, ZKIR versioning, key material management, key prefetching, binary serialization format, the midnight-proof-server binary, Rust codebase, components, dependencies, Docker image build, or multi-arch support.
version: 0.1.0
---

# Proof Server Architecture

The Midnight proof server is a Rust service built on actix-web v4 that generates zero-knowledge proofs for Midnight transactions. The binary is named `midnight-proof-server`. For basic Docker setup, health checks, and running the proof server, see `midnight-tooling:proof-server`. This skill covers internal architecture, component design, and the proving pipeline.

## Core Components

```text
midnight-proof-server binary
├── main.rs          CLI parsing, startup orchestration
├── lib.rs           HTTP server setup (actix-web v4)
├── endpoints.rs     Request handlers for all API routes
├── worker_pool.rs   Async channel-based job queue
└── versioned_ir.rs  ZKIR version dispatch (V2/V3)
```

### Component Responsibilities

| Component | Role |
|-----------|------|
| `main.rs` | Parses CLI flags and env vars, initializes key material, launches HTTP server |
| `lib.rs` | Configures actix-web server, sets up routes, manages app state |
| `endpoints.rs` | Implements all HTTP endpoint handlers (`/prove`, `/check`, `/k`, etc.) |
| `worker_pool.rs` | Manages async job queue with configurable parallelism and capacity |
| `versioned_ir.rs` | Dispatches proving requests to the correct ZKIR version handler |

## Worker Pool Architecture

The worker pool uses an async channel-based job queue to manage proof generation concurrently.

```text
HTTP Request ──→ endpoints.rs ──→ Worker Pool Channel
                                       │
                                       ▼
                              ┌──────────────────┐
                              │   Job Queue       │
                              │  (async channel)  │
                              └──────┬───────────┘
                                     │
                          ┌──────────┼──────────┐
                          ▼          ▼          ▼
                      Worker 1   Worker 2   Worker N
                      (own rt)   (own rt)   (own rt)
```

### Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--num-workers` | 2 | Number of parallel proving threads |
| `--job-capacity` | 0 (unlimited) | Max pending jobs in queue |
| `--job-timeout` | 600.0s (10 min) | TTL for each job before garbage collection |

### Job Lifecycle

Every proving request follows this state machine:

```text
Pending ──→ Processing ──→ Success
                       └──→ Error
                       └──→ Cancelled (timeout/GC)
```

1. **Pending** -- Job is submitted to the channel and waits for an available worker
2. **Processing** -- A worker picks up the job, creates its own tokio runtime, and begins proof generation
3. **Success** -- Proof generated and returned to the caller
4. **Error** -- Proving failed (invalid input, internal error)
5. **Cancelled** -- Job exceeded its TTL and was removed by garbage collection

### Capacity Limiting

When `--job-capacity` is set to a non-zero value, the worker pool enforces a maximum queue depth. If the queue is full when a new `/prove` request arrives, the server returns HTTP 429 (Too Many Requests). This prevents unbounded memory growth under heavy load.

### Garbage Collection

A background task runs every 10 seconds and removes jobs that have exceeded their TTL (`--job-timeout`). Each worker creates its own tokio runtime for CPU-intensive proof generation using `spawn_blocking` threads. This isolation prevents a slow proof from starving the HTTP server's event loop.

## Key Material Management

On startup, the proof server pre-fetches cryptographic material required for proof generation:

### Public Parameters

Pre-fetches public parameters for k values 10 through 15. These parameters define the polynomial commitment scheme size and are shared across all circuits with the same k value.

### Proving Keys

Pre-fetches proving keys for 4 built-in circuits:

| Circuit | Purpose |
|---------|---------|
| `zswap/spend` | Spending a shielded coin (nullifier creation) |
| `zswap/output` | Creating a shielded coin (commitment creation) |
| `zswap/sign` | Schnorr signature proof for transaction binding |
| `dust/spend` | Spending native DUST tokens |

### Data Provider

Uses `MidnightDataProvider` with `FetchMode::OnDemand` to manage key material. On-demand mode means any keys not pre-fetched at startup are fetched on first use (application-specific proving keys for custom Compact contracts).

### Startup Behavior

Pre-fetching parameters and keys can take several minutes depending on network speed and cache state. Use `--no-fetch-params` to skip pre-fetching for faster startup, but the first proof request for each circuit will incur the fetch latency.

## ZKIR Versioning

The proof server supports multiple versions of the Zero-Knowledge Intermediate Representation (ZKIR):

| Version | Status | Notes |
|---------|--------|-------|
| V2 | Default | Production-ready, used by current Compact compiler output |
| V3 | Experimental | Behind feature flag, not enabled in standard builds |

The `versioned_ir.rs` module dispatches proving requests to the correct backend based on the ZKIR version embedded in the proof preimage. The `/proof-versions` endpoint reports which versions the running server supports (typically `["V2"]`).

## Binary Serialization

All proving endpoints (`/prove`, `/prove-tx`, `/check`, `/k`) use a custom tagged binary serialization format -- not JSON. This format is defined by the `midnight-serialize` crate and is the same format used by the Midnight node and wallet SDK for proof-related data.

The binary format provides:
- Compact encoding for large cryptographic structures
- Tagged fields for forward compatibility
- Efficient deserialization without schema negotiation

Health and metadata endpoints (`/health`, `/ready`, `/version`, `/proof-versions`) use JSON or plain text.

## Key Dependencies

| Crate | Purpose |
|-------|---------|
| `midnight-ledger` (proving feature) | Core proving logic and circuit execution |
| `midnight-zswap` | Shielded token proof generation (spend/output/sign) |
| `midnight-zkir` | ZKIR parsing and version handling |
| `midnight-base-crypto` | Cryptographic primitives (field elements, curves) |
| `midnight-transient-crypto` | Transient hash and commitment functions |
| `midnight-serialize` | Binary serialization/deserialization |

The workspace version is **<version>**. Version numbers reflect the release at time of writing and may have been superseded. Replace `<version>` with the version matching your target Midnight network. Check `midnight-tooling:release-notes` for current versions.

## Docker / OCI Image

The proof server Docker image is built with a multi-stage process:

| Property | Value |
|----------|-------|
| Build system | Nix flakes |
| Binary linking | Statically linked (musl) |
| Base image | Minimal (bash + coreutils + CA certificates) |
| Architectures | `amd64`, `arm64` (multi-arch manifest) |
| Registries | `ghcr.io`, Docker Hub (`midnightntwrk/proof-server`) |

The static musl build ensures the binary runs without any shared library dependencies, making the image portable across Linux distributions. The minimal base image reduces attack surface and image size.

## Cross-References

| Skill | Relevance |
|-------|-----------|
| `midnight-tooling:proof-server` | Basic Docker setup, health checks, running the proof server |
| `compact-core:compact-circuit-costs` | Understanding proof generation costs and circuit complexity |
| `compact-core:compact-compilation` | Compiler output (ZKIR, proving keys) consumed by the proof server |
