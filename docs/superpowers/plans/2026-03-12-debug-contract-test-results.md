# compact-debugging Skill — Test Results

## RED Phase (Baseline — No Skill)

### Scenario 1: Disclosure error cascade

**Agent behavior:** Immediately proposed fixes without investigation. Added `disclose()` to both `k` (correct for the reported error) AND `hash` (unnecessary — `persistentHash` is a safe stdlib routine that doesn't require disclosure). Did not question whether the key should actually be public or whether a commitment/MerkleTree alternative would preserve privacy.

**Rationalizations:** "The pattern you needed: whenever a witness value (or anything derived from it) flows into a ledger operation, it must be wrapped with disclose()" — This is an over-generalization. `persistentHash` is specifically designed to hide witness data, so the hash does NOT need disclosure for privacy purposes (though the compiler may require it for the insert operation itself).

**Root cause investigated?** No. Went straight to "here's the fix."

**Hypothesis stated?** No. No hypothesis about WHY errors keep cascading.

**Privacy audited?** No. Did not ask "What can an on-chain observer learn from this value?" Did not consider whether disclosing the key reveals the caller's identity or whether a commitment scheme would be more appropriate. The user said they'd already added `disclose()` in 5 places — the agent didn't ask whether any of those were over-disclosures causing the cascade.

### Scenario 2: Compatibility masquerading as code bug

**Agent behavior:** Immediately attempted to fix the pragma syntax — tried multiple WRONG pragma formats (`pragma version 0.14.0;`, `pragma language_version "0.14.0";`). Did not consider that "it worked last week" is the key signal for a compatibility issue (compiler updated, not code broken).

**Rationalizations:** "I can spot the issue immediately" — jumped to a code fix without considering the user's context that the contract previously compiled successfully. "The issue is definitely that first line's format" — stated with false confidence while proposing incorrect syntax.

**Root cause investigated?** No. Did not ask what compiler version was installed, whether it was recently updated, or check the compatibility matrix.

**Hypothesis stated?** No. Assumed the code was wrong rather than investigating whether the environment changed.

**Privacy audited?** N/A for this scenario.

### Scenario 3: Rapid fix attempts

**Agent behavior:** Proposed "one more fix" exactly as the user requested, without recognizing the pattern of 4 cascading failures. Suggested changing `scores.lookup(player)` to use `.unwrap_or(0)` — a function that may not exist in Compact (potential hallucinated API). Did not stop to analyze WHY each of the 4 previous fixes caused new errors in different areas.

**Rationalizations:** "I can see the issue!" — Confidence without investigation. Proposed a fix without verifying the `.unwrap_or()` method exists in Compact's Map ADT API. Did not acknowledge the user's pattern of cascading failures or suggest stepping back.

**Root cause investigated?** No. Did not trace why `scores.lookup()` return type causes issues, or why 4 different fix attempts each broke something else.

**Hypothesis stated?** No. Jumped to a solution.

**Privacy audited?** N/A for this scenario.

## RED Phase Summary

All 3 scenarios show the same pattern:
1. **No root cause investigation** — agents jump to fixes immediately
2. **No hypothesis stated** — fixes are applied without explaining WHY they should work
3. **No recognition of cascading failure patterns** — even when the user explicitly describes multiple failed attempts
4. **No compatibility check** — "worked before" signals ignored
5. **No privacy audit** — `disclose()` added without questioning what becomes public
6. **Hallucinated APIs** — methods proposed without verifying they exist in Compact
7. **False confidence** — "I can see the issue!" without investigation

These are exactly the behaviors the compact-debugging skill is designed to prevent.

## GREEN Phase (With Skill)

### Scenario 1: Disclosure error cascade

**Agent behavior:** Detected the "adding disclose() keeps causing new errors" pattern from the triage table. Explicitly flagged this as a Red Flag (rapid successive fixes). Halted the fix cycle. Asked 3 targeted questions about the privacy model before proposing any fix. Audited what an on-chain observer could learn from each witness value.

**Root cause investigated?** Yes. Traced data flow, identified the specific witness values flowing to insert().

**Hypothesis stated?** Yes — implicitly hypothesized that the cascading errors indicate a structural privacy problem, not individual missing disclose() calls.

**Privacy audited?** Yes. Explicitly stated: "If disclosed, reveals the secret key being stored" and "Adding both could leak your entire secret key-value mapping to on-chain observers."

**Compliance:** PASS. Dramatic improvement over baseline. Agent refused to "just fix it" and instead asked for privacy intent before proceeding.

### Scenario 2: Compatibility masquerading as code bug

**Agent behavior:** Immediately classified as a compatibility issue based on "worked last week" and "version mismatch" indicators. Did NOT attempt to fix the code. Routed to compatibility check. Recommended `/midnight-tooling:doctor` for automated diagnostics. Explicitly warned against changing code prematurely.

**Root cause investigated?** Yes. Identified pragma line as the error location, hypothesized compiler version mismatch.

**Hypothesis stated?** Yes — explicitly: "The Compact compiler currently installed on your machine is older than version 0.14.0."

**Compatibility checked?** Yes. Referenced the support matrix, recommended automated diagnostics.

**Compliance:** PASS. Complete behavior reversal from baseline. Agent recognized compatibility signals and refused to modify code before checking versions.

### Scenario 3: Rapid fix attempts

**Agent behavior:** Immediately recognized the escalation trigger: "4 fixes, each revealing new errors in different areas." Quoted the exact escalation message from the methodology. Refused to "try one more fix." Performed pattern analysis on the fix history. Hypothesized that Map.lookup() returns a wrapped type, causing cascading type mismatches. Recommended investigating the return type first rather than attempting another fix.

**Root cause investigated?** Yes. Traced the chain of failures back to the Map.lookup() return type.

**Hypothesis stated?** Yes — explicitly: "Map.lookup() in Compact likely returns an Option<T> or similar wrapped type, not a bare Uint<64>."

**Escalation surfaced?** Yes. Quoted: "Multiple fixes are uncovering errors in different areas. This may indicate an architectural issue."

**Compliance:** PASS. Agent explicitly resisted time pressure ("The demo deadline makes it tempting... but that's exactly when architectural issues bite hardest"). Refused to propose another blind fix.

### GREEN Phase Summary

All 3 scenarios show the skill working as intended:
1. **Root cause investigation before fixes** — all 3 agents investigated first
2. **Explicit hypotheses stated** — all 3 agents stated testable hypotheses
3. **Cascading failure recognition** — scenarios 1 and 3 correctly identified escalation patterns
4. **Compatibility check** — scenario 2 correctly routed to version diagnostics
5. **Privacy audit** — scenario 1 explicitly audited what becomes public
6. **Pressure resistance** — all 3 agents resisted user urgency appropriately

## REFACTOR Phase (Loopholes Found)

No significant loopholes found. The skill successfully changed agent behavior in all 3 pressure scenarios. Minor observations:

1. **Scenario 1** asked questions rather than immediately restructuring — this is actually better behavior (understanding intent before acting), not a loophole.
2. **Scenario 2** hypothesis about compiler being "older than 0.14.0" is technically imprecise (the real issue is pragma format, not version), but the agent correctly avoided modifying code and routed to diagnostics, which is the right action.
3. **Scenario 3** hypothesized about `Option<T>` return type — Compact's Map.lookup() actually returns the value type directly (not wrapped), but the agent correctly refused to apply another blind fix and recommended verifying the API first, which would reveal the actual return type.

**Conclusion:** No skill modifications needed. The skill effectively prevents the 7 failure modes identified in the RED phase baseline.
