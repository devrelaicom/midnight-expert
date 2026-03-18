---
name: mcp-health
description: This skill should be used when the user asks about midnight health check, MCP server status, MCP version, checking the MCP server version, compiler versions available in MCP, update instructions for the MCP server, listing available libraries, MCP troubleshooting, midnight-health-check, midnight-get-status, midnight-check-version, midnight-get-update-instructions, midnight-list-compiler-versions, midnight-list-libraries, rate limiting, cache stats, or diagnosing MCP server connection issues.
---

# Midnight MCP Health and Diagnostics Tools

Six tools for checking server health, monitoring rate limits, managing versions, and listing available compilers and libraries. Call health tools once per session — status does not change during a conversation.

## midnight-health-check

Check server health and API connectivity. Use this as the first diagnostic step when the MCP server appears unresponsive or returns unexpected errors.

**Parameters:** None.

**Response includes:**

- Server status (healthy/unhealthy)
- API endpoint connectivity
- Service uptime

## midnight-get-status

View current rate limits and cache statistics. Use this to check whether you are approaching rate limits or to understand cache hit rates.

**Parameters:** None.

**Response includes:**

- Rate limit status (requests remaining, reset time)
- Cache statistics (hit rate, size, eviction counts)
- Active session count

## midnight-check-version

Compare the installed MCP server version against the latest available version on npm.

**Parameters:** None.

**Response includes:**

- Installed version
- Latest available version on npm
- Whether an update is available

## midnight-get-update-instructions

Get platform-specific instructions for updating the MCP server to the latest version.

**Parameters:** None.

**Response includes:**

- Update commands for the current platform
- Post-update verification steps
- Notes about breaking changes in the new version (if any)

## midnight-list-compiler-versions

List all compiler versions available through the MCP server, with their corresponding Compact language version mappings.

**Parameters:** None.

**Response includes:**

- Available compiler versions
- Language version mapping (which Compact language version each compiler supports)
- Default compiler version

Use this tool to check which compiler versions are available for `midnight-compile-contract`, or to determine the correct compiler version for a specific Compact language version.

## midnight-list-libraries

List available OpenZeppelin Compact library modules that can be used in contract development.

**Parameters:** None.

**Response includes:**

- Available library modules with descriptions
- Module import paths
- Supported versions

Use this tool to discover available library modules when writing new contracts, or to check whether a specific OpenZeppelin module is available.

## Troubleshooting

### Common Connection Issues

| Symptom | Likely Cause | Resolution |
|---------|-------------|------------|
| MCP server not responding | Server not started or crashed | Restart with `npx -y midnight-mcp@latest` |
| Connection refused | Wrong port or server not listening | Check MCP configuration in `.mcp.json` |
| Timeout on all calls | Network issue or server overloaded | Run `midnight-health-check` to confirm; check network connectivity |
| Authentication error | Invalid or expired credentials | Check MCP server configuration |

### Rate Limiting

The MCP server enforces rate limits to prevent abuse. If you encounter rate limiting:

1. Run `midnight-get-status` to check current rate limit status
2. Wait for the reset window (shown in the status response)
3. Reduce call frequency — follow the call frequency guidance in `mcp-overview`
4. Use compound tools (`midnight-upgrade-check`, `midnight-get-repo-context`) to reduce the number of individual calls

### Graceful Degradation

When the MCP server is unavailable or rate-limited, fall back to alternative approaches:

| MCP Tool | Fallback |
|----------|----------|
| `midnight-search-compact` | Use skills from `compact-core` plugin |
| `midnight-search-docs` | Use `midnight-fetch-docs` for live doc pages, or reference skill content |
| `midnight-compile-contract` | Use local `compact compile` via the Compact CLI (see `compact-core:compact-compilation`) |
| `midnight-search-typescript` | Use `npm view` and GitHub source browsing |
| `midnight-list-compiler-versions` | Use `compact list --installed` locally |
| `midnight-list-libraries` | Reference `compact-core:compact-standard-library` skill content |

### Version Mismatch

If `midnight-check-version` shows that the installed version is behind the latest:

1. Run `midnight-get-update-instructions` for platform-specific update steps
2. After updating, run `midnight-health-check` to verify the new version is running
3. Run `midnight-check-version` again to confirm the update was applied

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `mcp-overview` |
| Local Compact CLI as fallback for compilation | `compact-core:compact-compilation` |
| Compact standard library as fallback for library listing | `compact-core:compact-standard-library` |
| Verification methodology | `compact-core:verify-correctness` |
