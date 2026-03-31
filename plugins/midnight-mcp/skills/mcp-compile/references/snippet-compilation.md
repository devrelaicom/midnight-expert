# Snippet Compilation Workflow

## When to Use

Compiling incomplete Compact code fragments — a circuit definition without the surrounding contract, a ledger declaration, or a code sample from documentation. The hosted compiler auto-wraps incomplete snippets into valid contracts.

## How Auto-Wrapping Works

The compiler detects whether the submitted code is a complete contract or a snippet:

| Snippet Type | Detection | What Gets Added |
|-------------|-----------|-----------------|
| `complete` | Code has `pragma language_version` | Nothing — sent as-is |
| `circuit` | Starts with `circuit` or `export circuit` | Pragma + stdlib import |
| `ledger` | Starts with `ledger`, `export ledger`, `struct`, or `enum` | Pragma + stdlib import |
| `unknown` | Anything else | Pragma + stdlib import |

## What the Wrapper Adds

For code missing both pragma and stdlib import (most common case for snippets):

```compact
pragma language_version >= 0.22;

import CompactStandardLibrary;

<your code here>
```

This adds 4 lines before the user's code.

## Line Offset Rules

Error line numbers in the response are relative to the WRAPPED code, not the original. Adjust using:

| Condition | Lines Added | Adjustment |
|-----------|-------------|------------|
| Code has `pragma` | 0 | None needed |
| Code has stdlib import but no pragma | 2 | Subtract 2 from error line |
| Code has neither pragma nor import | 4 | Subtract 4 from error line |

## Detecting Wrapping

If the response includes `originalCode` and `wrappedCode` fields, wrapping occurred. Compare them to determine the offset.

## Example

```
Code submitted: "export circuit add(a: Uint<64>, b: Uint<64>): Uint<64> { return a + b; }"

Wrapped code (by compiler):
  Line 1: pragma language_version >= 0.22;
  Line 2: (blank)
  Line 3: import CompactStandardLibrary;
  Line 4: (blank)
  Line 5: export circuit add(a: Uint<64>, b: Uint<64>): Uint<64> { return a + b; }

If an error reports line 5 → the error is on line 1 of the original snippet (5 - 4 = 1).
```

## Limitations

- Auto-wrapping adds boilerplate but cannot add missing context. If a snippet references a ledger field declared elsewhere, or a type from another file, wrapping won't help — the compiler will report an undefined reference.
- For snippets that need surrounding context, either provide a complete contract or use `midnight-compile-archive` with the full file set.
- The default pragma is `>= 0.14` (open-ended). To pin a specific version, include the pragma in your snippet.
