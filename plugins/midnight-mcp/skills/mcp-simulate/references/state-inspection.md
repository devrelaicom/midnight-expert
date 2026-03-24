# State Inspection

## When to Use

After deploying, between circuit calls, or at the end of a test sequence to verify outcomes.

## The State Response Structure

| Field | Contents |
|-------|----------|
| `ledgerState` | Current values for ALL ledger fields, keyed by field name, each with `type` and `value` |
| `circuits` | Metadata for all exported circuits — name, isPublic, isPure, parameters with types, returnType, readsLedger, writesLedger |
| `callHistory` | Ordered array of all circuit calls made in this session — circuit name, arguments, caller, timestamp, stateChanges, and result |
| `expiresAt` | When the session will expire if inactive |

## Reading Ledger State by Type

- `Counter`: numeric string, e.g., `"5"`
- `Map<K, V>`: JSON-encoded map, e.g., `{"0xabc": "100"}`
- `Set<T>`: JSON-encoded set, e.g., `["0xabc", "0xdef"]`
- `MerkleTree<T, D>`: root hash and membership data
- `Uint<N>`, `Field`, `Bytes<N>`: string representations of their values
- `Boolean`: `"true"` or `"false"`

## Using Circuit Metadata

Before calling a circuit, check its `parameters` to know what arguments it expects and their types. Check `readsLedger` and `writesLedger` to understand what state it will access.

```
Circuit metadata example:
  {
    name: "transfer",
    isPublic: true,
    isPure: false,
    parameters: [
      { name: "amount", type: "Uint<64>" },
      { name: "to", type: "Bytes<32>" }
    ],
    returnType: "[]",
    readsLedger: ["balances"],
    writesLedger: ["balances"]
  }

This tells you:
  - Call with arguments: { amount: "50", to: "0xbob" }
  - It reads and writes the "balances" ledger field
  - It is impure (modifies state)
  - It returns nothing (Void/[])
```

## Analyzing Call History

The call history is an audit trail. Use it to:
- Verify that a specific sequence of operations occurred
- Check what state changes each call produced
- Debug unexpected state by tracing through the history

## State Before and After

```
State after deploy (before any calls):
  midnight-simulate-state({ sessionId: "abc-123-def" })
  → ledgerState: { count: { type: "Counter", value: "0" } }
    callHistory: []

After two increment calls (inc(5), inc(3)):
  midnight-simulate-state({ sessionId: "abc-123-def" })
  → ledgerState: { count: { type: "Counter", value: "8" } }
    callHistory: [
      { circuit: "inc", arguments: { n: "5" }, stateChanges: [{ field: "count", previousValue: "0", newValue: "5" }] },
      { circuit: "inc", arguments: { n: "3" }, stateChanges: [{ field: "count", previousValue: "5", newValue: "8" }] }
    ]
```

## The State Verification Pattern

Call circuit → Call state → Compare actual values against expected values. This is the fundamental testing loop.

```
1. Call: midnight-simulate-call({ sessionId: "...", circuit: "inc", arguments: { n: "5" } })
2. State: midnight-simulate-state({ sessionId: "..." })
3. Compare: ledgerState.count.value === "5" ← expected value
4. If mismatch: investigate callHistory and stateChanges
```
