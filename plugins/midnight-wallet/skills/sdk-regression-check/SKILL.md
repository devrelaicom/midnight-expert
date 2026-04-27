---
name: midnight-wallet:sdk-regression-check
description: >-
  This skill should be used when the user wants to verify the wallet SDK is
  current, check for SDK drift, has the wallet SDK updated, run an SDK
  regression test, validate that wallet patterns are still valid, do a
  wallet SDK version check, smoke test the wallet SDK, validate a wallet
  SDK installation, debug wallet SDK pattern failures, troubleshoot wallet
  SDK errors, diagnose wallet SDK failures, when wallet SDK is not
  working, why wallet SDK code is failing, wallet SDK runtime errors,
  wallet construction failing, WalletFacade.init throwing, sync stuck or
  never completes, transaction recipe rejected, signature mismatch in
  wallet SDK, type errors after upgrading wallet SDK, or when code that
  worked yesterday no longer works.
---

# SDK Regression Check

A drift-detection layer for the wallet SDK patterns documented in this
plugin. Two modes: a fast no-network drift check, and a slow live-devnet
smoke test.

## When to invoke

- Before trusting any pattern from `midnight-wallet:wallet-sdk` or
  `midnight-wallet:managing-test-wallets`, especially after a Midnight
  release or after a long gap in the project
- When patterns fail unexpectedly (signature mismatch, runtime error,
  unexpected types)
- When the user reports "code that worked yesterday no longer works"

## Lock-file policy

`versions.lock.json` is owned by plugin maintainers. Do NOT edit it as
part of running this skill. When drift is detected, report findings to
the user and stop. Updates to the lock file happen when the plugin is
released, not when this skill runs.

## Two modes

### Drift check (no network, fast)

```bash
${CLAUDE_SKILL_DIR}/scripts/drift-check.sh
```

Reads `versions.lock.json`, calls `npm view <package> version` for each
pinned package, classifies drift (`none`, `patch`, `minor`, `MAJOR`),
prints a table, exits 0 if all clean and 1 if any minor/major drift.

See `references/interpreting-output.md` for what to do per drift level.

### Smoke test (devnet required, slow)

```bash
${CLAUDE_SKILL_DIR}/scripts/smoke-test.sh
```

Spins up a temp project with the latest SDK packages, runs a fixture
that exercises the documented construction pattern end-to-end against
the local devnet, asserts a non-zero NIGHT balance for the genesis seed.

See `references/smoke-test-anatomy.md` for what each step verifies.

## References

| Reference | When to read |
|-----------|--------------|
| `references/interpreting-output.md` | After running drift-check.sh |
| `references/using-release-notes.md` | When drift is detected |
| `references/temp-project-setup.md` | When smoke-test.sh fails for environmental reasons |
| `references/smoke-test-anatomy.md` | When smoke-test.sh fails and you need to know which SDK layer broke |

## Related skills

| Need | Skill |
|------|-------|
| Wallet SDK reference | `midnight-wallet:wallet-sdk` |
| Test-wallet patterns | `midnight-wallet:managing-test-wallets` |
| Local devnet management | `midnight-tooling:devnet` |
| View Midnight release notes | `midnight-tooling:view-release-notes` |
