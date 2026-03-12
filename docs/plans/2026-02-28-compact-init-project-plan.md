# compact-init-project Skill Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create an actionable skill in compact-core that guides Claude through scaffolding a new Midnight/Compact project using create-mn-app, covering hello-world and counter templates.

**Architecture:** Four markdown files — SKILL.md (trigger + overview) plus three reference files (workflow, project structure, troubleshooting). Follows the same SKILL.md frontmatter pattern as existing compact-core skills. The workflow reference is the novel piece: it's procedural instructions Claude follows step-by-step, delegating to midnight-tooling commands for prereq checks and proof server management.

**Tech Stack:** Markdown skill files, YAML frontmatter, cross-plugin skill/command references

---

### Task 1: Create the references directory

**Files:**
- Create: `plugins/compact-core/skills/compact-init-project/references/` (directory)

**Step 1: Create the directory structure**

```bash
mkdir -p plugins/compact-core/skills/compact-init-project/references
```

Expected: Directory created at `plugins/compact-core/skills/compact-init-project/references/`

**Step 2: Verify structure**

```bash
ls -la plugins/compact-core/skills/compact-init-project/
```

Expected: Shows `references/` directory

---

### Task 2: Create references/create-mn-app-workflow.md

This is the main procedural document — the step-by-step workflow Claude follows.

**Files:**
- Create: `plugins/compact-core/skills/compact-init-project/references/create-mn-app-workflow.md`

**Step 1: Write the workflow reference**

