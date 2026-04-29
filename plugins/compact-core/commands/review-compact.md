---
name: compact-core:review-compact
description: Comprehensive review of Compact smart contract code covering 10 categories including privacy, security, tokens, concurrency, performance, and more, plus mechanical verification via /midnight-verify:verify. Supports parallel execution via agent teams (when enabled) or concurrent subagents.
allowed-tools: Bash, Agent, Read, Glob, Grep, TaskCreate, TaskUpdate, TaskList, AskUserQuestion, ToolSearch
argument-hint: "[path/to/contract.compact or directory]"
---

Review Compact smart contract code across 10 review categories using parallel reviewer agents. Privacy findings are always shown first.

## Review Categories

1. Privacy & Disclosure
2. Security & Cryptographic Correctness
3. Token & Economic Security
4. Concurrency & Contention
5. Compilation & Type Safety
6. Performance & Circuit Efficiency
7. Architecture, State Design & Composability
8. Code Quality & Best Practices
9. Testing Adequacy
10. Documentation

## Step 1: Identify Files to Review

If `$ARGUMENTS` provides a path, use it. Otherwise, find all relevant files:

```bash
# Find all Compact and related files
find . -name "*.compact" -not -path "*/node_modules/*" -not -path "*/.compact/*"
find . -name "*.ts" -not -path "*/node_modules/*" -not -path "*/.compact/*" | grep -iE "(witness|private)" || true
find . \( -name "*.test.ts" -o -name "*.spec.ts" \) -not -path "*/node_modules/*" | head -20
```

Collect the file list and present it to the user for confirmation.

## Step 1.5: Compile the Contract

After identifying the files, compile the primary `.compact` contract using the Compact CLI to produce shared compilation evidence for all reviewers.

1. **Compile the contract** (syntax validation):
   Run `compact compile --skip-zk <contract-file>` and capture both stdout and stderr. Save the combined output as `COMPILE_RESULT`.

   If the compile fails, capture the diagnostics — reviewers should see the failure as evidence rather than block the review.

2. **Note witness files**: If any `.ts` files matching witness patterns were found in Step 1, record their paths for the verification step.

Store the compile output for injection into reviewer prompts in the next steps.

## Step 2: Check for Agent Teams

Run this command to detect agent team support:

```bash
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-not_set}"
```

## Step 3a: Agent Teams Mode

If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is set (not "not_set"):

Create an agent team to perform the review. Tell Claude:

> Create an agent team to review Compact code across 10 categories. Spawn 10 reviewer teammates, one per category. Each teammate should:
>
> 1. Invoke the `compact-core:compact-review` skill
> 2. Read their assigned reference file from the Category Reference Map
> 3. Reference the shared compilation evidence provided below
> 4. Read all files: [INSERT FILE LIST]
> 5. Apply every checklist item from their reference
> 6. Report findings in the structured format with severity levels
>
> Teammate assignments:
> - Teammate 1 — "Privacy & Disclosure" → read `privacy-review` reference
> - Teammate 2 — "Security & Cryptographic Correctness" → read `security-review` reference
> - Teammate 3 — "Token & Economic Security" → read `token-security-review` reference
> - Teammate 4 — "Concurrency & Contention" → read `concurrency-review` reference
> - Teammate 5 — "Compilation & Type Safety" → read `compilation-review` reference
> - Teammate 6 — "Performance & Circuit Efficiency" → read `performance-review` reference
> - Teammate 7 — "Architecture, State Design & Composability" → read `architecture-review` reference
> - Teammate 8 — "Code Quality & Best Practices" → read `code-quality-review` reference
> - Teammate 9 — "Testing Adequacy" → read `testing-review` reference
> - Teammate 10 — "Documentation" → read `documentation-review` reference
>
>
> **Shared compilation evidence:**
> - Compilation result: [INSERT COMPILE_RESULT]
>
> Use sonnet model for each teammate.
> Wait for ALL teammates to complete before synthesizing the consolidated report.

Proceed to Step 4 when all teammates finish.

## Step 3b: Subagent Mode (concurrent)

If agent teams are NOT available:

