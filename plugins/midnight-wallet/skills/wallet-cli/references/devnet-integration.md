# Devnet Integration Reference

Covers how `midnight-wallet-cli` integrates with the local development network managed by the `midnight-tooling` plugin's devnet skill.

---

## Core Rule

Use `/midnight-tooling:devnet` for network lifecycle management. Use wallet MCP tools for wallet operations.

| Task | Tool |
|------|------|
| Start the devnet | `/midnight-tooling:devnet start` |
| Stop the devnet | `/midnight-tooling:devnet stop` |
| Check devnet health | `/midnight-tooling:devnet health` |
| View devnet logs | `/midnight-tooling:devnet logs` |
| Restart devnet | `/midnight-tooling:devnet restart` |
| Generate a wallet | `midnight_wallet_generate` |
| Check balance | `midnight_balance` |
| Transfer tokens | `midnight_transfer` |
| Fund wallet | `midnight_airdrop` |
| Register dust | `midnight_dust_register` |

---

## How Wallet-CLI Auto-Detects the Devnet

The wallet-cli does not require manual configuration to connect to the devnet. At startup, it runs `docker ps` and parses the output to find containers by Docker image name (not container name). It matches image names against known patterns:

| Service | Image Pattern |
|---------|--------------|
| Midnight node | `midnight-node` |
| Indexer | `indexer-standalone` |
| Proof server | `proof-server` |

For each matched container, the wallet-cli reads the port mappings from `docker ps` output and extracts the host-side port numbers.

### Standard Port Mapping

| Service | Default Host Port | Protocol |
|---------|------------------|----------|
| Midnight node RPC | `9944` | HTTP |
| Indexer GraphQL | `8088` | WebSocket (`ws://`) |
| Proof server | `6300` | HTTP |

The wallet-cli constructs endpoint URLs automatically:
- Node: `http://localhost:9944`
- Indexer: `ws://localhost:8088`
- Proof server: `http://localhost:6300`

This auto-detection works with containers started by both the devnet skill and the wallet-cli's own `localnet` commands — because it matches by image name, not container name.

---

## Why `midnight_localnet_*` Commands Conflict

The wallet-cli's built-in `localnet` management uses Docker Compose with different container names than the `midnight-tooling` devnet skill:

| Service | Devnet Skill Container Name | Wallet-CLI Container Name |
|---------|-----------------------------|--------------------------|
| Node | `midnight-node` | `node` |
| Indexer | `midnight-indexer` | `indexer` |
| Proof server | `midnight-proof-server` | `proof-server` |

Both use the **same host ports**. If `midnight_localnet_up` is called while the devnet skill's containers are running, Docker will refuse to bind the same port twice and one of the sets of containers will fail.

Additionally, `midnight_localnet_clean` removes containers by name — it could remove containers with its own container name scheme but not the devnet skill's containers, leaving a partial state.

### Safe vs Unsafe Tools

| Tool | Safe When Devnet Active? | Notes |
|------|--------------------------|-------|
| `midnight_localnet_status` | Yes | Read-only, shows container status |
| `midnight_localnet_logs` | Yes | Read-only, streams logs |
| `midnight_localnet_up` | No | Port conflict with devnet |
| `midnight_localnet_stop` | No | Wrong containers |
| `midnight_localnet_down` | No | Wrong containers |
| `midnight_localnet_clean` | No | May remove wrong containers |

---

## Network ID

When working with the local devnet, the network identifier is `undeployed`. This is the value used in:

- `midnight_wallet_generate` → `"network": "undeployed"`
- `midnight_balance` → `"network": "undeployed"`
- `midnight_transfer` → `"network": "undeployed"`
- `midnight_config_set` → `"key": "network", "value": "undeployed"`

The `undeployed` network is the only one that supports `midnight_airdrop`. The other networks (`preprod`, `preview`) are Midnight testnets with their own faucets.

---

## Configuration Overrides

If the devnet runs on non-standard ports, or if a remote devnet is used, endpoints can be overridden persistently via `midnight_config_set`:

```json
// Set a custom proof server URL
{ "key": "proof-server", "value": "http://localhost:6300" }

// Set a custom node URL
{ "key": "node", "value": "http://localhost:9944" }

// Set a custom indexer WebSocket URL
{ "key": "indexer-ws", "value": "ws://localhost:8088" }

// Lock the default network
{ "key": "network", "value": "undeployed" }
```

Overrides set with `midnight_config_set` take precedence over auto-detection. Use `midnight_config_unset` to restore auto-detection behavior:

```json
{ "key": "proof-server" }
```

### Per-Call Overrides

Individual tool calls also accept endpoint override parameters without changing the global config:

```json
{
  "to": "mn_addr_undeployed1xyz...",
  "amount": "10",
  "proof-server": "http://custom-host:6300",
  "node": "http://custom-host:9944",
  "indexer-ws": "ws://custom-host:8088"
}
```

---

## Typical Devnet Workflow

```
1. /midnight-tooling:devnet start          ← Start node, indexer, proof server
2. /midnight-tooling:devnet health         ← Wait for all services to be healthy
3. midnight_wallet_generate { "name": "alice" }
4. midnight_airdrop { "amount": "100" }
5. midnight_dust_register {}
6. midnight_transfer { "to": "...", "amount": "10" }
```

---

## Diagnosing Connection Issues

If wallet tools fail with `NETWORK_ERROR` or `ECONNREFUSED`:

1. Check devnet status: `/midnight-tooling:devnet status`
2. Check service health: `/midnight-tooling:devnet health`
3. View recent logs: `/midnight-tooling:devnet logs`
4. Restart if needed: `/midnight-tooling:devnet restart`

The wallet-cli auto-detects endpoints from `docker ps`, so if the devnet is running and healthy, no manual endpoint configuration is needed.
