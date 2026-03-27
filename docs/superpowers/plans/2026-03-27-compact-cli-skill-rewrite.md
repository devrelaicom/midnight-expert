# Compact CLI Skill Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the compact-cli skill to fix factual errors, add missing commands/features, restructure reference files around workflows, and add comprehensive troubleshooting.

**Architecture:** Replace 5 topic-grouped reference files with 5 workflow-grouped references plus a centralized error catalog. Rewrite SKILL.md with corrected description, version reporting, and global flags.

**Tech Stack:** Markdown only — no code changes.

---

### Task 1: Rewrite SKILL.md

**Files:**
- Modify: `plugins/midnight-tooling/skills/compact-cli/SKILL.md`

- [ ] **Step 1: Replace SKILL.md with rewritten content**

Write this exact content to `plugins/midnight-tooling/skills/compact-cli/SKILL.md`:

```markdown
---
name: compact-cli
description: >-
  This skill should be used when the user asks about the Compact CLI, Compact
  Dev Tool, Compact Developer CLI, or compact devtools for Midnight Network
  smart contract development, including setting up the Compact toolchain on a
  new machine, resolving "compact: command not found" or "No default compiler
  set" errors, validating that Compact source code compiles correctly, switching
  between compiler versions, pinning a project to a specific compiler version,
  understanding why compilation is slow or how to speed it up, figuring out
  which version of the compiler or language they're running, setting up a
  project-local toolchain directory, configuring import search paths for
  multi-file contracts, understanding error messages or exit codes from the
  compiler or formatter, or troubleshooting why format or fixup is reporting
  failures
---

# Compact CLI Management

The Compact CLI (`compact`) is the command-line tool for managing the Midnight Network's smart contract development toolchain. It handles compiler version management, code formatting, fixup transformations, and compiler invocation.

## **Terminology — Read This First**

> **Three distinct things share the "Compact" name. Always be precise about which is being referenced.**

| Term | What It Is | Binary / Location | Version Command |
|------|-----------|-------------------|-----------------|
| **Compact CLI** | The command-line management tool (also called Compact Dev Tool, Compact Developer CLI, compact devtools) | `compact` (typically `~/.local/bin/compact`) | `compact --version` |
| **Compact** (language) | The smart contract programming language | Source files: `*.compact` | N/A |
| **Compact compiler** | The compiler that transforms Compact source into ZK circuits and TypeScript | `compactc.bin` (managed by CLI, stored in `$COMPACT_DIRECTORY`) | `compact compile --version` |

**Relationship**: The Compact CLI manages and invokes the Compact compiler, which compiles Compact (the language) source files. The CLI is the orchestrator; the compiler is the worker it manages.

When users say "install Compact", they typically mean installing the Compact CLI (which then manages the compiler). When they say "update Compact", determine whether they mean:
- **The CLI tool itself** → `compact self update`
- **The compiler** → `compact update`

These are independent operations. The CLI and compiler have separate version numbers.

## Version Reporting

The toolchain reports three independent version numbers. Confusing them is a common source of errors.

| What | Commands | Example Output |
|------|----------|----------------|
| **CLI tool version** | `compact --version`, `compact self --version` | `compact 0.5.1` |
| **Compiler version** | `compact compile --version`, `compact format --version`, `compact fixup --version` | `0.30.0` |
| **Language version** | `compact compile --language-version`, `compact format --language-version`, `compact fixup --language-version` | `0.22.0` |

The compiler also reports two additional versions relevant to DApp developers:

| What | Command | Example Output |
|------|---------|----------------|
| **Ledger version** | `compact compile -- --ledger-version` | `ledger-8.0.2` |
| **Runtime JS package version** | `compact compile -- --runtime-version` | `0.15.0` |

The CLI and compiler update independently:

| What to Update | Command | Check First |
|---------------|---------|-------------|
| The compiler | `compact update` | `compact check` |
| The CLI tool | `compact self update` | `compact self check` |

## Quick Command Reference

| Command | Aliases | Purpose |
|---------|---------|---------|
| `compact compile <source> <target-dir>` | `c` | Compile a Compact source file |
| `compact compile +<VER> <source> <target-dir>` | | Compile with a specific compiler version (full semver required) |
| `compact format [FILES]` | `f`, `fmt` | Format Compact source files |
| `compact format --check [FILES]` | | Check formatting without changes |
| `compact fixup [FILES]` | `fx`, `fix` | Apply fixup transformations (e.g. rename deprecated identifiers) |
| `compact fixup --check [FILES]` | | Check if fixups are needed without changes |
| `compact update [VERSION]` | `u`, `up` | Download compiler version, set as default |
| `compact list` | `l` | List all available compiler versions (remote) |
| `compact list --installed` | | List locally installed compiler versions |
| `compact check` | `ch` | Check for compiler updates without downloading |
| `compact clean` | `cl` | Remove all installed compiler versions |
| `compact clean --keep-current` | | Remove all except current default version |
| `compact self check` | `s check` | Check for CLI tool updates |
| `compact self update` | `s update` | Update the CLI tool itself |

## Global Flags

Every command accepts these flags:

| Flag | Environment Variable | Purpose |
|------|---------------------|---------|
| `--directory <DIR>` | `COMPACT_DIRECTORY` | Use a custom artifact directory instead of `$HOME/.compact` |

The `--directory` flag can appear before or after the subcommand — both positions are equivalent. When both the flag and environment variable are set, the flag takes precedence. The directory is created automatically if it does not exist.

## Compiling

The CLI invokes the compiler via `compact compile <source> <target-dir>`. Use `--skip-zk` during development to skip proving key generation (significantly faster). Prefix with `+VERSION` (full semver, e.g. `+0.29.0`) to use a specific installed compiler version. See `references/compile-format-fixup.md` for all compiler flags, output structure, import paths, and compilation troubleshooting.

## Formatting and Fixup

`compact format` formats `.compact` source files in place. When no files are specified, it recursively formats all `.compact` files in the current directory, respecting `.gitignore`. Use `--check` for CI pipelines (exits non-zero if changes needed).

`compact fixup` applies source-level transformations such as renaming deprecated identifiers. It shares the same file-targeting and `--check` behavior as `format`. See `references/compile-format-fixup.md` for full details on both commands.

## Version Management

Install, list, switch, and remove compiler versions with `update`, `list`, `check`, and `clean`. The `update` command accepts partial versions (`0`, `0.29`, or `0.29.0`). See `references/version-management.md` for workflows and troubleshooting.

## CLI Self-Management

Update the CLI tool itself with `compact self update`. This is independent of compiler updates. See `references/self-management.md` for details.

## Reference Files

| Reference | When to Read |
|-----------|-------------|
| **`references/installation.md`** | First-time setup, PATH issues, new machine |
| **`references/compile-format-fixup.md`** | Compiling contracts, formatting, fixup, compiler flags |
| **`references/version-management.md`** | Installing, switching, listing, or removing compiler versions |
| **`references/self-management.md`** | Updating the CLI tool, checking versions |
| **`references/troubleshooting.md`** | Error messages, exit codes, common failures |
```

