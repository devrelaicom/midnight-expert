# MCP Compile Skill — Design Specification

**Date:** 2026-03-19
**Plugin:** `midnight-mcp`
**Skill:** `mcp-compile` (new, extracted from `mcp-analyze`)
**Status:** Draft

## Problem

The `mcp-analyze` skill bundles 7 tools into a single flat reference. Compilation (`midnight-compile-contract`, `midnight-compile-archive`) is one of the most important capabilities the MCP server offers, but it's buried alongside analysis, visualization, formatting, and diffing tools. The existing compile documentation is also substantially inaccurate — listing wrong parameter names, missing parameters entirely, and omitting critical features like snippet auto-wrapping, multi-version compilation, OZ library linking, and structured error responses.

## Goals

1. Extract MCP-hosted compilation into its own dedicated skill with accurate, comprehensive documentation
2. Provide workflow-oriented references that guide the LLM through common compilation tasks
3. Include error example files for the high-value error interpretation workflow
4. Bail out early when local compilation is the better choice, saving LLM context
5. Update `mcp-analyze` to remove compile tools and cross-reference the new skill

## Non-Goals

- Redesigning `mcp-analyze` beyond removing compile tools (future work)
- Extracting format into its own skill (future work)
- Adding a slash command (deferred — the MCP tools are the direct interface)
- Documenting local CLI compilation (owned by `compact-core:compact-compilation`)
- Changing the MCP server or playground

## Architecture

### Bail-Out Gate

The SKILL.md starts with a decision table evaluated before anything else. If the LLM's task matches a "use local instead" condition, it stops loading this skill and routes to the appropriate local compilation skill. This prevents wasting context on MCP compilation guidance when local is the right tool.

### Workflow-Oriented References

Each reference is a self-contained playbook for one compilation workflow. The LLM loads only the reference matching its current task. References include inline examples for parameter usage and response interpretation.

### Error Example Files

Error interpretation is the one workflow with separate example files. The error recovery reference routes to specific example files by error pattern. Each example file covers one error category with before/after pairs (error message + bad code → diagnosis + fixed code) and anti-patterns.

### Consumer

The primary consumer is the LLM. All content is written as concise operational instructions.

### Boundary with Other Skills

- `mcp-compile` owns: MCP-hosted compilation workflows, parameter guidance, response interpretation, error recovery via MCP tools
- `compact-core:compact-compilation` owns: local CLI compilation, artifact structure (ZKIR, keys, TS bindings), deep error catalog, development workflow with local tools
- `mcp-analyze` retains: analysis, visualization, proving, formatting, diffing tools

The compile skill cross-references `compact-core:compact-compilation` for deep error categories and artifact documentation. It does not duplicate that content.

## MCP Tool Parameters (Actual)

Source: `/Users/aaronbassett/Projects/midnight/midnight-mcp/src/tools/analyze/schemas.ts`

### `midnight-compile-contract`

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `code` | string | Yes | — | Compact source code to compile |
| `skipZk` | boolean | No | `true` | Skip ZK circuit generation for fast syntax-only validation. Overridden by `fullCompile`. |
| `fullCompile` | boolean | No | `false` | Full compilation with ZK generation. Overrides `skipZk`. |
| `version` | string | No | — | Compiler version (e.g., `"0.29.0"`) or `"detect"` for pragma-based resolution |
| `versions` | string[] | No | — | Multi-version compilation in parallel (max 10). E.g., `["latest", "0.26.0", "detect"]` |
| `includeBindings` | boolean | No | `false` | Return TypeScript artifacts. Forces full ZK compilation. |
| `libraries` | string[] | No | — | OpenZeppelin modules to link (max 20). E.g., `["access/Ownable", "token/FungibleToken"]` |

### `midnight-compile-archive`

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `files` | Record<string, string> | Yes | — | Map of relative file paths to source code. Keys preserve directory structure for import resolution. |
| `version` | string | No | — | Compiler version |
| `versions` | string[] | No | — | Multi-version compilation |
| `options.skipZk` | boolean | No | `true` | Skip ZK generation |
| `options.includeBindings` | boolean | No | `false` | Include TypeScript artifacts |
| `options.libraries` | string[] | No | — | OZ modules to link (max 20) |

### Response Structure

**Single-version compile response:**

