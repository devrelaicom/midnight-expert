# Witness Management

## When to Use

When testing circuits that use witnesses, or when you need to control witness return values for edge-case testing.

## Background

In Compact, `witness` declarations define functions whose implementations live in TypeScript on the prover side. During simulation, the OZ simulator provides a witness execution environment. You can override individual witnesses to return specific values.

## The `witnessOverrides` Parameter

A Record mapping witness names to return values. When a circuit calls a witness, the simulator uses the override value instead of the default implementation.

## Providing a Witness Override

```
Contract code:
  witness getSecret(): Field;
  export circuit reveal(): Field {
    return disclose(getSecret());
  }

Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "reveal",
  witnessOverrides: { "getSecret": "42" }
})
Response: {
  success: true,
  result: "42",
  stateChanges: []
}
Action: Witness returned 42. Circuit executed with that value.
```

## Testing Authorization Rejection

```
Contract code:
  witness isAuthorized(): Boolean;
  export circuit doRestricted(): [] {
    assert(disclose(isAuthorized()), "Not authorized");
    count.increment(1);
  }

Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "doRestricted",
  witnessOverrides: { "isAuthorized": "false" }
})
Response: {
  success: false,
  errors: [{ message: "Assertion failed: Not authorized", severity: "error" }]
}
Action: Assertion fired as expected. Witness override successfully tested the rejection path.
```

## Default Witness Behavior

When no override is provided, the simulator uses the default witness factory from the compiled artifacts. If no default exists, the witness returns a zero/empty value for its type.

## Testing Edge Cases with Witnesses

- Provide boundary values (max uint, empty bytes)
- Provide values that should trigger assertions
- Test the happy path and the rejection path separately

## Anti-Patterns

### Overriding unused witnesses

Overriding witnesses that the circuit doesn't actually call has no effect and creates confusion about what's being tested.

### Wrong-typed witness overrides

Providing a value whose type doesn't match the witness return type causes a runtime type error. Check the witness declaration before providing overrides.

### One-sided witness testing

Not testing both the valid and invalid witness paths means you only verify half the logic. Always test the acceptance and rejection paths for witness-gated behavior.
