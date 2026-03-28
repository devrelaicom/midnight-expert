# Verify SDK Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the verify-sdk placeholder with full SDK/TypeScript verification — type-checking via `tsc --noEmit`, E2E testing against local devnet, and updates to the hub and existing components.

**Architecture:** Three new skills (verify-sdk, verify-by-type-check, verify-by-devnet) provide verification logic. Two new agents (type-checker, sdk-tester) are thin wrappers. The hub, source skill, and verifier agent are updated to dispatch the new agents. SDK workspace at `.midnight-expert/verify/sdk-workspace/` with lazy init.

**Tech Stack:** Claude Code plugin system (skills, agents), TypeScript (`tsc --noEmit`), `@midnight-ntwrk/midnight-js-*` packages, `@midnight-ntwrk/testkit-js`, octocode-mcp

**Spec:** `docs/superpowers/specs/2026-03-28-verify-sdk-design.md`

---

## File Map

```
plugins/midnight-verify/
├── .claude-plugin/
│   └── plugin.json                         # Version bump to 0.3.0
├── skills/
│   ├── verify-sdk/SKILL.md                 # REPLACE: SDK claim classification + routing
│   ├── verify-by-type-check/SKILL.md       # NEW: tsc --noEmit verification method
│   ├── verify-by-devnet/SKILL.md           # NEW: E2E devnet verification method
│   ├── verify-correctness/SKILL.md         # MODIFY: add new agents to dispatch + new verdicts
│   └── verify-by-source/SKILL.md           # MODIFY: add midnight-js to repo routing
├── agents/
│   ├── type-checker.md                     # NEW: TypeScript type-checking agent
│   ├── sdk-tester.md                       # NEW: SDK E2E testing agent
│   └── verifier.md                         # MODIFY: add verify-sdk skill + new agents
```

---

### Task 1: Write the verify-by-type-check skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-type-check/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-type-check
```

- [ ] **Step 2: Write SKILL.md**

Write `plugins/midnight-verify/skills/verify-by-type-check/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-by-type-check
description: >-
  Verification by TypeScript compilation. Writes TypeScript test files that
  exercise SDK type claims, then runs tsc --noEmit to check if types match.
  Also verifies user .ts files that import @midnight-ntwrk packages. Loaded
  by the type-checker agent. Covers workspace setup (lazy init), two modes
  (claim mode and file mode), type assertion patterns, and result
  interpretation.
version: 0.3.0
---

# Verify by Type-Checking

You are verifying an SDK claim or user TypeScript file by running the TypeScript compiler. Follow these steps in order.

## Critical Rule

**A clean tsc run proves types are correct. It does NOT prove runtime behavior.** If the claim is about what happens when you call a function (not just its signature), note: "Types verified, but runtime behavior requires devnet verification."

## Step 1: Set Up the Workspace

The workspace lives at `.midnight-expert/verify/sdk-workspace/` relative to the project root (same level as `.claude/`). Determine the project root from your working directory or `$CLAUDE_PROJECT_DIR`.

**First time (workspace does not exist):**

```bash
mkdir -p .midnight-expert/verify/sdk-workspace
cd .midnight-expert/verify/sdk-workspace

# Initialize Node project
npm init -y

# Install all SDK packages + TypeScript
npm install \
  @midnight-ntwrk/midnight-js \
  @midnight-ntwrk/midnight-js-contracts \
  @midnight-ntwrk/midnight-js-types \
  @midnight-ntwrk/midnight-js-utils \
  @midnight-ntwrk/midnight-js-network-id \
  @midnight-ntwrk/midnight-js-level-private-state-provider \
  @midnight-ntwrk/midnight-js-indexer-public-data-provider \
  @midnight-ntwrk/midnight-js-http-client-proof-provider \
  @midnight-ntwrk/midnight-js-fetch-zk-config-provider \
  @midnight-ntwrk/midnight-js-node-zk-config-provider \
  @midnight-ntwrk/midnight-js-logger-provider \
  @midnight-ntwrk/midnight-js-dapp-connector-proof-provider \
  @midnight-ntwrk/midnight-js-compact \
  @midnight-ntwrk/testkit-js \
  typescript

# Create tsconfig.json for type-checking
cat > tsconfig.json << 'TSCONFIG_EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "Node16",
    "moduleResolution": "Node16",
    "strict": true,
    "noEmit": true,
    "skipLibCheck": false,
    "esModuleInterop": true,
    "resolveJsonModule": true
  },
  "include": ["jobs/**/*.ts"]
}
TSCONFIG_EOF
```

**Subsequent times (workspace exists):**

Run a quick integrity check:

```bash
cd .midnight-expert/verify/sdk-workspace
npm ls typescript
```

If `npm ls` reports errors, run `npm install` to repair.

**Create the job directory:**

```bash
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID
```

## Step 2: Determine the Mode

**Claim mode** — you received a natural language claim about the SDK (e.g., "deployContract returns DeployedContract"). Go to Step 3A.

**File mode** — you received a `.ts` file to verify (e.g., `/verify src/deploy.ts`). Go to Step 3B.

## Step 3A: Claim Mode — Write Type Assertions

Parse the claim and write a `.ts` file that exercises it using type-level assertions. The file should compile if and only if the claim is true.

**Common assertion patterns:**

```typescript
// 1. Verify an export exists
import { deployContract } from '@midnight-ntwrk/midnight-js-contracts';

// 2. Verify a function's return type
import type { DeployedContract } from '@midnight-ntwrk/midnight-js-contracts';
type Result = Awaited<ReturnType<typeof deployContract>>;
type _Check = Result extends DeployedContract ? true : never;
const _proof: _Check = true;

// 3. Verify an interface has a specific property
import type { MidnightProviders } from '@midnight-ntwrk/midnight-js-types';
type _HasWallet = MidnightProviders<any, any, any>['walletProvider'];

// 4. Verify a class extends another
import { CallTxFailedError, TxFailedError } from '@midnight-ntwrk/midnight-js-contracts';
const _err = new CallTxFailedError('test', []);
const _base: TxFailedError = _err; // assignability check

// 5. Verify a type is exported from a specific package
import type { ProverKey } from '@midnight-ntwrk/midnight-js-types';
const _pk: ProverKey = new Uint8Array() as ProverKey;

// 6. Verify a function's parameter types
import { toHex } from '@midnight-ntwrk/midnight-js-utils';
const _result: string = toHex(new Uint8Array([0xAB]));

// 7. Verify an import path works
import { setNetworkId } from '@midnight-ntwrk/midnight-js-network-id';
```

Write the file to the job directory:

```bash
cat > .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID/test-claim.ts << 'TS_EOF'
<type assertion code>
TS_EOF
```

## Step 3B: File Mode — Copy and Check User File

1. Copy the user's `.ts` file into the job directory
2. Check if the file imports from local paths (e.g., `./contract/index.js`, `../compiled/counter`):
   - If the compiled Compact output exists in the user's project, copy it to the job directory maintaining the relative path structure
   - If it doesn't exist, create a minimal `.d.ts` stub so tsc can proceed:
     ```typescript
     // stub for missing compiled contract
     declare const _default: any;
     export default _default;
     export declare const pureCircuits: any;
     export declare const ledger: any;
     export declare const Witnesses: any;
     export declare const Contract: any;
     ```
   - Note in your report which imports were stubbed — these are unverified
3. Ensure the job's tsconfig includes the file

## Step 4: Run tsc

```bash
cd .midnight-expert/verify/sdk-workspace
npx tsc --noEmit --project tsconfig.json 2>&1
```

Or to check a specific file:

```bash
npx tsc --noEmit jobs/$JOB_ID/test-claim.ts 2>&1
```

**Capture the full output (stdout and stderr).**

## Step 5: Interpret and Report

**If tsc exits 0 (no errors):**
- Claim mode: the type assertions compiled → types match the claim
- File mode: the user's file type-checks clean with the SDK

**If tsc exits non-zero:**
- Claim mode: the type assertion failed → types contradict the claim. The compiler error IS your evidence.
- File mode: the user's file has type errors. Report each error with file, line, and message.

**Report format:**

```
### Type-Check Report

**Claim:** [verbatim]

**Test file:**
\`\`\`typescript
[full source of the test .ts file]
\`\`\`

**tsc output:**
\`\`\`
[compiler output — clean or errors]
\`\`\`

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]

**Note:** [if behavioral claim: "Types verified, but runtime behavior requires devnet verification."]
[if file mode with stubs: "Imports from ./path/to/contract were stubbed — types for these imports are unverified."]
```

## Step 6: Clean Up

```bash
rm -rf .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID
```
```

- [ ] **Step 3: Verify the file**

```bash
head -10 plugins/midnight-verify/skills/verify-by-type-check/SKILL.md
```

Expected: YAML frontmatter with `name: midnight-verify:verify-by-type-check`

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-type-check/SKILL.md
git commit -m "feat(verify): add verify-by-type-check skill

TypeScript compilation verification method: writes type assertion files
or copies user .ts files, runs tsc --noEmit, interprets compiler output.
SDK workspace with lazy init and all @midnight-ntwrk packages.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 2: Write the verify-by-devnet skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-devnet/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-devnet
```

