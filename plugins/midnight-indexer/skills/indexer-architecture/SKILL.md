---
name: indexer-architecture
description: This skill should be used when the user asks about indexer architecture, indexer components, chain-indexer, wallet-indexer, indexer-api, spo-indexer, standalone mode, cloud mode, indexer configuration, indexer deployment, indexer storage, PostgreSQL vs SQLite, NATS, indexer telemetry, or indexer node connection.
version: 0.1.0
---

# Indexer Architecture

The Midnight indexer is a Rust application (edition 2024) built with async-graphql, axum, and subxt. It connects to a Midnight node via WebSocket, indexes on-chain data into a database, and exposes it through a GraphQL API.

**Current version:** 4.0.0 (released 2026-03-17)

## Component Overview

```text
┌──────────────────────────────────────────────────────────────────┐
│                      Midnight Indexer                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   │
│  │ chain-indexer  │──→│       DB       │←──│  indexer-api   │   │
│  │ (node via WS)  │   │ (Postgres/     │   │  (GraphQL      │   │
│  │                │   │  SQLite)       │   │   :8088)       │   │
│  └────────────────┘   └────────────────┘   └────────────────┘   │
│                                                                  │
│  ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   │
│  │ wallet-indexer │   │  spo-indexer   │   │ indexer-common │   │
│  │ (wallet        │   │ (stake pool    │   │ (shared types/ │   │
│  │  correlation)  │   │  via Blockfrost│   │  migrations)   │   │
│  └────────────────┘   └────────────────┘   └────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ indexer-standalone (all-in-one with SQLite)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Purpose |
|-----------|---------|
| `chain-indexer` | Connects to node via WebSocket, subscribes to new blocks, writes indexed data to DB |
| `wallet-indexer` | Correlates wallet sessions with relevant transactions |
| `indexer-api` | Serves the GraphQL API on port 8088 |
| `spo-indexer` | Indexes stake pool operator data via Blockfrost |
| `indexer-standalone` | All-in-one binary bundling all components with SQLite storage |
| `indexer-common` | Shared types, database migrations, and utilities |

## Data Flow

```text
Midnight Node (ws://localhost:9944)
        │
        ▼
  Chain Indexer ──→ Database (PostgreSQL or SQLite)
                         │
                         ▼
                    Indexer API (GraphQL :8088)
                         │
                         ▼
                    DApp / Wallet
```

## Deployment Modes

### Cloud Mode

- **Storage:** PostgreSQL 17 + NATS for inter-component messaging
- **Components:** Run chain-indexer, wallet-indexer, indexer-api, and spo-indexer as separate services
- **Use case:** Production deployments, high availability

### Standalone Mode

- **Storage:** SQLite (single file)
- **Components:** Single `indexer-standalone` binary bundles everything
- **Use case:** Local development, devnet, testing

## Configuration

All configuration uses environment variables with the `APP__` prefix and double-underscore nesting.

### Core Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `APP__APPLICATION__NETWORK_ID` | `undeployed` | Network identifier |
| `APP__INFRA__STORAGE__CNN_URL` | `/data/indexer.sqlite` | SQLite path (standalone) or PostgreSQL connection URL (cloud) |
| `APP__INFRA__NODE__URL` | `ws://localhost:9944` | Node WebSocket endpoint |
| `APP__INFRA__API__PORT` | `8088` | GraphQL API port |
| `APP__INFRA__SECRET` | (required) | 32-byte hex encryption secret for wallet viewing keys |

### Operational Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `blocks_buffer` | 10 | Number of blocks to buffer during indexing |
| `caught_up_max_distance` | 10 | Max blocks behind tip to consider "caught up" |
| `active_wallets_ttl` | 30 minutes | Time-to-live for inactive wallet sessions |
| `transaction_batch_size` | 50 | Transactions processed per batch |
| Node reconnection | Exponential backoff, max 30 attempts | Automatic reconnection on WebSocket disconnect |
| Subscription recovery timeout | 30 seconds | Timeout for recovering dropped subscriptions |

## Node Connection

The indexer connects to a Midnight node via WebSocket on port 9944 using the `subxt` Rust library. It subscribes to new finalized blocks and processes them sequentially, extracting transactions, contract actions, and ledger events.

## Telemetry

Both telemetry systems are disabled by default.

| System | Protocol | Default Port | Purpose |
|--------|----------|-------------|---------|
| OpenTelemetry | OTLP | — | Distributed tracing |
| Prometheus | HTTP scrape | 9000 | Metrics collection |

## Cross-References

- `midnight-tooling:devnet` — Manages the indexer as part of the local development stack
- `compact-core:compact-deployment` — Uses the indexer as a provider for contract state queries
