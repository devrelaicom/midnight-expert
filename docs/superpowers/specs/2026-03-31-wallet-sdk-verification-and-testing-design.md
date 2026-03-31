# Wallet SDK Verification and Testing — Design Spec

**Date:** 2026-03-31
**Status:** Approved
**Scope:** Add wallet SDK verification to midnight-verify plugin; add wallet-testing and dapp-connector-testing skills to midnight-cq plugin

## Overview

The Midnight Wallet SDK (`midnightntwrk/midnight-wallet`) is a TypeScript monorepo implementing the Midnight Wallet Specification. It provides key generation, address formatting, transaction building, state syncing, and three distinct wallet types (shielded, unshielded, dust). Two categories of users need tooling support:

1. **Anyone making claims about the wallet SDK** — needs verification through midnight-verify
2. **Developers building on the wallet SDK** — need testing guidance through midnight-cq

This spec adds a new verification domain to midnight-verify and two new testing skills to midnight-cq.

## Design Decisions

- **Separate domain**: verify-wallet-sdk is a parallel domain skill (like verify-compact, verify-zkir, verify-witness), not an extension of verify-sdk. The wallet SDK has a different source repo, different package namespace (`@midnight-ntwrk/wallet-sdk-*` vs `@midnight-ntwrk/midnight-js-*`), and different verification needs.
- **Reuse agents**: No new agents. The existing type-checker, source-investigator, and sdk-tester agents gain wallet-sdk modes via context passed from the verifier orchestrator.
- **Source-first verification**: Source code inspection is the primary verification method for all wallet SDK claims. Type-checking is a fast pre-flight only (never produces a standalone verdict). Devnet E2E is a fallback only when source investigation is Inconclusive.
- **Layered method skill**: A dedicated `verify-by-wallet-source` method skill contains wallet-specific repo knowledge, loaded by the source-investigator for wallet claims. This keeps the general `verify-by-source` skill clean.
- **Two midnight-cq skills**: `wallet-testing` targets developers building custom wallet implementations on the SDK packages. `dapp-connector-testing` targets DApp developers integrating via the DApp Connector API. These are separate audiences with separate concerns.
- **No internal SDK standards enforcement**: The wallet SDK's internal coding standards (FP patterns, Effect/Either separation, stubs-over-mocks) are the SDK team's concern. Our skills target users writing code against the SDK, not inside it.

## Part 1: midnight-verify — verify-wallet-sdk

### 1.1 Domain Skill: verify-wallet-sdk

**Purpose:** Classify wallet SDK claims and route them to the correct verification methods.

**Domain indicators** (how the verifier orchestrator recognizes wallet SDK claims):

- References to `@midnight-ntwrk/wallet-sdk-*` packages
- WalletFacade, WalletBuilder, WalletRuntime, RuntimeVariant
- Three-wallet architecture (shielded-wallet, unshielded-wallet, dust-wallet)
- HD derivation, Bech32m addresses, branded types (ProtocolVersion, WalletSeed, WalletState)
- DApp Connector API (ConnectedAPI, InitialAPI, `window.midnight`)
- Capabilities (Balancer, ProvingService, SubmissionService, PendingTransactions)
- Indexer client, node client, prover client in wallet context

**Verification flow** (every wallet SDK claim follows this):

1. **Type-check** (fast pre-flight) — dispatch type-checker in wallet-sdk-workspace mode. If type-check fails, the claim is likely broken, but still proceed to source investigation for the definitive verdict.
2. **Source investigation** (always runs, primary evidence) — dispatch source-investigator, which loads `verify-by-wallet-source` for wallet-specific repo guidance.
3. **Devnet E2E** (fallback only) — dispatch sdk-tester in wallet-devnet mode only if source investigation returns Inconclusive.

**Routing table:**

