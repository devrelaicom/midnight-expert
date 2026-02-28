# Design: compact-witness-ts Skill

**Date:** 2026-02-28
**Plugin:** compact-core
**Status:** Approved

## Problem

Every Compact contract requires TypeScript witness implementations, yet the existing compact-core skills repeatedly say "implementation goes in TypeScript" without explaining how. The six existing skills (compact-structure, compact-ledger, compact-privacy-disclosure, compact-standard-library, compact-tokens, compact-language-ref) cover the Compact side exclusively. The TypeScript side — which is half of every contract — has no skill coverage.

## Scope

**In scope:**
- Writing witness functions in TypeScript (WitnessContext pattern, return tuples)
- Private state management (types, factory functions, state transitions)
- Compiler-generated .d.ts files (Witnesses interface, Circuits type, Contract class)
- Type mappings (Compact → TypeScript)
- The Compact JavaScript runtime (Contract class, pureCircuits, ledger())

**Out of scope:**
- DApp infrastructure (wallet setup, providers, proof server, indexer)
- Contract deployment and interaction (deployContract, findDeployedContract, callTx)
- Network configuration and wallet SDKs
- These would be a separate future skill

## Approach: Contract-Out

Organized by developer workflow: you compiled your Compact contract, now what?

1. Compiler output → 2. Type mappings → 3. Witness implementation → 4. Contract runtime

This mirrors the natural developer journey and avoids duplicating the pattern-heavy approach already in compact-structure.

## Skill Identity

- **Name:** `compact-witness-ts`
- **Location:** `plugins/compact-core/skills/compact-witness-ts/`
- **Trigger description:** Covers TypeScript witness implementation, WitnessContext pattern, private state management, Compact-to-TypeScript type mappings, compiler-generated .d.ts files, Contract class, pure circuits, and ledger reading

## File Structure

```
plugins/compact-core/skills/compact-witness-ts/
├── SKILL.md
└── references/
    ├── type-mappings.md
    ├── witness-implementation.md
    └── contract-runtime.md
```

## SKILL.md Content

1. **Opening paragraph** — One sentence positioning the skill
2. **Compiler Output Overview** — What `compact compile` produces, key exports, import patterns
3. **Type Mapping Quick Reference** — Inline table of all Compact → TypeScript type mappings
4. **Witness Implementation Pattern** — Core WitnessContext pattern with concrete example
5. **Private State Design** — Brief coverage of private state types and factory functions
6. **Contract Class Usage** — Instantiation, pureCircuits, ledger reading
7. **Reference Routing Table** — Links to the three reference files

Cross-references to: compact-structure, compact-privacy-disclosure, compact-standard-library.

## Reference Files

### type-mappings.md

- Complete Compact → TypeScript type mapping table (expanded)
- CompactType<T> interface for runtime type validation
- Runtime bounds/length checking behavior
- Type casting patterns between Compact and TypeScript
- Generic type export rules (numeric params dropped)
- Maybe<T>, Either<L, R> representation
- Opaque<"string">, Opaque<"Uint8Array"> pass-through types
- Ledger ADT representation via ledger() function
- MerkleTreePath<N, T> representation for witness providers

### witness-implementation.md

- WitnessContext<L, PS> interface: ledger, privateState, contractAddress fields
- Witness return tuple [PS, ReturnType] — why it returns new private state
- Immutable private state pattern
- Private state mutation via spread-and-override
- Common witness patterns:
  - Secret key provider
  - Parameterized witness (circuit arguments after WitnessContext)
  - State-mutating witness
  - Ledger-reading witness
  - Contract-address-keyed state
- Side-effect-only witnesses returning []
- Error handling in witnesses
- The witnesses object: keys must match Compact names exactly

### contract-runtime.md

- Compiler-generated Contract class: constructor, circuits, impureCircuits, pureCircuits
- circuits vs impureCircuits distinction
- pureCircuits: local computation without proof
- The ledger() function: parsing contract state
- Contract instantiation patterns
- Witnesses interface type-checking
- Circuits type signatures
- Private state ID string identifier
- Re-export pattern (index.ts)

## Plugin Integration

Add keywords to plugin.json: `"witness-typescript"`, `"WitnessContext"`, `"private-state"`, `"type-mapping"`, `"compact-runtime"`, `"contract-class"`, `"pureCircuits"`, `"compiler-generated"`

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Witness & runtime only, no DApp infra | Focused scope; DApp infra is a separate concern |
| Inline examples only | Type mappings and patterns shown best as annotated snippets |
| Complement existing skills, no duplication | Avoids redundancy with compact-structure's Compact-side coverage |
| 3 reference files | Clean separation: types, witnesses, runtime |
| Contract-Out approach | Follows natural developer workflow post-compilation |

## Research Sources

- Official Midnight docs: bboard tutorial (witness implementation, contract types)
- Compiler documentation: .d.ts file structure, type translation rules
- Example DApps: counter (empty witnesses), bboard (secret key pattern), midnames (multi-key pattern), midnight-bank (parameterized witnesses), naval-battle (state-mutating witnesses)
- Compact runtime source: WitnessContext interface definition
- OpenZeppelin compact-contracts: empty witness patterns
- Language reference: type representation rules, generic export rules
