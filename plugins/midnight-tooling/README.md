# midnight-tooling

Installation, configuration, and management of Midnight Network development tools.

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code/plugins) that provides skills, commands, and a status bar integration for working with the Compact CLI, local devnet (node, indexer, proof server), compiler versions, and release notes. For wallet management and account funding, see the `midnight-wallet` plugin.

## Features

- Install and manage the Compact CLI and compiler versions
- Start, stop, and monitor the local devnet (node, indexer, proof server)
- Run diagnostics on your entire Midnight toolchain
- View release notes for any Midnight component
- Troubleshoot common development environment issues
- Status bar showing proof server and compiler status

## Prerequisites

- Unix-like environment (macOS, Linux, WSL)
- `curl` for installation and health checks
- `jq` recommended for JSON parsing (falls back to grep/sed)
- `docker` for the local devnet and standalone proof server

## Installation

Install via the Claude Code plugin marketplace:

```
/install-plugin midnight-tooling
```

Or add the plugin manually by cloning it into your Claude Code plugins directory.

## Commands

### `/midnight-tooling:doctor`

Comprehensive diagnostic for the Compact CLI installation and local devnet. Checks the CLI binary, compiler versions, PATH configuration, update availability, devnet services (node, indexer, proof server), and custom directory setup. Presents a health report with severity indicators and offers to fix issues.

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

### `/midnight-tooling:devnet`

Manage the local Midnight development network (node, indexer, proof server). Delegates to the `@aaronbassett/midnight-local-devnet` MCP server. For wallet management and account funding, use the `midnight-wallet` plugin.

```
/midnight-tooling:devnet start
/midnight-tooling:devnet stop
/midnight-tooling:devnet status
/midnight-tooling:devnet health
/midnight-tooling:devnet logs --service node
/midnight-tooling:devnet config
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

### devnet

Covers the local development network lifecycle — starting, stopping, restarting, checking status and health, viewing logs, and getting endpoint configuration for all 3 services (node, indexer, proof server).

**Triggers on**: starting/stopping the devnet, local network, node/indexer/proof server containers, port 9944/8088/6300 issues, network health

### proof-server

Covers working with proof servers in general — local (via devnet) and remote (testnet/mainnet). Includes API endpoints, version selection, Docker setup for standalone instances, and looking up environment endpoints.

**Triggers on**: proof server health, proof server version, proof server API endpoints, standalone proof server Docker setup

### troubleshooting

Systematic diagnosis and resolution of common issues with Midnight Network tools including `ERR_UNSUPPORTED_DIR_IMPORT`, version mismatches, NixOS/Windows/Bun setup, environment URLs, proof server connectivity, and devnet issues.

**Triggers on**: errors, installation failures, version mismatches, unexpected behavior with Midnight tools, devnet not starting, MCP server connectivity

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