- [ ] **Step 2: Verify the file renders correctly**

Run: `head -5 plugins/midnight-tooling/skills/compact-cli/SKILL.md`
Expected: The YAML frontmatter starting with `---` and `name: compact-cli`

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-tooling/skills/compact-cli/SKILL.md
git commit -m "docs(compact-cli): rewrite SKILL.md with corrected description, version reporting, fixup, and global flags"
```

---

### Task 2: Update installation.md

**Files:**
- Modify: `plugins/midnight-tooling/skills/compact-cli/references/installation.md`

- [ ] **Step 1: Replace installation.md with updated content**

Write this exact content to `plugins/midnight-tooling/skills/compact-cli/references/installation.md`:

```markdown
# Installing the Compact CLI

## Prerequisites

- A Unix-like environment (macOS, Linux, WSL)
- `curl` available on the system
- A shell that supports PATH configuration (zsh, bash)

No Node.js, Docker, or other tools are required to install the Compact CLI itself.

## Install via the Installer Script

Run the official installer to download pre-built binaries:

\`\`\`bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/midnightntwrk/compact/releases/latest/download/compact-installer.sh | sh
\`\`\`

The installer downloads the `compact` binary and places it in a local bin directory (typically `~/.local/bin/` or `~/.compact/bin/`). It also attempts to update the shell profile to add this directory to PATH.

## PATH Configuration

The installer script automatically modifies the shell profile (`~/.zshrc`, `~/.bashrc`, etc.) to add the Compact binary directory to PATH. However, the running shell session does not pick up these changes automatically.

### Reload the Shell

After installation, reload the shell configuration:

\`\`\`bash
# For zsh (default on macOS)
source ~/.zshrc

# For bash
source ~/.bashrc
\`\`\`

Alternatively, open a new terminal window.

### Manual PATH Configuration

If `compact` is still not found after reloading, add the binary directory to PATH manually. Check the installer output for the exact path, then add to the shell profile:

\`\`\`bash
# Add to ~/.zshrc or ~/.bashrc
export PATH="$HOME/.compact/bin:$PATH"
\`\`\`

Then reload the shell configuration.

### Verify PATH

Confirm the binary is accessible:

\`\`\`bash
which compact
# Expected output: /Users/<username>/.local/bin/compact
# or: /Users/<username>/.compact/bin/compact
\`\`\`

## First-Time Setup: Download a Compiler

The CLI tool alone cannot compile contracts. After installing the CLI, download a compiler version:

\`\`\`bash
compact update
\`\`\`

This downloads the latest compiler version and sets it as the default.

## What Gets Installed

The installer places the `compact` binary in `~/.local/bin/` or `~/.compact/bin/`. When a compiler is downloaded via `compact update`, it creates:

\`\`\`
~/.compact/
├── bin/                    # Symlinks to the default compiler version
│   ├── compactc            # Shell wrapper → compactc.bin
│   ├── format-compact      # Formatter binary
│   └── fixup-compact       # Fixup binary
└── versions/
    └── 0.30.0/
        └── aarch64-darwin/
            ├── compactc        # Shell wrapper
            ├── compactc.bin    # Actual compiler binary
            ├── format-compact
            ├── fixup-compact
            ├── zkir
            ├── zkir-v3
            ├── artifact.zip
            └── toolchain-0.30.0.md  # Release notes
\`\`\`

The `bin/` directory symlinks point to the current default version. Changing the default with `compact update <VERSION>` updates these symlinks.

## Verification

Run these commands to confirm everything is working:

\`\`\`bash
# Check CLI tool version
compact --version
# Example output: compact 0.5.1

# Check compiler version
compact compile --version
# Example output: 0.30.0

# Check installation path
which compact
# Example output: /Users/<username>/.local/bin/compact

# List installed compiler versions
compact list --installed
# Example output:
# compact: installed versions
# → 0.30.0
\`\`\`

The arrow (`→`) next to a version indicates it is the current default.

## Uninstalling

The Compact CLI does not provide an uninstall command. To remove it:

1. Delete the binary: `rm $(which compact)`
2. Delete the artifact directory: `rm -rf $HOME/.compact`
3. Remove the PATH entry from the shell profile (`~/.zshrc` or `~/.bashrc`)
4. Reload the shell: `source ~/.zshrc`

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `compact: command not found` | CLI not on PATH | Add `$HOME/.compact/bin` (or `$HOME/.local/bin`) to PATH, reload shell |
| `compact: command not found` after install | Shell session not reloaded | Run `source ~/.zshrc` (or `~/.bashrc`), or open a new terminal |
| `No default compiler set` after install | CLI installed but no compiler downloaded | Run `compact update` to download a compiler |
| `which compact` shows wrong path | Multiple installations | Check for duplicates in PATH, remove the unwanted one |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-tooling/skills/compact-cli/references/installation.md
git commit -m "docs(compact-cli): update installation.md with directory structure and troubleshooting"
```

