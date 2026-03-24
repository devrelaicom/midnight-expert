# Disclosure Error Examples

## When This Error Occurs

The compiler detected that a witness-derived value crosses the public boundary (ledger write, exported return, conditional branch) without an explicit `disclose()` call. The error message is: `potential witness-value disclosure must be declared but is not`.

## Examples

### Witness value assigned to ledger field

**Error:**
`potential witness-value disclosure must be declared but is not`

**Code that caused it:**
```compact
witness getBalance(): Uint<64>;

export ledger balance: Uint<64>;

export circuit setBalance(): [] {
  balance = getBalance();
}
```

**Diagnosis:** `getBalance()` returns a witness value (private, prover-side). Assigning it to a ledger field makes it public on-chain. The compiler requires `disclose()` to acknowledge this privacy boundary crossing.

**Fix:**
```compact
witness getBalance(): Uint<64>;

export ledger balance: Uint<64>;

export circuit setBalance(): [] {
  balance = disclose(getBalance());
}
```

### Witness value in if condition

**Error:**
`potential witness-value disclosure must be declared but is not` (via the conditional path)

**Code that caused it:**
```compact
witness getIsAuthorized(): Boolean;

export ledger value: Uint<64>;

export circuit guardedUpdate(): [] {
  if (getIsAuthorized()) {
    value = 42;
  }
}
```

**Diagnosis:** The `if` condition controls which ledger state is committed. A witness value in a branch condition effectively discloses information about the witness (whether it was true or false is observable from the resulting state). The compiler requires `disclose()` on the condition.

**Fix:**
```compact
witness getIsAuthorized(): Boolean;

export ledger value: Uint<64>;

export circuit guardedUpdate(): [] {
  if (disclose(getIsAuthorized())) {
    value = 42;
  }
}
```

### Witness value returned from exported circuit

**Error:**
`potential witness-value disclosure must be declared but is not` (via the return path)

**Code that caused it:**
```compact
witness getSecret(): Field;

export circuit revealSecret(): Field {
  return getSecret();
}
```

**Diagnosis:** Returning a witness value from an exported circuit exposes it to the caller (a public operation). The compiler requires `disclose()` on the return value to acknowledge this.

**Fix:**
```compact
witness getSecret(): Field;

export circuit revealSecret(): Field {
  return disclose(getSecret());
}
```

### Witness value passed to ADT method

**Error:**
`potential witness-value disclosure must be declared but is not` (via ledger operation)

**Code that caused it:**
```compact
witness getAmount(): Uint<64>;

export ledger counter: Counter;

export circuit increment(): [] {
  counter.increment(getAmount());
}
```

**Diagnosis:** Calling a ledger method like `counter.increment()` modifies on-chain state. The witness-derived argument crosses the public boundary when it's used in the ledger operation. `disclose()` must wrap the argument.

**Fix:**
```compact
witness getAmount(): Uint<64>;

export ledger counter: Counter;

export circuit increment(): [] {
  counter.increment(disclose(getAmount()));
}
```

### Transitive disclosure through intermediate computation

**Error:**
`potential witness-value disclosure must be declared but is not` (via multi-step path)

**Code that caused it:**
```compact
witness getSecret(): Field;

export ledger storedValue: Field;

export circuit processSecret(): [] {
  const x = getSecret();
  const y = x + 1;
  storedValue = y;
}
```

**Diagnosis:** The compiler traces witness origin through intermediate variables. `x` is witness-derived, `y` is computed from `x` so it is also witness-tainted, and `storedValue` is a ledger field. The disclosure happens at the ledger assignment boundary, not at every intermediate step.

**Fix:**
```compact
witness getSecret(): Field;

export ledger storedValue: Field;

export circuit processSecret(): [] {
  const x = getSecret();
  const y = x + 1;
  storedValue = disclose(y);
}
```

## Anti-Patterns

### Wrapping every variable in disclose() defensively

**Wrong:** Adding `disclose()` around every witness call and every intermediate variable.
**Problem:** Only values crossing the public boundary need `disclose()`. Wrapping intermediate values that stay within the circuit adds unnecessary disclosure points and can leak information you intended to keep private.
**Instead:** Place `disclose()` at the exact point where the value crosses the public boundary — the ledger assignment, the return statement, or the branch condition.

### Adding disclose() on non-witness values

**Wrong:** Seeing a disclosure error and adding `disclose()` on a constant or a ledger-read value.
**Problem:** The compiler traces witness origin. Non-witness values (constants, ledger reads, circuit parameters) never trigger this error. If you see the error, the value is definitely witness-derived. Adding `disclose()` on non-witness values is a no-op that adds confusion.
**Instead:** Trace the value back to its source. Follow the variable assignments until you find the `witness` call. Then place `disclose()` at the boundary where that witness-tainted value becomes public.

### Not reading the "via this path" trace

**Wrong:** Guessing where to add `disclose()` based on the error line number alone.
**Problem:** The error message includes a data flow path showing exactly how the witness value reaches the public boundary. The path may traverse several intermediate variables and function calls. The error line number points to the disclosure site, but the path shows the full chain.
**Instead:** Read the "via this path" trace in the error output. It shows each step from the witness origin to the disclosure point. Place `disclose()` at the final step before the public boundary.
