# MCP Compile Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract MCP-hosted compilation into a dedicated `mcp-compile` skill with workflow-oriented references, error example files, and a bail-out gate for local compilation routing.

**Architecture:** New skill with SKILL.md (bail-out gate + routing table), 6 workflow references with inline examples, 5 error example files with before/after pairs. Surgical edit to `mcp-analyze` to remove compile tools and add cross-reference.

**Tech Stack:** Markdown content files within the Claude Code plugin system. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-19-mcp-compile-skill-design.md`

---

## Dependency Graph

```
Task 1 (SKILL.md) ───────────────────────────────────────────────┐
  │                                                               │
  ├── Task 2 (quick-validation reference)             ──┐         │
  ├── Task 3 (multi-version reference)                ──┤         │
  ├── Task 4 (snippet-compilation reference)          ──┤         │
  ├── Task 5 (error-recovery reference + 5 examples)  ──┼── All ── Task 8 (Integration)
  ├── Task 6 (archive-compilation reference)          ──┤
  ├── Task 7 (full-compilation reference)             ──┘
  │
  └── (no dependency) ── Task 7.5 (Update mcp-analyze) ────────── Task 8 (Integration)
```

Tasks 2-7 are independent of each other and CAN run in parallel.
Task 7.5 is independent of Tasks 2-7 and CAN run in parallel with them.
Task 8 depends on all other tasks.

## Conventions

All paths in this plan are relative to `plugins/midnight-mcp/` unless stated otherwise.

**Reference file conventions** (from existing codebase patterns):
- No YAML frontmatter — references are plain markdown
- Start with `# Title` heading
- Concise, operational tone — instructions the LLM executes, not explanations
- Inline examples where appropriate (code blocks with parameter/response examples)

**Error example file conventions** (from spec):
- No YAML frontmatter
- Template: `# [Category] Examples` → `## When This Error Occurs` → `## Examples` (before/after pairs) → `## Anti-Patterns`
- Error message shown as it appears in `CompilerError.message`
- Code examples in Compact language using real syntax and types

---

### Task 1: Create SKILL.md

**Files:**
- Create: `skills/mcp-compile/SKILL.md`

- [ ] **Step 1: Create directories**

```bash
mkdir -p plugins/midnight-mcp/skills/mcp-compile/references
mkdir -p plugins/midnight-mcp/skills/mcp-compile/examples
```

- [ ] **Step 2: Write the SKILL.md**

```markdown
---
name: mcp-compile
description: This skill should be used when the user asks about compiling Compact code via MCP, hosted compilation, midnight-compile-contract, midnight-compile-archive, MCP compile, snippet compilation, multi-version compilation, compile errors from MCP, code auto-wrapping, testing backwards compatibility across Compact versions, OpenZeppelin library linking in MCP compilation, or interpreting hosted compiler responses.
---

# MCP-Hosted Compact Compilation

Compile Compact contracts using the hosted compiler service via MCP tools. Supports single-file and multi-file compilation, snippet auto-wrapping, multi-version testing, and OpenZeppelin library linking.

## When to Use Local Compilation Instead

Evaluate these conditions before continuing. If any match, stop loading this skill and use the referenced skill instead.

| Condition | Use Instead |
|-----------|-------------|
| Project imports from locally installed npm Compact packages | `compact-core:compact-compilation` |
| Need full artifact tree on disk (ZKIR, keys, TS bindings as files) | `compact-core:compact-compilation` |
| Bulk or automated compilation (hundreds+ of contracts) | `compact-core:compact-compilation` |
| CI/CD pipeline compilation | `compact-core:compact-compilation` + `midnight-tooling:compact-cli` |
| Need custom compiler flags not exposed by the MCP tool | `compact-core:compact-compilation` |

If none of these apply, continue with MCP-hosted compilation below.

## Compile Tools

| Tool | What It Does | When to Use |
|------|-------------|-------------|
| `midnight-compile-contract` | Compile single-file Compact code with hosted compiler | Quick validation, snippet testing, multi-version compat |
| `midnight-compile-archive` | Compile multi-file projects via file map | Projects with imports between Compact files, OZ module usage |

## Workflow Routing

Load the reference matching your current task. If compilation fails, also load `references/error-recovery.md`.

| Workflow | Reference | When |
|----------|-----------|------|
| Quick syntax/type check | `references/quick-validation.md` | LLM wrote or modified code, needs fast feedback |
| Test across compiler versions | `references/multi-version.md` | Backwards/forwards compat without changing local toolchain |
| Compile a code snippet | `references/snippet-compilation.md` | Incomplete code fragments, not full contracts |
| Interpret and recover from errors | `references/error-recovery.md` | Compilation failed, need to diagnose and fix |
| Multi-file project compilation | `references/archive-compilation.md` | Project with imports between files or OZ libraries |
| Full ZK compilation with artifacts | `references/full-compilation.md` | Pre-deployment validation, circuit metrics, TypeScript bindings |

## Rate Limits

The hosted compiler has rate limits. Budget your compile calls.

| Tool | Limit | Window |
|------|-------|--------|
| `midnight-compile-contract` | 20 requests | 60 seconds |
| `midnight-compile-archive` | 10 requests | 60 seconds |

When hitting rate limits: fix all reported errors before recompiling rather than recompiling after each individual fix.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Local CLI compilation, artifacts, ZKIR, keys | `compact-core:compact-compilation` |
| Compact standard library reference | `compact-core:compact-standard-library` |
| Analysis, visualization, formatting, diffing | `mcp-analyze` |
| Tool routing and category overview | `mcp-overview` |
| Verification methodology using compilation | `compact-core:verify-correctness` |
```