| Claim Type | Example | Pre-flight | Primary | Fallback |
|---|---|---|---|---|
| Package/type existence | "WalletFacade exports balanceFinalizedTransaction" | type-checker | source-investigator | — |
| Function signature | "submitTransaction returns Observable\<SubmissionEvent\>" | type-checker | source-investigator | — |
| Interface shape | "ShieldedAddress has coinPublicKey and encryptionPublicKey" | type-checker | source-investigator | — |
| Branded type structure | "ProtocolVersion is a branded bigint" | type-checker | source-investigator | — |
| HD derivation paths | "Role 2 is Dust, path m/44'/2400'/0'/2/0" | — | source-investigator | — |
| Address encoding | "Bech32m prefix for shielded is mn_shield-addr" | — | source-investigator | — |
| Three-token architecture | "Dust balance is time-dependent" | — | source-investigator | — |
| Variant/runtime behavior | "WalletRuntime migrates state between protocol versions" | — | source-investigator | sdk-tester |
| Transaction lifecycle | "SubmissionEvent goes Submitted → InBlock → Finalized" | type-checker | source-investigator | — |
| DApp Connector API | "ConnectedAPI.makeTransfer creates a shielded transfer" | type-checker | source-investigator | sdk-tester |
| Behavioral claims | "WalletFacade.init syncs all three wallets" | — | source-investigator | sdk-tester |
| Indexer/node integration | "IndexerClient retries 3 times on 502-504" | — | source-investigator | — |

**Verdict qualifiers:**

No `Confirmed (type-checked)` alone — type-checking is pre-flight only. Wallet SDK verdicts use:

- `Confirmed (source-verified)` — source investigation found definitive evidence
- `Confirmed (source-verified + tested)` — source confirmed, devnet E2E also passed
- `Refuted (source-verified)` — source contradicts the claim
- `Refuted (type-checked + source-verified)` — type-check failed and source confirms it's wrong
- `Inconclusive (source insufficient, devnet unavailable)` — couldn't confirm via source, devnet not running

### 1.2 Method Skill: verify-by-wallet-source

**Purpose:** Wallet-specific source investigation guidance for the source-investigator agent.

**Repository routing table:**

| Claim About | Primary Repo | Key Paths |
|---|---|---|
| Facade API, unified wallet operations | `midnightntwrk/midnight-wallet` | `packages/facade/src/` |
| Variant/runtime, hard-fork migration | `midnightntwrk/midnight-wallet` | `packages/runtime/src/` |
| Shielded wallet, ZK coin management | `midnightntwrk/midnight-wallet` | `packages/shielded-wallet/src/v1/` |
| Unshielded wallet, Night UTXO | `midnightntwrk/midnight-wallet` | `packages/unshielded-wallet/src/v1/` |
| Dust wallet, fee mechanics | `midnightntwrk/midnight-wallet` | `packages/dust-wallet/src/v1/` |
| Branded types, core abstractions | `midnightntwrk/midnight-wallet` | `packages/abstractions/src/` |
| Coin selection, balancing, proving, submission | `midnightntwrk/midnight-wallet` | `packages/capabilities/src/` |
| HD key derivation, BIP32/BIP39 | `midnightntwrk/midnight-wallet` | `packages/hd/src/` |
| Bech32m address encoding | `midnightntwrk/midnight-wallet` | `packages/address-format/src/` |
| Common utilities | `midnightntwrk/midnight-wallet` | `packages/utilities/src/` |
| GraphQL indexer sync | `midnightntwrk/midnight-wallet` | `packages/indexer-client/src/` |
| Polkadot RPC submission | `midnightntwrk/midnight-wallet` | `packages/node-client/src/` |
| ZK proof generation client | `midnightntwrk/midnight-wallet` | `packages/prover-client/src/` |
| DApp Connector API types | `midnightntwrk/midnight-dapp-connector-api` | `src/api.ts` |

**Search strategy:**

1. Start with octocode-mcp `githubSearchCode` against `midnightntwrk/midnight-wallet`
2. For API surface claims — check the package's `src/index.ts` exports first, then trace to implementation
3. For DApp Connector claims — search `midnightntwrk/midnight-dapp-connector-api` source
4. Clone locally (to /tmp, shallow) only when tracing cross-package dependencies or counting exports across the monorepo
5. Clean up cloned repos after investigation

**Evidence rules:**

Source code is evidence. Everything else is a hint.