You MUST launch ALL 10 reviewer agents in a **SINGLE message** using 10 Agent tool calls. This ensures they run concurrently. Do NOT call them sequentially — that defeats the purpose of parallelization.

In ONE message, make ALL of these Agent tool calls simultaneously:

**Agent call 1:**
```
subagent_type: "compact-core:reviewer"
description: "Review privacy & disclosure"
prompt: "You are reviewing category: Privacy & Disclosure.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the privacy-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 2:**
```
subagent_type: "compact-core:reviewer"
description: "Review security & crypto"
prompt: "You are reviewing category: Security & Cryptographic Correctness.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the security-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 3:**
```
subagent_type: "compact-core:reviewer"
description: "Review token & economic security"
prompt: "You are reviewing category: Token & Economic Security.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the token-security-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 4:**
```
subagent_type: "compact-core:reviewer"
description: "Review concurrency & contention"
prompt: "You are reviewing category: Concurrency & Contention.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the concurrency-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 5:**
```
subagent_type: "compact-core:reviewer"
description: "Review compilation & types"
prompt: "You are reviewing category: Compilation & Type Safety.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the compilation-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 6:**
```
subagent_type: "compact-core:reviewer"
description: "Review performance & efficiency"
prompt: "You are reviewing category: Performance & Circuit Efficiency.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the performance-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 7:**
```
subagent_type: "compact-core:reviewer"
description: "Review architecture & state"
prompt: "You are reviewing category: Architecture, State Design & Composability.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the architecture-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 8:**
```
subagent_type: "compact-core:reviewer"
description: "Review code quality"
prompt: "You are reviewing category: Code Quality & Best Practices.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the code-quality-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 9:**
```
subagent_type: "compact-core:reviewer"
description: "Review testing adequacy"
prompt: "You are reviewing category: Testing Adequacy.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the testing-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**Agent call 10:**
```
subagent_type: "compact-core:reviewer"
description: "Review documentation"
prompt: "You are reviewing category: Documentation.
Files to review: [INSERT FILE LIST].
Invoke the compact-core:compact-review skill. Read the documentation-review reference from the Category Reference Map. Apply every checklist item systematically. Report findings using the structured output format with severity levels (Critical, High, Medium, Low, Suggestions). End with Positive Highlights.

Shared compilation evidence (pre-computed by orchestrator — reference when evaluating checklist items):
- Compilation result: [INSERT COMPILE_RESULT]"
```

**CRITICAL: All 10 Agent tool calls MUST be in a single message to ensure concurrent execution.**

## Step 3.5: Mechanical Verification

After all reviewer agents complete, run `/midnight-verify:verify` on the contract for mechanical verification:

```bash
/midnight-verify:verify <contract.compact>
```

If witness `.ts` files were identified in Step 1, include them:

```bash
/midnight-verify:verify <contract.compact> <witnesses.ts>
```

This provides authoritative verification of compilation, type correctness, witness consistency, and behavioral correctness. Include the verification results in the consolidated report.

## Step 4: Consolidated Report

After ALL reviewers complete, produce the consolidated report.

**Ordering rules:**
1. **Privacy & Disclosure is ALWAYS the first category** — regardless of severity
2. Remaining categories ordered by highest severity found (Critical > High > Medium > Low > Suggestions)
3. Within each category: Critical → High → Medium → Low → Suggestions
4. Deduplicate issues found by multiple reviewers (keep the most detailed version)
5. Aggregate all Positive Highlights at the end

**Report format:**

```
# Compact Code Review Report

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| High | N |
| Medium | N |
| Low | N |
| Suggestions | N |

**Files reviewed:** [list]

---

## 1. Privacy & Disclosure

[Privacy findings — ALWAYS FIRST]

---

## 2. [Next category by severity]

[Findings]

---

[... remaining categories ...]

---

## Mechanical Verification

**Contract:** [file path]
**Witness:** [file path, if applicable]
**Result:** [/midnight-verify:verify output — verdict and evidence summary]

---

## Positive Highlights

[Aggregated from all reviewers — what was done well]
```

Present the report to the user.
