# Using release notes when drift is detected

When `drift-check.sh` reports `minor` or `MAJOR` drift on one or more
packages, this is the workflow for translating the change into an
actionable report.

## Step-by-step workflow

1. **Identify the drifted packages** from the drift-check table.
2. **For each drifted package**, load the `midnight-tooling:view-release-notes` skill
   scoped to the version range from PINNED to LATEST.
3. **Search the notes** for keywords:
   - `BREAKING`
   - `removed`
   - `renamed`
   - `deprecated`
   - `migrated`
   - `ledger`  (a ledger-version bump usually cascades to wallet incompatibility)
4. **Map findings to documented patterns.** For each finding, identify which
   reference file or example script in `midnight-wallet:wallet-sdk` or
   `midnight-wallet:managing-test-wallets` would be affected.
5. **Run smoke-test.sh.** If it passes, the documented patterns still
   work despite the drift. If it fails, capture the failing step from
   the JSON output.
6. **Surface a structured report to the user.** Include:
   - Which packages drifted (PINNED → LATEST per package)
   - Relevant release-note bullets per package
   - Which documented patterns appear affected (file paths)
   - Whether the smoke test passed or failed (step name if failed)
7. **Stop.** Do not edit `versions.lock.json`. Do not edit the
   wallet-sdk references or managing-test-wallets examples. Updates
   to plugin content happen as deliberate plugin maintenance and ship
   in a plugin release, not as part of running this skill.

## Why "stop"

The whole point of pinning versions and version-checking on demand is
that updates to documented SDK patterns are a maintenance decision, not
an inference Claude makes mid-conversation. The user (or plugin
maintainer) decides when to update.
