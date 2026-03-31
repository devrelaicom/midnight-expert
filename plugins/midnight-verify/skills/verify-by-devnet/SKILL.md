---
name: midnight-verify:verify-by-devnet
description: >-
  Verification by running E2E scripts against a local Midnight devnet.
  Writes SDK test scripts (raw or using testkit-js) that exercise the
  full transaction pipeline: deploy, call circuits, observe state. Checks
  devnet health before proceeding. Loaded by the sdk-tester agent.
  Loads the `midnight-tooling:devnet` skill for infrastructure management.
version: 0.3.0
---

# Verify by Devnet Execution

You are verifying an SDK behavioral claim by running a test script against a live local devnet. Follow these steps in order.

## Critical Rule

**Do NOT attempt E2E testing without first confirming devnet is healthy.** If devnet is unreachable, report Inconclusive immediately. Do not guess at behavior.

## Step 1: Check Devnet Health

Load the `midnight-tooling:devnet` skill for endpoint URLs and health check patterns. Check that all three services are reachable:

1. **Node** — health endpoint
2. **Indexer** — health endpoint
3. **Proof server** — health endpoint

If ANY service is unreachable:
- Report **Inconclusive (devnet unavailable)**
- Message: "Devnet not available. Load the `midnight-tooling:devnet` skill for instructions on starting the devnet, then retry."
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

// 2. Set up providers (load the `midnight-tooling:devnet` skill for URLs)
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
- Multi-step lifecycle tests (deploy -> call -> observe -> reconnect)
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
| "Full lifecycle (deploy -> call -> observe -> reconnect)" | testkit-js |
| "Multi-user interaction" | testkit-js |
| "State observation / subscriptions" | testkit-js |
| "Claim is ABOUT testkit behavior" | Raw SDK script |
| "Claim is about provider wiring" | Raw SDK script |

## Step 4: Handle Compact Contract Dependencies

Most E2E tests need a compiled Compact contract. Options:

1. **Check for pre-compiled test contracts** in the workspace (e.g., a counter contract)
2. **Write and compile a minimal contract** using `compact compile --skip-zk` — load the `midnight-tooling:compact-cli` skill for compilation details
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

## Wallet SDK Devnet Mode

This mode is used ONLY as a fallback for wallet SDK claims when source investigation returned Inconclusive. You will only reach this section if the verifier orchestrator explicitly dispatches you with `domain: 'wallet-sdk'`.

### Health Check Differences

The wallet SDK requires Docker containers instead of a standalone devnet:

1. **midnight-node** — check with `docker ps | grep midnight-node` or query the substrate RPC endpoint
2. **midnight-indexer** — check GraphQL health endpoint (typically `http://localhost:6300/api/v3/graphql`)
3. **proof-server** — check health endpoint (typically `http://localhost:6301/health`)

If ANY container is unreachable:
- Report **Inconclusive (source insufficient, devnet unavailable)**
- Message: "Source investigation was inconclusive and wallet devnet infrastructure is not available. Start the required Docker containers and retry."
- Stop. Do not proceed.

### Workspace

Reuse the wallet-sdk-workspace at `.midnight-expert/verify/wallet-sdk-workspace/`. It already has all wallet SDK packages installed.

### Script Approach

Write test scripts using the wallet SDK packages directly. The `packages/docs-snippets/` in the wallet repo provide reference patterns for common operations (initialization, transfers, swaps, balancing). Use these as hints for script structure but verify behavior through execution.

The rest of the devnet verification flow (choose approach, write script, run, interpret, report, clean up) follows the same pattern as the standard SDK devnet mode.
