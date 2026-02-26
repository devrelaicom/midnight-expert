---
title: Operators and Expressions
type: concept
description: Arithmetic, comparison, logical, bitwise, and cast operators in Compact — including operator precedence, conditional expressions, and the Field ordering restriction.
links:
  - type-system
  - bounded-computation
  - both-branches-execute
---

# Operators and Expressions

Compact supports a familiar set of operators, but the ZK circuit context imposes restrictions that general-purpose languages do not have. The most consequential is that `Field` does not support ordering operators — only equality.

## Arithmetic Operators

| Operator | Meaning | Operand Types |
|----------|---------|---------------|
| `+` | Addition | Field, Uint |
| `-` | Subtraction | Field, Uint |
| `*` | Multiplication | Field, Uint |
| `/` | Division | Field, Uint |
| `%` | Modulo | Uint only |

Arithmetic on `Uint` values must respect range bounds. Adding two `Uint<0..100>` values produces a result that could be up to 200, which requires either casting to a wider type with `as` or assigning to a wider variable. The [[type-system]] enforces these constraints at compile time.

## Comparison Operators

| Operator | Meaning | Operand Types |
|----------|---------|---------------|
| `==` | Equal | All types |
| `!=` | Not equal | All types |
| `<` | Less than | Uint only |
| `>` | Greater than | Uint only |
| `<=` | Less or equal | Uint only |
| `>=` | Greater or equal | Uint only |

**Critical restriction**: `Field` does not support ordering operators (`<`, `>`, `<=`, `>=`). Attempting `field_a < field_b` is a compile error. This is because Field arithmetic operates modulo a large prime (a consequence of [[bounded-computation]]), making ordering meaningless in the mathematical sense. If you need ordered comparison, cast to `Uint` first or use `Uint` from the start.

## Logical Operators

| Operator | Meaning |
|----------|---------|
| `&&` | Logical AND |
| `\|\|` | Logical OR |
| `!` | Logical NOT |

Logical operators work on `Boolean` values. Both sides of `&&` and `||` are always evaluated — there is no short-circuit evaluation in ZK circuits because [[both-branches-execute]].

## Bitwise Operators

| Operator | Meaning | Operand Types |
|----------|---------|---------------|
| `&` | Bitwise AND | Uint |
| `\|` | Bitwise OR | Uint |
| `^` | Bitwise XOR | Uint |
| `<<` | Left shift | Uint |
| `>>` | Right shift | Uint |

Bitwise operators are only available on `Uint` types. They operate on the binary representation of the integer within its declared range.

## Cast Operator

The `as` keyword performs type conversions:

```compact
const wide = narrow_value as Uint<0..1000>;  // Widening (always safe)
const narrow = wide_value as Uint<0..100>;   // Narrowing (inserts range check)
const bytes = field_value as Bytes<32>;      // Field to Bytes
```

Narrowing casts insert a range check into the circuit — the proof will fail if the value is out of range at proving time. See [[type-system]] for the full conversion rules.

## Conditional Expressions

Compact supports both `if/else` statements and ternary conditional expressions:

```compact
// Ternary expression — evaluates to a value
const result = condition ? value_if_true : value_if_false;

// If/else as expression
const result = if (condition) { expr_a } else { expr_b };
```

Both branches of a conditional expression are always evaluated because ZK circuits execute all paths (see [[both-branches-execute]]). The condition selects which result to use, but both sides incur circuit cost.

## Operator Precedence

From highest to lowest precedence:

1. `!` (unary NOT)
2. `*`, `/`, `%` (multiplicative)
3. `+`, `-` (additive)
4. `<<`, `>>` (shift)
5. `&` (bitwise AND)
6. `^` (bitwise XOR)
7. `|` (bitwise OR)
8. `<`, `>`, `<=`, `>=` (relational)
9. `==`, `!=` (equality)
10. `&&` (logical AND)
11. `||` (logical OR)
12. `? :` (ternary)

Use parentheses when in doubt — explicit grouping is clearer than relying on precedence, especially in complex circuit expressions where correctness is critical.
