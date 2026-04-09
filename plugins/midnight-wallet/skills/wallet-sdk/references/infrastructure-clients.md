# Infrastructure Clients

The wallet SDK connects to three backend services. Each has a dedicated client package.

## Architecture

| Service       | Purpose                              | Protocol        | Default URL                        |
|---------------|--------------------------------------|-----------------|------------------------------------|
| Indexer       | Blockchain state sync and queries    | GraphQL (WS+HTTP) | `http://localhost:8088/api/v4/graphql` (HTTP), `ws://localhost:8088/api/v4/graphql/ws` (WS) |
| Node          | Transaction submission               | WebSocket (Substrate RPC) | `ws://localhost:9944`     |
| Proof Server  | Zero-knowledge proof generation      | HTTP             | `http://localhost:6300`           |

## Indexer Client

**Package:** `@midnight-ntwrk/wallet-sdk-indexer-client`
**Protocol:** GraphQL over WebSocket (subscriptions) and HTTP (queries)

The indexer client is not used directly in most DApp code. The wallet manages
the indexer connection internally for state synchronization.

Monitor sync progress through the wallet's state observable:

```typescript
wallet.state().subscribe((state) => {
  // Each sub-wallet has its own SyncProgress
  const shieldedProgress = state.shielded.progress;
  const unshieldedProgress = state.unshielded.progress;
  const dustProgress = state.dust.progress;

  console.log(`Shielded: ${shieldedProgress.appliedIndex}/${shieldedProgress.highestIndex}`);
  console.log(`Synced: ${state.isSynced}`);
});
```

> **Tip:** If transactions appear missing, check `state.isSynced` and the
> individual `progress` fields to confirm the wallet has caught up with the chain head.

## Node Client

**Package:** `@midnight-ntwrk/wallet-sdk-node-client`
**Class:** `PolkadotNodeClient`

The node client has two entry points: the main export wraps the Effect layer and exposes
an `Observable`-based API, while the `/effect` sub-path exposes the raw Effect-ts API where
`sendMidnightTransaction` returns `Stream.Stream`.

```typescript
import { PolkadotNodeClient } from '@midnight-ntwrk/wallet-sdk-node-client/effect';

// sendMidnightTransaction signature:
// sendMidnightTransaction(
//   serializedTransaction: SerializedTransaction
// ): Stream.Stream<SubmissionEvent, NodeClientError>
```

The stream emits `SubmissionEvent` variants as the transaction progresses:

- `Submitted` — transaction accepted into the mempool
- `InBlock` — included in a block (with `blockHash` and `blockHeight`)
- `Finalized` — reached finality

In most DApp code, prefer `wallet.submitTransaction()` over calling the node
client directly. The wallet handles serialization, signing, and error recovery.

> **See also:** [wallet-construction.md](wallet-construction.md) for how `relayURL` is configured in `DefaultConfiguration`.

## Proof Server (Prover Client)

**Package:** `@midnight-ntwrk/wallet-sdk-prover-client`
**Class:** `HttpProverClient`

The prover client sends unproven transactions to the proof server over HTTP:

```typescript
import { HttpProverClient } from '@midnight-ntwrk/wallet-sdk-prover-client';

const prover = new HttpProverClient({
  url: new URL('http://localhost:6300'),
});

// proveTransaction signature:
// proveTransaction<S extends Signaturish, B extends Bindingish>(
//   transaction: Transaction<S, PreProof, B>,
//   costModel?: CostModel
// ): Promise<Transaction<S, Proof, B>>
const provenTx = await prover.proveTransaction(unprovenTx);
```

The proof server runs the ZK circuit to generate a SNARK proof for each
transaction. This is the most time-consuming step in the transaction pipeline.

**WASM alternative:** For browser environments or offline proving, the
`@midnight-ntwrk/wallet-sdk-prover-client` package also exports a WASM-based
prover through its capabilities package. This avoids the need for a separate
proof server process but is significantly slower.

> **See also:** [transactions.md](transactions.md) for how proving fits into
> the transaction lifecycle, and the `midnight-tooling:proof-server` skill for
> proof server management.

## Address Encoding

**Package:** `@midnight-ntwrk/wallet-sdk-address-format`
**Class:** `MidnightBech32m`

Midnight uses Bech32m encoding with a static `"mn"` prefix for all addresses.
The `MidnightBech32m` class provides static methods for encoding and parsing.

### Encoding an address

```typescript
import { MidnightBech32m, UnshieldedAddress } from '@midnight-ntwrk/wallet-sdk-address-format';

// MidnightBech32m.encode is static:
// static encode<T extends HasCodec<T>>(networkId: NetworkId, item: T): MidnightBech32m
const encoded = MidnightBech32m.encode('testnet', address);
const bech32String = encoded.asString();
// => "mn_addr_testnet1..."
```

### Parsing and decoding

```typescript
// MidnightBech32m.parse is static — returns a MidnightBech32m instance:
// static parse(bech32string: string): MidnightBech32m
const parsed = MidnightBech32m.parse('mn_addr_testnet1...');

// decode is an instance method — converts back to the typed object:
// decode<TClass extends HasCodec<any>>(tclass: TClass, networkId: NetworkId): CodecTarget<TClass>
const address = parsed.decode(UnshieldedAddress, 'testnet');
```

### Keystore and public keys

The `createKeystore` function lives in `@midnight-ntwrk/wallet-sdk-unshielded-wallet`,
not in the address-format package:

```typescript
import { createKeystore, PublicKey } from '@midnight-ntwrk/wallet-sdk-unshielded-wallet';

const keystore = createKeystore(secretKey, 'testnet');

// PublicKey.fromKeyStore extracts the public key, hex address, and bech32 address
const pubkey = PublicKey.fromKeyStore(keystore);
// => { publicKey, addressHex, address }
```

The `UnshieldedKeystore` interface provides:

- `signData(data: Uint8Array): Signature` — sign arbitrary data
- `getBech32Address(): MidnightBech32m` — the encoded address
- `getPublicKey(): SignatureVerifyingKey` — the raw public key

> **See also:** [key-derivation.md](key-derivation.md) for how secret keys are
> derived from seed phrases, and [wallet-construction.md](wallet-construction.md)
> for passing the keystore to the wallet builder.
