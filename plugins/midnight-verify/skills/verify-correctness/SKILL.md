---
name: midnight-verify:verify-correctness
description: >-
  Hub skill for the midnight-verify plugin. Classifies claims by domain,
  routes to the appropriate domain skill (verify-compact or verify-sdk),
  dispatches sub-agents (contract-writer and/or source-investigator) based
  on the domain skill's routing, and synthesizes final verdicts. Always loaded
  first by the verifier agent.
version: 0.2.0
---

# Verification Hub

You are the verification orchestrator. This skill tells you how to classify claims, route them, dispatch sub-agents, and synthesize verdicts.

## Process

### 1. Classify the Domain

Determine what domain the claim belongs to:

| Domain | Indicators | Route To |
|---|---|---|
| **Compact language** | Compact syntax, stdlib functions, types, disclosure, compiler behavior, patterns, privacy, circuit costs | Load `midnight-verify:verify-compact` |
| **SDK/TypeScript** | API signatures, @midnight-ntwrk packages, import paths, type definitions, providers, DApp connector | Load `midnight-verify:verify-sdk` |
| **Cross-domain** | Spans both Compact and SDK, or protocol/architecture | Load both domain skills |

### 2. Load the Domain Skill

Load the appropriate domain skill(s) using the Skill tool. The domain skill provides a routing table that tells you which verification method(s) to use.

### 3. Dispatch Sub-Agents

Based on the domain skill's routing:

- **Execution needed** → dispatch `midnight-verify:contract-writer` agent with the claim
- **Source inspection needed** → dispatch `midnight-verify:source-investigator` agent with the claim
- **Both needed** → dispatch BOTH agents **concurrently** (they are independent and can run in parallel)

When dispatching, pass:
- The claim verbatim
- Any relevant context (file path, code snippet, what specifically to check)
- For the contract-writer: what observable behavior would confirm/refute the claim
- For the source-investigator: which repo/area to focus on (from the domain skill's routing)

### 4. Synthesize the Verdict

Collect the sub-agent report(s) and produce the final verdict.

**Verdict options:**

| Verdict | Qualifier | When to Use |
|---|---|---|
| **Confirmed** | (tested) | Contract-writer compiled and ran code; output matched the claim |
| **Confirmed** | (source-verified) | Source-investigator found definitive source evidence confirming the claim |
| **Confirmed** | (tested + source-verified) | Both methods used and both agree the claim is correct |
| **Refuted** | (tested) | Contract-writer compiled and ran code; output contradicts the claim |
| **Refuted** | (source-verified) | Source-investigator found definitive source evidence contradicting the claim |
| **Refuted** | (tested + source-verified) | Both methods disagree with the claim |
| **Refuted** | (tested, source disagrees) | Execution contradicts but source seems to support — execution wins, disagreement noted |
| **Inconclusive** | — | Couldn't test via execution AND couldn't find definitive source evidence |

**When sub-agents disagree:** Execution evidence wins. The code ran and produced a result — that's more authoritative than interpreting source. But you MUST note the disagreement in your report so the user is aware.

**Inconclusive verdicts must explain:**
- Why the claim couldn't be tested via execution
- Why source inspection was insufficient
- What the user could do to resolve it (e.g., "this requires runtime benchmarking on a live network")

### 5. Format the Final Report

```markdown
## Verdict: [Confirmed|Refuted|Inconclusive] ([qualifier])

**Claim:** [the claim as stated — verbatim]

**Method:** [tested|source-verified|tested + source-verified]

**Evidence:**
[Summarize what was done and what was observed. For execution: describe the test
contract, compilation result, and runtime output. For source: describe where you
looked, what you found, with file paths and links. Include enough detail that the
user can independently verify your finding.]

**Conclusion:**
[One or two sentences: why the evidence confirms, refutes, or is inconclusive.]
```

**For file verification** (when given a `.compact` file to verify):

Extract individual claims from the file — assertions in comments, patterns used, stdlib functions called, type annotations, disclosure usage. Verify each claim separately. Group findings by line/section. Provide an overall summary at the end.

## What This Skill Does NOT Do

- It does not contain domain-specific verification logic — that lives in `verify-compact` and `verify-sdk`
- It does not contain method-specific instructions — those live in `verify-by-execution` and `verify-by-source`
- It does not directly verify anything — it classifies, routes, dispatches, and synthesizes
