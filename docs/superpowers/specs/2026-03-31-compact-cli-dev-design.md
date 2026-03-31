# compact-cli-dev Plugin Design

**Date:** 2026-03-31
**Status:** Draft
**Author:** Aaron Bassett + Claude

## Overview

A Claude Code plugin that scaffolds production-quality Oclif CLIs for interacting with Midnight Compact smart contracts on local devnet. The plugin provides a reusable template engine package, a complete CLI template with built-in wallet management, contract deployment, funding, and DUST registration commands, plus an AI agent for ongoing CLI development.

The design is informed by a deep analysis of four existing Midnight example CLIs (example-counter, hello-world-compact, example-bboard, example-kitties) and the decompiled wallet-cli source. Common patterns across all examples have been extracted and standardized into the template.

## Problem

Every Midnight example repo reinvents the same ~500 lines of CLI boilerplate: wallet HD derivation, WalletFacade composition, provider bundle setup, fund polling, DUST registration, readline menus. None use a CLI framework (all use raw `readline`), making them unscriptable, untestable, and hostile to LLM agents. There is no standard for wallet persistence, error handling, or progress feedback.

## Solution

Three deliverables:

1. **`@midnight-expert/template-engine`** — a generic, reusable npm package in `packages/template-engine/` that copies template directories and performs `{{PLACEHOLDER}}` substitution. Accepts JSON over stdin. Usable by any plugin that needs template scaffolding.

2. **`plugins/compact-cli-dev/`** — a Claude Code plugin containing:
   - A `core` skill with reference docs, the CLI template, and init script
   - A `dev` agent for ongoing CLI development
   - An `init` command that scaffolds a new CLI

3. **The CLI template itself** — a complete Oclif project with 12 built-in commands, wallet management, provider setup, funding, DUST registration, contract deployment, devnet control, error handling, progress feedback, Biome linting, Husky git hooks, Vitest tests, and GitHub Actions CI.

## Architecture

### Component Relationship

```
User: "Add a CLI to my project"
  │
  ▼
compact-cli-dev:dev agent (spawned)
  │
  ├── Loads compact-cli-dev:core skill (reference docs)
  ├── Loads devs:typescript-core skill (TS best practices)
  │
  ├── Detects: no CLI exists in project
  │
  ├── Runs /compact-cli-dev:init command
  │   │
  │   ├── Infers project-name, contract-name from project state
  │   │
  │   ├── Pipes JSON to template engine:
  │   │   echo '{"template":"...","output":"./cli","context":{...}}' \
  │   │     | npx @midnight-expert/template-engine
  │   │
  │   ├── Runs npm install in ./cli
  │   ├── Runs npx husky init
  │   └── Reports: "CLI scaffolded at ./cli"
  │
  └── Offers to add contract-specific commands
```

### Deliverable 1: Template Engine Package

**Location:** `packages/template-engine/`

**Purpose:** Generic template directory copier with placeholder substitution. Reusable by any plugin. Zero runtime dependencies beyond Node.js builtins.

**Interface:**

```bash
echo '<json>' | npx @midnight-expert/template-engine
```

**stdin JSON schema:**

```json
{
  "template": "/absolute/path/to/template/directory",
  "output": "./relative/or/absolute/output/directory",
  "context": {
    "KEY": "value — each KEY becomes {{KEY}} in template files"
  }
}
```

**stdout on success:**

```json
{
  "output": "/absolute/path/to/output",
  "files": 42
}
```

**stderr on failure:**

```json
{
  "error": "description of what went wrong"
}
```

**Behavior:**

1. Read and parse JSON from stdin
2. Validate: template directory exists, output directory does NOT exist (refuses to overwrite)
3. Recursively copy template directory to output
4. For every text file: replace all `{{KEY}}` occurrences with corresponding context values
5. Rename `*.tmpl` files to strip the `.tmpl` extension (e.g., `package.json.tmpl` → `package.json`)
6. Skip binary files (detected via file extension allowlist or null-byte scan)
7. Write result JSON to stdout

**Package structure:**

```
packages/template-engine/
├── package.json              # @midnight-expert/template-engine
├── tsconfig.json
├── biome.json
├── src/
│   ├── index.ts              # stdin reader → engine → stdout result
│   ├── engine.ts             # Core: recursive copy + substitute + rename
│   └── detect-binary.ts      # Binary file detection
└── test/
    ├── engine.test.ts
    └── fixtures/
        └── sample-template/  # Test fixtures
```

