# Deploy Workflows

## When to Use

Starting any simulation. This is always the first step — every session begins with a deploy.

## The Deploy-Compile Pipeline

Deploy compiles the contract before initializing the simulator. This takes ~1-5s (with skipZk). If compilation fails, the deploy fails with compiler errors — load `references/error-recovery.md` for diagnosis, and cross-reference `midnight-mcp:mcp-compile` error recovery for detailed compiler error guidance.

## Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `code` | Yes | Compact contract source code |
| `version` | No | Compiler version — `"detect"` resolves from pragma, specific version string, or omit for latest |
| `constructorArgs` | No | Arguments for the contract constructor — must match constructor signature |
| `caller` | No | Caller identity for the deploy transaction — sets contract creator/owner |

## Successful Deploy

```
Call: midnight-simulate-deploy({ code: "<compact source>" })
Response: {
  success: true,
  sessionId: "abc-123-def",
  circuits: [
    {
      name: "inc",
      isPublic: true,
      isPure: false,
      parameters: [{ name: "n", type: "Uint<64>" }],
      returnType: "[]",
      readsLedger: ["count"],
      writesLedger: ["count"]
    },
    {
      name: "get",
      isPublic: true,
      isPure: true,
      parameters: [],
      returnType: "Uint<64>",
      readsLedger: ["count"],
      writesLedger: []
    }
  ],
  ledgerState: {
    count: { type: "Counter", value: "0" }
  },
  expiresAt: "2026-03-19T15:15:00Z"
}
Action: Store sessionId. Inspect circuits to plan your test sequence.
```

## Failed Deploy (Compilation Error)

```
Call: midnight-simulate-deploy({ code: "export circuit bad(): Void { }" })
Response: {
  success: false,
  errors: [{
    message: "expected ';' but found '{'",
    severity: "error",
    line: 1,
    column: 35
  }]
}
Action: Load references/error-recovery.md to diagnose. This is a compiler error — see mcp-compile error recovery for detailed guidance.
```

## Interpreting the Deploy Response

- **`circuits`** tells you what you can call, what arguments each circuit takes, and which ledger fields it affects
- **`ledgerState`** shows initial values for all ledger fields (Counter starts at 0, Map starts empty, etc.)
- **`sessionId`** is required for ALL subsequent operations — store it
- **`expiresAt`** tells you when the session will expire if inactive (15 minutes from last activity)

## Version Selection

Same version semantics as `midnight-mcp:mcp-compile`:
- `"detect"` — resolves from `pragma language_version` in the source
- Specific version string (e.g., `"0.14.0"`) — uses that version
- Omit — uses the latest available version

## The Deploy-Then-Inspect Pattern

After deploying, call `midnight-simulate-state` to get a full picture of the contract before making any calls. This gives you the circuit signatures and initial state in a single read.

```
1. midnight-simulate-deploy({ code: "<contract>" })
   → Store sessionId

2. midnight-simulate-state({ sessionId: "<stored id>" })
   → Review circuits (signatures, pure/impure, ledger access)
   → Review initial ledgerState (all field types and values)
   → Plan your test sequence based on what you see
```
