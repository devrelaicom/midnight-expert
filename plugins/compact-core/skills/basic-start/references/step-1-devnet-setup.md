> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.

## Step 1: Devnet Setup

### What this verifies

Docker is running and the three devnet services (node, indexer, proof server) start and respond to health checks.

### Procedure

1. Generate the Docker Compose file:
   ```
   /midnight-tooling:devnet generate
   ```
   This creates `devnet.yml` with the latest stable versions of the Midnight node, indexer, and proof server.

2. Start the devnet:
   ```bash
   docker compose -f devnet.yml up -d
   ```

3. Check containers are running:
   ```bash
   docker compose -f devnet.yml ps
   ```
   All three services (node, indexer, proof-server) should show as running.

4. Health check — Node (should return HTTP 200 with JSON):
   ```bash
   curl -sf http://localhost:9944/health
   ```

5. Health check — Proof Server (should return HTTP 200):
   ```bash
   curl -sf http://localhost:6300/health
   ```

6. Health check — Indexer. This is a GraphQL endpoint (POST only), so use an introspection query:
   ```bash
   curl -sf -X POST http://localhost:8088/api/v3/graphql \
     -H "Content-Type: application/json" \
     -d '{"query": "{ __typename }"}'
   ```
   Should return `{"data":{"__typename":"Query"}}`.

7. Verify indexer sync status. The introspection query only confirms the indexer HTTP server is up — it doesn't mean it has finished syncing chain data. Compare the node's block height with the indexer's latest indexed block:

   Node height (hex to decimal):
   ```bash
   curl -sf -X POST http://localhost:9944 \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc":"2.0","id":1,"method":"chain_getHeader","params":[]}' \
     | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result']['number'],16))"
   ```

   Indexer height:
   ```bash
   curl -sf -X POST http://localhost:8088/api/v3/graphql \
     -H "Content-Type: application/json" \
     -d '{"query": "{ block { height } }"}' \
     | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['block']['height'])"
   ```

   If they are within 1-2 blocks of each other, the indexer is synced and ready. If the indexer is significantly behind, wait a moment and re-check. Wallet operations (like airdrop in step 3) may time out if the indexer hasn't caught up.

### Expected output

All three containers running. Node and proof server health checks return 200. Indexer responds to GraphQL. Block heights within 1-2 of each other.

> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.
