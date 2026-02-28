# compact-language-ref Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a comprehensive Compact language mechanics reference skill within the compact-core plugin.

**Architecture:** Single skill directory (`compact-language-ref`) with SKILL.md and 6 reference files. Standalone — no changes to existing `compact-structure` skill. All content sourced from Midnight MCP tools and official documentation.

**Tech Stack:** Markdown files following plugin-dev skill conventions. Use Midnight MCP (`midnight-get-latest-syntax`, `midnight-search-compact`, `midnight-fetch-docs`) for authoritative content.

---

### Task 1: Create skill directory structure

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/SKILL.md`
- Create: `plugins/compact-core/skills/compact-language-ref/references/` (directory)

**Step 1: Create directories**

```bash
mkdir -p plugins/compact-core/skills/compact-language-ref/references
```

**Step 2: Verify structure**

```bash
find plugins/compact-core/skills/compact-language-ref -type d
```

Expected:
```
plugins/compact-core/skills/compact-language-ref
plugins/compact-core/skills/compact-language-ref/references
```

---

### Task 2: Write references/types-and-values.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/references/types-and-values.md`

**Research:** Call `midnight-get-latest-syntax` for type definitions and `midnight-fetch-docs` at `/develop/reference/compact/lang-ref` (section "Compact Types") for authoritative type specs.

**Content to cover (all with code examples):**

1. **Primitive types:**
   - `Field` — finite field element, unbounded within field, use for hashes/commitments
   - `Boolean` — `true`/`false`
   - `Bytes<N>` — fixed-size byte array, N is byte count
   - `Uint<N>` — unsigned integer with N bits
   - `Uint<0..MAX>` — bounded unsigned integer
   - Uint equivalence: `Uint<8>` = `Uint<0..255>`, `Uint<64>` = `Uint<0..18446744073709551615>`
   - Numeric literal typing: literal `42` has type `Uint<0..42>`

2. **Opaque types:**
   - Only `Opaque<"string">` and `Opaque<"Uint8Array">` allowed
   - Opaque in circuits = hash representation (cannot inspect)
   - Opaque in witnesses = freely manipulable
   - Opaque in TypeScript = `string` or `Uint8Array`
   - On-chain = bytes/UTF-8 (not encrypted)

3. **Collection types:**
   - `Vector<N, T>` — fixed-size array, access by numeric literal index
   - `Maybe<T>` — optional: `some<T>(val)`, `none<T>()`, `.is_some`, `.value`
   - `Either<L, R>` — sum type: `left<L,R>(val)`, `right<L,R>(val)`, `.is_left`, `.left`, `.right`

4. **Custom types:**
   - `enum` — declaration, dot-notation access (`State.active`), export for TypeScript
   - `struct` — declaration, named-field construction, positional construction, spread syntax (`...s1`), field access via dot notation
   - Tuple creation: `[expr, expr, ...]`

5. **Default values:**
   - `default<T>()` syntax for every type
   - 0 for numeric, false for Boolean, empty for collections

**Target length:** ~1,200 words

---

### Task 3: Write references/operators-and-expressions.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/references/operators-and-expressions.md`

**Research:** Use `midnight-get-latest-syntax` `typeCompatibility` section for authoritative cast/arithmetic rules.

**Content to cover:**

1. **Arithmetic operators:**
   - `+`, `-`, `*` only — no division `/`, no modulo `%`
   - Division/modulo workaround: compute in witness, pass result to circuit
   - Bounded type expansion: `Uint<0..m> + Uint<0..n>` produces `Uint<0..m+n>`
   - Required cast-back: `(a + b) as Uint<64>`
   - Subtraction can fail at runtime if result would be negative
   - Field arithmetic: `Field + Field` works, `Field + Uint<N>` does not

2. **Comparison operators:**
   - `==`, `!=` — equality
   - `<`, `<=`, `>`, `>=` — relational
   - Same-type comparisons only: `Field == Field`, `Uint<N> == Uint<N>`, `Bytes<N> == Bytes<N>`
   - Cross-type comparison requires cast: `myField == (myUint as Field)`

