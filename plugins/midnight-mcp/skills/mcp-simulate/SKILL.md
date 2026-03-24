---
name: mcp-simulate
description: This skill should be used when the user asks about simulating a Compact contract, deploying a contract in simulation, calling a circuit in simulation, testing contract behavior, reading simulation state, managing simulation sessions, MCP simulation, midnight-simulate-deploy, midnight-simulate-call, midnight-simulate-state, midnight-simulate-delete, contract simulation lifecycle, testing contract assertions, witness mocking, multi-user contract testing, caller context simulation, interactive contract testing, or simulation error recovery.
---

# Midnight MCP Simulation

Four tools providing a real execution environment for deploying and testing Compact contracts without a live network. Uses the OpenZeppelin Compact Simulator under the hood — circuits execute actual compiled logic with full state management.

## When to Use Local Testing Instead

Evaluate these conditions before continuing. If any match, stop loading this skill and use the referenced skill instead.

| Condition | Use Instead |
|-----------|-------------|
| CI/CD pipeline testing (headless, reproducible) | OZ simulator locally via `@openzeppelin/compact-simulator` |
| Need ZK proof generation | `mcp-compile` (full compilation) |
| Need to test against live on-chain state | Local devnet via `midnight-tooling:devnet` |
| Bulk/automated test suites (hundreds of calls) | OZ simulator locally |

If none of these apply, continue with MCP-hosted simulation below.

## Simulation Tools

| Tool | What It Does | When to Use |
|------|-------------|-------------|
| `midnight-simulate-deploy` | Compile and deploy a contract into a new simulation session | Starting a new test session |
| `midnight-simulate-call` | Execute a circuit with real logic, mutating session state | Testing circuit behavior, state changes, assertions |
| `midnight-simulate-state` | Read current ledger state, circuit metadata, and call history | Verifying state between calls, inspecting available circuits |
| `midnight-simulate-delete` | End a session and free server resources | Done testing, cleanup |

## Session Lifecycle

```
deploy (compile + init) → call → state → (repeat call/state) → delete
```

1. **Deploy** compiles the contract and creates a session with initialized state
2. **Call** executes circuits against the deployed contract with real logic
3. **State** reads current ledger values, available circuits, and call history
4. **Delete** ends the session and frees server resources

Sessions are stateful — each call modifies the contract's ledger state, and subsequent calls see the updated state. This mirrors how contracts behave on-chain.

## Intent-to-Reference Routing

Load the references matching your current task. If simulation fails, also load `references/error-recovery.md`.

| Intent | References to Load |
|--------|-------------------|
| Deploy and explore a contract's structure | `references/deploy-workflows.md` + `references/state-inspection.md` |
| Test a multi-step workflow | `references/deploy-workflows.md` + `references/circuit-execution.md` + `references/testing-patterns.md` |
| Test with mock witnesses or edge-case inputs | `references/circuit-execution.md` + `references/witness-management.md` |
| Test multi-user / access control behavior | `references/circuit-execution.md` + `references/caller-context.md` |
| Verify state changes after circuit calls | `references/circuit-execution.md` + `references/state-inspection.md` |
| Debug a simulation failure | `references/error-recovery.md` |
| Manage session lifecycle (expiry, cleanup) | `references/session-management.md` |
| Test a specific contract pattern end-to-end | `references/testing-patterns.md` + relevant archetype example |
| Understand server-side limitations and future capabilities | `references/server-enhanced.md` |

## Loading Example Files

Each reference file describes patterns and names their example files. After reading a reference file, evaluate which patterns apply. Load the example file **only** for patterns you intend to use. Do not load example files for patterns you are skipping.

## Rate Limits

The hosted simulator has rate limits. Budget your simulation calls.

| Tool | Limit | Window |
|------|-------|--------|
| `midnight-simulate-deploy` | 20 requests | 60 seconds |
| `midnight-simulate-call` | 20 requests | 60 seconds |

Deploy is slower than other tools (~1-5s) because it involves compilation. Plan testing so you deploy once and make multiple calls, rather than redeploying for each test case.

## `/midnight-mcp:simulate` Command

Users can invoke `/midnight-mcp:simulate` to run simulations with preset testing modes.

### Modes

| Mode | Invocation | Behavior |
|------|-----------|----------|
| Interactive | `/midnight-mcp:simulate` | Guided session — asks what to test, deploys, walks through calls |
| Quick | `/midnight-mcp:simulate <code-or-file>` | Deploy and show structure (circuits + initial state) |
| Explicit | `/midnight-mcp:simulate <code> --test-sequence` | User-specified flags |

### Preset Flags

| Preset | Behavior |
|--------|----------|
| `--explore` | Deploy + state inspection, show circuits and ledger structure |
| `--test-sequence` | Guided multi-step: deploy, prompt for each circuit call, verify state between calls |
| `--regression` | Deploy + replay a known call sequence, compare final state against expected |
| `--assertions` | Deploy + systematically test each exported circuit's assertion paths |

### Modifier Flags

| Flag | Effect |
|------|--------|
| `--caller <address>` | Set default caller for all calls |
| `--cleanup` | Auto-delete session when done |
| `--version <ver>` | Compiler version for deploy |
| `--witness <name>=<value>` | Provide witness override (repeatable) |
| `--compile-first` | Run through `mcp-compile` (skipZk) before deploying |

No flags with code/file: `--explore`. No flags, no code: interactive mode.

## Cross-References

| Topic | Skill / Plugin |
|-------|---------------|
| Tool routing and category overview | `mcp-overview` |
| Compilation workflows and compiler errors | `mcp-compile` |
| Local CLI compilation and artifacts | `compact-core:compact-compilation` |
| Verification methodology | `compact-core:verify-correctness` |
| Compact standard library for understanding circuit behavior | `compact-core:compact-standard-library` |
| Local devnet for on-chain testing | `midnight-tooling:devnet` |
