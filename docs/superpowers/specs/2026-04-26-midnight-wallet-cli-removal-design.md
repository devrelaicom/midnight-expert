# Remove wallet-cli / wallet-MCP from `midnight-wallet` plugin; add `managing-test-wallets` and `sdk-regression-check` skills

**Date:** 2026-04-26
**Branch:** `fix-wallet-plugin`
**Status:** Design — pending user approval

---

## Summary

The `midnight-wallet` plugin currently wraps `midnight-wallet-cli` (an unofficial CLI) and its `midnight-wallet-mcp` server. The wrapper has become a source of hard-to-diagnose failures, likely because the unofficial CLI has drifted from the wallet SDK and is not being updated in lockstep with Midnight Network releases.

This spec removes the CLI/MCP layer entirely, restructures the plugin around the wallet SDK directly, and adds two new skills that teach the SDK patterns Claude needs to handle test-wallet workflows in conversation. A small descriptive doc is added to `midnight-tooling:devnet` to capture the local-devnet genesis seed. The `midnight-expert:doctor` skill is updated to drop its check for the (now-deleted) wallet MCP.

After this change, `midnight-wallet` ships three skills — `wallet-sdk` (reference, expanded per a fresh source audit), `managing-test-wallets` (procedural patterns + example scripts), and `sdk-regression-check` (drift detection + smoke test) — with no commands, no hooks, no MCP server.

---

## Motivation

The unofficial `midnight-wallet-cli` and `midnight-wallet-mcp` are an extra abstraction layer between Claude and the wallet SDK. Recent failures are hard to debug because problems can originate in the CLI, in the MCP wrapper, in the SDK itself, or in version skew between any of those. Removing the layer means:

- One fewer thing that can drift or break independently of the SDK
- Direct, source-verifiable knowledge for Claude (the SDK is the source of truth)
- Smaller blast radius for upstream changes — only the SDK's release notes matter
- No reliance on a third-party package's release cadence

The cost is real: convenience tooling like "create a funded test wallet in one command" no longer exists. The trade-off is that Claude can write equivalent ad-hoc TypeScript using the SDK directly, and that script is verifiable end-to-end.

---

## Constraints

These constraints apply to every artifact this spec touches:

1. **Public distribution.** All plugin content ships to other users via the marketplace. No references to local-only paths (`/tmp/...`), to specific example DApps the author has cloned, or to author-private documentation. Patterns are described generically and verified against the wallet SDK source.
2. **Source verification.** Every API claim (signatures, exports, types, behavior) is verified against the `midnightntwrk/midnight-wallet` repository before shipping. Inferred or recalled claims are prohibited; if a claim cannot be verified, it is omitted or labeled as needing verification.
3. **Framing of SDK stability.** Use "the Midnight Network ecosystem moves quickly, and there may be breaking changes between SDK versions." Do not claim the SDK "breaks frequently" or similar — that is an assertion we cannot back up.
4. **Knowledge placement.** Local-devnet facts go in `midnight-tooling:devnet`. Wallet patterns go in `midnight-wallet`. Cross-skill workflows are coordinated via cross-references, not by duplicating content.

---

## Goals

- Remove every trace of `midnight-wallet-cli` and `midnight-wallet-mcp` from the plugin and from cross-plugin references
- Give Claude a single, well-bounded skill for managing test wallets in two scenarios: embedded-in-DApp and ad-hoc
- Provide a fast, scriptable mechanism to detect SDK drift and verify the canonical wallet construction pattern still works
- Update `wallet-sdk` to cover material the audit found missing, particularly the variant/runtime pattern, the Effect-based dual API, and the capabilities sub-modules
- Make a single descriptive entry in `midnight-tooling:devnet` for the genesis seed (where it conceptually belongs), without changing devnet behavior

## Non-goals

