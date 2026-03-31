# Fast-Verify Command and SubagentStop Hook Fix Design

**Date:** 2026-03-31
**Status:** Approved

## Problem

The full `/verify` pipeline is slow and token-heavy. Two issues need fixing:

1. **SubagentStop hooks cause infinite loops.** When a hook blocks a subagent, the agent retries but hits the same block again because `stop_hook_active` is not checked. The existing `stop-check.sh` (Stop hook) already handles this — the SubagentStop scripts do not.

2. **No fast verification path.** Every claim goes through the full execution pipeline (compile, run, observe). For many claims, source inspection is sufficient and much faster. A source-first verification command with optional background execution would dramatically reduce time and token usage.

## Design

### 1. Fix stop_hook_active in SubagentStop hooks

All 7 `subagent-stop-*.sh` scripts need the same fix: if `stop_hook_active` is `true`, exit 0 immediately. This means the hook blocks once (reminding the agent of the process), then lets it through on retry. No infinite loops.

Add this immediately after reading stdin, before any transcript checks:

```bash
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi
```

This mirrors the pattern already used in `hooks/stop-check.sh`.

**Scripts to update:**
- `hooks/subagent-stop-contract-writer.sh`
- `hooks/subagent-stop-source-investigator.sh`
- `hooks/subagent-stop-type-checker.sh`
- `hooks/subagent-stop-cli-tester.sh`
- `hooks/subagent-stop-sdk-tester.sh`
- `hooks/subagent-stop-witness-verifier.sh`
- `hooks/subagent-stop-zkir-checker.sh`

### 2. Create `/fast-verify` command

A source-first verification command that returns a verdict based on source inspection, with an optional background execution check that only surfaces if it disagrees with the source verdict.

**Flow:**

1. Same input routing as `/verify` (file path, code snippet, natural language, directory)
2. Classify domain using the `midnight-verify:verify-correctness` hub skill
3. **Primary (foreground):** Dispatch the appropriate foreground agent (see table below)
4. **Secondary (background):** If applicable, dispatch the background agent with `run_in_background: true`
5. Present the foreground agent's verdict immediately
6. If the background agent completes and **disagrees** with the foreground verdict, surface a warning. If it agrees, stay silent.

**Domain routing:**

| Domain | Foreground Agent | Background Agent | Notes |
|---|---|---|---|
| Compact | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:contract-writer (agent)" (with `--skip-zk`) | Background compiles and executes but user doesn't wait |
| SDK | @"midnight-verify:source-investigator (agent)" | @"midnight-verify:type-checker (agent)" | Background type-checks |
| ZKIR | @"midnight-verify:source-investigator (agent)" | None | ZKIR execution too slow even with --skip-zk |
| Wallet SDK | @"midnight-verify:source-investigator (agent)" | None | Source is already primary for wallet SDK |
| Ledger | @"midnight-verify:source-investigator (agent)" | None | Source is already primary for ledger |
| Tooling | @"midnight-verify:cli-tester (agent)" | None | CLI execution is already fast |
| Witness | @"midnight-verify:source-investigator (agent)" | None | Cross-domain execution too complex for background |

**Verdict format:**

- With background check running: `Confirmed (source-verified, execution pending)` or `Refuted (source-verified, execution pending)`
- Without background check: `Confirmed (source-verified)` or `Refuted (source-verified)`
- Tooling domain: `Confirmed (cli-tested)` (same as `/verify` — no change for tooling)

**Background disagreement handling:**

When a background agent completes and its verdict disagrees with the foreground verdict, surface a warning:

```
WARNING: Background verification disagrees with source verdict.
- Source verdict: Confirmed (source-verified)
- Execution verdict: Refuted (tested)
- Recommendation: Run /verify for full verification.
```

**Key design decisions:**
- `/fast-verify` never waits for execution. Source is the verdict. Background execution is a safety net.
- The background contract-writer agent is told to compile with `--skip-zk` to avoid the expensive PLONK key generation.
- The `midnight-verify:verify-correctness` hub skill is still loaded for domain classification — the same classification logic applies.
- Domain skills are NOT loaded for `/fast-verify` — they contain routing tables for the full pipeline. The fast-verify command has its own simpler routing table (above).

## Files Changed

### Modified
- `hooks/subagent-stop-contract-writer.sh` -- add stop_hook_active check
- `hooks/subagent-stop-source-investigator.sh` -- add stop_hook_active check
- `hooks/subagent-stop-type-checker.sh` -- add stop_hook_active check
- `hooks/subagent-stop-cli-tester.sh` -- add stop_hook_active check
- `hooks/subagent-stop-sdk-tester.sh` -- add stop_hook_active check
- `hooks/subagent-stop-witness-verifier.sh` -- add stop_hook_active check
- `hooks/subagent-stop-zkir-checker.sh` -- add stop_hook_active check
- `.claude-plugin/plugin.json` -- version bump to 0.9.0

### New
- `commands/fast-verify.md` -- new /fast-verify command
