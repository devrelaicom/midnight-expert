# Verify SDK Skill — Design Spec

**Date:** 2026-03-28
**Status:** Draft
**Scope:** Implement SDK/TypeScript verification for the midnight-verify plugin. Replaces the verify-sdk placeholder with full claim classification, type-checking verification, devnet E2E verification, and updates to the hub and existing components.

## Problem

The verify-sdk skill is currently a placeholder returning Inconclusive for all SDK claims. SDK verification is fundamentally different from Compact verification:

- The SDK is a TypeScript layer that coordinates external services (node, indexer, proof server, wallet). Most SDK operations can't be tested without live infrastructure.
- However, a large class of SDK claims — API signatures, type definitions, import paths, interface shapes — can be verified purely through TypeScript compilation (`tsc --noEmit`) with no infrastructure needed.
- Behavioral claims about the deploy/call/state lifecycle require a running local devnet.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Agent reuse | Reuse source-investigator for midnight-js, add type-checker and sdk-tester | Source-investigator already does repo search; new methods need new agents |
| Type-checking oracle | `tsc --noEmit` | Definitive for types, signatures, imports — no runtime needed |
| Package checks | Delegate to `devs:deps-maintenance` agent (fallback: `npm view` directly) | Generic dependency agent, not Midnight-specific |
| Devnet lifecycle | Managed by `midnight-tooling:devnet` skill | verify-sdk just checks if services are reachable |
| SDK workspace | `.midnight-expert/verify/sdk-workspace/`, lazy init | Same pattern as Compact workspace, separate to avoid cross-contamination |
| SDK packages | Install all `@midnight-ntwrk/midnight-js-*` packages | Covers any possible claim, no "missing package" failures |
| Devnet approach | Both raw SDK scripts and testkit-js, agent chooses | Raw for isolation tests, testkit for complex lifecycle |
| Hub updates | Explicit — hub knows about all agents | Clear dispatch logic, no implicit discovery |
| User code verification | Type-checker handles both claim mode and file mode | Most user SDK errors are type errors catchable by tsc |

## Architecture

### New Files

```
plugins/midnight-verify/
├── skills/
│   ├── verify-sdk/SKILL.md              # SDK claim classification + routing
│   ├── verify-by-type-check/SKILL.md    # tsc --noEmit verification method
│   └── verify-by-devnet/SKILL.md        # E2E devnet verification method
├── agents/
│   ├── type-checker.md                  # Writes TS test files, runs tsc
│   └── sdk-tester.md                    # Writes E2E scripts, runs against devnet
```

### Modified Files

```
plugins/midnight-verify/
├── skills/
│   ├── verify-correctness/SKILL.md      # Hub — add new agents to dispatch
│   └── verify-by-source/SKILL.md        # Add midnight-js repo to routing
├── agents/
│   └── verifier.md                      # Update description + skills list
```

### Data Flow

**Type-checking flow (Tier 1 — no infrastructure):**

```
/verify "deployContract returns DeployedContract"
         |
         v
   verifier → classify → "SDK API type claim"
         |
         v
   Load verify-sdk → route to type-checker
         |
         v
   Dispatch type-checker agent (sonnet)
   loads: verify-by-type-check
         |
         v
   1. Ensure SDK workspace exists (lazy init)
   2. Write test.ts with type assertions
   3. Run tsc --noEmit
   4. Interpret compiler output
         |
         v
   Report: "tsc compiled clean, return type matches"
         |
         v
   Verdict: Confirmed (type-checked)
```

**Devnet flow (Tier 2 — requires infrastructure):**

```
/verify "deployContract deploys and returns a contract address"
         |
         v
   verifier → classify → "SDK behavioral claim"
         |
         v
   Load verify-sdk → route to sdk-tester
         |
         v
   Dispatch sdk-tester agent (sonnet)
   loads: verify-by-devnet
         |
         v
   1. Check devnet health (node, indexer, proof server)
   2. If unreachable → Inconclusive (devnet unavailable)
   3. Write E2E script (raw SDK or testkit-js)
   4. Run script
   5. Interpret output
         |
         v
   Verdict: Confirmed (tested)
```

**User file verification:**

```
/verify src/deploy.ts
         |
         v
   verifier → classify → "SDK TypeScript file"
         |
         v
   Dispatch type-checker (types) + sdk-tester (behavior, if devnet available)
   Concurrent if both applicable
         |
         v
   Type-checker: copies file to workspace, runs tsc, reports type errors
   SDK-tester: if devnet up, runs the file or exercises its key functions
         |
         v
   Verdict: synthesized from both reports
```

