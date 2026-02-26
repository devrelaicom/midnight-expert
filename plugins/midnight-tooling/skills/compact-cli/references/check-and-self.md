# CLI Health Checks and Self-Management

The Compact CLI has two layers of updates: the CLI tool itself and the compiler it manages. This reference covers commands for checking and updating the CLI tool.

## Checking for Compiler Updates

```bash
compact check
```

Queries the remote server for available compiler versions and reports whether a newer version exists. Does not download or install anything.

Use this to determine if `compact update` would do anything before running it.

### With Custom Directory

```bash
compact --directory ./.compact check
```

Checks for updates relative to the versions installed in the specified directory.

## Managing the CLI Tool Itself

The `compact self` subcommand manages the CLI binary independently of the compiler versions it manages.

### Check for CLI Tool Updates

```bash
compact self check
```

Checks whether a newer version of the Compact CLI tool is available. Does not download or install anything.

### Update the CLI Tool

```bash
compact self update
```

Downloads and replaces the `compact` binary with the latest version. This does not affect installed compiler versions.

**Important**: After running `compact self update`, verify the update succeeded:

```bash
compact --version
```

### When to Update What

| Scenario | Command | What Changes |
|----------|---------|-------------|
| New compiler features or fixes needed | `compact update` | Downloads new compiler version |
| CLI tool has a bug or missing feature | `compact self update` | Replaces the `compact` binary |
| Check if compiler update available | `compact check` | Nothing (read-only check) |
| Check if CLI update available | `compact self check` | Nothing (read-only check) |

### Recommended Update Order

When updating both:

1. Run `compact self update` first (update the CLI tool)
2. Verify with `compact --version`
3. Run `compact update` (download latest compiler)
4. Verify with `compact compile --version`

Updating the CLI tool first ensures the latest download and version management logic is used when fetching the compiler.
