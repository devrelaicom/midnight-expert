# Voting Contract Archetype

## Contract Code

```compact
pragma language_version >= 0.14;

import CompactStandardLibrary;

export ledger votesA: Counter;
export ledger votesB: Counter;
export ledger voters: Map<Bytes<32>, Boolean>;
export ledger votingOpen: Boolean;
export ledger owner: Bytes<32>;

export circuit openVoting(): [] {
  assert(caller == owner, "only owner can open voting");
  votingOpen = true;
}

export circuit vote(option: Uint<64>): [] {
  assert(votingOpen == true, "voting is closed");
  const hasVoted = voters.lookup(disclose(caller)).with_default(false);
  assert(hasVoted == false, "already voted");
  voters.insert(disclose(caller), true);
  assert(option == 0 || option == 1, "invalid option");
  if option == 0 {
    votesA.increment(1);
  } else {
    votesB.increment(1);
  }
}

export circuit closeVoting(): [] {
  assert(caller == owner, "only owner can close voting");
  votingOpen = false;
}

export pure circuit tally(): [Uint<64>, Uint<64>] {
  return [votesA, votesB];
}
```

## Simulation Sequence

### Step 1: Deploy

```
midnight-simulate-deploy({ code: "<voting contract source>", caller: "owner" })
→ {
    success: true,
    sessionId: "vote-session-1",
    ledgerState: {
      votesA: { type: "Counter", value: "0" },
      votesB: { type: "Counter", value: "0" },
      voters: { type: "Map<Bytes<32>, Boolean>", value: {} },
      votingOpen: { type: "Boolean", value: "false" },
      owner: { type: "Bytes<32>", value: "owner" }
    }
  }
```

### Step 2: Open voting

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "openVoting", caller: "owner" })
→ { success: true, stateChanges: [{ field: "votingOpen", previousValue: "false", newValue: "true" }] }
```

### Step 3: Alice votes for option A

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "vote", arguments: { option: "0" }, caller: "alice" })
→ {
    success: true,
    stateChanges: [
      { field: "voters", operation: "insert", key: "alice", newValue: "true" },
      { field: "votesA", operation: "increment", previousValue: "0", newValue: "1" }
    ]
  }
```

### Step 4: Bob votes for option B

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "vote", arguments: { option: "1" }, caller: "bob" })
→ {
    success: true,
    stateChanges: [
      { field: "voters", operation: "insert", key: "bob", newValue: "true" },
      { field: "votesB", operation: "increment", previousValue: "0", newValue: "1" }
    ]
  }
```

### Step 5: Charlie votes for option A

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "vote", arguments: { option: "0" }, caller: "charlie" })
→ {
    success: true,
    stateChanges: [
      { field: "voters", operation: "insert", key: "charlie", newValue: "true" },
      { field: "votesA", operation: "increment", previousValue: "1", newValue: "2" }
    ]
  }
```

### Step 6: Alice tries to vote again (assertion failure — already voted)

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "vote", arguments: { option: "0" }, caller: "alice" })
→ {
    success: false,
    errors: [{ message: "Assertion failed: already voted", severity: "error" }]
  }
✓ Duplicate vote correctly rejected
```

### Step 7: Verify state after votes

```
midnight-simulate-state({ sessionId: "vote-session-1" })
→ ledgerState: {
    votesA: { value: "2" },
    votesB: { value: "1" },
    voters: { value: { "alice": "true", "bob": "true", "charlie": "true" } },
    votingOpen: { value: "true" }
  }
✓ Option A: 2 votes (alice, charlie)
✓ Option B: 1 vote (bob)
✓ All three voters recorded
```

### Step 8: Close voting

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "closeVoting", caller: "owner" })
→ { success: true, stateChanges: [{ field: "votingOpen", previousValue: "true", newValue: "false" }] }
```

### Step 9: Tally results

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "tally" })
→ { success: true, result: ["2", "1"], stateChanges: [] }
✓ Option A: 2, Option B: 1
```

### Step 10: Dave tries to vote after close (assertion failure)

```
midnight-simulate-call({ sessionId: "vote-session-1", circuit: "vote", arguments: { option: "0" }, caller: "dave" })
→ {
    success: false,
    errors: [{ message: "Assertion failed: voting is closed", severity: "error" }]
  }
✓ Voting after close correctly rejected
```

### Step 11: Cleanup

```
midnight-simulate-delete({ sessionId: "vote-session-1" })
→ { success: true }
```

## What This Tests

- **Map membership (voter tracking)** — recording who has voted to prevent duplicates
- **Assertion on duplicate votes** — same voter cannot vote twice
- **State transitions (open to closed)** — voting can be opened and closed by the owner
- **Tallying** — counting votes per option across multiple voters
- **Multi-user voting** — multiple callers casting votes in the same session
- **Access control** — only the owner can open/close voting

## Limitations

This archetype uses simple Counter-based tallying with two options. A more sophisticated voting contract might use weighted votes, ranked choice, or privacy-preserving mechanisms. The simulation verifies the basic voting logic but does not test Zero Knowledge Proof (ZKP) privacy properties — those require full compilation and on-chain testing.