- [ ] **Step 3: Verify the SKILL.md**

Read back the file and confirm:
- Frontmatter has `name: mcp-compile` and `description` with compile-related trigger words
- Bail-out table is the first content after the title
- Workflow routing table has 6 rows pointing to reference files
- Rate limits section is present
- Cross-references section links to `compact-core:compact-compilation`, `mcp-analyze`, and others

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/SKILL.md
git commit -m "feat(mcp-compile): create skill with bail-out gate, workflow routing, and rate limit guidance"
```

---

### Task 2: Quick Validation Reference

**Files:**
- Create: `skills/mcp-compile/references/quick-validation.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/quick-validation.md`**

This is the most common workflow — the LLM wrote or modified Compact code and needs to check if it compiles.

Content to include:

**When to use:** After writing or modifying Compact code. This is the default compilation workflow.

**Parameters:**
- `code`: the Compact source code (required)
- `skipZk: true`: already the default — fast syntax and type checking without ZK generation (~1-2s)
- `version: "detect"`: use when the code has a `pragma language_version` and you want the compiler to match it. Otherwise omit to use the default (latest) version.

**Inline example — successful compile:**
```
Call: midnight-compile-contract({ code: "<compact source>", skipZk: true })
Response: {
  success: true,
  compilationMode: "syntax-only",
  compilerVersion: "0.29.0",
  executionTime: 1200,
  errors: [],
  warnings: []
}
Action: Code compiles. Proceed with the task.
```

**Inline example — failed compile:**
```
Call: midnight-compile-contract({ code: "<compact source>", skipZk: true })
Response: {
  success: false,
  compilationMode: "syntax-only",
  compilerVersion: "0.29.0",
  errors: [{
    message: "expected ';' but found '{'",
    severity: "error",
    line: 5,
    column: 30
  }],
  executionTime: 800
}
Action: Load references/error-recovery.md to diagnose and fix.
```

**The fix-and-recompile loop:**
1. Read ALL errors in the response (there may be multiple)
2. Fix all errors in the code before recompiling — do not recompile after each individual fix
3. Recompile once with the corrected code
4. If new errors appear, repeat (max 2-3 rounds)
5. If still failing after 3 attempts, present the errors to the user and ask for help

**Rate limit awareness:** 20 calls per 60 seconds. With the fix-and-recompile loop, each round costs one call. Three rounds = 3 calls. Rapid-fire single-error fixes would waste the budget.

**Warnings:** If `success: true` but `warnings` is non-empty, note the warnings but treat the compilation as successful. Warnings are informational — they don't block compilation.

**Response fields to check:**
- `success` — did it compile?
- `errors` — if failed, what went wrong? (load `references/error-recovery.md`)
- `warnings` — if succeeded, any concerns?
- `compilationMode` — confirms syntax-only validation
- `compilerVersion` — which compiler version was used
- `originalCode` / `wrappedCode` — if auto-wrapping occurred, these show what was changed (see `references/snippet-compilation.md`)

- [ ] **Step 2: Verify the file**

Read back. Confirm it has inline examples for both success and failure cases, the fix-and-recompile loop guidance, and rate limit awareness.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/references/quick-validation.md
git commit -m "feat(mcp-compile): add quick validation workflow reference"
```

---

### Task 3: Multi-Version Reference

**Files:**
- Create: `skills/mcp-compile/references/multi-version.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/multi-version.md`**

Content to include:

**When to use:** Testing the same code against multiple Compact compiler versions simultaneously. Useful for backwards/forwards compatibility checks without installing different compiler versions locally.

**Parameters:**
- `code`: the Compact source code (required)
- `versions`: array of version strings (max 10). Each version runs in parallel.
- `skipZk: true`: recommended for multi-version testing (faster, sufficient for compat checks)

**Special version values:**
- `"latest"` — newest installed compiler version
- `"detect"` — resolve from `pragma language_version` constraints in the code
- Specific version string — e.g., `"0.29.0"`, `"0.28.0"`