**Package/version verification:**

```
/verify "@midnight-ntwrk/midnight-js-contracts is at version 4.0.2"
         |
         v
   verifier → classify → "SDK package claim"
         |
         v
   Dispatch deps-maintenance agent
         |
         v
   npm view @midnight-ntwrk/midnight-js-contracts version
         |
         v
   Verdict: Confirmed/Refuted (package-verified)
```

## Skill Specifications

### 1. verify-sdk (SDK Domain Skill)

Replaces the placeholder. Loaded by the verifier agent alongside the hub skill for SDK claims.

**Claim classification for method routing:**

| SDK Claim Type | Example | Dispatch |
|---|---|---|
| API function exists | "deployContract is exported from contracts" | **type-checker** |
| Function signature / return type | "deployContract returns DeployedContract" | **type-checker** |
| Type/interface shape | "MidnightProviders has a walletProvider field" | **type-checker** |
| Import path correctness | "import { deployContract } from '@midnight-ntwrk/midnight-js-contracts'" | **type-checker** |
| Error class hierarchy | "CallTxFailedError extends TxFailedError" | **type-checker** |
| Package exists / version | "@midnight-ntwrk/midnight-js-contracts is at version 4.0.2" | **deps-maintenance** |
| Export count / package structure | "contracts package exports 91 symbols" | **source-investigator** |
| Implementation details | "httpClientProofProvider retries 3 times with exponential backoff" | **source-investigator** |
| Provider behavior | "LevelDB provider encrypts with AES-256-GCM" | **source-investigator** |
| Deploy/call lifecycle works | "deployContract deploys and returns a contract address" | **sdk-tester** |
| Transaction pipeline behavior | "submitCallTx proves, balances, submits, and waits" | **sdk-tester** |
| State query behavior | "getPublicStates returns on-chain ledger state" | **sdk-tester** |
| DApp code type-correctness | "This provider setup code is valid" | **type-checker** |
| Witness implementation | "This witness correctly implements the contract interface" | **type-checker** (+ **contract-writer** for Compact side) |
| Provider configuration | "This provider config connects to devnet correctly" | **type-checker** + **sdk-tester** |
| Transaction handling code | "This error handling catches CallTxFailedError" | **type-checker** |
| E2E integration | "This deploy+call flow works against devnet" | **sdk-tester** |
| File verification (`.ts` with SDK imports) | `/verify app.ts` | **type-checker** (types) + **sdk-tester** (behavior, if devnet) |
| Cross-domain (types + behavior) | "calling increment changes the counter from 0 to 1" | **type-checker + sdk-tester** (concurrent) |

**When in doubt:** Types/signatures/imports → **type-checker**. Runtime behavior → **sdk-tester**. Internal implementation → **source-investigator**. Package versions → **deps-maintenance**.

**Hints from existing skills:**

The verifier may consult these for context, never as evidence:
- `dapp-development:midnight-sdk` — provider setup, component overview
- `dapp-development:dapp-connector` — wallet integration patterns
- `compact-core:compact-witness-ts` — witness implementation patterns
- `compact-core:compact-deployment` — deployment patterns

### 2. verify-by-type-check (Type-Check Skill)

The type-checker agent's brain. Uses `tsc --noEmit` as the oracle.

**Workspace:**

- Location: `.midnight-expert/verify/sdk-workspace/` relative to project root
- Lazy initialization: only created/checked first time a verification job needs it
- Contains: `package.json` with all `@midnight-ntwrk/midnight-js-*` packages, `tsconfig.json` with strict mode + `noEmit: true`
- Per-job temp dirs: `jobs/<uuid>/`
- Cleanup after each job

**Installed packages (all SDK packages):**

- `@midnight-ntwrk/midnight-js-contracts`
- `@midnight-ntwrk/midnight-js-types`
- `@midnight-ntwrk/midnight-js-utils`
- `@midnight-ntwrk/midnight-js-network-id`
- `@midnight-ntwrk/midnight-js-level-private-state-provider`
- `@midnight-ntwrk/midnight-js-indexer-public-data-provider`
- `@midnight-ntwrk/midnight-js-http-client-proof-provider`
- `@midnight-ntwrk/midnight-js-fetch-zk-config-provider`
- `@midnight-ntwrk/midnight-js-node-zk-config-provider`
- `@midnight-ntwrk/midnight-js-logger-provider`
- `@midnight-ntwrk/midnight-js-dapp-connector-proof-provider`
- `@midnight-ntwrk/midnight-js-compact`
- `@midnight-ntwrk/midnight-js` (barrel)
- `@midnight-ntwrk/testkit-js` (for devnet tests)
- `typescript` (for `tsc`)

