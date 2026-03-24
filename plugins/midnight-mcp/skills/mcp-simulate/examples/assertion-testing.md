# Assertion Testing Examples

## When to Apply

When you want to verify that a contract's guard logic correctly rejects invalid operations. Test both the rejection path (assertion fires) and the acceptance path (valid inputs succeed).

## Examples

### Testing authorization rejection

```
1. Deploy with owner:
   midnight-simulate-deploy({ code: "<ownable contract>", caller: "alice" })
   → sessionId: "auth-1"
   → ledgerState: { owner: { type: "Bytes<32>", value: "alice" } }

2. Call restricted circuit as non-owner:
   midnight-simulate-call({ sessionId: "auth-1", circuit: "restricted", caller: "bob" })
   → success: false
   → errors: [{ message: "Assertion failed: caller must be owner" }]

3. Verify state unchanged:
   midnight-simulate-state({ sessionId: "auth-1" })
   → ledgerState: { owner: { type: "Bytes<32>", value: "alice" } }
   ✓ State unchanged after assertion failure

4. Call restricted circuit as owner:
   midnight-simulate-call({ sessionId: "auth-1", circuit: "restricted", caller: "alice" })
   → success: true
   ✓ Owner can call the restricted circuit

5. Delete:
   midnight-simulate-delete({ sessionId: "auth-1" })
```

### Testing insufficient balance

```
1. Deploy token contract:
   midnight-simulate-deploy({ code: "<token contract>", caller: "alice" })
   → sessionId: "balance-1"

2. Mint 100 tokens:
   midnight-simulate-call({ sessionId: "balance-1", circuit: "mint", arguments: { amount: "100" }, caller: "alice" })
   → success: true

3. Attempt transfer of 200 (exceeds balance):
   midnight-simulate-call({ sessionId: "balance-1", circuit: "transfer", arguments: { amount: "200", to: "bob" }, caller: "alice" })
   → success: false
   → errors: [{ message: "Assertion failed: insufficient balance" }]

4. Verify balance unchanged:
   midnight-simulate-state({ sessionId: "balance-1" })
   → ledgerState: { balances: { value: { "alice": "100" } } }
   ✓ Balance still 100 — failed transfer did not modify state

5. Transfer valid amount:
   midnight-simulate-call({ sessionId: "balance-1", circuit: "transfer", arguments: { amount: "50", to: "bob" }, caller: "alice" })
   → success: true
   ✓ Valid transfer succeeds

6. Delete:
   midnight-simulate-delete({ sessionId: "balance-1" })
```

### Testing input validation

```
1. Deploy contract with range-checked input:
   midnight-simulate-deploy({ code: "<contract with assert(n > 0 && n <= 100)>" })
   → sessionId: "range-1"

2. Call with zero (below range):
   midnight-simulate-call({ sessionId: "range-1", circuit: "process", arguments: { n: "0" } })
   → success: false
   → errors: [{ message: "Assertion failed: value must be between 1 and 100" }]

3. Call with 101 (above range):
   midnight-simulate-call({ sessionId: "range-1", circuit: "process", arguments: { n: "101" } })
   → success: false
   → errors: [{ message: "Assertion failed: value must be between 1 and 100" }]

4. Verify state unchanged after both failures:
   midnight-simulate-state({ sessionId: "range-1" })
   ✓ Ledger unchanged

5. Call with valid value:
   midnight-simulate-call({ sessionId: "range-1", circuit: "process", arguments: { n: "50" } })
   → success: true
   ✓ Valid input accepted

6. Delete:
   midnight-simulate-delete({ sessionId: "range-1" })
```

### Testing post-condition assertion

```
1. Deploy contract with invariant check:
   midnight-simulate-deploy({ code: "<contract where circuit asserts result <= maxSupply>" })
   → sessionId: "postcond-1"

2. Call with value that would violate invariant:
   midnight-simulate-call({ sessionId: "postcond-1", circuit: "mint", arguments: { amount: "999999999" } })
   → success: false
   → errors: [{ message: "Assertion failed: would exceed max supply" }]

3. Verify state unchanged:
   midnight-simulate-state({ sessionId: "postcond-1" })
   ✓ Ledger unchanged — invariant preserved

4. Call with valid amount:
   midnight-simulate-call({ sessionId: "postcond-1", circuit: "mint", arguments: { amount: "100" } })
   → success: true
   ✓ Valid amount accepted

5. Delete:
   midnight-simulate-delete({ sessionId: "postcond-1" })
```

## Anti-Patterns

### Not verifying unchanged state

Not verifying that state is unchanged after an assertion failure. This is the critical check — a failed call should NEVER modify ledger state. Always call `midnight-simulate-state` after a failure and confirm values match pre-failure state.

### Happy path only

Only testing happy paths misses the most important security properties. Assertion testing is specifically about the unhappy paths — verify that the contract correctly rejects operations it should reject.

### Confusing assertions with bugs

A deliberate assertion failure is the contract working correctly. When testing guards, `success: false` with an assertion message is the expected result. Only treat it as a bug if the assertion fires when it shouldn't.