- Building a replacement CLI for `midnight-wallet-cli`
- Automating preprod/preview faucet interaction (no public faucet API has been confirmed; the SDK pattern is "print address, wait for balance" and that is what we will document)
- Changing `midnight-tooling:devnet`'s compose template or scripts; the existing `CFG_PRESET: 'dev'` already produces the genesis-seed pre-mint that the SDK pattern relies on
- Persistent test-wallet aliasing (the local devnet wipes wallets on restart, so persistent name→address mapping has no durable utility)
- Implementing a faucet-API spike inside this design (it is flagged as an implementation-time investigation; the design accommodates either outcome)

---

## Removals

All paths are relative to the repo root unless noted.

### From `plugins/midnight-wallet/`

- `.mcp.json` — wires the wallet MCP server
- `commands/fund-mnemonic.md` — uses MCP tools that will no longer exist; the `commands/` directory is deleted entirely
- `hooks/hooks.json` — every entry matches `mcp__midnight-wallet__*`; no hook survives
- `hooks/scripts/session-start-health.sh` — shells out to `npx midnight-wallet-cli@latest`; no longer relevant
- `hooks/` directory itself
- `skills/wallet-cli/` — entire skill, references, and any subfiles
- `skills/setup-test-wallets/` — entire current MCP-orchestrated skill
- `skills/wallet-aliases/` — alias store and script (its main consumer was the MCP-resolution hook)

### From `plugins/midnight-expert/`

- `skills/doctor/scripts/check-mcp-servers.sh` — remove the line that lists `midnight-wallet|midnight-wallet|claude mcp add midnight-wallet -- npx -y -p midnight-wallet-cli@latest midnight-wallet-mcp|midnight-wallet`. The script structure stays; only that one entry is dropped.
- `skills/doctor/references/fix-table.md` — remove the row whose left column is `midnight-wallet not configured`. Other rows are unchanged.

---

## Additions

### `plugins/midnight-wallet/skills/managing-test-wallets/`

A new skill that teaches Claude SDK-driven patterns for creating, funding, monitoring, and transferring with test wallets. The skill is procedural — Claude reads its references and adapts the example scripts to the situation. The skill ships no commands and no persistent tooling.

Layout:

```
managing-test-wallets/
  SKILL.md
  references/
    addresses-and-tokens.md
    wallet-creation.md
    funding.md
    dust-registration.md
    balance-monitoring.md
    transfers.md
    network-config.md
    troubleshooting.md
  examples/
    create-wallet.ts
    fund-wallet-undeployed.ts
    fund-wallet-public-faucet.ts
    register-dust.ts
    monitor-wallet.ts
    transfer-night.ts
    transfer-shielded.ts
    full-test-wallet-setup.ts
```

The example scripts are templates — Claude lifts them and adapts to the user's project. Each example header pins the SDK package versions it was verified against and points at `sdk-regression-check` for the drift workflow.

### `plugins/midnight-wallet/skills/sdk-regression-check/`

A new skill that gives Claude a fast way to ask "are the SDK patterns documented in this plugin still correct?". Two modes: a no-network drift check that compares pinned versions to npm, and a slow smoke test that runs the canonical construction pattern against a local devnet.

Layout:

```
sdk-regression-check/
  SKILL.md
  versions.lock.json
  references/
    interpreting-output.md
    using-release-notes.md
    temp-project-setup.md
    smoke-test-anatomy.md
  scripts/
    drift-check.sh
    smoke-test.sh
    fixtures/
      smoke-test.ts
```

Cross-referenced from both `wallet-sdk` (in its critical-caveat section) and `managing-test-wallets` (same).

### `plugins/midnight-tooling/skills/devnet/references/genesis-seed.md`

A single descriptive reference. Captures the local-devnet genesis seed value, explains that the `dev` preset's chain spec pre-mints NIGHT to the wallet derived from that seed, includes a security warning that the seed is public and devnet-only, and cross-links to `midnight-wallet:managing-test-wallets` for the funding pattern. No behavior change — just a fact this skill should own.

---

## Updates

### `plugins/midnight-wallet/skills/wallet-sdk/`

The audit confirmed the existing references (quick-reference, wallet-construction, key-derivation, state-and-balances, transactions, infrastructure-clients) are accurate and detailed. The gaps surfaced by the audit are added as new references and edits to existing ones.

