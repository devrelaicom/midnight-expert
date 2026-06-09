# midnight-node

<p align="center">
  <img src="assets/mascot.png" alt="midnight-node mascot" width="200" />
</p>

Technical reference for the Midnight node -- Substrate-based architecture, runtime pallets, RPC interface, configuration, operations, and governance.

## Skills

### midnight-node:node-architecture

Covers the Midnight node's Substrate runtime, Polkadot SDK foundation, runtime pallets, consensus mechanisms (AURA, GRANDPA, BEEFY), ledger storage with ParityDB, transaction lifecycle, ZK proof verification, Cardano partner chain integration, and source layout.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [pallet-inventory.md](skills/node-architecture/references/pallet-inventory.md) | All 28 runtime pallets with `pallet_index`, crate, alias, role, and the key calls/storage of the 8 Midnight-local pallets | When identifying which pallet owns a behaviour |
| [consensus-and-finality.md](skills/node-architecture/references/consensus-and-finality.md) | AURA / GRANDPA / BEEFY / MMR deep-dive — key types, slot/epoch params, justification period, `SessionKeys`, BEEFY-not-wired status | When reasoning about block production, finality, or light-client proofs |
| [cardano-integration.md](skills/node-architecture/references/cardano-integration.md) | The Cardano partner-chain integration — db-sync follower, cNIGHT observation, NIGHT bridge, Ariadne committee selection, SSL modes | When working on cross-chain data flow |

### midnight-node:node-configuration

Covers CLI flags, environment variables, TOML presets, chain spec files, network selection (qanet, preview, preprod, perfnet, devnet), validator key setup, Substrate pruning and RPC flags, and debugging configuration with SHOW_CONFIG.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [configuration-reference.md](skills/node-configuration/references/configuration-reference.md) | The complete config-key catalog from `node/src/cfg/**` + `res/cfg/default.toml`: every key with type, default, and `CFG_PRESET`/env-var layering | When looking up any config key or its default |
| [chain-spec-and-presets.md](skills/node-configuration/references/chain-spec-and-presets.md) | The 11 `res/cfg` presets, genesis JSON files, and the `CFG_PRESET` vs `--chain` selection mechanism | When choosing a network or assembling a chain spec |
| [validator-keys.md](skills/node-configuration/references/validator-keys.md) | The 3 validator session keys (AURA/GRANDPA/CROSS_CHAIN), KeyTypeIds, `SessionKeys`, key insertion/rotation, BEEFY-not-wired status | When provisioning validator keys |

### midnight-node:node-governance

Covers the federated authority governance model, Council and Technical Committee, governance motions, voting with a 5-day window, two-body approval, D-parameter management, runtime upgrades, and Cardano mainchain governance sync.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [governance-internals.md](skills/node-governance/references/governance-internals.md) | Pallet-level governance mechanics: the two collective instances, membership origins, the federated-authority proportion origin, motion lifecycle, and D-parameter storage | When auditing the governance flow or building governance tooling |

### midnight-node:node-operations

Covers running modes (validator, full node, archive, dev), Docker deployment, Prometheus metrics, monitoring, graceful shutdown, P2P networking, bootnodes, node keys, and troubleshooting common issues like sync failures and memory problems.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [metrics-and-monitoring.md](skills/node-operations/references/metrics-and-monitoring.md) | The node's observability surface: Prometheus scrape metrics, remote-write push, memory/storage monitors, and log signals | When setting up monitoring or interpreting metrics |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [diagnostics-and-deployment.md](skills/node-operations/examples/diagnostics-and-deployment.md) | Executed diagnostic RPC calls (health, sync, finality) with real output, plus Docker and systemd deployment templates | When checking node health or deploying a node |

### midnight-node:node-rpc-api

Covers the JSON-RPC API over WebSocket on port 9944, approximately 68 methods across multiple modules, Midnight-specific endpoints (midnight_contractState, midnight_zswapStateRoot, midnight_ledgerStateRoot), OpenRPC discovery, and subscription support.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [custom-rpcs.md](skills/node-rpc-api/references/custom-rpcs.md) | The 16 Midnight-specific RPC methods with exact params and return types | When calling a custom RPC or checking its signature |
| [substrate-rpcs.md](skills/node-rpc-api/references/substrate-rpcs.md) | The 52 standard Substrate RPC methods grouped by module | When using a standard `system_`/`chain_`/`state_`/`author_` method |

#### Examples

| Name | Description | When it is used |
|------|-------------|-----------------|
| [custom-rpc-calls.md](skills/node-rpc-api/examples/custom-rpc-calls.md) | Executed `midnight_*` / `systemParameters_*` / `sidechain_*` calls with real captured output, plus the `rpc.discover` version difference | When constructing a custom RPC request or verifying a return type |

### midnight-node:node-validator

Covers running a Midnight validator end-to-end -- generating the three session keys, becoming a permissioned (federated) or registered (staked) candidate, committee selection via the D-parameter and Ariadne, committee rotation per Cardano epoch, producing blocks with --validator, and local testing with the mock main-chain follower.

#### References

| Name | Description | When it is used |
|------|-------------|-----------------|
| [committee-and-candidates.md](skills/node-validator/references/committee-and-candidates.md) | The two candidate pools (permissioned vs registered), the D-parameter, Ariadne selection, committee storage and rotation, and live-vs-mock data sources | When investigating committee selection or candidate eligibility |
