# Testing Patterns

## When to Use

When planning a testing strategy for a contract. Choose the pattern matching your testing goal, then load the corresponding example file.

## Sequential Workflow Testing

Test a multi-step workflow where each circuit call builds on the previous state.

1. Deploy the contract
2. Call circuits in a logical order that exercises the workflow
3. Verify state after each call to catch issues early
4. Final state check confirms the complete workflow

This tests the happy path — the expected sequence of operations works correctly.

**Examples:** `examples/sequential-testing.md`

## Assertion Testing

Verify that guard logic works correctly by deliberately triggering assertion failures.

1. Identify circuits with `assert()` statements (check the contract code)
2. Call with inputs that should trigger the assertion (invalid caller, out-of-range values, violated preconditions)
3. Verify the assertion fires (`success: false` with assertion error message)
4. Verify state is unchanged after the failure
5. Call with valid inputs to confirm the circuit works when preconditions are met

Testing both the acceptance and rejection paths is essential.

**Examples:** `examples/assertion-testing.md`

## State Verification

Compare actual ledger state against expected values after each significant operation.

1. After each circuit call, call `midnight-simulate-state`
2. Compare actual `ledgerState` values against your expected values
3. Check specific ledger fields — not just `success: true`
4. Also verify that fields you did NOT intend to modify are unchanged

This catches subtle bugs where a circuit succeeds but produces wrong state.

**Examples:** `examples/state-verification.md`

## Multi-User Interaction Testing

Test interactions between different parties using the `caller` parameter.

1. Deploy with a specific caller to establish ownership
2. Alternate `caller` between calls to simulate different users
3. Test that access control works — owner-only circuits reject non-owners
4. Test transfers and state changes between users
5. Verify the shared ledger reflects all users' actions correctly

All callers operate on the same shared ledger within a single session.

**Examples:** `examples/multi-user-testing.md`

## Regression Testing

Verify that code changes don't break existing behavior.

1. Define a known sequence of calls that produces a known final state
2. Deploy the updated contract
3. Replay the exact call sequence
4. Compare the final state against the expected state
5. Any mismatch indicates a regression

Keep regression sequences simple and focused on critical invariants.

## The Compile-Then-Simulate Pattern

Before deploying, run the code through `midnight-mcp:mcp-compile` (skipZk) to catch compilation errors cheaply. Then deploy for simulation.

```
1. midnight-compile-contract({ code: "<contract>", skipZk: true })
   → If errors: fix code, don't waste a deploy
   → If success: proceed to deploy

2. midnight-simulate-deploy({ code: "<same contract>" })
   → Now test behavior, not compilation
```

This separates "does it compile?" from "does it behave correctly?"

## Contract Archetype Examples

For complete end-to-end test sequences showing all patterns applied together, see the archetype examples:

- `examples/counter-contract.md` — basic state mutation, pure vs impure circuits
- `examples/token-contract.md` — access control, multi-user, Map state
- `examples/voting-contract.md` — Set membership, state transitions, multi-user voting
- `examples/access-control-contract.md` — ownership transfer, assertion testing
