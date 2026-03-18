---
name: proof-server-configuration
description: This skill should be used when the user asks about proof server configuration, proof server flags, proof server CLI options, num-workers setting, job-capacity setting, job-timeout setting, no-fetch-params flag, MIDNIGHT_PROOF_SERVER environment variables, proof server tuning, proof server port configuration, proof server verbose mode, proof server memory requirements, proof server startup time, proof server resource planning, or proof server production settings.
version: 0.1.0
---

# Proof Server Configuration

Complete reference for all CLI flags and environment variables that control the Midnight proof server. For basic Docker setup and running, see `midnight-tooling:proof-server`. For internal architecture, see `proof-server-architecture`.

## CLI Flags & Environment Variables

Every CLI flag has a corresponding environment variable. When both are set, the CLI flag takes precedence.

| Flag | Env Var | Default | Description |
|------|---------|---------|-------------|
| `-p`, `--port` | `MIDNIGHT_PROOF_SERVER_PORT` | `6300` | HTTP listen port |
| `-v`, `--verbose` | `MIDNIGHT_PROOF_SERVER_VERBOSE` | `false` | Enable DEBUG-level logging |
| `--job-capacity` | `MIDNIGHT_PROOF_SERVER_JOB_CAPACITY` | `0` (unlimited) | Maximum number of pending jobs in the queue |
| `--num-workers` | `MIDNIGHT_PROOF_SERVER_NUM_WORKERS` | `2` | Number of parallel proving threads |
| `--job-timeout` | `MIDNIGHT_PROOF_SERVER_JOB_TIMEOUT` | `600.0` (10 min) | Job time-to-live in seconds before garbage collection |
| `--no-fetch-params` | `MIDNIGHT_PROOF_SERVER_NO_FETCH_PARAMS` | `false` | Skip pre-fetching ZK parameters and proving keys on startup |

## Flag Details

### `-p`, `--port`

The HTTP port the proof server listens on. Change this when running multiple proof server instances or when port 6300 conflicts with another service.

```bash
# CLI
midnight-proof-server --port 6301

# Environment variable
MIDNIGHT_PROOF_SERVER_PORT=6301 midnight-proof-server

# Docker
docker run -d --name midnight-proof-server -p 6301:6301 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server --port 6301
```

When changing the port with Docker, update both the container port (`--port` flag inside the container) and the Docker port mapping (`-p` flag).

### `-v`, `--verbose`

Enables DEBUG-level logging output. Without this flag, only INFO and above are logged. Verbose mode is useful for diagnosing proving failures, timing issues, and key material fetching.

```bash
# CLI
midnight-proof-server -v

# Docker (recommended for development)
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server -v
```

### `--num-workers`

Controls how many proof generation tasks can run in parallel. Each worker creates its own tokio runtime and processes one proof at a time using `spawn_blocking`.

```bash
# CLI — 4 workers for a quad-core machine
midnight-proof-server --num-workers 4

# Environment variable
MIDNIGHT_PROOF_SERVER_NUM_WORKERS=4 midnight-proof-server

# Docker
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server --num-workers 4
```

Worker count does not need to match CPU core count exactly. Proving is CPU-intensive, so more workers than cores leads to contention. Fewer workers than cores leaves headroom for the HTTP server and garbage collection.

### `--job-capacity`

Sets the maximum number of pending jobs in the worker pool queue. When the queue is full, new `/prove` requests receive HTTP 429 (Too Many Requests). A value of 0 (default) means unlimited queue depth.

```bash
# CLI — limit to 20 pending jobs
midnight-proof-server --job-capacity 20

# Environment variable
MIDNIGHT_PROOF_SERVER_JOB_CAPACITY=20 midnight-proof-server
```

Setting a capacity limit is recommended for production to prevent unbounded memory growth when the server receives more requests than it can process.

### `--job-timeout`