### Deliverable 2: Plugin Structure

```
plugins/compact-cli-dev/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── core/
│       ├── SKILL.md
│       ├── references/
│       │   ├── oclif-patterns.md         # Oclif conventions, command anatomy, base command
│       │   ├── wallet-management.md      # Wallet SDK patterns, facade building, persistence
│       │   ├── provider-setup.md         # Provider bundle factory, network config
│       │   ├── contract-lifecycle.md     # Deploy, join, call, query patterns
│       │   └── error-handling.md         # Error framework, classification, actionable messages
│       └── templates/
│           └── cli/                      # Complete Oclif project template
│               └── (see Deliverable 3)
├── agents/
│   └── dev.md                            # compact-cli-dev:dev agent
└── commands/
    └── init.md                           # compact-cli-dev:init command
```

#### Skill: `compact-cli-dev:core`

The skill SKILL.md provides:
- Overview of the CLI architecture and conventions
- Quick reference for all built-in commands
- Guide to the `src/lib/` module structure
- Patterns for adding new commands (Oclif command anatomy, base command usage)
- Wallet management conventions (file locations, permissions, formats)
- Provider bundle setup patterns
- Error handling patterns with actionable messages
- Progress feedback patterns (ora, cli-progress)

Reference docs provide deep dives into each area, with code examples pulled from the template.

#### Agent: `compact-cli-dev:dev`

**Triggers on:** "add a CLI", "create CLI commands", "work on the CLI", "add a command to interact with my contract", "I need a CLI for my contract"

**Model:** sonnet (fast iteration for code-heavy work)

**Workflow:**

1. Load `compact-cli-dev:core` skill (always)
2. Load `devs:typescript-core` skill (always)
3. Check if a CLI package exists in the project:
   - Look for Oclif config in a `package.json` within likely directories
   - Look for `.midnight-expert/` state directory
4. If no CLI exists → run `/compact-cli-dev:init` to scaffold
5. If CLI exists → work with existing code (add commands, modify lib, fix bugs)
6. After writing code → run `biome check`, `tsc --noEmit`, and `vitest run`
7. Follow patterns from `compact-cli-dev:core` references

**The agent does NOT:**
- Read template files (that's the template engine's job)
- Guess at Midnight SDK patterns (loads skill references)
- Skip validation (always runs biome + tsc + tests)

#### Command: `compact-cli-dev:init`

**Invocation:** `/compact-cli-dev:init [directory] [--project-name <name>] [--contract-name <name>] [--contract-path <path>]`

**Allowed tools:** Bash, Read, AskUserQuestion

**Steps:**

1. Determine parameters — use flags if provided, otherwise inspect the project:
   - `directory`: defaults to `./cli`
   - `project-name`: inferred from root `package.json` name, or directory name
   - `contract-name`: inferred by scanning for `.compact` files or `managed/` directories
   - `contract-path`: inferred from contract-name if standard layout detected
2. If anything can't be inferred, ask via `AskUserQuestion`
3. Build the context object with all template variables (see Deliverable 3 placeholder table)
4. Resolve the template path. `${CLAUDE_PLUGIN_ROOT}` does not expand in markdown — the command must resolve it via Bash:
   ```bash
   TEMPLATE_DIR="$(dirname "$(dirname "$(which compact-cli-dev 2>/dev/null || echo "")")")/skills/core/templates/cli"
   ```
   In practice, the agent should use the Bash tool to locate the plugin root (e.g., by reading the plugin registry or using a known path), then construct the absolute template path.
5. Pipe JSON to template engine:
   ```bash
   echo '{"template":"<resolved-template-dir>","output":"<dir>","context":{...}}' | npx @midnight-expert/template-engine
   ```
6. Run `npm install` in the output directory
7. Run `npx husky init` and copy hook scripts
8. Report what was created

### Deliverable 3: CLI Template

The template at `plugins/compact-cli-dev/skills/core/templates/cli/` is a complete, working Oclif project.

#### Template Placeholders

