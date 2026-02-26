# Checking Release Notes for Known Issues

Check release notes to identify known bugs, breaking changes, and fixes relevant to the versions of Midnight components the user is running.

## When to Check

- The user is running an older version of a component and may be hitting a bug that was fixed in a later release
- The user recently upgraded and something broke - a breaking change may have been introduced
- The user is running the latest version but their code was written for an earlier version
- A version mismatch was detected and the impact needs to be assessed

## Using the Release Notes Skill

The `release-notes` skill provides comprehensive access to all Midnight component release notes. Use it to fetch notes for specific components and versions.

Key information from the release notes skill's `references/component-map.md`:

The 16 Midnight components with release notes are organized under `docs/relnotes/` in the `midnightntwrk/midnight-docs` repository. Each component has a directory of version-specific MDX files.

## Checking for Fixes in Later Versions

When the user is on version X and the latest is version Y:

1. **Identify the component directory** using the release-notes skill's component map
2. **List available version files** between X and Y:
   ```
   githubViewRepoStructure(
     owner: "midnightntwrk",
     repo: "midnight-docs",
     path: "docs/relnotes/<component-dir>",
     depth: 1
   )
   ```
3. **Search for relevant fixes** in each version between X and Y. Use `matchString` for efficiency:
   ```
   githubGetFileContent(
     owner: "midnightntwrk",
     repo: "midnight-docs",
     path: "docs/relnotes/<component-dir>/<version>.mdx",
     matchString: "<keyword from user's error>",
     matchStringContextLines: 10
   )
   ```
4. If a fix is found in version Z (where X < Z <= Y), recommend upgrading to at least version Z.

## Checking for Breaking Changes

When the user recently upgraded or their code targets an earlier version:

1. **Fetch the release notes for the version the user is running:**
   ```
   githubGetFileContent(
     owner: "midnightntwrk",
     repo: "midnight-docs",
     path: "docs/relnotes/<component-dir>/<current-version>.mdx",
     matchString: "breaking",
     matchStringContextLines: 15
   )
   ```
2. If there are breaking changes, present them to the user and check if their code needs to be updated.
3. Also check the version immediately prior to help identify what changed.

## Checking Multiple Components

Version issues often span multiple components. When diagnosing:

1. Get the user's full version set (compiler, CLI, proof server, SDK packages, etc.)
2. Fetch the compatibility matrix (see `references/version-mismatch.md`)
3. Check release notes for each component that is not at the expected version
4. Prioritize checking components where the version gap is largest

## Batch File Reads

To reduce round trips, use up to 3 `githubGetFileContent` queries per call when checking multiple version files:

```
githubGetFileContent(queries: [
  { path: "docs/relnotes/<component>/<v1>.mdx", matchString: "<keyword>", ... },
  { path: "docs/relnotes/<component>/<v2>.mdx", matchString: "<keyword>", ... },
  { path: "docs/relnotes/<component>/<v3>.mdx", matchString: "<keyword>", ... }
])
```
