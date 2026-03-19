# MCP Simulate Skill — Design Specification

**Date:** 2026-03-19
**Plugin:** `midnight-mcp`
**Skill:** `mcp-simulate` (rewrite)
**Status:** Draft
**Prerequisite:** [compact-playground#17](https://github.com/devrelaicom/compact-playground/issues/17) — OZ simulator integration must be complete before implementation

## Problem

The current `mcp-simulate` skill is a single flat SKILL.md (~6,300 bytes) with basic tool documentation. It describes a simulation engine that uses regex-based static analysis — not actual compilation or execution. It can only simulate Counter/Uint increment; all other ledger types return unchanged. The skill does not document this limitation, potentially misleading the LLM into presenting simulation results as logic-validated when they are only structurally plausible.

With [compact-playground#17](https://github.com/devrelaicom/compact-playground/issues/17) complete, the playground simulator uses the [OpenZeppelin Compact Simulator](https://github.com/OpenZeppelin/compact-contracts/tree/main/packages/simulator) — a real execution engine that compiles contracts and runs actual circuit logic. This enables:

- Real circuit execution with actual state mutations across all ledger types
- Assertion evaluation (assert() statements actually execute)
- Witness support with runtime overrides/mocking
- Caller context for multi-user simulation
- Private state inspection
- Full type checking via compiled artifacts

The skill needs a complete rewrite to document these capabilities with the same richness as the `mcp-search` and `mcp-compile` skills.

## Goals

1. Rewrite the skill with workflow-oriented references, example files, and a slash command matching the quality of `mcp-search` and `mcp-compile`
2. Teach the LLM effective simulation strategies — testing patterns, witness management, multi-user testing, assertion testing
3. Provide error example files for the most common simulation failure modes
4. Provide contract archetype examples showing complete deploy→test→verify sequences
5. Bail out early when local testing or devnet is the better choice
6. File GitHub issues for remaining server-side enhancements not covered by the OZ integration

## Non-Goals

- Implementing the OZ simulator integration itself (that's [compact-playground#17](https://github.com/devrelaicom/compact-playground/issues/17))
- Changing the MCP server tool definitions (that follows from the playground integration)
- Documenting the OZ simulator's TypeScript API for local use (that's a `compact-core` concern)
- Redesigning other skills (`mcp-analyze`, `mcp-compile`, etc.)

## Architecture

### Bail-Out Gate

The SKILL.md starts with a decision table evaluated before anything else. Simulation now handles most interactive testing needs, so the bail-out conditions are narrow:

| Condition | Use Instead |
|-----------|-------------|
| CI/CD pipeline testing (headless, reproducible) | OZ simulator locally via `@openzeppelin/compact-simulator` |
| Need ZK proof generation | `mcp-compile` (full compilation) |
| Need to test against live on-chain state | Local devnet via `midnight-tooling:devnet` |
| Bulk/automated test suites (hundreds of calls) | OZ simulator locally |

### Hybrid Structure

The SKILL.md uses intent-based routing (like `mcp-search`) to direct the LLM to lifecycle-oriented references (the mechanical how-to). This gives the LLM fast routing based on what it's trying to accomplish, while keeping each reference self-contained and focused.

### Workflow-Oriented References

Each reference is a self-contained playbook for one aspect of simulation. The LLM loads only the references matching its current task. References include inline examples for parameter usage and response interpretation.

### Example Files

Three categories of example files:

1. **Error examples** — routed from `error-recovery.md` by error pattern, with before/after pairs and anti-patterns
2. **Testing pattern examples** — recipes for common testing strategies (assertion testing, multi-user testing, state verification)
3. **Contract archetype examples** — complete deploy→test→verify sequences for common contract patterns (counter, token, voting, access control)

### Slash Command

A `/midnight-mcp:simulate` command with interactive, quick, and explicit modes, plus preset flags for common workflows.

### Consumer

The primary consumer is the LLM. All content is written as concise operational instructions.

### Boundary with Other Skills

- `mcp-simulate` owns: MCP-hosted simulation workflows, session management, testing patterns, error recovery via MCP simulate tools
- `mcp-compile` owns: compilation workflows, compiler error interpretation, multi-version compilation, snippet auto-wrapping
- `compact-core:verify-correctness` owns: verification methodology, correctness criteria, compilation + simulation as part of a broader verification strategy
- `midnight-tooling:devnet` owns: local network testing, on-chain state, deployment to devnet
- `compact-core:compact-compilation` owns: local CLI compilation, artifact structure

The simulate skill cross-references `mcp-compile` for compilation errors encountered during deploy (since deploy now involves compilation). It does not duplicate compile error documentation.

## Assumed MCP Tool Capabilities (Post-OZ Integration)

These are the capabilities the skill assumes exist after [compact-playground#17](https://github.com/devrelaicom/compact-playground/issues/17) is complete. The exact parameter names and response structures should be verified against the actual implementation before writing the skill content.

### `midnight-simulate-deploy`

Compiles the contract and creates a simulation session with the OZ simulator.

**Expected parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `code` | string | Yes | Compact contract source code |
| `version` | string | No | Compiler version |
| `constructorArgs` | unknown[] | No | Constructor arguments |
| `caller` | string | No | Caller identity for the deploy transaction (sets contract creator/owner) |

**Expected response includes:**
- `sessionId` — for subsequent operations
- `circuits` — array of circuit metadata with full type information (name, isPublic, isPure, parameters with types, returnType, readsLedger, writesLedger)
- `ledgerState` — initial ledger state for all field types
- `expiresAt` — session expiry timestamp

**Key change from current:** Deploy now involves compilation (~1-5s with skipZk), not instant static analysis.

### `midnight-simulate-call`

Executes a circuit with real compiled logic via the OZ simulator.

**Expected parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `sessionId` | string | Yes | Session ID from deploy |
| `circuit` | string | Yes | Circuit name |
| `arguments` | Record<string, unknown> | No | Circuit arguments (MCP server coerces types — see [midnight-mcp#20](https://github.com/devrelaicom/midnight-mcp/issues/20)) |
| `caller` | string | No | Caller address for access control testing |
| `witnessOverrides` | Record<string, unknown> | No | Override witness return values for testing |

**Expected response includes:**
- `success` — whether the circuit executed without error
- `result` — circuit return value (if any)
- `stateChanges` — array of field mutations (field, operation, previousValue, newValue)
- `updatedLedger` — full ledger state after execution
- `errors` — if assertion failed or runtime error, includes the error message

**Key changes from current:** Real execution (not heuristic), assertion evaluation, caller context, witness overrides, actual return values.

### `midnight-simulate-state`

Reads session state including all ledger types and call history.

**Expected parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `sessionId` | string | Yes | Session ID |

**Expected response includes:**
- `ledgerState` — current values for all ledger field types (Counter, Map, Set, MerkleTree, etc.)
- `circuits` — circuit metadata
- `callHistory` — array of previous calls with arguments, results, and state changes
- `expiresAt` — session expiry timestamp

### `midnight-simulate-delete`

Unchanged from current implementation.

## SKILL.md Content Specification

### Frontmatter

```yaml
name: mcp-simulate
description: This skill should be used when the user asks about simulating a Compact contract, deploying a contract in simulation, calling a circuit in simulation, testing contract behavior, reading simulation state, managing simulation sessions, MCP simulation, midnight-simulate-deploy, midnight-simulate-call, midnight-simulate-state, midnight-simulate-delete, contract simulation lifecycle, testing contract assertions, witness mocking, multi-user contract testing, caller context simulation, interactive contract testing, or simulation error recovery.
```

### Sections

1. **Title and intro** — "Midnight MCP Simulation" — four tools providing a real execution environment for deploying and testing Compact contracts without a live network. Uses the OpenZeppelin Compact Simulator under the hood — circuits execute actual compiled logic with full state management.

2. **Bail-out gate** — table (see Architecture section above)

3. **Simulation tools table:**

   | Tool | What It Does | When to Use |
   |------|-------------|-------------|
   | `midnight-simulate-deploy` | Compile and deploy a contract into a new simulation session | Starting a new test session |
   | `midnight-simulate-call` | Execute a circuit with real logic, mutating session state | Testing circuit behavior, state changes, assertions |
   | `midnight-simulate-state` | Read current ledger state, circuit metadata, and call history | Verifying state between calls, inspecting available circuits |
   | `midnight-simulate-delete` | End a session and free server resources | Done testing, cleanup |

4. **Session lifecycle diagram:**
   ```
   deploy (compile + init) → call → state → (repeat call/state) → delete
   ```

5. **Intent-to-reference routing table:**

   | Intent | References to load |
   |--------|-------------------|
   | Deploy and explore a contract's structure | `references/deploy-workflows.md` + `references/state-inspection.md` |
   | Test a multi-step workflow | `references/deploy-workflows.md` + `references/circuit-execution.md` + `references/testing-patterns.md` |
   | Test with mock witnesses or edge-case inputs | `references/circuit-execution.md` + `references/witness-management.md` |
   | Test multi-user / access control behavior | `references/circuit-execution.md` + `references/caller-context.md` |
   | Verify state changes after circuit calls | `references/circuit-execution.md` + `references/state-inspection.md` |
   | Debug a simulation failure | `references/error-recovery.md` |
   | Manage session lifecycle (expiry, cleanup) | `references/session-management.md` |
   | Test a specific contract pattern end-to-end | `references/testing-patterns.md` + relevant archetype example |

6. **Rate limits section:**

   | Tool | Limit | Window |
   |------|-------|--------|
   | `midnight-simulate-deploy` | 20 requests | 60 seconds |
   | `midnight-simulate-call` | 20 requests | 60 seconds |

   Note: Deploy is slower than other tools (~1-5s) because it involves compilation. Budget compile-then-deploy as a single operation.

7. **`/midnight-mcp:simulate` command** — summary of modes and flags (full spec in command file)

8. **Cross-references:**

   | Topic | Skill / Plugin |
   |-------|---------------|
   | Tool routing and category overview | `mcp-overview` |
   | Compilation workflows and compiler errors | `mcp-compile` |
   | Local CLI compilation and artifacts | `compact-core:compact-compilation` |
   | Verification methodology | `compact-core:verify-correctness` |
   | Compact standard library for understanding circuit behavior | `compact-core:compact-standard-library` |
   | Local devnet for on-chain testing | `midnight-tooling:devnet` |

## Reference File Specifications

All references live in `skills/mcp-simulate/references/`. No YAML frontmatter. Start with `# Title`. Concise, operational tone.

### 1. `deploy-workflows.md`

**Purpose:** How to deploy contracts into simulation sessions.

**Content:**

- **When to use:** Starting any simulation. This is always the first step.
- **The deploy-compile pipeline:** Deploy now compiles the contract before initializing the simulator. This takes ~1-5s (with skipZk). If compilation fails, the deploy fails with compiler errors — cross-reference `mcp-compile` error recovery for diagnosis.
- **Parameters:** `code` (required), `version` (optional — same behavior as `mcp-compile`), `constructorArgs` (optional — must match constructor signature)
- **Inline example — successful deploy:** Show the call, response with sessionId, circuits array (with parameter types, return types, pure/impure, ledger access), initial ledgerState
- **Inline example — failed deploy (compilation error):** Show the call, response with compiler errors, route to `mcp-compile` error recovery
- **Interpreting the deploy response:**
  - `circuits` tells you what you can call, what arguments each circuit takes, and which ledger fields it affects
  - `ledgerState` shows initial values for all ledger fields (Counter starts at 0, Map starts empty, etc.)
  - `sessionId` is required for ALL subsequent operations — store it
- **Version selection:** Same version semantics as `mcp-compile` — `"detect"` resolves from pragma, specific version string, or omit for latest
- **The deploy-then-inspect pattern:** After deploying, call `midnight-simulate-state` to get a full picture of the contract before making any calls. This gives you the circuit signatures and initial state in a single read.

### 2. `circuit-execution.md`

**Purpose:** How to call circuits and interpret results.

**Content:**

- **When to use:** After deploying, when you want to execute a circuit.
- **Parameters:** `sessionId` (required), `circuit` (required — must match an exported circuit name), `arguments` (optional — keyed by parameter name), `caller` (optional — see `caller-context.md`), `witnessOverrides` (optional — see `witness-management.md`)
- **Parameter formatting by type:**
  - `Uint<N>`: string representation of the integer, e.g., `"42"`, `"0"`
  - `Field`: string representation, e.g., `"12345"`
  - `Bytes<N>`: hex string, e.g., `"0x1a2b3c..."`
  - `Boolean`: `"true"` or `"false"`
  - Compound types: JSON-encoded where applicable

  Note: The MCP server handles type coercion ([midnight-mcp#20](https://github.com/devrelaicom/midnight-mcp/issues/20)), so passing raw values (e.g., `42` instead of `"42"`) should also work.
- **Inline example — successful call with state changes:** Show call to an increment circuit, response with stateChanges showing previousValue→newValue, updatedLedger
- **Inline example — pure circuit call:** Show call to a read-only circuit, response with result and no stateChanges
- **Inline example — assertion failure:** Show call that triggers an assert(), response with success=false and the assertion error message, ledger state unchanged
- **Understanding stateChanges:** Each entry shows which field changed, the operation, the previous value, and the new value. For Counters this is increment/decrement. For Maps it's insert/update/remove. For Sets it's add/remove.
- **Pure vs impure circuits:** Pure circuits return values without modifying ledger state. Impure circuits may modify state. The `isPure` flag in circuit metadata tells you which.
- **The fix-and-redeploy loop:** If a circuit call reveals a bug in the contract code, you must fix the code and deploy a new session. You cannot modify the contract in an existing session.
- **State accumulation:** Each successful call modifies the session's ledger state. Subsequent calls execute against the updated state. Failed calls (assertion failures, errors) do NOT modify state.

### 3. `witness-management.md`

**Purpose:** How to provide and override witnesses during simulation.

**Content:**

- **When to use:** When testing circuits that use witnesses, or when you need to control witness return values for edge-case testing.
- **Background:** In Compact, `witness` declarations define functions whose implementations live in TypeScript on the prover side. During simulation, the OZ simulator provides a witness execution environment. You can override individual witnesses to return specific values.
- **The `witnessOverrides` parameter:** A Record mapping witness names to return values. When a circuit calls a witness, the simulator uses the override value instead of the default implementation.
- **Inline example — providing a witness override:** Show a circuit that calls `witness getSecret(): Field;`, call with `witnessOverrides: { "getSecret": "42" }`, show the circuit executing with that value
- **Inline example — testing authorization rejection:** Show a circuit with `witness isAuthorized(): Boolean;`, call with `witnessOverrides: { "isAuthorized": "false" }`, show assertion failure
- **Default witness behavior:** When no override is provided, the simulator uses the default witness factory from the compiled artifacts. If no default exists, the witness returns a zero/empty value for its type.
- **Testing edge cases with witnesses:**
  - Provide boundary values (max uint, empty bytes)
  - Provide values that should trigger assertions
  - Test the happy path and the rejection path separately
- **Anti-patterns:**
  - Overriding witnesses that the circuit doesn't actually call (no effect, confusing)
  - Providing wrong-typed witness overrides (will cause a runtime type error)
  - Not testing both the valid and invalid witness paths

### 4. `caller-context.md`

**Purpose:** Multi-user simulation via the caller parameter.

**Content:**

- **When to use:** When testing access control, ownership, token transfers between users, or any multi-party interaction.
- **The `caller` parameter:** Available on both deploy and call. Sets the identity of the transaction sender. When a circuit checks the caller (e.g., `assert(caller == owner)`), the simulator uses this value.
- **Inline example — ownership check:** Deploy with `caller: "alice"`, call an owner-only circuit as `caller: "alice"` (succeeds), call the same circuit as `caller: "bob"` (assertion failure)
- **Inline example — token transfer:** Deploy as Alice, Alice mints tokens, Alice transfers to Bob (with `caller: "alice"`), Bob checks balance (with `caller: "bob"`)
- **Deploy caller vs call caller:** The `caller` on deploy sets the contract creator/owner. The `caller` on call sets the transaction sender for that specific call. They can differ.
- **Multi-party workflows:** Alternate `caller` between calls to simulate interactions between different users. The session maintains one shared state — all callers operate on the same ledger.
- **Anti-patterns:**
  - Forgetting to set `caller` when testing access control (defaults may not match expected owner)
  - Using the same caller for all calls when testing multi-party logic
  - Assuming caller values are validated (they're arbitrary strings in simulation)

### 5. `state-inspection.md`

**Purpose:** How to read and interpret simulation session state.

**Content:**

- **When to use:** After deploying, between circuit calls, or at the end of a test sequence to verify outcomes.
- **The state response structure:**
  - `ledgerState` — current values for ALL ledger fields, keyed by field name, each with `type` and `value`
  - `circuits` — metadata for all exported circuits (name, isPublic, isPure, parameters with types, returnType, readsLedger, writesLedger)
  - `callHistory` — ordered array of all circuit calls made in this session, each with circuit name, arguments, caller, timestamp, stateChanges, and result
  - `expiresAt` — when the session will expire if inactive
- **Reading ledger state by type:**
  - `Counter`: numeric string, e.g., `"5"`
  - `Map<K, V>`: JSON-encoded map, e.g., `{"0xabc": "100"}`
  - `Set<T>`: JSON-encoded set, e.g., `["0xabc", "0xdef"]`
  - `MerkleTree<T, D>`: root hash and membership data
  - `Uint<N>`, `Field`, `Bytes<N>`: string representations of their values
  - `Boolean`: `"true"` or `"false"`
- **Using circuit metadata:** Before calling a circuit, check its `parameters` to know what arguments it expects and their types. Check `readsLedger` and `writesLedger` to understand what state it will access.
- **Analyzing call history:** The call history is an audit trail. Use it to verify that a specific sequence of operations occurred, to check what state changes each call produced, and to debug unexpected state.
- **Inline example — state before and after:** Show state with a Counter at 0, then after two increment calls, Counter at the expected sum. Show the callHistory with both calls and their stateChanges.
- **The state verification pattern:** Call circuit → Call state → Compare actual values against expected values. This is the fundamental testing loop.

### 6. `session-management.md`

**Purpose:** Managing the simulation session lifecycle.

**Content:**

- **When to use:** When you need to understand session behavior, handle expiry, or manage resources.
- **Session creation:** Happens on deploy. Involves compilation (~1-5s), so it's not instant. Each session consumes server resources (compiled artifacts + simulator instance in memory).
- **TTL and inactivity:** Sessions expire after 15 minutes of inactivity. Each call or state request refreshes the TTL. The TTL is inactivity-based, not absolute.
- **Capacity limit:** ~100 concurrent sessions. If capacity is exceeded, deploy returns a `CAPACITY_EXCEEDED` error.
- **Detecting expired sessions:** Any operation on an expired session returns `SESSION_NOT_FOUND`. The session cannot be recovered — you must deploy a new one.
- **Recovering from expiry:** Deploy a new session with the same code, then replay the call sequence to reach the desired state. This costs compilation time + call time. Keep sessions alive during active testing.
- **Cleanup discipline:** Always call `midnight-simulate-delete` when done. Abandoned sessions consume resources until they expire. If testing multiple contracts, delete each session before deploying the next.
- **Inline example — session lifecycle:** Deploy → 3 calls → state check → delete. Show the full sequence.
- **Rate limit awareness:** Deploy is the most expensive operation (compilation). Plan your testing so you deploy once and make multiple calls, rather than redeploying for each test case. If you need to test different code versions, use `mcp-compile` multi-version first, then deploy the one that compiles.

### 7. `error-recovery.md`

**Purpose:** Error routing hub for simulation failures.

**Content:**

- **When to use:** After any failed simulation operation.
- **Reading error responses:** All errors include `success: false` and an `errors` array with `message`, `severity`, and optional `errorCode`.
- **Error category routing table:**

  | Error Pattern | Category | Example File |
  |---------------|----------|-------------|
  | Compiler errors during deploy (syntax, type, etc.) | Deployment error | `examples/deployment-errors.md` |
  | `SESSION_NOT_FOUND` | Session error | `examples/session-errors.md` |
  | `CIRCUIT_NOT_FOUND` / parameter type mismatch | Execution error | `examples/execution-errors.md` |
  | Assertion failure (`assert()` triggered) | Execution error | `examples/execution-errors.md` |
  | Witness not provided / wrong type | Witness error | `examples/witness-errors.md` |
  | `CAPACITY_EXCEEDED` / HTTP 429 | Capacity error | `examples/capacity-errors.md` |

- **Load only the example file matching your error.** Do not load all example files.
- **The recovery loop:** Read all errors → match category → load example file → fix → retry. For deploy errors, fix the code and redeploy. For call errors, fix the call parameters and retry.
- **Cross-reference:** Deploy compilation errors use the same compiler as `mcp-compile`. For detailed compiler error guidance, see `mcp-compile` error recovery reference.

### 8. `testing-patterns.md`

**Purpose:** How to design effective simulation test sequences.

**Content:**

- **When to use:** When planning a testing strategy for a contract.
- **Sequential workflow testing:** Deploy → call circuits in a logical order → verify state after each call. This tests the happy path. End section with `**Examples:** \`examples/sequential-testing.md\``
- **Assertion testing:** Deliberately trigger assertion failures to verify that guard logic works correctly. Call circuits with invalid inputs, unauthorized callers, or edge-case witness values. Verify that the assertion fires and state is unchanged. End section with `**Examples:** \`examples/assertion-testing.md\``
- **State verification:** After each significant operation, call `midnight-simulate-state` and compare actual values against expected values. Check specific ledger fields, not just success/failure. End section with `**Examples:** \`examples/state-verification.md\``
- **Multi-user interaction testing:** Use the `caller` parameter to simulate interactions between different parties. Test ownership checks, transfers, approvals, and multi-party protocols. End section with `**Examples:** \`examples/multi-user-testing.md\``
- **Regression testing:** Define a known sequence of calls that should produce a known final state. Deploy, replay the sequence, compare final state. Useful for verifying that code changes don't break existing behavior.
- **The compile-then-simulate pattern:** Before deploying, run the code through `mcp-compile` (skipZk) to catch compilation errors cheaply. Then deploy for simulation. This separates "does it compile?" from "does it behave correctly?"
- **Contract archetype examples:** For complete end-to-end test sequences, see the archetype examples: `examples/counter-contract.md`, `examples/token-contract.md`, `examples/voting-contract.md`, `examples/access-control-contract.md`

### 9. `server-enhanced.md`

**Purpose:** Future capabilities requiring playground changes beyond the OZ integration.

**Content (3 items):**

1. **Session Snapshots** — Save and restore session state at named checkpoints. Would enable branching test scenarios (test different paths from the same starting state without replaying calls). Server change: add `POST /simulate/:id/snapshot` and `POST /simulate/:id/restore/:snapshotId`. Plugin change: add snapshot guidance to `session-management.md` and `testing-patterns.md`.

2. **Scenario Files** — Accept a pre-written sequence of calls as a single request, returning all intermediate and final states. Would reduce round-trips for regression testing. Server change: add `POST /simulate/scenario` that takes code + call sequence, returns results for each step. Plugin change: add scenario-based testing to `testing-patterns.md`.

3. **Diff-Based State Comparison** — Return a structured diff between two session states or between two points in the same session's history. Would simplify state verification. Server change: add `GET /simulate/:id/diff?from=callIndex&to=callIndex`. Plugin change: add diff-based verification to `state-inspection.md`.

Each gets a GitHub issue on `devrelaicom/compact-playground`.

## Error Example File Specifications

All examples live in `skills/mcp-simulate/examples/`. No YAML frontmatter. Template: `# [Category] Examples` → `## When This Error Occurs` → `## Examples` (before/after pairs with error/diagnosis/fix) → `## Anti-Patterns`.

### 1. `deployment-errors.md`

**Title:** Deployment Error Examples

**When this error occurs:** Contract code fails compilation during `midnight-simulate-deploy`. The simulator cannot create a session because the code doesn't compile.

**Examples (4-5 before/after pairs):**

1. **Parse error in contract code:** Error: `expected ';' but found '{'`. Diagnosis: common Compact syntax issues (Void return type, deprecated ledger block, etc.). Fix: correct the syntax. Cross-reference: `mcp-compile` examples/parse-errors.md for detailed parse error guidance.

2. **Type error in contract code:** Error: `no matching overload`. Diagnosis: type mismatch in circuit body. Fix: correct the types. Cross-reference: `mcp-compile` examples/type-errors.md.

3. **Missing import:** Error: unbound identifier for stdlib type. Diagnosis: code lacks `import CompactStandardLibrary;`. Fix: add the import (or let auto-wrapping handle it for snippets).

4. **Disclosure error:** Error: `potential witness-value disclosure must be declared`. Diagnosis: witness value flows to public state without `disclose()`. Fix: add `disclose()` at the boundary. Cross-reference: `mcp-compile` examples/disclosure-errors.md.

5. **Empty code:** Error: "Contract code is required". Diagnosis: empty string or whitespace passed as code. Fix: provide actual Compact source.

**Anti-patterns (2-3):**
- Modifying the code in response to a deployment error without reading the compiler error (the error tells you exactly what's wrong)
- Redeploying the same code hoping for a different result (compilation is deterministic)
- Not cross-referencing `mcp-compile` error examples (deploy errors ARE compiler errors — the same guidance applies)

### 2. `session-errors.md`

**Title:** Session Error Examples

**When this error occurs:** A session operation (`call`, `state`, or `delete`) fails because the session no longer exists.

**Examples (3-4 before/after pairs):**

1. **Session expired due to inactivity:** Error: `SESSION_NOT_FOUND` after 15+ minutes of no activity. Diagnosis: TTL expired. Fix: redeploy and replay call sequence.

2. **Wrong session ID:** Error: `SESSION_NOT_FOUND` immediately after deploy. Diagnosis: session ID was not stored correctly or was overwritten. Fix: store the sessionId from deploy response and use it consistently.

3. **Session deleted but still referenced:** Error: `SESSION_NOT_FOUND` after calling delete. Diagnosis: tried to use a session after explicitly deleting it. Fix: deploy a new session if more testing is needed.

4. **Proactive TTL management:** Not an error per se — show the pattern of checking `expiresAt` in state responses and redeploying before expiry during long testing sessions.

**Anti-patterns (2-3):**
- Trying to recover an expired session (impossible — the state is gone, you must redeploy)
- Not storing the sessionId immediately after deploy
- Leaving sessions open and being surprised when they expire (the 15-minute TTL is inactivity-based — any call or state request resets it)

### 3. `execution-errors.md`

**Title:** Execution Error Examples

**When this error occurs:** A circuit call (`midnight-simulate-call`) fails during execution — the circuit was found but execution produced an error.

**Examples (4-5 before/after pairs):**

1. **Assertion failure:** Error: assertion message from the contract's `assert()` statement. Diagnosis: the circuit's guard condition was not met. State is unchanged. Fix: understand why the assertion fired — check caller, arguments, current state. This may be expected behavior (testing that guards work) or a bug in the test sequence.

2. **Circuit not found:** Error: `CIRCUIT_NOT_FOUND` with list of available circuits. Diagnosis: typo in circuit name, or calling a non-exported circuit. Fix: check the name against `circuits` in the deploy response or state.

3. **Parameter type mismatch:** Error: runtime type error when circuit receives wrong-typed argument. Diagnosis: passed a value that doesn't match the circuit's parameter type. Fix: check the circuit's parameter types in metadata, format the value correctly.

4. **Missing required parameter:** Error: circuit expected N arguments but received M. Diagnosis: didn't provide all required parameters. Fix: check circuit metadata for required parameters.

5. **Calling impure circuit that modifies state it can't access:** Error: runtime error from ledger operation. Diagnosis: the circuit tries to modify a ledger field in a way that's invalid given current state. Fix: check current state and ensure preconditions are met.

**Anti-patterns (2-3):**
- Treating assertion failures as bugs in the simulator (they're usually correct behavior — the contract is doing its job)
- Not checking circuit metadata before calling (the metadata tells you exactly what arguments to provide)
- Assuming a failed call modified state (failed calls do NOT modify ledger state)

### 4. `witness-errors.md`

**Title:** Witness Error Examples

**When this error occurs:** A circuit call fails because of a witness-related issue.

**Examples (3 before/after pairs):**

1. **Witness not provided:** Error: witness function returned no value. Diagnosis: the circuit calls a witness but no override was provided and no default implementation exists. Fix: provide a `witnessOverrides` value for the required witness.

2. **Witness returns wrong type:** Error: type mismatch from witness return. Diagnosis: the witness override value doesn't match the declared witness return type. Fix: check the witness declaration in the contract code, provide a correctly-typed value.

3. **Witness override triggers downstream assertion:** Error: assertion failure after witness returns. Diagnosis: the witness value was accepted but caused an assertion failure later in the circuit logic. This is often intentional — testing that the circuit correctly rejects bad witness values. Fix: if testing rejection, this is expected. If testing the happy path, provide a valid witness value.

**Anti-patterns (2):**
- Overriding witnesses that don't exist in the contract (the override is silently ignored — no error, but no effect)
- Not testing both valid and invalid witness paths (testing only the happy path misses critical guard behavior)

### 5. `capacity-errors.md`

**Title:** Capacity and Rate Limit Error Examples

**When this error occurs:** Server resource limits are hit.

**Examples (3 before/after pairs):**

1. **Capacity exceeded:** Error: `CAPACITY_EXCEEDED` — too many active sessions. Diagnosis: ~100 concurrent session limit reached. Fix: delete old sessions with `midnight-simulate-delete`, then retry deploy. If the sessions aren't yours (shared server), wait and retry.

2. **Rate limit (429):** Error: HTTP 429 rate limit exceeded. Diagnosis: too many requests in the 60-second window. Fix: wait for the window to reset. Batch your testing — deploy once, make multiple calls. Don't redeploy for each test case.

3. **Deploy is expensive — budget accordingly:** Show a pattern where rapid-fire deploys hit rate limits, vs a pattern where one deploy + many calls stays under limits. Deploy costs compilation time (~1-5s) AND a rate limit slot.

**Anti-patterns (2):**
- Redeploying for each test case instead of using one session with multiple calls (wastes rate limit budget and time)
- Not cleaning up sessions after testing (abandoned sessions block others from deploying)

## Testing Pattern Example File Specifications

Template: `# [Name] Examples` → `## When to Apply` → `## Examples` (3-5 complete sequences) → `## Anti-Patterns` (2-3).

### 6. `sequential-testing.md`

**Title:** Sequential Testing Examples

**When to apply:** When testing a multi-step workflow where each circuit call builds on the previous state.

**Examples (3-4 complete deploy→call→verify sequences):**

1. **Counter increment sequence:** Deploy counter contract → call `inc(5)` → verify state (Counter=5) → call `inc(3)` → verify state (Counter=8) → call `get()` (pure) → verify return value matches ledger state
2. **Initialize-then-operate pattern:** Deploy contract → call `init()` with constructor-like setup → call business logic circuits → verify final state
3. **Ordered operations with dependencies:** Deploy token contract → mint tokens → transfer tokens → verify sender balance decreased and receiver balance increased

**Anti-patterns:**
- Making calls without verifying state between them (you won't catch where things went wrong)
- Not planning the call sequence before executing (ad-hoc testing is less effective)
- Deploying a new session for each step instead of using the accumulated state

### 7. `assertion-testing.md`

**Title:** Assertion Testing Examples

**When to apply:** When you want to verify that a contract's guard logic correctly rejects invalid operations.

**Examples (3-5 before/after pairs):**

1. **Testing authorization rejection:** Deploy contract with owner="alice" → call restricted circuit as caller="bob" → verify assertion fires → verify state unchanged → call same circuit as caller="alice" → verify success
2. **Testing insufficient balance:** Deploy token contract → mint 100 tokens → attempt transfer of 200 → verify assertion failure → verify balance unchanged
3. **Testing input validation:** Deploy contract → call with out-of-range parameter → verify assertion → call with valid parameter → verify success
4. **Testing post-condition assertion:** Deploy contract → call circuit where the result would violate an invariant → verify the assertion catches it

**Anti-patterns:**
- Not verifying that state is unchanged after an assertion failure (this is the critical check)
- Only testing happy paths (assertion testing is specifically about the unhappy paths)
- Confusing assertion failures with bugs (a deliberate assertion failure is the contract working correctly)

### 8. `state-verification.md`

**Title:** State Verification Examples

**When to apply:** When you need to compare actual ledger state against expected values.

**Examples (3-5 complete verification sequences):**

1. **Counter arithmetic verification:** After 3 increment calls with values 5, 3, 7 → verify Counter = 15 (not just "some number")
2. **Map state verification:** Deploy with empty Map → insert key-value → verify Map contains entry → insert another → verify both entries → remove first → verify only second remains
3. **Multi-field verification:** Deploy contract with Counter + Map → call circuit that modifies both → verify BOTH fields changed correctly (not just one)
4. **Unchanged field verification:** Call a circuit that modifies field A → verify field A changed → verify field B did NOT change (important for detecting unintended side effects)

**Anti-patterns:**
- Checking only `success: true` without inspecting actual state values (success means "no error", not "correct result")
- Verifying only the fields you expect to change (also check that other fields DIDN'T change)
- Not verifying state after error cases (state should be unchanged after failures)

### 9. `multi-user-testing.md`

**Title:** Multi-User Testing Examples

**When to apply:** When testing interactions between different parties — ownership, transfers, approvals, voting.

**Examples (3-5 complete multi-caller sequences):**

1. **Ownership transfer:** Deploy as Alice (owner) → Alice transfers ownership to Bob → Bob calls owner-only circuit (succeeds) → Alice calls owner-only circuit (now fails)
2. **Token transfer between users:** Deploy as Alice → Alice mints 100 → Alice transfers 30 to Bob → verify Alice=70, Bob=30 → Bob transfers 10 to Charlie → verify Alice=70, Bob=20, Charlie=10
3. **Access control with multiple roles:** Deploy → set Alice as admin, Bob as user → Admin calls admin-only circuit (succeeds) → User calls admin-only circuit (fails) → Admin grants user admin role → User retries (succeeds)

**Anti-patterns:**
- Using the same caller for all calls in a multi-user test (defeats the purpose)
- Not testing both authorized and unauthorized calls (always test both paths)
- Forgetting that caller values are strings — consistency matters ("alice" vs "Alice" are different callers)

## Contract Archetype Example File Specifications

Template: `# [Name] Contract Archetype` → `## Contract Code` (complete Compact source) → `## Simulation Sequence` (step-by-step deploy→call→verify) → `## What This Tests` → `## Limitations` (what simulation can/cannot verify for this pattern).

### 10. `counter-contract.md`

**Title:** Counter Contract Archetype

**Contract:** A simple contract with a Counter ledger field, increment/decrement circuits, and a read circuit. This is the baseline archetype — simulation handles it perfectly.

**Simulation sequence:** Deploy → state (verify Counter=0) → inc(5) → state (verify Counter=5) → inc(3) → state (verify Counter=8) → get() (verify return=8) → delete

**What this tests:** Basic state mutation, pure vs impure circuits, return values, state accumulation across calls.

### 11. `token-contract.md`

**Title:** Token Contract Archetype

**Contract:** A token contract with mint, transfer, and balance circuits. Uses Counter or Map for balance tracking, access control for minting.

**Simulation sequence:** Deploy as owner → mint(100) as owner → state (verify balance=100) → transfer(30, bob) as owner → state (verify owner=70, bob=30) → mint(50) as bob (verify assertion failure — owner-only) → state (verify unchanged) → delete

**What this tests:** Access control via caller context, multi-field state mutations, assertion testing, multi-user interaction.

### 12. `voting-contract.md`

**Title:** Voting Contract Archetype

**Contract:** A voting contract with vote, close, and tally circuits. Uses Counter for tally, Set or Map for voter tracking, Boolean for voting-open state.

**Simulation sequence:** Deploy → vote(optionA) as alice → vote(optionB) as bob → vote(optionA) as charlie → vote(optionA) as alice (verify assertion — already voted) → close() as owner → tally() (verify optionA=2, optionB=1) → vote(optionA) as dave (verify assertion — voting closed) → delete

**What this tests:** Set membership (voter tracking), assertion on duplicate votes, state transitions (open→closed), tallying, multi-user voting.

### 13. `access-control-contract.md`

**Title:** Access Control Contract Archetype

**Contract:** A contract with owner-only and public circuits, ownership transfer, and role-based access. Uses Bytes for owner address, potentially Map for roles.

**Simulation sequence:** Deploy as alice → call owner-only circuit as alice (succeeds) → call owner-only circuit as bob (assertion failure) → transfer ownership to bob as alice → call owner-only circuit as bob (succeeds) → call owner-only circuit as alice (assertion failure) → delete

**What this tests:** Ownership verification via caller context, ownership transfer, assertion testing for unauthorized access, state verification that ownership change persists.

## Slash Command Specification

**File:** `commands/simulate.md`

### Frontmatter

```yaml
description: Simulate Compact contracts interactively — deploy, call circuits, inspect state, and verify behavior with preset testing modes and witness/caller control
allowed-tools: AskUserQuestion, Read, Glob, Grep, mcp__midnight__midnight-simulate-deploy, mcp__midnight__midnight-simulate-call, mcp__midnight__midnight-simulate-state, mcp__midnight__midnight-simulate-delete, mcp__midnight__midnight-compile-contract
argument-hint: [<code-or-file>] [--explore | --test-sequence | --regression | --assertions] [--caller <address>] [--cleanup] [--version <ver>] [--witness <name>=<value>] [--compile-first]
```

### Modes

| Mode | Invocation | Behavior |
|------|-----------|----------|
| Interactive | `/midnight-mcp:simulate` | Guided session — asks what to test, deploys, walks through calls |
| Quick | `/midnight-mcp:simulate <code-or-file>` | Deploy and show structure (circuits + initial state) |
| Explicit | `/midnight-mcp:simulate <code> --test-sequence` | User-specified flags |

### Preset Flags

| Preset | Activates |
|--------|-----------|
| `--explore` | Deploy + state inspection, show circuits and ledger structure, list available circuits with signatures |
| `--test-sequence` | Guided multi-step: deploy, prompt for each circuit call, verify state between calls, cleanup at end |
| `--regression` | Deploy + prompt for or read a known call sequence, execute all calls, compare final state against expected |
| `--assertions` | Deploy + systematically test each exported circuit's assertion paths (call with invalid args, unauthorized callers, edge cases) |

### Modifier Flags

| Flag | Effect |
|------|--------|
| `--caller <address>` | Set default caller for all calls |
| `--cleanup` | Auto-delete session when done |
| `--version <ver>` | Compiler version for deploy |
| `--witness <name>=<value>` | Provide witness override (repeatable for multiple witnesses) |
| `--compile-first` | Run through `mcp-compile` (skipZk) before deploying, catching compile errors before spending a deploy |

No flags with code/file: `--explore`. No flags, no code: interactive mode.

### Command Steps

1. **Parse arguments and flags** — extract code (inline or from file path), preset, modifier flags
2. **Interactive mode** (if no arguments) — guided Q&A: what contract? what do you want to test? manual or automated?
3. **Load skill references** — based on preset, load relevant references and example files
4. **Pre-deploy validation** (if `--compile-first`) — run through `mcp-compile` with skipZk, report any errors before deploying
5. **Deploy** — call `midnight-simulate-deploy` with code and optional version
6. **Execute preset workflow:**
   - `--explore`: call state, present circuits and ledger structure
   - `--test-sequence`: loop of prompted calls with state verification
   - `--regression`: execute call sequence, verify final state
   - `--assertions`: for each circuit, test boundary/rejection cases
7. **Cleanup** (if `--cleanup` or end of workflow) — call `midnight-simulate-delete`
8. **Present results** — summary of what was tested, pass/fail for each step, any issues found

## GitHub Issues (Server-Enhanced)

3 issues on `devrelaicom/compact-playground`:

1. **Session Snapshots** — `feat: add session snapshot/restore for branching test scenarios`
2. **Scenario Files** — `feat: add batch scenario execution for regression testing`
3. **Diff-Based State Comparison** — `feat: add structured state diff between call history points`

## File Inventory

| # | Path (relative to `plugins/midnight-mcp/`) | Action |
|---|---------------------------------------------|--------|
| 1 | `skills/mcp-simulate/SKILL.md` | Rewrite |
| 2 | `skills/mcp-simulate/references/deploy-workflows.md` | Create |
| 3 | `skills/mcp-simulate/references/circuit-execution.md` | Create |
| 4 | `skills/mcp-simulate/references/witness-management.md` | Create |
| 5 | `skills/mcp-simulate/references/caller-context.md` | Create |
| 6 | `skills/mcp-simulate/references/state-inspection.md` | Create |
| 7 | `skills/mcp-simulate/references/session-management.md` | Create |
| 8 | `skills/mcp-simulate/references/error-recovery.md` | Create |
| 9 | `skills/mcp-simulate/references/testing-patterns.md` | Create |
| 10 | `skills/mcp-simulate/references/server-enhanced.md` | Create |
| 11 | `skills/mcp-simulate/examples/deployment-errors.md` | Create |
| 12 | `skills/mcp-simulate/examples/session-errors.md` | Create |
| 13 | `skills/mcp-simulate/examples/execution-errors.md` | Create |
| 14 | `skills/mcp-simulate/examples/witness-errors.md` | Create |
| 15 | `skills/mcp-simulate/examples/capacity-errors.md` | Create |
| 16 | `skills/mcp-simulate/examples/sequential-testing.md` | Create |
| 17 | `skills/mcp-simulate/examples/assertion-testing.md` | Create |
| 18 | `skills/mcp-simulate/examples/state-verification.md` | Create |
| 19 | `skills/mcp-simulate/examples/multi-user-testing.md` | Create |
| 20 | `skills/mcp-simulate/examples/counter-contract.md` | Create |
| 21 | `skills/mcp-simulate/examples/token-contract.md` | Create |
| 22 | `skills/mcp-simulate/examples/voting-contract.md` | Create |
| 23 | `skills/mcp-simulate/examples/access-control-contract.md` | Create |
| 24 | `commands/simulate.md` | Create |

**Total: 24 files (1 rewrite, 23 create) + 3 GitHub issues**
