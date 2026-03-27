# Compact CLI Skill Rewrite — Design Spec

**Date:** 2026-03-27
**Scope:** `plugins/midnight-tooling/skills/compact-cli/`

## Summary

Rewrite the compact-cli skill to fix factual errors, add missing commands and features, restructure reference files around workflows, and add comprehensive troubleshooting. Based on hands-on CLI testing against v0.5.1 (CLI) / v0.30.0 (compiler) and source code analysis of `LFDT-Minokawa/compact`.

## Problems With Current Skill

1. **Factual error**: `--directory` ordering claim is wrong — the flag is `global = true` in clap, works in any position
2. **Missing command**: `fixup` not in SKILL.md command reference table
3. **Missing features**: `COMPACT_PATH` env var, `--trace-search`, `--ledger-version`, `--runtime-version`, `clean --cache`, command aliases, partial version specs in `update`, format respects `.gitignore`
4. **Incomplete version reporting**: 3 distinct version numbers (CLI, compiler, language) plus 2 more (ledger, runtime) — not explained
5. **No troubleshooting**: No reference file has error messages, exit codes, or common mistakes
6. **`custom-directories.md` bloat**: 60% is direnv/mise/dotenv-cli instructions — removed per user request
7. **Description too narrow**: Doesn't match "Compact Dev Tool", "Compact Developer CLI", "devtool", "compact toolchain"
8. **`format --check` confusion**: Exits 1 with "Error: formatting failed" even when working correctly
9. **Compile output structure undocumented**
10. **`+VERSION` requires full semver**: Not documented; `update` accepts partials but `+VERSION` does not

## Approach

Workflow-oriented rewrite (Approach C from brainstorming): restructure references by workflow, add troubleshooting to each reference file, and add a centralized error catalog.

## Deliverables

### Files to Create/Rewrite

| File | Action |
|------|--------|
| `SKILL.md` | Rewrite |
| `references/compile-format-fixup.md` | New (replaces `compile-and-format.md`) |
| `references/version-management.md` | New (replaces `update-list-clean.md`) |
| `references/self-management.md` | New (replaces `check-and-self.md`) |
| `references/troubleshooting.md` | New |
| `references/installation.md` | Update in place |

### Files to Delete

| File | Reason |
|------|--------|
| `references/compile-and-format.md` | Replaced by `compile-format-fixup.md` |
| `references/check-and-self.md` | Replaced by `self-management.md` |
| `references/update-list-clean.md` | Replaced by `version-management.md` |
| `references/custom-directories.md` | Content folded into SKILL.md Global Flags section |

---

## SKILL.md Design

### Frontmatter

```yaml
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
```

### Body Structure

1. **Terminology table** — same 3-way distinction (CLI tool / language / compiler), unchanged
2. **Version Reporting** (new) — documents the 3 main version numbers plus ledger and runtime versions, with commands and example output
3. **Quick Command Reference** — updated table with `fixup` added, aliases column, `+VERSION` notes full semver requirement
4. **Global Flags** (new) — `--directory` / `COMPACT_DIRECTORY` as a standalone section, correcting the false ordering claim
5. **Compiling** — brief summary pointing to `compile-format-fixup.md`
6. **Formatting and Fixup** — brief summary pointing to `compile-format-fixup.md`
7. **Version Management** — brief summary pointing to `version-management.md`
8. **CLI Self-Management** — brief summary pointing to `self-management.md`
9. **Reference Files** — index table

### Version Reporting Section

```markdown
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
```

### Quick Command Reference

```markdown
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
```

### Global Flags Section

```markdown
## Global Flags

Every command accepts these flags:

| Flag | Environment Variable | Purpose |
|------|---------------------|---------|
| `--directory <DIR>` | `COMPACT_DIRECTORY` | Use a custom artifact directory instead of `$HOME/.compact` |

The `--directory` flag can appear before or after the subcommand — both positions are equivalent. When both the flag and environment variable are set, the flag takes precedence. The directory is created automatically if it does not exist.
```

### Reference Files Index