| Placeholder | Source | Example |
|---|---|---|
| `{{PROJECT_NAME}}` | `--project-name` or inferred | `my-dapp` |
| `{{CLI_PACKAGE_NAME}}` | derived: `${PROJECT_NAME}-cli` | `my-dapp-cli` |
| `{{CONTRACT_NAME}}` | `--contract-name` or inferred | `counter` |
| `{{CONTRACT_PACKAGE}}` | derived: `@midnight-ntwrk/${CONTRACT_NAME}-contract` | `@midnight-ntwrk/counter-contract` |
| `{{CONTRACT_ZK_CONFIG_PATH}}` | `--contract-path` or inferred | `../contract/src/managed/counter` |
| `{{GENERATED_AT}}` | auto-generated timestamp | `2026-03-31T14:00:00Z` |

#### Template File Structure

```
templates/cli/
├── package.json.tmpl
├── tsconfig.json
├── biome.json
├── .husky/
│   ├── pre-commit                  # biome check --staged
│   └── pre-push                    # biome check . && tsc --noEmit && vitest run
├── .github/
│   └── workflows/
│       └── ci.yml                  # PR + push: install → biome → tsc → vitest
├── src/
│   ├── base-command.ts             # Shared Oclif base command
│   ├── commands/
│   │   ├── deploy.ts
│   │   ├── join.ts
│   │   ├── call.ts                 # Working example showing callTx pattern with TODO marker
│   │   ├── query.ts                # Working example showing queryContractState pattern with TODO marker
│   │   ├── balance.ts
│   │   ├── wallet/
│   │   │   ├── create.ts
│   │   │   ├── list.ts
│   │   │   ├── info.ts
│   │   │   └── fund.ts
│   │   ├── dust/
│   │   │   ├── register.ts
│   │   │   └── status.ts
│   │   └── devnet/
│   │       ├── start.ts
│   │       ├── stop.ts
│   │       └── status.ts
│   └── lib/
│       ├── wallet.ts               # HD derivation, WalletFacade, seed gen, file I/O
│       ├── providers.ts            # One-call provider bundle factory
│       ├── funding.ts              # Genesis airdrop, DUST orchestration
│       ├── contract.ts             # Deploy/join wrappers, address persistence
│       ├── config.ts               # Local devnet network config (hardcoded 127.0.0.1)
│       ├── errors.ts               # Error classification + actionable messages
│       ├── progress.ts             # ora spinner + cli-progress wrappers
│       └── constants.ts            # Timeouts, fees, paths, genesis seed
├── test/
│   ├── commands/
│   │   ├── wallet/
│   │   │   └── create.test.ts
│   │   ├── deploy.test.ts
│   │   └── balance.test.ts
│   ├── lib/
│   │   ├── wallet.test.ts
│   │   ├── funding.test.ts
│   │   └── errors.test.ts
│   └── helpers/
│       └── init.ts                 # Test setup, mock providers
└── bin/
    ├── run.ts
    └── dev.ts
```

#### SDK Dependencies

Based on the wallet-cli analysis and the example repos (using latest versions):

```json
{
  "@midnight-ntwrk/compact-runtime": "0.15.0",
  "@midnight-ntwrk/ledger-v8": "^8.0.0",
  "@midnight-ntwrk/midnight-js-contracts": "^4.0.0",
  "@midnight-ntwrk/midnight-js-http-client-proof-provider": "^4.0.0",
  "@midnight-ntwrk/midnight-js-indexer-public-data-provider": "^4.0.0",
  "@midnight-ntwrk/midnight-js-level-private-state-provider": "^4.0.0",
  "@midnight-ntwrk/midnight-js-network-id": "^4.0.0",
  "@midnight-ntwrk/midnight-js-node-zk-config-provider": "^4.0.0",
  "@midnight-ntwrk/midnight-js-types": "^4.0.0",
  "@midnight-ntwrk/midnight-js-utils": "^4.0.0",
  "@midnight-ntwrk/wallet-sdk-address-format": "^3.0.0",
  "@midnight-ntwrk/wallet-sdk-dust-wallet": "^3.0.0",
  "@midnight-ntwrk/wallet-sdk-facade": "^3.0.0",
  "@midnight-ntwrk/wallet-sdk-hd": "^3.0.0",
  "@midnight-ntwrk/wallet-sdk-shielded": "^2.0.0",
  "@midnight-ntwrk/wallet-sdk-unshielded-wallet": "^2.0.0",
  "@midnight-ntwrk/compact-js": "^4.0.0",
  "@oclif/core": "^4.0.0",
  "ora": "^8.0.0",
  "cli-progress": "^3.12.0",
  "ws": "^8.19.0",
  "rxjs": "^7.8.0"
}
```

