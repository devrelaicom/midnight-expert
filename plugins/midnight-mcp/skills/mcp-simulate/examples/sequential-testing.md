# Sequential Testing Examples

## When to Apply

When testing a multi-step workflow where each circuit call builds on the previous state. Deploy once, call circuits in order, verify state between calls.

## Examples

### Counter increment sequence

```
1. Deploy:
   midnight-simulate-deploy({ code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nexport ledger count: Counter;\nexport circuit inc(n: Uint<16>): [] { count.increment(disclose(n)); }\nexport circuit get(): Uint<64> { return count; }" })
   → sessionId: "abc-123-def"
   → ledgerState: { count: { type: "Counter", value: "0" } }

2. Call inc(5):
   midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "5" } })
   → success: true, stateChanges: [{ field: "count", previousValue: "0", newValue: "5" }]

3. Verify state:
   midnight-simulate-state({ sessionId: "abc-123-def" })
   → ledgerState: { count: { type: "Counter", value: "5" } }
   ✓ Counter = 5 (expected)

4. Call inc(3):
   midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "3" } })
   → success: true, stateChanges: [{ field: "count", previousValue: "5", newValue: "8" }]

5. Verify state:
   → ledgerState: { count: { type: "Counter", value: "8" } }
   ✓ Counter = 8 (expected: 5 + 3)

6. Call get():
   midnight-simulate-call({ sessionId: "abc-123-def", circuit: "get" })
   → success: true, result: "8", stateChanges: []
   ✓ Return value matches ledger state

7. Delete:
   midnight-simulate-delete({ sessionId: "abc-123-def" })
```

### Initialize-then-operate pattern

```
1. Deploy:
   midnight-simulate-deploy({ code: "<contract with init circuit>" })
   → sessionId: "session-1"
   → ledgerState: { initialized: { type: "Boolean", value: "false" }, data: { type: "Field", value: "0" } }

2. Initialize:
   midnight-simulate-call({ sessionId: "session-1", circuit: "init", arguments: { seed: "42" } })
   → success: true
   → stateChanges: [
       { field: "initialized", previousValue: "false", newValue: "true" },
       { field: "data", previousValue: "0", newValue: "42" }
     ]

3. Verify initialization:
   midnight-simulate-state({ sessionId: "session-1" })
   → ledgerState: { initialized: { type: "Boolean", value: "true" }, data: { type: "Field", value: "42" } }
   ✓ Both fields set correctly

4. Operate on initialized state:
   midnight-simulate-call({ sessionId: "session-1", circuit: "process" })
   → success: true

5. Verify final state:
   midnight-simulate-state({ sessionId: "session-1" })
   ✓ Check that process modified data as expected

6. Delete:
   midnight-simulate-delete({ sessionId: "session-1" })
```

### Ordered operations with dependencies

```
1. Deploy token contract:
   midnight-simulate-deploy({ code: "<token contract>", caller: "alice" })
   → sessionId: "token-1"
   → ledgerState: { balances: { type: "Map<Bytes<32>, Uint<64>>", value: {} }, owner: { type: "Bytes<32>", value: "alice" } }

2. Mint tokens:
   midnight-simulate-call({ sessionId: "token-1", circuit: "mint", arguments: { amount: "100" }, caller: "alice" })
   → success: true
   → stateChanges: [{ field: "balances", operation: "insert", key: "alice", newValue: "100" }]

3. Verify mint:
   midnight-simulate-state({ sessionId: "token-1" })
   → ledgerState: { balances: { type: "Map<Bytes<32>, Uint<64>>", value: { "alice": "100" } } }
   ✓ Alice has 100 tokens

4. Transfer tokens:
   midnight-simulate-call({ sessionId: "token-1", circuit: "transfer", arguments: { amount: "30", to: "bob" }, caller: "alice" })
   → success: true
   → stateChanges: [
       { field: "balances", operation: "update", key: "alice", previousValue: "100", newValue: "70" },
       { field: "balances", operation: "insert", key: "bob", newValue: "30" }
     ]

5. Verify transfer:
   midnight-simulate-state({ sessionId: "token-1" })
   → ledgerState: { balances: { value: { "alice": "70", "bob": "30" } } }
   ✓ Alice decreased by 30, Bob received 30

6. Delete:
   midnight-simulate-delete({ sessionId: "token-1" })
```

## Anti-Patterns

### Skipping intermediate verification

Making calls without verifying state between them. When the final state is wrong, you can't tell which step introduced the error. Verify after each significant call.

### Ad-hoc testing

Not planning the call sequence before executing. Write down the expected state after each step before making any calls — then compare actual vs expected at each step.

### Redeploy per step

Deploying a new session for each step instead of using the accumulated state. State is cumulative within a session — that's the point. Redeploying loses all previous state and wastes rate limit budget.
