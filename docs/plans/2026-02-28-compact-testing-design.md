# Design: compact-testing Skill

**Date:** 2026-02-28
**Plugin:** compact-core
**Author:** Aaron Bassett

## Overview

Add a `compact-testing` skill to the compact-core plugin that covers unit testing Compact smart contracts using the compiled JavaScript implementation and Vitest, plus compilation validation as a test gate.

## Context

Compact contracts compile to JavaScript (`index.cjs`) via the Compact compiler. There is no official Compact testing framework — the official approach is to test the generated JS implementation using standard JS test frameworks. All official Midnight examples (counter, bboard) use Vitest with a Simulator class pattern.

The existing `compact-witness-ts` skill covers the Contract class and witness implementation but does not cover testing patterns, test setup, or compilation validation.

## Scope

- **In scope:** Off-chain unit testing with Vitest, the Simulator pattern, context lifecycle, circuit calling, ledger/private-state assertions, error testing, multi-user testing, pure circuit testing, token operation testing, and compilation validation (compact compile as test gate, compiler error interpretation, CI integration).
- **Out of scope:** Integration testing (deploying to local testnet, Docker, provider setup, wallet creation, end-to-end transaction testing).
- **API version:** Newer API only (`createCircuitContext`, `impureCircuits`, `currentQueryContext`). Older API patterns are not documented.
- **Self-contained:** Includes enough witness/contract context to be standalone with minimal cross-referencing to compact-witness-ts.

## File Structure

```
plugins/compact-core/skills/compact-testing/
├── SKILL.md
├── references/
│   ├── test-setup.md
│   ├── simulator-pattern.md
│   ├── assertions-and-patterns.md
│   └── compilation-validation.md
└── examples/
    ├── vitest.config.ts
    ├── CounterSimulator.test.ts
    ├── BBoardSimulator.test.ts
    ├── TokenSimulator.test.ts
    └── PureCircuits.test.ts
```

## SKILL.md Content

1. **Overview** — Testing Compact contracts via the compiled JS implementation + Vitest. No official test framework; test the generated JS.
2. **Quick Start** — Minimal setup: dependencies, setNetworkId, import Contract, instantiate, create context, call circuits, assert.
3. **Simulator Pattern** — Summary of the Simulator class pattern. Cross-ref to references/simulator-pattern.md.
4. **Testing Checklist** — Quick reference table: what to test and how.
5. **Key API Reference** — Essential imports from @midnight-ntwrk/compact-runtime.
6. **Compilation Validation** — Summary of compact compile as test gate. Cross-ref to references/compilation-validation.md.
7. **Common Mistakes** — Testing-specific pitfalls.
8. **Reference routing table** — Links to all references and examples.

### Trigger Description

> This skill should be used when the user asks about testing Compact smart contracts, writing unit tests for circuits, setting up Vitest for Compact projects, the Simulator pattern for contract testing, creating test context (createConstructorContext, createCircuitContext, sampleContractAddress), calling impureCircuits or circuits in tests, asserting ledger state with the ledger() function, testing assertion failures and error cases, multi-user testing, private state in tests, Compact compiler validation, compilation errors, CI pipeline testing, compact compile as a test gate, or test-driven development for Midnight contracts.

### Keywords for plugin.json

`"testing"`, `"vitest"`, `"unit-test"`, `"simulator"`, `"createCircuitContext"`, `"createConstructorContext"`, `"sampleContractAddress"`, `"impureCircuits"`, `"compact-compile"`, `"test-driven"`

## Reference Files

### references/test-setup.md
- Directory structure (contract/src/test/, managed/ output)
- vitest.config.ts reference configuration (mode: "node", globals: true, deps.interopDefault: true)
- Required dependencies and their purpose
- setNetworkId("undeployed") explanation
- package.json scripts ("test": "vitest run", "test:compile": "npm run compact && vitest run")

### references/simulator-pattern.md
- Why use a simulator (encapsulates context management, clean test API)
- Anatomy: constructor -> initialState() -> createCircuitContext() -> circuit methods -> ledger/private state accessors
- Context lifecycle: circuitContext updated after each circuit call (this.circuitContext = result.context)
- Witness setup in simulator constructor
- Type definitions: CircuitContext, WitnessContext<Ledger, PrivateState>, [PrivateState, ReturnValue] tuple
- Multi-user support: swapping currentPrivateState
- Full annotated simulator example

### references/assertions-and-patterns.md
- Ledger state assertions (reading via ledger(), checking individual fields)
- Circuit return value assertions
- Private state assertions (currentPrivateState)
- Error case testing (.toThrow("failed assert: ..."))
- Multi-user / multi-actor testing (creating multiple seed/key pairs, switching users)
- Pure circuit testing (contract.pureCircuits.*)
- Testing constructors (verifying initial state)
- Edge cases: empty state, max values, boundary conditions

### references/compilation-validation.md
- compact compile command and expected output structure
- Exit codes and what they mean
- Common compiler errors and how to interpret them
- Integrating compilation into CI (run compile before tests)
- Compiler version compatibility (pragma ranges)
- Using compilation to catch type errors, disclosure violations, sealed ledger misuse

## Example Files

### examples/vitest.config.ts
Reference Vitest configuration for Compact contract testing. Compact, annotated, copy-paste ready.

### examples/CounterSimulator.test.ts
Beginner-level complete test file:
- Imports from compact-runtime and generated code
- setNetworkId("undeployed")
- CounterSimulator class with constructor context, circuit context, increment/decrement methods, ledger reader
- Simple witness (empty or minimal)
- Tests: initial state is 0, increment increases counter, multiple increments, ledger state, private state tracking

### examples/BBoardSimulator.test.ts
Intermediate-level complete test file:
- Witnesses with secret key (localSecretKey pattern)
- Post/takeDown circuit calls with arguments
- Multi-user testing (switching private state between users)
- Error assertions (posting to occupied board, unauthorized takedown)
- Ledger state with Maybe<T> fields (is_some, value)
- Access control patterns

### examples/TokenSimulator.test.ts
Token testing example:
- Minting shielded/unshielded tokens
- Sending tokens and checking balances
- Testing zswap integration and token colors
- Domain separator patterns

### examples/PureCircuits.test.ts
Pure circuit testing example:
- Testing pureCircuits from TypeScript
- Computation-only tests with no ledger side effects
- Verifying hash computations and helper functions
- Input/output validation

## Research Sources

- Official docs: https://docs.midnight.network/develop/guides/compact-javascript-runtime
- Example counter: https://github.com/midnightntwrk/example-counter
- Example bboard: https://github.com/midnightntwrk/example-bboard
- Midnight MCP server search results for testing patterns
- compact-export test-center patterns (private repo, indexed via MCP)
