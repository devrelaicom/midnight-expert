# midnight-node

<p align="center">
  <img src="assets/mascot.png" alt="midnight-node mascot" width="200" />
</p>

Technical reference for the Midnight node -- Substrate-based architecture, runtime pallets, RPC interface, configuration, operations, and governance.

## Skills

### midnight-node:node-architecture

Covers the Midnight node's Substrate runtime, Polkadot SDK foundation, runtime pallets, consensus mechanisms (AURA, GRANDPA, BEEFY), ledger storage with ParityDB, transaction lifecycle, ZK proof verification, Cardano partner chain integration, and source layout.

### midnight-node:node-configuration

Covers CLI flags, environment variables, TOML presets, chain spec files, network selection (qanet, preview, preprod, perfnet, devnet), validator key setup, Substrate pruning and RPC flags, and debugging configuration with SHOW_CONFIG.

### midnight-node:node-governance

Covers the federated authority governance model, Council and Technical Committee, governance motions, voting with a 5-day window, two-body approval, D-parameter management, runtime upgrades, and Cardano mainchain governance sync.

### midnight-node:node-operations

Covers running modes (validator, full node, archive, dev), Docker deployment, Prometheus metrics, monitoring, graceful shutdown, P2P networking, bootnodes, node keys, and troubleshooting common issues like sync failures and memory problems.

### midnight-node:node-rpc-api

Covers the JSON-RPC API over WebSocket on port 9944, approximately 68 methods across multiple modules, Midnight-specific endpoints (midnight_contractState, midnight_zswapStateRoot, midnight_ledgerStateRoot), OpenRPC discovery, and subscription support.
