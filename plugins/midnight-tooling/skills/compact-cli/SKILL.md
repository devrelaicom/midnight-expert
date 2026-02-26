---
name: compact-cli
description: This skill should be used when the user asks about the Compact CLI tool for Midnight Network development, including installing or uninstalling compact, resolving "compact: command not found" errors, managing compiler versions with compact update/list/clean, formatting source files with compact format, checking for updates with compact check or compact self update, switching compiler versions, using --skip-zk for fast compilation, setting up per-project toolchain directories with COMPACT_DIRECTORY or direnv/mise, or understanding the difference between the Compact CLI and the Compact compiler
---

# Compact CLI Management

The Compact CLI (`compact`) is the command-line tool for managing the Midnight Network's smart contract development toolchain. It handles compiler version management, code formatting, and compiler invocation.

## **Terminology — Read This First**

> **Three distinct things share the "Compact" name. Always be precise about which is being referenced.**

| Term | What It Is | Binary / Location | Version Command |
|------|-----------|-------------------|-----------------|
| **Compact CLI** | The command-line management tool | `compact` (typically `~/.local/bin/compact`) | `compact --version` |
| **Compact** (language) | The smart contract programming language | Source files: `*.compact` | N/A |
| **Compact compiler** | The compiler that transforms Compact source into ZK circuits and TypeScript | `compactc.bin` (managed by CLI, stored in `$COMPACT_DIRECTORY`) | `compact compile --version` |

**Relationship**: The Compact CLI manages and invokes the Compact compiler, which compiles Compact (the language) source files. The CLI is the orchestrator; the compiler is the worker it manages.

When users say "install Compact", they typically mean installing the Compact CLI (which then manages the compiler). When they say "update Compact", determine whether they mean:
- **The CLI tool itself** → `compact self update`
- **The compiler** → `compact update`

These are independent operations. The CLI and compiler have separate version numbers.

## Quick Command Reference

| Command | Purpose |
|---------|---------|
| `compact --version` | Show CLI tool version |
| `compact compile --version` | Show default compiler version |
| `compact compile <source> <target-dir>` | Compile a Compact source file |
| `compact compile +<VER> <source> <target-dir>` | Compile with a specific compiler version |
| `compact format [FILES]` | Format Compact source files |
| `compact format --check [FILES]` | Check formatting without changes |
| `compact update` | Download latest compiler, set as default |
| `compact update <VERSION>` | Install a specific compiler version |
| `compact list` | List all available compiler versions (remote) |
| `compact list --installed` | List locally installed compiler versions |
| `compact check` | Check for compiler updates without downloading |
| `compact clean` | Remove all installed compiler versions |
| `compact clean --keep-current` | Remove all except current default version |
| `compact self check` | Check for CLI tool updates |
| `compact self update` | Update the CLI tool itself |

Every command accepts `--directory <DIR>` to use a custom artifact directory instead of the default `$HOME/.compact`. This can also be set via the `COMPACT_DIRECTORY` environment variable.

## Formatting

The `compact format` command formats `.compact` source files in place. When no files are specified, `compact format` recursively formats all `.compact` files in the current directory. Use `--check` for CI pipelines (exits non-zero if changes needed). See `references/compile-and-format.md` for full flag details, CI integration, and pre-commit hook examples.

## Compiling

The CLI invokes the compiler via `compact compile <source> <target-dir>`. Prefix with `+VERSION` to use a specific compiler version. The `--directory` flag must appear before `compile`, not after. See `references/compile-and-format.md` for all compiler flags and compilation patterns.

## Custom Artifact Directories

All commands accept `--directory <DIR>` to override the default artifact location (`$HOME/.compact`). Set the `COMPACT_DIRECTORY` environment variable to make this permanent. See `references/custom-directories.md` for configuring per-project directories using direnv, mise, dotenv-cli, or Claude Code settings.

## Two Things to Update

A common source of confusion: the CLI tool and the compiler update independently.

| What to Update | Command | What Changes |
|---------------|---------|-------------|
| The compiler | `compact update` | Downloads a new compiler version, sets it as default |
| The CLI tool | `compact self update` | Updates the `compact` binary itself |

Run `compact check` to see if a new compiler version is available. Run `compact self check` to see if a new CLI tool version is available.

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| `compact: command not found` | CLI not on PATH | Add `$HOME/.compact/bin` to PATH, reload shell |
| `compact compile` fails silently | No compiler installed | Run `compact update` to download a compiler |
| Wrong compiler version | Default not set | Run `compact update <VERSION>` to set default |
| Stale compiler | Not updated | Run `compact check` then `compact update` |
| Compilation very slow | ZK proof generation | Use `--skip-zk` during development |

## Reference Files

Consult these for detailed procedures:

| Reference | Content | When to Read |
|-----------|---------|-------------|
| **`references/installation.md`** | Installing the CLI, PATH configuration, shell reload, first-time verification | First-time setup or new machine |
| **`references/compile-and-format.md`** | Full compile and format command details, flags, CI integration | Compiling contracts or formatting code |
| **`references/check-and-self.md`** | CLI health checks, self-update, checking for updates | Verifying or updating the CLI tool itself |
| **`references/update-list-clean.md`** | Compiler version management: install, list, switch, remove | Managing multiple compiler versions |
| **`references/custom-directories.md`** | Per-project toolchain directories, `COMPACT_DIRECTORY`, direnv, mise, dotenv-cli, Claude Code settings | Project-local configuration |
