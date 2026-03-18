---
name: proof-server-operations
description: This skill should be used when the user asks about proof server monitoring, proof server health check patterns, proof server readiness checks, proof server busy status, proof server troubleshooting, proof server logs, proof server capacity planning, proof server performance, proof server job queue monitoring, proof server Docker health check, proof server Kubernetes health check, proof server 503 errors, proof server 429 errors, proof server timeout issues, proof server memory issues, or proof server debugging.
version: 0.1.0
---

# Proof Server Operations

Operational guide for monitoring, health checking, troubleshooting, and capacity planning the Midnight proof server. For basic Docker setup, see `midnight-tooling:proof-server`. For configuration flags, see `proof-server-configuration`. For architecture internals, see `proof-server-architecture`.

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
| `/ready` | 503 | Job queue is full, server is busy |
| `/prove` | 429 | Request rejected, capacity limit reached |

### Monitoring Script

```bash
#!/bin/bash
# Check proof server operational status
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
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server -v
```

### Docker Compose Health Check

```yaml
services:
  proof-server:
    image: midnightntwrk/proof-server:8.0.2
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

The `start_period` of 300 seconds (5 minutes) accounts for the parameter pre-fetch phase during which `/health` returns 200 but `/ready` may not yet be fully operational.

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

## Log Analysis

### Enabling Verbose Logs

Start the proof server with `-v` (or `--verbose`) to enable DEBUG-level logging:

```bash
docker run -d --name midnight-proof-server -p 6300:6300 \
  midnightntwrk/proof-server:8.0.2 -- midnight-proof-server -v
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

| Log Pattern | Meaning |
|-------------|---------|
| `Listening on 0.0.0.0:6300` | Server started and accepting connections |
| `Fetching public params for k=...` | Pre-fetching ZK parameters (startup) |
| `Job submitted` | New proving request accepted |
| `Job completed` | Proof generated successfully |
| `Job failed` | Proving error (check subsequent lines for details) |
| `Job cancelled (timeout)` | Job exceeded TTL and was garbage collected |
| `Capacity limit reached` | Queue full, returning 429 |

## Troubleshooting

### Common Issues

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| `/ready` returns 503 continuously | All workers busy and queue full | Increase `--num-workers` or `--job-capacity` |
| `/prove` returns 429 | Job capacity limit reached | Increase `--job-capacity` or add more workers |
| `/prove` returns 400 | Malformed request or unsupported proof version | Check that client SDK version matches proof server version |
| `/prove` returns 500 | Internal proving error | Enable verbose mode (`-v`), check logs for stack trace |
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
- `/check` returning unexpected constraint violations
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

## Cross-References

| Skill | Relevance |
|-------|-----------|
| `midnight-tooling:proof-server` | Basic Docker commands, image version selection, starting and stopping |
| `compact-core:compact-circuit-costs` | Understanding proof complexity and circuit k-values |
