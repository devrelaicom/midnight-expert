# Debugging Disclosure Errors

Step-by-step guide for understanding and fixing the Compact compiler's
disclosure errors. When the compiler reports "potential witness-value disclosure
must be declared but is not", this guide will help you diagnose the issue and
apply the correct fix.

## Anatomy of a Disclosure Error

The compiler produces a structured error message when it detects undeclared
witness disclosure. Here is a real error produced by compiling a contract that
writes a witness return value directly to the ledger without `disclose()`:

```
Exception: contract.compact line 6 char 11:
  potential witness-value disclosure must be declared but is not:
    witness value potentially disclosed:
      the return value of witness getBalance at line 2 char 1
    nature of the disclosure:
      ledger operation might disclose the witness value
    via this path through the program:
      the right-hand side of = at line 6 char 11
```

The error has three parts:

**Witness source** -- The line starting with "witness value potentially
disclosed" identifies which witness function or circuit parameter produced the
private data. In this example, it is the return value of `getBalance` declared
at line 2.

**Nature of disclosure** -- The line starting with "nature of the disclosure"
describes what kind of public boundary the witness data is crossing. Common
phrasings include:
- "ledger operation might disclose the witness value" -- a direct ledger write
- "ledger operation might disclose the result of an addition" -- an indirect write via arithmetic
- "the value returned from exported circuit X might disclose the result of a comparison" -- a return from an exported circuit
- "comparison involving witness value" -- a conditional or assert on witness data

**Path through program** -- The lines under "via this path through the program"
trace every binding, circuit call, struct access, and computation the data
passes through from the witness source to the disclosure point. This is the
most valuable part of the error. In simple cases (like a direct write), the
path is a single line. In complex cases where data flows through multiple
transformations, the path shows every step:

```
Exception: contract.compact line 13 char 11:
  potential witness-value disclosure must be declared but is not:
    witness value potentially disclosed:
      the return value of witness getBalance at line 3 char 1
    nature of the disclosure:
      ledger operation might disclose the result of an addition
    via this path through the program:
      the binding of s at line 11 char 3
      the argument to obfuscate at line 12 char 13
      the computation at line 7 char 10
      the binding of x at line 12 char 3
      the right-hand side of = at line 13 char 11
```

This path shows the data flowing through a struct binding, into a helper
circuit call, through an arithmetic computation, back into a local binding,
and finally into the ledger write. Reading the path from top to bottom reveals
exactly how witness data reached the disclosure point.

## The 5-Step Debugging Process

### Step 1: Read the witness source

Find the line "witness value potentially disclosed" in the error. It names the
witness function or identifies the circuit parameter that is the origin of the
private data. Go to the line and character position indicated and confirm which
value it refers to.

### Step 2: Read the disclosure path

Follow "via this path through the program" from top to bottom. Each line
describes one step in the data flow: a variable binding (`the binding of x`),
a function argument (`the argument to fn`), a computation (`the computation at
line N`), a struct field access, or the final disclosure point (such as
`the right-hand side of =`). This path is the compiler telling you exactly how
the witness data reached the public boundary.

### Step 3: Ask "Is this disclosure intentional?"

Decide whether you intended to make this value public:
- **Yes, this should be public** -- You are writing a public key to the ledger,
  checking an access-control condition, or returning a result the caller needs.
  Proceed to Step 4.
- **No, this leaks private data** -- You are accidentally exposing a secret key,
  a private balance, or internal state that should remain hidden. Proceed to
  Step 5.

### Step 4: Place disclose() at the right location

Wrap the value in `disclose()` as close to the disclosure point as possible.
Do not wrap at the witness call site unless the witness always returns
non-private data. For structured values, wrap only the witness-containing
portion.

```compact
// Direct ledger write: wrap at the assignment
balance = disclose(getBalance());

// Conditional: wrap the condition expression
if (disclose(getFlag())) { ... }

// Return from exported circuit: wrap the return expression
return disclose(computedValue);

// ADT method: wrap each witness-derived argument
balances.insert(disclose(key), disclose(amount));
```

### Step 5: Restructure to avoid the leak

If you did not intend to disclose the value, restructure the code to keep the
data private:
- **Use a commitment** instead of writing the raw value:
  `storedHash = disclose(persistentCommit<Field>(secret, rand))`
