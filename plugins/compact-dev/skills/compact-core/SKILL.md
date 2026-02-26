---
name: compact-core
description: Use when writing, reviewing, or debugging Compact smart contracts for the Midnight Network, encountering ZK circuit constraints, privacy disclosure errors, ledger state design decisions, or needing Compact language syntax and patterns
---

# Compact Language Reference

Compact is the domain-specific language for zero-knowledge smart contracts on the Midnight Network. This skill provides a navigable knowledge graph covering the full language: types, circuits, witnesses, ledger ADTs, privacy model, tokens, and common patterns.

## How to Use This Reference

### Start at the Map of Content

Read `references/compact-language-moc.md` first. It is the central hub that organizes all 45 reference files into sections: Core Language, Circuits and Witnesses, Ledger State, Privacy Model, Tokens, Standard Library, Patterns, and Gotchas.

### Navigate via Wikilinks

Reference files use `[[wikilinks]]` to cross-reference each other. Each wikilink maps directly to a filename in the `references/` directory:

- `[[type-system]]` → read `references/type-system.md`
- `[[persistent-hash-is-not-safe]]` → read `references/persistent-hash-is-not-safe.md`
- `[[cell-and-counter]]` → read `references/cell-and-counter.md`

Every reference file also has YAML frontmatter with a `links:` array listing its direct connections. Use these to find related topics without returning to the MoC.

### When to Read Linked Files

**Read immediately** when:
- The linked topic is directly needed to answer the user's question
- A gotcha link appears in code you're writing or reviewing (e.g., `[[persistent-hash-is-not-safe]]`, `[[both-branches-execute]]`, `[[send-result-change-handling]]`)
- You're about to use a feature described in the link (e.g., read `[[merkle-trees]]` before writing MerkleTree code)
- The compiler error you're debugging is explained by a linked file (e.g., `[[disclosure-compiler-error]]`, `[[void-is-not-a-return-type]]`)

**Read on demand** when:
- The link provides background context you already understand
- The link covers an ADT or pattern not relevant to the current task
- The information in the current file is sufficient

**Typical navigation depth:** Start at MoC → read 1-3 topic files relevant to the task → follow 1-2 wikilinks from those files when you hit a concept you need. Most tasks require 2-4 files total, not all 45.

## Quick Lookup by Task

| Task | Start Here |
|------|-----------|
| Write a new contract | `[[contract-file-layout]]`, `[[pragma-and-imports]]` |
| Choose ledger state types | `[[ledger-state-design]]` (has decision tree) |
| Write a circuit | `[[circuit-declarations]]`, `[[pure-vs-impure-circuits]]` |
| Implement witness functions | `[[witness-functions]]`, `[[witness-context-object]]` |
| Fix disclosure compiler error | `[[disclosure-compiler-error]]`, `[[witness-value-tracking]]` |
| Handle privacy correctly | `[[transient-vs-persistent]]`, `[[disclosure-model]]` |
| Work with tokens | `[[token-operations]]`, `[[coin-lifecycle]]` |
| Type mapping to TypeScript | `[[compact-to-typescript-types]]` |
| Common contract patterns | `[[commit-reveal-pattern]]`, `[[access-control-pattern]]`, `[[state-machine-pattern]]` |
| Start from a template | `[[starter-contract-templates]]` |

## Reference File Types

Each file's frontmatter includes a `type` field:

- **concept** — Core language feature or design principle
- **gotcha** — Common mistake that causes bugs or privacy leaks; always read these when relevant
- **pattern** — Proven contract design pattern with code examples
- **moc** — Map of Content (navigation hub)

## Critical Gotchas

Always check these when writing Compact code:

1. **`[[persistent-hash-is-not-safe]]`** — Using `persistentHash` on private witness data leaks information
2. **`[[both-branches-execute]]`** — Both sides of if-else evaluate in ZK circuits; side effects happen regardless of condition
3. **`[[send-result-change-handling]]`** — Ignoring change from token sends silently burns funds
4. **`[[disclosure-compiler-error]]`** — How to read "potential witness-value disclosure" errors
5. **`[[void-is-not-a-return-type]]`** — Use `[]` not `Void` for circuits that return nothing
6. **`[[no-unbounded-loops]]`** — All iteration must be bounded at compile time
