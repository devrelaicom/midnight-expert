---
name: midnight-tooling:troubleshooting
description: This skill should be used when the user encounters errors, installation failures, version mismatches, or unexpected behavior with Midnight Network tools. Covers troubleshooting "ERR_UNSUPPORTED_DIR_IMPORT", "version mismatch", "NixOS installation", "Windows setup", "WSL", "Bun setup", "wrong environment", "incorrect URLs", "connection refused", "proof server not starting", "Docker not running", "OOM", "compact command not found", "bad interpreter", "exec format error", "COMPACT_DIRECTORY", "direnv not working", "mise not working", "port 6300", "ZK parameters not found", "stale terminal", "environment variables not set", "breaking changes after upgrade", "devnet not starting", "node not running", "indexer not syncing", "network start failed", "devnet health check failing", "MCP server not connecting", "midnight-devnet MCP error", or searching Midnight GitHub issues and release notes for known bugs. For wallet initialization failures or funding failures, use the midnight-wallet plugin.
---

# Midnight Troubleshooting

Systematic diagnosis and resolution of common issues encountered when developing with Midnight Network tools.

## General Approach

Follow this diagnostic sequence for any issue:

1. **Identify the symptom** - exact error message, unexpected behavior, or failure point
2. **Route to the correct reference** - use the diagnostic table below
3. **Fetch current documentation** - many references pull the latest docs from source via octocode
4. **Check for known issues** - search open GitHub issues in the midnightntwrk org
5. **Check release notes** - the issue may be a known bug fixed in a newer version

## Diagnostic Routing

| Symptom / Keyword | Reference File |
|---|---|
| NixOS, Nix, nix-shell | `references/nixos-installation.md` |
| Version mismatch, incompatible versions, compatibility matrix | `references/version-mismatch.md` |
| ERR_UNSUPPORTED_DIR_IMPORT, stale terminal, node version | `references/err-unsupported-dir-import.md` |
| Bun, bun runtime, bun setup | `references/bun-setup.md` |
| Windows, WSL, PowerShell | `references/windows-setup.md` |
| Wrong URL, incorrect endpoint, wrong network, wrong environment, preprod, testnet, mainnet | `references/environment-urls.md` |
| Proof server, Docker, ZK parameters, port 6300, container (for proof-server-in-devnet issues also check `references/devnet-issues.md`) | `references/proof-server-issues.md` |
| compact: command not found, shebang, exec format error, compactc wrapper | `references/compact-cli-issues.md` |
| direnv, mise, dotenv-cli, COMPACT_DIRECTORY, stale cache | `references/environment-tooling.md` |
| Devnet, local network, node, indexer, network start | `references/devnet-issues.md` |
| Wallet initialization, funding, balance, transfers, dust registration | Use the `midnight-wallet` plugin |
| MCP server not connecting, midnight-devnet MCP error, npx failed | `references/devnet-issues.md` |

For **cross-cutting** diagnostic techniques (not tied to a specific symptom):

| Technique | Reference File |
|---|---|
| Search open GitHub issues in midnightntwrk org | `references/searching-issues.md` |
| Check release notes for known bugs or breaking changes | `references/checking-release-notes.md` |

## Fetching Documentation from Source

Several references instruct fetching the latest documentation from the `midnightntwrk/midnight-docs` GitHub repository via the octocode MCP tools. This ensures guidance reflects the current state of the docs rather than stale cached knowledge.

Standard fetch pattern using octocode:

```
githubGetFileContent(
  owner: "midnightntwrk",
  repo: "midnight-docs",
  path: "<path-to-mdx-file>",
  fullContent: true
)
```

When parsing fetched MDX content:
- Strip YAML frontmatter (between `---` delimiters)
- Strip JSX import statements (`import ... from ...`)
- Strip JSX components (`<Tabs>`, `<TabItem>`, `<Admonition>`, etc.) but preserve their text content
- Preserve all markdown content, code blocks, and links

## Combining Techniques

Many issues benefit from multiple references. For example, a version mismatch may require:
1. `references/version-mismatch.md` - diagnose and fix the mismatch
2. `references/searching-issues.md` - check if others report the same combination
3. `references/checking-release-notes.md` - verify whether a newer version resolves it

When a problem is ambiguous, start with `references/searching-issues.md` to see if the exact error message appears in open issues before diving into specific references.

## Unrecognized Symptoms

If the user's issue does not match any row in the routing tables above:

1. Start with `references/searching-issues.md` to search for the exact error message
2. Check `references/checking-release-notes.md` for recent breaking changes
3. Ask the user for the exact error message, component versions, and operating system

## Cross-Skill Dependencies

Some references link to other skills in this plugin:

- **`references/checking-release-notes.md`** depends on the **release-notes** skill and its `references/component-map.md` for component directory mappings.
- **`references/compact-cli-issues.md`** references the **compact-cli** skill's `references/installation.md` for additional installation detail.
- **`references/environment-tooling.md`** references the **compact-cli** skill's `references/custom-directories.md` for per-project toolchain setup.
- **`references/devnet-issues.md`** depends on the **devnet** skill and its references for network lifecycle details.
- **`references/proof-server-issues.md`** references the **proof-server** skill for API endpoint details, Docker setup, and version management.
