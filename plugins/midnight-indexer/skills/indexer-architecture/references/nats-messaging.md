# NATS Messaging — Deep Dive

This reference adds source-level depth to the NATS pub-sub section of the `midnight-indexer:indexer-architecture` skill. It covers the trait abstraction, both concrete implementations, exact payload fields, the self-healing subscriber loop, per-component wiring, and reconnect configuration. The skill covers the high-level overview; this file covers the why and how.

## The Pub-Sub Abstraction (`indexer-common/src/domain/pub_sub.rs`)

All pub-sub interaction goes through two sealed traits and one sealed marker:

```text
Message (sealed)
  ├── BlockIndexed           TOPIC = "BlockIndexed"
  ├── WalletIndexed          TOPIC = "WalletIndexed"
  └── UnshieldedUtxoIndexed  TOPIC = "UnshieldedUtxoIndexed"

Publisher (trait_variant::make(Send))
  └── async fn publish<T: Message>(&self, message: &T) -> Result<(), Self::Error>

Subscriber (trait_variant::make(Send))
  └── fn subscribe<T: Message>(&self) -> impl Stream<Item = Result<T, Self::Error>>
```

The `Message` trait (`domain/pub_sub.rs:34–38`) is sealed with the `sealed::Sealed` bound, so the three message types are the only valid implementations. Each type carries its own `TOPIC` constant via the `message!` macro (`domain/pub_sub.rs:23–31`), which becomes the NATS subject name before `ToSubject` prepends `pub-sub.`.

`Publisher` and `Subscriber` use `#[trait_variant::make(Send)]` to generate `Send`-compatible variants (`domain/pub_sub.rs:69–98`), allowing both to be used across Tokio task boundaries with no unsafe code.

A `NoopSubscriber` (`domain/pub_sub.rs:100–113`) produces an empty stream. It exists so components that never subscribe can satisfy the type parameter without a real implementation.

## The Two Implementations

Both implementations are gated by Cargo features: `cloud` → NATS; `standalone` → in-process. This means a build never links both simultaneously (`infra/pub_sub.rs:14–19`).

### NATS (`infra/pub_sub/nats/`)

| Type | File | Role |
|------|------|------|
| `NatsPublisher` | `nats/publisher.rs:25` | Wraps `async_nats::Client`; publishes JSON bytes to the NATS subject |
| `NatsSubscriber` | `nats/subscriber.rs:29` | Wraps `async_nats::Client`; returns a self-healing stream per topic |
| `Config` | `nats.rs:23–29` | `url`, `username`, `password: SecretString`, `max_reconnects: usize` |

Both publisher and subscriber are constructed with identical `ConnectOptions` setup (`max_reconnects`, `user_and_password`, `event_callback`). They share the same event callback that maps all `async_nats::Event` variants to `debug!`/`warn!` log lines.

**Serialization:** `NatsPublisher::publish` calls `serde_json::to_vec(message)?.into()` and passes the resulting bytes to `client.publish(T::TOPIC, payload)` (`nats/publisher.rs:62–68`). `NatsSubscriber` deserializes with `serde_json::from_slice(&message.payload)` (`nats/subscriber.rs:82`). The wire format is compact JSON with no envelope — just the struct fields.

### In-Process Tokio Broadcast (`infra/pub_sub/in_mem/`)

| Type | File | Role |
|------|------|------|
| `InMemPubSub` | `in_mem.rs:27` | Factory; owns three `broadcast::Sender<Value>` (capacity 42 each) |
| `InMemPublisher` | `in_mem/publisher.rs:24` | `match T::TOPIC` → send to the correct sender |
| `InMemSubscriber` | `in_mem/subscriber.rs:25` | `match T::TOPIC` → subscribe the correct sender; wraps in `BroadcastStream` |

`InMemPubSub::default()` (`in_mem.rs:46–68`) creates the three broadcast channels, then spawns one drain task per channel (`spawn_drain`) that keeps a receiver alive. Without the drain task, a sender with zero active receivers would return `SendError` on every publish. The drain task loops on `receiver.recv()` and logs a warning on `RecvError::Lagged` but does not break — ensuring the channel stays open even when no external subscriber is attached (`in_mem.rs:71–86`). Channel capacity of 42 is sufficient for normal operation; if the drain task lags (e.g., 1000 publishes in a tight loop without yields), `RecvError::Lagged` is returned and the drain task skips ahead without invalidating the receiver.