**Common use cases:**

| Task | Versions to test |
|------|------------------|
| Backwards compatibility | `["detect", "0.26.0", "0.25.0"]` |
| Forward compatibility (will it work on latest?) | `["detect", "latest"]` |
| Find which version introduced a breaking change | `["0.26.0", "0.27.0", "0.28.0", "0.29.0"]` |
| Test against project's pragma constraints | `["detect"]` (single version, pragma-resolved) |

**Inline example — multi-version compile:**
```
Call: midnight-compile-contract({
  code: "<compact source>",
  versions: ["latest", "0.28.0", "0.26.0"],
  skipZk: true
})
Response: [
  { success: true,  requestedVersion: "latest", compilerVersion: "0.29.0", ... },
  { success: true,  requestedVersion: "0.28.0", compilerVersion: "0.28.0", ... },
  { success: false, requestedVersion: "0.26.0", compilerVersion: "0.26.0",
    errors: [{ message: "...", line: 3, column: 10 }], ... }
]
Action: Code compiles on 0.28.0+ but not 0.26.0. Report the compatibility boundary.
```

**Interpreting multi-version results:**
- Each version returns its own result object with `requestedVersion` (what you asked for) and `compilerVersion` (what was resolved)
- Check `success` per version — some may pass while others fail
- If a version fails, check its `errors[]` for version-specific issues (syntax that doesn't exist in older versions, deprecated constructs removed in newer versions)
- When reporting to the user, show the compatibility matrix: which versions pass and which fail

**Limits:** Maximum 10 versions per request. For broader sweeps, split into multiple calls.

- [ ] **Step 2: Verify the file**

Read back. Confirm it covers special version values, common use case table, inline multi-version example, and result interpretation.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/references/multi-version.md
git commit -m "feat(mcp-compile): add multi-version compilation workflow reference"
```

---

### Task 4: Snippet Compilation Reference

**Files:**
- Create: `skills/mcp-compile/references/snippet-compilation.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/snippet-compilation.md`**

Content to include:

**When to use:** Compiling incomplete Compact code fragments — a circuit definition without the surrounding contract, a ledger declaration, or a code sample from documentation. The hosted compiler auto-wraps incomplete snippets into valid contracts.

**How auto-wrapping works:**

The compiler detects whether the submitted code is a complete contract or a snippet:

| Snippet type | Detection | What gets added |
|-------------|-----------|-----------------|
| `complete` | Code has `pragma language_version` | Nothing — sent as-is |
| `circuit` | Starts with `circuit` or `export circuit` | Pragma + stdlib import |
| `ledger` | Starts with `ledger`, `export ledger`, `struct`, or `enum` | Pragma + stdlib import |
| `unknown` | Anything else | Pragma + stdlib import |

**What the wrapper adds:**

For code missing both pragma and stdlib import (most common case for snippets):
```
pragma language_version >= 0.14;

import CompactStandardLibrary;

<your code here>
```

This adds 4 lines before the user's code.

**Line offset rules:**

Error line numbers in the response are relative to the WRAPPED code, not the original. Adjust using:

| Condition | Lines added | Adjustment |
|-----------|-------------|------------|
| Code has `pragma` | 0 | None needed |
| Code has stdlib import but no pragma | 2 | Subtract 2 from error line |
| Code has neither pragma nor import | 4 | Subtract 4 from error line |

**How to detect wrapping occurred:** If the response includes `originalCode` and `wrappedCode` fields, wrapping occurred. Compare them to determine the offset.

**Inline example — snippet compilation:**
```
Code submitted: "export circuit add(a: Uint<64>, b: Uint<64>): Uint<64> { return a + b; }"

Wrapped code (by compiler):
  Line 1: pragma language_version >= 0.14;
  Line 2: (blank)
  Line 3: import CompactStandardLibrary;
  Line 4: (blank)
  Line 5: export circuit add(a: Uint<64>, b: Uint<64>): Uint<64> { return a + b; }

If an error reports line 5 → the error is on line 1 of the original snippet (5 - 4 = 1).
```

**Limitations:**
- Auto-wrapping adds boilerplate but cannot add missing context. If a snippet references a ledger field declared elsewhere, or a type from another file, wrapping won't help — the compiler will report an undefined reference.
- For snippets that need surrounding context, either provide a complete contract or use `midnight-compile-archive` with the full file set.
- The default pragma is `>= 0.14` (open-ended). To pin a specific version, include the pragma in your snippet.

- [ ] **Step 2: Verify the file**

Read back. Confirm it covers wrapping rules, line offset adjustment table, inline example showing offset math, and limitations.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/references/snippet-compilation.md
git commit -m "feat(mcp-compile): add snippet compilation workflow reference"
```

---

### Task 5: Error Recovery Reference + 5 Example Files

**Files:**
- Create: `skills/mcp-compile/references/error-recovery.md`
- Create: `skills/mcp-compile/examples/parse-errors.md`
- Create: `skills/mcp-compile/examples/type-errors.md`
- Create: `skills/mcp-compile/examples/disclosure-errors.md`
- Create: `skills/mcp-compile/examples/overflow-errors.md`
- Create: `skills/mcp-compile/examples/service-errors.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/error-recovery.md`**

This is the routing hub for error interpretation. The LLM loads this when compilation fails, then selectively loads the example file matching the error pattern.

Content to include:

**When to use:** After any failed compilation. This reference helps diagnose the error and route to the correct example file.

**Reading the CompilerError structure:**
```
{
  message: "expected ';' but found '{'",   // Error description
  severity: "error",                        // "error", "warning", or "info"
  file: "contract.compact",                 // Source file (optional)
  line: 5,                                  // 1-based line number (optional)
  column: 30                                // 1-based column (optional)
}
```

**Error category routing — match the error message pattern, then load the corresponding example file:**

| Error Pattern | Category | Example File |
|---------------|----------|-------------|
| `"expected '...' but found '...'"` | Parse error | `examples/parse-errors.md` |
| `"no matching overload"` | Type error | `examples/type-errors.md` |
| `"potential witness-value disclosure must be declared"` | Disclosure error | `examples/disclosure-errors.md` |
| `"integer too large"`, `"MAX_FIELD"`, overflow | Overflow error | `examples/overflow-errors.md` |
| HTTP 429, timeout, 5xx, connection error | Service error | `examples/service-errors.md` |
| `"internal compiler error"` | Compiler bug | See recovery steps below |

**Load only the example file matching your error.** Do not load all example files.

**Line number adjustment for wrapped snippets:**
If the compilation used auto-wrapping (check `originalCode` / `wrappedCode` in response), subtract the wrapper offset from error line numbers before interpreting. See `references/snippet-compilation.md` for offset rules.

**The recovery loop:**
1. Read ALL errors in the response
2. Match each error to its category using the routing table above
3. Load the example file for the primary error category
4. Fix all errors in the code
5. Recompile once
6. If new errors appear (common — fixing one error can reveal others), repeat from step 1
7. Maximum 2-3 rounds. If still failing, present the errors to the user with your diagnosis and ask for help.

**Internal compiler errors:** If the error message contains "internal compiler error" or the compilation exits with no message:
1. Try a different compiler version (`version: "latest"` or a specific recent version)
2. If it persists across versions, this is a compiler bug — inform the user and suggest filing an issue
3. Cross-reference: `compact-core:compact-compilation` references/compiler-errors.md has a catalog of known internal errors and their fixed versions

**For the full error catalog** with detailed explanations of every error category, compiler behavior, and version-specific quirks, see `compact-core:compact-compilation` references/compiler-errors.md. The example files below cover the most common errors and how to fix them in the MCP context.

- [ ] **Step 2: Write `examples/parse-errors.md`**

```markdown
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
```

- [ ] **Step 3: Write `examples/type-errors.md`**

5 before/after pairs covering:

1. **Mixing Field and Uint without cast:**
   - Error: `no matching overload for operator ... expected Field but received Uint<64>`
   - Bad: `const result = myField + myUint;`
   - Fix: `const result = myField + (myUint as Field);`

2. **Arithmetic result type expansion:**
   - Error: `expected Uint<64> but received Uint<0..N>`
   - Bad: `balances.insert(key, a + b);`
   - Fix: `balances.insert(key, (a + b) as Uint<64>);`

3. **Direct Uint to Bytes cast:**
   - Error: `cannot cast from type Uint<64> to type Bytes<32>`
   - Bad: `const b: Bytes<32> = amount as Bytes<32>;`
   - Fix: `const b: Bytes<32> = (amount as Field) as Bytes<32>;`

4. **Wrong argument type to ADT method:**
   - Error: `no matching overload` on a Map/Set/Counter method
   - Bad: passing `Field` to a `Map<Bytes<32>, Uint<64>>` insert
   - Fix: match the declared value type

5. **Generic parameter mismatch:**
   - Error: type parameter constraint not met
   - Bad: passing wrong type where a generic constraint exists
   - Fix: check the expected type parameter and match it

Anti-patterns (3):
- Adding casts everywhere without understanding the mismatch
- Casting to `Field` as a universal fix (works for some, wrong for others — e.g., `Bytes` needs two-step)
- Ignoring the compiler's overload candidate list (it shows all valid signatures)

- [ ] **Step 4: Write `examples/disclosure-errors.md`**

5 before/after pairs covering:

1. **Witness value assigned to ledger field:**
   - Error: `potential witness-value disclosure must be declared but is not`
   - Bad: `balance = getBalance();`
   - Fix: `balance = disclose(getBalance());`

2. **Witness value in if condition:**
   - Error: same disclosure error with "via this path" pointing to the conditional
   - Bad: `if (getIsAuthorized()) { ... }`
   - Fix: `if (disclose(getIsAuthorized())) { ... }`

3. **Witness value returned from exported circuit:**
   - Error: disclosure via return path
   - Bad: `return getSecret();`
   - Fix: `return disclose(getSecret());`

4. **Witness value passed to ADT method:**
   - Error: disclosure via ledger operation
   - Bad: `counter.increment(getAmount());`
   - Fix: `counter.increment(disclose(getAmount()));`

5. **Transitive disclosure through intermediate computation:**
   - Error: disclosure via multi-step path
   - Bad: `const x = getSecret(); const y = x + 1; ledgerField = y;`
   - Fix: `const x = getSecret(); const y = x + 1; ledgerField = disclose(y);` (disclose at the boundary, not on every intermediate)

Anti-patterns (3):
- Wrapping every variable in `disclose()` defensively (only values crossing the public boundary need it)
- Adding `disclose()` on non-witness values (the compiler traces witness origin — non-witness values never trigger this error)
- Not reading the "via this path" trace (the error tells you exactly the data flow path — follow it to find the right place for `disclose()`)

- [ ] **Step 5: Write `examples/overflow-errors.md`**

3 before/after pairs covering:

1. **Integer literal exceeds field modulus:**
   - Error: integer too large / exceeds BLS12-381 scalar field (~2^255)
   - Bad: `const huge = 999999999999999999999999999999999999999999999999999999999999999999999999999999;`
   - Fix: use smaller values within the field modulus, or restructure the computation

2. **Large constant computation overflow at compile time:**
   - Error: compile-time arithmetic exceeds field
   - Bad: `const result = 2 ** 256;` (exponentiation overflows)
   - Fix: restructure as runtime computation using witness if needed

3. **MAX_FIELD runtime mismatch (post-compilation):**
   - Error: `CompactError: compiler thinks maximum field value is 524358... but runtime says ...`
   - Diagnosis: compiler and `@midnight-ntwrk/compact-runtime` target different proof system curves
   - Fix: align versions — `npm install @midnight-ntwrk/compact-runtime@<matching-version>`

Anti-patterns (2):
- Trying to increase the integer type size (`Uint<128>` → `Uint<256>`) — the field modulus is a hard limit of the BLS12-381 proof system, not related to the `Uint<N>` type width
- Confusing `Uint<N>` max values with the field modulus — `Uint<64>` max is 2^64-1, but the field modulus is ~2^255. These are different constraints applied at different stages.

- [ ] **Step 6: Write `examples/service-errors.md`**

3 before/after pairs covering:

1. **429 Rate Limit:**
   - Error: HTTP 429 "Rate limit exceeded"
   - Context: too many compile calls within 60 seconds
   - Recovery: wait for the rate limit window to reset. Batch all code fixes before recompiling — don't recompile after every single-line fix. If consistently hitting limits, consider switching to local compilation for the session.

2. **Compilation timeout:**
   - Error: compilation did not complete within the timeout window
   - Context: complex contracts with many circuits or full ZK compilation on large contracts
   - Recovery: use `skipZk: true` if you don't need ZK artifacts. For very large contracts, use local compilation where there's no server-side timeout. If `skipZk: true` also times out, the contract may be too complex for the hosted service.

3. **Service unavailable (5xx):**
   - Error: HTTP 500/502/503
   - Context: the playground service may be sleeping (Fly.io cold start) or experiencing an outage
   - Recovery: wait 5 seconds and retry once. If the error persists, fall back to local compilation. This is an infrastructure issue, not a code problem.

Anti-patterns (2):
- Rapid-fire recompilation attempts when rate limited (this makes the problem worse — you'll stay rate limited longer. Fix all errors first, then submit one compile call.)
- Assuming service errors mean the code is wrong (429, timeout, and 5xx are infrastructure issues — the code hasn't been evaluated. Don't modify the code in response to service errors.)

- [ ] **Step 7: Verify all files**

Read back each file. Confirm:
- `references/error-recovery.md` has the error pattern routing table pointing to all 5 example files
- Each example file follows the template: `# [Category] Examples` → `## When This Error Occurs` → `## Examples` with error/code/diagnosis/fix → `## Anti-Patterns`
- Parse errors has 6 examples and 3 anti-patterns
- Type errors has 5 examples and 3 anti-patterns
- Disclosure errors has 5 examples and 3 anti-patterns
- Overflow errors has 3 examples and 2 anti-patterns
- Service errors has 3 examples and 2 anti-patterns
- All Compact code examples use real syntax and types

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/references/error-recovery.md
git add plugins/midnight-mcp/skills/mcp-compile/examples/parse-errors.md
git add plugins/midnight-mcp/skills/mcp-compile/examples/type-errors.md
git add plugins/midnight-mcp/skills/mcp-compile/examples/disclosure-errors.md
git add plugins/midnight-mcp/skills/mcp-compile/examples/overflow-errors.md
git add plugins/midnight-mcp/skills/mcp-compile/examples/service-errors.md
git commit -m "feat(mcp-compile): add error recovery reference and 5 error example files"
```

---

### Task 6: Archive Compilation Reference

**Files:**
- Create: `skills/mcp-compile/references/archive-compilation.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/archive-compilation.md`**

Content to include:

**When to use:** Compiling multi-file Compact projects where source files import from each other, or when linking OpenZeppelin library modules.

**The `files` parameter:** A Record mapping relative file paths to source code. The directory structure in the keys is preserved so that import resolution works correctly.

**Inline example — multi-file project:**
```
Call: midnight-compile-archive({
  files: {
    "src/main.compact": "pragma language_version >= 0.16;\nimport \"./lib/token.compact\";\n...",
    "src/lib/token.compact": "pragma language_version >= 0.16;\nimport CompactStandardLibrary;\n..."
  },
  options: { skipZk: true }
})
```

**OpenZeppelin library linking:**

To use OZ Compact modules, pass them via `options.libraries`:

```
Call: midnight-compile-archive({
  files: {
    "src/main.compact": "pragma language_version >= 0.16;\nimport \"access/Ownable\";\n..."
  },
  options: {
    skipZk: true,
    libraries: ["access/Ownable"]
  }
})
```

Available OZ domains and modules:

| Domain | Example Modules |
|--------|----------------|
| `access` | `Ownable`, `AccessControl` |
| `security` | (security modules) |
| `token` | `FungibleToken`, `Transferable` |
| `utils` | (utility modules) |

Format: `"domain/ModuleName"`. Max 20 libraries per request. Transitive cross-domain dependencies are resolved automatically — if `Ownable` imports from `utils`, the `utils` domain is linked automatically.

**When to use archive vs single-file:**
- Use `midnight-compile-archive` when: your code has `import "./other.compact"` statements, you're using OZ modules, or the project is split across multiple files
- Use `midnight-compile-contract` when: it's a single self-contained file or snippet with no external imports (stdlib import is handled by auto-wrapping)

**Rate limit:** 10 requests per 60 seconds (stricter than single-file compile at 20/60s). Budget accordingly.

**Multi-version support:** Archive compilation also supports `version` and `versions` parameters. Same behavior as single-file: `"detect"` resolves from pragma, `"latest"` uses newest compiler, or specify a version string.

- [ ] **Step 2: Verify the file**

Read back. Confirm it covers the `files` map structure, OZ library linking with domain/module format, when to use archive vs single-file, rate limits, and multi-version support.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/references/archive-compilation.md
git commit -m "feat(mcp-compile): add archive compilation workflow reference"
```

---

### Task 7: Full Compilation Reference

**Files:**
- Create: `skills/mcp-compile/references/full-compilation.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/full-compilation.md`**

Content to include:

**When to use:** Pre-deployment validation, circuit metric analysis, or when TypeScript bindings are needed from the hosted compiler.

**Parameters:**
- `fullCompile: true` — performs full ZK compilation including circuit generation (~10-30s). Overrides `skipZk`.
- `includeBindings: true` — returns compiler-generated TypeScript artifacts in the response. Implicitly forces full compilation.

**Inline example — full compile with insights:**
```
Call: midnight-compile-contract({
  code: "<compact source>",
  fullCompile: true
})
Response: {
  success: true,
  compilationMode: "full",
  compilerVersion: "0.29.0",
  executionTime: 15200,
  insights: {
    circuitCount: 2,
    circuits: [
      { name: "transfer", k: 8, rows: 180 },
      { name: "mint", k: 5, rows: 24 }
    ],
    usesZkProofs: true
  }
}
```

**Interpreting CompilerInsights:**

| Field | Meaning | What to watch for |
|-------|---------|-------------------|
| `circuitCount` | Number of compiled circuits | Unexpected count may indicate missing exports |
| `circuits[].name` | Circuit name | Should match your exported circuit names |
| `circuits[].k` | Evaluation domain size (2^k) | Each increment roughly doubles proving time. k=5 is small, k=15+ is expensive |
| `circuits[].rows` | Constraint rows used | Must be <= 2^k. Higher = more complex circuit |
| `usesZkProofs` | Whether any circuit generates ZK proofs | `false` means all circuits are pure (no on-chain state) |

**k-value guidance:**
- k=5 (~32 rows): small circuit, fast proving
- k=8 (~256 rows): moderate circuit
- k=12 (~4096 rows): complex circuit, noticeable proving time
- k=16+ (~65536+ rows): very complex, significant proving time — consider optimization

**includeBindings:**
When `includeBindings: true`, the response includes a `bindings` field — a Record mapping file paths to generated TypeScript content. This is the same content that local compilation writes to the `contract/` directory.

Use this when you need to inspect the generated types without running a local compile. For full artifact generation on disk (ZKIR, keys, plus bindings), use local compilation instead.

**Execution time expectations:**
- Syntax-only (`skipZk: true`): 1-2 seconds
- Full compilation (`fullCompile: true`): 10-30 seconds depending on circuit complexity
- Full with bindings: same as full compilation (bindings are generated as a side effect)

**When NOT to use full compilation:**
- During iterative development (use `skipZk: true` for fast feedback)
- When you only need to check syntax/types (full compile is wasteful for validation)
- When you need artifacts on disk (use local compilation)

**Cross-reference:** For detailed documentation of ZKIR format, prover/verifier key structure, and TypeScript binding types, see `compact-core:compact-compilation`.

- [ ] **Step 2: Verify the file**

Read back. Confirm it covers `fullCompile` and `includeBindings` parameters, `CompilerInsights` interpretation with k-value guidance, execution time expectations, and when NOT to use full compilation.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-compile/references/full-compilation.md
git commit -m "feat(mcp-compile): add full compilation workflow reference"
```

---

### Task 7.5: Update mcp-analyze SKILL.md

**Files:**
- Modify: `skills/mcp-analyze/SKILL.md`

**Depends on:** Task 1

- [ ] **Step 1: Read the current mcp-analyze SKILL.md**

Read `skills/mcp-analyze/SKILL.md` to confirm current content.

- [ ] **Step 2: Update the frontmatter**

Remove compile-related trigger words from the description:

Change:
```yaml
description: This skill should be used when the user asks about analyzing a Compact contract, compiling a contract via MCP, visualizing a contract, proving a contract, formatting a contract, compiling an archive, MCP compile, MCP analyze, contract analysis pipelines, midnight-analyze-contract, midnight-compile-contract, midnight-compile-archive, midnight-visualize-contract, midnight-prove-contract, midnight-format-contract, midnight-diff-contracts, semantic contract diff, or circuit visualization.
```

To:
```yaml
description: This skill should be used when the user asks about analyzing a Compact contract, visualizing a contract, proving a contract, formatting a contract, MCP analyze, contract analysis pipelines, midnight-analyze-contract, midnight-visualize-contract, midnight-prove-contract, midnight-format-contract, midnight-diff-contracts, semantic contract diff, or circuit visualization.
```

- [ ] **Step 3: Update the title and intro**

Change:
```markdown
# Midnight MCP Analysis and Compilation Tools

Seven tools for analyzing, compiling, visualizing, formatting, proving, and diffing Compact contracts. All analysis and compilation tools produce deterministic results — call each tool once per contract and reuse the result.
```

To:
```markdown
# Midnight MCP Analysis Tools

Five tools for analyzing, visualizing, formatting, proving, and diffing Compact contracts. All tools produce deterministic results — call each tool once per contract and reuse the result.

For compilation tools (`midnight-compile-contract`, `midnight-compile-archive`), see the `mcp-compile` skill.
```

- [ ] **Step 4: Remove the compile tool sections**

Remove the following sections entirely:
- `## midnight-compile-contract` (lines 39-66 in current file)
- `## midnight-compile-archive` (lines 68-80 in current file)

- [ ] **Step 5: Update the Call Frequency table**

Remove the `midnight-compile-contract` and `midnight-compile-archive` rows from the table.

Change:
```markdown
| Tool | Calls per Contract |
|------|--------------------|
| `midnight-analyze-contract` | 1 |
| `midnight-compile-contract` | 1 (per version, if multi-version testing) |
| `midnight-compile-archive` | 1 |
| `midnight-visualize-contract` | 1 |
| `midnight-prove-contract` | 1 |
| `midnight-format-contract` | 1 |
| `midnight-diff-contracts` | 1 per version pair |
```

To:
```markdown
| Tool | Calls per Contract |
|------|--------------------|
| `midnight-analyze-contract` | 1 |
| `midnight-visualize-contract` | 1 |
| `midnight-prove-contract` | 1 |
| `midnight-format-contract` | 1 |
| `midnight-diff-contracts` | 1 per version pair |
```

- [ ] **Step 6: Update the Cross-References table**

Add a row for the new `mcp-compile` skill:

```markdown
| MCP-hosted compilation workflows and error recovery | `mcp-compile` |
```

- [ ] **Step 7: Verify the changes**

Read back the modified file. Confirm:
- Frontmatter description no longer mentions compile, MCP compile, midnight-compile-contract, midnight-compile-archive, or compiling an archive
- Title says "Analysis Tools" not "Analysis and Compilation Tools"
- Intro paragraph mentions 5 tools, not 7
- Cross-reference to `mcp-compile` is present
- The `midnight-compile-contract` and `midnight-compile-archive` sections are gone
- Call frequency table has 5 rows, not 7
- The remaining 5 tool sections (`midnight-analyze-contract`, `midnight-visualize-contract`, `midnight-prove-contract`, `midnight-format-contract`, `midnight-diff-contracts`) are unchanged

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-analyze/SKILL.md
git commit -m "refactor(mcp-analyze): remove compile tools, add cross-reference to mcp-compile skill"
```

---

### Task 8: Integration Verification

**Depends on:** All previous tasks

- [ ] **Step 1: Verify all new files exist**

```bash
# SKILL.md
test -f plugins/midnight-mcp/skills/mcp-compile/SKILL.md && echo "OK: SKILL.md" || echo "MISSING: SKILL.md"

# 6 reference files
for f in quick-validation multi-version snippet-compilation error-recovery archive-compilation full-compilation; do
  test -f "plugins/midnight-mcp/skills/mcp-compile/references/$f.md" && echo "OK: references/$f.md" || echo "MISSING: references/$f.md"
done

# 5 example files
for f in parse-errors type-errors disclosure-errors overflow-errors service-errors; do
  test -f "plugins/midnight-mcp/skills/mcp-compile/examples/$f.md" && echo "OK: examples/$f.md" || echo "MISSING: examples/$f.md"
done
```

All 12 files must show "OK".

- [ ] **Step 2: Verify SKILL.md references**

Confirm every reference file path in the SKILL.md routing table exists:

```bash
grep -oP 'references/[a-z-]+\.md' plugins/midnight-mcp/skills/mcp-compile/SKILL.md | sort -u | while read ref; do
  test -f "plugins/midnight-mcp/skills/mcp-compile/$ref" && echo "OK: $ref" || echo "BROKEN: $ref"
done
```

- [ ] **Step 3: Verify error-recovery routes to example files**

Confirm every example file path in `references/error-recovery.md` exists:

```bash
grep -oP 'examples/[a-z-]+\.md' plugins/midnight-mcp/skills/mcp-compile/references/error-recovery.md | while read ex; do
  test -f "plugins/midnight-mcp/skills/mcp-compile/$ex" && echo "OK: $ex" || echo "BROKEN: $ex"
done
```

- [ ] **Step 4: Verify example file structure**

Each example file must have:
- `# [Category] Examples` heading
- `## When This Error Occurs` section
- `## Examples` section with at least 2 `### ` subsections
- `## Anti-Patterns` section with at least 2 `### ` subsections

```bash
for f in plugins/midnight-mcp/skills/mcp-compile/examples/*.md; do
  name=$(basename "$f")
  subsections=$(grep -c '^### ' "$f" 2>/dev/null || echo 0)
  has_when=$(grep -c '## When This Error Occurs' "$f" 2>/dev/null || echo 0)
  has_anti=$(grep -c '## Anti-Patterns' "$f" 2>/dev/null || echo 0)
  if [ "$has_when" -ge 1 ] && [ "$has_anti" -ge 1 ] && [ "$subsections" -ge 4 ]; then
    echo "OK: $name ($subsections subsections)"
  else
    echo "CHECK: $name (when=$has_when, anti=$has_anti, subsections=$subsections)"
  fi
done
```

- [ ] **Step 5: Verify mcp-analyze was updated correctly**

```bash
# Should NOT contain compile trigger words
grep -c "midnight-compile-contract\|midnight-compile-archive\|compiling a contract\|MCP compile\|compiling an archive" plugins/midnight-mcp/skills/mcp-analyze/SKILL.md
# Expected: 0 (or very small number if cross-reference mentions the tool name)

# Should contain cross-reference to mcp-compile
grep -c "mcp-compile" plugins/midnight-mcp/skills/mcp-analyze/SKILL.md
# Expected: >= 1

# Should say "Five tools" not "Seven tools"
grep -c "Five tools" plugins/midnight-mcp/skills/mcp-analyze/SKILL.md
# Expected: 1
```

- [ ] **Step 6: Final commit if any fixes were made**

If any verification steps revealed issues that were fixed:

```bash
git add -A plugins/midnight-mcp/
git commit -m "fix(mcp-compile): address integration verification findings"
```

- [ ] **Step 7: Summary**

Report:
- Total files created (12)
- Files modified (1 — `mcp-analyze/SKILL.md`)
- Any issues found and fixed during verification
- Any remaining concerns
