# compact-core

Core knowledge for writing Midnight Compact smart contracts.

A [Claude Code plugin](https://docs.anthropic.com/en/docs/claude-code/plugins) that provides skills, commands, and agents for developing smart contracts in the Compact language on the Midnight blockchain. Covers contract structure, data types, ledger declarations, circuits, witnesses, privacy patterns, deployment, testing, and code review.

## Features

- Write and scaffold Compact smart contracts with correct structure
- Understand Compact's type system, control flow, and module system
- Design ledger state with the right ADT types (Counter, Map, Set, MerkleTree)
- Implement TypeScript witness functions with correct type mappings
- Apply 18 reusable contract patterns (access control, governance, privacy, tokens)
- Use shielded and unshielded tokens with the zswap protocol
- Understand circuit costs, compiler output, and optimization strategies
- Deploy contracts to Midnight networks with provider and wallet setup
- Write unit tests with Vitest and the Simulator pattern
- Review contracts across 11 security and correctness categories
- Initialize new projects with `create-mn-app`

## Prerequisites

- [Compact CLI](https://docs.midnight.network/) installed
- Node.js for TypeScript witness development and testing

## Installation

Install via the Claude Code plugin marketplace:

```
/install-plugin compact-core
```

Or add the plugin manually by cloning it into your Claude Code plugins directory.

## Commands

### `/compact-core:review-compact`

Comprehensive review of Compact smart contract code covering 11 categories including privacy, security, tokens, concurrency, performance, and more. Supports parallel execution via reviewer agents.

```
/compact-core:review-compact path/to/contract.compact
/compact-core:review-compact contracts/
```

### `/compact-core:debug-contract`

Interactive debugging workflow for Compact smart contract errors. Uses symptom-driven triage to route to the appropriate domain-specific skill.

```
/compact-core:debug-contract
```

## Agents

### compact-dev

Write, generate, review, or fix Compact smart contract code. Use for creating new contracts, modifying existing ones, fixing compilation errors, implementing privacy patterns, or answering questions about Compact syntax and semantics.

### reviewer

Focused single-category reviewer dispatched by the `review-compact` command. Not intended for direct invocation.

## Skills

### compact-structure

Contract anatomy — pragma, imports, ledger declarations, sealed ledger, circuits, witnesses, constructors, export patterns, and disclosure rules.

**Triggers on**: writing or scaffolding a Compact contract, contract anatomy, pragma, circuit definitions

### compact-language-ref

Language mechanics — types (Field, Bytes, Uint, Boolean, Vector, Maybe, Either, enums, structs), operators, control flow, for loops, modules, imports, and stdlib functions.

**Triggers on**: Compact syntax, type casting, compiler errors, wrong syntax patterns

### compact-ledger

On-chain state — ledger declarations, modifiers (export, sealed), ADT types and operations, constructor initialization, state design choices, privacy of state operations, Kernel ledger, and the token/coin system.

**Triggers on**: ledger fields, Map vs Set vs MerkleTree, Counter, on-chain visibility, kernel.self()

### compact-standard-library

Authoritative index of everything `import CompactStandardLibrary;` provides — types, constructors, elliptic curve functions, Merkle tree verification, and a verification protocol to prevent hallucinated functions.

**Triggers on**: stdlib types, Maybe/Either, ecAdd/ecMul, merkleTreePathRoot, verifying function existence

### compact-tokens

Tokens on Midnight — shielded vs unshielded approaches, mint/send/receive functions, token colors, domain separators, NIGHT/DUST model, and standard token contract patterns.

**Triggers on**: minting, burning, transfers, ShieldedCoinInfo, FungibleToken, NFT, zswap

### compact-privacy-disclosure

Privacy model — disclose() rules, privacy-by-default design, commitment schemes, nullifier patterns, Merkle membership proofs, unlinkable actions, selective disclosure, and debugging disclosure errors.

**Triggers on**: disclose, witness protection, commitments, nullifiers, anonymous auth, "potential witness-value disclosure" errors

### compact-witness-ts

TypeScript witness implementation — WitnessContext, private state, Compact-to-TypeScript type mappings, compiler-generated .d.ts files, Contract class, and the runtime.

**Triggers on**: witness functions in TypeScript, WitnessContext, type mappings, contract.circuits, pure circuits

### compact-patterns

18 reusable contract design patterns — access control (owner-only, RBAC, multi-sig), pausable, initializable, state machine, time-lock, commit-reveal, auction, escrow, treasury, voting, governance, registry, allowlist, credential, and anonymous membership.

**Triggers on**: design patterns, access control, governance, escrow, multi-sig, pattern combinations

### compact-transaction-model

Transaction execution — guaranteed vs fallible phases, kernel.checkpoint(), transaction composition, state conflicts, DUST fees, gas limits, proof verification, and atomic swaps via transaction merging.

**Triggers on**: transaction semantics, fallible/guaranteed phase, checkpoint, fees, gas, atomic swap

### compact-circuit-costs

Cost model across three dimensions: circuit/proving costs (gate counts, hash tradeoffs), runtime gas (readTime, computeTime, bytesWritten), and state costs. Covers optimization strategies.

**Triggers on**: gate count, proving time, gas costs, transientHash vs persistentHash, loop unrolling, optimization

### compact-compilation

Compiler pipeline — output artifacts (TypeScript bindings, ZKIR, prover/verifier keys, metadata), circuit metrics, compiler errors, --skip-zk flag, and build directory structure.

**Triggers on**: compiling contracts, compiler output, ZKIR, prover keys, k-value, compilation errors

### compact-deployment

Deployment lifecycle — provider configuration (indexer, node, proof server), wallet setup (WalletFacade, HD wallet), network connections (undeployed, preview, preprod), deployContract, findDeployedContract, and callTx.

**Triggers on**: deploying contracts, providers, wallet setup, network config, contract addresses

### compact-testing

Unit testing with Vitest — Simulator pattern, createConstructorContext, createCircuitContext, asserting ledger state, testing assertion failures, multi-user tests, and compilation as a test gate.

**Triggers on**: testing, Vitest, Simulator, createCircuitContext, test-driven development

### compact-init-project

Project scaffolding with `create-mn-app` — templates, project structure, and first-time setup.

**Triggers on**: new project, create-mn-app, scaffold, hello-world, counter template

### compact-review

Review checklists for 11 categories of Compact contract review — privacy, security, cryptographic correctness, token economics, concurrency, compilation, performance, witness-contract consistency, architecture, code quality, and testing.

**Triggers on**: code review, security review, privacy review

### compact-debugging

Interactive debugging process — symptom-driven triage, fix tracking, and escalation for compiler failures, proof generation issues, witness mismatches, and compatibility problems.

**Triggers on**: debugging errors, compiler failures, "won't compile", proof generation issues, version mismatches

## Companion Plugins

Some features reference skills from companion plugins:

- **midnight-tooling** — CLI installation, proof server management, devnet, release notes
- **devs** — General code review, TypeScript, and security skills used by the reviewer agent

## License

[MIT](LICENSE)