**Serialization:** Both `InMemPublisher` and `InMemSubscriber` round-trip through `serde_json::Value` (`in_mem/publisher.rs:40`, `in_mem/subscriber.rs:62–64`). This mirrors the NATS wire format so that message structs are always validated by their `Serialize`/`Deserialize` bounds on both paths.

## Payload Structs (exact fields)

All three types derive `Serialize, Deserialize` — JSON field names match the Rust field names exactly.

### `BlockIndexed` (`domain/pub_sub.rs:46–50`)

```rust
pub struct BlockIndexed {
    pub height: u64,
    pub max_transaction_id: Option<u64>,
    pub caught_up: bool,
}
```

`height` is the block number. `max_transaction_id` is the highest transaction-table row ID saved in the same DB write as the block — it is `None` when the block contained no transactions. `caught_up` is `true` once the chain-indexer's block lag drops within `caught_up_max_distance` of the node tip. The `wallet-indexer` uses `max_transaction_id` to short-circuit re-scanning: it stores the last seen value and skips `index_wallet` when the DB has advanced no further (`wallet-indexer/src/application.rs:66–84`).

### `WalletIndexed` (`domain/pub_sub.rs:55–57`)

```rust
pub struct WalletIndexed {
    pub wallet_id: Uuid,
}
```

UUID of the wallet session that received new relevant transactions. The `indexer-api` uses this to push shielded-transaction subscription updates to connected GraphQL clients.

### `UnshieldedUtxoIndexed` (`domain/pub_sub.rs:63–65`)

```rust
pub struct UnshieldedUtxoIndexed {
    pub address: UnshieldedAddress,
}
```

One message is published per unique owner address that appears in created or spent unshielded UTXOs within a block (`chain-indexer/src/application.rs:484–501`). The `indexer-api` uses this to push unshielded-transaction subscription updates.

## Self-Healing Subscriber Loop

Core NATS (not JetStream) subscriptions can silently complete — the inner stream ends without an error when the connection drops. `NatsSubscriber::subscribe` wraps around this with an outer infinite throttled stream (`nats/subscriber.rs:63–87`):

```text
stream::repeat(())
    │
    ├── throttled by REPEAT_DELAY = 100ms        ← nats/subscriber.rs:25
    │
    └── for each tick:
            │
            ├── client.subscribe(T::TOPIC)        ← issues a fresh SUBSCRIBE command
            │
            └── flatten the inner message stream  ← messages flow until it completes
                    │
                    └── when inner stream ends → outer loop ticks again after 100ms
                            → re-subscribes automatically
```

`REPEAT_DELAY` is defined as `const REPEAT_DELAY: Duration = Duration::from_millis(100)` (`nats/subscriber.rs:25`). The outer `stream::repeat(())` is throttled — not a busy spin — so during normal operation it issues one `SUBSCRIBE` command and then stays inside the `try_flatten` consuming the resulting inner stream indefinitely.

**What happens on a dropped connection:** The inner NATS subscription stream completes. `try_flatten` exhausts it, the outer loop ticks after 100ms, and `client.subscribe(T::TOPIC)` is called again. If NATS is still unreachable, `SubscribeError` is emitted as a stream item error; the outer loop retries 100ms later. The `async_nats::Client` itself has already attempted `max_reconnects` reconnections at the TCP level before surfacing the drop to the application. Once the NATS server is back, the next outer tick succeeds, and the subscription is live again.

**No data is lost** even though messages published during a subscriber's downtime are gone (core NATS is at-most-once, `-js` flag enables JetStream on the server but the indexer never creates JetStream consumers). The `wallet-indexer` recovers by polling the DB for active wallets on a configurable `active_wallets_query_delay` interval, independent of whether any `BlockIndexed` event arrived (`wallet-indexer/src/application.rs:168–204`). The `indexer-api` tracks `caught_up` from `BlockIndexed.caught_up` and will lag on the flag while disconnected, but GraphQL queries against the DB remain accurate.

