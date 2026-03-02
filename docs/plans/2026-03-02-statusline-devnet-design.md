# Statusline Devnet Integration Design

**Date**: 2026-03-02
**Scope**: Modify `plugins/midnight-tooling/scripts/sl.sh` to display local devnet node status using the `midnight-local-devnet` CLI, add Compact language version, and optimize for statusline space constraints.

## Segments

Three segments, matching the current count:

| Segment | Content | Colors | Condition |
|---------|---------|--------|-----------|
| Brand | `🌙 Midnight` | PRIMARY_BG/FG | Always (Midnight project) |
| Devnet | `Devnet ✓✓✓` | SUCCESS (all up), WARNING (partial), ERROR (all down) | CLI available, devnet partially/fully running |
| Devnet | `No devnet` | TERTIARY (muted) | CLI unavailable, all services stopped, or error |
| Compact | `⚙ compactc 0.16.0/0.29.0` | INFO | `compact` in PATH |
| Compact | `⚙ compactc 0.16.0/0.29.0 ↑` | WARNING | Update available |

### Devnet Icons

Three icons representing Node, Indexer, Proof Server (left to right):
- `✓` = running/healthy (green foreground)
- `✗` = not running/unhealthy (red foreground)

Icon display logic:
- All services stopped → show "No devnet" (not three crosses)
- Any services running → show icon grid (e.g., `✓✓✗`)

### Compact Version Format

Slash-separated: `compactc {compiler_version}/{language_version}`
- Compiler version from `compact compile --version`
- Language version from `compact compile --language-version`
- If language version unavailable, show compiler version only

## Data Sources

### Primary: `npx @aaronbassett/midnight-local-devnet status --json`

```json
{
  "running": true,
  "services": [
    { "name": "node", "port": 9944, "url": "...", "status": "running" },
    { "name": "indexer", "port": 8088, "url": "...", "status": "running" },
    { "name": "proof-server", "port": 6300, "url": "...", "status": "running" }
  ]
}
```

Service status values: `running`, `stopped`, `unhealthy`, `unknown`.

### Supplementary: `npx @aaronbassett/midnight-local-devnet health --json`

```json
{
  "node": { "healthy": true, "responseTime": 45 },
  "indexer": { "healthy": true, "responseTime": 32 },
  "proofServer": { "healthy": true, "responseTime": 28, "error": "..." },
  "allHealthy": true
}
```

Health data overrides status when available — a container that is "running" but health-check-unhealthy shows `✗`.

## Caching Strategy

| Check | Cache TTL | Cache File |
|-------|-----------|------------|
| Rendered output | 5s | `/tmp/midnight-sl-${DIR_HASH}` (existing) |
| Devnet health | 30s | `/tmp/midnight-devnet-health-${DIR_HASH}` |
| Compact versions | 1 hour | `/tmp/midnight-compact-ver-${DIR_HASH}` |
| Compact update check | 30 min | `/tmp/midnight-compact-check-${DIR_HASH}` (existing) |
| Project detection | 1 hour | `/tmp/midnight-detect-${DIR_HASH}` (existing) |

## Error Handling

| Failure | Behavior |
|---------|----------|
| `npx` not available | "No devnet" segment (TERTIARY) |
| `status --json` timeout (3s) | "No devnet", cache failure for 5s |
| `status --json` returns error | "No devnet" |
| `health --json` fails | Ignore, use status data only |
| `compact compile --version` fails | Omit compact segment entirely |
| `compact compile --language-version` fails | Show compiler version only |
| All services stopped | "No devnet" (not `✗✗✗`) |

## What Changes

### Removed
- Direct `curl` to `localhost:6300/ready` for proof server check
- Docker-based proof server port discovery fallback
- Standalone proof server segment with busy/starting/ready states

### Added
- `npx @aaronbassett/midnight-local-devnet status --json` as primary devnet check
- `npx @aaronbassett/midnight-local-devnet health --json` as 30s supplementary check
- `compact compile --language-version` call (1hr cache)
- Devnet segment with ✓✗ icon grid
- "No devnet" muted state

### Modified
- Compact segment: `compactc v0.16` → `compactc 0.16.0/0.29.0` (slash-separated, no `v` prefix)
- Project detection: CLI availability as additional detection signal (file-based checks remain as fallback)

## Preserved (unchanged)
- Phase 0: stdin/config reading
- Phase 1: 5s output cache mechanism
- Phase 2: Chain discovery and execution
- Phase 3: File-based project detection (as fallback)
- Phase 5: Theme system (all 8 themes) and style system (powerline/minimal/capsule)
- Phase 6: Output and cache write
- All cross-platform helpers (get_hash, get_file_age, run_with_timeout)
