# Session Error Examples

## When This Error Occurs

A session operation (`call`, `state`, or `delete`) fails because the session no longer exists. The error code is always `SESSION_NOT_FOUND`.

## Examples

### Session expired due to inactivity

```
Before:
  midnight-simulate-deploy({ code: "<contract>" })
  → sessionId: "abc-123-def"
  (15+ minutes pass with no activity)
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "5" } })

Error:
  { success: false, errors: [{ message: "SESSION_NOT_FOUND", errorCode: "SESSION_NOT_FOUND" }] }

Diagnosis:
  Session expired after 15 minutes of inactivity. The TTL is inactivity-based — any call or state request would have refreshed it.

Fix:
  Redeploy with the same code and replay the call sequence:
  midnight-simulate-deploy({ code: "<same contract>" })
  → sessionId: "xyz-456-uvw"
  (replay previous calls to restore state)
```

### Wrong session ID

```
Before:
  midnight-simulate-deploy({ code: "<contract>" })
  → sessionId: "abc-123-def"
  midnight-simulate-call({ sessionId: "wrong-id-here", circuit: "inc" })

Error:
  { success: false, errors: [{ message: "SESSION_NOT_FOUND", errorCode: "SESSION_NOT_FOUND" }] }

Diagnosis:
  The session ID does not match any active session. The ID was not stored correctly or was overwritten by a subsequent deploy.

Fix:
  Use the exact sessionId returned from the deploy response. Store it immediately after deploy and reference it consistently for all subsequent operations.
```

### Session deleted but still referenced

```
Before:
  midnight-simulate-deploy({ code: "<contract>" })
  → sessionId: "abc-123-def"
  midnight-simulate-delete({ sessionId: "abc-123-def" })
  → success: true
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc" })

Error:
  { success: false, errors: [{ message: "SESSION_NOT_FOUND", errorCode: "SESSION_NOT_FOUND" }] }

Diagnosis:
  The session was explicitly deleted but subsequent operations still reference it.

Fix:
  Deploy a new session if more testing is needed:
  midnight-simulate-deploy({ code: "<contract>" })
  → sessionId: "new-456-ghi"
```

### Proactive TTL management

```
Pattern for long testing sessions:

1. midnight-simulate-deploy({ code: "<contract>" })
   → sessionId: "abc-123-def", expiresAt: "2026-03-19T15:15:00Z"

2. (Make calls and verify state)

3. Check expiresAt periodically via midnight-simulate-state:
   → expiresAt: "2026-03-19T15:25:00Z"  (refreshed by the state call itself)

4. If approaching expiry during a long testing session:
   - Any call or state request refreshes the TTL
   - Make a state request to keep the session alive

5. If the session does expire:
   - Redeploy with the same code
   - Replay the call sequence to restore state
```

## Anti-Patterns

### Attempting session recovery

Trying to recover an expired session is impossible. The state is gone — the simulator has freed all resources. You must redeploy and replay.

### Not storing sessionId

Not storing the sessionId immediately after deploy leads to wrong-ID errors. The deploy response is the only source of the session ID.

### Ignoring TTL

Leaving sessions open and being surprised when they expire. The 15-minute TTL is inactivity-based — any call or state request resets it, but you must make at least one request every 15 minutes during active testing.