---

### Task 3: Create compile-format-fixup.md

**Files:**
- Create: `plugins/midnight-tooling/skills/compact-cli/references/compile-format-fixup.md`

- [ ] **Step 1: Write compile-format-fixup.md**

Write this exact content to `plugins/midnight-tooling/skills/compact-cli/references/compile-format-fixup.md`:

```markdown
# Compiling, Formatting, and Fixup

## Compiling

### Basic Compilation

\`\`\`bash
compact compile <source-path> <target-directory>
\`\`\`

- `<source-path>`: Path to the `.compact` source file
- `<target-directory>`: Directory where output files are written (created if it doesn't exist)

### Compiler Output

With `--skip-zk`:

\`\`\`
<target-directory>/
├── compiler/
│   └── contract-info.json       # Compiler metadata
└── contract/
    ├── index.d.ts               # TypeScript type definitions
    ├── index.js                 # Generated JavaScript contract code
    └── index.js.map             # Source map
\`\`\`

Without `--skip-zk`, the output also includes ZKIR circuit files and proving keys. Proving key generation can be very slow — use `--skip-zk` during development and only generate keys for final builds or testing.

### Version-Specific Compilation

Prefix with `+VERSION` using **full semver** (partial versions are not accepted):

\`\`\`bash
# Works
compact compile +0.29.0 src/contract.compact build/

# Fails — partial version
compact compile +0.29 src/contract.compact build/
# Error: Invalid version format
\`\`\`

The specified version must already be installed. Install it with `compact update 0.29.0` first.

### Compiler Flags

These flags are passed through to the compiler binary:

| Flag | Purpose |
|------|---------|
| `--version` | Print compiler version |
| `--language-version` | Print language version |
| `--ledger-version` | Print target ledger version |
| `--runtime-version` | Print required Compact runtime JS package version |
| `--skip-zk` | Skip proving key generation (faster development builds) |
| `--no-communications-commitment` | Omit contract communications commitment |
| `--sourceRoot <path>` | Override sourceRoot in generated source maps |
| `--compact-path <search-list>` | Set import search path (colon-separated; semicolon on Windows) |
| `--trace-search` | Print where the compiler looks for included/imported files |
| `--vscode` | Format errors as single lines for VS Code extension |
| `--trace-passes` | Print compiler tracing (for compiler developers) |

### Import Search Paths

For multi-file contracts with includes or imports, the compiler searches:
1. Relative to the directory of the including/importing file
2. Each directory in the compact path, left to right

Set the compact path via:
- `--compact-path <dir1>:<dir2>` flag on the compile command
- `COMPACT_PATH` environment variable (used when `--compact-path` is not set)

## Formatting

### Basic Usage

\`\`\`bash
compact format              # All .compact files in current directory (recursive)
compact format src/         # All .compact files in src/ (recursive)
compact format file.compact # Specific file
\`\`\`

When scanning directories, `compact format` respects `.gitignore` rules — ignored files are skipped.

### Check Mode

\`\`\`bash
compact format --check
\`\`\`

Exits `0` if all files are formatted. Exits `1` with "Error: formatting failed" and a diff if any file needs formatting. Despite the error message, this is normal `--check` behavior — it means formatting changes are needed, not that the tool is broken.

### Verbose Mode

\`\`\`bash
compact format --verbose
# file.compact: unchanged
# other.compact: formatted
\`\`\`

### CI Integration

\`\`\`yaml
# GitHub Actions
- name: Check Compact formatting
  run: compact format --check
\`\`\`

Note: exit code `1` from `--check` means "files need formatting" — treat this as a failing check, not an error.

## Fixup

The `compact fixup` command applies source-level transformations to Compact files, such as renaming deprecated identifiers across language versions (e.g. `NativePoint` → `JubjubPoint`).

### Basic Usage

\`\`\`bash
compact fixup              # All .compact files in current directory (recursive)
compact fixup file.compact # Specific file
\`\`\`

Like `format`, directory scanning respects `.gitignore`.

### Check Mode

\`\`\`bash
compact fixup --check
\`\`\`

Same behavior as `format --check` — exits `0` if no changes needed, `1` with a diff if fixups are required.

### Flags

| Flag | Purpose |
|------|---------|
| `--check` / `-c` | Check without changing files |
| `--update-Uint-ranges` | Adjust Uint range endpoints |
| `--vscode` | Format errors as single lines for VS Code |
| `--verbose` / `-v` | Print each file processed |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `parse error: found "X" looking for Y` | Syntax error in source | Fix the source code at the indicated line/column |
| `parse error: found keyword "X" (which is reserved for future use)` | Using a reserved keyword as identifier | Rename the identifier |
| `expected right-hand side of = to have type X but received Y` | Type mismatch in assignment | Cast or adjust the expression to match the expected type |
| `potential witness-value disclosure must be declared` | Undeclared witness disclosure | Add the required disclosure declaration to the circuit |
| `language version X mismatch` | Compiler version doesn't match `pragma language_version` in source | Use the right compiler version (`compact compile +VERSION`) or update the pragma |
| `Error: Failed to run compactc` / `No default compiler set` | No compiler installed | Run `compact update` |
| `Couldn't find compiler for <arch> (<version>)` | Requested version not installed | Run `compact update <VERSION>` first |
| `Invalid version format` | Partial version used with `+VERSION` | Use full semver: `+0.29.0` not `+0.29` |
| `formatting failed` / `fixup failed` | Source has parse errors, OR `--check` detected changes needed | If using `--check`, this is expected — changes are needed. Otherwise, fix parse errors in source |
| Compilation very slow | ZK proving key generation | Use `--skip-zk` during development |
| Non-.compact file passed to format/fixup | Format/fixup only process `.compact` files | Only pass `.compact` files or directories containing them |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-tooling/skills/compact-cli/references/compile-format-fixup.md
git commit -m "docs(compact-cli): add compile-format-fixup.md reference"
```

---

### Task 4: Create version-management.md

**Files:**
- Create: `plugins/midnight-tooling/skills/compact-cli/references/version-management.md`

- [ ] **Step 1: Write version-management.md**

Write this exact content to `plugins/midnight-tooling/skills/compact-cli/references/version-management.md`:

```markdown
# Compiler Version Management

