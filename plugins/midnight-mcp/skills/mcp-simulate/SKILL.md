---
name: mcp-simulate
description: Use when the user asks to test my contract, try out my Compact code, run my contract locally, check if my contract works, debug my contract logic, or mentions my simulation expired, or asks about simulating a contract, deploying in simulation, calling a circuit, reading simulation state, MCP simulation, contract simulation lifecycle, midnight-simulate-deploy, midnight-simulate-call, midnight-simulate-state, or midnight-simulate-delete.
---

# Midnight MCP Simulation Tools

Four tools provide a stateful simulation environment for deploying and testing Compact contracts without a live network. Simulation sessions follow a lifecycle: deploy, call, inspect state, and delete.

## Simulation Lifecycle

```
deploy → call → state → (repeat call/state) → delete
```

1. **Deploy** creates a session with an initialized contract
2. **Call** executes circuits against the deployed contract
3. **State** reads current ledger values, available circuits, and call history
4. **Delete** ends the session and frees server resources

Sessions are stateful — each call modifies the contract's ledger state, and subsequent calls see the updated state. This mirrors how contracts behave on-chain.

## midnight-simulate-deploy

Deploy a Compact contract into a new simulation session. Returns a `sessionId` used for all subsequent operations.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `source` | Yes | Compact source code to deploy |
| `constructorArgs` | No | Arguments for the contract constructor, if the contract defines one |

**Response includes:**

- `sessionId` — Required for all subsequent `call`, `state`, and `delete` operations
- Deployed contract metadata (available circuits, initial ledger state)

**Important:**

- Sessions expire after 15 minutes of inactivity. If a session expires, deploy again to get a new session
- The server supports approximately 100 concurrent sessions. Delete sessions when you are done to free resources
- Constructor arguments must match the contract's constructor signature exactly

## midnight-simulate-call

Execute a circuit on a deployed contract within an active simulation session.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `sessionId` | Yes | Session ID from a previous `midnight-simulate-deploy` call |
| `circuit` | Yes | Name of the circuit to execute |
| `arguments` | No | Arguments to pass to the circuit. Must match the circuit's parameter types |

**Response includes:**

- Circuit return value (if any)
- Updated ledger state after execution
- Execution status (success or error with details)

**Important:**

- The circuit name must match an exported circuit in the deployed contract
- Arguments are type-checked against the circuit's parameter signature
- State changes from a successful call persist in the session — subsequent calls and state queries reflect the updated ledger
- If a circuit call fails (assertion failure, type error, etc.), the ledger state is not modified

## midnight-simulate-state

Read the current state of a simulation session, including ledger values, available circuits, and call history.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `sessionId` | Yes | Session ID from a previous `midnight-simulate-deploy` call |

**Response includes:**

- Current ledger field values
- List of available circuits with their parameter signatures
- Call history for the session (previous calls and their results)

Use this tool to inspect state between calls, to verify that a circuit modified the ledger as expected, or to check what circuits are available before making a call.

## midnight-simulate-delete

End a simulation session and free server resources.

**Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `sessionId` | Yes | Session ID from a previous `midnight-simulate-deploy` call |

Always delete sessions when you are finished testing. The server has a limited number of concurrent sessions (~100), and abandoned sessions consume resources until they expire after 15 minutes.

## Session Management Best Practices

### Session Lifecycle

1. **Deploy once per contract version.** If you modify the source, deploy a new session rather than trying to reuse an existing one
2. **Call circuits in a logical sequence.** Since state is cumulative, plan your call sequence to test the behavior you care about
3. **Inspect state after significant operations.** Use `midnight-simulate-state` to verify that ledger mutations match expectations
4. **Delete when done.** Do not leave sessions open after testing is complete

### Handling Session Expiry

Sessions expire after 15 minutes of inactivity. If you receive a session-not-found error:

1. The session has expired — you cannot recover it
2. Deploy a new session with the same source code
3. Replay the sequence of calls needed to reach the desired state

### Testing Patterns

**Sequential testing** — Deploy, then call circuits in order to test a workflow:

1. Deploy the contract
2. Call the initialization circuit (if any)
3. Call business logic circuits in sequence
4. Inspect state after each call to verify correctness

**State verification** — Use `midnight-simulate-state` to check that ledger values match expectations after each operation. Compare actual values against expected values documented in the contract's specification.

**Error case testing** — Call circuits with invalid arguments or in invalid states to verify that the contract rejects them correctly. A failed call should not modify the ledger — use `midnight-simulate-state` to confirm.

**Multi-circuit interaction** — Test that circuits interact correctly by calling them in various orders and verifying that the resulting state is consistent.

## Common Errors

Simulation tools return structured error responses. The most frequent errors:

| Error | Trigger | Quick fix |
|-------|---------|-----------|
| `session_not_found` | Session expired (15 min inactivity) or deleted | Deploy a new session, replay calls |
| `circuit_not_found` | Typo or calling a non-exported circuit | Check spelling; use `midnight-simulate-state` to list circuits |
| `type_mismatch` | Wrong argument type, count, or format | Consult `references/argument-formats.md` for type mapping |
| `assertion_failure` | Contract `assert()` failed | Read the assertion message; inspect state for preconditions |
| `compilation_error` | Invalid Compact source in deploy | Fix source; use `compact-core:compact-compilation` to verify |

Failed circuit calls (assertion failure, type mismatch) do not modify ledger state -- no rollback is needed.

For detailed error payloads and recovery steps, see `references/common-errors.md`.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Tool routing and category overview | `mcp-overview` |
| Compact compilation for verifying source before simulation | `compact-core:compact-compilation` |
| Verification methodology using simulation | `compact-core:verify-correctness` |
| Compact standard library for understanding circuit behavior | `compact-core:compact-standard-library` |
| Full simulation lifecycle worked example | `examples/simulation-lifecycle.md` |
| Argument formats and Compact-to-JSON type mapping | `references/argument-formats.md` |
| Common error payloads and recovery steps | `references/common-errors.md` |