```markdown
# create-mn-app Workflow

This is a step-by-step procedural workflow. Follow each phase in order. Do not skip phases.

## Phase 1 — Environment Check

Run `/midnight-tooling:doctor` to verify the development environment is ready.

**Required passes:**
- Node.js 22+ installed
- Docker Desktop installed and running
- Compact CLI installed with a compiler version available

**If any check FAILs:**
1. Report the failures to the user
2. For missing Compact CLI: run `/midnight-tooling:install-cli`
3. For Docker issues: refer to `midnight-tooling:proof-server` skill
4. For Node.js issues: user must install Node.js 22+ from https://nodejs.org/
5. Re-run `/midnight-tooling:doctor` after fixes to confirm

**If all checks PASS or WARN:** proceed to Phase 2.

## Phase 2 — Template Selection

Ask the user which template they want. Use `AskUserQuestion` with these options:

| Template | Description | Best For |
|----------|-------------|----------|
| **Hello World** | Simple message storage contract. Bundled template — scaffolds locally, installs deps. | First-time Midnight developers, learning the basics |
| **Counter** | Increment/decrement counter with ZK proofs. Cloned from `midnightntwrk/example-counter`. Uses npm workspaces. | Understanding state management and ZK proof generation |

If the user describes a custom project instead of choosing a template, recommend the closest template as a starting point and explain they can modify the contract after scaffolding.

If the user has not specified a project name, ask for one. Default suggestion: `my-midnight-app`. Project names must be valid npm package names (lowercase, no spaces, hyphens allowed).

## Phase 3 — Project Scaffolding

### Hello World template

Run:

```bash
npx create-mn-app@latest <project-name> --template hello-world
```

This command will:
1. Create the project directory
2. Scaffold template files (contract, TypeScript sources, configs)
3. Install npm dependencies
4. Check Docker availability for proof server
5. Attempt initial contract compilation

If the user has a preferred package manager, add the appropriate flag:
- `--use-npm` (default)
- `--use-yarn`
- `--use-pnpm`
- `--use-bun`

### Counter template

Run:

```bash
npx create-mn-app@latest <project-name> --template counter
```

This command will:
1. Check prerequisites (Node 22+, Docker, Compact compiler >= 0.28.0)
2. Clone the `midnightntwrk/example-counter` repository
3. Initialize a fresh git repository
4. Display setup instructions

**Important:** The counter template requires the Compact compiler to be installed. If `create-mn-app` reports a version mismatch, run:

```bash
compact update
```

Or for a specific version:

```bash
compact update 0.28.0
```

### Verify scaffolding

After `create-mn-app` completes, verify the project was created:

```bash
ls <project-name>/
```

For hello-world, expect: `contracts/`, `src/`, `package.json`, `tsconfig.json`, `docker-compose.yml`
For counter, expect: `contract/`, `counter-cli/`, `package.json`

## Phase 4 — Proof Server

Start the proof server using the midnight-tooling command:

Run `/midnight-tooling:run-proof-server`

This starts a Docker container running the Midnight proof server on port 6300. The command handles:
- Resolving the latest stable Docker image tag
- Starting the container
- Verifying the health endpoint responds

**If the proof server fails to start:** consult `references/troubleshooting.md` for common issues.

## Phase 5 — Compile Contract

### Hello World

If `create-mn-app` already compiled the contract during scaffolding (it attempts this automatically), skip this step. Otherwise:

```bash
cd <project-name>
npm run compile
```

Verify compilation output exists:

```bash
ls contracts/managed/hello-world/
```

Expected directories: `compiler/`, `contract/`, `keys/`, `zkir/`

### Counter

The counter template uses npm workspaces. Compile with:

```bash
cd <project-name>
npm install
cd contract
npm run compact
npm run build
cd ..
```

Verify compilation output exists:

```bash
ls contract/src/managed/counter/
```

Expected directories: `compiler/`, `contract/`, `keys/`, `zkir/`

**Note:** First compilation downloads ~500MB of ZK parameters. This may take several minutes depending on network speed.

## Phase 6 — Summary & Next Steps

After successful scaffolding and compilation, present the user with:

### What was created

Confirm:
- Project directory at `./<project-name>/`
- Compact contract source file (show path)
- Compiled contract artifacts in `managed/` directory
- Proof server running on port 6300

### Available commands

For hello-world:
- `npm run deploy` — Deploy contract to Preprod (requires wallet funding)
- `npm run cli` — Interactive CLI to test the deployed contract
- `npm run check-balance` — Check wallet balance
- `npm run compile` — Re-compile the contract after changes

For counter:
- `cd counter-cli && npm run start` — Run the counter CLI
- `cd contract && npm run compact` — Re-compile the contract after changes

### Next steps to deploy (out of scope for this skill, but inform the user)

1. Get test tokens from the Preprod faucet: https://faucet.preprod.midnight.network/
2. Funding takes 2–3 minutes
3. Run the deploy command
4. DUST tokens are generated automatically by delegating tNight holdings

### Relevant skills for writing contracts

Point the user to these compact-core skills for customizing their contract:
- `compact-structure` — Contract anatomy, pragma, types, circuits, witnesses
- `compact-ledger` — On-chain state design, ADT operations
- `compact-privacy-disclosure` — Privacy patterns, disclose() rules
- `compact-witness-ts` — TypeScript witness implementation
```

**Step 2: Verify the file was created**

```bash
wc -l plugins/compact-core/skills/compact-init-project/references/create-mn-app-workflow.md
```

Expected: ~140-160 lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-init-project/references/create-mn-app-workflow.md
git commit -m "feat(compact-core): add create-mn-app workflow reference for compact-init-project"
```

---

### Task 3: Create references/project-structure.md

**Files:**
- Create: `plugins/compact-core/skills/compact-init-project/references/project-structure.md`

**Step 1: Write the project structure reference**

```markdown
# Project Structure & Version Reference

## Hello World Project Layout

After running `npx create-mn-app <name> --template hello-world`:

```
<project-name>/
├── contracts/
│   └── hello-world.compact           # Contract source (pragma language_version >= 0.16)
├── src/
│   ├── deploy.ts                     # Deploy contract to Preprod network
│   ├── cli.ts                        # Interactive CLI for testing deployed contract
│   └── check-balance.ts              # Check wallet tNight/DUST balance
├── docker-compose.yml                # Proof server Docker config (port 6300)
├── package.json                      # Node 22+, type: module, SDK 3.0 dependencies
├── tsconfig.json                     # ES2022 target, NodeNext modules
└── README.md
```

After compilation, the managed output directory is created:

```
contracts/managed/hello-world/
├── compiler/                         # Contract structure metadata (JSON)
├── contract/                         # Generated JavaScript + TypeScript type definitions
│   ├── index.js                      # Runtime implementation
│   └── index.d.ts                    # Type declarations (Ledger, Witnesses, Contract, etc.)
├── keys/                             # Cryptographic ZK proving and verifying keys
└── zkir/                             # Zero-Knowledge Intermediate Representation
```

### Hello World Contract Source

The scaffolded contract:

```compact
pragma language_version >= 0.16;

import CompactStandardLibrary;

// Public ledger state - visible on blockchain
export ledger message: Opaque<"string">;

// Circuit to store a message on the blockchain
// The message will be publicly visible
export circuit storeMessage(customMessage: Opaque<"string">): [] {
  message = disclose(customMessage);
}
```

### Hello World package.json Scripts

| Script | Command | Purpose |
|--------|---------|---------|
| `compile` | `compact compile contracts/hello-world.compact contracts/managed/hello-world` | Compile the Compact contract |
| `setup` | `docker compose up -d && npm run compile && npm run deploy` | Full setup: proof server + compile + deploy |
| `deploy` | `npx tsx src/deploy.ts` | Deploy to Preprod |
| `cli` | `npx tsx src/cli.ts` | Interactive contract CLI |
| `check-balance` | `npx tsx src/check-balance.ts` | Check wallet balance |
| `proof-server:start` | `docker compose up -d` | Start proof server |
| `proof-server:stop` | `docker compose down` | Stop proof server |
| `clean` | `rm -rf contracts/managed deployment.json` | Remove build artifacts |

## Counter Project Layout

After running `npx create-mn-app <name> --template counter`:

```
<project-name>/
├── contract/                         # npm workspace: smart contract
│   ├── src/
│   │   ├── counter.compact           # Contract source
│   │   ├── managed/counter/          # (after compile) compiler output
│   │   └── test/                     # Contract unit tests
│   ├── package.json
│   └── tsconfig.json
├── counter-cli/                      # npm workspace: CLI interface
│   ├── src/
│   │   └── ...                       # CLI implementation
│   ├── package.json
│   └── tsconfig.json
├── package.json                      # Root workspace configuration
└── README.md
```

The counter uses npm workspaces — both `contract` and `counter-cli` are workspace packages managed from the root.

## SDK Package Versions (February 2026)

These are the versions used by `create-mn-app` v0.3.19 hello-world template:

| Package | Version |
|---------|---------|
| `@midnight-ntwrk/compact-runtime` | 0.14.0 |
| `@midnight-ntwrk/compact-js` | 2.4.0 |
| `@midnight-ntwrk/ledger-v7` | 7.0.0 |
| `@midnight-ntwrk/midnight-js-contracts` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-http-client-proof-provider` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-indexer-public-data-provider` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-level-private-state-provider` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-node-zk-config-provider` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-network-id` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-types` | 3.0.0 |
| `@midnight-ntwrk/midnight-js-utils` | 3.0.0 |
| `@midnight-ntwrk/wallet-sdk-facade` | 1.0.0 |
| `@midnight-ntwrk/wallet-sdk-hd` | 3.0.0 |
| `@midnight-ntwrk/wallet-sdk-shielded` | 1.0.0 |
| `@midnight-ntwrk/wallet-sdk-unshielded-wallet` | 1.0.0 |
| `@midnight-ntwrk/wallet-sdk-dust-wallet` | 1.0.0 |

Dev dependencies: `typescript ^5.9.3`, `tsx ^4.21.0`, `@types/node ^22.0.0`

Counter template requires Compact compiler >= 0.28.0 (current: compactc-v0.29.0).

## Toolchain Versions

| Component | Version | Install/Update |
|-----------|---------|----------------|
| Compact compiler | compactc-v0.29.0 | `compact update` |
| create-mn-app | 0.3.19 | `npx create-mn-app@latest` |
| Proof server Docker image | midnightntwrk/proof-server:7.0.0 | Via Docker |
| Node.js | 22+ required | https://nodejs.org/ |