The Compact CLI supports multiple compiler versions installed side-by-side. One version is the "default" used when `compact compile` is invoked without a `+VERSION` specifier.

## Installing Compiler Versions

### Update to Latest

\`\`\`bash
compact update
\`\`\`

Downloads the latest compiler version and sets it as default. If already installed, no download occurs.

Example output:
\`\`\`
compact: aarch64-darwin -- 0.30.0 -- already installed
\`\`\`

### Install a Specific Version

The `update` command accepts three version formats:

| Format | Example | Matches |
|--------|---------|---------|
| Full semver | `compact update 0.29.0` | Exact version |
| Major.minor | `compact update 0.29` | Latest patch of 0.29.x |
| Major only | `compact update 0` | Latest minor.patch of 0.x.x |

By default, `update` sets the newly installed version as the default.

### Install Without Setting Default

\`\`\`bash
compact update 0.29.0 --no-set-default
\`\`\`

Downloads the version but keeps the current default. Useful for installing a version to test with `compact compile +0.29.0` without disrupting your main workflow.

## Listing Versions

### Available Versions (Remote)

\`\`\`bash
compact list
\`\`\`

Example output:
\`\`\`
compact: available versions

→ 0.30.0 - x86_macos, aarch64_macos, x86_linux, aarch64_linux
  0.29.0 - x86_macos, aarch64_macos, x86_linux, aarch64_linux
  0.28.0 - x86_macos, aarch64_macos, x86_linux
\`\`\`

The arrow (`→`) indicates the current default. Each version lists available platform builds.

### Installed Versions (Local)

\`\`\`bash
compact list --installed
\`\`\`

Example output:
\`\`\`
compact: installed versions

→ 0.30.0
  0.29.0
  0.28.0
\`\`\`

## Checking for Updates

\`\`\`bash
compact check
\`\`\`

Queries the remote server and reports whether a newer compiler version is available. Does not download anything.

Example output:
\`\`\`
compact: aarch64-darwin -- Up to date -- 0.30.0
\`\`\`

## Cleaning Up

### Remove All Versions

\`\`\`bash
compact clean
\`\`\`

Removes all installed compiler versions. After this, `compact compile` will fail until a version is reinstalled.

### Keep Current Default

\`\`\`bash
compact clean --keep-current
\`\`\`

Removes all versions except the current default.

### Clear the API Cache

\`\`\`bash
compact clean --cache
\`\`\`

Removes the GitHub API response cache (`github_cache.json`). The cache has a 15-minute TTL and is used by `list`, `check`, and `update` to avoid redundant API calls. Clear it if you suspect stale results after a new release.

## Common Workflows

### Switch Between Compiler Versions

\`\`\`bash
# Install both versions
compact update 0.30.0
compact update 0.29.0

# Now 0.29.0 is default (most recently updated)
# Compile with default
compact compile src/contract.compact build/

# Compile with a specific version without changing default
compact compile +0.30.0 src/contract.compact build/

# Switch default back
compact update 0.30.0
\`\`\`

### Pin a Project to a Specific Version

\`\`\`bash
# Install into project-local directory
compact --directory ./.compact update 0.29.0

# Set COMPACT_DIRECTORY so all commands use it
export COMPACT_DIRECTORY=./.compact

# Now compile uses the project-local version
compact compile src/contract.compact build/
\`\`\`

### Audit and Clean Up

\`\`\`bash
compact list --installed     # See what's installed
compact clean --keep-current # Remove old versions
compact list --installed     # Verify
\`\`\`

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Couldn't find version X` | Requested version doesn't exist remotely | Run `compact list` to see available versions |
| `compact list` shows stale results | 15-minute API cache | Run `compact clean --cache` then `compact list` |
| `compact update` hangs or times out | Network/proxy issue or GitHub API down | Check connectivity to github.com; try setting `GITHUB_TOKEN` |
| `compact list` shows versions but `compact update X` fails | Platform not available for that version | Check the platform list in `compact list` output |
| Version installed but not used | Default not changed | Run `compact update <VERSION>` to set default, or use `+VERSION` |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-tooling/skills/compact-cli/references/version-management.md
git commit -m "docs(compact-cli): add version-management.md reference"
```

---

### Task 5: Create self-management.md

**Files:**
- Create: `plugins/midnight-tooling/skills/compact-cli/references/self-management.md`

- [ ] **Step 1: Write self-management.md**

Write this exact content to `plugins/midnight-tooling/skills/compact-cli/references/self-management.md`:

```markdown
# CLI Self-Management

