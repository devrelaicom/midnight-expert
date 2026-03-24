# Argument Formats

Data structures and type mappings for `constructorArgs` and `arguments` parameters in the simulation tools.

## constructorArgs (midnight-simulate-deploy)

A JSON object keyed by constructor parameter name. The MCP server handles type coercion. Omit the field entirely if the contract has no constructor or the constructor takes no parameters.

```compact
// Constructor with two parameters
constructor(initialCount: Uint<64>, admin: Bytes<32>) {
  count.increment(disclose(initialCount) as Uint<16>);
  authority = disclose(admin);
}
```

```json
{
  "code": "...",
  "constructorArgs": { "initialCount": 10, "admin": "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789" }
}
```

## arguments (midnight-simulate-call)

A JSON object keyed by circuit parameter name. The MCP server handles type coercion. Omit the field entirely if the circuit takes no parameters.

```compact
export circuit transfer(recipient: Bytes<32>, amount: Uint<64>): [] { ... }
```

```json
{
  "sessionId": "sim_abc123",
  "circuit": "transfer",
  "arguments": { "recipient": "0xabcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789", "amount": 100 }
}
```

## Compact Type to JSON Mapping

### Numeric Types

| Compact type | JSON representation | Examples |
|-------------|---------------------|----------|
| `Uint<32>` | Number or string | `42`, `"42"` |
| `Uint<64>` | Number or string | `1000`, `"1000"` |
| `Field` | Decimal string (for large values) or number | `"21888242871839275222246405745257275088548364400416034343698204186575808495617"`, `7` |

Use a string when the value exceeds JavaScript's safe integer range (`2^53 - 1`). `Field` values are elements of a large prime field and should always be passed as decimal strings unless the value is small.

### Byte Arrays

| Compact type | JSON representation | Example |
|-------------|---------------------|---------|
| `Bytes<N>` | Hex string, `0x`-prefixed, `2*N` hex characters | `"0x1234abcd"` (for `Bytes<4>`) |

The hex string must be exactly `2*N` characters (after the `0x` prefix). Shorter values should be zero-padded on the left.

```json
"0x00000000000000000000000000000000000000000000000000000000deadbeef"
```

### Boolean

| Compact type | JSON representation | Example |
|-------------|---------------------|---------|
| `Boolean` | JSON boolean | `true`, `false` |

### Structs

Struct values are JSON objects with field names as keys:

```compact
export struct Point {
  x: Field;
  y: Field;
}

export circuit setOrigin(p: Point): [] { ... }
```

```json
{
  "sessionId": "sim_abc123",
  "circuit": "setOrigin",
  "arguments": { "p": { "x": "0", "y": "0" } }
}
```

### Vectors (Fixed-Size Arrays)

`Vector<N, T>` values are JSON arrays of length `N`:

```compact
export circuit setCoords(coords: Vector<3, Uint<64>>): [] { ... }
```

```json
{
  "sessionId": "sim_abc123",
  "circuit": "setCoords",
  "arguments": { "coords": [10, 20, 30] }
}
```

The array value is the `Vector<3, Uint<64>>`; the key is the parameter name.

### Maybe (Optional)

`Maybe<T>` maps to `null` (for no value) or the unwrapped value:

```compact
export circuit setLabel(label: Maybe<Bytes<32>>): [] { ... }
```

Providing a value:

```json
{ "arguments": { "label": "0xabcdef..." } }
```

Providing no value:

```json
{ "arguments": { "label": null } }
```

### Enum Variants

Enum values are JSON objects with a single key -- the variant name:

```compact
export enum Phase { setup, commit, reveal, finalized }

export circuit setPhase(p: Phase): [] { ... }
```

```json
{ "arguments": { "p": { "setup": {} } } }
```

For enum variants that carry data (if supported), the value is nested inside the variant key.

## Quick Reference Table

| Compact type | JSON type | Example value |
|-------------|-----------|---------------|
| `Uint<32>` | number / string | `42` |
| `Uint<64>` | number / string | `"9999999999999"` |
| `Field` | string / number | `"123456789"` |
| `Bytes<N>` | hex string | `"0x1a2b3c..."` |
| `Boolean` | boolean | `true` |
| Struct | object | `{ "x": "0", "y": "1" }` |
| `Vector<N, T>` | array of length N | `[1, 2, 3]` |
| `Maybe<T>` | null or T | `null`, `42` |
| Enum | object with variant key | `{ "setup": {} }` |
