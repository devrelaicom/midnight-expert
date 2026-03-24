# Type Error Examples

## When This Error Occurs

The compiler successfully parsed the code but found a type mismatch. Type errors typically mention `no matching overload`, `expected [Type] but received [Type]`, or `cannot cast from type [A] to type [B]`.

## Examples

### Mixing Field and Uint without cast

**Error:**
`no matching overload for operator +: expected Field but received Uint<64>`

**Code that caused it:**
```compact
export circuit compute(myField: Field, myUint: Uint<64>): Field {
  const result = myField + myUint;
  return result;
}
```

**Diagnosis:** `Field` and `Uint<N>` are distinct types. Arithmetic operators require both operands to be the same type. The `+` operator has overloads for `(Field, Field)` and `(Uint<N>, Uint<N>)` but not `(Field, Uint<N>)`.

**Fix:**
```compact
export circuit compute(myField: Field, myUint: Uint<64>): Field {
  const result = myField + (myUint as Field);
  return result;
}
```

### Arithmetic result type expansion

**Error:**
`expected Uint<64> but received Uint<0..18446744073709551615>`

**Code that caused it:**
```compact
export circuit addBalances(balances: Map<Bytes<32>, Uint<64>>, key: Bytes<32>, a: Uint<64>, b: Uint<64>): [] {
  balances.insert(key, a + b);
}
```

**Diagnosis:** Adding two `Uint<64>` values produces a result type `Uint<0..N>` (range type) that may exceed the target type's range. The compiler widens the result to prevent overflow. You must explicitly cast back to the target type.

**Fix:**
```compact
export circuit addBalances(balances: Map<Bytes<32>, Uint<64>>, key: Bytes<32>, a: Uint<64>, b: Uint<64>): [] {
  balances.insert(key, (a + b) as Uint<64>);
}
```

### Direct Uint to Bytes cast

**Error:**
`cannot cast from type Uint<64> to type Bytes<32>`

**Code that caused it:**
```compact
export circuit convert(amount: Uint<64>): Bytes<32> {
  const b: Bytes<32> = amount as Bytes<32>;
  return b;
}
```

**Diagnosis:** Direct casting between `Uint<N>` and `Bytes<N>` is not supported. The cast must go through `Field` as an intermediate type: `Uint → Field → Bytes`.

**Fix:**
```compact
export circuit convert(amount: Uint<64>): Bytes<32> {
  const b: Bytes<32> = (amount as Field) as Bytes<32>;
  return b;
}
```

### Wrong argument type to ADT method

**Error:**
`no matching overload for method insert on Map<Bytes<32>, Uint<64>>: expected Uint<64> but received Field`

**Code that caused it:**
```compact
export circuit store(registry: Map<Bytes<32>, Uint<64>>, key: Bytes<32>, value: Field): [] {
  registry.insert(key, value);
}
```

**Diagnosis:** The `Map<Bytes<32>, Uint<64>>` was declared with `Uint<64>` as the value type, but a `Field` value was passed to `insert`. The method's type signature requires the value type to match the map's declaration.

**Fix:**
```compact
export circuit store(registry: Map<Bytes<32>, Uint<64>>, key: Bytes<32>, value: Field): [] {
  registry.insert(key, value as Uint<64>);
}
```

### Generic parameter mismatch

**Error:**
`expected Bytes<32> but received Bytes<20>`

**Code that caused it:**
```compact
export ledger accounts: Map<Bytes<32>, Uint<64>>;

export circuit lookup(addr: Bytes<20>): Uint<64> {
  return accounts.lookup(addr);
}
```

**Diagnosis:** The map key type is `Bytes<32>` but `Bytes<20>` was passed. Generic type parameters must match exactly — there is no implicit widening for `Bytes<N>`.

**Fix:**
```compact
export ledger accounts: Map<Bytes<32>, Uint<64>>;

export circuit lookup(addr: Bytes<32>): Uint<64> {
  return accounts.lookup(addr);
}
```

## Anti-Patterns

### Adding casts everywhere without understanding the mismatch

**Wrong:** Sprinkling `as Field` or `as Uint<64>` on every expression until it compiles.
**Problem:** Casts can silently truncate or reinterpret values. An `as Uint<64>` on a value larger than 2^64-1 will wrap around. Understand what each cast does before applying it.
**Instead:** Read the error message — it states the expected and received types. Add a cast only at the boundary where the mismatch occurs.

### Casting to Field as a universal fix

**Wrong:** Using `as Field` on every type mismatch.
**Problem:** `Field` accepts `Uint<N>` casts but does not accept `Bytes<N>` directly. And casting `Bytes` to `Field` is a one-way operation — you lose the byte-level structure. Some operations need `Bytes`, not `Field`.
**Instead:** Check whether the target type is `Field`, `Uint<N>`, or `Bytes<N>`. For `Uint → Bytes`, go through `Field` as intermediate. For `Bytes → Uint`, also go through `Field`.

### Ignoring the compiler's overload candidate list

**Wrong:** Guessing the correct method signature from memory.
**Problem:** When the compiler reports `no matching overload`, it often lists the available overloads. These show exactly what signatures exist and what types they accept.
**Instead:** Read the overload candidates in the error message. Match your arguments to one of the listed signatures.