The `compact self` subcommand manages the CLI binary itself — independent of the compiler versions it manages.

## Check for CLI Updates

\`\`\`bash
compact self check
\`\`\`

Reports whether a newer version of the CLI tool is available. Does not download anything.

Example output:
\`\`\`
compact: compact -- 0.5.1 -- Up to date
\`\`\`

## Update the CLI Tool

\`\`\`bash
compact self update
\`\`\`

Downloads and replaces the `compact` binary with the latest version. Does not affect installed compiler versions.

After updating, verify:
\`\`\`bash
compact --version
# compact 0.5.1
\`\`\`

## Recommended Update Order

When updating both the CLI and compiler:

1. `compact self update` — update the CLI tool first
2. `compact --version` — verify CLI update
3. `compact update` — download latest compiler
4. `compact compile --version` — verify compiler update

Updating the CLI first ensures the latest download and version management logic is used when fetching the compiler.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `compact self update` fails with network error | Cannot reach GitHub releases | Check connectivity; try setting `GITHUB_TOKEN` env var |
| Version unchanged after `compact self update` | Already on latest | Expected — no action needed |
| `compact self check` reports update but `compact self update` fails | Permissions on the binary | Check write permissions on the `compact` binary path (`which compact`) |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-tooling/skills/compact-cli/references/self-management.md
git commit -m "docs(compact-cli): add self-management.md reference"
```