Note: The `signTransactionIntents` workaround is NOT needed — it was fixed in wallet-sdk-facade 3.0.0 (confirmed by reviewing the midnight-js repo, commit c73eb959, October 2025).

#### Built-in Commands

| Command | Description | JSON output |
|---|---|---|
| `wallet:create [name]` | Generate wallet with random seed, save to `.midnight-expert/wallets.json` | `{ name, address, seed }` |
| `wallet:list` | List saved wallets | `[{ name, address }]` |
| `wallet:info <name>` | Show wallet details and balances | `{ name, address, night, dust }` |
| `wallet:fund <name>` | Airdrop from genesis + register DUST | `{ txId, night, dust }` |
| `dust:register <name>` | Register NIGHT UTXOs for DUST generation | `{ txId, registered }` |
| `dust:status <name>` | Check DUST balance and registration | `{ balance, available, registered }` |
| `balance <name>` | Query NIGHT + DUST balances | `{ night, dust }` |
| `deploy` | Deploy compiled contract, save address | `{ contractAddress, txId, blockHeight }` |
| `join <address>` | Join existing deployed contract | `{ contractAddress }` |
| `devnet:start` | `docker compose up -d` on devnet.yml | `{ services: [...] }` |
| `devnet:stop` | `docker compose down` | `{ stopped: true }` |
| `devnet:status` | Health check all services | `{ node, indexer, proofServer }` |

All commands support `--json` via Oclif's built-in JSON output flag.

#### Base Command

All commands extend a shared `BaseCommand` class providing:

- **Wallet loading** by name from `.midnight-expert/wallets.json`
- **Provider initialization** via `providers.ts` factory
- **Error handling** — catches all errors, classifies via `errors.ts`, prints actionable message
- **JSON output** — `this.log()` for human output, `return` for `--json` structured output
- **Welcome banner** — on first run (tracked by `.midnight-expert/.initialized`), prints:

```
  WARNING: These wallets are for LOCAL DEVNET use only.
  Seeds are stored in plaintext. Never use these accounts
  on preprod, preview, or mainnet.
```

#### State Files

All under `.midnight-expert/` in project root:

| File | Permissions | Schema |
|---|---|---|
| `wallets.json` | `0o600` | `{ "<name>": { "seed": "hex64", "address": "bech32m", "createdAt": "ISO8601" } }` |
| `deployed-contracts.json` | `0o644` | `{ "<name>": { "address": "hex", "deployedAt": "ISO8601", "txId": "hex" } }` |
| `.initialized` | `0o644` | Empty marker file — welcome banner has been shown |

#### Code Quality

- **Biome** — linting + formatting (tabs, 100 char width, strict rules matching midnight-expert conventions)
- **Husky** git hooks:
  - `pre-commit`: `biome check --staged` (lint + format changed files only)
  - `pre-push`: `biome check . && tsc --noEmit && vitest run` (full validation)
- **Vitest** for tests — all tests mock Midnight SDK providers (no Docker required)
- **GitHub Actions CI** (`.github/workflows/ci.yml`):
  - Triggers: PR to main, push to main
  - Steps: checkout → install → `biome check .` → `tsc --noEmit` → `vitest run`

#### Error Handling Framework

`src/lib/errors.ts` provides error classification with actionable messages:

| Error Pattern | Classification | User Action |
|---|---|---|
| Insufficient DUST | `DUST_REQUIRED` | "Run `<cli> dust:register <wallet>`" |
| Proof server unreachable | `SERVICE_DOWN` | "Run `<cli> devnet:start`" |
| Indexer connection failed | `SERVICE_DOWN` | "Run `<cli> devnet:status` to check services" |
| Contract not found | `CONTRACT_NOT_FOUND` | "Verify address and that devnet is running" |
| Wallet not found | `WALLET_NOT_FOUND` | "Run `<cli> wallet:create <name>`" |
| Stale UTXO | `STALE_UTXO` | Auto-retry (up to 3 times) |
| Wallet sync timeout | `SYNC_TIMEOUT` | "Devnet may be starting up. Wait and retry." |