- [ ] **Step 2: Write SKILL.md**

Write `plugins/midnight-verify/skills/verify-by-devnet/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-by-devnet
description: >-
  Verification by running E2E scripts against a local Midnight devnet.
  Writes SDK test scripts (raw or using testkit-js) that exercise the
  full transaction pipeline: deploy, call circuits, observe state. Checks
  devnet health before proceeding. Loaded by the sdk-tester agent.
  References midnight-tooling:devnet for infrastructure management.
version: 0.3.0
---

# Verify by Devnet Execution

You are verifying an SDK behavioral claim by running a test script against a live local devnet. Follow these steps in order.

## Critical Rule

**Do NOT attempt E2E testing without first confirming devnet is healthy.** If devnet is unreachable, report Inconclusive immediately. Do not guess at behavior.

## Step 1: Check Devnet Health

Load `midnight-tooling:devnet` skill for endpoint URLs and health check patterns. Check that all three services are reachable:

1. **Node** — health endpoint
2. **Indexer** — health endpoint
3. **Proof server** — health endpoint

If ANY service is unreachable:
- Report **Inconclusive (devnet unavailable)**
- Message: "Devnet not available. Start it with `midnight-tooling:devnet` and retry."
- Stop. Do not proceed to Step 2.

## Step 2: Set Up the Workspace

Uses the same workspace as the type-checker: `.midnight-expert/verify/sdk-workspace/`.

If it doesn't exist, follow the same initialization as `verify-by-type-check` (create workspace, install packages, create tsconfig).

Create a job directory:

```bash
JOB_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
mkdir -p .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID
```

## Step 3: Choose Your Approach

You have two approaches. Choose based on the claim:

### Approach A: Raw SDK Script

Write a self-contained `.mjs` script that imports SDK packages directly. Best for:
- Testing a specific SDK function's behavior in isolation
- Verifying a particular API call's return value or side effects
- Claims about a single SDK feature
- Claims that are ABOUT SDK behavior (not testkit behavior)
- Claims about provider wiring

**Pros:** No extra dependencies. Transparent — mirrors what a DApp developer would write. Easy to debug.

**Cons:** More boilerplate (provider setup, wallet init, waiting for sync).

**Example structure for a raw SDK script:**

```javascript
import { deployContract } from '@midnight-ntwrk/midnight-js-contracts';
import { setNetworkId } from '@midnight-ntwrk/midnight-js-network-id';
import { httpClientProofProvider } from '@midnight-ntwrk/midnight-js-http-client-proof-provider';
import { indexerPublicDataProvider } from '@midnight-ntwrk/midnight-js-indexer-public-data-provider';
import { NodeZkConfigProvider } from '@midnight-ntwrk/midnight-js-node-zk-config-provider';
import { levelPrivateStateProvider } from '@midnight-ntwrk/midnight-js-level-private-state-provider';

// 1. Configure network
setNetworkId('devnet');

// 2. Set up providers (reference midnight-tooling:devnet for URLs)
const providers = {
  privateStateProvider: levelPrivateStateProvider({ ... }),
  publicDataProvider: indexerPublicDataProvider({ ... }),
  zkConfigProvider: new NodeZkConfigProvider({ ... }),
  proofProvider: httpClientProofProvider({ ... }),
  walletProvider: ...,   // from wallet SDK
  midnightProvider: ..., // from wallet SDK
};

// 3. Execute the claim
// ... deploy, call, observe ...

// 4. Output structured result
console.log(JSON.stringify({ result: ... }));
```

### Approach B: testkit-js

Use `@midnight-ntwrk/testkit-js` for TestEnvironment and wallet management. Best for:
- Multi-step lifecycle tests (deploy → call → observe → reconnect)
- Claims involving multiple users or contract interactions
- Claims about state observation patterns (observables, subscriptions)
- Complex provider wiring scenarios

**Pros:** Handles provider wiring, wallet management, health checks automatically. Less boilerplate for complex scenarios.

**Cons:** Additional abstraction layer. Don't use when the claim is about SDK primitives that testkit wraps.

**Example structure for a testkit-js script:**

```javascript
// Testkit handles environment setup, wallet init, provider wiring
import { createTestEnvironment } from '@midnight-ntwrk/testkit-js';