3. **Boolean operators:**
   - `&&` (short-circuit AND), `||` (short-circuit OR), `!` (negation)

4. **Type cast expressions:**
   - Syntax: `expression as Type` (only form; `<Type>expression` not supported)
   - Three cast kinds: static (always succeeds), conversion (semantic change), checked (can fail at runtime)
   - Complete cast path table with all from→to combinations
   - Multi-step casts: `Uint→Bytes` via Field, `Boolean→Field` via Uint

5. **Conditional expressions:**
   - Ternary form: `condition ? expr1 : expr2`
   - Both branches must have compatible types

6. **Literals:**
   - Boolean: `true`, `false`
   - Numeric: `0`, `42`, `1000` — type is `Uint<0..n>` for literal `n`
   - String: `"hello"`, `'hello'` — type is `Bytes<N>` where N is UTF-8 length
   - Padded string: `pad(32, "hello")` — type is `Bytes<32>`

7. **Anonymous circuits (lambdas):**
   - Syntax: `(params): ReturnType => body` or `(params) => expr`
   - Not first-class — must be immediately called

**Target length:** ~1,200 words

---

### Task 4: Write references/control-flow.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/references/control-flow.md`

**Research:** Use `midnight-fetch-docs` at `/develop/reference/compact/lang-ref` sections "for loop", "if statement", "return statement", "const binding statement".

**Content to cover:**

1. **Variable declarations:**
   - `const` only — no `let`, no `var`, no reassignment
   - Optional type annotation: `const x: Field = 42;`
   - Multiple bindings: `const x = 1, y = x;`
   - Shadowing in nested blocks allowed
   - Destructuring: tuple `const [a, b] = pair;` and struct `const {x, y} = point;`

2. **if/else:**
   - Standard form: `if (condition) { ... } else { ... }`
   - No `else if` chaining — use nested if/else
   - Both branches must have compatible return types
   - Condition must be `Boolean`

3. **for loops:**
   - Range iteration: `for (const i of 0 .. 10) { ... }` — i goes from 0 to 9
   - Vector/array iteration: `for (const item of [3, 2, 1]) { ... }`
   - Loop bounds must be compile-time constants (ZK circuit constraint)
   - No `while` loops, no recursion — circuits have fixed computational bounds

4. **return statements:**
   - `return expr;` for circuits with return values
   - `return;` for circuits returning `[]`
   - Every control-flow path must end with a return (or implicit `return;`)

5. **Blocks:**
   - Curly braces create nested scopes: `{ const x = 1; ... }`
   - Constants can be shadowed in nested blocks

6. **What doesn't exist:**
   - No `while` loops (non-deterministic iteration count)
   - No recursion (circuits must have fixed depth)
   - No `let`/`var` (no mutable variables)
   - No `switch`/`match` (use if/else chains)
   - No exceptions/try-catch (use `assert` for error conditions)

**Target length:** ~800 words

---

### Task 5: Write references/modules-and-imports.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/references/modules-and-imports.md`

**Research:** Use `midnight-fetch-docs` at `/develop/reference/compact/lang-ref` sections "Include files", "Modules, exports, and imports", "Top-level exports".

**Content to cover:**

1. **Pragma:**
   - Syntax: `pragma language_version >= 0.16 && <= 0.18;`
   - Bounded range required, no patch versions
   - Must be first statement in file

2. **Include files:**
   - Syntax: `include "path/to/file";`
   - Searches for `path/to/file.compact` in current directory, then `COMPACT_PATH`
   - Included verbatim — no namespace isolation
   - Can appear at top level or within modules

3. **Modules:**
   - Definition: `module ModName { ... }`
   - Generic modules: `module ModName<T> { ... }`
   - Identifiers private by default — must `export` explicitly
   - Two export forms: `export` prefix on definition, or `export { name1, name2 };`