**New references to add:**

- `references/variants-and-runtime.md` — covers the variant/runtime pattern that organizes each wallet for hard-fork compatibility. Documents `WalletBuilder<TWalletFamily>`, `WalletRuntime<TWalletFamily>`, the `RuntimeVariant` interface (`tag`, `startSync()`, `migrateFromPrevious()`), and the visitor-style `dispatch<T>(fn: PolyFunction<T>)` on `Runtime.WalletBase`. Explains when a user would touch this directly (advanced custom-variant scenarios) vs. when the facade is enough.
- `references/effect-and-promise-apis.md` — documents that most services expose both Promise-based and Effect-based flavors. Promise APIs are the default for most consumers; Effect APIs (under `*Effect` exports and `./effect` sub-modules) provide composable lazy operations with typed errors extending `Data.TaggedError`. Lists which sub-modules expose the Effect flavor.
- `references/capabilities-deep-dive.md` — covers the `wallet-sdk-capabilities` package's five sub-exports: `./balancer` (`Balancer`, `CounterOffer`, `Imbalances`), `./submission` (`SubmissionService<T>`, `makeDefaultSubmissionService`), `./pendingTransactions` (`PendingTransactionsService<T>`, persistence trait), `./proving` (`ProvingService<T>`, `UnboundTransaction`, `makeDefaultProvingService`, `makeSimulatorProvingServiceEffect`), `./simulation` (`Simulator`, `SimulatorState`, in-memory wallet for testing). Notes that the `Balancer` rebalances across all three wallet types — a single instance, not three.
- `references/errors-and-troubleshooting.md` — lists the per-wallet error types (`shielded/v1/WalletError`, `unshielded-wallet/v1/WalletError`, `dust-wallet/v1/WalletError`), the cross-cutting errors (`WalletRuntimeError`, `URLError`, `ClientServerErrors`, `NodeClientError`), and the `Data.TaggedError` discriminator pattern. Includes a small table of common runtime symptoms with where to look first.

**Updates to existing references:**

- `quick-reference.md`:
  - Add the `@midnight-ntwrk/wallet-sdk` meta-package and its sub-paths (`./address-format`, `./capabilities`, `./dust`, `./facade`, `./hd`, `./proving`, `./shielded`, `./testing`, `./unshielded`)
  - Enumerate sub-exports per package: `node-client/effect`, `node-client/testing`, `indexer-client/effect`, `prover-client/effect`, `runtime/abstractions`, `utilities/networking`, `utilities/testing`, `capabilities/{balancer,submission,pendingTransactions,proving,simulation}`
  - Expand the `wallet-sdk-utilities` row: `ArrayOps`, `BlobOps`, `DateOps`, `EitherOps`, `RecordOps`, `LedgerOps`, `SafeBigInt`, `ObservableOps`; networking sub-module (`HttpURL`, `WsURL`); type-level utilities (`hlist`, `polyFunction`, `Fluent`)
  - Add `WalletFacade.fetchTermsAndConditions` and the `TermsAndConditions` type
  - Add `Clock` (`{ readonly now: () => Date }`) for injectable time in tests
  - Add `Simulator` and `SimulatorState` from the simulation sub-module
- `infrastructure-clients.md`: add a section pointing to `capabilities-deep-dive.md` for the customization layer (balancer/proving/submission/pending-transactions service overrides during `WalletFacade.init`)
- `transactions.md`: cross-link `errors-and-troubleshooting.md` from the "Reverting Transactions" section
- `state-and-balances.md`: add a one-paragraph note on the `Clock` injection point and how it interacts with `dust.balance(time)`
- `SKILL.md`:
  - Remove the related-skills row referencing `midnight-wallet:wallet-cli`
  - Add rows for `midnight-wallet:managing-test-wallets` and `midnight-wallet:sdk-regression-check`
  - Add a new top-of-file caveat block linking to `sdk-regression-check` for drift verification
  - Expand the deep-dive references table to include the four new files

