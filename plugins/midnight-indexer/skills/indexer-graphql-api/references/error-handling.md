# Error Handling

Common error responses from the indexer GraphQL API and how to resolve them.

## Complexity Limit Exceeded

The indexer enforces a maximum query complexity of **200**. Deeply nested or wide queries will be rejected before execution.

**Error response:**

```json
{
  "errors": [
    {
      "message": "Query is too complex. Maximum complexity is 200, but the query has a complexity of 350.",
      "extensions": {
        "code": "QUERY_TOO_COMPLEX"
      }
    }
  ]
}
```

**How to fix:**
- Remove unused fields from the selection set
- Avoid deeply nested relationships (e.g., `block > transactions > contractActions > transaction > ...`)
- Split one large query into multiple smaller queries
- Request only the fields you need from `Transaction` objects

## Invalid Session ID

Returned when a `sessionId` passed to `shieldedTransactions` or `disconnect` is expired, malformed, or was never created.

**Error response:**

```json
{
  "errors": [
    {
      "message": "Invalid session ID: session-uuid-here",
      "extensions": {
        "code": "INVALID_SESSION"
      }
    }
  ]
}
```

**How to fix:**
- Call the `connect` mutation with a valid viewing key to obtain a new session ID
- Session IDs do not persist across indexer restarts; reconnect after indexer downtime
- Ensure the session has not been explicitly disconnected via the `disconnect` mutation

## Malformed Query

Syntax errors in the GraphQL query are returned with position information.

**Error response:**

```json
{
  "errors": [
    {
      "message": "Syntax Error: Expected Name, found \"}\".",
      "locations": [
        {
          "line": 5,
          "column": 3
        }
      ]
    }
  ]
}
```

**How to fix:**
- Check for missing field names, unclosed braces, or invalid characters
- Validate the query using a GraphQL client (e.g., GraphiQL, Altair) before sending programmatically
- Ensure inline fragments (`... on TypeName`) reference valid type names (`ContractDeploy`, `ContractCall`, `ContractUpdate`)

## Max Depth Exceeded

The indexer enforces a maximum query depth of **15** levels.

**Error response:**

```json
{
  "errors": [
    {
      "message": "Query is too deep. Maximum depth is 15.",
      "extensions": {
        "code": "QUERY_TOO_DEEP"
      }
    }
  ]
}
```

**How to fix:**
- Flatten the query by removing unnecessary nesting
- Fetch deeply nested data in a separate follow-up query

## Subscription Errors

### WebSocket Connection Failure

If the client cannot establish a WebSocket connection, verify:

1. The URL uses the `/ws` suffix: `/api/v4/graphql/ws`
2. The correct protocol is specified: `graphql-transport-ws`
3. TLS is used for remote endpoints (`wss://` not `ws://`)

### Heartbeat Timeout

The WebSocket connection may be dropped if the client does not respond to server pings within the timeout window.

**Symptoms:** Subscription stops receiving events with no error message.

**How to fix:**
- Use a GraphQL WebSocket client library (e.g., `graphql-ws`) that handles ping/pong automatically
- Implement reconnection logic with offset-based resumption (see `references/pagination-and-offsets.md`)
- Monitor connection state and re-subscribe when the connection drops