---

### Task 6: Create troubleshooting.md

**Files:**
- Create: `plugins/midnight-tooling/skills/compact-cli/references/troubleshooting.md`

- [ ] **Step 1: Write troubleshooting.md**

Write this exact content to `plugins/midnight-tooling/skills/compact-cli/references/troubleshooting.md`:

```markdown
# Troubleshooting

## Exit Codes

| Code | Meaning | Source |
|------|---------|--------|
| `0` | Success | CLI or compiler |
| `1` | CLI error (missing compiler, failed operation) | CLI |
| `2` | Usage error (unknown subcommand, invalid flag) | CLI (clap) |
| `255` | Compiler error (parse error, type error, semantic error) | Compiler |

## Error Messages by Category

### Installation and PATH

| Error | Cause | Fix |
|-------|-------|-----|
| `compact: command not found` | CLI binary not on PATH | Add `$HOME/.compact/bin` (or `$HOME/.local/bin`) to PATH, reload shell |
| `compact: command not found` after install | Shell session not reloaded | Run `source ~/.zshrc` (or `~/.bashrc`), or open a new terminal |
| `which compact` shows unexpected path | Multiple installations | Remove the unwanted binary, check PATH order |

### Compiler Not Found

| Error | Cause | Fix |
|-------|-------|-----|
| `Error: Failed to run compactc` / `No default compiler set` | No compiler installed, or custom `--directory` with no compiler | Run `compact update` (with `--directory` if applicable) |
| `Couldn't find compiler for <arch> (<version>)` / `Directory does not exist` | Requested version not installed for this platform | Run `compact update <VERSION>` to install it |
| `Binary file not found` | Corrupt or incomplete installation | Run `compact clean` then `compact update` to reinstall |

