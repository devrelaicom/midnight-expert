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
| Indexer (GraphQL) | `https://indexer.preprod.midnight.network/api/v3/graphql` |
| Indexer (WebSocket) | `wss://indexer.preprod.midnight.network/api/v3/graphql/ws` |
| RPC | `https://rpc.preprod.midnight.network` |
| Faucet | `https://faucet.preprod.midnight.network/` |
| Docs | `https://docs.midnight.network` |

## Verifying Versions

If these versions appear outdated, use the Midnight MCP server to check current versions:

- `midnight-get-version-info` with repo `compact` for compiler version
- `midnight-get-version-info` with repo `midnight-js` for SDK version
- `midnight-get-latest-updates` for recent changes across all repos