Sets the time-to-live (TTL) in seconds for each job. A background garbage collector runs every 10 seconds and removes jobs that have exceeded this timeout. Applies to jobs in any state (pending, processing).

```bash
# CLI — 5 minute timeout
midnight-proof-server --job-timeout 300

# Environment variable
MIDNIGHT_PROOF_SERVER_JOB_TIMEOUT=300 midnight-proof-server
```

The default of 600 seconds (10 minutes) is generous for most circuits. Complex circuits with high k-values may need longer timeouts. Simple circuits typically complete in under 30 seconds.

### `--no-fetch-params`

Skips the pre-fetching of ZK public parameters (k=10 through k=15) and built-in proving keys (zswap/spend, zswap/output, zswap/sign, dust/spend) on startup. This makes the server available faster but defers the fetch cost to the first proof request for each circuit.

```bash
# CLI
midnight-proof-server --no-fetch-params

# Environment variable
MIDNIGHT_PROOF_SERVER_NO_FETCH_PARAMS=true midnight-proof-server

# Docker — fast startup for development
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server --no-fetch-params -v
```

## Environment Profiles

### Development

Default settings work well for development. The server starts with 2 workers and pre-fetches parameters.

```bash
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server -v
```

For faster startup during iterative development, skip parameter pre-fetching:

```bash
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server --no-fetch-params -v
```

### Production

Scale workers based on available CPU cores and set capacity limits to prevent resource exhaustion:

```bash
docker run -d --name midnight-proof-server -p 6300:6300 \
  --memory=8g \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server \
  --num-workers 8 \
  --job-capacity 50 \
  --job-timeout 300
```

### CI / Testing

Minimal configuration for automated testing where fast startup matters more than throughput:

```bash
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server \
  --no-fetch-params \
  --num-workers 1 \
  --job-capacity 5
```

## Tuning Guidance

### Worker Count

| Scenario | Recommended `--num-workers` |
|----------|----------------------------|
| Development (local machine) | 2 (default) |
| CI / testing | 1 |
| Production (4-core) | 3-4 |
| Production (8-core) | 6-8 |
| Production (16+ core) | 12-14 (leave cores for OS/HTTP) |

Proving is CPU-bound. Each worker occupies one core during proof generation. Leave 1-2 cores free for the HTTP server, garbage collection, and OS tasks.

### Job Capacity

| Scenario | Recommended `--job-capacity` |
|----------|------------------------------|
| Development | 0 (unlimited, default) |
| Production (small) | 10-20 |
| Production (large) | 50-100 |

Unlimited capacity is fine for development where request volume is low. In production, set capacity to prevent OOM when bursts of requests arrive faster than workers can process them.

### Memory Requirements

| Configuration | Minimum RAM |
|---------------|-------------|
| Development (2 workers) | 4 GB |
| Production (4 workers) | 8 GB |
| Production (8 workers) | 16 GB |

Each worker holds proving keys and intermediate state in memory during proof generation. Complex circuits (high k-values) require more memory per worker. When running in Docker, set the container memory limit using `--memory` to match.

### Startup Time

| Mode | Typical Startup Time |
|------|---------------------|
| With pre-fetch (default) | 2-5 minutes (network and cache dependent) |
| With `--no-fetch-params` | Under 5 seconds |

Pre-fetching downloads public parameters and proving keys from the network. Subsequent starts are faster if the cache is warm. The `--no-fetch-params` flag defers this cost to the first proof request, making the server available immediately but causing a delay on the first proof for each circuit.

### Job Timeout

| Circuit Complexity | Recommended `--job-timeout` |
|-------------------|----------------------------|
| Simple (k <= 12) | 120-300 seconds |
| Medium (k = 13-15) | 300-600 seconds |
| Complex (k > 15) | 600-1200 seconds |

The default 600-second timeout accommodates most circuits. Increase it only if you observe timeout-related job cancellations in the logs for legitimate proving requests.
