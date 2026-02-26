# Compiler Version Management

The Compact CLI supports multiple compiler versions installed side-by-side. One version is the "default" used when `compact compile` is invoked without a version specifier.

## Installing / Updating Compiler Versions

### Update to Latest

```bash
compact update
```

Downloads the latest compiler version from the remote server and sets it as the default. If the latest version is already installed, no download occurs.

### Install a Specific Version

```bash
compact update 0.25.0
```

Downloads the specified version and sets it as the default. If already downloaded, skips the download and just sets the default.

### Install Without Setting Default

```bash
compact update 0.25.0 --no-set-default
```

Downloads the specified version but does not change which version is the default. Useful for installing a version to test with `compact compile +0.25.0` without disrupting the main workflow.

### With Custom Directory

```bash
compact --directory ./.compact update 0.25.0
```

Installs the compiler version into the specified artifact directory instead of the default `$HOME/.compact`.

## Listing Versions

### List Available Versions (Remote)

```bash
compact list
```

Queries the remote server and shows all available compiler versions that can be installed.

### List Installed Versions (Local)

```bash
compact list --installed
```

Shows compiler versions currently installed in the artifact directory. The current default is marked with an arrow (`→`):

```
compact: installed versions

→ 0.28.0
  0.25.0
```

### List Installed in Custom Directory

```bash
compact --directory ./.compact list --installed
```

## Cleaning Up Versions

### Remove All Versions

```bash
compact clean
```

Removes all installed compiler versions from the artifact directory. After this, `compact compile` will fail until a version is installed with `compact update`.

### Remove All Except Current Default

```bash
compact clean --keep-current
```

Removes all installed versions except the one currently set as default. Useful for freeing disk space while keeping the working version.

### Clean Custom Directory

```bash
compact --directory ./.compact clean --keep-current
```

## Common Workflows

### Switch Between Compiler Versions

```bash
# Install both versions
compact update 0.28.0
compact update 0.25.0

# Now 0.25.0 is default (most recently updated)
# Use default version
compact compile src/contract.compact build/

# Use a specific version without changing default
compact compile +0.28.0 src/contract.compact build/

# Switch default back to 0.28.0
compact update 0.28.0
```

### Pin a Project to a Specific Compiler Version

```bash
# Install specific version in project-local directory
compact --directory ./.compact update 0.25.0

# Configure COMPACT_DIRECTORY for the project (see custom-directories.md)
# Then compile normally - will use the project-local version
compact compile src/contract.compact build/
```

### Audit and Clean Up

```bash
# See what's installed
compact list --installed

# Remove old versions, keep the one in use
compact clean --keep-current

# Verify
compact list --installed
```
