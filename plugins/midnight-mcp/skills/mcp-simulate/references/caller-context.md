# Caller Context

## When to Use

When testing access control, ownership, token transfers between users, or any multi-party interaction.

## The `caller` Parameter

Available on both deploy and call. Sets the identity of the transaction sender. When a circuit checks the caller (e.g., `assert(caller == owner)`), the simulator uses this value.

## Ownership Check

```
Deploy: midnight-simulate-deploy({ code: "<ownable contract>", caller: "alice" })
→ sessionId: "abc-123-def", ledgerState: { owner: { type: "Bytes<32>", value: "alice" } }

Call as owner (succeeds):
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "restricted", caller: "alice" })
  → success: true

Call as non-owner (fails):
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "restricted", caller: "bob" })
  → success: false, errors: [{ message: "Assertion failed: caller must be owner" }]
```

## Token Transfer

```
Deploy as Alice → mint(100) as Alice → transfer(30, "bob") as Alice
→ ledgerState: { balances: { "alice": "70", "bob": "30" } }

Check balance as Bob:
  midnight-simulate-call({ sessionId: "...", circuit: "getBalance", caller: "bob" })
  → result: "30"
```

## Deploy Caller vs Call Caller

The `caller` on deploy sets the contract creator/owner. The `caller` on call sets the transaction sender for that specific call. They can differ.

- Deploy with `caller: "alice"` — Alice becomes the contract owner
- Call with `caller: "bob"` — Bob is the sender for that call
- The contract's ledger determines what Bob can do based on its access control logic

## Multi-Party Workflows

Alternate `caller` between calls to simulate interactions between different users. The session maintains one shared state — all callers operate on the same ledger.

```
1. Deploy as "alice" (owner)
2. Call mint(100) as "alice" → alice has 100
3. Call transfer(30, "bob") as "alice" → alice has 70, bob has 30
4. Call transfer(10, "charlie") as "bob" → alice has 70, bob has 20, charlie has 10
```

## Anti-Patterns

### Forgetting to set caller

Not setting `caller` when testing access control means the default may not match the expected owner. Always explicitly set `caller` on deploy to establish ownership, and on each call to specify who is acting.

### Same caller for everything

Using the same caller for all calls when testing multi-party logic defeats the purpose. Alternate callers to verify that access control actually works.

### Assuming caller validation

Caller values are arbitrary strings in simulation — they are not validated as addresses. Consistency matters: `"alice"` and `"Alice"` are treated as different callers.
