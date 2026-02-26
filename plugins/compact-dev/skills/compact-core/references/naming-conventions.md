---
title: Naming Conventions
type: concept
description: Compact follows strict naming conventions — camelCase for circuits and witnesses, PascalCase for types and modules, kebab-case for files.
links:
  - circuit-declarations
  - witness-functions
  - compact-to-typescript-types
  - contract-file-layout
  - export-and-visibility
---

# Naming Conventions

Compact enforces conventions by community practice and tooling warnings. Following them ensures generated TypeScript code has idiomatic names and that the [[contract-file-layout]] reads naturally.

## Convention Table

| Element | Convention | Example |
|---------|-----------|---------|
| Circuit names | camelCase | `transferTokens`, `castVote` |
| Witness names | camelCase | `getCaller`, `fetchBalance` |
| Struct names | PascalCase | `UserRecord`, `VoteData` |
| Enum names | PascalCase | `Status`, `TokenAction` |
| Enum variants | PascalCase | `Status.Active`, `Status.Pending` |
| Module names | PascalCase | `TokenLogic`, `AccessControl` |
| Ledger fields | camelCase | `totalSupply`, `memberCount` |
| Constants | camelCase or UPPER_SNAKE | `maxUsers` or `MAX_USERS` |
| File names | kebab-case | `my-contract.compact` |
| Type parameters | Single uppercase | `T`, `A`, `B` |
| Numeric params | Hash prefix | `#n`, `#depth` |

Circuits and witnesses share the camelCase convention because they are called with the same syntax in [[circuit-declarations]], even though their implementations differ as described in [[witness-functions]]. Struct and enum names use PascalCase to visually distinguish types from values, which aligns with the TypeScript output where these become TypeScript interfaces — see [[compact-to-typescript-types]] for the full mapping.

Enum variant access uses dot notation (`Status.Active`), never the Rust-style double colon (`Status::Active`). Using `::` is a static analysis error flagged by the Midnight MCP's deprecation checker, and it is one of the most common syntax mistakes from developers with Rust experience.
