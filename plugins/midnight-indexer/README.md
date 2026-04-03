# midnight-indexer

<p align="center">
  <img src="assets/mascot.png" alt="midnight-indexer mascot" width="200" />
</p>

Technical reference for the Midnight indexer -- architecture, GraphQL API, data model, and operational guidance for querying on-chain state.

## Skills

### midnight-indexer:indexer-architecture

Covers the indexer's Rust-based component architecture (chain-indexer, wallet-indexer, indexer-api, spo-indexer), standalone vs cloud deployment modes, database options (PostgreSQL vs SQLite), node connection via WebSocket, and configuration.

### midnight-indexer:indexer-data-model

Covers what the indexer indexes across nine data categories (blocks, transactions, contract actions, contract balances, unshielded UTXOs, ledger events, DUST generation, system parameters, and SPO data), the database schema, and entity relationships.

### midnight-indexer:indexer-graphql-api

Covers the GraphQL API for querying on-chain state, managing wallet sessions, and subscribing to real-time events. Includes HTTP and WebSocket endpoints on port 8088, query limits (complexity 200, depth 15), and the v3/v4 API paths.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [error-handling.md](skills/indexer-graphql-api/references/error-handling.md) | Common error responses from the GraphQL API and how to resolve them | When troubleshooting complexity limit, depth limit, or request size errors |
| [graphql-types.md](skills/indexer-graphql-api/references/graphql-types.md) | Key types returned by the indexer GraphQL API (Block, Transaction, etc.) | When constructing queries or understanding the shape of API responses |
| [pagination-and-offsets.md](skills/indexer-graphql-api/references/pagination-and-offsets.md) | Offset-based addressing for queries and subscriptions using BlockOffset and other offset types | When paginating results or specifying starting points for subscriptions |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [http-requests.md](skills/indexer-graphql-api/examples/http-requests.md) | Complete curl examples for the indexer GraphQL HTTP endpoint | When making HTTP POST queries against the indexer |
| [websocket-subscriptions.md](skills/indexer-graphql-api/examples/websocket-subscriptions.md) | TypeScript examples using graphql-ws for real-time subscriptions | When setting up WebSocket subscriptions to indexer events |