| Source | Role | Rule |
|---|---|---|
| Source code definitions (function signatures, type exports, implementation) | Primary evidence | Always the target. Verdicts must cite source code. |
| Test files | Navigation aid | Follow test imports to find the right source code. Do not cite tests as evidence. Running tests (clone to /tmp, execute) is a last resort — realistically never needed. |
| docs-snippets, spec documents (Wallet Spec, DApp Connector Spec, Ledger Spec) | Hints only | Useful for orienting where to look. Never evidence on their own. Any claim derived from these must be corroborated by source code inspection. |
| ADRs, Design.md | Hints only | Can support "why" claims, but the "what" they describe must be verified via source. |

### 1.3 Changes to Existing midnight-verify Components

**verifier agent (`agents/verifier.md`):**
- Add Wallet SDK to domain list in description
- Add dispatch rules: wallet SDK claims → load `verify-wallet-sdk`, dispatch type-checker (pre-flight) then source-investigator (primary), optionally sdk-tester (fallback)
- Add wallet SDK examples to description

**verify-correctness hub skill (`skills/verify-correctness/SKILL.md`):**
- Add "Wallet SDK" row to domain classification table with indicators
- Add wallet-specific verdict qualifiers
- Add rule: for wallet SDK claims, type-checking is pre-flight only, never a standalone verdict

**type-checker agent (`agents/type-checker.md`):**
- Add wallet-sdk-workspace mode to description

**verify-by-type-check skill (`skills/verify-by-type-check/SKILL.md`):**
- Add wallet-sdk-workspace setup section
- Workspace path: `.midnight-expert/verify/wallet-sdk-workspace/`
- Package list: `@midnight-ntwrk/wallet-sdk-facade`, `@midnight-ntwrk/wallet-sdk-shielded`, `@midnight-ntwrk/wallet-sdk-unshielded-wallet`, `@midnight-ntwrk/wallet-sdk-dust-wallet`, `@midnight-ntwrk/wallet-sdk-runtime`, `@midnight-ntwrk/wallet-sdk-abstractions`, `@midnight-ntwrk/wallet-sdk-capabilities`, `@midnight-ntwrk/wallet-sdk-hd`, `@midnight-ntwrk/wallet-sdk-address-format`, `@midnight-ntwrk/wallet-sdk-utilities`, `@midnight-ntwrk/wallet-sdk-indexer-client`, `@midnight-ntwrk/wallet-sdk-node-client`, `@midnight-ntwrk/wallet-sdk-prover-client`, `@midnight-ntwrk/dapp-connector-api`, `typescript`
- Mode selection: verifier passes `domain: 'wallet-sdk'` context; type-checker uses wallet-sdk-workspace when domain is wallet-sdk, sdk-workspace otherwise

**source-investigator agent (`agents/source-investigator.md`):**
- Add wallet SDK to description
- When claim domain is wallet SDK → load `verify-by-wallet-source` instead of `verify-by-source`

**sdk-tester agent (`agents/sdk-tester.md`):**
- Add wallet-devnet fallback mode to description

**verify-by-devnet skill (`skills/verify-by-devnet/SKILL.md`):**
- Add wallet-devnet mode section
- Health check: Docker containers (midnight-node, midnight-indexer, proof-server) instead of standalone devnet
- Note: this mode is fallback-only for wallet SDK claims, reached only when source investigation is Inconclusive
- Workspace reuses wallet-sdk-workspace (same packages needed)

## Part 2: midnight-cq — wallet-testing

### 2.1 Skill: wallet-testing

**Purpose:** Guide developers writing tests for custom wallet implementations and extensions built on the wallet SDK packages.

**Target audience:** Developers building custom wallet variants, extending capabilities, implementing custom services, or composing wallets via WalletBuilder.

**Scope — what users are doing:**
- Building custom wallet variants for new protocol versions
- Extending capabilities (custom coin selection, custom balancing)
- Implementing custom services (alternative proving backends, custom indexer sync)
- Composing wallets via WalletBuilder with their own variants
- Working with the three wallet types at the SDK level

**What this skill does NOT cover:**
- Testing DApp code that integrates via the DApp Connector API (use `dapp-connector-testing`)
- Testing Compact contracts (use `compact-testing`)
- Testing DApp UI end-to-end (use `dapp-testing`)
- Enforcing the wallet SDK's internal coding standards (FP patterns, Effect/Either separation) — those are the SDK team's concern

**Decision guide:**

