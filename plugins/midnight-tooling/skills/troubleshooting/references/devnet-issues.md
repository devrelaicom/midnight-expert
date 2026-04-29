# Devnet Issues

Diagnose and resolve common issues with the Midnight local devnet, including network startup and indexer sync. For wallet initialization and funding issues, use the `midnight-wallet` plugin.

## Network Fails to Start

**Symptoms:** `/midnight-tooling:devnet start` fails, containers do not appear in `docker ps`, or the command hangs.

**Common causes and fixes:**

1. **Docker not running:** The devnet requires Docker. Ensure Docker Desktop (macOS/Windows) or the Docker daemon (Linux) is running.
   ```bash
   docker info
   ```
   If this fails, start Docker before retrying `/midnight-tooling:devnet start`.

2. **Port conflicts:** The devnet uses several ports by default:
   - **9944** — Midnight node (WebSocket RPC)
   - **8088** — Indexer (GraphQL API)
   - **6300** — Proof server

   Check for conflicts:
   ```bash
   lsof -i :9944
   lsof -i :8088
   lsof -i :6300
   ```
   Stop any conflicting processes or containers before starting the devnet.

3. **Insufficient resources:** The devnet runs three containers simultaneously. Ensure Docker has at least 4 GB RAM allocated, preferably 8 GB. On Docker Desktop, check Settings > Resources > Memory.

## Partial Startup

**Symptoms:** Some services start successfully but others fail. For example, the node is running but the indexer or proof server is not.

**Diagnosis:**

1. Check overall status with `/midnight-tooling:devnet status` to see which services are running. From inside a script, run the `midnight-tooling:devnet-health` skill's `status.sh` directly.
2. Check health of each service with `/midnight-tooling:devnet health`, or run `health.sh` from the `midnight-tooling:devnet-health` skill.
3. Inspect logs for the failing service:
   ```
   /midnight-tooling:devnet logs --service node
   /midnight-tooling:devnet logs --service indexer
   /midnight-tooling:devnet logs --service proof-server
   ```
4. A service may fail to start if its dependencies are not yet ready. The indexer depends on the node being available. If the node starts slowly, the indexer may fail on its initial connection attempt. Restarting the network with `/midnight-tooling:devnet stop` then `/midnight-tooling:devnet start` often resolves transient startup ordering issues.

## Wallet Initialization and Funding

Wallet initialization, account funding, balance checking, transfers, and dust registration are handled by the `midnight-wallet` plugin. If you are experiencing issues with any of these operations, install and use `midnight-wallet`.

## Indexer Sync Issues

**Symptoms:** The indexer is running but returns stale or empty data. GraphQL queries to the indexer return no results or outdated blocks.

**Cause:** The indexer depends on the node. If the node is unhealthy or behind, the indexer cannot sync.

**Fix:**

1. Check node health first — the indexer cannot sync if the node is not producing or processing blocks.
2. Check indexer logs for connection errors or sync failures:
   ```
   /midnight-tooling:devnet logs --service indexer
   ```
3. If the node is healthy but the indexer is stale, restart the indexer. If the issue persists, perform a clean slate recovery (see below).

## Clean Slate Recovery

**When to use:** When the devnet state is corrupted, services fail repeatedly after restarts, or you want to start completely fresh.

**Steps:**

1. Stop the network and remove all volumes:
   ```
   /midnight-tooling:devnet stop --remove-volumes
   ```
2. Start a fresh network:
   ```
   /midnight-tooling:devnet start
   ```

This removes all chain data, indexer state, and proof server caches. After a clean start, any wallet operations (initialization, funding) must be re-run via the `midnight-wallet` plugin.

## If Issues Persist

1. Search for devnet issues: `gh search issues "devnet org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Search for Docker-related issues: `gh search issues "docker org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
3. Check release notes for the component versions in use via `references/checking-release-notes.md`