```markdown
## Reference Files

| Reference | When to Read |
|-----------|-------------|
| **`references/installation.md`** | First-time setup, PATH issues, new machine |
| **`references/compile-format-fixup.md`** | Compiling contracts, formatting, fixup, compiler flags |
| **`references/version-management.md`** | Installing, switching, listing, or removing compiler versions |
| **`references/self-management.md`** | Updating the CLI tool, checking versions |
| **`references/troubleshooting.md`** | Error messages, exit codes, common failures |
```

---

## Reference File Designs

### `references/installation.md` (Update)

Changes from current:
- Update example version numbers to `0.5.1` (CLI) and `0.30.0` (compiler)
- Add "What Gets Installed" section documenting `~/.compact/` directory structure: `bin/` with symlinks to default version, `versions/<ver>/<arch>/` with `compactc` (shell wrapper), `compactc.bin` (actual binary), `format-compact`, `fixup-compact`, `zkir`, `zkir-v3`, `artifact.zip`, `toolchain-<ver>.md`
- Add troubleshooting table: `compact: command not found` (PATH), shell not reloaded, `No default compiler set` (no compiler), wrong `which compact` path

### `references/compile-format-fixup.md` (New)

Sections:
1. **Compiling** — basic compilation, compiler output structure (with/without `--skip-zk`), version-specific compilation (`+VERSION` full semver only), full compiler flags table (including `--ledger-version`, `--runtime-version`, `--compact-path`, `--trace-search`, `--vscode`, `--no-communications-commitment`, `--sourceRoot`), import search paths (`--compact-path` / `COMPACT_PATH`)
2. **Formatting** — basic usage, directory scanning respects `.gitignore`, check mode (exit 1 with "Error: formatting failed" is expected), verbose mode, CI integration
3. **Fixup** — purpose (source-level transformations for version migration), basic usage, check mode, flags (`--update-Uint-ranges`, `--vscode`, `--verbose`)
4. **Troubleshooting** — parse errors, type mismatches, disclosure errors, language version mismatch, missing compiler, invalid `+VERSION`, `formatting failed` / `fixup failed` meaning, slow compilation

### `references/version-management.md` (New)

Sections:
1. **Installing Compiler Versions** — `compact update` (latest), specific version with three version formats (full semver `0.29.0`, major.minor `0.29`, major only `0`), `--no-set-default`, example output
2. **Listing Versions** — `compact list` (remote, with platform info and `→` marker), `compact list --installed` (local)
3. **Checking for Updates** — `compact check` with example output
4. **Cleaning Up** — `compact clean`, `--keep-current`, `--cache` (removes GitHub API cache, 15-minute TTL)
5. **Common Workflows** — switching versions, pinning a project, audit and clean up
6. **Troubleshooting** — version not found, stale cache, network/proxy issues, platform not available

### `references/self-management.md` (New)

Sections:
1. **Check for CLI Updates** — `compact self check` with example output
2. **Update the CLI Tool** — `compact self update`, post-update verification
3. **Recommended Update Order** — CLI first, then compiler (ensures latest download logic)
4. **Troubleshooting** — network errors, permissions, already on latest

### `references/troubleshooting.md` (New)

Centralized error catalog organized by category:

1. **Exit Codes** — table: 0 (success), 1 (CLI error), 2 (usage error), 255 (compiler error)
2. **Installation and PATH** — `command not found`, shell not reloaded, wrong binary path
3. **Compiler Not Found** — `No default compiler set`, version not installed, corrupt installation
4. **Version Errors** — `Invalid version format` (+VERSION), version not found remotely, language version mismatch
5. **Compilation Errors** — parse errors, reserved keywords, type mismatches, disclosure errors, unbound identifiers, missing source file, compiler crash/signal, slow compilation
6. **Formatting and Fixup Errors** — `formatting failed` meaning (check mode vs real error), `fixup failed`, non-.compact files
7. **Network and GitHub API** — `Error while fetching compact releases`, hangs/timeouts, rate limiting (`GITHUB_TOKEN` fix), stale cache (15-min TTL, `clean --cache`), `artifact Extraction failed`
8. **Unknown Subcommand** — typo suggestions, partial prefix matching note