The audit also surfaced two specific points that need verification at implementation time, not design time:

- The `TransactionHistoryStorage<T>.getAll()` return type. Current skill says `AsyncIterableIterator<T>`; the audit summary says `Promise<T[]>`. The skill is internally consistent with `getAllFromTxHistory()` returning an async iterator in `transactions.md`, so the existing claim may be correct, but the discrepancy must be reconciled by reading the actual `abstractions/src/index.ts` source.
- The `serialize()` return type. Current skill says `Promise<SerializedTransactionHistory>`; the audit says `Promise<string>`. Same — verify from source.

These are flagged as part of the implementation plan, not the design.

### `plugins/midnight-wallet/.claude-plugin/plugin.json`

- `description`: rewrite to "Wallet SDK reference, test-wallet management patterns, and SDK regression checking for Midnight Network development."
- `keywords`: drop `mcp`, `wallet-cli`. Keep `wallet`, `wallet-sdk`, `night-tokens`, `dust-tokens`, `transfer`, `airdrop`, `balance`, `test-wallets`, `devnet`, `bip39`, `mnemonic`, `wallet-facade`, `hd-wallet`. Add `shielded`, `unshielded`, `sdk-regression`.
- `version`: bump to `0.4.0` (breaking — entire MCP/CLI surface removed, hooks gone, commands gone)

### `plugins/midnight-wallet/README.md`

Full rewrite around the three-skill structure. No mention of MCP, no mention of CLI. Briefly describes each skill's role and when Claude reaches for it.

---

## Detailed design

### `managing-test-wallets/SKILL.md`

Triggers on: create test wallet, fund a wallet, get tNight from a faucet, register DUST, monitor wallet balance, transfer NIGHT or shielded tokens, derive a wallet from a seed or BIP-39 mnemonic, set up wallets for tests, watch an address for incoming funds, generate dust.

Body opens with the critical caveat (verify SDK is current via `sdk-regression-check`), follows with a "When to use this skill" table that names the two scenarios (embedded-in-DApp vs. ad-hoc one-off), then a "three-address model" section that warns about the most common mistake (faucet expects unshielded; do not give it the shielded address), then the decision-tree table:

| User wants… | Reference | Example |
|-------------|-----------|---------|
| Generate a brand-new wallet | `wallet-creation.md` | `create-wallet.ts` |
| Restore from BIP-39 mnemonic / hex seed | `wallet-creation.md` | `create-wallet.ts` |
| Fund on local devnet | `funding.md` | `fund-wallet-undeployed.ts` |
| Fund on preprod or preview | `funding.md` | `fund-wallet-public-faucet.ts` |
| Register DUST | `dust-registration.md` | `register-dust.ts` |
| Watch balance changes | `balance-monitoring.md` | `monitor-wallet.ts` |
| Transfer NIGHT | `transfers.md` | `transfer-night.ts` |
| Transfer shielded tokens | `transfers.md` | `transfer-shielded.ts` |
| End-to-end (create + fund + dust) | all of the above | `full-test-wallet-setup.ts` |

Closes with a related-skills table linking to `wallet-sdk` (reference), `sdk-regression-check`, `midnight-tooling:devnet` (genesis seed and devnet management), `midnight-dapp-dev:dapp-connector` (browser flow), `midnight-dapp-dev:midnight-sdk` (provider setup), and `midnight-cq:wallet-testing` (test patterns).

### `managing-test-wallets/references/`

