# Access Control Contract Archetype

## Contract Code

```compact
pragma language_version >= 0.14;

import CompactStandardLibrary;

export ledger owner: Bytes<32>;
export ledger data: Counter;

export circuit transferOwnership(newOwner: Bytes<32>): [] {
  assert(caller == owner, "caller must be owner");
  owner = newOwner;
}

export circuit restricted(): [] {
  assert(caller == owner, "caller must be owner");
  data.increment(1);
}

export pure circuit getData(): Uint<64> {
  return data;
}

export pure circuit getOwner(): Bytes<32> {
  return owner;
}
```

## Simulation Sequence

### Step 1: Deploy as Alice

```
midnight-simulate-deploy({ code: "<access control contract source>", caller: "alice" })
→ {
    success: true,
    sessionId: "acl-session-1",
    circuits: [
      { name: "transferOwnership", isPublic: true, isPure: false, parameters: [{ name: "newOwner", type: "Bytes<32>" }], readsLedger: ["owner"], writesLedger: ["owner"] },
      { name: "restricted", isPublic: true, isPure: false, parameters: [], readsLedger: ["owner", "data"], writesLedger: ["data"] },
      { name: "getData", isPublic: true, isPure: true, parameters: [], readsLedger: ["data"], writesLedger: [] },
      { name: "getOwner", isPublic: true, isPure: true, parameters: [], readsLedger: ["owner"], writesLedger: [] }
    ],
    ledgerState: {
      owner: { type: "Bytes<32>", value: "alice" },
      data: { type: "Counter", value: "0" }
    }
  }
```

### Step 2: Alice calls owner-only circuit (succeeds)

```
midnight-simulate-call({ sessionId: "acl-session-1", circuit: "restricted", caller: "alice" })
→ {
    success: true,
    stateChanges: [{ field: "data", operation: "increment", previousValue: "0", newValue: "1" }]
  }
✓ Owner can call restricted circuit
```

### Step 3: Bob calls owner-only circuit (assertion failure)

```
midnight-simulate-call({ sessionId: "acl-session-1", circuit: "restricted", caller: "bob" })
→ {
    success: false,
    errors: [{ message: "Assertion failed: caller must be owner", severity: "error" }]
  }
✓ Non-owner correctly rejected
```

### Step 4: Verify state unchanged after rejection

```
midnight-simulate-state({ sessionId: "acl-session-1" })
→ ledgerState: {
    owner: { type: "Bytes<32>", value: "alice" },
    data: { type: "Counter", value: "1" }
  }
✓ Data still 1 (Bob's failed call did not modify state)
✓ Owner still Alice
```

### Step 5: Alice transfers ownership to Bob

```
midnight-simulate-call({ sessionId: "acl-session-1", circuit: "transferOwnership", arguments: { newOwner: "bob" }, caller: "alice" })
→ {
    success: true,
    stateChanges: [{ field: "owner", previousValue: "alice", newValue: "bob" }]
  }
```

### Step 6: Verify ownership change

```
midnight-simulate-state({ sessionId: "acl-session-1" })
→ ledgerState: {
    owner: { type: "Bytes<32>", value: "bob" },
    data: { type: "Counter", value: "1" }
  }
✓ Owner is now Bob
✓ Data unchanged by ownership transfer
```

### Step 7: Bob calls owner-only circuit (now succeeds)

```
midnight-simulate-call({ sessionId: "acl-session-1", circuit: "restricted", caller: "bob" })
→ {
    success: true,
    stateChanges: [{ field: "data", operation: "increment", previousValue: "1", newValue: "2" }]
  }
✓ New owner can call restricted circuit
```

### Step 8: Alice calls owner-only circuit (now fails)

```
midnight-simulate-call({ sessionId: "acl-session-1", circuit: "restricted", caller: "alice" })
→ {
    success: false,
    errors: [{ message: "Assertion failed: caller must be owner", severity: "error" }]
  }
✓ Previous owner is now correctly rejected
```

### Step 9: Cleanup

```
midnight-simulate-delete({ sessionId: "acl-session-1" })
→ { success: true }
```

## What This Tests

- **Ownership verification via caller context** — only the owner can call restricted circuits
- **Ownership transfer** — the transferOwnership circuit changes who the owner is
- **Assertion testing for unauthorized access** — non-owners are rejected with assertion errors
- **State verification that ownership change persists** — after transfer, the new owner has access and the previous owner does not
- **State isolation** — ownership transfer does not affect other ledger fields (data unchanged)

## Limitations

This archetype uses a single-owner model. More complex access control patterns (multi-sig, role-based, time-locked) would require additional ledger fields and more sophisticated assertion logic. The simulation verifies ownership transfer mechanics but does not test revocation patterns or multi-level hierarchies.
