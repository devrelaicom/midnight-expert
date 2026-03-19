---
name: mcp-health
description: Diagnose and manage the Midnight MCP server. Use when the user asks is the MCP server running, MCP server down, what compilers are available, OpenZeppelin libraries, update MCP, upgrade MCP server, or asks about health check, MCP status, MCP version, MCP troubleshooting, rate limiting, cache stats, midnight-health-check, midnight-get-status, midnight-check-version, midnight-get-update-instructions, midnight-list-compiler-versions, or midnight-list-libraries.
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

**Interpreting results:** If the server reports unhealthy status, check network connectivity first, then verify the server process is running. If uptime is very low, the server may have recently restarted — check logs for crash details.

## midnight-get-status

View current rate limits and cache statistics. Use this to check whether you are approaching rate limits or to understand cache hit rates.

**Parameters:** None.

**Response includes:**

- Rate limit status (requests remaining, reset time)
- Cache statistics (hit rate, size, eviction counts)
- Active session count

**Interpreting results:** If requests remaining is below 10, reduce call frequency and prefer compound tools. If the cache hit rate is low, you may be issuing too many unique queries — try reusing previous results. The reset time indicates when your rate limit quota refreshes.

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

**Linking to compilation:** Pass the desired version string from this tool's output in the `versions` array parameter of `midnight-compile-contract`. For example, if this tool lists version `"0.5.0"`, use `"versions": ["0.5.0"]` in your compile call.

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
