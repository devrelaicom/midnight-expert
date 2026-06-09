# Executed Subscription Examples

Worked, executed WebSocket subscription walkthroughs against a live indexer. Each block below is real captured output, not illustrative.

> **Captured against:** the local devnet's indexer `midnightntwrk/indexer-standalone:4.2.1` (node `0.22.5`), 2026-06, over `ws://127.0.0.1:8088/api/v4/graphql/ws`. The devnet image is one minor behind the `4.3.3` source documented elsewhere; the subscriptions shown here have a stable shape across both. One version-specific argument-name difference is noted at the end. To start the stack, see `midnight-tooling:devnet`.

## Transport: `graphql-transport-ws`

Subscriptions are **WebSocket-only** — POSTing one over HTTP returns `"Subscriptions are not supported on this transport."`. The endpoint speaks the [`graphql-transport-ws`](https://github.com/enisdenjo/graphql-ws/blob/master/PROTOCOL.md) sub-protocol. The handshake is:

```text
client ──connection_init──▶ server
client ◀──connection_ack─── server
client ──subscribe (id, query)──▶ server
client ◀──next (id, payload)──── server      (repeated per event)
client ──complete (id)──▶ server             (to stop)
client ◀──complete (id)──── server
```

### Reproducible client

The captures below were produced with this minimal Node client (`npm i ws`):

```js
const WebSocket = require('ws');
const ws = new WebSocket('ws://127.0.0.1:8088/api/v4/graphql/ws', 'graphql-transport-ws');
const query = 'subscription { blocks { height hash timestamp } }';
ws.on('open', () => ws.send(JSON.stringify({ type: 'connection_init' })));
ws.on('message', (raw) => {
  const msg = JSON.parse(raw);
  if (msg.type === 'connection_ack')
    ws.send(JSON.stringify({ id: '1', type: 'subscribe', payload: { query } }));
  else if (msg.type === 'next')
    console.log(JSON.stringify(msg.payload.data));
});
```

In the browser, use the `graphql-ws` library with the same protocol; the SDK's `indexerPublicDataProvider` handles this for you (see `midnight-dapp-dev:midnight-sdk`).

## Example 1 — `blocks`: stream every new block

```text
SEND  {"type":"connection_init"}
RECV  {"type":"connection_ack"}
SEND  {"id":"1","type":"subscribe","payload":{"query":
        "subscription { blocks { height hash timestamp protocolVersion author transactions { hash } } }"}}

RECV  {"type":"next","id":"1","payload":{"data":{"blocks":{
        "height":63436,
        "hash":"d901a55620ce35603d4a061b30a81d6f14a70a6e96b48c0afc01ed931d1ee4ad",
        "timestamp":1781002794006,"protocolVersion":22000,
        "author":"d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d",
        "transactions":[]}}}}

RECV  {"type":"next","id":"1","payload":{"data":{"blocks":{
        "height":63437,
        "hash":"5a548e60e009b5c295cc9fd01ea6f6d6a57d6e9189cfec0853ad472bca9cab40",
        "timestamp":1781002800010,"protocolVersion":22000,
        "author":"d43593c715fdd31c61141abd04a99fd6822c8558854ccde39a5684e7a56da27d",
        "transactions":[]}}}}

SEND  {"id":"1","type":"complete"}
RECV  {"type":"complete","id":"1"}
```

The two blocks are consecutive (63436 → 63437) and their timestamps differ by `1781002800010 − 1781002794006 = 6004 ms` — the devnet's ~6-second slot time. `transactions` is `[]` because these devnet blocks carry no regular transactions. `transactions` returns the `Transaction` **interface**; to select `RegularTransaction`-only fields like `identifiers`, use an inline fragment `... on RegularTransaction { identifiers }`.

Pass `blocks(offset: { height: N })` (or `{ hash: "0x…" }`) to replay from a specific block instead of starting at the live tip.

## Example 2 — `zswapLedgerEvents`: resumable ledger-event stream

Ledger-event subscriptions take an optional `id` cursor and **replay from that id**, then continue live. Each event carries `id`, `maxId` (the highest event id currently stored — a progress/high-water mark), `protocolVersion`, and a `raw` serialized blob.

```text
SEND  {"id":"1","type":"subscribe","payload":{"query":
        "subscription { zswapLedgerEvents(id: 0) { id maxId protocolVersion raw } }"}}

RECV  {"type":"next","id":"1","payload":{"data":{"zswapLedgerEvents":{
        "id":2,"maxId":29,"protocolVersion":22000,
        "raw":"6d69646e696768743a6576656e745b76395d3a0400b9042e… (650 hex chars)"}}}}
RECV  {"type":"next","id":"1","payload":{"data":{"zswapLedgerEvents":{
        "id":3,"maxId":29,"protocolVersion":22000,"raw":"6d69646e696768743a…"}}}}
RECV  {"type":"next","id":"1","payload":{"data":{"zswapLedgerEvents":{
        "id":4,"maxId":29,"protocolVersion":22000,"raw":"6d69646e696768743a…"}}}}
        … continues through id 21 (the stored backlog), then waits for new events …
```

- **`id` cursor:** `id: 0` replays the whole backlog; pass the last `id` you processed to resume exactly after it. This is how a client recovers after a disconnect without missing or double-processing events.
- **`maxId`:** the highest stored event id (here `29`) — compare your current `id` against it to gauge how far behind you are.
- **`raw`:** a hex-encoded tagged-serialized event. The prefix `6d69646e696768743a6576656e745b76395d3a` decodes to ASCII `midnight:event[v9]:` — the `midnight-serialize` tag header. Decode it with the ledger event types; the GraphQL layer does not pre-parse it for zswap events.

## Example 3 — `dustLedgerEvents`: interface + inline fragments

`dustLedgerEvents` returns the `DustLedgerEvent` **interface**, whose concrete types are `DustInitialUtxo`, `DustGenerationDtimeUpdate`, `DustSpendProcessed`, and `ParamChange`. Use `__typename` (and inline fragments for type-specific fields) to discriminate:

```text
SEND  {"id":"1","type":"subscribe","payload":{"query":
        "subscription { dustLedgerEvents(id: 0) {
           id maxId protocolVersion
           __typename
           ... on DustInitialUtxo { __typename }
           ... on DustGenerationDtimeUpdate { __typename }
           ... on DustSpendProcessed { __typename }
           ... on ParamChange { __typename } } }"}}

RECV  {"type":"next","id":"1","payload":{"data":{"dustLedgerEvents":{
        "id":1,"maxId":128,"protocolVersion":22000,"__typename":"ParamChange"}}}}
RECV  {"type":"next","id":"1","payload":{"data":{"dustLedgerEvents":{
        "id":30,"maxId":128,"protocolVersion":22000,"__typename":"DustInitialUtxo"}}}}
RECV  {"type":"next","id":"1","payload":{"data":{"dustLedgerEvents":{
        "id":31,"maxId":128,"protocolVersion":22000,"__typename":"DustInitialUtxo"}}}}
        … continues with further DustInitialUtxo events up to maxId 128 …
```

The devnet's DUST backlog begins with a `ParamChange` (the initial DUST parameters, event id `1`) followed by a run of `DustInitialUtxo` events (each NIGHT UTXO registered for DUST generation). For the storage-side model behind these events see `midnight-indexer:indexer-data-model` → `references/dust-and-spo-data.md`.

## Notes and caveats

- **Stop a subscription** by sending `{"id":"…","type":"complete"}`; the server acks with its own `complete`. A buffered backlog already in flight may deliver a few more `next` frames before the `complete` settles.
- **Version-specific argument name:** on this `4.2.1` devnet, `dustNullifierTransactions` takes `nullifierPrefixes`. In the documented `4.3.3` schema it was renamed to `nullifierLeBytesPrefixes` (while `shieldedNullifierTransactions` keeps `nullifierPrefixes`). Always check `references/schema-reference.md` for the exact argument names of your target version.
- **`@beta` DUST surface:** `dustGenerations`, the DUST commitment/generation Merkle-tree updates, and the `*StartIndex`/`*EndIndex` fields are marked `@beta` and may change — see `references/dust-beta-api.md`.
- **Transport:** these only work over the `/api/v4/graphql/ws` WebSocket endpoint; the HTTP POST endpoint rejects subscriptions.

## Cross-references

- `references/pagination-and-offsets.md` — the `offset` / `id` / `transactionId` resumption arguments for each subscription
- `references/schema-reference.md` — exact argument names and return types for all 9 subscriptions
- `references/dust-beta-api.md` — the `@beta` DUST subscription surface
- `examples/websocket-subscriptions.md` — TypeScript `graphql-ws` client setup
- `midnight-indexer:indexer-operations` → `examples/running-standalone.md` — HTTP queries and health probes against the same devnet
- `midnight-dapp-dev:midnight-sdk` — the SDK's `indexerPublicDataProvider`, which manages these subscriptions for you
