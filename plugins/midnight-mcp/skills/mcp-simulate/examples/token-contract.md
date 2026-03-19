# Token Contract Archetype

## Contract Code

```compact
pragma language_version >= 0.14;

import CompactStandardLibrary;

export ledger balances: Map<Bytes<32>, Uint<64>>;
export ledger owner: Bytes<32>;

export circuit mint(amount: Uint<64>): [] {
  assert(caller == owner, "only owner can mint");
  const current = balances.lookup(disclose(caller)).with_default(0);
  balances.insert(disclose(caller), current + amount);
}

export circuit transfer(amount: Uint<64>, to: Bytes<32>): [] {
  const senderBalance = balances.lookup(disclose(caller)).with_default(0);
  assert(senderBalance >= amount, "insufficient balance");
  balances.insert(disclose(caller), senderBalance - amount);
  const receiverBalance = balances.lookup(to).with_default(0);
  balances.insert(to, receiverBalance + amount);
}

export pure circuit getBalance(user: Bytes<32>): Uint<64> {
  return balances.lookup(user).with_default(0);
}
```

## Simulation Sequence

### Step 1: Deploy as owner

```
midnight-simulate-deploy({ code: "<token contract source>", caller: "alice" })
→ {
    success: true,
    sessionId: "token-session-1",
    circuits: [
      { name: "mint", isPublic: true, isPure: false, parameters: [{ name: "amount", type: "Uint<64>" }], readsLedger: ["balances", "owner"], writesLedger: ["balances"] },
      { name: "transfer", isPublic: true, isPure: false, parameters: [{ name: "amount", type: "Uint<64>" }, { name: "to", type: "Bytes<32>" }], readsLedger: ["balances"], writesLedger: ["balances"] },
      { name: "getBalance", isPublic: true, isPure: true, parameters: [{ name: "user", type: "Bytes<32>" }], readsLedger: ["balances"], writesLedger: [] }
    ],
    ledgerState: {
      balances: { type: "Map<Bytes<32>, Uint<64>>", value: {} },
      owner: { type: "Bytes<32>", value: "alice" }
    }
  }
```

### Step 2: Mint 100 tokens as owner

```
midnight-simulate-call({ sessionId: "token-session-1", circuit: "mint", arguments: { amount: "100" }, caller: "alice" })
→ {
    success: true,
    stateChanges: [{ field: "balances", operation: "insert", key: "alice", newValue: "100" }],
    updatedLedger: { balances: { value: { "alice": "100" } }, owner: { value: "alice" } }
  }
```

### Step 3: Verify mint

```
midnight-simulate-state({ sessionId: "token-session-1" })
→ ledgerState: { balances: { value: { "alice": "100" } }, owner: { value: "alice" } }
✓ Alice has 100 tokens
```

### Step 4: Transfer 30 to Bob

```
midnight-simulate-call({ sessionId: "token-session-1", circuit: "transfer", arguments: { amount: "30", to: "bob" }, caller: "alice" })
→ {
    success: true,
    stateChanges: [
      { field: "balances", operation: "update", key: "alice", previousValue: "100", newValue: "70" },
      { field: "balances", operation: "insert", key: "bob", newValue: "30" }
    ]
  }
```

### Step 5: Verify transfer

```
midnight-simulate-state({ sessionId: "token-session-1" })
→ ledgerState: { balances: { value: { "alice": "70", "bob": "30" } } }
✓ Alice: 100 - 30 = 70
✓ Bob: 0 + 30 = 30
```

### Step 6: Attempt mint as non-owner (assertion failure)

```
midnight-simulate-call({ sessionId: "token-session-1", circuit: "mint", arguments: { amount: "50" }, caller: "bob" })
→ {
    success: false,
    errors: [{ message: "Assertion failed: only owner can mint", severity: "error" }]
  }
```

### Step 7: Verify state unchanged after failure

```
midnight-simulate-state({ sessionId: "token-session-1" })
→ ledgerState: { balances: { value: { "alice": "70", "bob": "30" } } }
✓ Balances unchanged — failed mint did not modify state
```

### Step 8: Cleanup

```
midnight-simulate-delete({ sessionId: "token-session-1" })
→ { success: true }
```

## What This Tests

- **Access control via caller context** — only the owner can mint tokens
- **Map state mutations** — insert and update operations on the balances Map
- **Assertion testing** — non-owner mint is correctly rejected
- **Multi-user interaction** — Alice and Bob interacting with the same shared ledger
- **State unchanged after failure** — failed operations preserve ledger integrity

## Limitations

The Bytes<32> caller values in simulation are arbitrary strings. In a real deployment, these would be cryptographic addresses. The simulation verifies the contract logic works correctly but does not validate that caller values are proper addresses. Map operations in simulation should mirror on-chain behavior, but verify edge cases around empty Maps and missing keys.
