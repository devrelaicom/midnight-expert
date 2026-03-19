# Multi-User Testing Examples

## When to Apply

When testing interactions between different parties — ownership, transfers, approvals, voting. Use the `caller` parameter to simulate different users acting on the same shared ledger.

## Examples

### Ownership transfer

```
1. Deploy as Alice (owner):
   midnight-simulate-deploy({ code: "<ownable contract>", caller: "alice" })
   → sessionId: "owner-1"
   → ledgerState: { owner: { type: "Bytes<32>", value: "alice" } }

2. Alice calls owner-only circuit (succeeds):
   midnight-simulate-call({ sessionId: "owner-1", circuit: "restricted", caller: "alice" })
   → success: true

3. Bob calls owner-only circuit (fails):
   midnight-simulate-call({ sessionId: "owner-1", circuit: "restricted", caller: "bob" })
   → success: false
   → errors: [{ message: "Assertion failed: caller must be owner" }]

4. Alice transfers ownership to Bob:
   midnight-simulate-call({ sessionId: "owner-1", circuit: "transferOwnership", arguments: { newOwner: "bob" }, caller: "alice" })
   → success: true

5. Verify ownership changed:
   midnight-simulate-state({ sessionId: "owner-1" })
   → ledgerState: { owner: { type: "Bytes<32>", value: "bob" } }
   ✓ Bob is now owner

6. Bob calls owner-only circuit (now succeeds):
   midnight-simulate-call({ sessionId: "owner-1", circuit: "restricted", caller: "bob" })
   → success: true

7. Alice calls owner-only circuit (now fails):
   midnight-simulate-call({ sessionId: "owner-1", circuit: "restricted", caller: "alice" })
   → success: false
   → errors: [{ message: "Assertion failed: caller must be owner" }]
   ✓ Alice is no longer owner

8. Delete:
   midnight-simulate-delete({ sessionId: "owner-1" })
```

### Token transfer between users

```
1. Deploy as Alice:
   midnight-simulate-deploy({ code: "<token contract>", caller: "alice" })
   → sessionId: "token-1"

2. Alice mints 100 tokens:
   midnight-simulate-call({ sessionId: "token-1", circuit: "mint", arguments: { amount: "100" }, caller: "alice" })
   → success: true

3. Alice transfers 30 to Bob:
   midnight-simulate-call({ sessionId: "token-1", circuit: "transfer", arguments: { amount: "30", to: "bob" }, caller: "alice" })
   → success: true

4. Verify balances:
   midnight-simulate-state({ sessionId: "token-1" })
   → ledgerState: { balances: { value: { "alice": "70", "bob": "30" } } }
   ✓ Alice: 100 - 30 = 70
   ✓ Bob: 0 + 30 = 30

5. Bob transfers 10 to Charlie:
   midnight-simulate-call({ sessionId: "token-1", circuit: "transfer", arguments: { amount: "10", to: "charlie" }, caller: "bob" })
   → success: true

6. Verify all balances:
   midnight-simulate-state({ sessionId: "token-1" })
   → ledgerState: { balances: { value: { "alice": "70", "bob": "20", "charlie": "10" } } }
   ✓ Alice: 70 (unchanged)
   ✓ Bob: 30 - 10 = 20
   ✓ Charlie: 0 + 10 = 10
   ✓ Total supply: 70 + 20 + 10 = 100 (conservation check)

7. Delete:
   midnight-simulate-delete({ sessionId: "token-1" })
```

### Access control with multiple roles

```
1. Deploy:
   midnight-simulate-deploy({ code: "<role-based contract>", caller: "alice" })
   → sessionId: "roles-1"

2. Set Alice as admin:
   midnight-simulate-call({ sessionId: "roles-1", circuit: "setAdmin", arguments: { user: "alice" }, caller: "alice" })
   → success: true

3. Admin calls admin-only circuit (succeeds):
   midnight-simulate-call({ sessionId: "roles-1", circuit: "adminAction", caller: "alice" })
   → success: true

4. Non-admin calls admin-only circuit (fails):
   midnight-simulate-call({ sessionId: "roles-1", circuit: "adminAction", caller: "bob" })
   → success: false
   → errors: [{ message: "Assertion failed: caller must be admin" }]

5. Admin grants Bob admin role:
   midnight-simulate-call({ sessionId: "roles-1", circuit: "setAdmin", arguments: { user: "bob" }, caller: "alice" })
   → success: true

6. Bob retries admin-only circuit (now succeeds):
   midnight-simulate-call({ sessionId: "roles-1", circuit: "adminAction", caller: "bob" })
   → success: true
   ✓ Role grant took effect

7. Delete:
   midnight-simulate-delete({ sessionId: "roles-1" })
```

## Anti-Patterns

### Single caller testing

Using the same caller for all calls in a multi-user test defeats the purpose. The whole point is to verify that different callers get different results based on their identity and permissions.

### One-sided access testing

Not testing both authorized and unauthorized calls. Always test both paths — verify that authorized callers succeed AND unauthorized callers are rejected.

### Case-sensitive caller strings

Forgetting that caller values are strings — consistency matters. `"alice"` and `"Alice"` are treated as different callers. Use consistent casing throughout your test sequence.
