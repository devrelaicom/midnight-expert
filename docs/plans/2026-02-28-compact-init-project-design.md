# Design: compact-init-project Skill

**Date:** 2026-02-28
**Plugin:** compact-core
**Type:** Actionable guide skill

## Overview

A skill that guides Claude through scaffolding a new Midnight/Compact project using `create-mn-app`. Claude follows the procedural workflow step-by-step: verifying prerequisites, running the scaffolding tool, starting the proof server, and compiling the contract.

## Scope

**In scope:**
- Hello-world template (bundled, simple starter)
- Counter template (remote clone from `midnightntwrk/example-counter`)
- Prerequisite verification via `/midnight-tooling:doctor`
- Proof server startup via `/midnight-tooling:run-proof-server`
- Contract compilation
- Quick reference for SDK versions, network URLs, project structure
- Troubleshooting common init failures

**Out of scope:**
- Bboard template (may add later)
- Deployment to Preprod (involves wallet creation and faucet funding)
- Writing custom Compact contracts (covered by other compact-core skills)
- Existing project troubleshooting (covered by `midnight-tooling:troubleshooting`)

## File Structure

```
plugins/compact-core/skills/compact-init-project/
├── SKILL.md                        # Trigger description + overview
└── references/
    ├── create-mn-app-workflow.md    # Step-by-step procedural workflow
    ├── project-structure.md        # File layouts, SDK versions, network URLs
    └── troubleshooting.md          # Common init failures and fixes
```

## Skill Identity

**Trigger description:** Creating a new Midnight project, scaffolding a Compact smart contract project, "create-mn-app", initializing a DApp, setting up a new Midnight application, "new project", "start a project", "project template", hello-world or counter template setup, first-time Midnight development environment setup.

**Not for:** Existing project troubleshooting, adding features to an existing project, writing Compact contracts from scratch, deploying to Preprod.

## Workflow (create-mn-app-workflow.md)

### Phase 1 — Environment Check
1. Run `/midnight-tooling:doctor` to verify prerequisites
2. If any FAIL results: guide user to fix before continuing (link to midnight-tooling skills)
3. If all PASS/WARN: proceed

### Phase 2 — Template Selection
1. Ask user which template:
   - **Hello World** — simple starter, bundled template, message storage contract
   - **Counter DApp** — state management, remote clone, increment/decrement with ZK proofs
2. If user describes a custom project, recommend the closest template as starting point

### Phase 3 — Project Scaffolding
1. Run `npx create-mn-app <project-name> --template <selected-template>`
2. For hello-world: create-mn-app handles install + compile automatically
3. For counter: create-mn-app clones the repo and shows setup instructions
4. Verify the project directory was created with expected structure

### Phase 4 — Proof Server
1. Run `/midnight-tooling:run-proof-server` to start the Docker proof server
2. Wait for health check to confirm it's ready

### Phase 5 — Compile Contract
1. For hello-world: `npm run compile` (or equivalent for detected package manager)
2. For counter: `cd contract && npm install && npm run compact && npm run build`
3. Verify managed output directory was populated with compiler artifacts

### Phase 6 — Summary & Next Steps
1. Confirm what was created and compiled
2. Show available commands (deploy, cli, check-balance, etc.)
3. Point to faucet URL: `https://faucet.preprod.midnight.network/`
4. Mention relevant compact-core skills for writing contracts

## Project Structure Reference (project-structure.md)

### Hello World Layout
```
<project-name>/
├── contracts/
│   └── hello-world.compact           # pragma language_version >= 0.16
├── src/
│   ├── deploy.ts                     # Deploy to Preprod
│   ├── cli.ts                        # Interactive CLI
│   └── check-balance.ts              # Wallet balance checker
├── docker-compose.yml                # Proof server config
├── package.json                      # Node 22+, type: module, SDK 3.0
├── tsconfig.json                     # ES2022, NodeNext
└── contracts/managed/                # (after compile)
    └── hello-world/
        ├── compiler/                 # Contract metadata JSON
        ├── contract/                 # Generated JS + type defs
        ├── keys/                     # ZK proving/verifying keys
        └── zkir/                     # ZK intermediate representation
```

### Counter Layout
```
<project-name>/
├── contract/                         # Workspace: smart contract
│   ├── src/
│   │   ├── counter.compact
│   │   └── test/
│   └── src/managed/counter/          # (after compile)
└── counter-cli/                      # Workspace: CLI interface
    └── src/
```

### Key SDK Versions (Feb 2026)
- `@midnight-ntwrk/compact-runtime`: 0.14.0
- `@midnight-ntwrk/compact-js`: 2.4.0
- `@midnight-ntwrk/ledger-v7`: 7.0.0
- `@midnight-ntwrk/midnight-js-*`: 3.0.0
- `@midnight-ntwrk/wallet-sdk-*`: 1.0.0–3.0.0
- Proof server: `midnightntwrk/proof-server:7.0.0`
- Compact compiler: `compactc-v0.29.0`

### Network Endpoints (Preprod)
- Indexer: `https://indexer.preprod.midnight.network`
- RPC: `https://rpc.preprod.midnight.network`
- Faucet: `https://faucet.preprod.midnight.network/`

Note: Use Midnight MCP `midnight-get-version-info` to verify versions if reference feels stale.

## Troubleshooting Reference (troubleshooting.md)

### Scaffolding Failures

| Problem | Cause | Fix |
|---------|-------|-----|
| `npx create-mn-app` not found/fails | npm cache, network | `npm cache clean --force`, retry. Check node 22+ |
| Directory already exists | Name collision | Choose different name or approve overwrite |
| Git clone fails (counter) | Network, auth | Check internet. Test with `git ls-remote` |
| `compact: command not found` | CLI not installed | Run `/midnight-tooling:install-cli` |

### Compilation Failures

| Problem | Cause | Fix |
|---------|-------|-----|
| Compiler version mismatch | Old compiler | `compact update` or `compact update 0.29.0` |
| `pragma language_version` error | Compiler too old | Same as above |
| ZK parameter download stalls | Docker resources | Increase Docker memory to 4+ GB |

### Proof Server Failures

| Problem | Cause | Fix |
|---------|-------|-----|
| Docker not running | Desktop not started | Start Docker Desktop. Run `/midnight-tooling:doctor` |
| Port 6300 in use | Conflicting process | `lsof -i :6300`, stop conflicting process |
| Container exits immediately | Resource constraints | Increase Docker memory to 4-8 GB |

Cross-references: `midnight-tooling:troubleshooting` skill, `/midnight-tooling:doctor` command.

## Dependencies

- **midnight-tooling plugin:** `/midnight-tooling:doctor`, `/midnight-tooling:run-proof-server`, `/midnight-tooling:install-cli`
- **External tools:** `npx` (Node.js), Docker Desktop
- **create-mn-app:** v0.3.19+ (`npx create-mn-app`)
- **Midnight MCP server:** For version verification (`midnight-get-version-info`)

## Plugin.json Updates

Add keywords to compact-core's `plugin.json`:
- `create-mn-app`, `project-setup`, `scaffolding`, `init-project`, `hello-world`, `counter-template`
