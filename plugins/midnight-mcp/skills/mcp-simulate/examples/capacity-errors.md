# Capacity and Rate Limit Error Examples

## When This Error Occurs

Server resource limits are hit — either too many concurrent sessions or too many requests in the rate limit window.

## Examples

### Capacity exceeded

```
Before:
  midnight-simulate-deploy({ code: "<contract>" })

Error:
  { success: false, errors: [{ message: "CAPACITY_EXCEEDED: maximum concurrent sessions reached", errorCode: "CAPACITY_EXCEEDED" }] }

Diagnosis:
  ~100 concurrent session limit reached. Other sessions (yours or shared server users) are consuming all capacity.

Fix:
  Delete old sessions, then retry deploy:
  midnight-simulate-delete({ sessionId: "<old-session-1>" })
  midnight-simulate-delete({ sessionId: "<old-session-2>" })
  midnight-simulate-deploy({ code: "<contract>" })
  → success: true

  If the sessions aren't yours (shared server), wait and retry after a few minutes — sessions expire after 15 minutes of inactivity.
```

### Rate limit (HTTP 429)

```
Before:
  (20 deploy calls within 60 seconds)
  midnight-simulate-deploy({ code: "<contract>" })

Error:
  HTTP 429 — rate limit exceeded

Diagnosis:
  Too many requests in the 60-second window. Deploy and call each have a 20-request limit per 60 seconds.

Fix:
  Wait for the window to reset (up to 60 seconds), then retry.
  Restructure testing to batch operations:
  - Deploy once, make multiple calls (instead of redeploying per test case)
  - Plan your call sequence before executing
```

### Deploy is expensive — budget accordingly

```
Anti-pattern — rapid-fire deploys hitting limits:
  midnight-simulate-deploy({ code: "<contract v1>" })  → test → delete
  midnight-simulate-deploy({ code: "<contract v1>" })  → test → delete
  midnight-simulate-deploy({ code: "<contract v1>" })  → test → delete
  ... (hits rate limit after 20 deploys)

Better — one deploy, many calls:
  midnight-simulate-deploy({ code: "<contract>" })
  → sessionId: "abc-123-def"

  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "testA", ... })
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "testB", ... })
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "testC", ... })
  midnight-simulate-state({ sessionId: "abc-123-def" })
  ... (many calls within one session — each call costs 1 rate limit slot, not a compilation)

  midnight-simulate-delete({ sessionId: "abc-123-def" })

Deploy costs compilation time (~1-5s) AND a rate limit slot. Calls are fast and share the session's compiled artifacts.
```

## Anti-Patterns

### Redeploy-per-test

Redeploying for each test case instead of using one session with multiple calls. This wastes both rate limit budget and compilation time. Deploy once, test everything in that session, delete when done.

### Abandoned sessions

Not cleaning up sessions after testing. Abandoned sessions block others from deploying by consuming capacity. Always call `midnight-simulate-delete` when finished.