## Publisher and Subscriber Wiring Per Component

### Cloud (NATS)

| Component | Constructs | Publishes | Subscribes |
|-----------|-----------|-----------|------------|
| `chain-indexer` | `NatsPublisher` only | `BlockIndexed`, `UnshieldedUtxoIndexed` | — |
| `wallet-indexer` | `NatsPublisher` + `NatsSubscriber` | `WalletIndexed` | `BlockIndexed` |
| `indexer-api` | `NatsSubscriber` only | — | `BlockIndexed`, `WalletIndexed`, `UnshieldedUtxoIndexed` |
| `spo-indexer` | neither | — | — |

Source citations:
- `chain-indexer/src/main.rs:112` — `NatsPublisher::new(pub_sub_config)`
- `wallet-indexer/src/main.rs:92,95` — `NatsPublisher::new` + `NatsSubscriber::new`
- `indexer-api/src/main.rs:103` — `NatsSubscriber::new(pub_sub_config)`
- `spo-indexer` contains no pub-sub references

The `indexer-api` subscribes `BlockIndexed` at two levels: once in `application::run` to track the `caught_up` flag (`indexer-api/src/application.rs:41`), and again inside each GraphQL subscription resolver (`infra/api/v4/subscription/block.rs:68`, `zswap_ledger_events.rs:59`, `dust_ledger_events.rs:59`, `contract_action.rs:70`, `dust_nullifier_transactions.rs:114`, `shielded_nullifier_transactions.rs:125`, `dust_generations.rs:140`). Each GraphQL subscription creates an independent call to `subscriber.subscribe::<BlockIndexed>()` — `NatsSubscriber` is `Clone` and each clone issues its own `SUBSCRIBE` to NATS.

### Standalone (In-Process)

`indexer-standalone/src/main.rs:123` creates a single `InMemPubSub::default()` instance. The chain-indexer and wallet-indexer both receive `pub_sub.publisher()` clones; the wallet-indexer and indexer-api both receive `pub_sub.subscriber()` clones (`standalone/src/main.rs:137,162,171`). All clones share the same three `broadcast::Sender` handles.

## Reconnect Configuration

```text
max_reconnects = 4   (chain-indexer/config.yaml:28,
                      wallet-indexer/config.yaml:27,
                      indexer-api/config.yaml:25)
```

This value is passed directly to `ConnectOptions::max_reconnects(max_reconnects)` in both `NatsPublisher::new` and `NatsSubscriber::new`. It controls the number of TCP-level reconnect attempts the `async_nats::Client` makes after an established connection drops — not the application-level subscription resubscribe loop (which is independent and unbounded). After 4 failed TCP reconnect attempts the client moves to the `Closed` state; the `NATS client closed` warning is emitted, and subsequent `publish` calls begin returning `PublishError`. The self-healing subscriber loop continues trying to call `client.subscribe()` every 100ms but those calls will fail as `SubscribeError` until the process is restarted.

Override with `APP__INFRA__PUB_SUB__MAX_RECONNECTS`.

## Docker NATS Launch

```text
# docker-compose.yaml:164–170
nats:
  profiles: [cloud]
  image: "nats:2.12.3"
  restart: "always"
  command: ["--user", "indexer", "--pass", $APP__INFRA__PUB_SUB__PASSWORD, "-js"]
  ports: ["4222:4222"]
```

`-js` enables JetStream on the server (required for the NATS image to start without error in some configurations), but the indexer never creates JetStream streams or consumers — it uses only the core NATS `subscribe`/`publish` API. Authentication is plaintext username/password; there is no TLS configuration in the default compose file.

The `APP__INFRA__PUB_SUB__PASSWORD` env var must be set externally (e.g., `openssl rand -hex 32`). The username is fixed to `indexer` in all three component `config.yaml` files and in the NATS server command. It can be overridden with `APP__INFRA__PUB_SUB__USERNAME`.

## Cross-references

- `midnight-indexer:indexer-architecture` — overview table, failure modes, env vars, NATS events log
- `midnight-tooling:devnet` — starting the local Docker stack (includes the NATS container)
- `midnight-indexer:indexer-data-model` — database schema that forms the fallback polling source
