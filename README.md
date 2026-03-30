# midnight-expert

AI-powered development tools for the [Midnight](https://midnight.network/) blockchain — a suite of [Claude Code plugins](https://docs.anthropic.com/en/docs/claude-code/plugins) that help you write, test, deploy, and review smart contracts in the Compact language.

This project extends the Midnight Network with additional developer tooling.

## Plugins

This repository contains five interconnected plugins, each installable independently from the Claude Code marketplace.

### compact-core

The primary plugin. Provides 18 skills, 2 agents, and a review command covering the full Compact development lifecycle:

- **Write contracts** — structure, types, ledger declarations, circuits, witnesses, constructors
- **Apply patterns** — 18 reusable designs including access control, governance, escrow, tokens, commit-reveal, multi-sig
- **Understand privacy** — disclosure rules, nullifiers, commitments, Merkle membership proofs, unlinkable actions
- **Implement witnesses** — TypeScript witness functions with correct type mappings and WitnessContext
- **Manage tokens** — shielded/unshielded flows, mint/send/receive, zswap protocol, NIGHT/DUST model
- **Optimize** — circuit costs, gate counts, gas model, proving time tradeoffs
- **Compile and deploy** — compiler pipeline, artifacts, provider config, wallet setup, network connections
- **Test** — Vitest with the Simulator pattern, createCircuitContext, multi-user test scenarios
- **Review** — 10-category code review across privacy, security, tokens, concurrency, performance, and more

```
/install-plugin compact-core
```

### compact-examples

Curated library of reference Compact contracts — OpenZeppelin-style implementations of fungible tokens, NFTs, access control, pausable patterns, and more.

```
/install-plugin compact-examples
```

### core-concepts

Educational foundation covering Midnight's architecture, data models, privacy patterns, cryptographic protocols, smart contract principles, and zero-knowledge proofs. Includes a `concept-explainer` agent.

```
/install-plugin core-concepts
```

### midnight-tooling

Development environment management — Compact CLI installation, local devnet lifecycle (node, indexer, proof server via Docker), account funding, diagnostics, troubleshooting, and release notes. Includes status bar integration with 7 themes.

```
/install-plugin midnight-tooling
```

### midnight-plugin-utils

Infrastructure utilities for the plugin ecosystem — dependency checking, dependency scanning, and plugin root resolution.

```
/install-plugin midnight-plugin-utils
```

## Getting Started

### Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed
- [Compact CLI](https://docs.midnight.network/) for compiling contracts
- Node.js for TypeScript witness development and testing
- Docker for local devnet (optional)

### Install the plugins

Install the plugins you need from within Claude Code:

```
/install-plugin compact-core
/install-plugin core-concepts
/install-plugin midnight-tooling
```

Once installed, the skills activate automatically based on what you're working on. Ask Claude to write a Compact contract, review existing code, set up a devnet, or explain a privacy pattern — the relevant skills engage on their own.

### Quick examples

**Scaffold a new project:**
> "Create a new Midnight project with a fungible token contract"

**Review a contract:**
```
/compact-core:review-compact contracts/MyToken.compact
```

**Get a concept explained:**
> "How do nullifiers prevent double-spending in Midnight?"

**Set up local devnet:**
> "Start a local Midnight devnet and fund a test account"

## Repository Structure

```
plugins/
├── compact-core/          # Smart contract development (18 skills, 2 agents, 1 command)
├── compact-examples/      # Reference contract implementations
├── core-concepts/         # Blockchain and privacy education (6 skills, 1 agent)
├── midnight-tooling/      # Toolchain management (5 skills, 4 commands)
└── midnight-plugin-utils/ # Plugin infrastructure utilities (3 skills)
contracts/                 # Reference Compact contracts for testing and examples
scripts/                   # Validation and CI automation
.github/workflows/         # GitHub Actions for plugin validation
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
4. Include accurate technical claims — this project maintains a verification ledger for fact-checking

## License

[MIT](LICENSE) — Copyright (c) 2026 Aaron Bassett
