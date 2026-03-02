# Devnet Issues

Diagnose and resolve common issues with the Midnight local devnet, including network startup, wallet initialization, funding, indexer sync, and MCP server connectivity.

## Network Fails to Start

**Symptoms:** `/devnet start` fails, containers do not appear in `docker ps`, or the command hangs.

**Common causes and fixes:**

1. **Docker not running:** The devnet requires Docker. Ensure Docker Desktop (macOS/Windows) or the Docker daemon (Linux) is running.
   ```bash
   docker info
   ```
   If this fails, start Docker before retrying `/devnet start`.

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

1. Check overall status with `/devnet status` to see which services are running.
2. Check health of each service with `/devnet health`.
3. Inspect logs for the failing service:
   ```
   /devnet logs --service node
   /devnet logs --service indexer
   /devnet logs --service proof-server
   ```
4. A service may fail to start if its dependencies are not yet ready. The indexer depends on the node being available. If the node starts slowly, the indexer may fail on its initial connection attempt. Restarting the network with `/devnet stop` then `/devnet start` often resolves transient startup ordering issues.

## Wallet Initialization Fails

**Symptoms:** `/devnet wallet-init` fails or returns errors about connectivity or unhealthy services.

**Cause:** Wallet initialization requires the network to be fully healthy. The node and indexer must both be running and synced before the wallet can be created.

**Fix:**

1. Check network health: `/devnet health`
2. Ensure all services report healthy status before attempting wallet initialization.
3. If services are starting up, wait for them to become healthy and retry.
4. If services are unhealthy, diagnose using per-service logs (see Partial Startup above).

## Funding Failures

**Symptoms:** `/devnet fund` fails or returns errors.

**Common causes and fixes:**

1. **Devnet not running:** Funding requires a running devnet. Verify with `/devnet status`.
2. **Master wallet not initialized:** The master wallet must be initialized before funding. Run `/devnet wallet-init` first if it has not been done since the network started.
3. **Insufficient balance:** The master wallet has a finite balance. If many accounts have been funded, the master wallet may be depleted. Use `/devnet balances` to check the master wallet balance.
4. **Invalid address:** Funding requires a valid Bech32-encoded Midnight address. Double-check the address format. A valid address starts with the appropriate prefix for the network.

## Indexer Sync Issues

**Symptoms:** The indexer is running but returns stale or empty data. GraphQL queries to the indexer return no results or outdated blocks.

**Cause:** The indexer depends on the node. If the node is unhealthy or behind, the indexer cannot sync.

**Fix:**

1. Check node health first — the indexer cannot sync if the node is not producing or processing blocks.
2. Check indexer logs for connection errors or sync failures:
   ```
   /devnet logs --service indexer
   ```
3. If the node is healthy but the indexer is stale, restart the indexer. If the issue persists, perform a clean slate recovery (see below).

## Clean Slate Recovery

**When to use:** When the devnet state is corrupted, services fail repeatedly after restarts, or you want to start completely fresh.

**Steps:**

1. Stop the network and remove all volumes:
   ```
   /devnet stop --remove-volumes
   ```
2. Start a fresh network:
   ```
   /devnet start
   ```

This removes all chain data, indexer state, and proof server caches. You will need to re-initialize the wallet and re-fund any accounts after a clean start.

## MCP Server Connectivity

**Symptoms:** `/devnet` commands fail before reaching Docker, MCP tool calls return errors, or the midnight-devnet MCP server does not start.

**Common causes and fixes:**

1. **Node.js not available:** The MCP server requires Node.js and `npx`. Verify they are installed and on the PATH:
   ```bash
   node --version
   npx --version
   ```

2. **Package resolution failure:** The MCP server runs via `npx @aaronbassett/midnight-local-devnet`. If the npm registry is unreachable or the package name has changed, npx will fail. Check:
   - Network access to the npm registry: `npm ping`
   - That the package exists: `npm view @aaronbassett/midnight-local-devnet`

3. **Docker not running:** Even though the MCP server itself is a Node.js process, it manages Docker containers. If Docker is not running, the MCP server will start but tool calls that interact with containers will fail. Ensure Docker is running before using devnet commands.

4. **MCP configuration issues:** Verify that the midnight-devnet MCP server is correctly configured in your Claude Code settings. The server should be listed in the MCP servers configuration and should show as connected.

## If Issues Persist

1. Search for devnet issues: `gh search issues "devnet org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Search for Docker-related issues: `gh search issues "docker org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
3. Check release notes for the component versions in use via `references/checking-release-notes.md`