**Mode 1 — Claim mode:**

Verifying a claim about the SDK API:

1. Parse the claim to identify what's being asserted (function exists, return type, interface shape, etc.)
2. Write a `.ts` test file with type-level assertions that exercise the claim
3. Run `tsc --noEmit` on the file
4. If it compiles: types match → evidence toward Confirmed
5. If it fails: type error → evidence toward Refuted
6. Report compiler output either way

Type assertion patterns the agent should use:

```typescript
// Verify export exists
import { deployContract } from '@midnight-ntwrk/midnight-js-contracts';

// Verify return type
type Result = Awaited<ReturnType<typeof deployContract>>;
type Check = Result extends DeployedContract ? true : never;
const _: Check = true;

// Verify interface shape
const _test: MidnightProviders<any, any, any> = {} as any;
_test.walletProvider; // Property must exist

// Verify class hierarchy
const err = new CallTxFailedError('test');
const _isBase: TxFailedError = err; // Must be assignable
```

**Mode 2 — File mode:**

Verifying a user's `.ts` file:

1. Copy the file into the job directory
2. If the file imports from local paths (e.g., `./contract/index.js` — compiled Compact output), handle missing imports:
   - If compiled contract output is available in the project, copy it
   - Otherwise, create minimal type stubs so tsc can proceed, and note which imports were stubbed
3. Run `tsc --noEmit`
4. Report all type errors with line numbers, or confirm clean compilation

**What tsc proves vs doesn't prove:**

The skill must be explicit:
- **Proves:** types exist, signatures match, imports resolve, interfaces are satisfied, generics are correct, error hierarchies hold
- **Does NOT prove:** runtime behavior, actual values returned, side effects, network communication, correct business logic

A clean `tsc` run for a behavioral claim should note: "Types verified, but runtime behavior requires devnet verification."

### 3. verify-by-devnet (Devnet Skill)

The sdk-tester agent's brain. Runs E2E scripts against a local devnet.

**Prerequisite check:**

Before any E2E verification, check devnet health:
- Node health endpoint
- Indexer health endpoint
- Proof server health endpoint

Reference `midnight-tooling:devnet` skill for endpoint URLs and health check patterns.

If any service is unreachable → **Inconclusive** with message: "Devnet not available. Start it with `midnight-tooling:devnet` and retry. Only the type-checking portion of this claim could be verified." No guessing, no partial execution.

**Approach A: Raw SDK scripts (`.mjs`)**

Write a self-contained script using SDK packages directly. Best for:
- Testing specific SDK function behavior in isolation
- Verifying a particular API call's return value or side effects
- Claims about a single SDK feature
- Claims that are ABOUT SDK behavior (not testkit behavior)

Pros: No extra dependencies beyond the SDK itself. Transparent — mirrors what a DApp developer would write. Easy to debug.
Cons: More boilerplate (provider setup, wallet initialization, waiting for sync).

Example — verifying "deployContract returns a contract address":
```javascript
import { deployContract } from '@midnight-ntwrk/midnight-js-contracts';
import { setNetworkId } from '@midnight-ntwrk/midnight-js-network-id';
// ... set up providers, compile contract, deploy, check contractAddress
```

**Approach B: testkit-js**

Use `@midnight-ntwrk/testkit-js` for TestEnvironment and wallet management. Best for:
- Multi-step lifecycle tests (deploy → call → observe → reconnect)
- Claims involving multiple users or contract interactions
- Claims about state observation patterns (observables, subscriptions)
- Complex provider wiring scenarios

Pros: Handles provider wiring, wallet management, health checks automatically. Less boilerplate for complex scenarios.
Cons: Additional abstraction layer. Don't use when the claim is about SDK primitives that testkit wraps.

**Decision guidance:**

| Scenario | Approach |
|---|---|
| "Does function X return Y?" | Raw SDK script |
| "Does deploy work?" | Raw SDK script |
| "Full lifecycle (deploy → call → observe → reconnect)" | testkit-js |
| "Multi-user interaction" | testkit-js |
| "State observation / subscriptions" | testkit-js |
| "Claim is ABOUT testkit behavior" | Raw SDK script |
| "Claim is about provider wiring" | Raw SDK script |

