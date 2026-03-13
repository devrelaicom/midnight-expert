# Deployment Troubleshooting

Common errors and their solutions when deploying and interacting with Compact contracts. For provider setup details, see `references/network-and-providers.md`. For wallet configuration, see `references/wallet-setup.md`.

## WebSocket Polyfill (Node.js)

**Symptom:** `ReferenceError: WebSocket is not defined` or indexer subscriptions fail silently.

**Cause:** Node.js does not have a built-in `WebSocket` global. The indexer provider uses GraphQL subscriptions over WebSocket.

**Fix:** Add at the top of your entry point, before any SDK imports:

```typescript
import { WebSocket } from "ws";
globalThis.WebSocket = WebSocket as unknown as typeof globalThis.WebSocket;
```

This is only needed in Node.js environments. Browsers have `WebSocket` natively.

## Proof Server Not Running

**Symptom:** `Error: connect ECONNREFUSED 127.0.0.1:6300` or proof generation hangs indefinitely.

**Cause:** The proof server Docker container is not running. All ZK proof generation requires the proof server.

**Fix:** Start the proof server:

```bash
docker run -p 6300:6300 midnightntwrk/proof-server:7.0.0 -- midnight-proof-server -v
```

Verify it is running:

```bash
curl http://localhost:6300/check
```

The proof server always runs locally, even when connecting to remote networks (Preview, Preprod). This protects private witness data from being transmitted over the network.

## Transaction Signing Workaround

**Symptom:** Transactions fail with signing-related errors, or `signRecipe` produces incorrect signatures for proven transactions.

**Cause:** A known issue in the wallet SDK where `signRecipe` hardcodes `'pre-proof'` as the proof marker instead of using `'proof'` for already-proven transactions.

**Fix:** Use the `signTransactionIntents` helper in your `balanceTx` implementation:

```typescript
import * as ledger from "@midnight-ntwrk/ledger";

function signTransactionIntents(
  tx: { intents?: Map<number, any> },
  signFn: (payload: Uint8Array) => ledger.Signature,
  proofMarker: "proof" | "pre-proof",
): void {
  if (!tx.intents || tx.intents.size === 0) return;

  for (const segment of tx.intents.keys()) {
    const intent = tx.intents.get(segment);
    if (!intent) continue;

    const cloned = ledger.Intent.deserialize<
      ledger.SignatureEnabled,
      ledger.Proofish,
      ledger.PreBinding
    >("signature", proofMarker, "pre-binding", intent.serialize());

    const sigData = cloned.signatureData(segment);
    const signature = signFn(sigData);

    // Sign all fallible and guaranteed unshielded offers
    for (const [offerIdx] of cloned.fallibleUnshieldedOffers.entries()) {
      cloned.signFallibleUnshieldedOffer(offerIdx, signature);
    }
    for (const [offerIdx] of cloned.guaranteedUnshieldedOffers.entries()) {
      cloned.signGuaranteedUnshieldedOffer(offerIdx, signature);
    }

    tx.intents.set(segment, cloned);
  }
}
```

Call this in your `balanceTx` implementation:

```typescript
// In the walletProvider.balanceTx implementation:
signTransactionIntents(recipe.baseTransaction, signFn, "proof");
if (recipe.balancingTransaction) {
  signTransactionIntents(recipe.balancingTransaction, signFn, "pre-proof");
}
```

## Wrong Network ID

**Symptom:** Cryptographic operations fail, transactions are rejected, or wallet sync produces garbage data.

**Cause:** `setNetworkId()` was called with the wrong value, or was not called before creating providers.

**Fix:** Ensure `setNetworkId()` is called **once, before any other SDK calls**:

```typescript
import { setNetworkId } from "@midnight-ntwrk/midnight-js-network-id";

// Must match the network you're connecting to
setNetworkId("undeployed"); // local Docker network
setNetworkId("preview");    // Preview testnet
setNetworkId("preprod");    // Pre-production testnet
```

Verify with:

```typescript
import { getNetworkId } from "@midnight-ntwrk/midnight-js-network-id";
console.log(`Current network: ${getNetworkId()}`);
```

## Insufficient Funds

**Symptom:** `Error: Insufficient DUST balance` or transaction balancing fails.

**Cause:** The wallet does not have enough DUST to pay transaction fees.

**Fix:**

1. **Get tNight from faucet** (test networks only):
   - Preview: `https://faucet.preview.midnight.network`
   - Preprod: `https://faucet.preprod.midnight.network`

2. **Wait for DUST generation:** DUST accrues from staked NIGHT over time. After receiving NIGHT, wait several blocks for DUST to begin accumulating.

3. **Check balance:**
   ```typescript
   const state = await wallet.state();
   const dustBalance = state.dust.walletBalance(new Date());
   console.log(`DUST balance: ${dustBalance}`);
   ```

## Deployment Timeout

**Symptom:** `deployContract` or `findDeployedContract` hangs indefinitely.

**Cause:** The indexer WebSocket subscription is not receiving events. Common causes:
- Incorrect indexer WebSocket URL
- Firewall blocking WebSocket connections
- Indexer service is down or not synced

**Fix:**

1. Verify the indexer is reachable:
   ```bash
   curl -X POST <indexer-graphql-url> \
     -H "Content-Type: application/json" \
     -d '{"query": "{ __typename }"}'
   ```

2. Check the WebSocket URL uses `ws://` (local) or `wss://` (remote), not `http://`

3. Ensure `globalThis.WebSocket` is set (see WebSocket Polyfill section above)

## Contract Not Found

**Symptom:** `findDeployedContract` never resolves or throws an error.

**Cause:** The contract address is incorrect, the contract was deployed on a different network, or the indexer has not yet indexed the deployment block.

**Fix:**

1. Verify the contract address is a valid hex string
2. Confirm you are connected to the same network where the contract was deployed
3. Ensure `setNetworkId()` matches the deployment network
4. Wait for the indexer to catch up — it may lag behind the node

## Error Types Reference

| Error Type | Package | Cause |
|-----------|---------|-------|
| `DeployTxFailedError` | `midnight-js-contracts` | Deployment transaction submitted but failed on-chain |
| `CallTxFailedError` | `midnight-js-contracts` | Circuit call transaction failed on-chain |
| `TxFailedError` | `midnight-js-contracts` | Base error class for transaction failures |
| `ContractTypeError` | `midnight-js-contracts` | Contract type mismatch between compiled and on-chain |
| `InsertVerifierKeyTxFailedError` | `midnight-js-contracts` | Verifier key submission failed |

All transaction errors include the `txId` and `blockHeight` where the failure occurred. Check the node logs or indexer for detailed failure reasons.
