# Circuit Execution

## When to Use

After deploying, when you want to execute a circuit and interpret the results.

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `sessionId` | Yes | Session ID from deploy |
| `circuit` | Yes | Must match an exported circuit name |
| `arguments` | No | Keyed by parameter name — the MCP server handles type coercion |
| `caller` | No | See `references/caller-context.md` |
| `witnessOverrides` | No | See `references/witness-management.md` |

## Parameter Formatting by Type

- `Uint<N>`: string representation of the integer, e.g., `"42"`, `"0"`
- `Field`: string representation, e.g., `"12345"`
- `Bytes<N>`: hex string, e.g., `"0x1a2b3c..."`
- `Boolean`: `"true"` or `"false"`
- Compound types: JSON-encoded where applicable

The MCP server handles type coercion, so passing raw values (e.g., `42` instead of `"42"`) should also work.

## Successful Call with State Changes

```
Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "inc",
  arguments: { n: "5" }
})
Response: {
  success: true,
  result: null,
  stateChanges: [
    { field: "count", operation: "increment", previousValue: "0", newValue: "5" }
  ],
  updatedLedger: {
    count: { type: "Counter", value: "5" }
  }
}
Action: Counter incremented from 0 to 5. State changes confirm the mutation.
```

## Pure Circuit Call

```
Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "get"
})
Response: {
  success: true,
  result: "5",
  stateChanges: [],
  updatedLedger: {
    count: { type: "Counter", value: "5" }
  }
}
Action: Pure circuit returned 5. No state changes (read-only).
```

## Assertion Failure

```
Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "transferOwnership",
  arguments: { newOwner: "0xbob" },
  caller: "eve"
})
Response: {
  success: false,
  errors: [{
    message: "Assertion failed: caller must be owner",
    severity: "error"
  }],
  updatedLedger: {
    owner: { type: "Bytes<32>", value: "0xalice" }
  }
}
Action: Assertion fired — caller "eve" is not the owner. Ledger unchanged. This may be expected behavior (testing guards) or indicate wrong caller.
```

## Understanding stateChanges

Each entry shows which field changed, the operation, the previous value, and the new value:

- **Counter**: increment/decrement operations
- **Map**: insert/update/remove operations
- **Set**: add/remove operations

## Pure vs Impure Circuits

Pure circuits return values without modifying ledger state. Impure circuits may modify state. The `isPure` flag in circuit metadata tells you which. Pure circuits always have empty `stateChanges`.

## The Fix-and-Redeploy Loop

If a circuit call reveals a bug in the contract code, you must fix the code and deploy a new session. You cannot modify the contract in an existing session.

1. Identify the bug from the call response
2. Fix the contract source code
3. Delete the current session
4. Deploy a new session with the fixed code
5. Replay calls to reach the test point

## State Accumulation

Each successful call modifies the session's ledger state. Subsequent calls execute against the updated state. Failed calls (assertion failures, errors) do NOT modify state — the ledger remains as it was before the failed call.
