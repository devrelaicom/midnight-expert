# Operators and Expressions

Every Compact expression has a statically known type. The compiler rejects programs where operator usage does not satisfy the required type constraints.

## Arithmetic Operators

Compact provides three binary arithmetic operators: **add** (`+`), **subtract** (`-`), and **multiply** (`*`). Division and modulo are not available.

### Bounded Type Expansion

When both operands are unsigned integers the result type expands to hold every possible value:

| Operation | Left Type | Right Type | Result Type |
|-----------|-----------|------------|-------------|
| `+` | `Uint<0..m>` | `Uint<0..n>` | `Uint<0..m+n>` |
| `-` | `Uint<0..m>` | `Uint<0..n>` | `Uint<0..m>` |
| `*` | `Uint<0..m>` | `Uint<0..n>` | `Uint<0..m*n>` |

Because the result type widens, you almost always need to cast the result back to a target type before storing or returning it:

```compact
export ledger balance: Uint<64>;

export circuit deposit(amount: Uint<64>): [] {
  // balance + amount produces Uint<0..36893488147419103230>
  // cast back to Uint<64> before assignment
  balance = (balance + amount) as Uint<64>;
}
```

It is a compile error if the expanded bound would exceed the maximum unsigned integer.

### Subtraction Can Fail at Runtime

`Uint` subtraction checks whether the right operand is greater than the left. If so the operation raises a runtime error because the result would be negative. There is no wraparound for unsigned integers.

```compact
export circuit withdraw(amount: Uint<64>): [] {
  // Fails at runtime if amount > balance
  balance = (balance - amount) as Uint<64>;
}
```

### Field Arithmetic

If either operand has type `Field`, the result has type `Field`. Field arithmetic wraps around modulo the field prime -- overflow and underflow do not cause runtime errors, they simply wrap.

```compact
export ledger total: Field;

export circuit accumulate(x: Field): [] {
  total = total + x;   // Field + Field -> Field, wraps on overflow
}
```

Mixing `Field` and `Uint` in a single expression is a type error. Cast the `Uint` operand first:

```compact
const f: Field = 10;
const u: Uint<64> = 5;
// const bad = f + u;           // type error
const good = f + (u as Field);  // ok: Field + Field -> Field
```

### No Division or Modulo

The operators `/` and `%` do not exist in Compact. Workaround: compute the result off-chain in a witness and verify the relationship in the circuit:

```compact
witness compute_quotient(a: Uint<64>, b: Uint<64>): Uint<64>;

export circuit verified_divide(a: Uint<64>, b: Uint<64>): Uint<64> {
  const q = compute_quotient(a, b);
  assert(disclose((q * b) as Uint<64> <= a), "quotient too large");
  return q;
}
```

## Comparison Operators

### Equality: `==` and `!=`

Equality and inequality work on any two values whose types are in a subtype relation: `Boolean`, `Uint`, `Field`, `Bytes<N>`, enums, structs, and tuples all support `==` and `!=` when both operands share a common type. Cross-type equality requires an explicit cast:

```compact
const f: Field = 42;
const u: Uint<64> = 42;
// const bad = f == u;            // type error
const ok = f == (u as Field);     // ok: Field == Field
```

### Relational: `<`, `<=`, `>`, `>=`

Relational operators require both operands to be unsigned integer types. `Field` values cannot be compared with these operators.

```compact
pure circuit is_eligible(age: Uint<8>): Boolean {
  return age >= 18;
}
```

To compare a `Field` value relationally, cast it to a bounded unsigned integer first:

```compact
const f: Field = 50;
// const bad = f > 0;                     // type error: Field not allowed
const ok = (f as Uint<64>) > 0;           // ok: Uint<64> > Uint<0..0>
```

## Boolean Operators

Compact provides three boolean operators. Both `&&` and `||` use short-circuit evaluation.

| Operator | Name | Behavior |
|----------|------|----------|
| `&&` | Logical AND | Evaluates right operand only if left is `true` |
| `\|\|` | Logical OR | Evaluates right operand only if left is `false` |
| `!` | Negation | Unary prefix operator; flips `true` to `false` and vice versa |

Both operands of `&&` and `||` must have type `Boolean`. The operand of `!` must also be `Boolean`.

```compact
export circuit check_access(isAdmin: Boolean, isOwner: Boolean): Boolean {
  return isAdmin || isOwner;          // short-circuit OR
}

export circuit validate(active: Boolean, score: Uint<64>): Boolean {
  return active && score > 0;         // short-circuit AND
}

pure circuit invert(flag: Boolean): Boolean {
  return !flag;                       // negation
}
```

## Type Cast Expressions

### Syntax

Compact uses the `as` keyword for casts. TypeScript-style angle-bracket casts (`<T>expr`) are not supported.

```compact
const f: Field = myUint as Field;
```

### Cast Kinds

Every allowed cast falls into one of three categories:

- **static** -- changes only the compile-time type; no runtime effect
- **conversion** -- always succeeds but converts the runtime representation
- **checked** -- verified at runtime; raises an error if the value does not fit

### Cast Path Table

The table below shows which casts are allowed and their kind. Empty cells mean the cast is not allowed.

