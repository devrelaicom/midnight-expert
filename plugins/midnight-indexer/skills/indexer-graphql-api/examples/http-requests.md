# HTTP Request Examples

Complete `curl` examples for the indexer GraphQL HTTP endpoint. All examples target a local indexer; replace the URL for other networks (see network endpoints in SKILL.md).

## Query Latest Block

```bash
curl -X POST http://localhost:8088/api/v4/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "{ block { hash height timestamp transactions { hash ... on RegularTransaction { identifiers } } } }"
  }'
```

Expected response (note: `timestamp` is a UNIX timestamp in milliseconds, and `identifiers` is an array):

```json
{
  "data": {
    "block": {
      "hash": "1a2b3c...",
      "height": 12345,
      "timestamp": 1736937000000,
      "transactions": [
        {
          "hash": "abc123...",
          "identifiers": ["def456..."]
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
    "query": "{ contractAction(address: \"YOUR_CONTRACT_ADDRESS_HEX\") { ... on ContractDeploy { address state transaction { hash } } ... on ContractCall { address entryPoint state unshieldedBalances { tokenType amount } } } }"
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
    "connect": "a1b2c3d4e5f6..."
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
    "query": "mutation { disconnect(sessionId: \"a1b2c3d4e5f6...\") }"
  }'
```
