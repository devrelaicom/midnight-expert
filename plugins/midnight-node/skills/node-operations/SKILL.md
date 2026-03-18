---
name: node-operations
description: This skill should be used when the user asks about running the Midnight node, validator mode, full node, archive node, dev mode, Docker deployment, midnight-node-docker, Prometheus metrics, node monitoring, memory monitoring, graceful shutdown, P2P networking, bootnodes, node keys, port 30333, node troubleshooting, blocks not finalizing, mainchain follower errors, IPC errors, state sync issues, node logs, node peers, or node health checks.
version: 0.1.0
---

# Node Operations

Operational guide for running, monitoring, and troubleshooting the Midnight node. For configuration options, see `midnight-node:node-configuration`. For architecture internals, see `midnight-node:node-architecture`.

## Running Modes

### Validator Node

Produces blocks and participates in consensus. Requires all four validator keys.

```bash
midnight-node --chain preview \
  --validator \
  --name "my-validator"
```

Validator nodes must have:
- AURA, GRANDPA, CROSS_CHAIN, and BEEFY keys configured (see `node-configuration`)
- Sufficient peers for consensus participation
- Stable network connectivity and uptime

### Full Node

Syncs and validates the chain without producing blocks. Serves RPC requests and provides network capacity.

```bash
midnight-node --chain preview \
  --name "my-full-node" \
  --rpc-external --rpc-cors all
```

### Archive Node

Retains all historical state. Required for block explorers, indexers, and historical queries.

```bash
midnight-node --chain preview \
  --state-pruning archive \
  --blocks-pruning archive \
  --name "my-archive-node"
```

### Development Mode

Single-node ephemeral chain for local development and testing.

```bash
midnight-node --dev --tmp
```

Development mode automatically:
- Creates a single-validator chain
- Uses pre-funded development accounts
- Enables all RPC methods
- Uses ephemeral storage (deleted on shutdown with `--tmp`)

## Docker Deployment

The Midnight node is distributed as a Docker image via `midnight-node-docker`.

```bash
# Pull the node image
docker pull midnightntwrk/midnight-node:0.22.0

# Run a full node
docker run -d --name midnight-node \
  -p 9944:9944 \
  -p 30333:30333 \
  -p 9615:9615 \
  -v midnight-data:/data \
  midnightntwrk/midnight-node:0.22.0 \
  midnight-node --chain preview \
    --rpc-external --rpc-cors all \
    --prometheus-external
```

### Port Mapping

| Port | Protocol | Purpose |
|------|----------|---------|
| 9944 | WebSocket | JSON-RPC API |
| 30333 | TCP | P2P networking |
| 9615 | HTTP | Prometheus metrics |

### Volume Mounts

| Path | Purpose |
|------|---------|
| `/data` | Chain database and ledger storage |
| `/keys` | Validator key files (validator mode only) |

## Monitoring

### Prometheus Metrics

The node exposes Prometheus metrics on port 9615 by default.

```bash
# Enable external Prometheus endpoint
midnight-node --chain preview --prometheus-external

# Scrape metrics
curl http://localhost:9615/metrics
```

Key metrics to monitor:

| Metric | Description |
|--------|-------------|
| `substrate_block_height` | Current best and finalized block heights |
| `substrate_number_leaves` | Number of leaves in the state trie |
| `substrate_peers_count` | Number of connected peers |
| `substrate_ready_transactions_number` | Transactions in the ready queue |
| `substrate_sync_peers` | Number of sync peers |
| `substrate_block_verification_time` | Block import verification time |

### Push Endpoint

The node supports pushing metrics to a remote Prometheus Pushgateway via the `PROMETHEUS_PUSH_ENDPOINT` environment variable.

```bash
PROMETHEUS_PUSH_ENDPOINT=http://pushgateway:9091 midnight-node --chain preview
```

### Memory Monitoring

The node includes a configurable memory monitoring system. When memory usage exceeds the configured threshold, the node initiates a graceful shutdown to prevent out-of-memory crashes.

| Parameter | Description |
|-----------|-------------|
| `memory_threshold` | Percentage of system memory that triggers shutdown (e.g., `90`) |

The node logs memory usage periodically and emits a warning before initiating shutdown, allowing the process manager (systemd, Docker, Kubernetes) to restart it cleanly.

## P2P Networking

### Bootnodes

Bootnodes are the initial peers the node contacts to discover the network. Each network preset includes default bootnodes.

```bash
# Add custom bootnodes
midnight-node --chain preview \
  --bootnodes /dns4/bootnode.example.com/tcp/30333/p2p/12D3KooW...
```

### Node Keys

Each node has a unique libp2p identity derived from a node key. The key is auto-generated on first run and stored in the database directory.

```bash
# Generate a node key manually
midnight-node key generate-node-key --file /keys/node.key

# Use a specific node key
midnight-node --chain preview --node-key-file /keys/node.key
```

### P2P Port

The default P2P port is 30333. Ensure this port is open for inbound connections if the node should be reachable by peers.

```bash
midnight-node --chain preview --port 30333 --listen-addr /ip4/0.0.0.0/tcp/30333
```

## Troubleshooting

### Blocks Not Finalizing

| Symptom | Possible Cause | Resolution |
|---------|---------------|------------|
| Best block increases but finalized block is stuck | GRANDPA consensus stalled | Check peer count (`system_health` RPC); ensure validator keys are correct |
| Finalized block lags far behind best block | Network partition or insufficient validators | Verify bootnodes are reachable; check GRANDPA round state via `grandpa_roundState` |
| No blocks produced at all | AURA authority not in active set | Verify AURA key is registered; check epoch configuration |

### Mainchain Follower Errors

| Symptom | Possible Cause | Resolution |
|---------|---------------|------------|
| `MainchainFollower connection failed` | PostgreSQL db-sync unreachable | Verify db-sync is running and PostgreSQL connection string is correct |
| `MainchainFollower sync behind` | db-sync is still syncing Cardano chain | Wait for db-sync to reach tip; check db-sync logs |
| Partner chain data stale | db-sync stopped or restarting | Restart db-sync; verify Cardano node connectivity |

### IPC Errors

| Symptom | Possible Cause | Resolution |
|---------|---------------|------------|
| IPC socket connection refused | Node process crashed or socket file stale | Restart the node; remove stale socket files from data directory |
| IPC timeout | Node under heavy load | Increase system resources; check CPU and memory usage |

### State Sync Issues

| Symptom | Possible Cause | Resolution |
|---------|---------------|------------|
| Sync stalls at a specific block | Corrupted state or database | Clear chain data and resync: remove database directory, restart node |
| `State database error` | Disk full or I/O error | Check disk space; verify storage health |
| Very slow sync | Insufficient peers or slow network | Add more bootnodes; verify network connectivity; increase `--db-cache` |

### Diagnostic Commands

```bash
# Check node health
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_health","params":[]}' \
  http://localhost:9944

# Check sync state
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_syncState","params":[]}' \
  http://localhost:9944

# Check connected peers
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"system_peers","params":[]}' \
  http://localhost:9944

# Check GRANDPA round state
curl -s -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"grandpa_roundState","params":[]}' \
  http://localhost:9944
```

## Cross-References

- `midnight-node:node-configuration` — Detailed configuration flags and environment variables
- `midnight-node:node-rpc-api` — RPC methods used for monitoring and diagnostics
- `midnight-tooling:devnet` — Local development stack that manages node lifecycle automatically
