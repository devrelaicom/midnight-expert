# Node Diagnostics and Deployment

Worked, executed diagnostic RPC calls against a running node, plus deployment templates. The diagnostic outputs below are real captured responses.

> **Captured against:** the local devnet node `midnightntwrk/midnight-node:0.22.5` (the devnet's node image), 2026-06, over `http://127.0.0.1:9944`. **This is a different version than the documented node 1.0.0** — `state_getRuntimeVersion` below reports `specVersion 22000` (the 0.22.x line), whereas node 1.0.0 reports `specVersion 1000000`. The RPC *shapes* shown here are stable across both; treat the node-1.0.0 source as authoritative for version-specific facts. The node serves JSON-RPC over both HTTP and WebSocket on port 9944. To start the stack, see `midnight-tooling:devnet`.

## Health & sync diagnostics (safe RPCs)

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_health","params":[]}'
{"jsonrpc":"2.0","id":1,"result":{"peers":0,"isSyncing":false,"shouldHavePeers":false}}

$ # system_syncState — starting / current / highest block
{"jsonrpc":"2.0","id":1,"result":{"startingBlock":63107,"currentBlock":63962,"highestBlock":63962}}

$ # system_version
{"jsonrpc":"2.0","id":1,"result":"0.22.5-31b06338"}

$ # system_chain / system_chainType / system_nodeRoles
{"jsonrpc":"2.0","id":1,"result":"undeployed1"}
{"jsonrpc":"2.0","id":1,"result":"Local"}
{"jsonrpc":"2.0","id":1,"result":["Authority"]}
```

On this single-node devnet `peers` is `0` and `shouldHavePeers` is `false` (a solo authority). On a real network, watch `peers` and `isSyncing`. `currentBlock == highestBlock` means the node is at the tip.

## Runtime version

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"state_getRuntimeVersion","params":[]}'
{"jsonrpc":"2.0","id":1,"result":{
  "specName":"midnight","implName":"midnight",
  "authoringVersion":1,"specVersion":22000,"implVersion":0,
  "apis":[["0xf78b278be53f454c",2], ["0xdf6acb689907609b",5], …],   // 24 entries
  "transactionVersion":2,"systemVersion":1,"stateVersion":1}}
```

`specVersion 22000` is the devnet's 0.22.x runtime. **Node 1.0.0 reports `specVersion 1000000` and `transactionVersion 3`** (see `midnight-node:node-architecture`).

## Finality diagnostics

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"chain_getFinalizedHead","params":[]}'
{"jsonrpc":"2.0","id":1,"result":"0xd676656e6cc8ce077380c9c8c9bd7001a74c9b6f62a0d134ffbbde0d94847019"}

$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"grandpa_roundState","params":[]}'
{"jsonrpc":"2.0","id":1,"result":{
  "setId":280,
  "best":{"round":1000,"totalWeight":10,"thresholdWeight":7,
          "prevotes":{"currentWeight":10,"missing":[]},
          "precommits":{"currentWeight":0,"missing":["5FA9nQDVg267DEd8m1ZypXLBnvN7SFxYwV7ndqSYGiN9TTpu"]}},
  "background":[]}}
```

`grandpa_roundState` shows the live GRANDPA round: `thresholdWeight` (here 7 of `totalWeight` 10) is the weight needed to finalize. A `prevotes`/`precommits` `missing` list that never clears points at offline voters. If `chain_getFinalizedHead` stops advancing while best blocks climb, finality has stalled — check peers and validator keys.

## A note on unsafe RPCs

Some diagnostic methods are classified **unsafe** and are rejected unless the node is started with `--rpc-methods=unsafe`. On the default (safe) devnet:

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"system_peers","params":[]}'
{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"RPC call is unsafe to be called externally"}}
```

`system_peers`, the `network_*` peer-reputation methods, and the `author_*` keystore methods are all unsafe. Expose them only on a trusted interface (never with `--rpc-external --rpc-cors all` in production).

## Diagnostic one-liners

```bash
N=http://localhost:9944
call(){ curl -s $N -H 'content-type: application/json' -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":[]}"; echo; }
call system_health        # peers / isSyncing / shouldHavePeers
call system_syncState     # startingBlock / currentBlock / highestBlock
call chain_getFinalizedHead
call grandpa_roundState   # finality round + voter weights
call state_getRuntimeVersion
```

## Deployment templates

### Docker

```bash
docker run -d --name midnight-node \
  -p 9944:9944 -p 30333:30333 -p 9615:9615 \
  -v midnight-data:/data \
  -e CFG_PRESET=preview \
  midnightntwrk/midnight-node:<version> \
  midnight-node --prometheus-external
```

Replace `<version>` with the release tag for your target network (see `midnight-tooling:release-notes`). The `/data` and `/keys` mount conventions come from the separate `midnight-node-docker` repository, not the node source.

### systemd unit (full node)

```ini
[Unit]
Description=Midnight Node
After=network-online.target
Wants=network-online.target

[Service]
Environment=CFG_PRESET=preview
ExecStart=/usr/local/bin/midnight-node --name "%H" --prometheus-external
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
# memory_threshold (config) triggers a graceful shutdown; systemd restarts the unit
User=midnight
StateDirectory=midnight

[Install]
WantedBy=multi-user.target
```

The node's memory monitor (`memory_threshold`) shuts the process down gracefully when available memory drops below the configured floor; `Restart=on-failure` then brings it back. See `references/metrics-and-monitoring.md` for the monitor details.

## Cross-references

- `references/metrics-and-monitoring.md` — Prometheus metrics, remote-write push, memory/storage monitors
- `midnight-node:node-rpc-api` → `examples/custom-rpc-calls.md` — executed Midnight-specific RPC calls against the same devnet
- `midnight-node:node-configuration` — `--validator`, `--rpc-methods`, pruning, and the full flag set
- `midnight-tooling:devnet` — starting and stopping the local devnet node
