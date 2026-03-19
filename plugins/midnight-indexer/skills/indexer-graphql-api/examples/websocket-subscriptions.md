# WebSocket Subscription Examples

TypeScript examples using the `graphql-ws` library to connect to the indexer subscription endpoint.

## Setup

Install the dependency:

```bash
npm install graphql-ws ws
```

## Subscribe to Blocks

Stream new blocks as they are produced:

```typescript
import { createClient } from "graphql-ws";
import WebSocket from "ws";

const client = createClient({
  url: "ws://localhost:8088/api/v4/graphql/ws",
  webSocketImpl: WebSocket,
});

const unsubscribe = client.subscribe(
  {
    query: `subscription {
      blocks {
        hash
        height
        timestamp
        transactions {
          hash
          identifier
        }
      }
    }`,
  },
  {
    next(data) {
      const block = data.data?.blocks;
      console.log(`Block #${block.height}: ${block.hash}`);
    },
    error(err) {
      console.error("Subscription error:", err);
    },
    complete() {
      console.log("Subscription complete");
    },
  },
);

// To stop the subscription later:
// unsubscribe();
```

## Subscribe to Shielded Transactions

Full connect, subscribe, and disconnect flow:

```typescript
import { createClient } from "graphql-ws";
import WebSocket from "ws";

const INDEXER_HTTP = "http://localhost:8088/api/v4/graphql";
const INDEXER_WS = "ws://localhost:8088/api/v4/graphql/ws";

async function monitorShieldedTransactions(viewingKey: string) {
  // Step 1: Connect wallet via HTTP mutation
  const connectResponse = await fetch(INDEXER_HTTP, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      query: `mutation { connect(viewingKey: "${viewingKey}") }`,
    }),
  });
  const { data } = await connectResponse.json();
  const sessionId = data.connect;
  console.log("Session ID:", sessionId);

  // Step 2: Subscribe via WebSocket
  const client = createClient({
    url: INDEXER_WS,
    webSocketImpl: WebSocket,
  });

  const unsubscribe = client.subscribe(
    {
      query: `subscription($sessionId: String!) {
        shieldedTransactions(sessionId: $sessionId) {
          transaction {
            hash
            identifier
            result
          }
          progress {
            current
            total
          }
        }
      }`,
      variables: { sessionId },
    },
    {
      next(data) {
        const { transaction, progress } = data.data?.shieldedTransactions;
        console.log(
          `[${progress.current}/${progress.total}] Transaction: ${transaction.hash}`,
        );
      },
      error(err) {
        console.error("Subscription error:", err);
      },
      complete() {
        console.log("Subscription complete (caught up with chain head)");
      },
    },
  );

  // Step 3: Disconnect when done
  async function cleanup() {
    unsubscribe();
    await fetch(INDEXER_HTTP, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        query: `mutation { disconnect(sessionId: "${sessionId}") }`,
      }),
    });
    console.log("Session disconnected");
  }

  // Disconnect on SIGINT
  process.on("SIGINT", async () => {
    await cleanup();
    process.exit(0);
  });
}

// Usage
monitorShieldedTransactions("bech32m_encoded_viewing_key_here");
```

## Resuming After Disconnection

When reconnecting after a WebSocket drop, use the offset parameter to avoid reprocessing:

```typescript
// Track the last received block height
let lastBlockHeight = 0;

function subscribeToBlocks(client: ReturnType<typeof createClient>) {
  return client.subscribe(
    {
      query: `subscription($offset: Int) {
        blocks(offset: $offset) {
          hash
          height
          timestamp
        }
      }`,
      variables: { offset: lastBlockHeight > 0 ? lastBlockHeight : null },
    },
    {
      next(data) {
        const block = data.data?.blocks;
        lastBlockHeight = block.height;
        console.log(`Block #${block.height}`);
      },
      error(err) {
        console.error("Error, reconnecting in 3s...", err);
        setTimeout(() => subscribeToBlocks(client), 3000);
      },
      complete() {
        console.log("Complete");
      },
    },
  );
}
```
