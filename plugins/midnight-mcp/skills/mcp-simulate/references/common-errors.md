# Common Errors

Error responses from the simulation tools, with example payloads and recovery steps.

## Session Not Found / Expired

Returned when the `sessionId` does not match any active session. Sessions expire after 15 minutes of inactivity.

**Example response:**

```json
{
  "error": "session_not_found",
  "message": "No active simulation session with ID 'sim_a1b2c3d4e5f6'. The session may have expired or been deleted.",
  "sessionId": "sim_a1b2c3d4e5f6"
}
```

**Recovery:**

1. Deploy a new session with `midnight-simulate-deploy` using the same source code
2. Replay the sequence of circuit calls needed to reach the desired state
3. If you need long-running sessions, make periodic calls to keep the session alive

## Circuit Not Found

Returned when the `circuit` parameter does not match any exported circuit in the deployed contract.

**Example response:**

```json
{
  "error": "circuit_not_found",
  "message": "No exported circuit named 'incremnt' in the deployed contract. Available circuits: increment, decrement, incrementBy, getCount",
  "circuit": "incremnt"
}
```

**Recovery:**

1. Check the circuit name for typos -- names are case-sensitive
2. Use `midnight-simulate-state` to list available circuits and their signatures
3. Only `export circuit` declarations are callable -- internal `circuit` and `pure circuit` helpers are not entry points

## Type Mismatch

Returned when the provided arguments do not match the circuit's parameter types.

**Example response:**

```json
{
  "error": "type_mismatch",
  "message": "Argument 0 for circuit 'incrementBy': expected Uint<64>, got String 'abc'",
  "circuit": "incrementBy",
  "parameterIndex": 0,
  "expectedType": "Uint<64>",
  "actualValue": "abc"
}
```

**Common causes and fixes:**

| Cause | Fix |
|-------|-----|
| Wrong number of arguments | Check the circuit signature with `midnight-simulate-state` |
| String where number expected | Pass `42` instead of `"abc"` |
| Number where hex string expected | `Bytes<N>` requires a `0x`-prefixed hex string, not a number |
| Wrong hex length | `Bytes<32>` needs exactly 64 hex characters after `0x` |
| Object where array expected | `Vector<N, T>` maps to a JSON array, not an object |

**Recovery:**

1. Use `midnight-simulate-state` to inspect the circuit's parameter signature
2. Refer to `references/argument-formats.md` for the Compact-to-JSON type mapping
3. Fix the argument value and retry the call

## Assertion Failure

Returned when a circuit's `assert()` statement fails during execution. The ledger state is NOT modified on assertion failure.

**Example response:**

```json
{
  "error": "assertion_failure",
  "message": "Assertion failed in circuit 'incrementBy': Amount must be positive",
  "circuit": "incrementBy",
  "assertionMessage": "Amount must be positive"
}
```

**Common causes:**

| Assertion message (example) | Likely cause |
|-----------------------------|--------------|
| "Amount must be positive" | Passed `0` to a circuit that requires `amount > 0` |
| "Not authorized" | Caller identity does not match the stored authority |
| "Already used" | Nullifier or one-time token was already consumed |
| "Exceeds limit" | Value out of allowed range |

**Recovery:**

1. Read the assertion message -- it usually explains the constraint that was violated
2. Use `midnight-simulate-state` to inspect the current ledger state and understand preconditions
3. Adjust the arguments or call circuits in a different order to satisfy the contract's invariants
4. The ledger state is unchanged after a failed assertion, so no rollback is needed

## Compilation Error

Returned by `midnight-simulate-deploy` when the provided Compact source code fails to compile.

**Example response:**

```json
{
  "error": "compilation_error",
  "message": "Failed to compile Compact source",
  "details": [
    {
      "line": 5,
      "column": 12,
      "message": "Unknown type 'Void'. Did you mean '[]'?"
    }
  ]
}
```

**Recovery:**

1. Fix the syntax or type error indicated in `details`
2. Common mistakes: using `Void` instead of `[]`, using `ledger { }` block syntax instead of individual `export ledger` declarations, missing `pragma language_version 0.21;`
3. Use the `compact-core:compact-compilation` skill to verify source before deploying
4. Redeploy with the corrected source

## Summary

| Error | Cause | Key recovery action |
|-------|-------|---------------------|
| `session_not_found` | Session expired or deleted | Deploy a new session |
| `circuit_not_found` | Typo or non-exported circuit | Check name with `midnight-simulate-state` |
| `type_mismatch` | Wrong argument type or count | Consult `references/argument-formats.md` |
| `assertion_failure` | Contract invariant violated | Read assertion message, check state |
| `compilation_error` | Invalid Compact source | Fix source, use compilation skill to verify |