## Network Endpoints (Preprod)

| Service | URL |
|---------|-----|
| Indexer | `https://indexer.preprod.midnight.network` |
| RPC | `https://rpc.preprod.midnight.network` |
| Faucet | `https://faucet.preprod.midnight.network/` |
| Docs | `https://docs.midnight.network` |

## Verifying Versions

If these versions appear outdated, use the Midnight MCP server to check current versions:

- `midnight-get-version-info` with repo `compact` for compiler version
- `midnight-get-version-info` with repo `midnight-js` for SDK version
- `midnight-get-latest-updates` for recent changes across all repos
```

**Step 2: Verify the file was created**

```bash
wc -l plugins/compact-core/skills/compact-init-project/references/project-structure.md
```

Expected: ~130-150 lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-init-project/references/project-structure.md
git commit -m "feat(compact-core): add project-structure reference for compact-init-project"
```

---

### Task 4: Create references/troubleshooting.md

**Files:**
- Create: `plugins/compact-core/skills/compact-init-project/references/troubleshooting.md`

**Step 1: Write the troubleshooting reference**

```markdown
# Project Initialization Troubleshooting

Common failures when creating a new Midnight project and how to resolve them.

## Scaffolding Failures

### `npx create-mn-app` fails or hangs

**Symptoms:** Command not found, network errors, npm cache issues.

**Fixes:**
1. Verify Node.js version: `node --version` (must be 22+)
2. Clear npm cache: `npm cache clean --force`
3. Try with explicit registry: `npx --registry https://registry.npmjs.org create-mn-app@latest <name>`
4. If behind a proxy, configure npm: `npm config set proxy <url>`

### Directory already exists

**Symptom:** `create-mn-app` prompts about existing directory.

**Fix:** Choose a different project name, or approve the overwrite prompt. To remove manually: `rm -rf <project-name>` then retry.

### Git clone fails (counter template)

**Symptom:** Error cloning `midnightntwrk/example-counter`.

**Fixes:**
1. Test connectivity: `git ls-remote https://github.com/midnightntwrk/example-counter.git`
2. If behind a firewall, ensure GitHub access is allowed
3. If SSH issues, ensure HTTPS is used (create-mn-app uses HTTPS by default)

### Compact compiler not found (counter template)

**Symptom:** `create-mn-app` reports Compact compiler not installed or version too old.

**Fixes:**
1. Install the Compact CLI: run `/midnight-tooling:install-cli`
2. Update to latest compiler: `compact update`
3. If a specific version is required: `compact update 0.28.0`
4. Verify: `compact compile --version`

### Compact compiler version mismatch (counter template)

**Symptom:** `create-mn-app` reports compiler version below required minimum (0.28.0).

**Fixes:**
1. Update compiler: `compact update`
2. `create-mn-app` will offer to auto-update — accept when prompted
3. If auto-update fails: `compact self update` then `compact update`

## Compilation Failures

### `pragma language_version` error

**Symptom:** Compiler rejects the pragma directive.

**Fixes:**
1. Update compiler: `compact update`
2. Verify the pragma in the `.compact` file matches a supported version
3. The hello-world template uses `pragma language_version >= 0.16;` which is compatible with all recent compilers

### ZK parameter download stalls or fails

**Symptom:** First compilation hangs at "downloading ZK parameters" or fails with timeout.

**Fixes:**
1. First compilation downloads ~500MB of ZK parameters — this is normal and takes several minutes
2. Ensure stable internet connection
3. If Docker resources are limited, increase Docker Desktop memory to 4+ GB
4. Retry the compilation — partial downloads are cached

### Compilation succeeds but managed directory is empty

**Symptom:** `contracts/managed/hello-world/` or `contract/src/managed/counter/` exists but is missing expected subdirectories.

**Fixes:**
1. Check compiler output for warnings or errors
2. Run compilation with verbose output: `compact compile --trace-passes <source> <target>`
3. Ensure the target directory path is correct (different for hello-world vs counter)
4. Clean and retry: `rm -rf contracts/managed && npm run compile`