```
{
  success: boolean,
  output: string,                    // "Compilation successful" or error summary
  compilationMode: "syntax-only" | "full",
  compilerVersion: string,           // Resolved compiler version used
  errors: CompilerError[],           // If failed
  warnings: CompilerError[],         // If succeeded with warnings
  executionTime: number,             // Milliseconds
  compiledAt: string,                // ISO 8601 timestamp
  originalCode: string,              // Original code (if auto-wrapped)
  wrappedCode: string,               // Code after wrapper additions (if auto-wrapped)
  // Additional fields when fullCompile or includeBindings:
  bindings: Record<string, string>,  // TypeScript artifacts
  insights: CompilerInsights         // Circuit metrics
}
```

**CompilerError:**
```
{
  message: string,
  severity: "error" | "warning" | "info",
  file: string,       // Optional
  line: number,        // Optional, 1-based
  column: number       // Optional, 1-based
}
```

**CompilerInsights** (full ZK compilation only):
```
{
  circuitCount: number,
  circuits: [{ name: string, k: number, rows: number }],
  usesZkProofs: boolean
}
```

**Multi-version response:** Array of results, each with an additional `requestedVersion` field.

### Snippet Auto-Wrapping

The playground automatically wraps incomplete code snippets:
- If code has no `pragma language_version` → adds `pragma language_version >= 0.14;`
- If code has no `import CompactStandardLibrary` → adds the import
- Line offset: errors in wrapped code report line numbers offset by 2-4 lines depending on what was added

Snippet types detected: `complete` (has pragma), `circuit` (starts with circuit/export circuit), `ledger` (starts with ledger/export ledger/struct/enum), `unknown` (everything else).

### Rate Limits

| Endpoint | Limit | Window |
|----------|-------|--------|
| `/compile` | 20 requests | 60 seconds |
| `/compile/archive` | 10 requests | 60 seconds |

### OpenZeppelin Library Linking

Available domains: `access`, `security`, `token`, `utils`.

Library format: `"domain/ModuleName"` (e.g., `"access/Ownable"`, `"token/FungibleToken"`).

Libraries are statically linked from the playground's pre-installed OZ modules. Transitive dependencies across domains are resolved automatically. Max 20 libraries per request.

## SKILL.md Structure

### 1. Bail-Out Decision (top of file)

Evaluated immediately. If any condition matches, the LLM stops loading this skill.

| Condition | Use Instead |
|-----------|-------------|
| Project has local npm-installed Compact dependencies being imported | `compact-core:compact-compilation` |
| Need full artifact tree on disk (ZKIR, keys, TS bindings as files) | `compact-core:compact-compilation` |
| Bulk/automated compilation (hundreds+ of contracts) | `compact-core:compact-compilation` |
| CI/CD pipeline compilation | `compact-core:compact-compilation` + `midnight-tooling:compact-cli` |
| Need custom compiler flags not exposed by the MCP tool | `compact-core:compact-compilation` |

### 2. Tool Summary

| Tool | What It Does | When to Use |
|------|-------------|-------------|
| `midnight-compile-contract` | Compile single-file Compact code with hosted compiler | Quick validation, snippet testing, multi-version compat |
| `midnight-compile-archive` | Compile multi-file projects via file map | Projects with imports between Compact files, OZ module usage |

### 3. Workflow Routing Table

| Workflow | Reference | When |
|----------|-----------|------|
| Quick syntax/type check | `references/quick-validation.md` | LLM wrote or modified code, needs fast feedback |
| Test across compiler versions | `references/multi-version.md` | Backwards/forwards compatibility without changing local toolchain |
| Compile a code snippet | `references/snippet-compilation.md` | Incomplete code fragments, not full contracts |
| Interpret and recover from errors | `references/error-recovery.md` | Compilation failed, need to diagnose and fix |
| Multi-file project compilation | `references/archive-compilation.md` | Project with imports between files or OZ libraries |
| Full ZK compilation with artifacts | `references/full-compilation.md` | Pre-deployment validation, circuit metrics, TypeScript bindings |

### 4. Trusted Sources and Cross-References

Cross-reference table linking to `compact-core:compact-compilation`, `compact-core:compact-standard-library`, `mcp-analyze`, `mcp-overview`.

## Reference File Details

### `references/quick-validation.md`

