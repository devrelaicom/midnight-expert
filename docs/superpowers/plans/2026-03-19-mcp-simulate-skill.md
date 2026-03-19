# MCP Simulate Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the `mcp-simulate` skill with workflow-oriented references, error and testing pattern examples, contract archetype examples, and a `/midnight-mcp:simulate` slash command — matching the richness of the `mcp-search` and `mcp-compile` skills.

**Architecture:** SKILL.md (bail-out gate + intent routing table), 9 workflow references with inline examples, 13 example files (5 error, 4 testing pattern, 4 contract archetype), and a slash command with preset modes. All content assumes the OZ simulator integration ([compact-playground#17](https://github.com/devrelaicom/compact-playground/issues/17)) is complete.

**Tech Stack:** Markdown content files within the Claude Code plugin system. GitHub CLI for issue creation. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-19-mcp-simulate-skill-design.md`

---

## Dependency Graph

```
Task 1 (SKILL.md) ──────────────────────────────────────────────────────┐
  │                                                                      │
  ├── Task 2 (deploy-workflows reference)                    ──┐         │
  ├── Task 3 (circuit-execution reference)                   ──┤         │
  ├── Task 4 (witness-management reference)                  ──┤         │
  ├── Task 5 (caller-context reference)                      ──┤         │
  ├── Task 6 (state-inspection reference)                    ──┤         │
  ├── Task 7 (session-management reference)                  ──┤── All ── Task 13 (Integration)
  ├── Task 8 (error-recovery reference + 5 error examples)   ──┤
  ├── Task 9 (testing-patterns reference + 4 pattern examples)──┤
  ├── Task 10 (4 contract archetype examples)                ──┘
  │
  ├── Task 11 (server-enhanced reference) ── Task 12 (GitHub Issues) ─── Task 13 (Integration)
  │
  └── Task 13.5 (Slash Command) ──────────────────────────────────────── Task 13 (Integration)
```

Tasks 2-10 are independent of each other and CAN run in parallel.
Task 11 and Task 13.5 are independent of Tasks 2-10 and CAN run in parallel with them.
Task 12 depends on Task 11.
Task 13 depends on all other tasks.

## Conventions

All paths in this plan are relative to `plugins/midnight-mcp/` unless stated otherwise.

**Reference file conventions** (from existing codebase patterns):
- No YAML frontmatter — references are plain markdown
- Start with `# Title` heading
- Concise, operational tone — instructions the LLM executes, not explanations
- Inline examples where appropriate (code blocks with parameter/response examples)

**Error example file conventions** (from spec):
- No YAML frontmatter
- Template: `# [Category] Examples` → `## When This Error Occurs` → `## Examples` (before/after pairs with error/diagnosis/fix) → `## Anti-Patterns`
- Error messages shown as they appear in the response `errors` array

**Testing pattern example file conventions** (from spec):
- No YAML frontmatter
- Template: `# [Name] Examples` → `## When to Apply` → `## Examples` (3-5 complete sequences) → `## Anti-Patterns` (2-3 mandatory)
- Scenario labels are concrete Midnight tasks
- All content uses real Midnight terminology, tool names, parameter values

**Contract archetype example file conventions** (from spec):
- No YAML frontmatter
- Template: `# [Name] Contract Archetype` → `## Contract Code` (complete Compact source) → `## Simulation Sequence` (step-by-step deploy→call→verify) → `## What This Tests` → `## Limitations`
- Complete, compilable Compact source code

**Command file conventions** (from existing commands like `devnet.md`, `doctor.md`):
- YAML frontmatter with `description`, `allowed-tools`, `argument-hint`
- Step-by-step instructions the LLM follows
- Delegated to MCP tools where applicable

---

### Task 1: Rewrite SKILL.md

**Files:**
- Modify: `skills/mcp-simulate/SKILL.md`

- [ ] **Step 1: Read the current SKILL.md**

Read `skills/mcp-simulate/SKILL.md` to confirm current content before overwriting.

- [ ] **Step 2: Create directories**

```bash
mkdir -p plugins/midnight-mcp/skills/mcp-simulate/references
mkdir -p plugins/midnight-mcp/skills/mcp-simulate/examples
mkdir -p plugins/midnight-mcp/commands
```

- [ ] **Step 3: Write the new SKILL.md**

Replace the entire file with:

```markdown
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
```

- [ ] **Step 4: Verify the SKILL.md**

Read back the file and confirm:
- Frontmatter has `name` and `description` fields with simulation-related trigger words
- Bail-out table is the first content after the title
- Routing table has 8 rows mapping intents to reference files
- All 9 reference file paths are mentioned (7 in routing table + `error-recovery.md` in preamble + `server-enhanced.md` is not in routing since it's loaded by explicit intent)
- Rate limits section is present
- Command documentation covers all modes, flags, presets
- Cross-references section is present

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/SKILL.md
git commit -m "feat(mcp-simulate): rewrite SKILL.md with bail-out gate, intent routing, and OZ simulator documentation"
```

---

### Task 2: Deploy Workflows Reference

**Files:**
- Create: `skills/mcp-simulate/references/deploy-workflows.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/deploy-workflows.md`**

This is the entry point for all simulation — every session starts with a deploy. The reference covers the compile-then-deploy pipeline.

Content to include:

**When to use:** Starting any simulation. This is always the first step.

**The deploy-compile pipeline:** Deploy now compiles the contract before initializing the simulator. This takes ~1-5s (with skipZk). If compilation fails, the deploy fails with compiler errors — cross-reference `mcp-compile` error recovery for diagnosis.

**Parameters:**
- `code`: the Compact source code (required)
- `version`: compiler version (optional — same behavior as `mcp-compile`: `"detect"` resolves from pragma, specific version string, or omit for latest)
- `constructorArgs`: arguments for the contract constructor (optional — must match constructor signature)
- `caller`: caller identity for the deploy transaction (optional — sets contract creator/owner)

**Inline example — successful deploy:**
```
Call: midnight-simulate-deploy({ code: "<compact source>" })
Response: {
  success: true,
  sessionId: "abc-123-def",
  circuits: [
    {
      name: "inc",
      isPublic: true,
      isPure: false,
      parameters: [{ name: "n", type: "Uint<64>" }],
      returnType: "[]",
      readsLedger: ["count"],
      writesLedger: ["count"]
    },
    {
      name: "get",
      isPublic: true,
      isPure: true,
      parameters: [],
      returnType: "Uint<64>",
      readsLedger: ["count"],
      writesLedger: []
    }
  ],
  ledgerState: {
    count: { type: "Counter", value: "0" }
  },
  expiresAt: "2026-03-19T15:15:00Z"
}
Action: Store sessionId. Inspect circuits to plan your test sequence.
```

**Inline example — failed deploy (compilation error):**
```
Call: midnight-simulate-deploy({ code: "export circuit bad(): Void { }" })
Response: {
  success: false,
  errors: [{
    message: "expected ';' but found '{'",
    severity: "error",
    line: 1,
    column: 35
  }]
}
Action: Load references/error-recovery.md to diagnose. This is a compiler error — see mcp-compile error recovery for detailed guidance.
```

**Interpreting the deploy response:**
- `circuits` tells you what you can call, what arguments each circuit takes, and which ledger fields it affects
- `ledgerState` shows initial values for all ledger fields (Counter starts at 0, Map starts empty, etc.)
- `sessionId` is required for ALL subsequent operations — store it
- `expiresAt` tells you when the session will expire if inactive (15 minutes from last activity)

**Version selection:** Same version semantics as `mcp-compile` — `"detect"` resolves from pragma, specific version string, or omit for latest.

**The deploy-then-inspect pattern:** After deploying, call `midnight-simulate-state` to get a full picture of the contract before making any calls. This gives you the circuit signatures and initial state in a single read.

- [ ] **Step 2: Verify the file**

Read back. Confirm it has inline examples for both success and failure cases, parameter documentation, response interpretation guidance, and the deploy-then-inspect pattern.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/deploy-workflows.md
git commit -m "feat(mcp-simulate): add deploy workflows reference"
```

---

### Task 3: Circuit Execution Reference

**Files:**
- Create: `skills/mcp-simulate/references/circuit-execution.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/circuit-execution.md`**

This is the core simulation reference — how to call circuits and interpret results.

Content to include:

**When to use:** After deploying, when you want to execute a circuit.

**Parameters:**
- `sessionId` (required): session ID from deploy
- `circuit` (required): must match an exported circuit name
- `arguments` (optional): keyed by parameter name. The MCP server handles type coercion ([midnight-mcp#20](https://github.com/devrelaicom/midnight-mcp/issues/20))
- `caller` (optional): see `references/caller-context.md`
- `witnessOverrides` (optional): see `references/witness-management.md`

**Parameter formatting by type:**
- `Uint<N>`: string representation of the integer, e.g., `"42"`, `"0"`
- `Field`: string representation, e.g., `"12345"`
- `Bytes<N>`: hex string, e.g., `"0x1a2b3c..."`
- `Boolean`: `"true"` or `"false"`
- Compound types: JSON-encoded where applicable

Note: The MCP server handles type coercion, so passing raw values (e.g., `42` instead of `"42"`) should also work.

**Inline example — successful call with state changes:**
```
Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "inc",
  arguments: { n: "5" }
})
Response: {
  success: true,
  result: null,
  stateChanges: [
    { field: "count", operation: "increment", previousValue: "0", newValue: "5" }
  ],
  updatedLedger: {
    count: { type: "Counter", value: "5" }
  }
}
Action: Counter incremented from 0 to 5. State changes confirm the mutation.
```

**Inline example — pure circuit call:**
```
Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "get"
})
Response: {
  success: true,
  result: "5",
  stateChanges: [],
  updatedLedger: {
    count: { type: "Counter", value: "5" }
  }
}
Action: Pure circuit returned 5. No state changes (read-only).
```

**Inline example — assertion failure:**
```
Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "transferOwnership",
  arguments: { newOwner: "0xbob" },
  caller: "eve"
})
Response: {
  success: false,
  errors: [{
    message: "Assertion failed: caller must be owner",
    severity: "error"
  }],
  updatedLedger: {
    owner: { type: "Bytes<32>", value: "0xalice" }
  }
}
Action: Assertion fired — caller "eve" is not the owner. Ledger unchanged. This may be expected behavior (testing guards) or indicate wrong caller.
```

**Understanding stateChanges:** Each entry shows which field changed, the operation, the previous value, and the new value. For Counters this is increment/decrement. For Maps it's insert/update/remove. For Sets it's add/remove.

**Pure vs impure circuits:** Pure circuits return values without modifying ledger state. Impure circuits may modify state. The `isPure` flag in circuit metadata tells you which.

**The fix-and-redeploy loop:** If a circuit call reveals a bug in the contract code, you must fix the code and deploy a new session. You cannot modify the contract in an existing session.

**State accumulation:** Each successful call modifies the session's ledger state. Subsequent calls execute against the updated state. Failed calls (assertion failures, errors) do NOT modify state.

- [ ] **Step 2: Verify the file**

Read back. Confirm it has inline examples for success, pure circuit, and assertion failure cases, parameter formatting guidance, stateChanges interpretation, and the fix-and-redeploy loop.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/circuit-execution.md
git commit -m "feat(mcp-simulate): add circuit execution reference"
```

---

### Task 4: Witness Management Reference

**Files:**
- Create: `skills/mcp-simulate/references/witness-management.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/witness-management.md`**

Content to include:

**When to use:** When testing circuits that use witnesses, or when you need to control witness return values for edge-case testing.

**Background:** In Compact, `witness` declarations define functions whose implementations live in TypeScript on the prover side. During simulation, the OZ simulator provides a witness execution environment. You can override individual witnesses to return specific values.

**The `witnessOverrides` parameter:** A Record mapping witness names to return values. When a circuit calls a witness, the simulator uses the override value instead of the default implementation.

**Inline example — providing a witness override:**
```
Contract code:
  witness getSecret(): Field;
  export circuit reveal(): Field {
    return disclose(getSecret());
  }

Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "reveal",
  witnessOverrides: { "getSecret": "42" }
})
Response: {
  success: true,
  result: "42",
  stateChanges: []
}
Action: Witness returned 42. Circuit executed with that value.
```

**Inline example — testing authorization rejection:**
```
Contract code:
  witness isAuthorized(): Boolean;
  export circuit doRestricted(): [] {
    assert(disclose(isAuthorized()), "Not authorized");
    count.increment(1);
  }

Call: midnight-simulate-call({
  sessionId: "abc-123-def",
  circuit: "doRestricted",
  witnessOverrides: { "isAuthorized": "false" }
})
Response: {
  success: false,
  errors: [{ message: "Assertion failed: Not authorized", severity: "error" }]
}
Action: Assertion fired as expected. Witness override successfully tested the rejection path.
```

**Default witness behavior:** When no override is provided, the simulator uses the default witness factory from the compiled artifacts. If no default exists, the witness returns a zero/empty value for its type.

**Testing edge cases with witnesses:**
- Provide boundary values (max uint, empty bytes)
- Provide values that should trigger assertions
- Test the happy path and the rejection path separately

**Anti-patterns:**
- Overriding witnesses that the circuit doesn't actually call (no effect, confusing)
- Providing wrong-typed witness overrides (will cause a runtime type error)
- Not testing both the valid and invalid witness paths

- [ ] **Step 2: Verify the file**

Read back. Confirm it has inline examples for witness override and authorization rejection, default witness behavior, edge-case testing guidance, and anti-patterns.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/witness-management.md
git commit -m "feat(mcp-simulate): add witness management reference"
```

---

### Task 5: Caller Context Reference

**Files:**
- Create: `skills/mcp-simulate/references/caller-context.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/caller-context.md`**

Content to include:

**When to use:** When testing access control, ownership, token transfers between users, or any multi-party interaction.

**The `caller` parameter:** Available on both deploy and call. Sets the identity of the transaction sender. When a circuit checks the caller (e.g., `assert(caller == owner)`), the simulator uses this value.

**Inline example — ownership check:**
```
Deploy: midnight-simulate-deploy({ code: "<ownable contract>", caller: "alice" })
→ sessionId: "abc-123-def", ledgerState: { owner: { type: "Bytes<32>", value: "alice" } }

Call as owner (succeeds):
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "restricted", caller: "alice" })
  → success: true

Call as non-owner (fails):
  midnight-simulate-call({ sessionId: "abc-123-def", circuit: "restricted", caller: "bob" })
  → success: false, errors: [{ message: "Assertion failed: caller must be owner" }]
```

**Inline example — token transfer:**
```
Deploy as Alice → mint(100) as Alice → transfer(30, "bob") as Alice
→ ledgerState: { balances: { "alice": "70", "bob": "30" } }

Check balance as Bob:
  midnight-simulate-call({ sessionId: "...", circuit: "getBalance", caller: "bob" })
  → result: "30"
```

**Deploy caller vs call caller:** The `caller` on deploy sets the contract creator/owner. The `caller` on call sets the transaction sender for that specific call. They can differ.

**Multi-party workflows:** Alternate `caller` between calls to simulate interactions between different users. The session maintains one shared state — all callers operate on the same ledger.

**Anti-patterns:**
- Forgetting to set `caller` when testing access control (defaults may not match expected owner)
- Using the same caller for all calls when testing multi-party logic
- Assuming caller values are validated (they're arbitrary strings in simulation)

- [ ] **Step 2: Verify the file**

Read back. Confirm it has inline examples for ownership check and token transfer, deploy vs call caller distinction, multi-party guidance, and anti-patterns.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/caller-context.md
git commit -m "feat(mcp-simulate): add caller context reference"
```

---

### Task 6: State Inspection Reference

**Files:**
- Create: `skills/mcp-simulate/references/state-inspection.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/state-inspection.md`**

Content to include:

**When to use:** After deploying, between circuit calls, or at the end of a test sequence to verify outcomes.

**The state response structure:**
- `ledgerState` — current values for ALL ledger fields, keyed by field name, each with `type` and `value`
- `circuits` — metadata for all exported circuits (name, isPublic, isPure, parameters with types, returnType, readsLedger, writesLedger)
- `callHistory` — ordered array of all circuit calls made in this session, each with circuit name, arguments, caller, timestamp, stateChanges, and result
- `expiresAt` — when the session will expire if inactive

**Reading ledger state by type:**
- `Counter`: numeric string, e.g., `"5"`
- `Map<K, V>`: JSON-encoded map, e.g., `{"0xabc": "100"}`
- `Set<T>`: JSON-encoded set, e.g., `["0xabc", "0xdef"]`
- `MerkleTree<T, D>`: root hash and membership data
- `Uint<N>`, `Field`, `Bytes<N>`: string representations of their values
- `Boolean`: `"true"` or `"false"`

**Using circuit metadata:** Before calling a circuit, check its `parameters` to know what arguments it expects and their types. Check `readsLedger` and `writesLedger` to understand what state it will access.

**Analyzing call history:** The call history is an audit trail. Use it to verify that a specific sequence of operations occurred, to check what state changes each call produced, and to debug unexpected state.

**Inline example — state before and after:**
```
State after deploy (before any calls):
  midnight-simulate-state({ sessionId: "abc-123-def" })
  → ledgerState: { count: { type: "Counter", value: "0" } }
    callHistory: []

After two increment calls (inc(5), inc(3)):
  midnight-simulate-state({ sessionId: "abc-123-def" })
  → ledgerState: { count: { type: "Counter", value: "8" } }
    callHistory: [
      { circuit: "inc", arguments: { n: "5" }, stateChanges: [{ field: "count", previousValue: "0", newValue: "5" }] },
      { circuit: "inc", arguments: { n: "3" }, stateChanges: [{ field: "count", previousValue: "5", newValue: "8" }] }
    ]
```

**The state verification pattern:** Call circuit → Call state → Compare actual values against expected values. This is the fundamental testing loop.

- [ ] **Step 2: Verify the file**

Read back. Confirm it has the state response structure, ledger type interpretations, call history analysis, inline example showing before/after state, and the verification pattern.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/state-inspection.md
git commit -m "feat(mcp-simulate): add state inspection reference"
```

---

### Task 7: Session Management Reference

**Files:**
- Create: `skills/mcp-simulate/references/session-management.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/session-management.md`**

Content to include:

**When to use:** When you need to understand session behavior, handle expiry, or manage resources.

**Session creation:** Happens on deploy. Involves compilation (~1-5s), so it's not instant. Each session consumes server resources (compiled artifacts + simulator instance in memory).

**TTL and inactivity:** Sessions expire after 15 minutes of inactivity. Each call or state request refreshes the TTL. The TTL is inactivity-based, not absolute.

**Capacity limit:** ~100 concurrent sessions. If capacity is exceeded, deploy returns a `CAPACITY_EXCEEDED` error.

**Detecting expired sessions:** Any operation on an expired session returns `SESSION_NOT_FOUND`. The session cannot be recovered — you must deploy a new one.

**Recovering from expiry:** Deploy a new session with the same code, then replay the call sequence to reach the desired state. This costs compilation time + call time. Keep sessions alive during active testing.

**Cleanup discipline:** Always call `midnight-simulate-delete` when done. Abandoned sessions consume resources until they expire. If testing multiple contracts, delete each session before deploying the next.

**Inline example — session lifecycle:**
```
1. Deploy: midnight-simulate-deploy({ code: "<contract>" })
   → sessionId: "abc-123-def"

2. Call: midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "5" } })
   → success: true

3. Call: midnight-simulate-call({ sessionId: "abc-123-def", circuit: "inc", arguments: { n: "3" } })
   → success: true

4. State: midnight-simulate-state({ sessionId: "abc-123-def" })
   → ledgerState: { count: { type: "Counter", value: "8" } }

5. Delete: midnight-simulate-delete({ sessionId: "abc-123-def" })
   → success: true
```

**Rate limit awareness:** Deploy is the most expensive operation (compilation). Plan your testing so you deploy once and make multiple calls, rather than redeploying for each test case. If you need to test different code versions, use `mcp-compile` multi-version first, then deploy the one that compiles.

- [ ] **Step 2: Verify the file**

Read back. Confirm it covers session creation, TTL, capacity, expiry recovery, cleanup, inline lifecycle example, and rate limit awareness.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/session-management.md
git commit -m "feat(mcp-simulate): add session management reference"
```

---

### Task 8: Error Recovery Reference + 5 Error Example Files

**Files:**
- Create: `skills/mcp-simulate/references/error-recovery.md`
- Create: `skills/mcp-simulate/examples/deployment-errors.md`
- Create: `skills/mcp-simulate/examples/session-errors.md`
- Create: `skills/mcp-simulate/examples/execution-errors.md`
- Create: `skills/mcp-simulate/examples/witness-errors.md`
- Create: `skills/mcp-simulate/examples/capacity-errors.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/error-recovery.md`**

This is the routing hub for error interpretation. The LLM loads this when simulation fails, then selectively loads the example file matching the error pattern.

Content to include:

**When to use:** After any failed simulation operation.

**Reading error responses:** All errors include `success: false` and an `errors` array with `message`, `severity`, and optional `errorCode`.

**Error category routing table — match the error pattern, then load the corresponding example file:**

| Error Pattern | Category | Example File |
|---------------|----------|-------------|
| Compiler errors during deploy (syntax, type, disclosure) | Deployment error | `examples/deployment-errors.md` |
| `SESSION_NOT_FOUND` | Session error | `examples/session-errors.md` |
| `CIRCUIT_NOT_FOUND` / parameter type mismatch / assertion failure | Execution error | `examples/execution-errors.md` |
| Witness not provided / witness wrong type | Witness error | `examples/witness-errors.md` |
| `CAPACITY_EXCEEDED` / HTTP 429 | Capacity error | `examples/capacity-errors.md` |

**Load only the example file matching your error.** Do not load all example files.

**The recovery loop:**
1. Read ALL errors in the response
2. Match each error to its category using the routing table above
3. Load the example file for the primary error category
4. Fix the issue (for deploy errors: fix code and redeploy; for call errors: fix parameters and retry)
5. If new errors appear, repeat from step 1
6. Maximum 2-3 rounds. If still failing, present the errors to the user with your diagnosis and ask for help.

**Cross-reference:** Deploy compilation errors use the same compiler as `mcp-compile`. For detailed compiler error guidance, see `mcp-compile` error recovery reference.

- [ ] **Step 2: Write `examples/deployment-errors.md`**

Follow the spec's deployment-errors section exactly. Include:

1. **Parse error in contract code:** Error `expected ';' but found '{'`. Diagnosis: common Compact syntax issues (Void return type, deprecated ledger block, witness with body, `function` instead of `circuit`, division operator). Fix: correct the syntax. Cross-reference: `mcp-compile` examples/parse-errors.md.

2. **Type error in contract code:** Error `no matching overload`. Diagnosis: type mismatch in circuit body (mixing Field and Uint, arithmetic result expansion, direct Uint to Bytes cast). Fix: correct the types. Cross-reference: `mcp-compile` examples/type-errors.md.

3. **Missing import:** Error: unbound identifier for stdlib type. Diagnosis: code lacks `import CompactStandardLibrary;`. Fix: add the import.

4. **Disclosure error:** Error `potential witness-value disclosure must be declared`. Diagnosis: witness value flows to public state without `disclose()`. Fix: add `disclose()` at the boundary. Cross-reference: `mcp-compile` examples/disclosure-errors.md.

5. **Empty code:** Error: "Contract code is required". Diagnosis: empty string or whitespace. Fix: provide actual Compact source.

Anti-patterns (3):
- Modifying code in response to a deployment error without reading the compiler error
- Redeploying the same code hoping for a different result (compilation is deterministic)
- Not cross-referencing `mcp-compile` error examples (deploy errors ARE compiler errors)

- [ ] **Step 3: Write `examples/session-errors.md`**

Follow the spec's session-errors section exactly. Include:

1. **Session expired due to inactivity:** Error `SESSION_NOT_FOUND` after 15+ minutes of no activity. Fix: redeploy and replay call sequence.

2. **Wrong session ID:** Error `SESSION_NOT_FOUND` immediately after deploy. Fix: store the sessionId from deploy response and use it consistently.

3. **Session deleted but still referenced:** Error `SESSION_NOT_FOUND` after calling delete. Fix: deploy a new session if more testing is needed.

4. **Proactive TTL management:** Pattern of checking `expiresAt` in state responses and redeploying before expiry during long testing sessions.

Anti-patterns (3):
- Trying to recover an expired session (impossible — the state is gone)
- Not storing the sessionId immediately after deploy
- Leaving sessions open and being surprised when they expire

- [ ] **Step 4: Write `examples/execution-errors.md`**

Follow the spec's execution-errors section exactly. Include:

1. **Assertion failure:** Error: assertion message from the contract's `assert()` statement. Diagnosis: guard condition not met. State unchanged. Fix: understand why — check caller, arguments, current state. May be expected behavior.

2. **Circuit not found:** Error `CIRCUIT_NOT_FOUND` with list of available circuits. Diagnosis: typo in circuit name or calling non-exported circuit. Fix: check against `circuits` in deploy response or state.

3. **Parameter type mismatch:** Error: runtime type error. Diagnosis: wrong-typed argument. Fix: check circuit parameter types in metadata.

4. **Missing required parameter:** Error: expected N arguments but received M. Fix: check circuit metadata for required parameters.

5. **Invalid state operation:** Error: runtime error from ledger operation. Diagnosis: invalid operation given current state. Fix: check current state and ensure preconditions are met.

Anti-patterns (3):
- Treating assertion failures as bugs in the simulator (they're usually correct behavior)
- Not checking circuit metadata before calling
- Assuming a failed call modified state (failed calls do NOT modify ledger state)

- [ ] **Step 5: Write `examples/witness-errors.md`**

Follow the spec's witness-errors section exactly. Include:

1. **Witness not provided:** Error: witness function returned no value. Fix: provide `witnessOverrides` value for the required witness.

2. **Witness returns wrong type:** Error: type mismatch from witness return. Fix: check witness declaration, provide correctly-typed value.

3. **Witness override triggers downstream assertion:** Error: assertion failure after witness returns. Diagnosis: witness value caused assertion later in circuit logic. Fix: if testing rejection this is expected; if testing happy path, provide valid witness value.

Anti-patterns (2):
- Overriding witnesses that don't exist in the contract (silently ignored)
- Not testing both valid and invalid witness paths

- [ ] **Step 6: Write `examples/capacity-errors.md`**

Follow the spec's capacity-errors section exactly. Include:

1. **Capacity exceeded:** Error `CAPACITY_EXCEEDED`. Fix: delete old sessions, then retry deploy.

2. **Rate limit (429):** Error HTTP 429. Fix: wait for window reset. Batch testing — deploy once, make multiple calls.

3. **Deploy is expensive — budget accordingly:** Show rapid-fire deploys hitting limits vs one deploy + many calls pattern.

Anti-patterns (2):
- Redeploying for each test case instead of using one session with multiple calls
- Not cleaning up sessions after testing

- [ ] **Step 7: Verify all files**

Read back each file. Confirm:
- `references/error-recovery.md` has the error pattern routing table pointing to all 5 example files
- Each example file follows the template: heading → When This Error Occurs → Examples → Anti-Patterns
- deployment-errors has 5 examples and 3 anti-patterns
- session-errors has 4 examples and 3 anti-patterns
- execution-errors has 5 examples and 3 anti-patterns
- witness-errors has 3 examples and 2 anti-patterns
- capacity-errors has 3 examples and 2 anti-patterns

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/error-recovery.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/deployment-errors.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/session-errors.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/execution-errors.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/witness-errors.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/capacity-errors.md
git commit -m "feat(mcp-simulate): add error recovery reference and 5 error example files"
```

---

### Task 9: Testing Patterns Reference + 4 Pattern Example Files

**Files:**
- Create: `skills/mcp-simulate/references/testing-patterns.md`
- Create: `skills/mcp-simulate/examples/sequential-testing.md`
- Create: `skills/mcp-simulate/examples/assertion-testing.md`
- Create: `skills/mcp-simulate/examples/state-verification.md`
- Create: `skills/mcp-simulate/examples/multi-user-testing.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/testing-patterns.md`**

This file covers 4 testing strategies plus supplementary guidance. Each strategy section ends with an `**Examples:**` pointer.

1. **Sequential Workflow Testing** — When to apply: testing a multi-step workflow where each circuit call builds on the previous state. Instructions: deploy, call circuits in a logical order, verify state after each call. This tests the happy path. End section with `**Examples:** \`examples/sequential-testing.md\``

2. **Assertion Testing** — When to apply: verifying that guard logic works correctly. Instructions: deliberately trigger assertion failures by calling circuits with invalid inputs, unauthorized callers, or edge-case witness values. Verify the assertion fires and state is unchanged. End section with `**Examples:** \`examples/assertion-testing.md\``

3. **State Verification** — When to apply: comparing actual vs expected ledger state. Instructions: after each significant operation, call `midnight-simulate-state` and compare actual values against expected values. Check specific ledger fields, not just success/failure. End section with `**Examples:** \`examples/state-verification.md\``

4. **Multi-User Interaction Testing** — When to apply: testing interactions between different parties. Instructions: use the `caller` parameter to simulate interactions between different users. Test ownership checks, transfers, approvals, and multi-party protocols. End section with `**Examples:** \`examples/multi-user-testing.md\``

5. **Regression Testing** — When to apply: verifying code changes don't break behavior. Instructions: define a known sequence of calls that should produce a known final state. Deploy, replay the sequence, compare final state.

6. **The compile-then-simulate pattern** — Before deploying, run the code through `mcp-compile` (skipZk) to catch compilation errors cheaply. Then deploy for simulation. This separates "does it compile?" from "does it behave correctly?"

7. **Contract archetype examples** — For complete end-to-end test sequences, see the archetype examples: `examples/counter-contract.md`, `examples/token-contract.md`, `examples/voting-contract.md`, `examples/access-control-contract.md`

- [ ] **Step 2: Write `examples/sequential-testing.md`**

Follow the spec's sequential-testing section. 3-4 complete deploy→call→verify sequences:

1. **Counter increment sequence:** Deploy counter contract → call `inc(5)` → verify state (Counter=5) → call `inc(3)` → verify state (Counter=8) → call `get()` (pure) → verify return value matches ledger state

2. **Initialize-then-operate pattern:** Deploy contract → call `init()` with constructor-like setup → call business logic circuits → verify final state

3. **Ordered operations with dependencies:** Deploy token contract → mint tokens → transfer tokens → verify sender balance decreased and receiver balance increased

Anti-patterns (3):
- Making calls without verifying state between them
- Not planning the call sequence before executing
- Deploying a new session for each step instead of using the accumulated state

- [ ] **Step 3: Write `examples/assertion-testing.md`**

Follow the spec's assertion-testing section. 3-5 before/after pairs:

1. **Testing authorization rejection:** Deploy with owner="alice" → call restricted circuit as caller="bob" → verify assertion fires → verify state unchanged → call as caller="alice" → verify success

2. **Testing insufficient balance:** Deploy token contract → mint 100 tokens → attempt transfer of 200 → verify assertion failure → verify balance unchanged

3. **Testing input validation:** Deploy → call with out-of-range parameter → verify assertion → call with valid parameter → verify success

4. **Testing post-condition assertion:** Deploy → call circuit where result would violate an invariant → verify assertion catches it

Anti-patterns (3):
- Not verifying that state is unchanged after an assertion failure
- Only testing happy paths
- Confusing assertion failures with bugs

- [ ] **Step 4: Write `examples/state-verification.md`**

Follow the spec's state-verification section. 3-5 complete verification sequences:

1. **Counter arithmetic verification:** After 3 increment calls with values 5, 3, 7 → verify Counter = 15

2. **Map state verification:** Deploy with empty Map → insert key-value → verify Map contains entry → insert another → verify both entries → remove first → verify only second remains

3. **Multi-field verification:** Deploy with Counter + Map → call circuit that modifies both → verify BOTH fields changed correctly

4. **Unchanged field verification:** Call circuit that modifies field A → verify field A changed → verify field B did NOT change

Anti-patterns (3):
- Checking only `success: true` without inspecting actual state values
- Verifying only the fields you expect to change
- Not verifying state after error cases

- [ ] **Step 5: Write `examples/multi-user-testing.md`**

Follow the spec's multi-user-testing section. 3-5 complete multi-caller sequences:

1. **Ownership transfer:** Deploy as Alice → Alice transfers ownership to Bob → Bob calls owner-only circuit (succeeds) → Alice calls owner-only circuit (now fails)

2. **Token transfer between users:** Deploy as Alice → Alice mints 100 → Alice transfers 30 to Bob → verify Alice=70, Bob=30 → Bob transfers 10 to Charlie → verify Alice=70, Bob=20, Charlie=10

3. **Access control with multiple roles:** Deploy → set Alice as admin, Bob as user → Admin calls admin-only circuit (succeeds) → User calls admin-only circuit (fails) → Admin grants user admin role → User retries (succeeds)

Anti-patterns (3):
- Using the same caller for all calls in a multi-user test
- Not testing both authorized and unauthorized calls
- Forgetting that caller values are strings — consistency matters ("alice" vs "Alice" are different callers)

- [ ] **Step 6: Verify all files**

Read back each file. Confirm:
- Reference has 4 technique sections with `**Examples:**` pointers, plus regression and compile-then-simulate sections, plus archetype pointer
- Each example file follows the template: heading → When to Apply → Examples (3-5 sequences) → Anti-Patterns (2-3)
- All content uses real Midnight terminology

- [ ] **Step 7: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/testing-patterns.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/sequential-testing.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/assertion-testing.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/state-verification.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/multi-user-testing.md
git commit -m "feat(mcp-simulate): add testing patterns reference and 4 pattern example files"
```

---

### Task 10: Contract Archetype Example Files

**Files:**
- Create: `skills/mcp-simulate/examples/counter-contract.md`
- Create: `skills/mcp-simulate/examples/token-contract.md`
- Create: `skills/mcp-simulate/examples/voting-contract.md`
- Create: `skills/mcp-simulate/examples/access-control-contract.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `examples/counter-contract.md`**

Template: `# Counter Contract Archetype` → `## Contract Code` → `## Simulation Sequence` → `## What This Tests` → `## Limitations`

**Contract Code:** A complete, compilable Compact contract with:
- `pragma language_version >= 0.14;`
- `import CompactStandardLibrary;`
- `export ledger count: Counter;`
- `export circuit inc(n: Uint<64>): [] { count.increment(n); }`
- `export pure circuit get(): Uint<64> { return count; }`

**Simulation Sequence:** Deploy → state (verify Counter=0) → inc(5) → state (verify Counter=5) → inc(3) → state (verify Counter=8) → get() (verify return=8) → delete. Show each step with the tool call and expected response.

**What This Tests:** Basic state mutation, pure vs impure circuits, return values, state accumulation across calls.

**Limitations:** Counter contracts are the simplest pattern — simulation handles them perfectly. This is a good baseline for verifying that the simulator is working correctly.

- [ ] **Step 2: Write `examples/token-contract.md`**

**Contract Code:** A token contract with:
- `export ledger balances: Map<Bytes<32>, Uint<64>>;`
- `export ledger owner: Bytes<32>;`
- Owner-only `mint` circuit
- `transfer` circuit with balance checks
- Pure `getBalance` circuit

**Simulation Sequence:** Deploy as owner → mint(100) as owner → state (verify balance=100) → transfer(30, bob) as owner → state (verify owner=70, bob=30) → mint(50) as bob (verify assertion failure — owner-only) → state (verify unchanged) → delete

**What This Tests:** Access control via caller context, Map state mutations, assertion testing, multi-user interaction.

**Limitations:** Note any limitations of how the simulator handles Map operations or Bytes<32> caller values.

- [ ] **Step 3: Write `examples/voting-contract.md`**

**Contract Code:** A voting contract with:
- Counter for tally per option
- Set or Map for voter tracking
- Boolean or enum for voting-open state
- Vote, close, and tally circuits

**Simulation Sequence:** Deploy → vote(optionA) as alice → vote(optionB) as bob → vote(optionA) as charlie → vote(optionA) as alice (verify assertion — already voted) → close() as owner → tally() (verify optionA=2, optionB=1) → vote(optionA) as dave (verify assertion — voting closed) → delete

**What This Tests:** Set membership (voter tracking), assertion on duplicate votes, state transitions (open→closed), tallying, multi-user voting.

- [ ] **Step 4: Write `examples/access-control-contract.md`**

**Contract Code:** A contract with:
- `export ledger owner: Bytes<32>;`
- Owner-only and public circuits
- Ownership transfer circuit

**Simulation Sequence:** Deploy as alice → call owner-only circuit as alice (succeeds) → call owner-only circuit as bob (assertion failure) → transfer ownership to bob as alice → call owner-only circuit as bob (succeeds) → call owner-only circuit as alice (assertion failure) → delete

**What This Tests:** Ownership verification via caller context, ownership transfer, assertion testing for unauthorized access, state verification that ownership change persists.

- [ ] **Step 5: Verify all files**

Read back each file. Confirm:
- Each follows the template: Contract Code → Simulation Sequence → What This Tests → Limitations
- Contract code is complete and compilable (has pragma, import, ledger, circuits)
- Simulation sequence shows each step with tool call and expected response
- Uses real Midnight terminology and types

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/examples/counter-contract.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/token-contract.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/voting-contract.md
git add plugins/midnight-mcp/skills/mcp-simulate/examples/access-control-contract.md
git commit -m "feat(mcp-simulate): add 4 contract archetype example files"
```

---

### Task 11: Server-Enhanced Reference

**Files:**
- Create: `skills/mcp-simulate/references/server-enhanced.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `references/server-enhanced.md`**

This file documents 3 features that require playground changes beyond the OZ integration. Each section should include:
- What the feature does
- What it would enable for the LLM consumer
- Current limitation (why the LLM cannot do this today)
- Recommended server-side implementation approach
- What would need to change in this plugin once the server supports it

Techniques:

1. **Session Snapshots** — Save and restore session state at named checkpoints. Would enable branching test scenarios (test different paths from the same starting state without replaying calls). Currently the LLM must redeploy and replay the full call sequence to test a different path. Server change: add `POST /simulate/:id/snapshot` and `POST /simulate/:id/restore/:snapshotId`. Plugin change: add snapshot guidance to `session-management.md` and `testing-patterns.md`.

2. **Scenario Files** — Accept a pre-written sequence of calls as a single request, returning all intermediate and final states. Would reduce round-trips for regression testing. Currently each call requires a separate request. Server change: add `POST /simulate/scenario` that takes code + call sequence, returns results for each step. Plugin change: add scenario-based testing to `testing-patterns.md`.

3. **Diff-Based State Comparison** — Return a structured diff between two session states or between two points in the same session's history. Would simplify state verification. Currently the LLM must manually compare ledger state objects. Server change: add `GET /simulate/:id/diff?from=callIndex&to=callIndex`. Plugin change: add diff-based verification to `state-inspection.md`.

- [ ] **Step 2: Verify the file**

Read back. Confirm all 3 features are documented with the required sections.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-simulate/references/server-enhanced.md
git commit -m "feat(mcp-simulate): add server-enhanced reference with 3 playground feature requests"
```

---

### Task 12: Create GitHub Issues for Server-Side Enhancements

**Depends on:** Task 11

This task creates 3 GitHub issues on `devrelaicom/compact-playground`, one per feature in `references/server-enhanced.md`.

- [ ] **Step 1: Read back `references/server-enhanced.md`**

Read the file to get the exact content for each issue.

- [ ] **Step 2: Create GitHub issue for Session Snapshots**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add session snapshot/restore for branching test scenarios" \
  --body "$(cat <<'EOF'
## Summary

Add the ability to save and restore simulation session state at named checkpoints, enabling branching test scenarios without replaying call sequences.

## Motivation

Currently, testing different paths from the same starting state requires redeploying and replaying the full call sequence for each branch. For complex contracts with multi-step setup, this wastes rate limit budget and time.

## Proposed Change

- Add `POST /simulate/:id/snapshot` — saves current state and returns a `snapshotId`
- Add `POST /simulate/:id/restore/:snapshotId` — restores state to a previously saved snapshot
- Snapshots share the session's TTL and are cleaned up when the session is deleted

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-simulate/references/session-management.md` — add snapshot lifecycle guidance
- `plugins/midnight-mcp/skills/mcp-simulate/references/testing-patterns.md` — add branching test pattern
- `plugins/midnight-mcp/skills/mcp-simulate/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 3: Create GitHub issue for Scenario Files**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add batch scenario execution for regression testing" \
  --body "$(cat <<'EOF'
## Summary

Accept a pre-written sequence of circuit calls as a single request, returning all intermediate and final states in one response.

## Motivation

Regression testing requires replaying a known sequence of calls and verifying the final state. Currently each call requires a separate round-trip, which is slow and consumes rate limit budget. A batch endpoint would enable one-shot regression testing.

## Proposed Change

- Add `POST /simulate/scenario` that accepts:
  - `code`: contract source
  - `version`: optional compiler version
  - `caller`: optional default caller
  - `calls`: array of `{ circuit, arguments?, caller?, witnessOverrides? }`
- Returns: array of step results, each with `success`, `result`, `stateChanges`, `updatedLedger`
- Execution stops at the first failure (remaining steps returned as `skipped`)

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-simulate/references/testing-patterns.md` — add scenario-based regression testing
- `plugins/midnight-mcp/skills/mcp-simulate/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 4: Create GitHub issue for Diff-Based State Comparison**

```bash
gh issue create --repo devrelaicom/compact-playground \
  --title "feat: add structured state diff between call history points" \
  --body "$(cat <<'EOF'
## Summary

Return a structured diff between two points in a simulation session's call history, showing which ledger fields changed and how.

## Motivation

State verification currently requires the LLM to manually compare full ledger state objects from two different state queries. A structured diff would simplify verification, especially for contracts with many ledger fields where only a few change per operation.

## Proposed Change

- Add `GET /simulate/:id/diff?from=<callIndex>&to=<callIndex>` that returns:
  - `changes`: array of `{ field, type, fromValue, toValue }`
  - `unchanged`: array of field names that did not change
- `from=0` means initial state (after deploy, before any calls)
- `to` defaults to current state if omitted

## Plugin Updates Required

Once implemented, update in `midnight-expert`:
- `plugins/midnight-mcp/skills/mcp-simulate/references/state-inspection.md` — add diff-based verification pattern
- `plugins/midnight-mcp/skills/mcp-simulate/references/server-enhanced.md` — mark as implemented
EOF
)"
```

- [ ] **Step 5: Verify all issues were created**

```bash
gh issue list --repo devrelaicom/compact-playground --search "simulate" --json title,url --limit 10
```

Confirm 3 new issues exist (plus the existing #17 for OZ integration).

---

### Task 13.5: Slash Command

**Files:**
- Create: `commands/simulate.md`

**Depends on:** Task 1

- [ ] **Step 1: Write `commands/simulate.md`**

Follow the command conventions from existing commands (`devnet.md`, `doctor.md`). The command file needs YAML frontmatter and step-by-step instructions.

```markdown
---
description: Simulate Compact contracts interactively — deploy, call circuits, inspect state, and verify behavior with preset testing modes and witness/caller control
allowed-tools: AskUserQuestion, Read, Glob, Grep, mcp__midnight__midnight-simulate-deploy, mcp__midnight__midnight-simulate-call, mcp__midnight__midnight-simulate-state, mcp__midnight__midnight-simulate-delete, mcp__midnight__midnight-compile-contract
argument-hint: [<code-or-file>] [--explore | --test-sequence | --regression | --assertions] [--caller <address>] [--cleanup] [--version <ver>] [--witness <name>=<value>] [--compile-first]
---

Simulate Compact contracts using the MCP simulation tools with preset testing modes.

## Step 1: Parse Arguments and Flags

Parse `$ARGUMENTS` into:
- **Code source**: inline code string, or file path to read
- **Preset flag**: `--explore`, `--test-sequence`, `--regression`, `--assertions`
- **Modifier flags**: `--caller <address>`, `--cleanup`, `--version <ver>`, `--witness <name>=<value>`, `--compile-first`

If no arguments at all → go to **Step 2: Interactive Mode**.
If code present but no preset → apply `--explore` as default preset.
If preset present → resolve preset to its behavior.

## Step 2: Interactive Mode

If no arguments were provided, start a guided simulation session:

1. Ask: "What contract do you want to simulate? (paste code, provide a file path, or describe what you want to test)"
2. Based on the answer:
   - If code provided → continue to Step 3
   - If file path → read the file, continue to Step 3
   - If description → help construct or find the contract, then continue
3. Ask: "What do you want to test? (explore structure, test a workflow, test assertions, or regression test)"
4. Based on the answer, set the appropriate preset.
5. Ask: "Do you need to set a caller identity or provide witness overrides?" (only if the contract uses access control or witnesses)
6. Continue to **Step 3**.

Use `AskUserQuestion` for each question. One question per message.

## Step 3: Resolve Code Source

If the code source is a file path, read the file with the Read tool.
If inline code, use it directly.

## Step 4: Load Skill References

Based on the active preset, read the relevant reference and example files from the `mcp-simulate` skill directory.

| Preset | References to Load |
|--------|--------------------|
| `--explore` | `references/deploy-workflows.md`, `references/state-inspection.md` |
| `--test-sequence` | `references/deploy-workflows.md`, `references/circuit-execution.md`, `references/testing-patterns.md` |
| `--regression` | `references/deploy-workflows.md`, `references/circuit-execution.md`, `references/testing-patterns.md` |
| `--assertions` | `references/deploy-workflows.md`, `references/circuit-execution.md`, `references/testing-patterns.md` |

If `--witness` is specified, also load `references/witness-management.md`.
If `--caller` is specified, also load `references/caller-context.md`.

## Step 5: Pre-Deploy Validation

If `--compile-first` flag is set:
1. Call `midnight-compile-contract` with the code and `skipZk: true`
2. If compilation fails, report errors and stop — do not deploy
3. If compilation succeeds, continue to Step 6

## Step 6: Deploy

Call `midnight-simulate-deploy` with:
- `code`: the resolved source code
- `version`: from `--version` flag if provided
- `caller`: from `--caller` flag if provided

If deploy fails, load `references/error-recovery.md` and diagnose.

Store the `sessionId` for all subsequent operations.

## Step 7: Execute Preset Workflow

### `--explore` (default)
1. Call `midnight-simulate-state` to get full session state
2. Present to the user:
   - Available circuits with their signatures (parameters, return types, pure/impure)
   - Initial ledger state for all fields
   - Which circuits read/write which ledger fields
3. Ask if the user wants to make any calls

### `--test-sequence`
1. Present available circuits
2. Loop:
   a. Ask: "Which circuit do you want to call? (or 'done' to finish)"
   b. If done → go to Step 8
   c. Ask for arguments if the circuit has parameters
   d. Call `midnight-simulate-call` with the circuit, arguments, and any modifier flags
   e. Call `midnight-simulate-state` to show updated state
   f. Present: result, state changes, current ledger
   g. Repeat

### `--regression`
1. Ask: "Provide the call sequence (circuit name + arguments per step) and the expected final state"
2. Execute each call in sequence
3. After all calls, compare final state against expected state
4. Report: pass/fail for each field, highlighting mismatches

### `--assertions`
1. For each exported circuit:
   a. Identify the circuit's parameters and any assertion conditions (from code analysis)
   b. Test with valid arguments → verify success
   c. Test with boundary/invalid arguments → verify assertion failure
   d. Verify state unchanged after assertion failures
2. Report: which circuits passed, which assertion paths were tested, any unexpected results

## Step 8: Cleanup

If `--cleanup` flag is set, or if the workflow is complete:
1. Call `midnight-simulate-delete` with the sessionId
2. Confirm deletion

## Step 9: Present Results

Present a summary:
- What was tested (circuits called, assertions tested)
- Pass/fail status for each step
- Any issues found
- Suggestions for further testing if gaps were identified

## Step 10: No-Results Fallback

If deployment failed and could not be recovered:
1. Suggest running `mcp-compile` first to catch compilation errors
2. Suggest checking the contract code with `compact-core:verify-correctness`
3. Note that the code may have syntax that requires a specific compiler version — try with `--version`
```

- [ ] **Step 2: Verify the command file**

Read back the file. Confirm:
- YAML frontmatter has `description`, `allowed-tools`, `argument-hint`
- All MCP tool names in `allowed-tools` use the correct `mcp__midnight__` prefix
- All 10 steps are present and logically ordered
- Interactive mode uses `AskUserQuestion`
- Preset reference loading table is present
- Each preset workflow is fully specified

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-mcp/commands/simulate.md
git commit -m "feat(midnight-mcp): add /midnight-mcp:simulate slash command with presets and interactive mode"
```

---

### Task 13: Integration Verification

**Depends on:** All previous tasks

- [ ] **Step 1: Verify all files exist**

```bash
# SKILL.md
test -f plugins/midnight-mcp/skills/mcp-simulate/SKILL.md && echo "OK: SKILL.md" || echo "MISSING: SKILL.md"

# 9 reference files
for f in deploy-workflows circuit-execution witness-management caller-context state-inspection session-management error-recovery testing-patterns server-enhanced; do
  test -f "plugins/midnight-mcp/skills/mcp-simulate/references/$f.md" && echo "OK: references/$f.md" || echo "MISSING: references/$f.md"
done

# 13 example files
for f in deployment-errors session-errors execution-errors witness-errors capacity-errors sequential-testing assertion-testing state-verification multi-user-testing counter-contract token-contract voting-contract access-control-contract; do
  test -f "plugins/midnight-mcp/skills/mcp-simulate/examples/$f.md" && echo "OK: examples/$f.md" || echo "MISSING: examples/$f.md"
done

# Command file
test -f plugins/midnight-mcp/commands/simulate.md && echo "OK: commands/simulate.md" || echo "MISSING: commands/simulate.md"
```

All 24 files must show "OK". Fix any missing files before proceeding.

- [ ] **Step 2: Verify cross-references in SKILL.md**

Confirm that every reference file path mentioned in the routing table exists:

```bash
grep -oP 'references/[a-z-]+\.md' plugins/midnight-mcp/skills/mcp-simulate/SKILL.md | sort -u | while read ref; do
  test -f "plugins/midnight-mcp/skills/mcp-simulate/$ref" && echo "OK: $ref" || echo "BROKEN: $ref"
done
```

- [ ] **Step 3: Verify example file references in cluster references**

For each reference file, confirm that every `examples/*.md` path it mentions exists:

```bash
for ref in plugins/midnight-mcp/skills/mcp-simulate/references/*.md; do
  grep -oP 'examples/[a-z-]+\.md' "$ref" 2>/dev/null | while read ex; do
    test -f "plugins/midnight-mcp/skills/mcp-simulate/$ex" && echo "OK: $(basename $ref) → $ex" || echo "BROKEN: $(basename $ref) → $ex"
  done
done
```

- [ ] **Step 4: Verify error example file structure**

Each error example file must have:
- `# [Category] Examples` heading
- `## When This Error Occurs` section
- `## Examples` section with at least 2 `### ` subsections
- `## Anti-Patterns` section with at least 2 `### ` subsections

```bash
for f in plugins/midnight-mcp/skills/mcp-simulate/examples/{deployment,session,execution,witness,capacity}-errors.md; do
  name=$(basename "$f")
  subsections=$(grep -c '^### ' "$f" 2>/dev/null || echo 0)
  has_when=$(grep -c '## When This Error Occurs' "$f" 2>/dev/null || echo 0)
  has_anti=$(grep -c '## Anti-Patterns' "$f" 2>/dev/null || echo 0)
  if [ "$has_when" -ge 1 ] && [ "$has_anti" -ge 1 ] && [ "$subsections" -ge 4 ]; then
    echo "OK: $name ($subsections subsections)"
  else
    echo "CHECK: $name (when=$has_when, anti=$has_anti, subsections=$subsections)"
  fi
done
```

- [ ] **Step 5: Verify testing pattern example file structure**

Each testing pattern example file must have:
- `# [Name] Examples` heading
- `## When to Apply` section
- `## Examples` section with at least 3 `### ` subsections
- `## Anti-Patterns` section with at least 2 `### ` subsections

```bash
for f in plugins/midnight-mcp/skills/mcp-simulate/examples/{sequential-testing,assertion-testing,state-verification,multi-user-testing}.md; do
  name=$(basename "$f")
  subsections=$(grep -c '^### ' "$f" 2>/dev/null || echo 0)
  has_when=$(grep -c '## When to Apply' "$f" 2>/dev/null || echo 0)
  has_anti=$(grep -c '## Anti-Patterns' "$f" 2>/dev/null || echo 0)
  if [ "$has_when" -ge 1 ] && [ "$has_anti" -ge 1 ] && [ "$subsections" -ge 5 ]; then
    echo "OK: $name ($subsections subsections)"
  else
    echo "CHECK: $name (when=$has_when, anti=$has_anti, subsections=$subsections)"
  fi
done
```

- [ ] **Step 6: Verify contract archetype example file structure**

Each contract archetype example file must have:
- `# [Name] Contract Archetype` heading
- `## Contract Code` section
- `## Simulation Sequence` section
- `## What This Tests` section

```bash
for f in plugins/midnight-mcp/skills/mcp-simulate/examples/{counter,token,voting,access-control}-contract.md; do
  name=$(basename "$f")
  has_code=$(grep -c '## Contract Code' "$f" 2>/dev/null || echo 0)
  has_seq=$(grep -c '## Simulation Sequence' "$f" 2>/dev/null || echo 0)
  has_tests=$(grep -c '## What This Tests' "$f" 2>/dev/null || echo 0)
  if [ "$has_code" -ge 1 ] && [ "$has_seq" -ge 1 ] && [ "$has_tests" -ge 1 ]; then
    echo "OK: $name"
  else
    echo "CHECK: $name (code=$has_code, seq=$has_seq, tests=$has_tests)"
  fi
done
```

- [ ] **Step 7: Verify command file frontmatter**

```bash
head -5 plugins/midnight-mcp/commands/simulate.md
```

Confirm `description`, `allowed-tools`, and `argument-hint` are present in the YAML frontmatter.

- [ ] **Step 8: Verify GitHub issues**

```bash
gh issue list --repo devrelaicom/compact-playground --search "simulate" --json title,url --limit 10
```

Confirm 3 new issues were created (plus existing #17).

- [ ] **Step 9: Final commit if any fixes were made**

If any verification steps revealed issues that were fixed:

```bash
git add -A plugins/midnight-mcp/
git commit -m "fix(mcp-simulate): address integration verification findings"
```

- [ ] **Step 10: Summary**

Report:
- Total files created/modified
- Total GitHub issues created
- Any issues found and fixed during verification
- Any remaining concerns
