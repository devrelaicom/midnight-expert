# Fast-Check Command Design

**Date:** 2026-03-31
**Status:** Approved

## Problem

The `/check` command's full pipeline (extract → classify → verify → report) is slow and token-heavy. Classification adds 4 parallel agent dispatches + a merge step, and domain-specific verification dispatches execution agents that are expensive. For many fact-checking use cases, source inspection is sufficient.

## Design

### `/fast-check` command

A streamlined fact-checking pipeline that skips classification and uses source inspection for all claims.

**Pipeline:** Extract → Verify (source-only) → Report

**Steps:**

1. **Preflight** — verify midnight-verify plugin is installed (same as `/check`)
2. **Initialize Run** — create run directory with metadata (same as `/check`)
3. **Resolve Inputs** — parse arguments into content list (same as `/check`)
4. **Extract Claims** — parallel claim-extractor agents, merge, assign IDs (same as `/check`)
5. **Verify Claims** — dispatch @"midnight-verify:source-investigator (agent)" for ALL claims. No domain classification, no domain-specific routing. Batch in rounds of up to 5 concurrent agents. Each gets the claim verbatim + source file/line context.
6. **Generate Report** — load reporting skill, generate report.md + terminal summary (same as `/check`)
7. **GitHub Issues** — conditional issue creation if GitHub source + refuted claims (same as `/check`)

**What's cut vs `/check`:**
- No classification stage (saves 4 parallel agent dispatches + merge)
- No domain-specific routing (everything goes to source-investigator)
- No execution agents (no contract-writer, type-checker, sdk-tester, cli-tester, witness-verifier, zkir-checker)

**Verdict qualifiers:** Always `(source-verified)` since only source-investigator runs.

## Files Changed

### New
- `plugins/midnight-fact-check/commands/fast-check.md`

### Modified
- `plugins/midnight-fact-check/.claude-plugin/plugin.json` — version bump
