---
name: proof-server:proof-server-operations
description: This skill covers monitoring, troubleshooting, and capacity planning for the proof server. Use it when the user asks about health check patterns, readiness checks, busy status, logs, performance, job queue monitoring, Docker or Kubernetes health checks, 503 errors, 429 errors, 400 errors, timeout issues, memory issues, debugging, version mismatch, version compatibility, scaling, horizontal scaling, or how to diagnose proof server issues.
version: 0.1.0
---

# Proof Server Operations

Operational guide for monitoring, health checking, troubleshooting, and capacity planning the Midnight proof server. For basic Docker setup, see `midnight-tooling:proof-server`. For configuration flags, see `proof-server:proof-server-configuration`. For architecture internals, see `proof-server:proof-server-architecture`.

> Replace `<version>` in image tags below with the version matching your target Midnight network. Check `midnight-tooling:release-notes` for current versions.

## Monitoring

### Key Endpoint: `/ready`

The `/ready` endpoint is the primary operational monitoring surface. It reports worker pool utilization in real time.

```bash
curl -s http://localhost:6300/ready | jq .
```

```json
{
  "status": "ok",
  "jobsProcessing": 1,
  "jobsPending": 3,
  "jobCapacity": 20,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

| Field | Meaning | Action Threshold |
|-------|---------|-----------------|
| `status` | `"ok"` = accepting work, `"busy"` = queue full | Alert on sustained `"busy"` |
| `jobsProcessing` | Active proving tasks (one per worker) | Should be <= `--num-workers` |
| `jobsPending` | Queued tasks waiting for a worker | Rising trend = need more workers |
| `jobCapacity` | Max queue depth (0 = unlimited) | Should match `--job-capacity` |

### HTTP Status Codes for Monitoring

| Endpoint | Code | Meaning |
|----------|------|---------|
| `/health` | 200 | Server process is alive |
| `/ready` | 200 | Server is accepting proving requests |
| `/ready` | 503 | Job queue is full, server is busy (only when `--job-capacity > 0`; default 0 = unlimited, so 503 is never returned from `/ready` by default) |
| `/prove` | 429 | Request rejected, capacity limit reached |

### Pre-warming Parameters

Use `/fetch-params/{k}` to pre-warm the parameter cache for specific circuit sizes (only available when the server was started without `--no-fetch-params`):

```bash
# Pre-warm parameters for k-value 13
curl -sf http://localhost:6300/fetch-params/13
```

### Monitoring Script

```bash
#!/bin/bash
# Check proof server operational status
# Requires: curl, jq
READY=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:6300/ready)
if [ "$READY" = "200" ]; then
  STATS=$(curl -s http://localhost:6300/ready)
  PROCESSING=$(echo "$STATS" | jq -r '.jobsProcessing')
  PENDING=$(echo "$STATS" | jq -r '.jobsPending')
  CAPACITY=$(echo "$STATS" | jq -r '.jobCapacity')
  echo "OK: processing=$PROCESSING pending=$PENDING capacity=$CAPACITY"
elif [ "$READY" = "503" ]; then
  echo "BUSY: proof server at capacity"
else
  echo "DOWN: proof server not responding (HTTP $READY)"
fi
```

## Health Check Patterns

### Docker Health Check

Add a health check to the Docker run command:

```bash
docker run -d --name midnight-proof-server \
  -p 6300:6300 \
  --health-cmd="curl -sf http://localhost:6300/health || exit 1" \
  --health-interval=30s \
  --health-timeout=10s \
  --health-retries=3 \
  midnightntwrk/proof-server:<version> -- midnight-proof-server -v
```

### Docker Compose Health Check

```yaml
services:
  proof-server:
    image: midnightntwrk/proof-server:<version>
    command: ["midnight-proof-server", "-v"]
    ports:
      - "6300:6300"
    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost:6300/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 300s
```

The `start_period` of 300 seconds (5 minutes) accounts for the parameter pre-fetch phase. The pre-fetch runs *before* the HTTP listener binds, so during this phase the health check cannot connect at all (`/health` itself is unreachable, not just slow to become ready). The generous `start_period` prevents these expected connection failures from marking the container unhealthy until the port is bound and `/health` starts answering.

### Kubernetes Probes

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 6300
  initialDelaySeconds: 10
  periodSeconds: 30
  timeoutSeconds: 5
readinessProbe:
  httpGet:
    path: /ready
    port: 6300
  initialDelaySeconds: 120
  periodSeconds: 10
  timeoutSeconds: 5
```

Use `/health` for liveness (is the process alive?) and `/ready` for readiness (can it handle proving requests?). The readiness probe returns 503 when the server is at capacity, which causes Kubernetes to stop routing traffic to the pod.

> **Note:** During startup, while the server is pre-fetching ZK parameters (the default behavior without `--no-fetch-params`), the HTTP listener is not yet bound — the parameter pre-fetch completes *before* the server starts listening. As a result, **both** `/health` and `/ready` are unreachable (connection refused) during pre-fetch, rather than returning 200/503. This is expected behavior, not an error. Once parameter pre-fetch completes the server binds its port and both endpoints become reachable; pre-fetch can take 2-5 minutes depending on network speed and cache state. `/ready` returns 503 only after the server is listening, when the job queue is full.

## Log Analysis

> For a structured reference of all log patterns, verbosity levels, and the full monitoring script, see `references/logging-and-monitoring.md`.

### Enabling Verbose Logs

Start the proof server with `-v` (or `--verbose`) to enable DEBUG-level logging:

```bash
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:<version> -- midnight-proof-server -v
```

### Viewing Logs

```bash
# Recent logs
docker logs --tail 50 midnight-proof-server

# Follow logs in real time
docker logs -f midnight-proof-server

# Logs with timestamps
docker logs --timestamps midnight-proof-server
```

### Key Log Patterns

| Log Pattern | Level | Meaning |
|-------------|-------|---------|
| `Ensuring zswap key material is available...` | INFO | Startup parameter pre-fetch beginning (logged before the HTTP port binds) |
| `Starting to process request for /k...` | INFO | A `/k` request has been received and is being processed (analogous lines exist for `/check`, `/prove`, and `/prove-tx`) |
| `Received request: ...` | DEBUG | Hex dump of the raw request body (only emitted in verbose mode) |

## Troubleshooting

### Common Issues

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| `/ready` returns 503 continuously | All workers busy and queue full | Increase `--num-workers` or `--job-capacity` |
| `/prove` returns 429 | Job capacity limit reached | Increase `--job-capacity` or add more workers |
| `/prove` returns 400 | Malformed or undeserializable binary request (the tagged payload failed to parse) | Check that the client SDK version matches the proof server version |
| `/prove` returns 500 | Internal proving error (including a genuinely unsupported, non-V2 proof version, which trips an internal `unreachable!()` rather than a clean 400) | Enable verbose mode (`-v`), check logs for stack trace |
| Proofs take very long | Complex circuit or insufficient CPU | Check k-value of circuit; increase `--num-workers` |
| Server exits on startup | Insufficient memory or port conflict | Check Docker memory allocation (min 4 GB); verify port 6300 is free |
| First proof is slow | Parameter fetch on first use (`--no-fetch-params`) | Pre-warm with `/fetch-params/{k}` or remove `--no-fetch-params` |
| Jobs being cancelled | TTL exceeded (`--job-timeout` too low) | Increase `--job-timeout` for complex circuits |
| High memory usage | Too many workers or complex circuits | Reduce `--num-workers` or increase Docker memory limit |

### Diagnostic Checklist

When the proof server is not behaving as expected, run through these checks in order:

```bash
# 1. Is the container running?
docker ps --filter "name=midnight-proof-server"

# 2. Is the process alive?
curl -sf http://localhost:6300/health

# 3. Is it accepting work?
curl -sf http://localhost:6300/ready

# 4. What version is running?
curl -sf http://localhost:6300/version

# 5. What proof versions are supported?
curl -sf http://localhost:6300/proof-versions

# 6. Check recent logs for errors
docker logs --tail 50 midnight-proof-server

# 7. Check container resource usage
docker stats midnight-proof-server --no-stream
```

### Version Mismatch Issues

The proof server, Compact compiler, and wallet SDK must use compatible versions. A version mismatch typically manifests as:

- `/prove` returning 400 (binary deserialization failure)
- `/check` returning unexpected results, or `/prove` returning 500 (internal circuit error)
- Proofs that generate successfully but fail on-chain verification

Check versions across all components:

```bash
# Proof server version
curl -sf http://localhost:6300/version

# Compact compiler version
compactc --version
```

## Capacity Planning

### Throughput Estimation

Proof generation is CPU-intensive. Each proof runs in a `spawn_blocking` thread, occupying one CPU core for its duration.

| Circuit Complexity (k-value) | Approx. Proving Time (per proof) |
|-----------------------------|----------------------------------|
| k = 10-11 | 5-15 seconds |
| k = 12-13 | 15-60 seconds |
| k = 14-15 | 1-5 minutes |
| k > 15 | 5+ minutes |

### Throughput by Worker Count

For a circuit with ~30 second proving time:

| Workers | Max Throughput | Recommended RAM |
|---------|---------------|-----------------|
| 1 | ~2 proofs/min | 4 GB |
| 2 | ~4 proofs/min | 4 GB |
| 4 | ~8 proofs/min | 8 GB |
| 8 | ~16 proofs/min | 16 GB |

### Scaling Strategy

```text
Single Instance (vertical scaling)
├── Increase --num-workers for more parallelism
├── Increase --job-capacity for burst absorption
└── Increase Docker memory allocation

Multiple Instances (horizontal scaling)
├── Run multiple proof server containers
├── Load balance with /ready-aware health checks
└── Use Kubernetes HPA on CPU utilization
```

## Performance Characteristics

- **CPU-intensive:** Proof generation dominates resource usage; each proof uses one core continuously
- **Memory per worker:** Each worker holds proving keys and intermediate computation state; memory usage scales with worker count and circuit complexity
- **I/O minimal:** After startup parameter fetch, the server has negligible disk and network I/O
- **Latency profile:** First proof may be slow (parameter fetch if `--no-fetch-params`); subsequent proofs have consistent latency determined by circuit complexity
- **Garbage collection:** Background GC runs every 10 seconds, removing timed-out jobs; negligible CPU overhead

## References

| Name | Description | When used |
|------|-------------|-----------|
| `references/logging-and-monitoring.md` | Structured reference for log patterns, verbosity levels, and monitoring script details | When diagnosing proof server behaviour via logs or setting up operational monitoring |

## Cross-References

| Skill | Relevance |
|-------|-----------|
| `midnight-tooling:proof-server` | Basic Docker commands, image version selection, starting and stopping |
| `compact-core:compact-circuit-costs` | Understanding proof complexity and circuit k-values |
