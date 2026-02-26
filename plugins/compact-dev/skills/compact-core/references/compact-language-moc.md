---
title: Compact Language Map of Content
type: moc
description: Central navigation hub for all Compact language knowledge — the ZK smart contract language for the Midnight Network.
links:
  - type-system
  - bounded-computation
  - pragma-and-imports
  - contract-file-layout
  - export-and-visibility
  - naming-conventions
  - compact-to-typescript-types
  - circuit-declarations
  - witness-functions
  - constructor-circuit
  - pure-vs-impure-circuits
  - circuit-witness-boundary
  - ledger-state-design
  - cell-and-counter
  - map-and-set
  - merkle-trees
  - sealed-ledger-fields
  - disclosure-model
  - witness-value-tracking
  - transient-vs-persistent
  - commitment-and-nullifier-schemes
  - token-operations
  - coin-lifecycle
  - standard-library-functions
  - maybe-and-either-types
  - commit-reveal-pattern
  - access-control-pattern
  - anonymous-membership-proof
  - fungible-token-template
  - private-balance-verification
  - state-machine-pattern
  - persistent-hash-is-not-safe
  - void-is-not-a-return-type
  - no-unbounded-loops
  - both-branches-execute
  - disclosure-compiler-error
  - send-result-change-handling
  - operators-and-expressions
  - variable-declarations
  - witness-context-object
  - list-adt
  - immediate-vs-deferred-operations
  - zswap-advanced-operations
  - starter-contract-templates
---

# Compact Language — Map of Content

Compact is the domain-specific language for writing zero-knowledge smart contracts on the Midnight Network. Every Compact program compiles to a ZK circuit, which means the language enforces constraints that general-purpose languages do not: all computation must be bounded, privacy is the default, and the programmer must explicitly opt in to revealing data on-chain.

## Core Language

Every Compact file begins with a [[pragma-and-imports]] declaration that sets the language version and brings the standard library into scope. The [[type-system]] defines all available primitive and user-defined types, each of which has a corresponding TypeScript representation described in [[compact-to-typescript-types]]. Understanding [[bounded-computation]] is essential because it explains why there are no unbounded loops, no recursion, and no dynamic allocation. All identifiers should follow the [[naming-conventions]] that the community enforces by convention and tooling.

The [[operators-and-expressions]] section details all available operators — arithmetic, comparison, logical, bitwise, and cast — including the critical restriction that Field does not support ordering. The [[variable-declarations]] section covers the three binding forms (`const`, `let`, `let mut`) and scope rules.

A well-structured contract follows the [[contract-file-layout]], which dictates the ordering of declarations from pragma through types, ledger fields, constructor, witnesses, and circuits. The [[export-and-visibility]] rules determine which circuits and types form the contract's public API.

## Circuits and Witnesses

The [[circuit-declarations]] section covers how to write the on-chain logic that compiles to ZK proofs, including parameters, return types, and the `export` keyword. Circuits that access ledger state or call witnesses are impure, a distinction explained in [[pure-vs-impure-circuits]]. The [[witness-functions]] section describes the off-chain TypeScript functions that feed private data into circuits, creating the trust boundary detailed in [[circuit-witness-boundary]]. The [[witness-context-object]] provides each witness implementation with access to ledger state and contract metadata. Every contract starts with a [[constructor-circuit]] that initializes ledger state at deployment.

## Ledger State

Choosing the right on-chain data structure is one of the most consequential design decisions, and [[ledger-state-design]] provides the decision tree for selecting among the available ADTs. The simplest options are [[cell-and-counter]] — a Cell for single values and a Counter for commutative increments. For key-value lookups and membership tracking, [[map-and-set]] covers the Map and Set ADTs. For sequential collections with push/pop behavior, the [[list-adt]] provides queue and stack semantics. Privacy-preserving membership proofs require [[merkle-trees]], which provide both standard and historic variants. Some fields should be immutable after deployment, which is the role of [[sealed-ledger-fields]].

## Privacy Model

Midnight's privacy model is opt-in disclosure, and [[disclosure-model]] explains how `disclose()` gates the flow of private data to public state. The compiler enforces this through [[witness-value-tracking]], an abstract interpreter that traces how witness-derived values propagate through the program. The distinction between [[transient-vs-persistent]] hash and commit functions is the single most critical safety concept — using the wrong variant leaks data. For hiding values on-chain while proving properties about them, [[commitment-and-nullifier-schemes]] describes the commit-reveal primitives.

## Tokens

Midnight supports both native (NIGHT) and custom fungible tokens through the Zswap protocol. The [[token-operations]] section covers minting, sending, and receiving, while [[coin-lifecycle]] explains the CoinInfo and SendResult structures that track coins through their lifetime. The distinction between [[immediate-vs-deferred-operations]] determines when token transfers take effect within a transaction. For advanced multi-party shielded transactions, the [[zswap-advanced-operations]] provide low-level primitives.

## Standard Library

The [[standard-library-functions]] section catalogs the hashing, commitment, elliptic curve, and block-time functions available after `import CompactStandardLibrary`. The [[maybe-and-either-types]] section covers the two generic wrapper types used throughout the standard library for optional values and sum types.

## Proven Patterns

Common contract patterns have emerged in the Midnight ecosystem. The [[commit-reveal-pattern]] enables multi-phase protocols where data is committed before being revealed. The [[access-control-pattern]] shows how to restrict circuit execution to authorized callers. For privacy-preserving group membership, the [[anonymous-membership-proof]] uses Merkle trees so a prover can demonstrate membership without revealing which member they are. The [[fungible-token-template]] provides a complete custom token contract. The [[private-balance-verification]] pattern proves a balance exceeds a threshold without revealing the exact amount. The [[state-machine-pattern]] models contract lifecycle through enum-based states with guarded transitions. For getting started quickly, [[starter-contract-templates]] provides minimal and owned contract skeletons as building blocks.

## Critical Gotchas

These are the mistakes that cause the most debugging time:

- [[persistent-hash-is-not-safe]] — The most dangerous misconception about privacy
- [[void-is-not-a-return-type]] — The `Void` keyword is deprecated; use `[]`
- [[no-unbounded-loops]] — ZK circuits require bounded iteration
- [[both-branches-execute]] — Both sides of if-else always evaluate in a ZK circuit
- [[disclosure-compiler-error]] — How to read and fix "potential witness-value disclosure"
- [[send-result-change-handling]] — Ignoring change from token sends silently burns funds
