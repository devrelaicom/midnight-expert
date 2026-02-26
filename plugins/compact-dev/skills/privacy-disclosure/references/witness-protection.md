# Witness Protection

How the Compact compiler tracks and protects witness-derived values.

## Compiler Tracking Mechanism

The Compact compiler performs static analysis to track the flow of witness values through your code. Every value has a "taint" status:

- **Untainted**: Public values, constants, ledger reads
- **Tainted**: Witness function results and any values derived from them

## Taint Propagation Rules

### Direct Taint

```compact
witness get_secret(): Field;

const secret = get_secret();  // secret is TAINTED
```

### Arithmetic Propagation

Any arithmetic operation involving a tainted value produces a tainted result:

```compact
witness get_a(): Field;

const a = get_a(); // TAINTED
const b = a + 1; // TAINTED (a is tainted)
const c = b * 2; // TAINTED (b is tainted)
const d = c / 4; // TAINTED (c is tainted)
```

### Conditional Propagation

Both branches of a conditional inherit taint:

```compact
witness get_flag(): Boolean;
witness get_value(): Field;

const flag = get_flag(); // TAINTED
const value = get_value();   // TAINTED

// Result is TAINTED because value is tainted
const result = if flag { value } else { 0 };
```

### Struct/Enum Propagation

Any struct or enum containing a tainted field is entirely tainted:

```compact
struct Data {
    public_part: Field,
    secret_part: Field
}

witness get_secret(): Field;

const data = Data {
    public_part: 42,
    secret_part: get_secret()  // TAINTED
};

// Entire struct is TAINTED
// Even public_part access is considered tainted for safety
const x = data.public_part;  // TAINTED (conservative)
```

## Taint Clearing

### Commitment Functions

Commitment functions clear taint because they hide the input:

```compact
witness get_secret(): Field;

const secret = get_secret(); // TAINTED
const commitment = persistentCommit(secret); // UNTAINTED (commitment is safe)
```

### Hash Functions (Partial Clearing)

Hash outputs are not tainted, but using hashes for sensitive data is unsafe:

```compact
witness get_secret(): Field;

const secret = get_secret(); // TAINTED
const hash = persistentHash(secret); // UNTAINTED (but unsafe pattern!)

// The hash itself isn't tainted, but can be brute-forced
// if the secret has low entropy
```

### Explicit Disclosure

`disclose()` clears taint by marking the value as intentionally public:

```compact
witness get_value(): Field;

const value = get_value(); // TAINTED
const disclosed = disclose(value);   // UNTAINTED (intentionally revealed)
```

## Why Comparisons Require Disclosure

Comparisons are disclosure triggers because they leak information through the circuit's behavior:

```compact
witness get_age(): Uint<8>;

// This comparison reveals information about age
const is_adult = get_age() > 18;

// If is_adult is true, we know age > 18
// If is_adult is false, we know age <= 18
// The Boolean result leaks information about the witness
```

Even though the exact age isn't revealed, the comparison result conveys information about the witness value.

## Assertion Special Case

Assertions are a nuanced case:

```compact
witness get_value(): Field;

// Assertions don't directly return values
assert get_value() > 0;  // But comparison still requires disclosure!

// The assertion affects proof validity:
// - If assertion passes: we know value > 0
// - If assertion fails: proof generation fails
// Either way, information is leaked through proof success/failure
```

## Pattern Matching and Taint

Pattern matching with `is` creates interesting taint scenarios:

```compact
enum Option<T> {
    Some(T),
    None
}

witness get_option(): Option<Field>;

const opt = get_option();  // TAINTED

// Pattern match itself doesn't clear taint
if opt is Option::Some(value) {
    // value is TAINTED here
}
```

## Function Boundaries

Taint flows through function calls:

```compact
witness get_input(): Field;

// This helper doesn't involve witnesses directly
circuit double(x: Field): Field {
    return x * 2;
}

// But if called with tainted input, output is tainted
const input = get_input(); // TAINTED
const result = double(input);   // TAINTED (input was tainted)
```

## Visualizing Taint Flow

```
┌─────────────────┐
│  witness call   │ ──▶ TAINTED
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   arithmetic    │ ──▶ TAINTED (if any input tainted)
└────────┬────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌───────┐  ┌───────────┐
│compare│  │commitment │
└───┬───┘  └─────┬─────┘
    │             │
    ▼             ▼
  REQUIRES     UNTAINTED
 DISCLOSURE    (safe to return)
```

## Common Mistakes

### Mistake 1: Forgetting Transitive Taint

```compact
witness get_x(): Field;

// Developer thinks y is safe because it's "just math"
const x = get_x();
const y = x * x + 3;
const z = y / 2;

return z;  // ERROR: z is tainted through x -> y -> z
```

### Mistake 2: Assuming Hash Clears Taint Safely

```compact
witness get_password(): Bytes<32>;

// Hash output isn't tainted, but this is still insecure!
const hash = persistentHash(get_password());

// An attacker can brute-force common passwords
// and compare hashes to identify the password
```

### Mistake 3: Field Access Confusion

```compact
struct User {
    public_id: Field,
    private_balance: Field
}

witness get_user(): User;

const user = get_user();
const id = user.public_id;  // Still TAINTED!

// Even though it's named "public", it came from a witness
return id;  // ERROR: needs disclosure
```

## Debugging Taint Issues

When you get `potential witness-value disclosure`:

1. **Trace backwards** from the error location to find the witness source
2. **Check all arithmetic** - any operation with tainted input is tainted
3. **Look for hidden paths** - conditionals, pattern matching
4. **Verify assumptions** - field access on witness structs is still tainted

```compact
// Add explicit disclose() to identify which value is problematic
const a = disclose(get_a());  // This one?
const b = disclose(get_b());  // Or this one?
const result = a + b;
return result;  // Now we know which was the issue
```
