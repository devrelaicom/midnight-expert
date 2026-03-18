# HTTP Request Examples

Complete `curl` examples for the indexer GraphQL HTTP endpoint. All examples target a local indexer; replace the URL for other networks (see network endpoints in SKILL.md).

## Query Latest Block

```bash
curl -X POST http://localhost:8088/api/v4/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ block { hash height timestamp transactions { hash identifier } } }"
  }'
```

Expected response:

```json
{
  "data": {
    "block": {
      "hash": "0x1a2b3c...",
      "height": 12345,
      "timestamp": "2025-01-15T10:30:00Z",
      "transactions": [
        {
          "hash": "0xabc123...",
          "identifier": "tx-id-1"
        }
      ]
    }
  }
}
```

## Query Contract Actions

```bash
curl -X POST http://localhost:8088/api/v4/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ contractAction(address: \"0xYOUR_CONTRACT_ADDRESS\") { ... on ContractDeploy { address state transaction { hash } } ... on ContractCall { address entryPoint state unshieldedBalances { tokenType value } } } }"
  }'
```

## Connect Wallet (Mutation)

Establish a wallet session for shielded transaction scanning:

```bash
curl -X POST http://localhost:8088/api/v4/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { connect(viewingKey: \"YOUR_BECH32M_VIEWING_KEY\") }"
  }'
```

Expected response:

```json
{
  "data": {
    "connect": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
}
```

The returned string is the session ID. Use it with the `shieldedTransactions` subscription or the `disconnect` mutation.

## Disconnect Wallet (Mutation)

End an active wallet session:

```bash
curl -X POST http://localhost:8088/api/v4/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "mutation { disconnect(sessionId: \"a1b2c3d4-e5f6-7890-abcd-ef1234567890\") }"
  }'
```
