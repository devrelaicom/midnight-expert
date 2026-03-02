---
name: devnet
description: This skill should be used when the user asks about the Midnight local development network, including "start the devnet", "stop the devnet", "restart the network", "local development network", "midnight node", "midnight indexer", "network status", "network health", "devnet config", "network endpoints", "port 9944", "port 8088", "port 6300", "Docker Compose", "devnet not starting", "local blockchain", "devnet logs", "network ID", "DUST token", "genesis wallet", "fund account", "get tDUST", "wallet balance", or "clean slate restart"
---

# Midnight Development Network (Devnet)

The devnet is a local 3-service blockchain network for Midnight development. It runs via Docker Compose and is managed entirely through MCP tools -- not direct Docker commands.

## **Terminology -- Read This First**

> **Four distinct components make up the local development environment. Always be precise about which is being referenced.**

| Term | What It Is | Port | Container |
|------|-----------|------|-----------|
| **Devnet** | The complete local 3-service network managed as a unit | N/A (all three below) | Managed via Docker Compose |
| **Node** | The Midnight blockchain node (Substrate-based) | 9944 | `midnight-node` |
| **Indexer** | GraphQL API for querying chain state and subscribing to events | 8088 | `midnight-indexer` |
| **Proof server** | Generates zero-knowledge proofs for transactions | 6300 | `midnight-proof-server` |

The devnet is **not** a single service. It is the coordinated set of all three services. Starting the devnet starts all three; stopping it stops all three.

## Prerequisites

Docker Desktop must be installed and running before the devnet can start. The three services together require adequate system resources.

| Check | Command | Expected |
|-------|---------|----------|
| Docker installed | `docker --version` | Version string |
| Docker daemon running | `docker info` | System info (no connection errors) |
| Adequate resources | Docker Desktop settings | 4 GB+ RAM allocated to Docker |

If Docker is not installed, see `references/docker-setup.md` for platform-specific installation instructions.

## Quick Command Reference

All devnet operations are performed through MCP tools, not direct Docker or Docker Compose commands.

| Command | Purpose |
|---------|---------|
| `/devnet start` | Pull images, start all 3 services, initialize genesis wallet, register DUST token |
| `/devnet stop` | Close wallets and stop all containers |
| `/devnet restart` | Stop and restart the network (with options for clean slate) |
| `/devnet status` | Check Docker container state for all services (fast) |
| `/devnet health` | Hit HTTP endpoints on each service to verify responsiveness (thorough) |
| `/devnet logs` | View recent logs from the network services |
| `/devnet config` | Show endpoint URLs, network ID, and Docker image versions |

## Services

| Service | Port | Endpoint | Purpose |
|---------|------|----------|---------|
| **Node** | 9944 | `http://127.0.0.1:9944` | Blockchain RPC (Substrate JSON-RPC) |
| **Indexer** | 8088 | `http://127.0.0.1:8088/api/v3/graphql` | GraphQL queries and subscriptions |
| **Proof server** | 6300 | `http://127.0.0.1:6300` | Zero-knowledge proof generation |

The indexer also exposes a WebSocket endpoint at `ws://127.0.0.1:8088/api/v3/graphql/ws` for real-time subscriptions.

The network ID for local devnet is `undeployed`.

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Cannot connect to the Docker daemon` | Docker Desktop not running | Start Docker Desktop and wait for it to be ready |
| Port 9944, 8088, or 6300 already in use | Another process occupying a required port | Stop the conflicting process; use `lsof -i :<port>` to identify it |
| Services fail to start or exit immediately | Insufficient Docker resources | Allocate at least 4 GB RAM to Docker Desktop (see `references/docker-setup.md`) |
| Network starts but indexer not responding | Indexer still syncing with node | Wait 10-20 seconds after start; use `/devnet health` to check readiness |
| Stale chain state causing errors | Corrupted or outdated volumes | Restart with `--remove-volumes` for a clean slate |
| Container name conflicts | Previous containers not cleaned up | Stop the devnet first, then start again; the MCP tools handle container cleanup |

## Reference Files

Consult these for detailed procedures:

| Reference | Content | When to Read |
|-----------|---------|-------------|
| **`references/network-lifecycle.md`** | Starting, stopping, restarting the network; status vs health checks; getting config; clean slate vs preserve state | Managing the devnet lifecycle |
| **`references/docker-setup.md`** | Docker installation per platform, daemon troubleshooting, resource configuration, port conflicts | Docker installation issues or first-time setup |