4. **Imports:**
   - Standard library: `import CompactStandardLibrary;`
   - Module import: `import ModName;` brings exported names into scope
   - Prefixed import: `import ModName prefix Prefix_;` — names become `Prefix_name`
   - Generic import: `import Identity<Field>;` specializes generic module
   - Path import: `import "path/to/module";` or `import "path/to/module" prefix P_;`
   - Compiler looks for `ModName.compact` in current directory, then `COMPACT_PATH`

5. **Top-level exports:**
   - `export ledger`, `export circuit`, `export enum`, `export struct`
   - Re-exporting: `export { Maybe, Either };`
   - Exported names are accessible from TypeScript DApp code

6. **File organization patterns:**
   - Single file for small contracts
   - `include` for splitting large contracts (types, ledger, witnesses, circuits in separate files)
   - Modules for reusable library code with namespace isolation

**Target length:** ~800 words

---

### Task 6: Write references/stdlib-functions.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/references/stdlib-functions.md`

**Research:** Use `midnight-get-latest-syntax` `builtinFunctions.stdlib` for authoritative signatures.

**Content to cover (positive reference only — no "what doesn't exist"):**

1. **Hashing functions:**
   - `persistentHash<T>(value: T): Bytes<32>` — Poseidon hash, deterministic, same input always same output. Use for ledger-stored hashes, public key derivation, commitments that need to be verified later.
   - `transientHash<T>(value: T): Field` — returns `Field` NOT `Bytes<32>`. Use for intermediate computations not stored in ledger.
   - Key difference: persistent returns `Bytes<32>`, transient returns `Field`

2. **Commitment functions:**
   - `persistentCommit<T>(value: T): Bytes<32>` — hiding commitment. Use for ledger-stored commitments.
   - `transientCommit<T>(value: T, rand: Field): Field` — returns `Field` NOT `Bytes<32>`. Takes explicit randomness parameter. Use for intermediate commitments.
   - Key difference: persistent takes no randomness (built-in), transient requires explicit randomness

3. **Utility functions:**
   - `pad(length, value): Bytes<N>` — pad string literal to fixed-length bytes. Both args must be literals. UTF-8 encoding followed by zero bytes.
   - `disclose(value: T): T` — explicitly mark a value as publicly visible on-chain. Required when witness values flow to ledger operations or conditionals.
   - `assert(condition: Boolean, message?: string): []` — fail the circuit (abort transaction) if condition is false. Message is optional but recommended.
   - `default<T>(): T` — default value for any type: 0 for numeric, false for Boolean, empty for collections.

4. **When to use persistent vs transient:**
   - Persistent: value will be stored in ledger or compared across transactions
   - Transient: value is used within a single circuit execution and discarded

**Target length:** ~800 words

---

### Task 7: Write references/troubleshooting.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/references/troubleshooting.md`

**Research:** Use `midnight-get-latest-syntax` `commonErrors` and `commonMistakes` arrays for comprehensive error catalog.

**Content to cover:**

1. **Functions that do NOT exist:**
   - `public_key(sk)` — use `persistentHash<Vector<2, Bytes<32>>>([pad(32, "app:pk:"), sk])` pattern
   - `verify_signature(msg, sig, pk)` — do signature verification off-chain in witness
   - `random()` — ZK circuits are deterministic, use `witness get_random_value(): Field;`

2. **Common compiler errors (table: error message → cause → fix):**
   - `unbound identifier "public_key"` → not a builtin → use persistentHash
   - `incompatible combination of types Field and Uint` → type mismatch → cast with `as`
   - `operation "value" undefined for Counter` → wrong method → use `.read()`
   - `implicit disclosure of witness value` → missing `disclose()` → wrap conditional
   - `parse error: found "{" looking for an identifier` → `ledger {}` block → individual declarations
   - `parse error: found "{" looking for ";"` → `Void` return type → use `[]`
   - `unbound identifier "Cell"` → deprecated wrapper → use type directly
   - `potential witness-value disclosure must be declared` → param to ledger → `disclose()`
   - `expected ... Uint<64> but received Uint<0..N>` → arithmetic result → cast back
   - `cannot cast from type Uint<64> to type Bytes<32>` → direct cast → go through Field
   - `cannot prove assertion` → logic error → check witness values and ranges
   - `parse error: found ":" looking for ")"` → `Enum::variant` → use dot notation
   - `parse error: found "{" after witness` → witness body → declaration only
   - `unbound identifier "function"` → `pure function` → use `pure circuit`

