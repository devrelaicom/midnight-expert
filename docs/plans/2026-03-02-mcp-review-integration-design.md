# MCP Tool Integration for Compact Code Review

**Date:** 2026-03-02
**Status:** Approved
**Scope:** Augment the compact-review skill's 11 reviewer categories with Midnight MCP server tools

## Problem

The compact-review system is entirely LLM-driven. 11 reviewer agents each load a static checklist, read code, and apply judgment. None use the Midnight MCP server's analysis tools (compilation, structural analysis, syntax validation, semantic search). This means:

- Compilation issues are caught by pattern-matching, not actual compilation
- Structural problems are identified by eyeballing, not machine analysis
- Syntax correctness is checked against memorized rules, not the authoritative syntax reference
- No cross-reference with official docs or reference implementations

## Solution

Augment the existing checklist-driven review with MCP tool evidence using an "advisory + required" approach:

1. **Shared pre-pass** in the orchestrating command runs 4 MCP tools once and injects outputs into all reviewer prompts
2. **Per-category required tools** listed in each reference file for category-specific analysis
3. **Inline tool hints** on checklist items where MCP tools can verify findings

## Architecture

### Two-Phase Tool Integration

```
Phase 1: Orchestrator Pre-Pass (review-compact command)
  ├── midnight-compile-contract (skipZk=true)
  ├── midnight-extract-contract-structure
  ├── midnight-analyze-contract
  └── midnight-get-latest-syntax
  → Outputs injected into all 11 reviewer prompts

Phase 2: Reviewer Execution (per-category)
  ├── Reference shared evidence from prompt
  ├── Run category-specific required tools (if any)
  ├── Apply checklist with inline tool hints (advisory)
  └── Report findings with tool-backed evidence
```

### Tool-to-Category Mapping

All categories receive shared evidence from the pre-pass. Additional category-specific tools:

| Category | Required (category-specific) | Advisory Hints |
|----------|------------------------------|----------------|
| Privacy & Disclosure | — | explain-circuit, search-docs |
| Security & Cryptographic Correctness | — | search-compact, search-docs |
| Token & Economic Security | — | search-compact, list-examples |
| Concurrency & Contention | — | search-docs |
| Compilation & Type Safety | — | search-compact |
| Performance & Circuit Efficiency | compile-contract (fullCompile=true) | explain-circuit, search-docs |
| Witness-Contract Consistency | — | search-compact, search-docs |
| Architecture, State Design | — | list-examples, search-compact |
| Code Quality & Best Practices | — | search-compact, list-examples |
| Testing Adequacy | — | list-examples, search-docs |
| Documentation | — | search-docs |

### Reference File Format

Each reference file gets three additions:

**1. Required MCP Tools section** (after intro, before first checklist):

```markdown
## Required MCP Tools

Run these tools before starting your review. Reference their output when evaluating checklist items.

| Tool | Label | Purpose |
|------|-------|---------|
| `midnight-compile-contract` | `[shared]` | Compilation errors and warnings |
| `midnight-extract-contract-structure` | `[shared]` | Deprecated syntax, structural issues |
| `midnight-analyze-contract` | `[shared]` | Static pattern analysis |
| `midnight-get-latest-syntax` | `[shared]` | Authoritative syntax reference |

Tools marked `[shared]` are pre-run by the orchestrator — their output is in your prompt.
Tools marked `[category-specific]` must be run by you during your review.
```

**2. Inline tool hints** on applicable checklist items:

```markdown
- [ ] **Checklist item title**
  [existing description unchanged]

  > **Tool:** `midnight-compile-contract` output will show `error message` if present.
```

**3. Tool Reference footer:**

```markdown
## Tool Reference

| Tool | Description |
|------|-------------|
| `midnight-compile-contract` | Compile contract; skipZk=true for syntax, fullCompile=true for ZK |
| `midnight-extract-contract-structure` | Deep structural analysis: deprecated syntax, missing disclose(), etc. |
| ... | ... |
```

## File Changes

### Modified Files (13 total)

1. **`commands/review-compact.md`** — Add Step 2.5 (shared MCP pre-pass), update reviewer prompt templates
2. **`agents/reviewer.md`** — Add MCP tool awareness, evidence reference step, advisory hint guidance
3. **`references/privacy-review.md`** — Required MCP Tools section, inline hints, footer
4. **`references/security-review.md`** — Required MCP Tools section, inline hints, footer
5. **`references/token-security-review.md`** — Required MCP Tools section, inline hints, footer
6. **`references/concurrency-review.md`** — Required MCP Tools section, inline hints, footer
7. **`references/compilation-review.md`** — Required MCP Tools section, inline hints, footer
8. **`references/performance-review.md`** — Required MCP Tools section, inline hints, category-specific tool, footer
9. **`references/witness-consistency-review.md`** — Required MCP Tools section, inline hints, footer
10. **`references/architecture-review.md`** — Required MCP Tools section, inline hints, footer
11. **`references/code-quality-review.md`** — Required MCP Tools section, inline hints, footer
12. **`references/testing-review.md`** — Required MCP Tools section, inline hints, footer
13. **`references/documentation-review.md`** — Required MCP Tools section, inline hints, footer

### Unchanged Files

- `SKILL.md` — category map, severity classification, output format stay as-is
- `plugin.json` — no structural changes needed

## Design Decisions

1. **Augment, don't replace** — LLM checklist review remains the core; MCP tools provide evidence
2. **Shared pre-pass** — 4 common tools run once by orchestrator instead of 11x by each reviewer
3. **Per-category references** — Tool guidance lives in each reference file, not centrally
4. **Advisory + required** — Required tools must run; advisory hints are contextual suggestions
5. **`[shared]` vs `[category-specific]` labels** — Reviewers know which tools are pre-computed vs need to run
