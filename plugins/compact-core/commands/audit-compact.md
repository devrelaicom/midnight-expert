---
name: compact-core:audit-compact
description: Deep adversarial security audit of Compact smart contract code. Runs a single security-reviewer specialist over the threat model, then confirms Critical/High findings via midnight-verify and synthesizes a consolidated security report. Security-only; for a full 10-category review use /compact-core:review-compact.
allowed-tools: Bash, Agent, Read, Glob, Grep, SlashCommand, TaskCreate, TaskUpdate, TaskList, AskUserQuestion, ToolSearch
argument-hint: "[path/to/contract.compact or directory]"
---

Run a focused security audit of Compact code: one deep security-reviewer pass, then main-thread mechanical confirmation of Critical/High findings. You (the main thread) are the orchestrator — the security-reviewer agent cannot dispatch subagents, so you run all `midnight-verify` confirmations yourself.

## Step 1: Identify Files

If `$ARGUMENTS` provides a path, use it. Otherwise find candidates:

```bash
find . -name "*.compact" -not -path "*/node_modules/*" -not -path "*/.compact/*"
find . -name "*.ts" -not -path "*/node_modules/*" -not -path "*/.compact/*" | grep -iE "(witness|private)" || true
find . \( -name "*.test.ts" -o -name "*.spec.ts" \) -not -path "*/node_modules/*" | head -20
```

Present the file list and confirm with the user. Record witness `.ts` paths for the verification step.

## Step 2: Compile Once (shared evidence)

Compile the primary `.compact` contract:

```bash
compact compile --skip-zk <contract-file> <out-dir>
```

Capture combined stdout/stderr as `COMPILE_RESULT`. If compilation fails, keep the diagnostics as evidence — do not abort; a compile failure is itself security-relevant context for the reviewer.

## Step 3: Dispatch ONE security-reviewer agent

Make a single `Agent` call:

```
subagent_type: "compact-core:security-reviewer"
description: "Security audit of <contract>"
prompt: "Perform a security audit of the following files: [INSERT FILE LIST].
Invoke the compact-core:compact-security skill; walk references/threat-catalog.md and
references/witness-trust-boundary.md; pull granular criteria from the compact-review
security/token/privacy references via the Reuse Map. Report findings in the structured
format (Critical → Suggestion + Positive Highlights). Emit a ## Verification Requests
block for every Critical and High finding; if none, emit (none). Do NOT run midnight-verify
— hand the requests back to me.

Shared compilation evidence (reference when evaluating items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

Wait for the agent's report.

## Step 4: Parse Verification Requests

From the agent's report, extract the `## Verification Requests` block. Each `VR-n` has a `type` (poc | target | source), a `claim`, and a `suggested command`. If the block is `(none)`, skip to Step 6.

## Step 5: Run midnight-verify (main thread)

For the **target** contract, regardless of requests, run:

```
/midnight-verify:verify <contract.compact> [<witnesses.ts>]
```

Then for each Verification Request:
- `type: poc` or `type: source` → run `/midnight-verify:verify "<claim>"`.
- `type: target` → run `/midnight-verify:verify <contract.compact> [<witnesses.ts>]` (reuse the target result above if identical).

Record each verdict as **Confirmed**, **Refuted**, or **Inconclusive** with the evidence summary. If `midnight-verify` is unavailable (e.g. devnet down for an execution-only claim), mark the verdict basis explicitly (e.g. "source-only") and continue — never block the report.

## Step 6: Synthesize the consolidated report

Annotate each Critical/High finding with its verdict. **Downgrade Refuted findings but record that verification refuted them** (never silently drop). Keep Inconclusive findings with a note. Order: witness-trust/access-control and privacy first, then by severity. Produce:

```
# Compact Security Audit Report

## Summary
| Severity | Count | Confirmed | Refuted | Inconclusive |
|----------|-------|-----------|---------|--------------|
| Critical | N | … | … | … |
| High | N | … | … | … |
| Medium | N | — | — | — |
| Low | N | — | — | — |
| Suggestions | N | — | — | — |

**Files reviewed:** […]

## 1. Witness Trust Boundary & Access Control
[findings, each Critical/High annotated: **Verification:** Confirmed | Refuted | Inconclusive — evidence]

## 2. Cryptographic Correctness
## 3. Information Leakage & Disclosure
## 4. Token & Economic Security
## … (only sections with findings)

## Mechanical Verification
- Target: <`/midnight-verify:verify` result>
- VR-1 … VR-n: <verdict + evidence>

## Positive Highlights
[…]
```

Present the report to the user.
