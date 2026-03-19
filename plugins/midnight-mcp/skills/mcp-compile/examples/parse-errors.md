# Parse Error Examples

## When This Error Occurs

The compiler encountered syntax it does not expect. Parse errors have the format: `expected '[token]' but found '[token]'`. The error tells you exactly what the compiler was looking for.

## Examples

### Void return type

**Error:**
`expected ";" but found "{"`

**Code that caused it:**
```compact
export circuit doSomething(): Void {
  count.increment(1);
}
```

**Diagnosis:** Compact does not have a `Void` keyword. The compiler sees `Void` as an identifier, then expects a semicolon to end what it thinks is a declaration, but finds `{` instead.

**Fix:**
```compact
export circuit doSomething(): [] {
  count.increment(1);
}
```

### Double-colon enum access

**Error:**
`expected ")" but found ":"`

**Code that caused it:**
```compact
if (state == State::active) {
  // ...
}
```

**Diagnosis:** Compact uses dot notation for enum variants, not Rust-style `::` syntax. The compiler parses `State` as the expression, then expects `)` to close the `if` condition, but finds the first `:` instead.

**Fix:**
```compact
if (state == State.active) {
  // ...
}
```

### Deprecated ledger block syntax

**Error:**
`expected an identifier but found "{"`

**Code that caused it:**
```compact
ledger {
  counter: Counter;
  owner: Bytes<32>;
}
```

**Diagnosis:** The `ledger { }` block form was removed. The compiler expects an identifier (the field name) after `ledger`, but finds `{`.

**Fix:**
```compact
export ledger counter: Counter;
export ledger owner: Bytes<32>;
```

### Witness with implementation body

**Error:**
`expected ";" but found "{"`

**Code that caused it:**
```compact
witness getSecret(): Field {
  return 42;
}
```

**Diagnosis:** Witnesses are declarations only — they end with a semicolon. The implementation lives in TypeScript on the prover side. The compiler expects `;` after the signature but finds `{`.

**Fix:**
```compact
witness getSecret(): Field;
```

### Using `pure function` instead of `pure circuit`

**Error:**
`unbound identifier "function"`

**Code that caused it:**
```compact
pure function add(a: Field, b: Field): Field {
  return a + b;
}
```

**Diagnosis:** Compact uses the keyword `circuit`, not `function`. The compiler does not recognize `function` as a keyword.

**Fix:**
```compact
export pure circuit add(a: Field, b: Field): Field {
  return a + b;
}
```

### Division operator

**Error:**
Parse error (compiler looks for comment syntax after `/`)

**Code that caused it:**
```compact
const result = x / y;
```

**Diagnosis:** Compact does not support the `/` operator. The compiler recognizes `/` as the start of a comment token (`//` or `/* */`). Division must be implemented via a witness pattern that computes the result off-chain and verifies it on-chain.

**Fix:**
```compact
witness _divMod(x: Uint<32>, y: Uint<32>): [Uint<32>, Uint<32>];

export circuit div(x: Uint<32>, y: Uint<32>): Uint<32> {
  const res = disclose(_divMod(x, y));
  const quotient = res[0];
  const remainder = res[1];
  assert(remainder < y && x == y * quotient + remainder, "Invalid division");
  return quotient;
}
```

## Anti-Patterns

### Guessing the fix without reading the error tokens

**Wrong:** Seeing a parse error and immediately rewriting the whole line based on intuition.
**Problem:** The `expected '...' but found '...'` message tells you exactly what the compiler wanted. The fix is almost always in the gap between those two tokens.
**Instead:** Read the expected and found tokens. The expected token tells you what construct the compiler was parsing. The found token tells you where it derailed.

### Assuming parse errors are type errors

**Wrong:** Adding type casts to fix a parse error.
**Problem:** Parse errors happen before type checking — the compiler hasn't gotten far enough to check types. Casts won't help because the code can't even be parsed.
**Instead:** Fix the syntax first. Type errors (if any) will appear on the next compile.

### Not recognizing deprecated Compact syntax

**Wrong:** Assuming the code is correct because it looks like valid Compact from a tutorial.
**Problem:** Compact syntax has changed across versions. The `ledger { }` block, `Void` type, and other constructs were removed. Tutorials or examples targeting older versions will trigger parse errors.
**Instead:** Check if the construct was deprecated. Cross-reference with `compact-core:compact-language-ref` for current syntax.
