---
description: Simulate Compact contracts interactively — deploy, call circuits, inspect state, and verify behavior with preset testing modes and witness/caller control
allowed-tools: AskUserQuestion, Read, Glob, Grep, mcp__midnight__midnight-simulate-deploy, mcp__midnight__midnight-simulate-call, mcp__midnight__midnight-simulate-state, mcp__midnight__midnight-simulate-delete, mcp__midnight__midnight-compile-contract
argument-hint: "[<code-or-file>] [--explore | --test-sequence | --regression | --assertions] [--caller <address>] [--cleanup] [--version <ver>] [--witness <name>=<value>] [--compile-first]"
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
2. Suggest checking the contract code with `midnight-verify:verify-correctness`
3. Note that the code may have syntax that requires a specific compiler version — try with `--version`
