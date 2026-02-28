# Design: compact-language-ref skill

**Date**: 2026-02-26
**Plugin**: compact-core
**Approach**: Standalone skill (no changes to compact-structure)

## Purpose

Comprehensive Compact language mechanics reference covering the foundational knowledge needed to write correct Compact code — types, operators, expressions, control flow, modules, and stdlib functions. Independent of contract architecture or domain patterns.

## Rationale

The existing `compact-structure` skill covers contract anatomy (pragma, imports, ledger, circuits, witnesses, constructor, exports). It includes a quick-reference types table but doesn't go deep on language mechanics.

Developers need to understand the mechanical language details (casting rules, arithmetic behavior, control flow constraints, module system) before they can implement higher-level patterns. This skill fills that gap.

## Approach

Build `compact-language-ref` as a standalone skill within the existing `compact-core` plugin. No changes to `compact-structure`. Minor overlap in type coverage is acceptable — `compact-structure` keeps its quick-reference table for contract layout context, this skill goes deep on language mechanics.

## Skill structure

```
plugins/compact-core/skills/compact-language-ref/
├── SKILL.md                                    # ~1,500-2,000 words
└── references/
    ├── types-and-values.md                     # All types in depth
    ├── operators-and-expressions.md            # Arithmetic, comparison, casting
    ├── control-flow.md                         # if/else, for loops, const
    ├── modules-and-imports.md                  # pragma, import, include, export
    ├── stdlib-functions.md                     # Complete stdlib API (positive ref)
    └── troubleshooting.md                      # Non-existent functions, compiler errors, wrong->correct
```

## SKILL.md content (~1,500-2,000 words)

- Trigger description covering: "Compact types", "type casting", "Compact operators", "arithmetic in Compact", "control flow", "if/else", "for loop", "module system", "include files", "stdlib functions", "Compact syntax", "Compact language reference"
- Quick-reference tables for types, operators, and casting
- Control flow summary
- Module system basics
- Routing table to all 6 reference files

## Reference file details

### types-and-values.md
- Primitive types: Field, Boolean, Bytes<N>, Uint<N>
- Uint<N> / Uint<0..MAX> equivalence (same type family)
- Opaque<"string"> and Opaque<"Uint8Array"> — semantics and limitations
- Collection types: Vector<N,T>, Maybe<T>, Either<L,R>
- Ledger ADT types: Counter, Map, Set, List, MerkleTree, HistoricMerkleTree
- Custom types: enum declaration, struct declaration
- Construction syntax for structs and enums
- Field access (dot notation for structs, .is_some/.value for Maybe, etc.)
- Default values via default<T>()

### operators-and-expressions.md
- Arithmetic: +, -, * only (no division, no modulo)
- Bounded type expansion from arithmetic (Uint<64> + Uint<64> -> wider bounded type)
- Required cast-back: (a + b) as Uint<64>
- Subtraction runtime failure if result negative
- Comparison operators: ==, !=, <, <=, >, >=
- Boolean operators: &&, ||, !
- Type cast expressions: `expression as Type`
- Complete cast path table (safe, checked, multi-step)
- Multi-step casts: Uint->Bytes via Field, Boolean->Field via Uint

### control-flow.md
- if/else branching
- for loops over numeric ranges: `for (const i of 0 .. 10)`
- for loops over array literals: `for (const item of [3, 2, 1])`
- Compile-time loop bound constraints (circuits have fixed computational bounds)
- Variable declarations with const (no let/var)
- No while loops, no recursion (ZK circuit constraints)

### modules-and-imports.md
- pragma language_version syntax (bounded range, no patch version)
- import CompactStandardLibrary
- include directive for splitting contracts across files
- export for ledger fields, circuits, enums, structs
- Re-exporting stdlib types: export { Maybe, Either }
- File organization patterns for larger contracts

### stdlib-functions.md (positive reference only)
- persistentHash<T>(value: T): Bytes<32> — Poseidon hash, consistent across calls
- persistentCommit<T>(value: T): Bytes<32> — hiding commitment
- transientHash<T>(value: T): Field — hash for non-stored values (note: returns Field, not Bytes<32>)
- transientCommit<T>(value: T, rand: Field): Field — commitment for non-stored values
- pad(length, value): Bytes<N> — pad string to fixed-length bytes
- disclose(value: T): T — explicitly reveal a value on-chain
- assert(condition, message?): [] — fail circuit if condition false
- default<T>(): T — default value for a type
- When to use persistent vs transient variants

### troubleshooting.md
- Functions that do NOT exist: public_key(), verify_signature(), random()
- Correct alternatives for each non-existent function
- Common compiler error messages mapped to causes and fixes
- Wrong->correct syntax mappings (all from MCP syntax reference)
- Type error resolution guide

## Data sources

- Midnight MCP `midnight-get-latest-syntax` — authoritative syntax reference, common mistakes, compiler errors
- Midnight MCP `midnight-search-compact` — real-world code examples from Midnight repos
- Midnight MCP `midnight-fetch-docs` — official docs pages for language reference
- WebFetch of raw docs from midnightntwrk/midnight-docs repo

## Non-goals

- Contract architecture/anatomy (covered by compact-structure)
- Privacy patterns, token patterns, access control (future skills)
- TypeScript DApp integration (future skill)
- Compact CLI tooling (covered by midnight-tooling plugin)