## Proof Server Failures

### Docker not running

**Symptom:** `/midnight-tooling:run-proof-server` fails with Docker errors.

**Fixes:**
1. Start Docker Desktop
2. On Linux: `sudo systemctl start docker`
3. Verify: `docker info`
4. Run `/midnight-tooling:doctor` for detailed diagnostics

### Port 6300 already in use

**Symptom:** Proof server fails to start with "port already allocated" error.

**Fixes:**
1. Find what's using the port: `lsof -i :6300` (macOS/Linux) or `ss -tlnp | grep 6300` (Linux)
2. Stop the conflicting process or container
3. If it's an old proof server container: `docker stop midnight-proof-server && docker rm midnight-proof-server`
4. Retry starting the proof server

### Container exits immediately

**Symptom:** Proof server container starts then stops within seconds.

**Fixes:**
1. Check logs: `docker logs midnight-proof-server`
2. Increase Docker memory allocation to 4–8 GB (Docker Desktop → Settings → Resources)
3. The proof server needs at least 4 GB RAM
4. Check for OOM kill: `docker inspect midnight-proof-server --format='{{.State.OOMKilled}}'`

### Health check fails

**Symptom:** Container is running but `curl http://localhost:6300/health` fails.

**Fixes:**
1. Wait 30–60 seconds — the proof server takes time to initialize
2. Check if the container is still starting: `docker logs -f midnight-proof-server`
3. The `/ready` endpoint returns HTTP 503 while loading ZK parameters
4. Monitor readiness: `curl http://localhost:6300/ready`

## Cross-References

For deeper troubleshooting beyond project initialization:
- Run `/midnight-tooling:doctor` for comprehensive environment diagnostics
- Consult the `midnight-tooling:troubleshooting` skill for error-specific guidance
- Consult the `midnight-tooling:compact-cli` skill for CLI-specific issues
- Consult the `midnight-tooling:proof-server` skill for Docker and proof server issues
```

**Step 2: Verify the file was created**

```bash
wc -l plugins/compact-core/skills/compact-init-project/references/troubleshooting.md
```

Expected: ~100-120 lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-init-project/references/troubleshooting.md
git commit -m "feat(compact-core): add troubleshooting reference for compact-init-project"
```

---

### Task 5: Create SKILL.md

This is the entry point. It must have YAML frontmatter with `name` and `description` fields matching the pattern in existing compact-core skills (see `plugins/compact-core/skills/compact-structure/SKILL.md` for the exact format).

**Files:**
- Create: `plugins/compact-core/skills/compact-init-project/SKILL.md`

**Step 1: Write the SKILL.md**

```markdown
---
name: compact-init-project
description: This skill should be used when the user asks to create a new Midnight project, scaffold a Compact smart contract project, use create-mn-app, initialize a DApp, set up a new Midnight application, start a new project, use a project template, set up hello-world or counter template, or is doing first-time Midnight development environment setup. Also triggered by "new project", "start a project", "init project", "create-mn-app", or "scaffold".
---

# Initialize a New Midnight/Compact Project

This skill guides you through creating a new Midnight project using `create-mn-app`, the official scaffolding tool. Follow the workflow in `references/create-mn-app-workflow.md` step by step.

## Supported Templates

| Template | Type | Description |
|----------|------|-------------|
| **Hello World** | Bundled | Simple message storage contract. Best for first-time Midnight developers. |
| **Counter** | Remote (clone) | Increment/decrement counter with ZK proofs. Demonstrates state management and npm workspaces. |

## Quick Start

Follow `references/create-mn-app-workflow.md` phases in order:

1. **Environment Check** — Run `/midnight-tooling:doctor` to verify Node 22+, Docker, and Compact CLI
2. **Template Selection** — Ask user which template (hello-world or counter)
3. **Scaffolding** — Run `npx create-mn-app@latest <name> --template <template>`
4. **Proof Server** — Run `/midnight-tooling:run-proof-server` to start Docker proof server
5. **Compile** — Compile the Compact contract and verify managed output
6. **Summary** — Show what was created and next steps

## Key Dependencies

This skill delegates to midnight-tooling plugin commands:
- `/midnight-tooling:doctor` — prerequisite verification
- `/midnight-tooling:run-proof-server` — Docker proof server lifecycle
- `/midnight-tooling:install-cli` — Compact compiler installation (if needed)

## Not For

- Existing project troubleshooting → use `midnight-tooling:troubleshooting`
- Writing custom Compact contracts → use `compact-structure`, `compact-ledger`, etc.
- Deploying to Preprod → out of scope (involves wallet creation and faucet funding)
- Adding features to an existing project → use domain-specific compact-core skills

## Reference Files

| Topic | Reference |
|-------|-----------|
| Step-by-step workflow (follow this) | `references/create-mn-app-workflow.md` |
| Project layouts, SDK versions, network URLs | `references/project-structure.md` |
| Common init failures and fixes | `references/troubleshooting.md` |
```