| Question | Skill |
|---|---|
| Am I building a custom wallet variant or capability? | `wallet-testing` (this skill) |
| Am I integrating with the wallet via the DApp Connector API? | `dapp-connector-testing` |
| Am I testing Compact contract logic? | `compact-testing` |
| Am I testing DApp UI flows? | `dapp-testing` |

**Core testing challenges (the boundary problem):**

Users write their own code in whatever style they choose, but must interact with SDK types at the interface boundary. The skill covers:

1. **Unwrapping Effect/Either in tests** — SDK methods return `Effect<A, E>` and `Either<A, E>`. Tests need `Effect.runPromise()`, `Effect.runSync()`, `Exit.isFailure()`, `Either.isRight()`.
2. **Asserting on Observable state** — WalletFacade exposes `state(): Observable<FacadeState>`. Tests need to subscribe, filter for conditions, assert on emitted values.
3. **Constructing branded type fixtures** — ProtocolVersion, WalletSeed, WalletState, NetworkId are branded. Tests need valid instances.
4. **Satisfying SDK interfaces for test doubles** — custom capabilities and services must implement the correct interfaces (e.g., `TransactingCapability` returns `Either<[Result, State], WalletError>`).
5. **Setting up WalletBuilder in tests** — wiring variants, providing initial state, starting the runtime.

**Anti-patterns:**
- Unwrapping Effect with `try/catch` instead of `Effect.runPromiseExit`
- Asserting on Observable without waiting for the right emission
- Constructing branded types with plain casts instead of the SDK's constructors
- Providing partial interface implementations that pass TypeScript but fail at runtime
- Sharing wallet instances across tests (state bleeds)

### 2.2 Reference: effect-boundary-patterns.md

Covers how to unwrap and assert on Effect/Either results in Vitest tests:

- `Effect.runPromise()` for happy-path async assertions
- `Effect.runSync()` for synchronous assertions
- `Effect.runPromiseExit()` + `Exit.isFailure()` for testing failure paths
- Mock services via `Layer.succeed()` for providing test doubles to Effect services
- Testing Effect Streams — collecting emissions, asserting on stream contents
- `Either.isRight()` / `Either.isLeft()` for pure capability return values

### 2.3 Reference: wallet-builder-setup.md

Covers constructing wallets in test contexts:

- Using `WalletBuilder.init().withVariant()` to compose test wallets
- Constructing valid initial state for each wallet type
- Providing test doubles for capabilities (coin selection, balancing) that satisfy the interface
- Providing test doubles for services (proving, submission, sync) that satisfy the interface
- Constructing branded type instances (ProtocolVersion, WalletSeed, NetworkId)
- Starting and stopping wallet runtime in beforeEach/afterEach

### 2.4 Reference: observable-testing.md

Covers testing RxJS Observable state exposed by the facade:

- Subscribing to `walletFacade.state()` in tests
- Using `firstValueFrom` with `filter` to wait for specific state conditions
- Asserting on FacadeState shape (shielded balances, unshielded balances, dust balance, sync progress)
- Testing state transitions (pending → confirmed → finalized)
- Cleaning up subscriptions in afterEach to prevent test leaks

## Part 3: midnight-cq — dapp-connector-testing

### 3.1 Skill: dapp-connector-testing

**Purpose:** Guide DApp developers writing tests for their DApp Connector API integration — the `window.midnight` injection, `InitialAPI.connect()`, and `ConnectedAPI` methods.

**Target audience:** DApp developers integrating with the wallet through the standard DApp Connector API.

**Relationship to existing dapp-testing skill:**
- `dapp-connector-testing` (this skill) — "is my DApp Connector integration correct?"
- `dapp-testing` — "does my UI work end-to-end?"

They complement each other. `dapp-testing` covers Playwright E2E and generic integration patterns. This skill is specifically about testing the API contract between DApp and wallet.

**Scope — what users are testing:**
- Connection lifecycle (discovery, `apiVersion` validation, `connect()`, disconnect)
- Balance queries (`getShieldedBalances`, `getUnshieldedBalances`, `getDustBalance`)
- Address queries (`getShieldedAddresses`, `getUnshieldedAddress`, `getDustAddress`)
- Transaction creation (`makeTransfer`, `makeIntent`)
- Transaction balancing (`balanceUnsealedTransaction`, `balanceSealedTransaction`)
- Transaction submission (`submitTransaction`)
- Data signing (`signData` with encoding options)
- Configuration and status (`getConfiguration`, `getConnectionStatus`)
- Proving delegation (`getProvingProvider`)
- Permission hinting (`hintUsage`)
- Error handling (all 5 error codes)
- Progressive enhancement (graceful degradation when methods throw PermissionRejected)