- **`addresses-and-tokens.md`** — three sub-wallets (`UnshieldedWallet`, `ShieldedWallet`, `DustWallet`), three address types (`UnshieldedAddress` `mn_addr_*`, `ShieldedAddress`, `DustAddress`), three balance shapes. Faucets and the genesis-seed airdrop fund the unshielded address. Shielded tokens are minted via Zswap, not via faucets. DUST is generated over time from registered NIGHT UTXOs.
- **`wallet-creation.md`** — random seed via `generateRandomSeed`, BIP-39 mnemonic via `generateMnemonicWords` / `validateMnemonic` / `mnemonicToSeedSync`, hex seed via `Buffer.from(hex, 'hex')`. HD derivation pattern. Construction with `WalletFacade.init`. Memory hygiene (`hdWallet.clear()`).
- **`funding.md`** — network-keyed strategies. For `undeployed`: build a facade from the genesis seed (cross-link to `midnight-tooling:devnet#genesis-seed`), wait for sync, transfer NIGHT to the new wallet's unshielded address, wait for the new wallet to observe the balance. For `preprod` / `preview`: print the unshielded address, print the faucet URL, subscribe to wallet state, log when the balance becomes non-zero. Notes the spike on whether either testnet has a programmatic faucet API; the script is structured so an API path can drop in if found.
- **`dust-registration.md`** — what DUST is (fee resource generated from registered NIGHT UTXOs over time), why it must be registered before any transaction can pay fees, the `registerNightUtxosForDustGeneration` recipe flow (balance, sign, finalize, submit), how `estimateRegistration` reports the fee and per-UTXO yield. Calls out that `state.dust.balance(date)` requires a `Date` parameter because DUST expires.
- **`balance-monitoring.md`** — `wallet.state()` returns an `Observable<FacadeState>`. Subscribe and read `state.unshielded.balances['']` (NIGHT, 6 decimals), `state.shielded.balances` (per-token-type), `state.dust.balance(new Date())`. Handle the "wait until isSynced" pattern with `waitForSyncedState()`. Sample loop: filter for synced, then sample at an interval until a target balance is reached or a timeout fires.
- **`transfers.md`** — three transfer kinds. Unshielded NIGHT via `transferTransaction` with a `CombinedTokenTransfer` of `type: 'unshielded'`. Shielded via `type: 'shielded'`. Combined (atomic shielded + unshielded) by passing both. Recipe → sign → finalize → submit. Fee estimation via `estimateTransactionFee`. The `payFees` option default and when to override.
- **`network-config.md`** — `DefaultConfiguration` shape per network. `undeployed` points at `127.0.0.1:9944` / `8088` / `6300` (devnet). `preprod` points at `https://rpc.preprod.midnight.network`, `https://indexer.preprod.midnight.network/api/v3/graphql`, and a host-local proof server. `preview` is parallel. Each comes with a `setNetworkId('undeployed' | 'preprod' | 'preview')` call from `@midnight-ntwrk/midnight-js-network-id`. WebSocket polyfill required for Node (`(globalThis as any).WebSocket = WebSocket;`).
- **`troubleshooting.md`** — common symptoms keyed to causes: stale UTXO (retry after a short wait), DUST required (run register-dust first), sync stuck (check devnet health via `midnight-tooling:devnet`), websocket churn (polyfill in Node), zero balance after faucet (verify unshielded address; faucets do not fund shielded), transaction rejected after major SDK version bump (run `sdk-regression-check --smoke`).

### `managing-test-wallets/examples/`

Each example file opens with a header comment block:

```ts
// Verified against the package versions pinned in
// midnight-wallet:sdk-regression-check/versions.lock.json on 2026-04-26.
// If your installed @midnight-ntwrk/wallet-sdk-* versions differ,
// run scripts/drift-check.sh in that skill before trusting this template.
```

Body is a self-contained TypeScript script that runs under `npx tsx`. Comments mark the steps a reader can vary.

