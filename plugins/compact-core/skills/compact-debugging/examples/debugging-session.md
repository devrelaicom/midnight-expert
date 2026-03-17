# Debugging Session Example: Cascading Errors

This walkthrough demonstrates the debugging process — symptom-driven triage, fix tracking, and escalation — using a realistic scenario where fixing one error reveals another.

## Scenario

A developer reports: "My contract won't compile. I get an 'unbound identifier' error."

## Step 1: Classify the Symptom

Error message: `unbound identifier public_key`

Triage table match: "unbound identifier" → Route to `compact-language-ref` (troubleshooting section) and `compact-standard-library` (verification protocol).

## Step 2: Investigate

Check whether `public_key` exists in the standard library.

**Finding:** Neither `public_key()` nor `publicKey()` exists in the Compact stdlib. This is a common hallucination. The correct pattern is a domain-separated hash:

```compact
// Wrong — does not exist
const pk = public_key(secret_key);

// Correct — domain-separated hash
const pk = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), secret_key]);
```

**Fix applied.** Update fix-tracking log.

### Fix-Tracking Log

| # | Symptom | Skill Used | Fix | Result |
|---|---------|-----------|-----|--------|
| 1 | `unbound identifier public_key` | compact-standard-library | Replace with persistentHash pattern | New error |

## Step 3: New Error After Fix

After fixing, the compiler now reports: `potential witness-value disclosure must be declared`

This is expected — the fix introduced a `persistentHash` call on witness-derived data, and the result flows to a ledger write without `disclose()`.

**Triage:** "potential witness-value disclosure" → Route to `compact-privacy-disclosure` (debugging-disclosure reference).

## Step 4: Apply Second Fix

The `persistentHash` output carries witness taint (unlike `persistentCommit` which clears it). Wrap the ledger write:

```compact
// Before (disclosure error)
owner = persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), local_secret_key()]);

// After (correct)
owner = disclose(persistentHash<Vector<2, Bytes<32>>>([pad(32, "myapp:pk:"), local_secret_key()]));
```

### Updated Fix-Tracking Log

| # | Symptom | Skill Used | Fix | Result |
|---|---------|-----------|-----|--------|
| 1 | `unbound identifier public_key` | compact-standard-library | Replace with persistentHash pattern | New error |
| 2 | `potential witness-value disclosure must be declared` | compact-privacy-disclosure | Add disclose() wrapper | Compiles |

## Step 5: Verify

Compile the contract. Result: **Compilation successful.**

Two consecutive fixes were needed, but both were in different error categories — this is normal cascading, not a sign of deeper issues. The escalation threshold (3+ consecutive failures in the same area) was not reached.

## Key Takeaways

1. **Symptom-driven triage** matched each error to the right skill immediately
2. **Fix tracking** made the cascade visible and prevented losing context
3. **Escalation was not needed** because each fix addressed a genuine issue in a different domain
4. The `public_key()` → `persistentHash` → `disclose()` cascade is a common real-world pattern
