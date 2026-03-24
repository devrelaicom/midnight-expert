# Execution Error Examples

## When This Error Occurs

A circuit call (`midnight-simulate-call`) fails during execution — the circuit was found but execution produced an error.

## Examples

### Assertion failure

```
Before:
  midnight-simulate-deploy({ code: "<ownable contract>", caller: "alice" })
  → sessionId: "abc-123-def"
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "restricted", caller: "bob" })

Error:
  { success: false, errors: [{ message: "Assertion failed: caller must be owner", severity: "error" }] }

Diagnosis:
  The circuit's assert() statement fired because the guard condition was not met. State is unchanged.
  This may be:
  - Expected behavior (testing that guards work correctly)
  - Wrong caller (should have used "alice")
  - Wrong state (a prerequisite call was missed)

Fix:
  Understand why the assertion fired:
  - Check the caller — is this the right identity for this operation?
  - Check current state — are preconditions met?
  - If testing guard behavior, this IS the expected result — verify state unchanged
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "restricted", caller: "alice" })
  → success: true
```

### Circuit not found

```
Before:
  midnight-simulate-deploy({ code: "<counter contract>" })
  → sessionId: "abc-123-def", circuits: [{ name: "inc", ... }, { name: "get", ... }]
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "increment" })

Error:
  { success: false, errors: [{ message: "CIRCUIT_NOT_FOUND: 'increment'. Available circuits: inc, get", severity: "error" }] }

Diagnosis:
  Typo in circuit name. The circuit is named "inc", not "increment".
  Other causes: calling a non-exported circuit, or calling a circuit from a different contract.

Fix:
  Check the circuit name against the deploy response or state:
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc" })
  → success: true
```

### Parameter type mismatch

```
Before:
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "inc",
    arguments: { n: "not-a-number" }
  })

Error:
  { success: false, errors: [{ message: "Type error: expected Uint<64> for parameter 'n', received invalid value", severity: "error" }] }

Diagnosis:
  The argument value doesn't match the circuit's parameter type. "not-a-number" is not a valid Uint<64>.

Fix:
  Check the circuit's parameter types in the deploy response or state metadata:
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "inc",
    arguments: { n: "5" }
  })
  → success: true
```

### Missing required parameter

```
Before:
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "transfer"
  })

Error:
  { success: false, errors: [{ message: "Expected 2 arguments (amount, to) but received 0", severity: "error" }] }

Diagnosis:
  The circuit requires arguments that were not provided.

Fix:
  Check circuit metadata for required parameters, then provide them:
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "transfer",
    arguments: { amount: "50", to: "0xbob" }
  })
  → success: true
```

### Invalid state operation

```
Before:
  midnight-simulate-deploy({ code: "<token contract>", caller: "alice" })
  → sessionId: "abc-123-def"
  (no tokens minted yet — balance is 0)
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "transfer", arguments: { amount: "100", to: "0xbob" }, caller: "alice" })

Error:
  { success: false, errors: [{ message: "Assertion failed: insufficient balance", severity: "error" }] }

Diagnosis:
  The circuit tried to transfer tokens but the current balance is 0. The operation's preconditions are not met.

Fix:
  Check current state and ensure preconditions are met:
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "mint", arguments: { amount: "100" }, caller: "alice" })
  → success: true
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "transfer", arguments: { amount: "50", to: "0xbob" }, caller: "alice" })
  → success: true
```

## Anti-Patterns

### Blaming the simulator

Treating assertion failures as bugs in the simulator. They are usually correct behavior — the contract is doing its job by rejecting invalid operations.

### Skipping metadata checks

Not checking circuit metadata before calling. The metadata tells you exactly what arguments to provide, their types, and what ledger fields the circuit accesses.

### Assuming failed calls modify state

Failed calls (assertion failures, type errors, missing parameters) do NOT modify ledger state. The ledger remains exactly as it was before the failed call. No rollback is needed because no mutation occurred.
