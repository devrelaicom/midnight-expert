# midnight-tooling

Installation, configuration, and management of Midnight Network development tools.

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code/plugins) that provides skills, commands, and a status bar integration for working with the Compact CLI, the proof server, compiler versions, and release notes.

## Features

- Install and manage the Compact CLI and compiler versions
- Start, stop, and monitor the Docker-based proof server
- Run diagnostics on your entire Midnight toolchain
- View release notes for any Midnight component
- Troubleshoot common development environment issues
- Status bar showing proof server and compiler status

## Prerequisites

- Unix-like environment (macOS, Linux, WSL)
- `curl` for installation and proof server health checks
- `jq` recommended for JSON parsing (falls back to grep/sed)
- `docker` for the proof server and alternate port detection

## Installation

Install via the Claude Code plugin marketplace:

```
/install-plugin midnight-tooling
```

Or add the plugin manually by cloning it into your Claude Code plugins directory.

## Commands

### `/midnight-tooling:doctor`

Comprehensive diagnostic for the Compact CLI installation. Checks the CLI binary, compiler versions, PATH configuration, update availability, proof server status, and custom directory setup. Presents a health report with severity indicators and offers to fix issues.

```
/midnight-tooling:doctor
/midnight-tooling:doctor --auto-fix
```

### `/midnight-tooling:install-cli`

Install, update, or configure the Compact CLI tool. Supports global installation and per-project configuration with automatic environment setup (direnv, mise, dotenv-cli, Claude Code settings).

```
/midnight-tooling:install-cli
/midnight-tooling:install-cli install for this project
/midnight-tooling:install-cli update
```

### `/midnight-tooling:run-proof-server`

Start, restart, stop, or manage the Midnight proof server Docker container.

```
/midnight-tooling:run-proof-server
/midnight-tooling:run-proof-server --restart
/midnight-tooling:run-proof-server --stop
/midnight-tooling:run-proof-server --logs
```

### `/midnight-tooling:view-release-notes`

View release notes for any Midnight Network component, fetched from the official documentation repository.

```
/midnight-tooling:view-release-notes
/midnight-tooling:view-release-notes compact
/midnight-tooling:view-release-notes ledger --version 1.x
```

### `/midnight-tooling:install-statusline-script`

Install the Midnight statusline script, which displays proof server and Compact CLI status in the Claude Code status bar. Chains with any existing statusLine configuration rather than replacing it.

```
/midnight-tooling:install-statusline-script
/midnight-tooling:install-statusline-script --update
/midnight-tooling:install-statusline-script --uninstall
/midnight-tooling:install-statusline-script --theme tokyo --style capsule
```

## Skills

### compact-cli

Manages the Compact CLI tool for Midnight Network development. Covers installation, compiler version management, code formatting, custom directory configuration, and troubleshooting.

**Triggers on**: installing Compact, updating compiler versions, formatting Compact files, configuring `COMPACT_DIRECTORY`, resolving `compact: command not found`

### proof-server

Manages the Midnight proof server lifecycle. Covers starting, stopping, restarting, checking logs, verifying health on port 6300, and Docker container setup.

**Triggers on**: starting/stopping the proof server, proof server not working, checking proof server logs, Docker container for proofs, port 6300 issues

### troubleshooting

Systematic diagnosis and resolution of common issues with Midnight Network tools including `ERR_UNSUPPORTED_DIR_IMPORT`, version mismatches, NixOS/Windows/Bun setup, environment URLs, and proof server connectivity.

**Triggers on**: errors, installation failures, version mismatches, unexpected behavior with Midnight tools

### release-notes

View and search release notes for all Midnight Network components from the official documentation repository.

**Triggers on**: what changed in a version, latest release, changelog, component update details

## StatusLine

The plugin includes a status bar integration that shows Midnight Network project status directly in Claude Code. It activates automatically for Midnight projects (detected by `.compact` files, `@midnight-ntwrk` packages, a `.compact/` directory, or Docker files referencing `midnightntwrk` images).

The statusline composes with any existing statusLine configuration -- it chains the original command and appends Midnight-specific segments after it.

### Segments

- **Brand**: `Midnight` -- always shown for Midnight projects
- **Proof server**: `Proof: ready` / `Proof: busy (3/5)` / `Proof: off` -- checks `localhost:6300` with Docker fallback for alternate ports
- **Compact CLI**: `compactc v0.29.0` / `compactc v0.29.0 ->` -- shows compiler version and update indicator

### Themes

Set via `MIDNIGHT_TOOLING_STATUSLINE_THEME` environment variable. Default: `marrakech`.

| Theme | Description |
|-------|-------------|
| `dark` | Deep blues and purples |
| `light` | Light backgrounds, vivid accents |
| `neutral` | Balanced greys with color accents |
| `tokyo` | Tokyo Night inspired palette |
| `miami` | Neon pinks and cyans |
| `marrakech` | Warm earth tones (default) |
| `reykjavik` | Cool Nordic blues |
| `cartagena` | Rich purples and warm oranges |
| `berlin` | Industrial greys with muted accents |

### Styles

Set via `MIDNIGHT_TOOLING_STATUSLINE_STYLE` environment variable. Default: `powerline`.

| Style | Description |
|-------|-------------|
| `powerline` | Seamless flow with arrow separators (default) |
| `minimal` | Rectangular bracketed segments |
| `capsule` | Rounded pill-shaped segments |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `MIDNIGHT_TOOLING_STATUSLINE_THEME` | Override theme (case-insensitive) |
| `MIDNIGHT_TOOLING_STATUSLINE_STYLE` | Override style (case-insensitive) |
| `MIDNIGHT_TOOLING_STATUSLINE_ACTIVE` | Set to `1` to force statusline display (skip project detection) |

## License

[MIT](LICENSE)
