# Installing the Compact CLI

## Prerequisites

- A Unix-like environment (macOS, Linux, WSL)
- `curl` available on the system
- A shell that supports PATH configuration (zsh, bash)

No Node.js, Docker, or other tools are required to install the Compact CLI itself.

## Install via the Installer Script

Run the official installer to download pre-built binaries:

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/midnightntwrk/compact/releases/latest/download/compact-installer.sh | sh
```

The installer downloads the `compact` binary and places it in a local bin directory (typically `~/.local/bin/` or `~/.compact/bin/`). It also attempts to update the shell profile to add this directory to PATH.

## PATH Configuration

The installer script automatically modifies the shell profile (`~/.zshrc`, `~/.bashrc`, etc.) to add the Compact binary directory to PATH. However, the running shell session does not pick up these changes automatically.

### Reload the Shell

After installation, reload the shell configuration:

```bash
# For zsh (default on macOS)
source ~/.zshrc

# For bash
source ~/.bashrc
```

Alternatively, open a new terminal window.

### Manual PATH Configuration

If `compact` is still not found after reloading, add the binary directory to PATH manually. Check the installer output for the exact path, then add to the shell profile:

```bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$HOME/.compact/bin:$PATH"
```

Then reload the shell configuration.

### Verify PATH

Confirm the binary is accessible:

```bash
which compact
# Expected output: /Users/<username>/.local/bin/compact
# or: /Users/<username>/.compact/bin/compact
```

## First-Time Setup: Download a Compiler

The CLI tool alone cannot compile contracts. After installing the CLI, download a compiler version:

```bash
compact update
```

This downloads the latest compiler version and sets it as the default.

## Verification

Run these commands to confirm everything is working:

```bash
# Check CLI tool version
compact --version
# Example output: compact 0.2.0

# Check compiler version
compact compile --version
# Example output: 0.28.0

# Check installation path
which compact
# Example output: /Users/<username>/.local/bin/compact

# List installed compiler versions
compact list --installed
# Example output:
# compact: installed versions
# → 0.28.0
```

The arrow (`→`) next to a version indicates it is the current default.

## Uninstalling

The Compact CLI does not provide an uninstall command. To remove it:

1. Delete the binary: `rm $(which compact)`
2. Delete the artifact directory: `rm -rf $HOME/.compact`
3. Remove the PATH entry from the shell profile (`~/.zshrc` or `~/.bashrc`)
4. Reload the shell: `source ~/.zshrc`
