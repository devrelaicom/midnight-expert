---
name: mcp-compile
version: 1.0.0
description: This skill should be used when the user asks about compiling Compact code via MCP, hosted compilation, midnight-compile-contract, midnight-compile-archive, MCP compile, snippet compilation, multi-version compilation, compile errors from MCP, code auto-wrapping, testing backwards compatibility across Compact versions, OpenZeppelin library linking in MCP compilation, interpreting hosted compiler responses, quick validation, check if code compiles, full ZK compilation via MCP, circuit metrics, k-values, or TypeScript bindings from MCP.
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
| `midnight-compile-contract` | Compile single-file Compact code with hosted compiler (default: `skipZk=true`) | Quick validation, snippet testing, multi-version compat |
| `midnight-compile-archive` | Compile multi-file projects via file map | Projects with imports between Compact files, OZ module usage |

## Workflow Routing

Load the reference matching your current task. If compilation fails, also load `references/error-recovery.md`.

| Workflow | Reference | When |
|----------|-----------|------|
| Correct code patterns to aim for | `examples/common-patterns.md` | Writing new code, need correct compilation targets |
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
| Analysis, visualization, diffing | `mcp-analyze` |
| Compact code formatting via MCP | `mcp-format` |
| Tool routing and category overview | `mcp-overview` |
| Verification methodology using compilation | `compact-core:verify-correctness` |