const env = await createTestEnvironment('undeployed');
// ... use env to deploy contracts, call circuits, observe state
```

### Decision Guide

| Scenario | Use |
|---|---|
| "Does function X return Y?" | Raw SDK script |
| "Does deploy work?" | Raw SDK script |
| "Full lifecycle (deploy → call → observe → reconnect)" | testkit-js |
| "Multi-user interaction" | testkit-js |
| "State observation / subscriptions" | testkit-js |
| "Claim is ABOUT testkit behavior" | Raw SDK script |
| "Claim is about provider wiring" | Raw SDK script |

## Step 4: Handle Compact Contract Dependencies

Most E2E tests need a compiled Compact contract. Options:

1. **Check for pre-compiled test contracts** in the workspace (e.g., a counter contract)
2. **Write and compile a minimal contract** using `compact compile --skip-zk` — load `midnight-tooling:compact-cli` for compilation details
3. **Use a stock counter contract** — this is the simplest possible Midnight contract:

```compact
import CompactStandardLibrary;

export ledger round: Counter;

export circuit increment(): [] {
  round.increment(1);
}
```

Compile it and place the output in the job directory.

## Step 5: Write and Run the Script

Write the chosen script to the job directory:

```bash
cat > .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID/test-claim.mjs << 'SCRIPT_EOF'
<script content>
SCRIPT_EOF
```

Run it:

```bash
cd .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID
node test-claim.mjs
```

**Capture stdout and stderr.** The script should output structured JSON for programmatic interpretation.

**If the script throws:** Capture the error. Determine if it's a claim issue (the SDK genuinely doesn't behave as claimed) or a test issue (your script has a bug). If it's a test issue, fix and retry once.

## Step 6: Interpret and Report

**Report format:**

```
### Devnet Execution Report

**Claim:** [verbatim]

**Approach:** [Raw SDK script / testkit-js]

**Test script:**
\`\`\`javascript
[full source]
\`\`\`

**Output:**
\`\`\`
[stdout/stderr]
\`\`\`

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation]
```

## Step 7: Clean Up

```bash
rm -rf .midnight-expert/verify/sdk-workspace/jobs/$JOB_ID
```
```

- [ ] **Step 3: Verify the file**

```bash
head -10 plugins/midnight-verify/skills/verify-by-devnet/SKILL.md
```

Expected: YAML frontmatter with `name: midnight-verify:verify-by-devnet`

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-devnet/SKILL.md
git commit -m "feat(verify): add verify-by-devnet skill

E2E devnet verification method: checks devnet health first, then runs
raw SDK scripts or testkit-js tests against local infrastructure.
Includes decision guide for choosing between approaches.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 3: Write the verify-sdk skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-sdk/SKILL.md`

- [ ] **Step 1: Replace SKILL.md**

Write `plugins/midnight-verify/skills/verify-sdk/SKILL.md` with this content:

```markdown
---
name: midnight-verify:verify-sdk
description: >-
  SDK/TypeScript claim classification and method routing. Determines what
  kind of SDK claim is being verified and which verification method applies:
  type-checking (tsc --noEmit), devnet E2E testing, source inspection, or
  package checks. Handles both claims about the SDK API itself and
  verification of user code that uses the SDK. Loaded by the verifier
  agent alongside the hub skill.
version: 0.3.0
---

# SDK Claim Classification

This skill classifies SDK/TypeScript claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Claim Type → Method Routing

When you receive an SDK-related claim, classify it using this table to determine which agent(s) to dispatch:

### Claims About the SDK API

| Claim Type | Example | Dispatch |
|---|---|---|
| API function exists | "deployContract is exported from contracts" | **type-checker** |
| Function signature / return type | "deployContract returns DeployedContract" | **type-checker** |
| Type/interface shape | "MidnightProviders has a walletProvider field" | **type-checker** |
| Import path correctness | "import { deployContract } from '@midnight-ntwrk/midnight-js-contracts'" | **type-checker** |
| Error class hierarchy | "CallTxFailedError extends TxFailedError" | **type-checker** |
| Package exists / version | "@midnight-ntwrk/midnight-js-contracts is at version 4.0.2" | **deps-maintenance** (fallback: verifier runs `npm view` directly) |
| Export count / package structure | "contracts package exports 91 symbols" | **source-investigator** |
| Implementation details | "httpClientProofProvider retries 3 times with exponential backoff" | **source-investigator** |
| Provider internal behavior | "LevelDB provider encrypts with AES-256-GCM" | **source-investigator** |
| Deploy/call lifecycle behavior | "deployContract deploys and returns a contract address" | **sdk-tester** |
| Transaction pipeline behavior | "submitCallTx proves, balances, submits, and waits" | **sdk-tester** |
| State query behavior | "getPublicStates returns on-chain ledger state" | **sdk-tester** |

### Claims About User Code That Uses the SDK

| Claim Type | Example | Dispatch |
|---|---|---|
| DApp code type-correctness | "This provider setup code is valid" | **type-checker** |
| Witness implementation | "This witness correctly implements the contract interface" | **type-checker** (+ **contract-writer** for the Compact side) |
| Provider configuration | "This provider config connects to devnet correctly" | **type-checker** + **sdk-tester** |
| Import usage patterns | "This file's SDK imports are correct" | **type-checker** |
| Transaction handling code | "This error handling catches CallTxFailedError" | **type-checker** |
| E2E integration | "This deploy+call flow works against devnet" | **sdk-tester** |
| File verification (`.ts` with SDK imports) | `/verify app.ts` | **type-checker** (types) + **sdk-tester** (behavior, if devnet available) |
| Cross-domain (types + behavior) | "calling increment changes counter from 0 to 1" | **type-checker + sdk-tester** (concurrent) |

### Routing Rules

**When in doubt:**
- Types, signatures, imports, interfaces → **type-checker**
- Runtime behavior, what happens when you call something → **sdk-tester**
- Internal implementation, how something works under the hood → **source-investigator**
- Package versions, existence → **deps-maintenance** (or `npm view` fallback)

**When multiple methods apply, dispatch concurrently.** Type-checking and devnet testing are independent and can run in parallel.

## Hints from Existing Skills

The verifier or sub-agents may consult these skills for context. They are **hints only** — never cite them as evidence in the verdict.

- `dapp-development:midnight-sdk` — provider setup, component overview
- `dapp-development:dapp-connector` — wallet integration patterns
- `compact-core:compact-witness-ts` — witness implementation patterns
- `compact-core:compact-deployment` — deployment patterns

Load only what's relevant to the specific claim.
```