**Step 2: Verify the file was created**

```bash
wc -l plugins/compact-core/skills/compact-init-project/SKILL.md
```

Expected: ~50-60 lines

**Step 3: Commit**

```bash
git add plugins/compact-core/skills/compact-init-project/SKILL.md
git commit -m "feat(compact-core): add SKILL.md for compact-init-project"
```

---

### Task 6: Update plugin.json with new keywords

**Files:**
- Modify: `plugins/compact-core/.claude-plugin/plugin.json`

**Step 1: Read current plugin.json**

```bash
cat plugins/compact-core/.claude-plugin/plugin.json
```

**Step 2: Add new keywords to the keywords array**

Add these keywords to the existing array (append after `"compiler-generated"`):

```json
"create-mn-app",
"project-setup",
"scaffolding",
"init-project",
"hello-world",
"counter-template"
```

The full updated keywords array should be:

```json
"keywords": [
    "midnight",
    "compact",
    "smart-contracts",
    "zero-knowledge",
    "ledger",
    "circuits",
    "witnesses",
    "zk-proofs",
    "tokens",
    "shielded",
    "unshielded",
    "zswap",
    "standard-library",
    "stdlib",
    "elliptic-curve",
    "merkle-tree",
    "cryptographic",
    "privacy",
    "disclosure",
    "disclose",
    "witness-protection",
    "commitment",
    "nullifier",
    "selective-disclosure",
    "commit-reveal",
    "anonymous-auth",
    "merkle-proof",
    "witness-typescript",
    "WitnessContext",
    "private-state",
    "type-mapping",
    "compact-runtime",
    "contract-class",
    "pureCircuits",
    "compiler-generated",
    "create-mn-app",
    "project-setup",
    "scaffolding",
    "init-project",
    "hello-world",
    "counter-template"
  ]
```

**Step 3: Commit**

```bash
git add plugins/compact-core/.claude-plugin/plugin.json
git commit -m "feat(compact-core): add init-project keywords to plugin.json"
```

---

### Task 7: Final verification

**Step 1: Verify complete file structure**

```bash
find plugins/compact-core/skills/compact-init-project -type f | sort
```

Expected output:
```
plugins/compact-core/skills/compact-init-project/SKILL.md
plugins/compact-core/skills/compact-init-project/references/create-mn-app-workflow.md
plugins/compact-core/skills/compact-init-project/references/project-structure.md
plugins/compact-core/skills/compact-init-project/references/troubleshooting.md
```

**Step 2: Verify SKILL.md frontmatter parses correctly**

```bash
head -3 plugins/compact-core/skills/compact-init-project/SKILL.md
```

Expected: Lines starting with `---`, `name: compact-init-project`, `description: ...`

**Step 3: Verify plugin.json is valid JSON**

```bash
python3 -c "import json; json.load(open('plugins/compact-core/.claude-plugin/plugin.json')); print('Valid JSON')"
```

Expected: `Valid JSON`

**Step 4: Check git log for all commits**

```bash
git log --oneline -6
```

Expected: 5 new commits (workflow ref, project-structure ref, troubleshooting ref, SKILL.md, plugin.json update)
