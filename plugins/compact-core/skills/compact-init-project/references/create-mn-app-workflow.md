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
3. For Docker issues: refer to `/midnight-tooling:proof-server` skill
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

Start the local devnet (which includes the proof server) using the midnight-tooling command:

Run `/midnight-tooling:devnet start`

This starts the three Docker containers (node, indexer, proof server). The proof server runs on port 6300. The command handles:
- Resolving stable Docker image tags
- Starting the containers
- Waiting for them to come up

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

**Note:** First compilation downloads ZK parameters (a large download). This may take several minutes depending on network speed.

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
4. DUST is generated automatically by delegating tNight holdings

### Relevant skills for writing contracts

Point the user to these compact-core skills for customizing their contract:
- `compact-structure` — Contract anatomy, pragma, types, circuits, witnesses
- `compact-ledger` — On-chain state design, ADT operations
- `compact-privacy-disclosure` — Privacy patterns, disclose() rules
- `compact-witness-ts` — TypeScript witness implementation
