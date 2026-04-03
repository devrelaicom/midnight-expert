# midnight-tooling

Installs, configures, and manages the Midnight Network development toolchain -- Compact CLI, compiler version switching, local devnet (node, indexer, proof server), diagnostics, and release notes for all Midnight components.

## Skills

### midnight-tooling:compact-cli

Manages the Compact CLI tool for Midnight Network smart contract development, including installation, compiler version switching, code formatting and fixup, custom directory configuration, and troubleshooting CLI errors.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| installation.md | Prerequisites and steps for installing the Compact CLI | Setting up the Compact toolchain on a new machine |
| version-management.md | Installing, listing, switching, and pinning compiler versions | Managing multiple compiler versions side-by-side |
| self-management.md | CLI binary self-update and management commands | Checking for and applying CLI updates |
| compile-format-fixup.md | Compiling contracts, formatting code, and running fixup transformations | Building contracts or formatting Compact source files |
| troubleshooting.md | Exit codes, common errors, and resolution steps for the CLI | Diagnosing CLI failures or unexpected compiler behavior |

### midnight-tooling:devnet

Covers the local 3-service development network (node, indexer, proof server) lifecycle -- generating compose files, starting, stopping, restarting, checking status and health, viewing logs, and getting endpoint configuration.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| compose-structure.md | Anatomy of every field in the generated devnet.yml file | Understanding or debugging the Docker Compose configuration |
| docker-setup.md | Docker Desktop installation and resource configuration for the devnet | Setting up Docker before first devnet start |
| network-lifecycle.md | Generating, starting, stopping, and monitoring the devnet via Docker Compose | Managing the devnet through its full lifecycle |
| version-resolution.md | How Docker image versions are resolved and checked for compatibility | Resolving version conflicts or selecting specific component versions |

### midnight-tooling:proof-server

Covers working with the Midnight proof server in any context -- local development via devnet, standalone Docker instances, and remote servers on testnet/mainnet. Includes API endpoints, version selection, and environment endpoint lookup.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| docker-setup.md | Docker prerequisites for running the proof server | Setting up Docker for standalone proof server usage (delegates to devnet docker-setup) |

### midnight-tooling:release-notes

View and search release notes for all Midnight Network components from the official documentation repository. Covers component discovery, version listing, and batch retrieval via octocode MCP tools.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| component-map.md | Maps component names and aliases to their release notes paths | Resolving user-provided component names to the correct release notes files |

### midnight-tooling:troubleshooting

Systematic diagnosis and resolution of common issues with Midnight Network tools, including Node.js import errors, Compact CLI problems, proof server and Docker failures, devnet startup issues, and platform-specific setup.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| bun-setup.md | Configuring the Bun runtime for Midnight development | Setting up Bun as an alternative runtime |
| checking-release-notes.md | Using release notes to identify known bugs and fixes | Checking if a problem is a known issue fixed in a newer version |
| compact-cli-issues.md | Resolving Compact CLI installation and execution problems | Troubleshooting `compact: command not found` or CLI failures |
| devnet-issues.md | Diagnosing devnet startup, indexer sync, and MCP connectivity issues | Fixing local network startup failures or service connectivity |
| environment-tooling.md | Resolving direnv, mise, dotenv-cli, and COMPACT_DIRECTORY misconfiguration | Fixing environment variable and tooling configuration problems |
| environment-urls.md | Fixing incorrect endpoint URLs or wrong network environment connections | Resolving connection failures caused by wrong URLs |
| err-unsupported-dir-import.md | Resolving the Node.js ERR_UNSUPPORTED_DIR_IMPORT error | Fixing ESM import errors in Midnight projects |
| nixos-installation.md | Resolving installation issues on NixOS | Installing Midnight tools on NixOS |
| proof-server-issues.md | Diagnosing proof server connectivity and runtime problems | Fixing proof server failures in devnet or standalone contexts |
| searching-issues.md | Searching open GitHub issues in the midnightntwrk organization | Finding known problems, workarounds, and ongoing discussions |
| version-mismatch.md | Diagnosing and resolving version incompatibilities across components | Fixing errors caused by mismatched component versions |
| windows-setup.md | Resolving Windows-specific setup issues via WSL | Setting up Midnight development on Windows |

## Commands

### midnight-tooling:devnet

Manage a local Midnight devnet -- generate compose files, start/stop the network, check status and health, view logs and configuration.

#### Output

A status report of the requested devnet operation (e.g., services started, health check results, log output, or current configuration).

#### Invokes

- midnight-tooling:devnet (skill)
- midnight-tooling:troubleshooting (skill, on error)

### midnight-tooling:doctor

Comprehensive diagnostic and health report for the Compact CLI installation, compiler versions, PATH configuration, custom directory setup, proof server status, and plugin dependencies.

#### Output

A formatted health report with severity indicators (pass, warn, critical, info) for each diagnostic check, with optional auto-fix for detected issues.

#### Invokes

- midnight-plugin-utils:find-claude-plugin-root (skill)

### midnight-tooling:install-cli

Install, update, or configure the Compact CLI tool. Supports global installation and per-project configuration with automatic environment setup.

#### Output

Confirmation of CLI installation or update, with version information and any environment configuration changes applied.

### midnight-tooling:install-statusline-script

Install, update, or uninstall the Midnight statusline script that displays proof server and Compact CLI status in the Claude Code status bar.

#### Output

Confirmation of statusline script installation, update, or removal, including the selected theme and style.

### midnight-tooling:view-release-notes

View Midnight component release notes from the official documentation repository.

#### Output

Formatted release notes for the requested component and version range, fetched from the midnightntwrk/midnight-docs repository.

#### Invokes

- midnight-tooling:release-notes (skill)
