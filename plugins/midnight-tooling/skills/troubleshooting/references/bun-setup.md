# Bun Setup for Midnight Development

Set up the Bun runtime for use with Midnight Network development tools.

## Fetch Current Guide

Fetch the latest Bun setup guide from the Midnight docs repository:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "docs/guides/install-bun-runtime-midnight.mdx",
  fullContent: true
)
```

Parse the fetched MDX content by stripping frontmatter, JSX imports, and component wrappers. Present the remaining markdown instructions to the user.

## Quick Fixes (if fetch is unavailable)

If the MCP tool is unavailable, try these common resolutions:

- Ensure Bun is installed and up to date: `bun --version` (install via `curl -fsSL https://bun.sh/install | bash`)
- Run `bun install` instead of `npm install` to generate Bun-compatible lockfiles
- If a Midnight package fails under Bun, test with Node.js (`npx`) to isolate Bun-specific issues
- Check for postinstall script failures in `bun install` output — these often assume npm/node

## Common Bun Issues

- **Lock file format** - Bun uses `bun.lockb` (binary format). Newer versions may also generate `bun.lock`. These are not interchangeable with npm/yarn/pnpm lock files.
- **Package compatibility** - Some Midnight packages may have postinstall scripts that assume npm/node. Check for script failures during `bun install`.
- **Global vs local** - Bun manages globals differently from npm. Check both:
  ```bash
  bun pm ls              # local direct deps
  bun pm ls --all        # local full tree
  ```
- **Node.js compatibility** - Bun aims for Node.js compatibility but some Node.js APIs may behave differently. If a Midnight tool fails under Bun but works under Node, this is likely a Bun compatibility gap.

## If the Guide Does Not Resolve the Issue

1. Search for Bun-related issues: `gh search issues "bun org:midnightntwrk" --state=open --limit=20 --sort=updated --json "title,url,updatedAt,commentsCount"`
2. Try running with Node.js to determine if the issue is Bun-specific or a general Midnight issue