- [ ] **Step 2: Verify the file**

```bash
head -10 plugins/midnight-verify/skills/verify-sdk/SKILL.md
```

Expected: frontmatter with `version: 0.3.0`

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/skills/verify-sdk/SKILL.md
git commit -m "feat(verify): replace verify-sdk placeholder with full claim classification

SDK claim routing table covering API claims (types, signatures, packages,
behavior) and user code claims (DApp code, witnesses, provider config).
Routes to type-checker, sdk-tester, source-investigator, or deps-maintenance.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 4: Write the type-checker agent

**Files:**
- Create: `plugins/midnight-verify/agents/type-checker.md`

- [ ] **Step 1: Write type-checker.md**

Write `plugins/midnight-verify/agents/type-checker.md` with this content:

```markdown
---
name: type-checker
description: >-
  Use this agent to verify SDK type claims or check user TypeScript files
  by running tsc --noEmit. Writes type assertion files for claims about
  the SDK API, or copies user .ts files into the SDK workspace. Dispatched
  by the verifier orchestrator agent.

  Example 1: Claim "deployContract returns DeployedContract" — writes a .ts
  file with type-level assertions, runs tsc, confirms the return type matches.

  Example 2: Claim "CallTxFailedError extends TxFailedError" — writes an
  assignability check, runs tsc, confirms the inheritance hierarchy.

  Example 3: User file verification — copies src/deploy.ts to the workspace,
  runs tsc, reports any type errors with line numbers.

  Example 4: Claim "import { setNetworkId } from '@midnight-ntwrk/midnight-js-network-id'"
  works — writes a file with that import, runs tsc, confirms it resolves.
skills: midnight-verify:verify-by-type-check
model: sonnet
color: yellow
---

You are a TypeScript type-checking specialist for the Midnight SDK.

Load the `midnight-verify:verify-by-type-check` skill and follow it step by step. It tells you exactly how to:

1. Set up the SDK workspace (lazy — only if it doesn't exist)
2. Determine the mode (claim vs file)
3. Write type assertion files (claim mode) or copy user files (file mode)
4. Run `tsc --noEmit`
5. Interpret the compiler output
6. Report your findings
7. Clean up

Follow the skill precisely. Write precise type assertions that test exactly what the claim states — no more, no less.

**Remember:** A clean tsc run proves types are correct. It does NOT prove runtime behavior. If the claim is about what happens at runtime, note this explicitly in your report.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/agents/type-checker.md
git commit -m "feat(verify): add type-checker agent

Thin wrapper over verify-by-type-check skill. Sonnet model, writes
TypeScript type assertions and runs tsc --noEmit for SDK verification.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 5: Write the sdk-tester agent

**Files:**
- Create: `plugins/midnight-verify/agents/sdk-tester.md`

- [ ] **Step 1: Write sdk-tester.md**

Write `plugins/midnight-verify/agents/sdk-tester.md` with this content:

```markdown
---
name: sdk-tester
description: >-
  Use this agent to verify SDK behavioral claims by running E2E scripts
  against a local Midnight devnet. Checks devnet health first, then writes
  raw SDK scripts or testkit-js tests to exercise the full transaction
  pipeline. Dispatched by the verifier orchestrator agent.

  Example 1: Claim "deployContract deploys and returns a contract address" —
  writes a raw SDK script that deploys a counter contract, checks the result
  has a contractAddress field with a valid hex string.

  Example 2: Claim "full deploy+call+observe lifecycle works" — uses testkit-js
  to set up environment, deploy, call increment, read state, verify counter
  changed.

  Example 3: Claim "findDeployedContract reconnects to an existing contract" —
  uses testkit-js for the multi-step flow: deploy, disconnect, reconnect via
  address, verify state is accessible.