#### Progress Feedback

`src/lib/progress.ts` wraps `ora` and `cli-progress`:

- **Spinners** for indeterminate operations (wallet sync, proof generation, transaction submission)
- **Progress bars** for operations with known progress (future: multi-step deployments)
- Both silent when `--json` flag is active (output goes to stderr only in non-JSON mode)

#### Network Configuration

`src/lib/config.ts` — hardcoded local devnet only:

```typescript
export const DEVNET_CONFIG = {
  indexer: 'http://127.0.0.1:8088/api/v3/graphql',
  indexerWS: 'ws://127.0.0.1:8088/api/v3/graphql/ws',
  node: 'http://127.0.0.1:9944',
  proofServer: 'http://127.0.0.1:6300',
  networkId: 'undeployed',
};
```

#### Wallet Management

`src/lib/wallet.ts` — based on patterns from the wallet-cli and example-counter:

- **HD derivation:** `HDWallet.fromSeed()` → `selectAccount(0)` → `selectRoles([Zswap, NightExternal, Dust])` → `deriveKeysAt(0)`
- **Three sub-wallets:** ShieldedWallet, UnshieldedWallet, DustWallet → composed via WalletFacade
- **Seed format:** 64-char hex string (256-bit), generated via `generateRandomSeed()`
- **Genesis seed:** `0000000000000000000000000000000000000000000000000000000000000001`
- **WebSocket polyfill:** `globalThis.WebSocket = WebSocket` (required for GraphQL subscriptions)
- **Persistence:** Read/write `.midnight-expert/wallets.json` with `0o600` permissions

#### Funding

`src/lib/funding.ts` — local devnet only:

- **Airdrop:** Transfer from genesis wallet to target address (same mechanism as wallet-cli `airdrop` command)
- **DUST registration:** Filter unregistered NIGHT UTXOs → `createDustGenerationTransaction()` → sign → finalize → submit → poll until DUST balance > 0
- **RxJS polling** pattern for fund/sync waiting (matching all four example repos)

#### Contract Lifecycle

`src/lib/contract.ts`:

- **Deploy:** `deployContract(providers, { compiledContract, privateStateId, initialPrivateState })`
- **Join:** `findDeployedContract(providers, { contractAddress, compiledContract, privateStateId, initialPrivateState })`
- **Compiled contract loading:** `CompiledContract.make()` with `.pipe(withVacantWitnesses, withCompiledFileAssets())`
- **Address persistence:** Save to `.midnight-expert/deployed-contracts.json` on deploy

## Scope Boundaries

### In scope

- Local devnet only
- Single contract per CLI
- Wallet management for testing (plaintext seeds)
- Airdrop funding from genesis wallet
- DUST registration and status
- Deploy and join contract
- Stub `call` and `query` commands (agent fills in contract-specific logic)
- Template engine as a generic reusable package
- Full code quality tooling (Biome, Husky, Vitest, GitHub Actions)
- Tests for all built-in commands and lib modules (mocked providers)

### Out of scope

- Preprod/preview network support
- Multi-contract projects
- Wallet encryption or hardware wallet support
- Contract compilation (that's the Compact CLI's job)
- Browser/UI scaffolding
- Publishing the scaffolded CLI to npm
- Docker Compose generation (that's the devnet skill's job)

### Relationship to existing plugins

- **midnight-wallet** — the scaffolded CLI has its own wallet management (simpler, project-local). Wallet-cli MCP tools are complementary but not required.
- **midnight-tooling:devnet** — the `devnet:start/stop/status` commands shell out to `docker compose`. They search for a compose file in this order: `./devnet.yml` → `./.midnight/devnet.yml` → `~/.midnight-expert/devnet/devnet.yml`. If none found, the command prints an actionable error telling the user to generate one via the devnet skill. We don't generate compose files.
- **dapp-development:midnight-sdk** — our reference docs cover CLI-specific SDK patterns. No conflict.

### Stub commands: `call` and `query`

These are not empty files. They contain working Oclif command boilerplate that demonstrates the correct pattern (`contract.callTx.*` for `call`, `publicDataProvider.queryContractState()` for `query`), with a clearly marked `// TODO: Replace with your contract's circuit name and arguments` section. This way the agent (or developer) sees the exact pattern to follow and only needs to fill in the contract-specific parts.
