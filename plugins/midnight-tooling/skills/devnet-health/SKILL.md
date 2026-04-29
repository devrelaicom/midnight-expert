---
name: midnight-tooling:devnet-health
description: This skill should be used when the user asks to check the status or health of the local Midnight devnet, including "is the devnet running", "is the node up", "is the proof server responding", "indexer health", "devnet status", "devnet health", "are the containers running", "are the services healthy", "devnet probes", or when an agent (e.g. doctor, statusline) needs structured per-service status/health for the local devnet.
---

# Devnet Health

Status and health checks for the local Midnight devnet (node, indexer, proof server). Pure shell — requires only `bash`, `docker`, and `curl`.

The two checks answer different questions:

- **Status** — "Is the docker container present, and is it running?"
- **Health** — "Is the service responding to its health endpoint within 5 s?"

Container running ≠ service healthy: a container can be `running` while the service inside is still booting, crashing on a loop, or otherwise not serving requests. Run **both** checks for a complete picture.

## Service Inventory

| Service        | Container Name           | Port | Health Endpoint                   |
|----------------|--------------------------|------|-----------------------------------|
| `node`         | `midnight-node`          | 9944 | `http://127.0.0.1:9944/health`    |
| `indexer`      | `midnight-indexer`       | 8088 | `http://127.0.0.1:8088/ready`     |
| `proof-server` | `midnight-proof-server`  | 6300 | `http://127.0.0.1:6300/version`   |

## Scripts

Both scripts live in `scripts/` next to this SKILL.md and accept an optional `--json` flag.

### `status.sh` — container status

```bash
bash scripts/status.sh           # text: <service>\t<status>\t<containerName>
bash scripts/status.sh --json    # JSON: {"services":[...],"allRunning":bool}
```

Status values: `running` | `stopped` | `not-found`.

Exit `2` if Docker is missing or the daemon is not running (also reflected in JSON via the `error` field).

### `health.sh` — HTTP probes

```bash
bash scripts/health.sh           # text: <service>\t<healthy|unhealthy>\t<ms>\t<httpCode>
bash scripts/health.sh --json    # JSON: {"node":{...},"indexer":{...},"proofServer":{...},"allHealthy":bool}
```

A service is `healthy` when its endpoint returns HTTP 2xx within the 5 s timeout.

Exit `2` if `curl` is not installed.

## Usage Patterns

### Quick eyeball check

```bash
bash scripts/status.sh
bash scripts/health.sh
```

### "Is anything actually running?"

```bash
bash scripts/status.sh --json | jq -r '.allRunning'
bash scripts/health.sh --json | jq -r '.allHealthy'
```

### Status overlaid with health (treat running-but-unhealthy as down)

```bash
status_json="$(bash scripts/status.sh --json)"
health_json="$(bash scripts/health.sh --json)"

# Example: node container is "running" but health endpoint failed → unhealthy
node_state="$(printf '%s' "$status_json" | jq -r '.services[] | select(.name=="node") | .status')"
node_healthy="$(printf '%s' "$health_json" | jq -r '.node.healthy')"
if [ "$node_state" = "running" ] && [ "$node_healthy" != "true" ]; then
  echo "node container is up but not serving"
fi
```

### Per-service probe from a script (no jq)

```bash
while IFS=$'\t' read -r service status ms code; do
  case "$service" in
    node) [ "$status" = "healthy" ] && echo "node ok in ${ms}ms" ;;
  esac
done < <(bash scripts/health.sh)
```

## Locating the Scripts at Runtime

Other skills, commands, and scripts that want to invoke these checks should resolve the absolute path via the plugin root. Use the `midnight-plugin-utils:find-claude-plugin-root` skill to materialize `/tmp/cpr.py`, then:

```bash
PLUGIN_ROOT="$(python3 /tmp/cpr.py midnight-tooling)"
SCRIPTS_ROOT="$PLUGIN_ROOT/skills/devnet-health/scripts"

bash "$SCRIPTS_ROOT/status.sh" --json
bash "$SCRIPTS_ROOT/health.sh" --json
```

This keeps the scripts callable regardless of where the plugin is installed (project vs user vs marketplace).

## When To Use Which Skill

| Question | Skill |
|----------|-------|
| Start, stop, or configure the devnet, generate compose files, or pick versions | `midnight-tooling:devnet` |
| Run a quick "is it up and serving?" probe from inside an agent or script | this skill |
| Diagnose a broken devnet, port conflicts, indexer sync issues, partial startup | `midnight-tooling:troubleshooting` (with `references/devnet-issues.md`) |
| Wire devnet status into the doctor command or statusline | this skill |

## Compatibility Notes

- **macOS / Linux**: both scripts target POSIX `bash` 3.2+ and use only `docker`, `curl`, `awk`. No bash 4 features (associative arrays, `mapfile`).
- **`jq` is optional**: scripts do not depend on `jq`; they emit JSON directly with `printf`. Callers that want to parse JSON can use `jq` if available or fall back to the tab-separated text output.
- **Timeouts**: HTTP probes use a 5 s timeout. Status checks use Docker's default; on a healthy daemon they return immediately.
