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

[To be filled in during Task 5]

## REFACTOR Phase (Loopholes Found)

[To be filled in during Task 5]
