# Witness Error Examples

## When This Error Occurs

A circuit call fails because of a witness-related issue — the witness was not provided, returned the wrong type, or its return value triggered a downstream assertion.

## Examples

### Witness not provided

```
Before:
  Contract code:
    witness getSecret(): Field;
    export circuit reveal(): Field {
      return disclose(getSecret());
    }

  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "reveal"
  })

Error:
  { success: false, errors: [{ message: "Witness 'getSecret' returned no value", severity: "error" }] }

Diagnosis:
  The circuit calls witness getSecret() but no witnessOverrides was provided and no default implementation exists in the compiled artifacts.

Fix:
  Provide a witnessOverrides value for the required witness:
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "reveal",
    witnessOverrides: { "getSecret": "42" }
  })
  → success: true, result: "42"
```

### Witness returns wrong type

```
Before:
  Contract code:
    witness getAmount(): Uint<64>;
    export circuit deposit(): [] {
      count.increment(disclose(getAmount()));
    }

  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "deposit",
    witnessOverrides: { "getAmount": "not-a-number" }
  })

Error:
  { success: false, errors: [{ message: "Type mismatch: witness 'getAmount' expected Uint<64>, received invalid value", severity: "error" }] }

Diagnosis:
  The witness override value doesn't match the declared witness return type. "not-a-number" is not a valid Uint<64>.

Fix:
  Check the witness declaration in the contract code and provide a correctly-typed value:
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "deposit",
    witnessOverrides: { "getAmount": "100" }
  })
  → success: true
```

### Witness override triggers downstream assertion

```
Before:
  Contract code:
    witness getTransferAmount(): Uint<64>;
    export circuit withdraw(): [] {
      const amount = disclose(getTransferAmount());
      assert(amount <= count, "Insufficient balance");
      count.decrement(amount);
    }

  (Current state: count = 50)
  midnight-simulate-call({
    sessionId: "abc-123-def",
    circuit: "withdraw",
    witnessOverrides: { "getTransferAmount": "100" }
  })

Error:
  { success: false, errors: [{ message: "Assertion failed: Insufficient balance", severity: "error" }] }

Diagnosis:
  The witness value 100 was accepted (correct type) but caused an assertion failure because 100 > 50 (current count). The witness override tested the rejection path.

Fix:
  This depends on intent:
  - If testing rejection: this IS the expected result — verify state unchanged
  - If testing happy path: provide a valid value within balance:
    witnessOverrides: { "getTransferAmount": "30" }
    → success: true
```

## Anti-Patterns

### Overriding nonexistent witnesses

Overriding witnesses that don't exist in the contract is silently ignored — no error, but no effect. Verify the witness name matches a `witness` declaration in the contract source.

### One-sided witness testing

Not testing both valid and invalid witness paths misses critical guard behavior. Always test:
- Happy path: witness returns a valid value, circuit succeeds
- Rejection path: witness returns an invalid/boundary value, assertion fires correctly
