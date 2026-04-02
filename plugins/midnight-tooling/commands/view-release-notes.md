---
name: midnight-tooling:view-release-notes
description: View Midnight component release notes from the official documentation
allowed-tools: AskUserQuestion, mcp__plugin_midnight-tooling_octocode__githubViewRepoStructure, mcp__plugin_midnight-tooling_octocode__githubGetFileContent
argument-hint: "[<component> [--version <semver-range>]]"
---

View release notes for Midnight Network components fetched from the [midnight-docs](https://github.com/midnightntwrk/midnight-docs) repository.

## Step 1: Load Context

Read the `midnight-tooling:release-notes` skill. If the arguments include a component name, also read `references/component-map.md` for name resolution and aliases.

## Step 2: Parse Arguments

Parse `$ARGUMENTS` to extract:

- **Component name**: All text before `--version` flag (may be empty)
- **Version range**: Text after `--version` (may be empty)

| Input | Component | Version |
|-------|-----------|---------|
| *(empty)* | *(none)* | *(none)* |
| `compact tools` | compact tools | *(none)* |
| `compact tools --version 0.4.0` | compact tools | 0.4.0 |
| `--version >=1` | *(none)* | >=1 |
| `ledger --version 3.0.6 - 7.0.0` | ledger | 3.0.6 - 7.0.0 |

## Step 3: Resolve Component Name

Skip this step if no component name was provided.

1. Normalize the component name: lowercase, collapse whitespace
2. Match against the component map (directory names, display names, and aliases in `references/component-map.md`)
3. **Ambiguous match** (e.g., "compact" matches both Compact compiler and Compact developer tools): Use `AskUserQuestion` to disambiguate. Do not guess.
4. **No match**: Suggest the closest matches from the component map and ask the user

### Proof Server and Onchain Runtime Redirect

If the resolved component is `proof-server` or `onchain-runtime`:

- **Default**: Redirect to **Ledger** release notes
- Include a note in the response:

  > **Note**: The {component} is now developed as part of Ledger ([midnight-ledger](https://github.com/midnightntwrk/midnight-ledger)). The last standalone {component} release was 4.0.0 (12 May 2025). Showing Ledger release notes instead.
  >
  > To view the standalone {component} release notes, re-run with the `--standalone` flag or ask me to show them.

- If the user has previously indicated they want the standalone release notes in this conversation, honor that and fetch from the component's own directory

## Step 4: Fetch Directory Structure

Use `githubViewRepoStructure` to fetch the release notes structure:

```
owner: midnightntwrk
repo: midnight-docs
path: docs/relnotes
depth: 2
entriesPerPage: 200
```

If `pagination.hasMore` is true, fetch additional pages to get the complete structure.

From the structure, build a map of `component → [version files]` by parsing the directory listing.

## Step 5: Route Based on Arguments

### Case A: No component, no version — List all components

For each component directory:

1. Determine the latest stable version from filenames (highest semver, excluding RCs)
2. Fetch the component index MDX files (`docs/relnotes/{component}.mdx`) to get descriptions — batch up to 3 per `githubGetFileContent` call using `matchString="---"` with `matchStringContextLines=15` to get just the frontmatter and first paragraph
3. Extract the component title from the `title` frontmatter field

Present a formatted table:

```
| Component | Latest Version | Description |
|-----------|---------------|-------------|
| Compact compiler | 0.20 | Smart contract programming language and compiler |
| Compact developer tools | 0.4.0 | CLI for managing the Compact toolchain |
| ... | ... | ... |
```

Sort alphabetically. Mark deprecated components. For proof-server and onchain-runtime, show their latest standalone version with a note that they are now part of Ledger.

### Case B: No component, with version — List components matching version range

1. For each component, extract all versions from filenames
2. Apply the semver range filter (see Semver Range Matching in the skill)
3. List only components that have at least one matching version
4. For each matching component, show the matching version(s), not just the latest

Present as a table:

```
| Component | Matching Versions | Description |
|-----------|------------------|-------------|
| Ledger | 7.0.0, 4.0.0, 3.0.6 | Core blockchain infrastructure |
| ... | ... | ... |
```

### Case C: Component specified, no version — Show latest release notes

1. Find the latest stable version file for the resolved component (highest semver, excluding RCs)
2. Fetch the full file content with `githubGetFileContent` using `fullContent: true`
3. Format and present the release notes (see Step 6)

### Case D: Component + version — Show specific release notes

**Exact version**: Find the matching version file and fetch it.

**Version range**: Find all matching version files. If more than 5 match, show the most recent 5 and note that additional versions were omitted. Fetch and display each.

For each matching version, fetch the file content and format it (see Step 6).

## Step 6: Format Output

When presenting release notes content:

- **Strip** YAML frontmatter (do not display the license header, copyright, or sidebar fields)
- **Strip** MDX import statements (`import DynamicList from ...`)
- **Strip** JSX components (`<DynamicList />`)
- **Convert** `<div style={{...}}>` date blocks to plain text (e.g., extract `12 May 2025` from the JSX wrapper)
- **Preserve** all markdown content: headings, lists, code blocks, tables, and links
- **Use** the `title` frontmatter field as the main heading

Example formatted output:

```
## Compact developer tools 0.4.0 release notes

Today we are releasing the Compact developer tools (devtools) 0.4.0...

### Breaking Changes
...

### New Features
...
```

When listing components (Cases A and B):

- Present as a clean markdown table
- Sort alphabetically by display name
- Mark deprecated components with "(Deprecated)"
- For stale components (proof-server, onchain-runtime), append "→ see Ledger"
