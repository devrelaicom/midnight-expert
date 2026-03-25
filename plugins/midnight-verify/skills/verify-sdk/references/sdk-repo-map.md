# Midnight SDK — Package to Repository Map

When verifying an SDK API signature, type definition, or package behavior, and MCP search plus skill references are insufficient, use this table to find the package's source repository. Navigate to the package directory within the monorepo.

Use the `midnight-tooling` plugin's GitHub tools (`githubViewRepoStructure`, `githubSearchCode`, `githubGetFileContent`) to navigate these repositories.

## SDK Packages (midnight-js monorepo)

All `@midnight-ntwrk/midnight-js-*` packages live in a single monorepo:

| Package | What To Verify Here |
|---|---|
| `@midnight-ntwrk/midnight-js-contracts` | Contract deployment, call builders, provider interfaces |
| `@midnight-ntwrk/midnight-js-types` | Core type definitions, network types |
| `@midnight-ntwrk/midnight-js-network-id` | Network ID constants |
| `@midnight-ntwrk/midnight-js-indexer-public-data-provider` | Indexer provider implementation |
| `@midnight-ntwrk/midnight-js-http-client-proof-provider` | Proof provider implementation |
| `@midnight-ntwrk/midnight-js-level-private-state-provider` | LevelDB private state |
| `@midnight-ntwrk/midnight-js-node-zk-config-provider` | Node ZK config loading |
| `@midnight-ntwrk/midnight-js-fetch-zk-config-provider` | Browser ZK config fetching |
| `@midnight-ntwrk/midnight-js-logger-provider` | Logging interface |
| `@midnight-ntwrk/midnight-js-utils` | Utility functions |
| `@midnight-ntwrk/dapp-connector-api` | DApp <-> wallet connector types |
| `@midnight-ntwrk/compact-js` | Compact language types in TypeScript |
| `@midnight-ntwrk/testkit-js` | Testing utilities |

**Repository:** [midnightntwrk/midnight-js](https://github.com/midnightntwrk/midnight-js)

## Other SDK Repositories

| Component | Repository | What To Verify Here |
|---|---|---|
| Midnight SDK (umbrella) | [midnightntwrk/midnight-sdk](https://github.com/midnightntwrk/midnight-sdk) | SDK orchestration, managed by terraform |
| Wallet core | [midnightntwrk/midnight-wallet](https://github.com/midnightntwrk/midnight-wallet) | Wallet internals, signing |
| Indexer (backend) | [midnightntwrk/midnight-indexer](https://github.com/midnightntwrk/midnight-indexer) | Indexer API, GraphQL schema |