skills: midnight-verify:verify-by-devnet
model: sonnet
color: magenta
---

You are an SDK integration tester for the Midnight network.

Load the `midnight-verify:verify-by-devnet` skill and follow it step by step. It tells you exactly how to:

1. Check devnet health (MUST pass before proceeding — Inconclusive if not)
2. Set up the SDK workspace
3. Choose between raw SDK scripts and testkit-js (the skill has a decision guide)
4. Handle Compact contract dependencies (compile test contracts if needed)
5. Write and run the test script
6. Interpret the output
7. Report your findings
8. Clean up

Follow the skill precisely. Always check devnet health first. Choose the right approach for the claim. If devnet is unavailable, report Inconclusive immediately — do not guess.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/agents/sdk-tester.md
git commit -m "feat(verify): add sdk-tester agent

Thin wrapper over verify-by-devnet skill. Sonnet model, runs E2E scripts
against local devnet for SDK behavioral verification.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 6: Update verify-by-source skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-by-source/SKILL.md`

- [ ] **Step 1: Add midnight-js to the repository routing table**

In `plugins/midnight-verify/skills/verify-by-source/SKILL.md`, find the repository routing table (the markdown table after "Repository routing — match the claim to the right repo:") and add this row after the last existing row (Compact CLI releases):

```markdown
| SDK API, TypeScript packages, provider implementations | `midnightntwrk/midnight-js` | `packages/*/src/` — monorepo with 13 packages. `llms.txt` in repo root is a 10KB API overview useful as a starting point. |
```

- [ ] **Step 2: Update the "When This Method Is Used" section**

Add SDK-related examples to the bullet list:

```markdown
- SDK export counts ("midnight-js-contracts exports 91 symbols")
- SDK implementation details ("proof provider retries 3 times with backoff")
- SDK provider internals ("LevelDB provider uses AES-256-GCM encryption")
```

- [ ] **Step 3: Bump version to 0.3.0**

Change `version: 0.2.0` to `version: 0.3.0` in the frontmatter.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-source/SKILL.md
git commit -m "feat(verify): add midnight-js repo to source skill routing

Source-investigator can now search midnightntwrk/midnight-js for SDK
implementation details, export counts, and provider internals.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 7: Update verify-correctness hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Update Section 3 (Dispatch Sub-Agents)**

Replace the current Section 3 content in `plugins/midnight-verify/skills/verify-correctness/SKILL.md`:

Find:
```markdown
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
```

Replace with:
```markdown
### 3. Dispatch Sub-Agents

Based on the domain skill's routing:

- **Compact execution needed** → dispatch `midnight-verify:contract-writer` agent with the claim
- **Source inspection needed** → dispatch `midnight-verify:source-investigator` agent with the claim
- **Type-checking needed** → dispatch `midnight-verify:type-checker` agent with the claim and what type assertion to make
- **Devnet E2E needed** → dispatch `midnight-verify:sdk-tester` agent with the claim and what behavior to observe
- **Package/version check needed** → dispatch `devs:deps-maintenance` agent with the package name and version claim. If deps-maintenance is not available (plugin not installed), run `npm view` directly as a fallback.
- **Multiple methods needed** → dispatch applicable agents **concurrently** (they are independent and can run in parallel)

