> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.

## Step 3: Wallet Setup

### What this verifies

Wallet creation, NIGHT token airdrop from the genesis wallet, and DUST registration all work on the local devnet.

### Procedure

1. Verify the indexer is synced before proceeding. Use the block height comparison from Step 1:

   Node height:

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

   Heights should be within 1-2 blocks. If not, wait and re-check.

2. Create a wallet using the `midnight_wallet_generate` MCP tool:
   - `name`: `"deployer"`
   - `network`: `"undeployed"`

   **Save the `seed` from the output** — you will need it for deployment scripts in later steps.

3. Airdrop NIGHT tokens using the `midnight_airdrop` MCP tool:
   - `amount`: `"10000"`
   - `wallet`: `"deployer"`
   - `no-cache`: `"true"`

   **Always use `no-cache: "true"` for airdrops.** Without it, the wallet CLI's client-side cache can cause sync timeouts, even when the indexer is healthy and fully synced.

4. Register DUST using the `midnight_dust_register` MCP tool:
   - `wallet`: `"deployer"`

   If this times out, wait 30 seconds and retry with `no-cache: "true"`.

5. Verify the NIGHT balance using the `midnight_balance` MCP tool:
   - `wallet`: `"deployer"`

   Should show `10000.000000` NIGHT.

6. Verify DUST status using the `midnight_dust_status` MCP tool:
   - `wallet`: `"deployer"`

   `dustAvailable` should be `true` with a positive `dustBalance`.

### Expected output

Wallet created with an `undeployed` address and seed. Airdrop returns a transaction hash. DUST registration succeeds with a positive balance. Balance check confirms 10000 NIGHT. Dust status shows `dustAvailable: true`.

> **EPHEMERAL** — All code and files produced by this walkthrough are disposable. Do not commit, push, or retain any of it. Delete everything when done.