**Wallet stub patterns:**
The skill provides guidance on building configurable test doubles that implement `InitialAPI` and `ConnectedAPI`:
- Stubs return controlled data (specific balances, addresses, transaction results)
- Stubs can be configured to throw specific error codes
- Stubs can simulate different wallet behaviors (connected, disconnected, permission-denied)
- More detailed than dapp-testing's generic `page.addInitScript` wallet mock

**Error handling test patterns:**
- `Rejected` (transient) vs `PermissionRejected` (permanent per session) — test that DApp retries after Rejected but backs off after PermissionRejected
- `Disconnected` — test reconnection flow
- `InternalError` — test error display to user
- `InvalidRequest` — test request validation before sending

### 3.2 Reference: connector-stub-patterns.md

Complete ConnectedAPI test double implementations:
- Base stub implementing all ConnectedAPI methods with configurable return values
- Factory functions for common scenarios (funded wallet, empty wallet, disconnected wallet)
- Simulating balance changes between calls (for testing state refresh)
- Simulating transaction lifecycle (submit → pending → confirmed → finalized)
- Injecting stubs into both unit tests (direct import) and E2E tests (`page.addInitScript`)

### 3.3 Reference: error-handling-patterns.md

Test patterns for each error code:
- Testing that DApp distinguishes Rejected from PermissionRejected
- Testing Disconnected detection and reconnection
- Testing that DApp validates requests before sending (preventing InvalidRequest)
- Testing progressive enhancement — DApp calls `hintUsage`, handles PermissionRejected for individual methods, falls back to reduced functionality
- Testing that DApp sanitizes wallet name/icon (XSS prevention per spec)

## File Inventory

### New files — midnight-verify (2)

| File | Purpose |
|---|---|
| `skills/verify-wallet-sdk/SKILL.md` | Domain skill — routing table |
| `skills/verify-by-wallet-source/SKILL.md` | Method skill — wallet source investigation guidance |

### Modified files — midnight-verify (7)

| File | Change |
|---|---|
| `agents/verifier.md` | Add wallet SDK domain, dispatch rules, examples |
| `skills/verify-correctness/SKILL.md` | Add Wallet SDK to domain classification, verdict qualifiers, pre-flight-only rule |
| `agents/type-checker.md` | Add wallet-sdk-workspace mode to description |
| `skills/verify-by-type-check/SKILL.md` | Add wallet-sdk-workspace setup, package list, mode switching |
| `agents/source-investigator.md` | Add wallet SDK, load verify-by-wallet-source for wallet claims |
| `agents/sdk-tester.md` | Add wallet-devnet fallback mode |
| `skills/verify-by-devnet/SKILL.md` | Add wallet-devnet mode, Docker health checks, fallback-only note |

### New files — midnight-cq (7)

| File | Purpose |
|---|---|
| `skills/wallet-testing/SKILL.md` | Testing custom wallet implementations |
| `skills/wallet-testing/references/effect-boundary-patterns.md` | Unwrapping Effect/Either in tests |
| `skills/wallet-testing/references/wallet-builder-setup.md` | WalletBuilder wiring, test doubles |
| `skills/wallet-testing/references/observable-testing.md` | Observable state testing |
| `skills/dapp-connector-testing/SKILL.md` | Testing DApp Connector API integration |
| `skills/dapp-connector-testing/references/connector-stub-patterns.md` | ConnectedAPI test doubles |
| `skills/dapp-connector-testing/references/error-handling-patterns.md` | Error code test patterns |

### Modified files — midnight-cq (4)

| File | Change |
|---|---|
| `.claude-plugin/plugin.json` | Add keywords for new skills |
| `README.md` | Document new skills |
| `agents/cq-runner.md` | Recognize wallet SDK test projects when running quality checks |
| `agents/cq-reviewer.md` | Recognize wallet SDK test projects in audit |

### Total: 9 new files, 11 modified files. No new agents.
