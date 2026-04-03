<p align="center">
  <img src="assets/banner.png" alt="midnight expert" width="100%" />
</p>

AI-powered development tools for the [Midnight](https://midnight.network/) blockchain — a suite of [Claude Code plugins](https://docs.anthropic.com/en/docs/claude-code/plugins) that help you write, test, deploy, and review smart contracts in the Compact language.

**[midnightntwrk.expert](https://midnightntwrk.expert/)** — documentation, guides, and resources for Midnight developers.

## Install

```bash
curl -fsSL midnightntwrk.expert/me-install.sh | bash
```

Once installed, skills activate automatically based on what you're working on. Ask Claude to write a Compact contract, review existing code, set up a devnet, or explain a privacy pattern — the relevant skills engage on their own.

## Plugins

This repository contains 16 plugins organized by domain.

### Smart Contract Development

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/compact-core/assets/mascot.png" width="60" /> | **compact-core** | Compact language reference, patterns, privacy/disclosure, witnesses, tokens, circuit costs, debugging, and code review |
| <img src="plugins/compact-examples/assets/mascot.png" width="60" /> | **compact-examples** | OpenZeppelin-style reference implementations (access control, tokens, pausable, etc.) |
| <img src="plugins/compact-cli-dev/assets/mascot.png" width="60" /> | **compact-cli-dev** | Scaffold Oclif CLIs for Compact contracts with wallet management, deployment, and devnet control |

### DApp Development

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-dapp-dev/assets/mascot.png" width="60" /> | **midnight-dapp-dev** | Vite + React 19 DApp scaffolding, SDK reference, DApp Connector API, provider assembly, state management |

### Testing & Code Quality

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-cq/assets/mascot.png" width="60" /> | **midnight-cq** | Testing skills (contract simulator, DApp integration, DApp Connector, ledger, wallet) and code quality setup (Biome, Vitest, Playwright, CI) |
| <img src="plugins/midnight-verify/assets/mascot.png" width="60" /> | **midnight-verify** | Mechanical verification of Compact claims via compilation, execution, source inspection, type-checking, and ZKIR analysis |
| <img src="plugins/midnight-fact-check/assets/mascot.png" width="60" /> | **midnight-fact-check** | Fact-check documentation against the Midnight ecosystem — extract claims, classify by domain, verify, and report |

### Toolchain & Infrastructure

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-tooling/assets/mascot.png" width="60" /> | **midnight-tooling** | Compact CLI management, local devnet lifecycle, proof server, release notes, troubleshooting |
| <img src="plugins/midnight-wallet/assets/mascot.png" width="60" /> | **midnight-wallet** | Wallet CLI (MCP tools), test wallet setup, aliases, funding, dust registration |
| <img src="plugins/midnight-mcp/assets/mascot.png" width="60" /> | **midnight-mcp** | MCP server skills for compilation, simulation, search, and health checks |

### Knowledge & Education

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/core-concepts/assets/mascot.png" width="60" /> | **core-concepts** | Architecture, data models, privacy patterns, protocols, tokenomics, zero-knowledge proofs |
| <img src="plugins/midnight-node/assets/mascot.png" width="60" /> | **midnight-node** | Node architecture, configuration, governance, operations, RPC API |
| <img src="plugins/midnight-indexer/assets/mascot.png" width="60" /> | **midnight-indexer** | Indexer architecture, data model, GraphQL API |
| <img src="plugins/proof-server/assets/mascot.png" width="60" /> | **proof-server** | Proof server architecture, configuration, API, operations |

### Meta

| | Plugin | Description |
|---|--------|-------------|
| <img src="plugins/midnight-expert/assets/mascot.png" width="60" /> | **midnight-expert** | Ecosystem diagnostics — plugin health, MCP servers, external tools, cross-plugin references |
| <img src="plugins/midnight-plugin-utils/assets/mascot.png" width="60" /> | **midnight-plugin-utils** | Plugin infrastructure — dependency checking, scanning, root resolution |

## Quick Examples

**Write a contract:**
> "Create a Compact contract for a simple voting system"

**Review a contract:**
```
/compact-core:review-compact contracts/MyToken.compact
```

**Verify a claim:**
```
/midnight-verify:verify "Compact tuples are 0-indexed"
```

**Set up local devnet:**
```
/midnight-tooling:devnet generate
/midnight-tooling:devnet start
```

**Set up test wallets:**
```
/midnight-wallet:setup-test-wallets alice bob charlie
```

**Scaffold a DApp frontend:**
```
/midnight-dapp-dev:init
```

**Run diagnostics:**
```
/midnight-expert:doctor
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [Compact CLI](https://docs.midnight.network/) for compiling contracts
- Node.js for TypeScript witness development and testing
- Docker for local devnet (optional)

## Repository Structure

```
plugins/
  compact-core/          Smart contract development
  compact-examples/      Reference contract implementations
  compact-cli-dev/       CLI scaffolding for Compact contracts
  midnight-dapp-dev/     DApp frontend development
  midnight-cq/           Testing and code quality
  midnight-verify/       Mechanical verification
  midnight-fact-check/   Documentation fact-checking
  midnight-tooling/      Toolchain management
  midnight-wallet/       Wallet CLI and test wallets
  midnight-mcp/          MCP server skills
  core-concepts/         Blockchain and privacy education
  midnight-node/         Node operations and API
  midnight-indexer/      Indexer and GraphQL
  proof-server/          Proof server management
  midnight-expert/       Ecosystem diagnostics
  midnight-plugin-utils/ Plugin infrastructure
scripts/                 Validation and CI automation
.github/workflows/       GitHub Actions
```

## Development

### Validating plugins

```bash
bash scripts/validate-plugin.sh
bash scripts/validate-marketplace.sh
```

### Adding a new plugin

```bash
bash scripts/add-plugin.sh
```

### Reviewing a plugin or skill

```bash
bash scripts/review-plugin.sh <plugin-name>
bash scripts/review-skill.sh <plugin-name> <skill-name>
```

## Contributing

Contributions are welcome. When submitting changes:

1. Run `bash scripts/validate-plugin.sh` to ensure all plugins pass validation
2. Run `bash scripts/validate-marketplace.sh` to verify marketplace configuration
3. Follow the existing skill structure and naming conventions within each plugin
4. Include accurate technical claims — this project maintains a verification pipeline for fact-checking

## License

[MIT](LICENSE) — Copyright (c) 2026 Aaron Bassett
