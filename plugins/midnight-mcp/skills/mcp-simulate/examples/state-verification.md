# State Verification Examples

## When to Apply

When you need to compare actual ledger state against expected values. Always verify specific field values, not just `success: true`.

## Examples

### Counter arithmetic verification

```
1. Deploy counter contract:
   midnight-simulate-deploy({ code: "<counter contract>" })
   → sessionId: "arith-1"
   → ledgerState: { count: { type: "Counter", value: "0" } }

2. Increment by 5:
   midnight-simulate-call({ sessionId: "arith-1", circuit: "inc", arguments: { n: "5" } })
   → success: true

3. Verify:
   midnight-simulate-state({ sessionId: "arith-1" })
   → ledgerState: { count: { type: "Counter", value: "5" } }
   ✓ Expected: 0 + 5 = 5

4. Increment by 3:
   midnight-simulate-call({ sessionId: "arith-1", circuit: "inc", arguments: { n: "3" } })
   → success: true

5. Verify:
   → ledgerState: { count: { type: "Counter", value: "8" } }
   ✓ Expected: 5 + 3 = 8

6. Increment by 7:
   midnight-simulate-call({ sessionId: "arith-1", circuit: "inc", arguments: { n: "7" } })
   → success: true

7. Final verify:
   → ledgerState: { count: { type: "Counter", value: "15" } }
   ✓ Expected: 8 + 7 = 15 (not just "some number" — verify exact arithmetic)

8. Delete:
   midnight-simulate-delete({ sessionId: "arith-1" })
```

### Map state verification

```
1. Deploy with empty Map:
   midnight-simulate-deploy({ code: "<contract with Map<Bytes<32>, Uint<64>>>" })
   → sessionId: "map-1"
   → ledgerState: { entries: { type: "Map<Bytes<32>, Uint<64>>", value: {} } }
   ✓ Map starts empty

2. Insert first entry:
   midnight-simulate-call({ sessionId: "map-1", circuit: "insert", arguments: { key: "0xabc", value: "100" } })
   → success: true

3. Verify Map contains entry:
   midnight-simulate-state({ sessionId: "map-1" })
   → ledgerState: { entries: { value: { "0xabc": "100" } } }
   ✓ One entry: 0xabc → 100

4. Insert second entry:
   midnight-simulate-call({ sessionId: "map-1", circuit: "insert", arguments: { key: "0xdef", value: "200" } })
   → success: true

5. Verify both entries:
   → ledgerState: { entries: { value: { "0xabc": "100", "0xdef": "200" } } }
   ✓ Two entries present

6. Remove first entry:
   midnight-simulate-call({ sessionId: "map-1", circuit: "remove", arguments: { key: "0xabc" } })
   → success: true

7. Verify only second remains:
   → ledgerState: { entries: { value: { "0xdef": "200" } } }
   ✓ Only 0xdef remains — 0xabc was removed

8. Delete:
   midnight-simulate-delete({ sessionId: "map-1" })
```

### Multi-field verification

```
1. Deploy with Counter + Map:
   midnight-simulate-deploy({ code: "<contract with count: Counter and log: Map>" })
   → sessionId: "multi-1"
   → ledgerState: {
       count: { type: "Counter", value: "0" },
       log: { type: "Map<Bytes<32>, Uint<64>>", value: {} }
     }

2. Call circuit that modifies both fields:
   midnight-simulate-call({ sessionId: "multi-1", circuit: "recordAction", arguments: { actor: "0xalice", amount: "10" } })
   → success: true

3. Verify BOTH fields:
   midnight-simulate-state({ sessionId: "multi-1" })
   → ledgerState: {
       count: { type: "Counter", value: "1" },
       log: { type: "Map<Bytes<32>, Uint<64>>", value: { "0xalice": "10" } }
     }
   ✓ Counter incremented to 1
   ✓ Map has alice → 10
   ✓ Both fields changed as expected (not just one)

4. Delete:
   midnight-simulate-delete({ sessionId: "multi-1" })
```

### Unchanged field verification

```
1. Deploy with two Counter fields:
   midnight-simulate-deploy({ code: "<contract with fieldA: Counter and fieldB: Counter>" })
   → sessionId: "unchanged-1"
   → ledgerState: {
       fieldA: { type: "Counter", value: "0" },
       fieldB: { type: "Counter", value: "0" }
     }

2. Call circuit that modifies only fieldA:
   midnight-simulate-call({ sessionId: "unchanged-1", circuit: "incrementA", arguments: { n: "5" } })
   → success: true

3. Verify fieldA changed AND fieldB unchanged:
   midnight-simulate-state({ sessionId: "unchanged-1" })
   → ledgerState: {
       fieldA: { type: "Counter", value: "5" },
       fieldB: { type: "Counter", value: "0" }
     }
   ✓ fieldA = 5 (changed as expected)
   ✓ fieldB = 0 (unchanged — no unintended side effects)

4. Delete:
   midnight-simulate-delete({ sessionId: "unchanged-1" })
```

## Anti-Patterns

### Success-only checking

Checking only `success: true` without inspecting actual state values. Success means "no error", not "correct result". A circuit could succeed but produce the wrong state. Always compare actual ledger values against expected values.

### Partial field verification

Verifying only the fields you expect to change. Also check that other fields did NOT change — this detects unintended side effects that would otherwise go unnoticed.

### Skipping post-error verification

Not verifying state after error cases. State should be unchanged after failures — verify this explicitly to confirm the contract maintains consistency.
