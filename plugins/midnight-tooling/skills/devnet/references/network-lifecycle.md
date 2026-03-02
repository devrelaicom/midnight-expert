# Network Lifecycle

This reference covers starting, stopping, restarting, and monitoring the Midnight local development network (devnet). All operations are performed through MCP tools.

## Starting the Network

The `start-network` tool performs the full startup sequence:

1. **Pulls Docker images** for the node, indexer, and proof server (if not already cached)
2. **Starts 3 containers** via Docker Compose: `midnight-node`, `midnight-indexer`, `midnight-proof-server`
3. **Initializes the genesis master wallet** on the freshly started chain
4. **Registers the DUST token** so that accounts can be funded

After startup completes, all three services are running and the network is ready for development.

### What "Ready" Means

The network is fully ready when:
- The node is accepting RPC connections on port 9944
- The indexer is responding to GraphQL queries on port 8088
- The proof server health endpoint returns OK on port 6300
- The genesis wallet is initialized and DUST token is registered

Use `/devnet health` to verify all of these conditions.

## Stopping the Network

The `stop-network` tool:

1. **Closes any open wallets** managed by the devnet
2. **Stops all 3 containers** via Docker Compose

By default, Docker volumes are preserved. This means chain state, indexer data, and other persistent data survive a stop/start cycle.

### Removing Volumes (Clean Slate)

Pass `removeVolumes: true` (or `--remove-volumes`) to also delete Docker volumes when stopping. This removes all chain state and gives you a completely fresh network on the next start.

Use `--remove-volumes` when:
- Chain state is corrupted or causing unexpected errors
- You want to reset all account balances and contract deployments
- You are switching between incompatible devnet image versions
- You want a guaranteed clean starting point

Do **not** use `--remove-volumes` when:
- You have deployed contracts you want to keep testing against
- You have funded accounts with specific balances you need to preserve

## Restarting the Network

The `restart-network` tool stops and then starts the network in a single operation. It accepts the same options as stop and start, including `removeVolumes` for a clean restart.

A restart with `removeVolumes: true` is the most reliable way to return to a known-good state.

## Status vs Health

Two different tools check the network, each serving a different purpose:

| Tool | What It Checks | Speed | Use When |
|------|---------------|-------|----------|
| `network-status` | Docker container state (running, stopped, exited) | Fast | Quick check: "are the containers up?" |
| `health-check` | HTTP endpoints on each service (node RPC, indexer GraphQL, proof server health) | Slower | Thorough check: "are the services actually responding?" |

**Use `network-status`** for a quick look at whether containers are running. This only queries Docker and does not touch the services themselves.

**Use `health-check`** when you need to confirm the services are actually responsive and accepting requests. This makes HTTP calls to each service endpoint and reports their status.

A container can be "running" (per Docker) but not yet ready to accept requests -- for example, if the indexer is still syncing. The health check catches this; the status check does not.

## Getting Network Configuration

The `get-network-config` tool returns the current network configuration:

| Field | Value | Notes |
|-------|-------|-------|
| Node RPC | `http://127.0.0.1:9944` | Substrate JSON-RPC endpoint |
| Indexer GraphQL | `http://127.0.0.1:8088/api/v3/graphql` | Query and mutation endpoint |
| Indexer WebSocket | `ws://127.0.0.1:8088/api/v3/graphql/ws` | Subscription endpoint |
| Proof Server | `http://127.0.0.1:6300` | ZK proof generation |
| Network ID | `undeployed` | Fixed value for local devnet |
| Docker image versions | Varies | Versions of each service image currently configured |

### Network Endpoints

Use these endpoints when configuring DApps or tools to connect to the local devnet:

| Endpoint | URL | Protocol |
|----------|-----|----------|
| Node RPC | `http://127.0.0.1:9944` | HTTP (JSON-RPC) |
| Indexer GraphQL | `http://127.0.0.1:8088/api/v3/graphql` | HTTP (GraphQL) |
| Indexer WebSocket | `ws://127.0.0.1:8088/api/v3/graphql/ws` | WebSocket (GraphQL subscriptions) |
| Proof Server | `http://127.0.0.1:6300` | HTTP |

The network ID for the local devnet is `undeployed`. This value is used in DApp provider configurations and wallet connections to identify the local development network.

## Viewing Logs

The `network-logs` tool retrieves recent log output from the devnet containers. Use this to diagnose startup failures, connection issues, or unexpected service behavior.

## Typical Workflows

### First-time setup

1. Ensure Docker Desktop is installed and running (see `docker-setup.md`)
2. Run `/devnet start` -- this pulls images, starts services, and initializes the chain
3. Run `/devnet health` to confirm everything is ready

### Daily development

1. Run `/devnet start` to bring up the network
2. Develop and test against the local endpoints
3. Run `/devnet stop` when done (state is preserved for next time)

### Starting fresh

1. Run `/devnet restart` with `--remove-volumes` to wipe all state and restart clean
2. Run `/devnet health` to confirm the fresh network is ready