The most common workflow. LLM wrote or modified Compact code and needs to check if it compiles.

Content:
- Default parameters: `code` + `skipZk: true` (already the default)
- When to use `version: "detect"` (project has a `pragma language_version`)
- Interpreting success: `success: true`, `compilationMode: "syntax-only"`, `executionTime`
- Interpreting failure: reading `errors[]` with `message`, `line`, `column`, `severity`
- The fix-and-recompile loop: diagnose error → fix all reported errors → recompile once (don't rapid-fire recompiles)
- Rate limit awareness: 20 calls per 60 seconds — budget your recompiles
- Inline example: minimal compile call and response

### `references/multi-version.md`

Testing the same code against multiple compiler versions simultaneously.

Content:
- Using the `versions` array: `["latest", "0.28.0", "detect"]`
- Special version values: `"latest"` (newest installed), `"detect"` (pragma-based), specific version strings
- Maximum 10 versions per request
- Interpreting multi-version results: each version returns a separate result object with `requestedVersion`
- Common use cases: backwards compat check, forward compat check without upgrading local toolchain, finding which version introduced a breaking change
- Inline example: multi-version call with per-version result interpretation

### `references/snippet-compilation.md`

Compiling incomplete code fragments that aren't full contracts.

Content:
- How auto-wrapping works: adds `pragma language_version >= 0.14;` and `import CompactStandardLibrary;` when missing
- Snippet type detection: complete, circuit, ledger, expression, unknown
- Line offset adjustment: wrapper adds 2-4 lines — error line numbers need adjustment. Document the offset rules:
  - Has pragma: 0 lines added
  - Missing pragma, has stdlib import: 2 lines added
  - Missing both pragma and import: 4 lines added
- When wrapping happens vs doesn't (code with `pragma` is sent as-is)
- Limitations: auto-wrapping can't fix missing context (referenced types, ledger fields)
- Inline examples: bare circuit snippet → what the wrapper adds → how to read error line numbers

### `references/error-recovery.md`

The routing hub for error interpretation. Routes to specific error example files.

Content:
- Reading the `CompilerError` structure: `message`, `severity`, `file`, `line`, `column`
- Error category detection: pattern matching on the error message text
- The recovery loop: diagnose → fix all errors → recompile → verify (max 2-3 attempts before asking the user)
- Line number adjustment for wrapped snippets (cross-ref to `references/snippet-compilation.md`)
- Routing table to error example files:

| Error Pattern | Example File |
|---------------|-------------|
| "expected ... but found ..." | `examples/parse-errors.md` |
| "no matching overload" | `examples/type-errors.md` |
| "potential witness-value disclosure must be declared" | `examples/disclosure-errors.md` |
| Integer overflow, field modulus | `examples/overflow-errors.md` |
| 429, timeout, 5xx, service unavailable | `examples/service-errors.md` |

- Cross-reference to `compact-core:compact-compilation` references/compiler-errors.md for the full error catalog
- Guidance: load example file only for the error category you're seeing

### `references/archive-compilation.md`

Multi-file project compilation.

Content:
- Structuring the `files` map: keys are relative paths, directory structure preserved for import resolution
- Example: `{ "src/main.compact": "...", "src/lib/utils.compact": "..." }`
- OZ library linking via `options.libraries`: format `["domain/ModuleName"]`, available domains: `access`, `security`, `token`, `utils`
- Max 20 libraries per request
- Transitive dependency resolution: cross-domain OZ imports resolved automatically
- When to use archive vs single-file (multiple `.compact` files importing from each other)
- Rate limit: 10 requests per 60 seconds (stricter than single-file)
- Inline example: multi-file project with OZ imports

### `references/full-compilation.md`

Full ZK compilation for pre-deployment validation and artifact generation.

Content:
- `fullCompile: true` — generates ZK circuit artifacts, prover/verifier keys
- `includeBindings: true` — returns TypeScript artifacts in the response (forces full compilation)
- Interpreting `CompilerInsights`: `circuitCount`, per-circuit `name`, `k`, `rows`
- What k-value means: evaluation domain size = 2^k, larger = slower proving, each increment roughly doubles computation
- What rows means: constraint rows used, must be <= 2^k
- Execution time expectations: 10-30s for full compilation vs 1-2s for syntax-only
- When to use: before deployment, when circuit metrics matter, when you need to verify proof generation works
- Note: for full artifact tree on disk, use local compilation (`compact-core:compact-compilation`)
- Cross-reference to `compact-core:compact-compilation` for ZKIR format and key structure details

## Error Example Files

Each file follows the template:

```markdown
# [Error Category] Examples

## When This Error Occurs
One-line description of when the LLM will encounter this error category.

## Examples

### [Concrete scenario label]

**Error:**
[The compiler error message as returned in CompilerError.message]

**Code that caused it:**
[The Compact code that triggered the error]

**Diagnosis:** [What's wrong and why]

**Fix:**
[The corrected Compact code]

## Anti-Patterns

### [Anti-pattern label]

**Wrong:** [What the LLM might naively do to fix this error]
**Problem:** [Why that fix is wrong]
**Instead:** [What to do]
```

### `examples/parse-errors.md`

5-6 before/after pairs:
- `Void` return type → `[]`
- Double-colon enum access → dot notation
- Deprecated `ledger { }` block → individual `export ledger` declarations
- Witness with implementation body → semicolon-terminated declaration
- `pure function` → `pure circuit`
- Division operator `/` → witness pattern

Anti-patterns (2-3):
- Guessing the fix without reading "expected/found" tokens
- Assuming parse errors are type errors
- Not recognizing deprecated syntax from older Compact versions

### `examples/type-errors.md`

4-5 before/after pairs:
- `Field` + `Uint<N>` without cast → explicit `as Field`
- Arithmetic result expansion (`Uint<0..N>`) → cast back to concrete type
- Direct `Uint` to `Bytes` cast → two-step through `Field`
- Wrong argument type to ADT method → match declared type
- Generic parameter mismatch → check constraints

Anti-patterns (2-3):
- Adding casts everywhere without understanding the type mismatch
- Casting to `Field` as a universal fix
- Ignoring the compiler's overload candidate list

### `examples/disclosure-errors.md`

4-5 before/after pairs:
- Witness value to ledger field → `disclose()`
- Witness value in `if` condition → `disclose()`
- Witness value returned from exported circuit → `disclose()`
- Witness value passed to ADT method → `disclose()` the argument
- Transitive disclosure through intermediate computation → `disclose()` at the public boundary

Anti-patterns (2-3):
- Wrapping every variable in `disclose()` defensively
- Adding `disclose()` on non-witness values
- Not reading the error's "via this path" trace

### `examples/overflow-errors.md`

2-3 before/after pairs:
- Integer literal exceeds field modulus → use smaller values
- Large constant computation overflow → restructure as runtime computation
- `MAX_FIELD` runtime mismatch → version alignment between compiler and runtime

Anti-patterns (2):
- Trying to increase integer size (field modulus is a hard limit)
- Confusing `Uint<N>` max values with field modulus

### `examples/service-errors.md`

2-3 before/after pairs:
- 429 rate limit → wait, batch fixes before recompiling
- Compilation timeout → simplify code or use `skipZk: true`, consider local compilation
- 5xx service unavailable → retry after a few seconds, fall back to local compilation

Anti-patterns (2):
- Rapid-fire recompilation when rate limited
- Assuming service errors mean the code is wrong

## File Inventory

### New Files (12 total)

All paths relative to `plugins/midnight-mcp/`.

**SKILL.md** (1):
- `skills/mcp-compile/SKILL.md`

**Reference files** (6):
- `skills/mcp-compile/references/quick-validation.md`
- `skills/mcp-compile/references/multi-version.md`
- `skills/mcp-compile/references/snippet-compilation.md`
- `skills/mcp-compile/references/error-recovery.md`
- `skills/mcp-compile/references/archive-compilation.md`
- `skills/mcp-compile/references/full-compilation.md`

**Example files** (5):
- `skills/mcp-compile/examples/parse-errors.md`
- `skills/mcp-compile/examples/type-errors.md`
- `skills/mcp-compile/examples/disclosure-errors.md`
- `skills/mcp-compile/examples/overflow-errors.md`
- `skills/mcp-compile/examples/service-errors.md`

### Modified Files (1)

- `skills/mcp-analyze/SKILL.md` — Remove `midnight-compile-contract` and `midnight-compile-archive` sections, update frontmatter description, add cross-reference to `mcp-compile` skill

### External Artifacts

None.
