# Server-Enhanced Capabilities

Three features that require playground changes beyond the OZ simulator integration. These are not yet available — this documents what they would enable and what needs to change when they ship.

## Session Snapshots

**What it does:** Save and restore simulation session state at named checkpoints.

**What it enables:** Branching test scenarios — test different paths from the same starting state without replaying the full call sequence. Deploy once, reach a complex state through multiple calls, snapshot, test path A, restore, test path B.

**Current limitation:** The LLM must redeploy and replay the full call sequence to test each alternative path. For contracts with multi-step setup (e.g., mint tokens, set roles, configure state), this wastes rate limit budget and time.

**Recommended server-side implementation:**
- `POST /simulate/:id/snapshot` — saves current state, returns a `snapshotId`
- `POST /simulate/:id/restore/:snapshotId` — restores state to a previously saved snapshot
- Snapshots share the session's TTL and are cleaned up when the session is deleted

**Plugin changes when implemented:**
- `references/session-management.md` — add snapshot lifecycle guidance (create, restore, cleanup)
- `references/testing-patterns.md` — add branching test pattern using snapshots
- This file — mark Session Snapshots as implemented

## Scenario Files

**What it does:** Accept a pre-written sequence of calls as a single request, returning all intermediate and final states in one response.

**What it enables:** One-shot regression testing — send the full test sequence in a single request instead of making individual round-trips for each call. Reduces latency and rate limit consumption for known test sequences.

**Current limitation:** Each circuit call requires a separate request. Regression testing with 10+ calls means 10+ round-trips, each consuming a rate limit slot.

**Recommended server-side implementation:**
- `POST /simulate/scenario` accepts:
  - `code`: contract source
  - `version`: optional compiler version
  - `caller`: optional default caller
  - `calls`: array of `{ circuit, arguments?, caller?, witnessOverrides? }`
- Returns: array of step results, each with `success`, `result`, `stateChanges`, `updatedLedger`
- Execution stops at the first failure (remaining steps returned as `skipped`)

**Plugin changes when implemented:**
- `references/testing-patterns.md` — add scenario-based regression testing pattern
- This file — mark Scenario Files as implemented

## Diff-Based State Comparison

**What it does:** Return a structured diff between two points in a simulation session's call history, showing which ledger fields changed and how.

**What it enables:** Simplified state verification — instead of manually comparing full ledger state objects from two different state queries, get a structured diff showing only what changed. Especially valuable for contracts with many ledger fields where only a few change per operation.

**Current limitation:** The LLM must manually compare ledger state objects. For contracts with 10+ ledger fields, this means comparing every field to find the 1-2 that changed.

**Recommended server-side implementation:**
- `GET /simulate/:id/diff?from=<callIndex>&to=<callIndex>` returns:
  - `changes`: array of `{ field, type, fromValue, toValue }`
  - `unchanged`: array of field names that did not change
- `from=0` means initial state (after deploy, before any calls)
- `to` defaults to current state if omitted

**Plugin changes when implemented:**
- `references/state-inspection.md` — add diff-based verification pattern
- This file — mark Diff-Based State Comparison as implemented