### Version Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Invalid version format` | Partial version used with `+VERSION` syntax | Use full semver: `+0.29.0` not `+0.29` |
| `Couldn't find version X` | Version doesn't exist remotely | Run `compact list` to see available versions |
| `language version X mismatch` | Compiler version doesn't match the `pragma language_version` in source | Use the correct compiler version (`compact compile +VERSION`) or update the pragma |

### Compilation Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `parse error: found "X" looking for Y` | Syntax error in source | Fix the source at the indicated line and column |
| `parse error: found keyword "X" (which is reserved for future use)` | Identifier uses a reserved keyword | Rename the identifier |
| `expected right-hand side of = to have type X but received Y` | Type mismatch | Cast or adjust the expression to match the expected type |
| `potential witness-value disclosure must be declared` | Circuit discloses a witness value to the ledger without declaring it | Add the required disclosure declaration |
| `unbound identifier X` | Undefined type or variable | Check spelling; may be a renamed identifier across compiler versions (e.g. `NativePoint` → `JubjubPoint`) |
| `error opening source file: failed for X: no such file or directory` | Source file doesn't exist | Check the file path |
| `compiler toolchain was terminated by a signal` | Compiler crashed (OOM, segfault) | Check system memory; try `--skip-zk` to reduce memory usage; report the bug |
| Compilation very slow | ZK proving key generation | Use `--skip-zk` during development |