When dispatching, pass:
- The claim verbatim
- Any relevant context (file path, code snippet, what specifically to check)
- For the contract-writer: what observable behavior would confirm/refute the claim
- For the source-investigator: which repo/area to focus on (from the domain skill's routing)
- For the type-checker: what type assertion to write, or the file path to check
- For the sdk-tester: what runtime behavior to observe
```

- [ ] **Step 2: Add new verdict qualifiers to Section 4**

In the verdict options table, add these rows after the existing ones:

```markdown
| **Confirmed** | (type-checked) | Type-checker ran tsc --noEmit; types match the claim |
| **Confirmed** | (type-checked + tested) | Both tsc and devnet E2E agree |
| **Confirmed** | (package-verified) | npm view / deps-maintenance confirms package/version |
| **Refuted** | (type-checked) | tsc produced type errors contradicting the claim |
| **Refuted** | (package-verified) | Package doesn't exist or version doesn't match |
| **Inconclusive** | (devnet unavailable) | Claim needs E2E testing but devnet is not running |
| **Inconclusive** | (type-check insufficient) | Types match but claim is about runtime behavior — can't verify without devnet |
```

- [ ] **Step 3: Add critical rule about tsc and behavioral claims**

After the verdict table, add:

```markdown
**Critical rule for SDK claims:** A clean `tsc` run does NOT confirm behavioral claims. If the claim is about what happens at runtime (deploy, call, state changes), type-checking can confirm the type/signature part but must note that runtime verification requires devnet. When a claim has both type and behavioral components, dispatch type-checker and sdk-tester concurrently.
```

- [ ] **Step 4: Update the "What This Skill Does NOT Do" section**

Replace:
```markdown
- It does not contain method-specific instructions — those live in `verify-by-execution` and `verify-by-source`
```

With:
```markdown
- It does not contain method-specific instructions — those live in `verify-by-execution`, `verify-by-source`, `verify-by-type-check`, and `verify-by-devnet`
```

- [ ] **Step 5: Bump version to 0.3.0**

Change `version: 0.2.0` to `version: 0.3.0` in the frontmatter.

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(verify): update hub skill with SDK verification agents and verdicts

Hub now dispatches type-checker, sdk-tester, and deps-maintenance agents.
New verdict qualifiers for type-checked, package-verified, and devnet
unavailable. Critical rule: tsc doesn't confirm behavioral claims.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 8: Update verifier agent

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`

- [ ] **Step 1: Replace verifier.md**

Write `plugins/midnight-verify/agents/verifier.md` with this content:

```markdown
---
name: verifier
description: >-
  Use this agent to verify Midnight-related claims, Compact code correctness,
  SDK API usage, or TypeScript DApp code. This is the orchestrator — it
  classifies claims, determines the verification strategy, dispatches
  sub-agents, and synthesizes the final verdict.

  Dispatched by the /verify command or other skills/commands that need
  verification.

  Example 1: User runs /verify "Tuples in Compact are 0-indexed" — the
  orchestrator classifies this as a Compact behavioral claim, dispatches
  the contract-writer agent to compile and run a test, and reports the verdict.

  Example 2: User runs /verify "deployContract returns DeployedContract" — the
  orchestrator classifies this as an SDK type claim, dispatches the
  type-checker agent to run tsc --noEmit, and reports.

  Example 3: User runs /verify "deployContract deploys to the network" — the
  orchestrator classifies this as an SDK behavioral claim, dispatches the
  sdk-tester agent (if devnet is available), and reports.

  Example 4: User runs /verify src/deploy.ts — the orchestrator dispatches
  the type-checker for type errors and sdk-tester for behavioral verification
  concurrently.

  Example 5: A claim needs multiple methods — the orchestrator dispatches
  agents concurrently, cross-references findings, synthesizes a combined verdict.
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk
model: sonnet
color: green
---

You are the Midnight verification orchestrator.

## Your Job

1. Load the `midnight-verify:verify-correctness` hub skill — it tells you how to classify, route, dispatch, and synthesize.
2. Based on the claim domain:
   - Compact claims → load `midnight-verify:verify-compact`
   - SDK/TypeScript claims → load `midnight-verify:verify-sdk`
   - Cross-domain → load both
3. Follow the hub skill's process exactly.

## Dispatching Sub-Agents

**Compact verification:**
- Execution → dispatch `midnight-verify:contract-writer`
- Source inspection → dispatch `midnight-verify:source-investigator`

**SDK verification:**
- Type-checking → dispatch `midnight-verify:type-checker`
- Devnet E2E → dispatch `midnight-verify:sdk-tester`
- Source inspection → dispatch `midnight-verify:source-investigator`
- Package checks → dispatch `devs:deps-maintenance` (fallback: run `npm view` directly)

**When multiple methods are needed, dispatch agents concurrently.** They are independent and can run in parallel.

## Important

- You do NOT write test files, type assertions, or search source code yourself — the sub-agents do that.
- Your job is classification, routing, dispatch, and verdict synthesis.
- For SDK claims with both type and behavioral components, dispatch type-checker and sdk-tester concurrently.
- A clean tsc result does NOT confirm behavioral claims — note this when synthesizing verdicts.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md
git commit -m "feat(verify): update verifier agent with SDK dispatch capabilities

Verifier now loads verify-sdk skill and dispatches type-checker,
sdk-tester, and deps-maintenance agents for SDK claims. Handles
concurrent dispatch for claims with multiple verification methods.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 9: Update plugin manifest

**Files:**
- Modify: `plugins/midnight-verify/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump version and update description**

In `plugins/midnight-verify/.claude-plugin/plugin.json`, change:
- `"version": "0.2.0"` → `"version": "0.3.0"`
- Update description to mention SDK verification
- Add `"sdk"` and `"typescript"` to keywords

Replace the full file with:

```json
{
  "name": "midnight-verify",
  "version": "0.3.0",
  "description": "Verification framework for Midnight claims — verifies Compact code by compiling and executing test contracts, SDK/TypeScript claims by type-checking and devnet E2E testing, or by inspecting source code. Multi-agent pipeline with explicit /verify command.",
  "author": {
    "name": "Aaron Bassett",
    "email": "aaron@devrel-ai.com"
  },
  "homepage": "https://github.com/devrelaicom/midnight-expert",
  "repository": "https://github.com/devrelaicom/midnight-expert.git",
  "license": "MIT",
  "keywords": [
    "midnight",
    "compact",
    "verification",
    "correctness",
    "compile",
    "execute",
    "source-code",
    "zero-knowledge",
    "fact-checking",
    "testing",
    "sdk",
    "typescript"
  ]
}
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-verify/.claude-plugin/plugin.json
git commit -m "chore(verify): bump version to 0.3.0 for SDK verification

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

### Task 10: Final verification

**Files:**
- Verify: all files in `plugins/midnight-verify/`

- [ ] **Step 1: Verify complete plugin structure**

```bash
find plugins/midnight-verify -type f | sort
```

Expected (new files marked with *):
```
plugins/midnight-verify/.claude-plugin/plugin.json
plugins/midnight-verify/LICENSE
plugins/midnight-verify/agents/contract-writer.md
plugins/midnight-verify/agents/sdk-tester.md              *
plugins/midnight-verify/agents/source-investigator.md
plugins/midnight-verify/agents/type-checker.md             *
plugins/midnight-verify/agents/verifier.md
plugins/midnight-verify/commands/verify.md
plugins/midnight-verify/hooks/hooks.json
plugins/midnight-verify/hooks/stop-check.sh
plugins/midnight-verify/skills/verify-by-devnet/SKILL.md   *
plugins/midnight-verify/skills/verify-by-execution/SKILL.md
plugins/midnight-verify/skills/verify-by-source/SKILL.md
plugins/midnight-verify/skills/verify-by-type-check/SKILL.md *
plugins/midnight-verify/skills/verify-compact/SKILL.md
plugins/midnight-verify/skills/verify-correctness/SKILL.md
plugins/midnight-verify/skills/verify-sdk/SKILL.md
```

- [ ] **Step 2: Verify all new skill frontmatter**

```bash
for f in plugins/midnight-verify/skills/verify-sdk/SKILL.md plugins/midnight-verify/skills/verify-by-type-check/SKILL.md plugins/midnight-verify/skills/verify-by-devnet/SKILL.md; do
  echo "=== $f ==="
  head -8 "$f"
  echo ""
done
```

Expected: each has `version: 0.3.0`

- [ ] **Step 3: Verify new agent frontmatter**

```bash
for f in plugins/midnight-verify/agents/type-checker.md plugins/midnight-verify/agents/sdk-tester.md; do
  echo "=== $f ==="
  head -5 "$f"
  echo ""
done
```

Expected: type-checker has `model: sonnet`, `color: yellow`; sdk-tester has `model: sonnet`, `color: magenta`

- [ ] **Step 4: Verify verifier agent loads verify-sdk**

```bash
grep 'skills:' plugins/midnight-verify/agents/verifier.md
```

Expected: `skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk`

- [ ] **Step 5: Verify hub has new dispatch targets**

```bash
grep -c 'type-checker\|sdk-tester\|deps-maintenance' plugins/midnight-verify/skills/verify-correctness/SKILL.md
```

Expected: 3 or more matches

- [ ] **Step 6: Verify source skill has midnight-js**

```bash
grep 'midnight-js' plugins/midnight-verify/skills/verify-by-source/SKILL.md
```

Expected: at least one match with `midnightntwrk/midnight-js`

- [ ] **Step 7: Verify plugin version**

```bash
jq -r '.version' plugins/midnight-verify/.claude-plugin/plugin.json
```

Expected: `0.3.0`

- [ ] **Step 8: Review git log**

```bash
git log --oneline HEAD~9..HEAD
```

Expected: ~9 commits covering all tasks
