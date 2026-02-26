# Disclosure Rules

Complete reference for understanding when `disclose()` is required in Compact.

## The Fundamental Rule

**Any value derived from a witness function cannot be used in a way that makes it public without explicit `disclose()` wrapper.**

This is enforced by the compiler at compile time. If you violate this rule, you'll see:
```
error: potential witness-value disclosure
```

## Disclosure Triggers

### 1. Ledger Storage

Writing to any ledger ADT (Cell, Counter, Map, Set, List, MerkleTree) is a disclosure trigger.

```compact
ledger stored: Cell<Field>;
witness get_value(): Field;

// ERROR: witness value to ledger
export circuit bad_store(): [] {
    const value = get_value();
    stored.write(value);  // ERROR: potential witness-value disclosure
}

// CORRECT: explicit disclosure
export circuit good_store(): [] {
    const value = get_value();
    stored.write(disclose(value));  // OK
}

// CORRECT: use commitment instead
export circuit store_commitment(): [] {
    const value = get_value();
    const commitment = persistentCommit(value);
    stored.write(commitment);  // OK: commitment, not raw value
}
```

### 2. Circuit Return Values

Returning a witness-derived value from an exported circuit requires disclosure.

```compact
witness get_secret(): Field;

// ERROR: returning witness value
export circuit bad_return(): Field {
    const secret = get_secret();
    return secret;  // ERROR: potential witness-value disclosure
}

// CORRECT: explicit disclosure
export circuit reveal(): Field {
    const secret = get_secret();
    return disclose(secret);  // OK: intentional
}

// CORRECT: return derived non-secret value
export circuit verify(expected: Bytes<32>): Boolean {
    const secret = get_secret();
    const hash = persistentHash(secret);
    return hash == expected;  // OK: Boolean result is public
}
```

### 3. Comparison Operations

Comparing a witness value with anything is a disclosure trigger because it leaks information.

```compact
witness get_balance(): Uint<64>;

// ERROR: comparison discloses information
export circuit is_wealthy(): Boolean {
    const balance = get_balance();
    return balance > 1000000;  // ERROR: comparison requires disclosure
}

// CORRECT: explicit disclosure
export circuit is_wealthy_disclosed(): Boolean {
    const balance = get_balance();
    return disclose(balance) > 1000000;  // OK
}

// ALTERNATIVE: compare commitments/hashes
export circuit verify_minimum(min_commitment: Bytes<32>): Boolean {
    const balance = get_balance();
    const my_commitment = persistentCommit(balance);
    // This only reveals equality, not the actual values
    return my_commitment == min_commitment;  // Different pattern
}
```

### 4. External Contract Calls

When cross-contract calls become available, passing witness values to other contracts will require disclosure.

```compact
// FUTURE: when external calls are supported
// external contract OtherContract {
// circuit process(value: Field): [];
// }

// witness get_data(): Field;

// Would require: OtherContract.process(disclose(get_data()));
```

## Transitive Disclosure

The compiler tracks witness "taint" through all operations.

```compact
witness get_a(): Field;
witness get_b(): Field;

export circuit transitive_example(): Field {
    const a = get_a();
    const b = get_b();

    // All of these are tainted:
    const sum = a + b; // Tainted (from a and b)
    const product = sum * 2; // Tainted (from sum)
    const result = product + 1;  // Tainted (from product)

    return disclose(result); // Must disclose the final result
}
```

## Safe Operations That Don't Require Disclosure

These operations consume witness values but produce non-sensitive outputs:

### Commitments

```compact
witness get_secret(): Field;

export circuit safe_commitment(): Bytes<32> {
    const secret = get_secret();
    return persistentCommit(secret);  // OK: commitment is safe to return
}
```

### Assertions

```compact
witness get_value(): Field;

export circuit safe_assert(): [] {
    const value = get_value();
    assert disclose(value) > 0;  // Comparison requires disclosure even in assertions
}
```

### Hash-Based Verification

```compact
witness get_preimage(): Field;

export circuit verify_hash(expected: Bytes<32>): Boolean {
    const preimage = get_preimage();
    const actual = persistentHash(preimage);

    // Comparing hashes is OK - the hash values themselves aren't witness-derived
    return actual == expected;  // OK
}
```

## Error Messages

When you see `potential witness-value disclosure`, check:

1. **Is the value returned from a circuit?** -> Add `disclose()`
2. **Is the value written to ledger?** -> Add `disclose()` or use commitment
3. **Is the value in a comparison?** -> Add `disclose()` to both sides
4. **Is the value passed to another contract?** -> Add `disclose()`

## Best Practices

### 1. Minimize Disclosure

Only disclose what's absolutely necessary:

```compact
witness get_user_data(): UserData;

// BAD: discloses entire struct
export circuit bad_pattern(): UserData {
    return disclose(get_user_data());
}

// GOOD: only disclose what's needed
export circuit good_pattern(): Uint<64> {
    const data = get_user_data();
    return disclose(data.public_balance);  // Only disclose the public part
}
```

### 2. Use Commitments by Default

When storing sensitive data, prefer commitments:

```compact
ledger user_data: Map<Bytes<32>, Bytes<32>>;  // Store commitments

witness get_balance(): Uint<64>;

export circuit store_balance(user: Bytes<32>): [] {
    const balance = get_balance();
    const commitment = persistentCommit(balance);
    user_data.insert(user, commitment);  // Store commitment, not value
}
```

### 3. Document Disclosure Intent

Make it clear why disclosure is happening:

```compact
witness get_vote(): Field;

export circuit cast_vote(): Field {
    const vote = get_vote();
    // Disclosure required: vote must be recorded on ledger for counting
    return disclose(vote);
}
```