- **Use a MerkleTree** instead of a Set for membership checks (insert hides
  the leaf value)
- **Move computation inside the proof** -- do not write intermediate results
  to the ledger if they contain witness data
- **Use an internal circuit** instead of returning from an exported circuit,
  so the result stays within the ZK proof
- **Use a nullifier** to prove a property about a secret without revealing it

## Common Error Patterns with Fixes

### Pattern 1: Direct Ledger Write

A witness return value is assigned directly to a ledger field.

```compact
// ERROR
witness getBalance(): Bytes<32>;
export ledger balance: Bytes<32>;
export circuit recordBalance(): [] {
  balance = getBalance();
}
```

Compiler output:

```
potential witness-value disclosure must be declared but is not:
  witness value potentially disclosed:
    the return value of witness getBalance at line 3 char 1
  nature of the disclosure:
    ledger operation might disclose the witness value
  via this path through the program:
    the right-hand side of = at line 6 char 11
```

Fix -- wrap the assignment in `disclose()`:

```compact
export circuit recordBalance(): [] {
  balance = disclose(getBalance());
}
```

### Pattern 2: Indirect via Arithmetic or Type Cast

The witness value passes through an arithmetic operation or type cast before
reaching the ledger. The compiler tracks witness data through all operations.

```compact
// ERROR
witness getSecret(): Field;
export ledger result: Field;
export circuit compute(): [] {
  const x = getSecret() + 42;
  result = x;
}
```

Compiler output:

```
potential witness-value disclosure must be declared but is not:
  witness value potentially disclosed:
    the return value of witness getSecret at line 3 char 1
  nature of the disclosure:
    ledger operation might disclose the result of an addition
  via this path through the program:
    the binding of x at line 6 char 9
    the right-hand side of = at line 7 char 12
```

Fix -- wrap at the assignment, not at the witness call:

```compact
export circuit compute(): [] {
  const x = getSecret() + 42;
  result = disclose(x);
}
```

### Pattern 3: Conditional on Witness Value

A witness-derived value controls a branch condition. The branch choice itself
reveals information about the witness, so the compiler requires disclosure.

```compact
// ERROR
witness getFlag(): Boolean;
export ledger value: Field;
export circuit check(): [] {
  if (getFlag()) {
    value = 1;
  }
}
```

Compiler output:

```
potential witness-value disclosure must be declared but is not:
  witness value potentially disclosed:
    the return value of witness getFlag at line 3 char 1
  nature of the disclosure:
    comparison involving witness value
  via this path through the program:
    the condition of if at line 6 char 7
```

Fix -- wrap the condition in `disclose()`:

```compact
export circuit check(): [] {
  if (disclose(getFlag())) {
    value = 1;
  }
}
```

### Pattern 4: Return from Exported Circuit

A value derived from witness data is returned from an exported circuit. The
return value exits the ZK proof and becomes visible to the caller.

```compact
// ERROR
witness getBalance(): Uint<64>;
export circuit balanceExceeds(n: Uint<64>): Boolean {
  return getBalance() > n;
}
```

Compiler output:

```
potential witness-value disclosure must be declared but is not:
  witness value potentially disclosed:
    the return value of witness getBalance at line 3 char 1
  nature of the disclosure:
    the value returned from exported circuit balanceExceeds might disclose
    the result of a comparison
  via this path through the program:
    the comparison at line 5 char 10
```

Fix -- wrap the return expression in `disclose()`:

```compact
export circuit balanceExceeds(n: Uint<64>): Boolean {
  return disclose(getBalance() > n);
}
```

Note that both `getBalance()` and `n` are witness data (the former from a
witness function, the latter from an exported circuit parameter), so the
comparison result carries witness taint from both sides.

### Pattern 5: Struct Field Containing Witness Data

When a struct is written to the ledger and one or more fields contain
witness-derived data, the compiler flags the entire write.

```compact
// ERROR
struct Config { threshold: Uint<64>; admin: Bytes<32>; }
witness getThreshold(): Uint<64>;
export ledger storedConfig: Config;

export circuit configure(admin: Bytes<32>): [] {
  storedConfig = Config { threshold: getThreshold(), admin: admin };
}
```

Fix -- disclose only the witness-containing fields, not the entire struct:

```compact
export circuit configure(admin: Bytes<32>): [] {
  storedConfig = Config {
    threshold: disclose(getThreshold()),
    admin: disclose(admin)
  };
}
```

Both `getThreshold()` (witness return) and `admin` (exported circuit
parameter) are witness data, so both need `disclose()` before flowing into the
ledger write.

### Pattern 6: ADT Method with Witness Argument

Ledger ADT operations (Map, Set, List, Counter) make their arguments public
on-chain. Passing witness-derived values as arguments requires disclosure.

```compact
// ERROR
export ledger balances: Map<Bytes<32>, Uint<64>>;

export circuit deposit(key: Bytes<32>, amount: Uint<64>): [] {
  balances.insert(key, amount);
}
```

Fix -- disclose each witness-derived argument separately:

```compact
export circuit deposit(key: Bytes<32>, amount: Uint<64>): [] {
  balances.insert(disclose(key), disclose(amount));
}
```

### Pattern 7: Standard Library Call Forwarding Witness Data

When a standard library circuit that writes to the ledger receives
witness-derived arguments, those arguments must be disclosed before the call.

```compact
// ERROR
witness getRecipient(): Bytes<32>;
witness getAmount(): Uint<64>;

export circuit doTransfer(): [] {
  const recipient = getRecipient();
  const amount = getAmount();
  // If a stdlib circuit writes recipient/amount to ledger, disclose is needed
  balances.insert(recipient, amount);
}
```

Fix -- disclose each argument that flows into a public operation:

```compact
export circuit doTransfer(): [] {
  const recipient = getRecipient();
  const amount = getAmount();
  balances.insert(disclose(recipient), disclose(amount));
}
```

The same principle applies to any function or circuit that ultimately writes
its arguments to the ledger. The compiler traces through the call chain and
reports the full path if disclosure is missing.

## Where NOT to Put disclose()

**Do not disclose at the witness call site unless the witness always returns
public data.** Placing `disclose()` directly on the witness call eliminates
privacy for all downstream uses of that value. If the value flows to both a
ledger write (public) and a MerkleTree insert (private), disclosing at the
source makes the MerkleTree insert pointless.

```compact
// Wrong -- over-discloses; ALL uses of balance lose privacy
const balance = disclose(getBalance());
tree.insert(balance);       // Now public despite MerkleTree
ledger_val = balance;       // Also public

// Correct -- disclose only where needed
const balance = getBalance();
tree.insert(balance);                  // Private (MerkleTree hides leaf)
ledger_val = disclose(balance);        // Public (ledger write)
```

**Do not disclose a whole struct when only one field is witness-derived.** If a
struct has five fields and only one comes from a witness, wrapping the entire
struct in `disclose()` marks all five fields as intentionally public. Instead,
disclose only the individual field that carries witness data.

**Do not disclose inside a helper circuit if the caller also discloses.** A
single `disclose()` at the point of use is sufficient. Adding redundant
`disclose()` calls in helper circuits obscures which values are actually
witness-derived, making code harder to audit for privacy.

**Do not use disclose() to "fix" errors without understanding what you are
making public.** Every `disclose()` is a privacy decision. Before adding one,
answer: "What information will an on-chain observer learn from this value?"
If the answer reveals something that should remain private, restructure the
code instead (see Step 5 in the debugging process).

## Verifying Your Fix

After adding `disclose()` or restructuring code, verify the fix:

1. **Compile the contract** to confirm the disclosure error is resolved. If
   using MCP tools, `midnight-compile-contract` with `skipZk=true` provides
   fast syntax validation. If additional errors appear, repeat the 5-step
   process for each one.

2. **Audit what you are making public.** For every `disclose()` you added,
   trace the value back to its source and ask: "What can an on-chain observer
   learn?" Document the privacy implications as inline comments:

   ```compact
   // Observer learns: the caller's public key (derived from secret key)
   owner = disclose(get_public_key(local_secret_key()));
   ```

3. **Check for a privacy-preserving alternative.** Before accepting a
   `disclose()`, consider whether the design can avoid the disclosure entirely:
   - Can you use `persistentCommit` to store a commitment instead of the raw value?
   - Can you use a `MerkleTree` instead of a `Set` or `Map`?
   - Can you keep the result inside the proof by using an internal (non-exported) circuit?
   - Can you disclose only a boolean property (selective disclosure) instead of the full value?