| FROM \ TO | `Field` | `Uint<0..n>` | `Boolean` | `Bytes<n>` |
|-----------|---------|-------------|-----------|------------|
| **`Field`** | static | checked | conversion (1) | conversion (2) |
| **`Uint<0..m>`** | static | static if m<=n, checked if m>n (3) | -- | -- |
| **`Boolean`** | -- | conversion (4) | static | -- |
| **`Bytes<m>`** | conversion (5) | -- | -- | static if m==n (6) |
| **`enum`** | conversion | -- | -- | -- |

Notes:

1. `Field` to `Boolean`: `0` becomes `false`; all other values become `true`.
2. `Field` to `Bytes<n>`: little-endian conversion. Padded with trailing zeros. Runtime error if the value does not fit in `n` bytes.
3. `Uint<0..m>` to `Uint<0..n>`: widening (m <= n) is static; narrowing (m > n) is checked and fails at runtime if the value exceeds `n`.
4. `Boolean` to `Uint<0..n>`: `false` becomes `0`, `true` becomes `1`. If `n` is `0`, the cast is checked and fails at runtime when the value is `true`.
5. `Bytes<m>` to `Field`: little-endian interpretation. Runtime error if the result exceeds the maximum `Field` value.
6. `Bytes<m>` to `Bytes<n>`: only allowed when `m` equals `n` (a static identity cast).

### Multi-step Casts

Some type conversions require going through an intermediate type:

```compact
// Boolean -> Field: go through Uint
const flag: Boolean = true;
const flag_field: Field = (flag as Uint<0..1>) as Field;

// Uint -> Bytes: go through Field
const amount: Uint<64> = 1000;
const amount_bytes: Bytes<32> = (amount as Field) as Bytes<32>;
```

Direct `Boolean` to `Field` and direct `Uint` to `Bytes` casts are not allowed. The compiler will reject them.

### Arithmetic Results Require Casting

Because arithmetic widens the result type, you must cast before assigning to a fixed-width target:

```compact
export ledger balances: Map<Bytes<32>, Uint<64>>;

export circuit transfer(from: Bytes<32>, to: Bytes<32>, amount: Uint<64>): [] {
  const from_bal = balances.lookup(from);
  const to_bal = balances.lookup(to);
  balances.insert(disclose(from), (from_bal - amount) as Uint<64>);
  balances.insert(disclose(to), (to_bal + amount) as Uint<64>);
}
```

## Conditional Expressions

Compact supports the ternary conditional operator. Both branches must have types that are in a subtype relation.

```compact
pure circuit max(a: Uint<64>, b: Uint<64>): Uint<64> {
  return (a > b) ? a : b;
}
```

The condition must be `Boolean`. Only the selected branch is evaluated. The result type is the supertype of the two branch types (e.g., `Uint<0..50>` and `Uint<0..100>` yield `Uint<0..100>`).

## Literals

### Boolean Literals

`true` and `false` have type `Boolean`.

### Numeric Literals

A numeric literal `n` has type `Uint<0..n>` -- the tightest bounded type for that value:

```compact
const x = 0;     // Uint<0..0>
const y = 42;    // Uint<0..42>
const z = 1000;  // Uint<0..1000>
```

Because `Uint<0..n>` is a subtype of any wider `Uint`, literals can be used directly wherever a wider integer is expected without an explicit cast.

If a literal exceeds the implementation-defined maximum unsigned integer, it is a type error unless it fits in `Field` and appears inside a cast expression `n as Field`.

### String Literals

String literals use single (`'`) or double (`"`) quotes and support escaped characters. The type is `Bytes<N>` where N is the UTF-8 byte length:

```compact
const greeting = "hello";       // Bytes<5>
const tag = 'abcdefgh';         // Bytes<8>
```

### Padded String Literals

`pad(n, s)` produces a `Bytes<n>` value: the UTF-8 encoding of `s` followed by zero bytes up to length `n`. The string length must not exceed `n`.

```compact
const label: Bytes<32> = pad(32, "hello");   // 5 content bytes + 27 zero bytes
```

## Anonymous Circuits (Lambdas)

Anonymous circuits are inline circuit definitions using arrow syntax. The body can be an expression or a block:

```compact
// Expression body with return type annotation
(x: Uint<64>, y: Uint<64>): Uint<64> => (x + y) as Uint<64>

// Block body
(x: Uint<64>): Uint<64> => {
  const doubled = (x * 2) as Uint<64>;
  return doubled;
}
```

Anonymous circuits are **not first-class values**. They cannot be stored in variables, passed as arguments, or returned from circuits. They must be immediately called where they appear. There is no syntax for generic anonymous circuits.

They appear most commonly with `map` and `fold` over vectors. Parameters support destructuring:

```compact
const nums: Vector<3, Uint<64>> = [10, 20, 30];
const doubled = nums.map<Uint<64>>((x: Uint<64>): Uint<64> => (x * 2) as Uint<64>);

const pairs: Vector<2, [Uint<64>, Uint<64>]> = [[1, 2], [3, 4]];
const sums = pairs.map<Uint<64>>(
  ([a, b]: [Uint<64>, Uint<64>]): Uint<64> => (a + b) as Uint<64>
);
```