- **`create-wallet.ts`** — single canonical wallet construction. Generates random seed by default; accepts `--seed <hex>` or `--mnemonic "<phrase>"` via `process.argv`. Outputs unshielded, shielded, dust addresses on stdout.
- **`fund-wallet-undeployed.ts`** — takes a recipient unshielded address as an arg. Builds a sender facade from the genesis seed (loaded from a constant in the script with the standard local-devnet seed value, and a comment cross-referencing `midnight-tooling:devnet#genesis-seed`). Waits for sync. Transfers NIGHT. Waits for the recipient's balance to reflect. Exits 0 when confirmed.
- **`fund-wallet-public-faucet.ts`** — takes a recipient unshielded address and a network identifier (`preprod` or `preview`). Prints the faucet URL and the address. Subscribes to wallet state. Polls until the balance is non-zero or a timeout fires. The script is structured so a future programmatic faucet path can replace the "print and wait" branch without restructuring.
- **`register-dust.ts`** — takes a wallet seed and registers all available NIGHT UTXOs for DUST generation. Uses `estimateRegistration` first to print the fee preview, then runs the full registration recipe.
- **`monitor-wallet.ts`** — takes an unshielded address (optionally also a shielded and a dust address) and prints a live ticker of balances on each state emission. Highlights when DUST appears.
- **`transfer-night.ts`** — takes a sender seed, a recipient unshielded address, and an amount. Builds the transfer recipe, signs, finalizes, submits, prints the transaction identifier.
- **`transfer-shielded.ts`** — same shape as `transfer-night.ts`, but with `type: 'shielded'` outputs and a recipient shielded address.
- **`full-test-wallet-setup.ts`** — wires the above into one end-to-end script. On `undeployed`: create → fund via genesis → register DUST → print summary. On `preprod`/`preview`: create → print address + faucet URL → wait → register DUST → print summary.

### `sdk-regression-check/SKILL.md`

Triggers on: verify wallet SDK is current, check for SDK drift, has the wallet SDK updated, SDK regression test, are these wallet patterns still valid, wallet SDK version check, smoke test the wallet SDK, validate wallet SDK installation, debug wallet SDK pattern failures.

Body opens with "When to invoke" — before trusting any pattern from `wallet-sdk` or `managing-test-wallets`, when patterns fail unexpectedly, after a Midnight release, on a long-running project after a gap. Then the two modes:

- **Drift check (no network).** `scripts/drift-check.sh` reads `versions.lock.json`, calls `npm view <package> version` for each pinned package, classifies drift (`none`, `patch`, `minor`, `major`) per package, prints a table, exits 0 if all clean and 1 if any minor/major drift.
- **Smoke test (devnet required).** `scripts/smoke-test.sh` creates a temp directory, runs `npm init -y`, installs the latest `@midnight-ntwrk/wallet-sdk-*` packages plus the matching `@midnight-ntwrk/ledger-*`, then `npx tsx fixtures/smoke-test.ts` against the local devnet.

