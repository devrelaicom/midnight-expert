# Error Handling

Common error responses from the indexer GraphQL API and how to resolve them.

## Complexity Limit Exceeded

The indexer enforces a maximum query complexity (configured via `max_complexity`). Deeply nested or wide queries are rejected before execution.

The complexity limit is wired into the schema with async-graphql's built-in `.limit_complexity(max_complexity)` validator. The error message is the validator's fixed string `"Query is too complex."` — it does not include the configured limit or the query's actual complexity, and no `extensions.code` is attached.

**Error response:**

```json
{
  "errors": [
    {
      "message": "Query is too complex."
    }
  ]
}
```

**How to fix:**
- Remove unused fields from the selection set
- Avoid deeply nested relationships (e.g., `block > transactions > contractActions > transaction > ...`)
- Split one large query into multiple smaller queries
- Request only the fields you need from `Transaction` objects

## Session ID Errors

Two distinct errors can be returned for the `sessionId` passed to the `shieldedTransactions` subscription or the `disconnect` mutation. The indexer does **not** attach an `extensions.code`, capitalize "Invalid", or echo the supplied id back in the message.

### Malformed session ID

If the supplied id cannot be decoded into a 32-byte session ID, `decode_session_id` fails and the error is wrapped with the lowercase message `"invalid session ID"`. The full message is a chain joined with `:`, where the suffix is the underlying decode failure:

```json
{
  "errors": [
    {
      "message": "invalid session ID:cannot hex-decode session ID:..."
    }
  ]
}
```

A value that is valid hex but the wrong length yields `"invalid session ID:cannot convert into session ID:..."` instead.

### Unknown or expired session ID

If the id is well-formed (decodes to 32 bytes) but does not resolve to a live wallet session, the `shieldedTransactions` subscription returns the distinct message `"unknown or expired session ID"` (no source chain, no `extensions.code`):

```json
{
  "errors": [
    {
      "message": "unknown or expired session ID"
    }
  ]
}
```

**How to fix:**
- Call the `connect` mutation with a valid viewing key to obtain a new session ID
- Session IDs do not persist across indexer restarts; reconnect after indexer downtime
- Ensure the session has not been explicitly disconnected via the `disconnect` mutation
- Check the supplied value is the exact hex session ID returned by `connect` (correct length, valid hex)

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

The indexer enforces a maximum query depth (configured via `max_depth`, applied with both `.limit_depth(max_depth)` and `.limit_recursive_depth(max_depth)`).

The error message is async-graphql's fixed validator string `"Query is nested too deep."` — it does not include the configured limit, and no `extensions.code` is attached.

**Error response:**

```json
{
  "errors": [
    {
      "message": "Query is nested too deep."
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
