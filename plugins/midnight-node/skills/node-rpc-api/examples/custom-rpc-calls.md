# Custom RPC Calls — Executed

Worked, executed calls to the Midnight-specific RPC methods. The responses below are real captured output and confirm the documented return types.

> **Captured against:** the local devnet node `midnightntwrk/midnight-node:0.22.5` over `http://127.0.0.1:9944`, 2026-06. **This is a different version than the documented node 1.0.0** (the devnet reports `specVersion 22000`; 1.0.0 is `specVersion 1000000`). The method names, parameters, and return *types* shown here match the 1.0.0 documentation; exact values are devnet-specific. For the authoritative per-method param/return spec at 1.0.0 see `references/custom-rpcs.md` (16 custom methods) and `references/substrate-rpcs.md` (52 standard). The node serves JSON-RPC over both HTTP and WebSocket on 9944 — these examples use `curl` over HTTP; the SKILL's `wscat -c ws://localhost:9944 -x '…'` form is equivalent.

## `midnight_*` — ledger and version

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"midnight_ledgerVersion","params":[]}'
{"jsonrpc":"2.0","id":1,"result":"=8.0.2"}
```
`midnight_ledgerVersion` returns a **`String`** (here the ledger semver requirement `"=8.0.2"`) — not a `u32`. Confirms the documented return type.

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"midnight_apiVersions","params":[]}'
{"jsonrpc":"2.0","id":1,"result":[2]}
```
`midnight_apiVersions` returns **`Vec<u32>`**, currently `[2]` — the RPC protocol version, distinct from the runtime API version.

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"midnight_zswapStateRoot","params":[]}'
{"jsonrpc":"2.0","id":1,"result":[115,179,91,218,141,247,2,162,64,242,183,96,91,202,62,164,
                                  247,189,180,17,15,92,109,53,197,142,213,18,250,247,105,115,3]}
```
`midnight_zswapStateRoot` (and `midnight_ledgerStateRoot`) return a **`Vec<u8>`** byte array (33 bytes here), not a hex string. `midnight_contractState` (omitted — needs a deployed contract address) returns a hex `String`.

## `systemParameters_*` — governance parameters

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"systemParameters_getDParameter","params":[]}'
{"jsonrpc":"2.0","id":1,"result":{"numPermissionedCandidates":10,"numRegisteredCandidates":0}}
```
The D-parameter is the **`(num_permissioned, num_registered)` tuple** — here `(10, 0)`, a fully federated committee. It is NOT a `0.0`–`1.0` scalar. See `midnight-node:node-governance`.

```text
$ # systemParameters_getAriadneParameters requires a mainchain epoch_number
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"systemParameters_getAriadneParameters","params":[20613]}'
{"jsonrpc":"2.0","id":1,"result":{
  "dParameter":{"numPermissionedCandidates":10,"numRegisteredCandidates":0},
  "permissionedCandidates":[{"sidechainPublicKey":"0x020a1091341fe5664bfa1782d5e0477968…"}, …],
  "candidateRegistrations":{}}}
```
`systemParameters_getAriadneParameters` takes a required `epoch_number` (mainchain epoch) and an optional `d_parameter_at` block hash. It returns the D-parameter plus the candidate pools used by Ariadne selection. See `midnight-node:node-validator`.

## `sidechain_*` — partner-chain status

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"sidechain_getParams","params":[]}'
{"jsonrpc":"2.0","id":1,"result":{"genesis_utxo":"c684d0f7f5fb537d4996032a01a55511f3029cda9bcfc9a76b68e7b12d5a461a#6"}}

$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"sidechain_getStatus","params":[]}'
{"jsonrpc":"2.0","id":1,"result":{
  "sidechain":{"epoch":989447,"slot":296834325,"nextEpochTimestamp":1781006400000},
  "mainchain":{"epoch":20613,"slot":89050297,"nextEpochTimestamp":3447705600000}}}
```
`sidechain_getStatus` reports the current sidechain (Midnight) and mainchain (Cardano) epoch/slot — useful for confirming the main-chain follower is tracking Cardano.

## Deprecated and unsafe methods

```text
$ # sidechain_getAriadneParameters still works but is DEPRECATED — use systemParameters_getAriadneParameters
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"sidechain_getAriadneParameters","params":[20613]}'
{"jsonrpc":"2.0","id":1,"result":{"dParameter":{"numPermissionedCandidates":6,"numRegisteredCandidates":0}, …}}
```

```text
$ # network_* peer-reputation and author_*/system_peers methods are UNSAFE
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"network_peerReputations","params":[]}'
{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"RPC call is unsafe to be called externally"}}
```
The `network_*` methods (`peerReputations`, `peerReputation`, `unbanPeer`) require the node to be started with `--rpc-methods=unsafe`. The default devnet runs safe-only.

## OpenRPC discovery — a version difference

```text
$ curl -s http://127.0.0.1:9944 -H 'content-type: application/json' \
    -d '{"jsonrpc":"2.0","id":1,"method":"rpc.discover","params":[]}'
{"jsonrpc":"2.0","id":1,"error":{"code":-32601,"message":"Method not found"}}
```
On this `0.22.5` devnet, `rpc.discover` is **not registered** (`Method not found`). At node **1.0.0** the OpenRPC document is published (`docs/openrpc.json`, 68 methods = 16 custom + 52 standard) and `rpc.discover` returns it — a genuine version difference. For the full 1.0.0 method inventory and exact params/returns, use `references/custom-rpcs.md` and `references/substrate-rpcs.md` rather than `rpc.discover` against an older node.

## Cross-references

- `references/custom-rpcs.md` — the 16 custom methods at node 1.0.0, each with exact params and return types
- `references/substrate-rpcs.md` — the 52 standard Substrate methods
- `midnight-node:node-validator` — how the D-parameter and Ariadne parameters drive committee selection
- `midnight-node:node-governance` — the D-parameter `(u16,u16)` governance model
- `midnight-node:node-operations` → `examples/diagnostics-and-deployment.md` — executed `system_*` / `grandpa_*` diagnostics against the same devnet
