---
name: midnight-tooling:devnet
description: This skill should be used when the user asks about the Midnight local development network, including "start the devnet", "stop the devnet", "restart the network", "local development network", "midnight node", "midnight indexer", "network status", "network health", "devnet config", "network endpoints", "port 9944", "port 8088", "port 6300", "Docker Compose", "devnet not starting", "local blockchain", "devnet logs", "network ID", "generate devnet", "devnet versions", "update devnet", "devnet stale"
---

# Midnight Development Network (Devnet)

The devnet is a local 3-service blockchain network for Midnight development. It runs via Docker Compose and is managed through the `/midnight-tooling:devnet` command, which uses bash and Docker Compose commands directly.

## Terminology -- Read This First

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
| Docker Compose available | `docker compose version` | Version string |
| Adequate resources | Docker Desktop settings | 4 GB+ RAM allocated to Docker |

If Docker is not installed, see `references/docker-setup.md` for platform-specific installation instructions.

## Quick Command Reference

| Command | Purpose |
|---------|---------|
| `/midnight-tooling:devnet generate` | Create a `devnet.yml` from template with latest stable versions |
| `/midnight-tooling:devnet update` | Update image versions in an existing `devnet.yml` |
| `/midnight-tooling:devnet start` | Start all 3 services (generates compose file on first run) |
| `/midnight-tooling:devnet stop` | Stop all containers |
| `/midnight-tooling:devnet restart` | Stop and restart the network |
| `/midnight-tooling:devnet status` | Check Docker container state for all services (fast) |
| `/midnight-tooling:devnet health` | Hit HTTP endpoints on each service to verify responsiveness (thorough, with timing) |
| `/midnight-tooling:devnet logs` | View recent logs from the network services |
| `/midnight-tooling:devnet config` | Show endpoint URLs, network ID, image versions, and file info |

## Services

| Service | Port | Endpoint | Purpose |
|---------|------|----------|---------|
| **Node** | 9944 | `http://127.0.0.1:9944` | Blockchain RPC (Substrate JSON-RPC) |
| **Indexer** | 8088 | `http://127.0.0.1:8088/api/v3/graphql` | GraphQL queries and subscriptions |
| **Proof server** | 6300 | `http://127.0.0.1:6300` | Zero-knowledge proof generation |

The indexer also exposes a WebSocket endpoint at `ws://127.0.0.1:8088/api/v3/graphql/ws` for real-time subscriptions.

The network ID for local devnet is `undeployed`.

## Scripts

The skill includes four helper scripts in `${CLAUDE_SKILL_DIR}/scripts/`:

| Script | Purpose | Usage |
|--------|---------|-------|
| `resolve-versions.sh` | Query Docker Hub for latest stable image versions | Returns `key=value` pairs |
| `generate-devnet.sh` | Create `devnet.yml` from template with version substitution | `--template <path> --node-version X --indexer-version X --proof-server-version X [--directory <path>]` |
| `check-staleness.sh` | Check age of a `devnet.yml` file | Returns `age_days=N` and `stale=true/false` |
| `find-devnet.sh` | Locate a `devnet.yml` in standard locations | `[--file <path>]` |

The compose file template is at `${CLAUDE_SKILL_DIR}/templates/devnet.yml`.

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `docker: command not found` | Docker not installed | Install Docker Desktop — see `references/docker-setup.md` |
| `Cannot connect to the Docker daemon` | Docker Desktop not running | Start Docker Desktop and wait for it to be ready |
| `docker compose: command not found` | Older Docker without Compose V2 | Update Docker Desktop or install docker-compose-plugin |
| Services fail to start or exit immediately | Insufficient Docker resources | Allocate at least 4 GB RAM to Docker Desktop (see `references/docker-setup.md`) |
| Port 9944, 8088, or 6300 already in use | Another process occupying a required port | Stop the conflicting process; use `lsof -i :<port>` to identify it |
| Network starts but indexer not responding | Indexer still syncing with node | Wait 10-20 seconds after start; use `/midnight-tooling:devnet health` to check readiness |
| Stale chain state causing errors | Corrupted or outdated volumes | Restart with `--remove-volumes` for a clean slate |
| Container name conflicts | Previous containers not cleaned up | Stop the devnet first (`/midnight-tooling:devnet stop`), then start again |
| `Failed to fetch tags` from Docker Hub | Docker Hub unreachable or rate-limited | Check internet connection; use `--node-version` etc. to specify versions manually |
| Architecture mismatch on Apple Silicon | Image not available for arm64 | See Apple Silicon note in `references/docker-setup.md` |
| Compose file stale warning | File older than 5 days | Run `/midnight-tooling:devnet update` to refresh image versions |

## Wallet Operations

For wallet management, funding, balance checking, transfers, and dust registration, use the `midnight-wallet` plugin. The wallet plugin's MCP tools work with any running devnet — it auto-detects the services by Docker image name.

## Reference Files

Consult these for detailed procedures:

| Reference | Content | When to Read |
|-----------|---------|-------------|
| **`references/network-lifecycle.md`** | Generate, update, start, stop, restart flows; staleness checking; compose file locations; project naming; typical workflows | Managing the devnet lifecycle |
| **`references/docker-setup.md`** | Docker installation per platform, daemon troubleshooting, resource configuration, port conflicts | Docker installation issues or first-time setup |
| **`references/compose-structure.md`** | Anatomy of `devnet.yml`: every service, env var, healthcheck, dependency, and port explained; guidance on bespoke modifications | Debugging compose file issues or making custom changes |
| **`references/version-resolution.md`** | Docker Hub API, stable version filtering, compatibility matrix checking, graceful degradation | Version resolution problems or understanding the update process |
