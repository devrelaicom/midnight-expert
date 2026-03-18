---
name: mcp-repository
description: This skill should be used when the user asks about getting a file from a Midnight repo, listing example contracts, checking latest updates, checking breaking changes, getting a file at a specific version, comparing syntax between versions, upgrade checks, repo context, midnight-get-file, midnight-list-examples, midnight-get-latest-updates, midnight-check-breaking-changes, midnight-get-file-at-version, midnight-compare-syntax, midnight-upgrade-check, midnight-get-repo-context, or browsing Midnight repository content.
---

# Midnight MCP Repository Tools

Six individual tools and two compound tools for accessing Midnight repository content, browsing examples, tracking updates, and managing version transitions.

## midnight-get-file

Retrieve a file from a Midnight repository using repo aliases.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `repo` | Yes | Repository alias (see table below) |
| `path` | Yes | File path within the repository |

**Repository aliases:**

| Alias | Repository | Content |
|-------|-----------|---------|
| `compact` | Compact compiler/language repo | Compiler source, language spec |
| `counter` | Counter example | Simple counter contract example |
| `bboard` | Bulletin board example | Bulletin board DApp example |
| `welcome` | Welcome example | Introductory example contract |

Use this tool when you need the exact content of a specific file. Prefer this over search tools when you know the repository and file path.

## midnight-list-examples

Browse available example contracts with metadata including complexity ratings.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `category` | No | Filter by category (e.g., `token`, `governance`, `basic`) |
| `complexity` | No | Filter by complexity level |

**Response includes:**

- Example name and description
- Complexity rating (beginner, intermediate, advanced)
- File paths for the example's source files
- Tags and categories

Use this tool to find relevant examples when a user is learning a pattern, to suggest starting points for new projects, or to find reference implementations.

## midnight-get-latest-updates

Retrieve recent commits across Midnight repositories. Shows what has changed recently in the ecosystem.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `repo` | No | Filter to a specific repository. Omit for updates across all repos |
| `limit` | No | Number of recent commits to return |

Use this tool to check what has changed recently, to find when a feature was added, or to verify whether a reported bug has been fixed.

## midnight-check-breaking-changes

Check for breaking changes between two versions of a Midnight component.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `from` | Yes | Starting version |
| `to` | Yes | Target version |
| `component` | No | Specific component to check (e.g., `compact`, `sdk`) |

**Response includes:**

- List of breaking changes with descriptions
- Migration steps for each breaking change
- Affected APIs, syntax, or configuration

Use this tool before upgrading a project to a new version, or when a user reports issues after an upgrade.

## midnight-get-file-at-version

Retrieve the exact content of a file at a specific tagged version. Use this when you need to see what a file looked like at a particular release, or when comparing behavior across versions.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `repo` | Yes | Repository alias |
| `path` | Yes | File path within the repository |
| `version` | Yes | Version tag or commit reference |

## midnight-compare-syntax

Diff the syntax or API surface between two versions. Shows what changed in the language, compiler, or SDK between releases.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `from` | Yes | Starting version |
| `to` | Yes | Target version |
| `component` | No | Specific component to compare |

**Response includes:**

- Added syntax or API elements
- Removed syntax or API elements
- Changed behavior or signatures

## Compound Tools

Two compound tools bundle multiple repository operations into a single call, reducing token usage and round trips.

### midnight-upgrade-check

Combines version checking, breaking change detection, and migration guidance into a single call. Saves approximately 60% of the tokens that would be required by calling the individual tools separately.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `from` | Yes | Current version |
| `to` | Yes | Target version |
| `component` | No | Specific component to check |

**Equivalent to calling:**

1. `midnight-check-version` — What version is installed vs. what is available
2. `midnight-check-breaking-changes` — What breaks between the two versions
3. Migration guidance — Step-by-step instructions for the upgrade

### midnight-get-repo-context

Combines version information, syntax reference, and example listings into a single call. Saves approximately 50% of the tokens that would be required by calling the individual tools separately.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `component` | No | Specific component to get context for |
| `version` | No | Target version |

**Equivalent to calling:**

1. `midnight-check-version` — Current version information
2. `midnight-compare-syntax` — Syntax reference for the target version
3. `midnight-list-examples` — Relevant examples for the component

### When to Use Compound vs. Individual Tools

| Scenario | Use |
|----------|-----|
| Planning an upgrade | `midnight-upgrade-check` |
| Starting work on a new contract | `midnight-get-repo-context` |
| Need only breaking changes, not full upgrade plan | `midnight-check-breaking-changes` |
| Need a specific file, not general context | `midnight-get-file` |
| Need only examples, not version context | `midnight-list-examples` |

Always prefer compound tools when they cover your needs. Use individual tools only when you need a specific subset of information or need to customize parameters that the compound tool does not expose.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `mcp-overview` |
| Compact compilation for verifying retrieved code | `compact-core:compact-compilation` |
| Verification methodology using repository content | `compact-core:verify-correctness` |
| Compact standard library reference | `compact-core:compact-standard-library` |
