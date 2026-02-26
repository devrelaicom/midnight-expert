# Incorrect URLs and Wrong Environment

Resolve issues caused by incorrect endpoint URLs or connecting to the wrong Midnight network environment.

## Midnight Network Environments

Midnight follows Cardano's naming convention for network environments. The testnet is called **preprod** (pre-production), not "testnet".

Reference: https://book.world.dev.cardano.org/env-preprod.html

Common environment names:
- **preprod** - The public test network (equivalent to "testnet" in other ecosystems)
- **mainnet** - The production network

**Critical rule:** Do not mix URLs from different environments. All endpoints (node, indexer, proof server, etc.) must point to the same network environment.

## Fetch Current Environment URLs

Fetch the current URLs for each environment from the release notes overview page:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/relnotes/overview.mdx",
  matchString: "url",
  matchStringContextLines: 30
)
```

If the `matchString` approach doesn't capture all URLs, fetch the full content:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/relnotes/overview.mdx",
  fullContent: true
)
```

## Diagnosing URL Issues

### Symptoms

- Connection refused or timeout errors when calling Midnight APIs
- Unexpected data or empty responses from endpoints
- "Network mismatch" or "wrong network" errors in DApp logs
- Transactions submitted but never confirmed
- Wallet shows wrong balance or no balance

### Diagnostic Steps

1. **Collect all configured URLs** - Check environment variables, `.env` files, config files, and hardcoded values for any Midnight endpoint URLs
2. **Fetch current URLs** (above) - Compare the user's configured URLs against the official current URLs
3. **Verify environment consistency** - Ensure all URLs belong to the same environment (all preprod or all mainnet)
4. **Test connectivity** - Attempt to reach each endpoint:
   ```bash
   curl -s -o /dev/null -w "%{http_code}" <endpoint-url>/health
   ```
5. **Check for stale URLs** - Midnight may update endpoint URLs between releases. If the user's URLs don't match the current docs, they need to update.

### Common Mistakes

- Copying a URL from a tutorial written for a different environment
- Mixing preprod node URL with mainnet indexer URL
- Using an old URL that was valid in a previous release but has since changed
- Hardcoding URLs instead of using environment variables (makes switching environments error-prone)

## If Issues Persist

1. Search for URL or environment-related issues: `gh search issues "URL environment org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Check `references/checking-release-notes.md` for endpoint URL changes in recent releases