**Workspace:**

Uses the same `.midnight-expert/verify/sdk-workspace/` as the type-checker. The workspace already has all SDK packages and testkit-js installed.

For tests that need a compiled Compact contract:
1. Check if a pre-compiled test contract exists in the workspace (e.g., a simple counter)
2. If not, write a minimal `.compact` file and compile with `compact compile --skip-zk` (reference `midnight-tooling:compact-cli`)
3. Include a small set of stock test contracts in the workspace for common verification scenarios (counter with increment, basic deploy target)

**Report format:**

Same structure as other methods: claim, what was done, script source, output, interpretation.

## Agents

### type-checker (new)

- **Model:** sonnet
- **Color:** yellow
- **Loads:** `midnight-verify:verify-by-type-check`
- **Purpose:** Write TypeScript test files and run `tsc --noEmit` to verify SDK type claims and user code correctness
- **System prompt essence:** "You are a TypeScript type-checking specialist. Load the type-check skill and follow it. Write precise type assertions, run tsc, interpret the compiler output."

### sdk-tester (new)

- **Model:** sonnet
- **Color:** magenta
- **Loads:** `midnight-verify:verify-by-devnet`
- **Purpose:** Write and run E2E scripts against a local devnet to verify SDK behavioral claims
- **System prompt essence:** "You are an SDK integration tester. Load the devnet skill and follow it. Check devnet health first. Choose between raw SDK scripts and testkit-js based on the claim. Report what you observed."

### verifier (updated)

- **Skills:** add `midnight-verify:verify-sdk` to frontmatter
- **Description:** update to mention SDK verification, type-checking, and devnet testing
- **Dispatch section:** add type-checker, sdk-tester, deps-maintenance to known agents

### source-investigator (unchanged agent, updated skill)

The agent itself stays the same. The `verify-by-source` skill gets midnight-js added to its repo routing table.

## Updates to Existing Skills

### verify-correctness (Hub)

Add to Section 3 (Dispatch Sub-Agents):

- **Type-checking needed** → dispatch `midnight-verify:type-checker` agent with the claim and what type assertion to make
- **Devnet E2E needed** → dispatch `midnight-verify:sdk-tester` agent with the claim and what behavior to observe
- **Package/version check needed** → dispatch `devs:deps-maintenance` agent with the package name and version claim. If deps-maintenance is not available (plugin not installed), the verifier should run `npm view` directly as a fallback.
- When multiple methods are needed for an SDK claim, dispatch concurrently where independent (e.g., type-checker + sdk-tester can run in parallel)

### verify-by-source

Add to repository routing table:

| Claim About | Primary Repo | Key Paths / Notes |
|---|---|---|
| SDK API, TypeScript packages, provider implementations | `midnightntwrk/midnight-js` | `packages/*/src/` — monorepo, 13 packages. `llms.txt` in repo root has a 10KB API overview. |

## Verdict Extensions

New qualifiers added to the existing verdict system:

| Verdict | Qualifier | Meaning |
|---|---|---|
| Confirmed | (type-checked) | `tsc --noEmit` compiled clean, types match claim |
| Confirmed | (tested) | E2E script ran against devnet, behavior matches |
| Confirmed | (type-checked + tested) | Both methods agree |
| Confirmed | (package-verified) | `npm view` / deps-maintenance confirms |
| Refuted | (type-checked) | `tsc` produced errors contradicting claim |
| Refuted | (tested) | E2E ran, behavior contradicts claim |
| Refuted | (package-verified) | Package/version doesn't match |
| Inconclusive | (devnet unavailable) | Needs E2E but devnet not running |
| Inconclusive | (type-check insufficient) | Types match but claim is about runtime behavior |

**Critical rule:** A clean `tsc` run does NOT confirm behavioral claims. If the claim is about what happens at runtime, type-checking can confirm the type/signature part but must note that runtime verification requires devnet. The orchestrator should attempt to dispatch sdk-tester concurrently when a claim has both type and behavioral components.

## Future Work (Not In Scope)

- **OpenZeppelin Simulator** — local contract execution without devnet, bridges Compact and SDK testing
- **DApp Connector verification** — wallet-to-DApp integration patterns
- **Cross-version testing** — verify claims against multiple SDK versions simultaneously
- **Proof server oracle** — verify ZK proof generation and constraint enforcement
