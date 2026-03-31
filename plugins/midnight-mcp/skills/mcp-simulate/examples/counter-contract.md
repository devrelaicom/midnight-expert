# Counter Contract Archetype

## Contract Code

```compact
pragma language_version >= 0.22;

import CompactStandardLibrary;

export ledger count: Counter;

export circuit inc(n: Uint<16>): [] {
  count.increment(disclose(n));
}

export circuit get(): Uint<64> {
  return count;
}
```

## Simulation Sequence

### Step 1: Deploy

```
midnight-simulate-deploy({
  code: "pragma language_version >= 0.22;\nimport CompactStandardLibrary;\nexport ledger count: Counter;\nexport circuit inc(n: Uint<16>): [] { count.increment(disclose(n)); }\nexport circuit get(): Uint<64> { return count; }"
})
→ {
    success: true,
    sessionId: "counter-session-1",
    circuits: [
      { name: "inc", isPublic: true, isPure: false, parameters: [{ name: "n", type: "Uint<16>" }], returnType: "[]", readsLedger: ["count"], writesLedger: ["count"] },
      { name: "get", isPublic: true, isPure: false, parameters: [], returnType: "Uint<64>", readsLedger: ["count"], writesLedger: [] }
    ],
    ledgerState: { count: { type: "Counter", value: "0" } }
  }
```

### Step 2: Verify initial state

```
midnight-simulate-state({ sessionId: "counter-session-1" })
→ ledgerState: { count: { type: "Counter", value: "0" } }
  callHistory: []
✓ Counter starts at 0
```

### Step 3: Increment by 5

```
midnight-simulate-call({ sessionId: "counter-session-1", circuit: "inc", arguments: { n: "5" } })
→ {
    success: true,
    result: null,
    stateChanges: [{ field: "count", operation: "increment", previousValue: "0", newValue: "5" }],
    updatedLedger: { count: { type: "Counter", value: "5" } }
  }
```

### Step 4: Verify state after first increment

```
midnight-simulate-state({ sessionId: "counter-session-1" })
→ ledgerState: { count: { type: "Counter", value: "5" } }
✓ Counter = 5
```

### Step 5: Increment by 3

```
midnight-simulate-call({ sessionId: "counter-session-1", circuit: "inc", arguments: { n: "3" } })
→ {
    success: true,
    stateChanges: [{ field: "count", operation: "increment", previousValue: "5", newValue: "8" }],
    updatedLedger: { count: { type: "Counter", value: "8" } }
  }
```

### Step 6: Verify accumulated state

```
midnight-simulate-state({ sessionId: "counter-session-1" })
→ ledgerState: { count: { type: "Counter", value: "8" } }
✓ Counter = 5 + 3 = 8
```

### Step 7: Read counter value

```
midnight-simulate-call({ sessionId: "counter-session-1", circuit: "get" })
→ {
    success: true,
    result: "8",
    stateChanges: [],
    updatedLedger: { count: { type: "Counter", value: "8" } }
  }
✓ Return value (8) matches ledger state
✓ No state changes (read-only circuit)
```

### Step 8: Cleanup

```
midnight-simulate-delete({ sessionId: "counter-session-1" })
→ { success: true }
```

## What This Tests

- **Basic state mutation** — Counter increments correctly with different values
- **State-modifying vs read-only circuits** — `inc` modifies state, `get` reads without modifying
- **Return values** — `get` returns the current counter value
- **State accumulation** — Multiple increments accumulate correctly (0 → 5 → 8)
- **stateChanges tracking** — Each call reports what changed and the before/after values

## Limitations

Counter contracts are the simplest pattern — simulation handles them perfectly. This is a good baseline for verifying that the simulator is working correctly. There are no access control, witness, or multi-user concerns in this archetype.