The smoke fixture (`fixtures/smoke-test.ts`) executes the canonical pattern: load the local-devnet genesis seed, derive keys, init `WalletFacade`, wait for sync, assert the unshielded NIGHT balance is non-zero (i.e. the dev preset's pre-mint reached this seed). Failure produces a structured error pointing at which step broke (HD derivation, key conversion, init, sync, balance read).

The "How Claude reads the output" section is a table:

| Drift level | Meaning | What Claude does next |
|-------------|---------|-----------------------|
| `none` per package | No drift | Trust patterns; nothing to do |
| `patch` per package | Patch bump (no API change by SemVer) | Trust patterns; optionally update `versions.lock.json` to reduce noise |
| `minor` per package | New features, no removed APIs | Read release notes for new features that affect documented patterns; spot-check the relevant example; bump `versions.lock.json` |
| `major` per package | Breaking changes possible | Run `smoke-test.sh`. If smoke passes, the pattern still works — read release notes to learn what changed and update references. If smoke fails, follow the drift workflow below. |
| Smoke fail with no drift detected | Devnet, proof server, or environment issue | Run `midnight-tooling:devnet health`; check proof server; retry. Do not change the SDK skill content. |

The "Drift workflow with release notes" section walks Claude through the response to a major drift:

1. Identify drifted packages from `drift-check.sh`
2. For each drifted package, invoke the `midnight-tooling:view-release-notes` skill scoped to the version range from the pinned version to the latest
3. Look for: removed exports, renamed methods, changed signatures, deprecated APIs, ledger-version bumps
4. Translate findings into concrete edits to `wallet-sdk` references and `managing-test-wallets` examples
5. Re-run `smoke-test.sh` after edits. If it passes, bump `versions.lock.json` (`packages` and `verified` date)
6. If it still fails, surface a structured report with the failing step and the relevant release-note bullets so the user can decide whether to roll back or update further

### `sdk-regression-check/versions.lock.json`

```json
{
  "verified": "2026-04-26",
  "packages": {
    "@midnight-ntwrk/wallet-sdk": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-facade": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-hd": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-shielded": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-unshielded-wallet": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-dust-wallet": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-capabilities": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-abstractions": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-address-format": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-runtime": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-utilities": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-indexer-client": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-node-client": "<pin from npm>",
    "@midnight-ntwrk/wallet-sdk-prover-client": "<pin from npm>"
  }
}
```

The actual values are populated at implementation time by running `npm view <pkg> version` for each. The audit found current versions for many of these (wallet-sdk-facade@4.0.0, wallet-sdk-shielded@3.0.0, etc.) but those values must be re-fetched at implementation time so the lock reflects the moment the smoke test passes.

### `sdk-regression-check/references/`

- **`interpreting-output.md`** — full version of the table above, with worked examples of each row's interpretation.
- **`using-release-notes.md`** — workflow for handing drift to `midnight-tooling:view-release-notes`. Includes the version-range scoping pattern and the keywords to search for in the notes (`BREAKING`, `removed`, `renamed`, `deprecated`, `migrated`, `ledger`).
- **`temp-project-setup.md`** — manual steps for what `smoke-test.sh` automates: `mkdir`, `cd`, `npm init -y`, `npm install <packages>`, `npm install -D tsx typescript @types/node`, `npx tsx <fixture>`. Useful when the script fails for environmental reasons and the user wants to drive it manually.
- **`smoke-test-anatomy.md`** — step-by-step description of what the fixture does (build genesis-seed wallet, init facade, wait for sync, assert non-zero balance) so Claude can debug a failure to a specific step.

### `sdk-regression-check/scripts/`

- **`drift-check.sh`** — bash, depends on `npm` and `jq`. Reads `versions.lock.json`, queries npm registry for current versions, classifies drift per package by SemVer comparison, prints the table, exits with 0 (clean) or 1 (drift detected).
- **`smoke-test.sh`** — bash. Creates a temp dir under `$TMPDIR` (with a trap to clean up), runs `npm init -y`, `npm install <each package at latest>`, `npm install -D tsx typescript @types/node`, runs `npx tsx <skill_dir>/scripts/fixtures/smoke-test.ts`, surfaces the script's exit code, prints timings.
- **`fixtures/smoke-test.ts`** — TypeScript fixture. Reads the local-devnet genesis seed (constant), derives keys, builds `WalletFacade`, waits for sync, asserts `state.unshielded.balances[''] > 0n`. Logs each step. Exits 0 on success, 1 with a structured error message identifying the failed step on failure.

### `genesis-seed.md` (in `midnight-tooling:devnet/references/`)

Contents (final, ready to drop in):

```markdown
# Genesis Seed (Local Devnet Only)

The local devnet's `dev` preset pre-mints NIGHT tokens to the wallet
derived from this seed:

    0000000000000000000000000000000000000000000000000000000000000001

Building a wallet from this seed against the local devnet gives access
to the pre-minted NIGHT, which is the standard way to fund test wallets
for development workflows.

## Why it works

`templates/devnet.yml` sets `CFG_PRESET: 'dev'` on the node service.
The `dev` preset's chain spec includes a pre-mint to the wallet derived
from the seed above.

## When to use it

Funding test wallets on the local devnet. See
`midnight-wallet:managing-test-wallets` for the SDK-driven funding
pattern that uses this seed.

## Security warning

LOCAL DEVNET ONLY. This seed is well-known. Never use it on `preprod`,
`preview`, or any environment that handles real value. Anyone running
the local devnet has full access to the funds at this seed.
```

### Doctor cleanup

`plugins/midnight-expert/skills/doctor/scripts/check-mcp-servers.sh` currently includes the line:

```
"midnight-wallet|midnight-wallet|claude mcp add midnight-wallet -- npx -y -p midnight-wallet-cli@latest midnight-wallet-mcp|midnight-wallet"
```

It is removed. The script's structure (looping over a list of expected MCP servers) is unchanged.

`plugins/midnight-expert/skills/doctor/references/fix-table.md` currently includes:

```
| midnight-wallet not configured | `claude mcp add midnight-wallet -- npx -y -p midnight-wallet-cli@latest midnight-wallet-mcp` |
```

The row is removed. Other rows stay.

### Plugin metadata and README

`plugin.json` updates listed under "Updates → plugin.json" above.

`README.md` rewrite, structured around three sections (one per skill), each describing the skill's role, when Claude reaches for it, and any setup the user needs to do (e.g. `sdk-regression-check` needs a local devnet for the smoke test). No mention of MCP, CLI, or commands.

---

## Verification at implementation time

These items are deliberately not resolved in this design and become checks during implementation:

1. **Faucet API existence on `preprod` and `preview`.** Spike: probe `https://faucet.preprod.midnight.network/` and `https://faucet.preview.midnight.network/` for any documented or discoverable API endpoint. If found, `fund-wallet-public-faucet.ts` calls it. If not, it stays in the print-and-wait pattern.
2. **`TransactionHistoryStorage<T>.getAll()` return type.** Reconcile the existing skill's `AsyncIterableIterator<T>` claim with the audit summary's `Promise<T[]>`. Read `packages/abstractions/src/index.ts` from the SDK source and update the skill if needed.
3. **`TransactionHistoryStorage<T>.serialize()` return type.** Same — `Promise<SerializedTransactionHistory>` (current skill) vs. `Promise<string>` (audit). Verify from source.
4. **Pin actual versions in `versions.lock.json`.** Run `npm view` for each of the 14 packages and write the resolved versions into the file at the moment the smoke test passes for the first time.
5. **Smoke test acceptance threshold.** Confirm the pre-mint amount the `dev` preset deposits to the genesis seed, so the smoke assertion can be `>= <expected-min>` rather than just `> 0n`. If the value is brittle across image versions, a `> 0n` assertion is acceptable but should be documented.
6. **`@midnight-ntwrk/wallet-sdk` meta-package version.** The audit names version 1.0.0 but this is a fast-moving package; verify and pin at implementation time.

---

## Acceptance criteria

- `grep -ri "wallet-cli\|midnight-wallet-cli\|midnight-wallet-mcp" plugins/` returns no matches outside the changelog/spec docs
- `plugins/midnight-wallet/` contains exactly the three skills described, no `commands/`, no `hooks/`, no `.mcp.json`
- `plugins/midnight-tooling/skills/devnet/templates/devnet.yml` is byte-identical to its current state (no behavior change)
- `plugins/midnight-tooling/skills/devnet/references/genesis-seed.md` exists and matches the content above
- `plugins/midnight-expert/skills/doctor/` no longer mentions the wallet MCP in any file
- `scripts/drift-check.sh` runs cleanly against a freshly populated `versions.lock.json`
- `scripts/smoke-test.sh` passes against a running local devnet
- The `wallet-sdk` skill's references include the four new files and the `quick-reference.md` updates from the audit findings
- Every example script in `managing-test-wallets/examples/` runs end-to-end against a freshly started local devnet (or, for public-faucet examples, prints the right URL and address and exits cleanly when funds arrive)
- `plugin.json` version is bumped to `0.4.0`
- `README.md` makes no mention of MCP, CLI, or commands

---

## Out of scope

- A replacement CLI for `midnight-wallet-cli`. The user's stated direction is to teach Claude SDK patterns, not to ship another tool.
- Persistent test-wallet aliasing across devnet restarts (devnet wipes, so persistence has no durable utility).
- Programmatic faucet automation for testnets unless the implementation-time spike finds a public API.
- Any changes to `midnight-tooling:devnet` beyond the single new reference file.
- Onboarding work for the audit's deeper findings about the variant/runtime visitor pattern beyond a documentation reference; if the SDK exposes hooks for users to register custom variants, that is a separate skill or example, not part of this rewrite.