### Formatting and Fixup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `Error: formatting failed` with diff output | `--check` detected files that need formatting | Expected behavior — run `compact format` to fix, or this is your CI check working |
| `Error: formatting failed` without diff | Source file has parse errors, or non-`.compact` file passed | Fix parse errors in source; only pass `.compact` files |
| `Error: fixup failed` | Source has parse errors, or fixup could not process the file | Fix parse errors first, then re-run fixup |

### Network and GitHub API

| Error | Cause | Fix |
|-------|-------|-----|
| `Error while fetching compact releases` | Cannot reach GitHub API | Check internet connectivity; check proxy settings |
| `compact update` / `compact list` hangs | Network timeout, firewall blocking github.com | Check connectivity; try `curl -I https://api.github.com` |
| `Using cached data due to GitHub rate limit` | Unauthenticated API rate limit (60 req/hr) exceeded | Set `GITHUB_TOKEN` env var: `export GITHUB_TOKEN=$(gh auth token)` |
| Stale results from `compact list` | 15-minute API response cache | Run `compact clean --cache` to clear, then retry |
| `artifact Extraction failed` | Downloaded zip is corrupt or `unzip` not available | Ensure `unzip` is installed; retry the download |

### Unknown Subcommand

| Error | Cause | Fix |
|-------|-------|-----|
| `error: unrecognized subcommand 'X'` | Typo or invalid command | Check spelling; run `compact --help` for valid commands. Note: partial prefixes work (e.g. `compact comp` = `compact compile`) |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-tooling/skills/compact-cli/references/troubleshooting.md
git commit -m "docs(compact-cli): add troubleshooting.md error catalog"
```

---

### Task 7: Delete old reference files

**Files:**
- Delete: `plugins/midnight-tooling/skills/compact-cli/references/compile-and-format.md`
- Delete: `plugins/midnight-tooling/skills/compact-cli/references/check-and-self.md`
- Delete: `plugins/midnight-tooling/skills/compact-cli/references/update-list-clean.md`
- Delete: `plugins/midnight-tooling/skills/compact-cli/references/custom-directories.md`

- [ ] **Step 1: Delete the old reference files**

```bash
git rm plugins/midnight-tooling/skills/compact-cli/references/compile-and-format.md
git rm plugins/midnight-tooling/skills/compact-cli/references/check-and-self.md
git rm plugins/midnight-tooling/skills/compact-cli/references/update-list-clean.md
git rm plugins/midnight-tooling/skills/compact-cli/references/custom-directories.md
```

- [ ] **Step 2: Verify only the new files remain**

Run: `ls plugins/midnight-tooling/skills/compact-cli/references/`
Expected:
```
compile-format-fixup.md
installation.md
self-management.md
troubleshooting.md
version-management.md
```

- [ ] **Step 3: Commit**

```bash
git commit -m "docs(compact-cli): remove old reference files replaced by workflow-oriented structure"
```

---

### Task 8: Final verification

- [ ] **Step 1: Verify SKILL.md frontmatter parses correctly**

Run: `head -15 plugins/midnight-tooling/skills/compact-cli/SKILL.md`
Expected: Valid YAML frontmatter between `---` markers with `name: compact-cli` and a `description:` field

- [ ] **Step 2: Verify all reference files referenced in SKILL.md exist**

Run: `for f in installation.md compile-format-fixup.md version-management.md self-management.md troubleshooting.md; do test -f "plugins/midnight-tooling/skills/compact-cli/references/$f" && echo "OK: $f" || echo "MISSING: $f"; done`
Expected: All five files report `OK`

- [ ] **Step 3: Verify no old reference files remain**

Run: `ls plugins/midnight-tooling/skills/compact-cli/references/ | wc -l`
Expected: `5`

- [ ] **Step 4: Verify git status is clean**

Run: `git status plugins/midnight-tooling/skills/compact-cli/`
Expected: Nothing to commit, working tree clean
