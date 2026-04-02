---
name: midnight-tooling:release-notes
description: This skill should be used when the user asks about "Midnight release notes", "what changed in version X", "latest release", "changelog", "show me the changelog", "what's new in Midnight", "component versions", "list versions", "compact release notes", "ledger release notes", "wallet release notes", "proof server release notes", "node release notes", "lace release notes", "midnight-js release notes", "indexer release notes", viewing release history, checking component update details, or comparing versions of any Midnight Network component.
---

# Midnight Release Notes

Release notes for all Midnight Network components are maintained in the [midnight-docs](https://github.com/midnightntwrk/midnight-docs) repository under `docs/relnotes/`.

## Source Structure

The release notes directory contains:

- **Index files** (`docs/relnotes/{component}.mdx`) — Component title and brief description
- **Version files** (`docs/relnotes/{component}/{component}-{version}.mdx`) — Release notes for a specific version

## Fetching Release Notes

Use the octocode MCP tools to fetch release notes on demand from `midnightntwrk/midnight-docs` (branch: `main`):

1. **Discover components**: `githubViewRepoStructure` at path `docs/relnotes` with `depth=1`
2. **List versions for a component**: `githubViewRepoStructure` at path `docs/relnotes/{component}`
3. **Read release notes**: `githubGetFileContent` to fetch specific MDX files
4. **Read component description**: `githubGetFileContent` for the index file `docs/relnotes/{component}.mdx`

### Batch Reads

`githubGetFileContent` accepts up to 3 queries per call. Batch file reads for efficiency.

### Targeted Extraction

For large files, use `matchString` instead of `fullContent`. The `matchStringContextLines` parameter controls how many lines of surrounding context are returned around each match:

- `matchString="title:"` with `matchStringContextLines=1` — extract frontmatter title (1 line above and below)
- `matchString="## Breaking Changes"` with `matchStringContextLines=30` — extract a specific section (30 lines of context)

## MDX Format

Each version MDX file contains:

- **YAML frontmatter**: `title` field holds the component name and version (e.g., `title: Compact developer tools 0.4.0`). Some files also include a `description` field.
- **Release date**: Appears in one of two formats:
  - Inside a JSX `<div style={{...}}>` block as plain text, e.g., `12 May 2025`
  - As structured metadata: `* **Date**: 27 January 2026`
- **Content sections**: Varies by component but commonly includes Breaking Changes, New Features, Bug Fixes, Changelog, Artifacts, and Links.

Index MDX files (`{component}.mdx`) contain the component title, a short description paragraph, and an import for a dynamic list component (which should be stripped when displaying).

## Output Formatting

When presenting release notes to users:

- **Strip JSX/MDX artifacts**: Remove `import` statements, JSX components (e.g., `<div style={{...}}>`), and MDX-specific syntax. Preserve the plain text content within them.
- **Preserve markdown**: Keep headings, lists, code blocks, and links intact.
- **Reverse chronological order**: When showing multiple versions, present newest first.
- **Summaries**: For summary/overview requests, extract the `title` (component + version), release date, and section headings (Breaking Changes, New Features, Bug Fixes). Omit full section content unless the user asks for details.
- **Full notes**: When the user asks for details on a specific version, present the complete content with JSX/MDX artifacts stripped.

## Version Extraction from Filenames

Standard pattern: `{component}-{major}-{minor}-{patch}.mdx` maps to version `major.minor.patch`. RC pattern appends `-RC{n}`.

For the most reliable version number, always use the `title` field from the YAML frontmatter. The Compact compiler in particular uses a compound versioning scheme where the filename alone can be misleading. See `references/component-map.md` for full extraction rules, sorting guidance, and examples.

## Component Map

Midnight releases span 16 components. Consult **`references/component-map.md`** for the complete mapping of directory names, display names, descriptions, and aliases.

### Component Name Resolution

When a user specifies a component, perform fuzzy matching against directory names, display names, and known aliases from the component map. If the name is ambiguous and could match multiple components, ask the user to clarify. Do not guess.

Common ambiguous terms:

| User says | Could mean | Action |
|-----------|-----------|--------|
| "compact" | Compact compiler OR Compact developer tools | Ask user |
| "wallet" | Wallet (backend) OR Midnight Wallet API OR Lace | Ask user |

### Stale Components

The **proof-server** and **onchain-runtime** components are now part of Ledger and no longer receive standalone updates. When requested, show Ledger release notes instead with a note about the change. See `references/component-map.md` for last standalone versions and detailed handling guidance.

### Semver Range Matching

Support npm-style semver range syntax when filtering versions. There is no external semver tool — perform all comparison in-memory after fetching the version list via `githubViewRepoStructure`. Parse version strings into `(major, minor, patch)` tuples and compare numerically.

| Syntax | Meaning | Example |
|--------|---------|---------|
| `1.2.3` or `=1.2.3` | Exact match | `--version 0.4.0` |
| `>1.2.3` | Greater than | `--version >0.2` |
| `>=1.2.3` | Greater than or equal | `--version >=1` |
| `<1.2.3` | Less than | `--version <3.0.0` |
| `<=1.2.3` | Less than or equal | `--version <=2.0` |
| `1.2.3 - 2.0.0` | Inclusive range | `--version 0.2.0-0.4.0` |
| `^1.2.3` | Compatible (same major) | `--version ^2.0.0` |
| `~1.2.3` | Approximately (same minor) | `--version ~1.2` |

Treat missing segments as `.0`: `>0.2` means `>0.2.0`. Exclude RC versions from range matches unless the range explicitly includes an RC suffix.

## Reference Files

| Reference | Content | When to Read |
|-----------|---------|-------------|
| **`references/component-map.md`** | Complete component directory mapping with display names, descriptions, aliases, and stale component details | Component name resolution, listing components, disambiguation |
