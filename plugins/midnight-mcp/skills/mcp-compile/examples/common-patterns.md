# Common Compilation Patterns

## When to Apply

When writing or reviewing Compact code before sending it to the hosted compiler. These patterns show correct implementations that compile cleanly — use them as targets when fixing errors or writing new code.

## Examples

### Minimal contract with Counter state

**Code:**
```compact
pragma language_version >= 0.14.0;

ledger {
  count: Counter;
}

export circuit increment(amount: Uint<64>): [] {
  count.increment(amount);
}

export circuit get_count(): Uint<64> {
  return count.value();
}
```

**Why this compiles:** Uses `[]` for void return, `Counter` from ledger ADTs, `Uint<64>` for numeric parameters. No imports needed — `Counter` and `Uint` are built-in.

### Contract with Map state and witness

**Code:**
```compact
pragma language_version >= 0.14.0;

import CompactStandardLibrary;

ledger {
  balances: Map<Bytes<32>, Uint<64>>;
}

witness owner_key: Bytes<32>;

export circuit set_balance(key: Bytes<32>, amount: Uint<64>): [] {
  assert key == owner_key "only owner can set balances";
  balances.insert(key, amount);
}

export circuit get_balance(key: Bytes<32>): Uint<64> {
  return balances.lookup(key).value;
}
```

**Why this compiles:** Imports `CompactStandardLibrary` for `Map` operations. Uses `Bytes<32>` for keys, `assert` with string message, and `Map.lookup().value` to retrieve entries.

### Export with disclosure

**Code:**
```compact
pragma language_version >= 0.14.0;

ledger {
  total: Counter;
}

witness secret_value: Field;

export circuit add_with_disclosure(amount: Uint<64>): [] {
  disclose(secret_value);
  total.increment(amount);
}
```

**Why this compiles:** The `disclose(secret_value)` call explicitly declares that the witness value will be revealed on-chain. Without this, the compiler would reject the circuit with a disclosure error because `secret_value` is used in a context that requires disclosure.

### Enum and struct definitions

**Code:**
```compact
pragma language_version >= 0.14.0;

enum Status {
  active,
  paused,
  closed
}

struct Proposal {
  id: Uint<64>,
  status: Status,
  votes: Uint<64>
}

ledger {
  current: Proposal;
}

export circuit get_status(): Status {
  return current.status;
}
```

**Why this compiles:** Enums use comma-separated variants (no values). Structs use field-name-colon-type syntax. Enum and struct definitions must appear before their use in ledger or circuit declarations.

## Anti-Patterns

### Using `void` or `Void` return type

**Wrong:**
```compact
export circuit doSomething(): Void { ... }
```

**Problem:** Compact has no `Void` keyword. The compiler sees it as an identifier and produces a confusing parse error.

**Instead:** Use `[]` (empty tuple) for circuits that return nothing:
```compact
export circuit doSomething(): [] { ... }
```

### Using `::` for enum access

**Wrong:**
```compact
if (status == Status::active) { ... }
```

**Problem:** Compact uses dot notation for enum variant access, not Rust-style double-colon.

**Instead:**
```compact
if (status == Status.active) { ... }
```

### Omitting `pragma language_version`

**Wrong:**
```compact
ledger { count: Counter; }
export circuit inc(): [] { count.increment(1); }
```

**Problem:** The compiler requires a pragma declaration. Without it, compilation fails with a pragma-related error.

**Instead:** Always include `pragma language_version >= 0.14.0;` (or the appropriate version) as the first line.