3. **Wrong→correct syntax quick reference (table):**
   - All 14 common mistakes from MCP syntax reference with wrong, correct, and error message

**Target length:** ~1,000 words

---

### Task 8: Write SKILL.md

**Files:**
- Create: `plugins/compact-core/skills/compact-language-ref/SKILL.md`

**Dependencies:** All 6 reference files must exist first (Tasks 2-7).

**Content structure:**

1. **Frontmatter:**
   - `name: compact-language-ref`
   - `description:` third-person, ~400 chars, trigger phrases for types, casting, operators, arithmetic, control flow, for loops, modules, imports, include, stdlib functions, Compact syntax reference, language mechanics

2. **Body (~1,500-2,000 words):**
   - Opening paragraph: purpose of this skill (language mechanics, not contract architecture)
   - **Types quick reference table:** primitives, collections, custom — one-line each
   - **Operators table:** arithmetic (+,-,*), comparison (==,!=,<,<=,>,>=), boolean (&&,||,!)
   - **Type casting quick reference:** safe casts, checked casts, multi-step casts — table format
   - **Control flow summary:** const, if/else, for loops, no while/recursion
   - **Module system summary:** pragma, import, include, export, modules
   - **Standard library summary:** all 8 functions in table with signatures
   - **Reference routing table:** maps topics to reference files

**Step 1: Write SKILL.md**

Use the Write tool to create the file with full content.

**Step 2: Verify word count**

```bash
wc -w plugins/compact-core/skills/compact-language-ref/SKILL.md
```

Expected: 1,500-2,000 words

---

### Task 9: Validate and review

**Step 1: Verify all files exist**

```bash
find plugins/compact-core/skills/compact-language-ref -type f | sort
```

Expected:
```
plugins/compact-core/skills/compact-language-ref/SKILL.md
plugins/compact-core/skills/compact-language-ref/references/control-flow.md
plugins/compact-core/skills/compact-language-ref/references/modules-and-imports.md
plugins/compact-core/skills/compact-language-ref/references/operators-and-expressions.md
plugins/compact-core/skills/compact-language-ref/references/stdlib-functions.md
plugins/compact-core/skills/compact-language-ref/references/troubleshooting.md
plugins/compact-core/skills/compact-language-ref/references/types-and-values.md
```

**Step 2: Check word counts**

```bash
wc -w plugins/compact-core/skills/compact-language-ref/SKILL.md plugins/compact-core/skills/compact-language-ref/references/*.md
```

Expected: SKILL.md 1,500-2,000 words, references 800-1,200 each, total ~6,000-8,000

**Step 3: Run plugin-validator agent**

Validate the compact-core plugin structure, manifest, and all skills.

**Step 4: Run skill-reviewer agent**

Review compact-language-ref skill for description quality, progressive disclosure, writing style.

**Step 5: Fix any issues from validation**

Address critical/major issues identified by validators.

---

### Task 10: Commit

**Step 1: Stage files**

```bash
git add plugins/compact-core/skills/compact-language-ref/
```

**Step 2: Commit**

```bash
git commit -m "feat(compact-core): add compact-language-ref skill

Comprehensive Compact language mechanics reference covering types,
operators, expressions, control flow, modules/imports, stdlib
functions, and troubleshooting/common mistakes.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

**Step 3: Verify**

```bash
git status
git log --oneline -3
```

Expected: clean working tree, new commit visible
