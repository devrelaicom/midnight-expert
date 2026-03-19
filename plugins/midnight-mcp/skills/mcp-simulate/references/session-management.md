# Session Management

## When to Use

When you need to understand session behavior, handle expiry, or manage resources.

## Session Creation

Happens on deploy. Involves compilation (~1-5s), so it's not instant. Each session consumes server resources (compiled artifacts + simulator instance in memory).

## TTL and Inactivity

Sessions expire after 15 minutes of inactivity. Each call or state request refreshes the TTL. The TTL is inactivity-based, not absolute — a session that receives regular requests stays alive indefinitely.

## Capacity Limit

~100 concurrent sessions. If capacity is exceeded, deploy returns a `CAPACITY_EXCEEDED` error. Delete unused sessions to free capacity.

## Detecting Expired Sessions

Any operation on an expired session returns `SESSION_NOT_FOUND`. The session cannot be recovered — you must deploy a new one.

## Recovering from Expiry

Deploy a new session with the same code, then replay the call sequence to reach the desired state. This costs compilation time + call time. Keep sessions alive during active testing by making periodic state requests.

## Cleanup Discipline

Always call `midnight-simulate-delete` when done. Abandoned sessions consume resources until they expire. If testing multiple contracts, delete each session before deploying the next.

## Session Lifecycle Example

```
1. Deploy: midnight-simulate-deploy({ code: "<contract>" })
   → sessionId: "abc-123-def"

2. Call: midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "5" } })
   → success: true

3. Call: midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "3" } })
   → success: true

4. State: midnight-simulate-state({ sessionId: "abc-123-def" })
   → ledgerState: { count: { type: "Counter", value: "8" } }

5. Delete: midnight-simulate-delete({ sessionId: "abc-123-def" })
   → success: true
```

## Rate Limit Awareness

Deploy is the most expensive operation (compilation). Plan your testing so you deploy once and make multiple calls, rather than redeploying for each test case.

If you need to test different code versions, use `mcp-compile` multi-version first to identify which version compiles, then deploy the working version for simulation.
