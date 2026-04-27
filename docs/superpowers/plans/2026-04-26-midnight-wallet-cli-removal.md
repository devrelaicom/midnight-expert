# Midnight Wallet CLI/MCP Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the unofficial `midnight-wallet-cli`/`midnight-wallet-mcp` layer from the `midnight-wallet` plugin and replace it with three SDK-driven skills (`wallet-sdk` expanded, `managing-test-wallets` new, `sdk-regression-check` new), updating cross-plugin references and adding a single descriptive doc to `midnight-tooling:devnet`.

**Architecture:** The plugin owns three orthogonal skills. `wallet-sdk` is a source-verified reference, expanded with material from a fresh audit of the wallet SDK source. `managing-test-wallets` is a procedural skill teaching test-wallet patterns with executable example scripts. `sdk-regression-check` is the drift-detection layer — fast no-network drift check plus a slow live-devnet smoke test, with a strict "report only, never edit the lock file" policy.

**Tech Stack:** TypeScript, Node 20+, `npx tsx`, bash, `jq`, `npm`, the Midnight Wallet SDK (`@midnight-ntwrk/wallet-sdk-*`), `@midnight-ntwrk/ledger-v8`, the local Midnight devnet (Docker Compose via `midnight-tooling:devnet`).

**Spec:** `docs/superpowers/specs/2026-04-26-midnight-wallet-cli-removal-design.md`

---

## Phase 0 Findings — Plan Corrections (added 2026-04-27)

After Phase 0 ran end-to-end, two facts emerged that change the rest of the plan. Apply these corrections wherever you encounter the older patterns in this document.

### Correction A — Native NIGHT token key is NOT `""`

`UnshieldedWalletState.balances` is keyed by the token's raw bytes as a hex string. For the native NIGHT token that key is **64 hex zeros**, obtained from `ledger.nativeToken().raw`. The empty-string key returns nothing.

Wherever this plan or its embedded code blocks show:
```ts
state.unshielded.balances[""]
```
…the correct form is:
```ts
const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;
state.unshielded.balances[NIGHT_TOKEN_TYPE] ?? 0n
```

This affects: Task 0.6's fixture (already verified with the corrected key), Task 3.3's smoke-test fixture, Task 4.4-4.9 examples that read NIGHT balance, Tasks 4.10/4.14 references describing balance shapes, and Task 5.1's reconciliation (the existing `wallet-sdk:references/state-and-balances.md` makes the same wrong claim about `""` and must be corrected too).

### Correction B — Verification harness and smoke-test temp project must be ESM

`@midnight-ntwrk/wallet-sdk-*` packages are published as `"type": "module"`. CommonJS consumers fail with `ERR_PACKAGE_PATH_NOT_EXPORTED`.

For Task 0.5: the harness `package.json` was set to `"type": "module"` (already done).

For Task 3.4 (`smoke-test.sh`): after `npm init -y`, add a step to set the temp project's type to module:

```bash
cd "$WORKDIR"
npm init -y >/dev/null
npm pkg set type=module
```

For all Phase 4 example scripts: write them as ESM (`import`, not `require`); the harness is already ESM so they will run correctly via `npx tsx`.

---

## Verification Discipline

The whole motivation for this rework is that the prior CLI/MCP layer drifted silently from the SDK. The replacement must not have the same failure mode. Therefore:

1. **Every example script ships only after it has been executed end-to-end against a running local devnet.** Compilation is necessary but not sufficient. If a script can't run end-to-end (e.g. the public-faucet example needs a real testnet faucet), the plan calls out the specific manual verification step.
2. **Every claim added to the wallet-sdk reference skill is verified before commit** by either (a) writing a small TypeScript fixture that exercises the claim and observing real behavior, or (b) when execution is not feasible, by reading the actual source of the relevant package in `/tmp/midnight-wallet`.
3. **A single `/tmp/wallet-sdk-verify/` test project is the verification harness** for the entire implementation. It is set up once in Phase 0 and reused throughout. Every code-bearing task references it.
4. **The two audit-flagged discrepancies** (`TransactionHistoryStorage.getAll()` and `serialize()` return types) are reconciled in Phase 0 by reading `/tmp/midnight-wallet/packages/abstractions/src/index.ts`. The plan does not proceed past Phase 0 until those two facts are pinned.

---

## File Structure

### Files to delete (Phase 2)

| Path | Reason |
|------|--------|
| `plugins/midnight-wallet/.mcp.json` | Wires the unofficial wallet MCP server |
| `plugins/midnight-wallet/commands/fund-mnemonic.md` | Calls MCP tools that will not exist |
| `plugins/midnight-wallet/commands/` | Empty after fund-mnemonic.md is gone |
| `plugins/midnight-wallet/hooks/hooks.json` | Every entry matches `mcp__midnight-wallet__*` |
| `plugins/midnight-wallet/hooks/scripts/session-start-health.sh` | Shells out to deleted CLI |
| `plugins/midnight-wallet/hooks/` | Empty after the above |
| `plugins/midnight-wallet/skills/wallet-cli/` | Whole skill directory + references |
| `plugins/midnight-wallet/skills/setup-test-wallets/` | Whole skill (MCP-orchestrated) |
| `plugins/midnight-wallet/skills/wallet-aliases/` | Whole skill (alias store + script) |

### Files to modify

| Path | Modification |
|------|--------------|
| `plugins/midnight-expert/skills/doctor/scripts/check-mcp-servers.sh` | Remove the line listing the wallet MCP entry |
| `plugins/midnight-expert/skills/doctor/references/fix-table.md` | Remove the `midnight-wallet not configured` row |
| `plugins/midnight-wallet/.claude-plugin/plugin.json` | Update description, keywords, version |
| `plugins/midnight-wallet/README.md` | Full rewrite around three skills |
| `plugins/midnight-wallet/skills/wallet-sdk/SKILL.md` | Add disambiguation + caveat + new reference rows |
| `plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md` | Add meta-package, sub-exports, expand utilities row, add Simulator/T&C/Clock |
| `plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md` | Cross-link the new capabilities-deep-dive |
| `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md` | Cross-link errors-and-troubleshooting |
| `plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md` | Add Clock note |
| `plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md` | Reconcile `TransactionHistoryStorage` signatures from Phase 0 findings |
| `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md` | Reconcile `getAllFromTxHistory` signature if Phase 0 finds drift |

### Files to create

| Path | Purpose |
|------|---------|
| `plugins/midnight-tooling/skills/devnet/references/genesis-seed.md` | Descriptive doc, content provided in spec verbatim |
| `plugins/midnight-wallet/skills/wallet-sdk/references/variants-and-runtime.md` | New reference, audit-driven |
| `plugins/midnight-wallet/skills/wallet-sdk/references/effect-and-promise-apis.md` | New reference, audit-driven |
| `plugins/midnight-wallet/skills/wallet-sdk/references/capabilities-deep-dive.md` | New reference, audit-driven |
| `plugins/midnight-wallet/skills/wallet-sdk/references/errors-and-troubleshooting.md` | New reference, audit-driven |
| `plugins/midnight-wallet/skills/managing-test-wallets/SKILL.md` | New skill entry |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/addresses-and-tokens.md` | Three-address model |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/wallet-creation.md` | Seed sources, HD derivation, construction |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/funding.md` | Network-keyed funding strategies |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/dust-registration.md` | DUST mechanics + registration |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/balance-monitoring.md` | State subscription patterns |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/transfers.md` | Three transfer kinds |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/network-config.md` | DefaultConfiguration per network |
| `plugins/midnight-wallet/skills/managing-test-wallets/references/troubleshooting.md` | Common symptom→cause table |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/create-wallet.ts` | Wallet construction template |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-undeployed.ts` | Genesis-seed airdrop |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-public-faucet.ts` | Print-and-wait pattern |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/register-dust.ts` | DUST registration |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/monitor-wallet.ts` | Live balance ticker |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-night.ts` | Unshielded transfer |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-shielded.ts` | Shielded transfer |
| `plugins/midnight-wallet/skills/managing-test-wallets/examples/full-test-wallet-setup.ts` | End-to-end script |
| `plugins/midnight-wallet/skills/sdk-regression-check/SKILL.md` | New skill entry |
| `plugins/midnight-wallet/skills/sdk-regression-check/versions.lock.json` | Pinned versions + verified date |
| `plugins/midnight-wallet/skills/sdk-regression-check/references/interpreting-output.md` | Drift-table interpretation |
| `plugins/midnight-wallet/skills/sdk-regression-check/references/using-release-notes.md` | Drift workflow with release-notes skill |
| `plugins/midnight-wallet/skills/sdk-regression-check/references/temp-project-setup.md` | Manual temp-project steps |
| `plugins/midnight-wallet/skills/sdk-regression-check/references/smoke-test-anatomy.md` | Step-by-step smoke explanation |
| `plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh` | Fast no-network drift |
| `plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh` | Devnet-required smoke |
| `plugins/midnight-wallet/skills/sdk-regression-check/scripts/fixtures/smoke-test.ts` | Fixture run by smoke-test.sh |

---

## Phase 0 — Verification harness setup and audit-discrepancy reconciliation

### Task 0.1: Confirm wallet SDK source clone

**Files:** none (verification only)

- [ ] **Step 1: Confirm `/tmp/midnight-wallet` exists and is a fresh clone**

```bash
ls -d /tmp/midnight-wallet/.git && cat /tmp/midnight-wallet/package.json | head -5
```

Expected: `/tmp/midnight-wallet/.git` exists; `package.json` shows the workspace root.

- [ ] **Step 2: If missing, clone it**

```bash
cd /tmp && git clone --depth 1 git@github.com:midnightntwrk/midnight-wallet.git
```

### Task 0.2: Confirm local devnet is running

**Files:** none

- [ ] **Step 1: Check devnet health**

```bash
docker ps --format '{{.Names}}' | grep -E 'midnight-(node|indexer|proof-server)' | sort
```

Expected output (three lines, in any order):
```
midnight-indexer
midnight-node
midnight-proof-server
```

- [ ] **Step 2: If missing or unhealthy, start it via the devnet skill**

Load the `midnight-tooling:devnet` skill and run:

```bash
# Inside the devnet skill workflow
/midnight-tooling:devnet start
/midnight-tooling:devnet health
```

Expected: all three services healthy. If any are unhealthy, do not proceed past Phase 0.

### Task 0.3: Reconcile `TransactionHistoryStorage.getAll()` return type

**Files:**
- Read: `/tmp/midnight-wallet/packages/abstractions/src/index.ts`
- Read: `/tmp/midnight-wallet/packages/abstractions/src/TransactionHistoryStorage.ts` (if it exists as a separate file)
- Read: `plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md` (current claim)
- Read: `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md` (current cross-claim)

- [ ] **Step 1: Locate the `TransactionHistoryStorage` interface in the source**

```bash
grep -rn "interface TransactionHistoryStorage\|type TransactionHistoryStorage" /tmp/midnight-wallet/packages/abstractions/src/
```

Capture the file path and the full interface body in the task notes.

- [ ] **Step 2: Record the canonical signature for `getAll()` in a working note**

Create `/tmp/wallet-sdk-verify/notes/transaction-history-storage.md` (mkdir as needed) and write:

```markdown
# TransactionHistoryStorage — verified signatures

Source: <exact file path and line numbers>
Date: <today>

interface TransactionHistoryStorage<T extends { hash: TransactionHash }> {
  upsert(entry: T): Promise<void>;
  getAll(): <verified return type>;
  get(hash: TransactionHash): Promise<T | undefined>;
  serialize(): <verified return type>;
}
```

This file is the source of truth for Phase 6 reconciliation tasks.

- [ ] **Step 3: Decide which existing reference text needs editing**

If `getAll()` returns `AsyncIterableIterator<T>` (matching the existing skill), no change is needed — record this in the note.
If it returns `Promise<T[]>` (matching the audit summary), flag it for Phase 6 update.
Either way, the answer must come from the source — not from speculation.

### Task 0.4: Reconcile `TransactionHistoryStorage.serialize()` return type

**Files:** same as Task 0.3

- [ ] **Step 1: Read the same interface block; capture the actual return type of `serialize()`**

Update the note in `/tmp/wallet-sdk-verify/notes/transaction-history-storage.md` with the verified type.

- [ ] **Step 2: Decide if the current skill text needs editing**

Current skill says `Promise<SerializedTransactionHistory>`; audit says `Promise<string>`. Pick the one in the source. Flag the result for Phase 6.

### Task 0.5: Set up the verification test project

**Files:**
- Create: `/tmp/wallet-sdk-verify/package.json`
- Create: `/tmp/wallet-sdk-verify/tsconfig.json`
- Create: `/tmp/wallet-sdk-verify/.gitignore`

- [ ] **Step 1: Create the project directory and initialize**

```bash
mkdir -p /tmp/wallet-sdk-verify && cd /tmp/wallet-sdk-verify && npm init -y >/dev/null
```

- [ ] **Step 2: Pin the latest stable wallet SDK packages and ledger**

```bash
cd /tmp/wallet-sdk-verify && npm install \
  @midnight-ntwrk/wallet-sdk \
  @midnight-ntwrk/wallet-sdk-facade \
  @midnight-ntwrk/wallet-sdk-hd \
  @midnight-ntwrk/wallet-sdk-shielded \
  @midnight-ntwrk/wallet-sdk-unshielded-wallet \
  @midnight-ntwrk/wallet-sdk-dust-wallet \
  @midnight-ntwrk/wallet-sdk-capabilities \
  @midnight-ntwrk/wallet-sdk-abstractions \
  @midnight-ntwrk/wallet-sdk-address-format \
  @midnight-ntwrk/wallet-sdk-runtime \
  @midnight-ntwrk/wallet-sdk-utilities \
  @midnight-ntwrk/wallet-sdk-indexer-client \
  @midnight-ntwrk/wallet-sdk-node-client \
  @midnight-ntwrk/wallet-sdk-prover-client \
  @midnight-ntwrk/ledger-v8 \
  @scure/bip39 \
  ws \
  rxjs
```

```bash
cd /tmp/wallet-sdk-verify && npm install -D tsx typescript @types/node @types/ws
```

- [ ] **Step 3: Write a minimal tsconfig**

`/tmp/wallet-sdk-verify/tsconfig.json`:
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "resolveJsonModule": true
  },
  "include": ["**/*.ts"]
}
```

- [ ] **Step 4: Capture the resolved versions for use in Phase 4**

```bash
cd /tmp/wallet-sdk-verify && \
  jq '{
    "@midnight-ntwrk/wallet-sdk": .dependencies["@midnight-ntwrk/wallet-sdk"],
    "@midnight-ntwrk/wallet-sdk-facade": .dependencies["@midnight-ntwrk/wallet-sdk-facade"],
    "@midnight-ntwrk/wallet-sdk-hd": .dependencies["@midnight-ntwrk/wallet-sdk-hd"],
    "@midnight-ntwrk/wallet-sdk-shielded": .dependencies["@midnight-ntwrk/wallet-sdk-shielded"],
    "@midnight-ntwrk/wallet-sdk-unshielded-wallet": .dependencies["@midnight-ntwrk/wallet-sdk-unshielded-wallet"],
    "@midnight-ntwrk/wallet-sdk-dust-wallet": .dependencies["@midnight-ntwrk/wallet-sdk-dust-wallet"],
    "@midnight-ntwrk/wallet-sdk-capabilities": .dependencies["@midnight-ntwrk/wallet-sdk-capabilities"],
    "@midnight-ntwrk/wallet-sdk-abstractions": .dependencies["@midnight-ntwrk/wallet-sdk-abstractions"],
    "@midnight-ntwrk/wallet-sdk-address-format": .dependencies["@midnight-ntwrk/wallet-sdk-address-format"],
    "@midnight-ntwrk/wallet-sdk-runtime": .dependencies["@midnight-ntwrk/wallet-sdk-runtime"],
    "@midnight-ntwrk/wallet-sdk-utilities": .dependencies["@midnight-ntwrk/wallet-sdk-utilities"],
    "@midnight-ntwrk/wallet-sdk-indexer-client": .dependencies["@midnight-ntwrk/wallet-sdk-indexer-client"],
    "@midnight-ntwrk/wallet-sdk-node-client": .dependencies["@midnight-ntwrk/wallet-sdk-node-client"],
    "@midnight-ntwrk/wallet-sdk-prover-client": .dependencies["@midnight-ntwrk/wallet-sdk-prover-client"]
  }' /tmp/wallet-sdk-verify/package.json > /tmp/wallet-sdk-verify/notes/resolved-versions.json
```

Strip leading `^` from each value before reusing in `versions.lock.json`.

- [ ] **Step 5: Smoke-build the project to confirm types resolve**

```bash
cd /tmp/wallet-sdk-verify && npx tsc --noEmit
```

Expected: no errors (or only `skipLibCheck`-style benign warnings). If errors, do not proceed; fix the install before continuing.

### Task 0.6: Sanity-check the genesis-seed wallet build

**Files:**
- Create: `/tmp/wallet-sdk-verify/check-genesis.ts`

This single fixture validates the construction pattern that every Phase 5 example depends on. If it fails, the rest of the plan cannot succeed.

- [ ] **Step 1: Write the fixture**

`/tmp/wallet-sdk-verify/check-genesis.ts`:
```typescript
// Sanity check: build a wallet from the local-devnet genesis seed,
// wait for sync, assert non-zero unshielded NIGHT balance.

import WebSocket from "ws";
(globalThis as any).WebSocket = WebSocket;

import { Buffer } from "buffer";
import * as Rx from "rxjs";
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";
import {
  WalletFacade,
  WalletEntrySchema,
  type DefaultConfiguration,
} from "@midnight-ntwrk/wallet-sdk-facade";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
  UnshieldedWallet,
  createKeystore,
  PublicKey,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { InMemoryTransactionHistoryStorage } from "@midnight-ntwrk/wallet-sdk-abstractions";
import * as ledger from "@midnight-ntwrk/ledger-v8";

const GENESIS_SEED_HEX =
  "0000000000000000000000000000000000000000000000000000000000000001";

async function main() {
  const seed = Buffer.from(GENESIS_SEED_HEX, "hex");

  const hd = HDWallet.fromSeed(seed);
  if (hd.type !== "seedOk") throw new Error("HDWallet.fromSeed failed");

  const derived = hd.hdWallet
    .selectAccount(0)
    .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust] as const)
    .deriveKeysAt(0);
  if (derived.type !== "keysDerived")
    throw new Error("deriveKeysAt failed");

  hd.hdWallet.clear();

  const configuration: DefaultConfiguration = {
    networkId: "undeployed",
    costParameters: { feeBlocksMargin: 5 },
    relayURL: new URL("ws://localhost:9944"),
    provingServerUrl: new URL("http://localhost:6300"),
    indexerClientConnection: {
      indexerHttpUrl: "http://localhost:8088/api/v3/graphql",
      indexerWsUrl: "ws://localhost:8088/api/v3/graphql/ws",
    },
    txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
  };

  const shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(
    derived.keys[Roles.Zswap]
  );
  const dustSecretKey = ledger.DustSecretKey.fromSeed(
    derived.keys[Roles.Dust]
  );
  const unshieldedKeystore = createKeystore(
    derived.keys[Roles.NightExternal],
    "undeployed"
  );

  const wallet = await WalletFacade.init({
    configuration,
    shielded: (cfg) =>
      ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys),
    unshielded: (cfg) =>
      UnshieldedWallet(cfg).startWithPublicKey(
        PublicKey.fromKeyStore(unshieldedKeystore)
      ),
    dust: (cfg) =>
      DustWallet(cfg).startWithSecretKey(
        dustSecretKey,
        ledger.LedgerParameters.initialParameters().dust
      ),
  });

  await wallet.start(shieldedSecretKeys, dustSecretKey);
  const state = await wallet.waitForSyncedState();
  const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;
  const night = state.unshielded.balances[NIGHT_TOKEN_TYPE] ?? 0n;
  console.log(`Genesis-seed unshielded NIGHT balance: ${night}`);
  if (night <= 0n) {
    throw new Error(
      "Expected non-zero NIGHT balance for the genesis seed; got 0"
    );
  }
  await wallet.stop();
  process.exit(0);
}

main().catch((err) => {
  console.error("[check-genesis] FAILED:", err);
  process.exit(1);
});
```

- [ ] **Step 2: Run it against the local devnet**

```bash
cd /tmp/wallet-sdk-verify && npx tsx check-genesis.ts
```

Expected: prints `Genesis-seed unshielded NIGHT balance: <positive bigint>` and exits 0.

If it fails, the SDK signatures used here have drifted from those in the existing `wallet-sdk` skill. Reconcile the failure point before proceeding — do not continue with stale assumptions.

- [ ] **Step 3: Capture the observed balance for use in Phase 4**

Append to `/tmp/wallet-sdk-verify/notes/resolved-versions.json` (or alongside) a one-line note:

```bash
echo "genesis_seed_min_balance=<observed-value>" >> /tmp/wallet-sdk-verify/notes/devnet-facts.txt
```

This value (or simply `> 0n` if it varies between devnet image versions) becomes the smoke-test assertion threshold in Phase 4.

### Task 0.7: Commit Phase 0 verification notes (working notes only — not part of the plugin)

**Files:** none committed to the repo. The notes live in `/tmp/wallet-sdk-verify/` and are reused throughout the implementation.

- [ ] **Checkpoint:** Confirm Phase 0 outputs:
  - `/tmp/midnight-wallet/` is a fresh clone
  - `/tmp/wallet-sdk-verify/` is a working SDK consumer with `tsc --noEmit` clean
  - `/tmp/wallet-sdk-verify/notes/transaction-history-storage.md` records the verified `getAll()` and `serialize()` signatures
  - `/tmp/wallet-sdk-verify/notes/resolved-versions.json` lists the installed SDK package versions
  - `/tmp/wallet-sdk-verify/check-genesis.ts` runs and reports a non-zero NIGHT balance

Do not proceed to Phase 1 until all five hold.

---

## Phase 1 — Removals

### Task 1.1: Delete the wallet MCP wiring

**Files:**
- Delete: `plugins/midnight-wallet/.mcp.json`

- [ ] **Step 1: Delete the file**

```bash
git rm plugins/midnight-wallet/.mcp.json
```

- [ ] **Step 2: Confirm no remaining references in the plugin**

```bash
grep -r "\.mcp\.json\|midnight-wallet-mcp" plugins/midnight-wallet/ || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(midnight-wallet): remove wallet MCP server wiring"
```

### Task 1.2: Delete the fund-mnemonic command and the commands directory

**Files:**
- Delete: `plugins/midnight-wallet/commands/fund-mnemonic.md`
- Delete: `plugins/midnight-wallet/commands/`

- [ ] **Step 1: Remove the file and directory**

```bash
git rm -r plugins/midnight-wallet/commands
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(midnight-wallet): remove fund-mnemonic command (used MCP tools)"
```

### Task 1.3: Delete the hooks directory

**Files:**
- Delete: `plugins/midnight-wallet/hooks/hooks.json`
- Delete: `plugins/midnight-wallet/hooks/scripts/session-start-health.sh`
- Delete: `plugins/midnight-wallet/hooks/`

- [ ] **Step 1: Remove the directory and all contents**

```bash
git rm -r plugins/midnight-wallet/hooks
```

- [ ] **Step 2: Verify no remaining hook references in the plugin**

```bash
grep -r "mcp__midnight-wallet\|session-start-health\.sh" plugins/midnight-wallet/ || echo "clean"
```

Expected: `clean`.

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(midnight-wallet): remove hooks targeting deleted MCP tools"
```

### Task 1.4: Delete the wallet-cli skill

**Files:**
- Delete: `plugins/midnight-wallet/skills/wallet-cli/`

- [ ] **Step 1: Remove the skill directory recursively**

```bash
git rm -r plugins/midnight-wallet/skills/wallet-cli
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(midnight-wallet): remove wallet-cli skill"
```

### Task 1.5: Delete the setup-test-wallets skill

**Files:**
- Delete: `plugins/midnight-wallet/skills/setup-test-wallets/`

- [ ] **Step 1: Remove the directory**

```bash
git rm -r plugins/midnight-wallet/skills/setup-test-wallets
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(midnight-wallet): remove setup-test-wallets skill (MCP-orchestrated)"
```

### Task 1.6: Delete the wallet-aliases skill

**Files:**
- Delete: `plugins/midnight-wallet/skills/wallet-aliases/`

- [ ] **Step 1: Remove the directory**

```bash
git rm -r plugins/midnight-wallet/skills/wallet-aliases
```

- [ ] **Step 2: Commit**

```bash
git commit -m "feat(midnight-wallet): remove wallet-aliases skill"
```

### Task 1.7: Update doctor's check-mcp-servers.sh to drop the wallet MCP entry

**Files:**
- Modify: `plugins/midnight-expert/skills/doctor/scripts/check-mcp-servers.sh`

- [ ] **Step 1: Read the script and locate the wallet line**

```bash
grep -n "midnight-wallet" plugins/midnight-expert/skills/doctor/scripts/check-mcp-servers.sh
```

- [ ] **Step 2: Delete the line that references the wallet MCP**

Open the file and remove the line:
```
"midnight-wallet|midnight-wallet|claude mcp add midnight-wallet -- npx -y -p midnight-wallet-cli@latest midnight-wallet-mcp|midnight-wallet"
```

(or the equivalent if the exact text has been edited since the spec was written — the line is the one that names `midnight-wallet-cli`).

- [ ] **Step 3: Run the script to confirm it still parses and executes**

```bash
bash plugins/midnight-expert/skills/doctor/scripts/check-mcp-servers.sh || true
```

Expected: the script runs, exits with whatever status it normally exits with (depends on the user's MCP config), and does not mention `midnight-wallet` in its output.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-expert/skills/doctor/scripts/check-mcp-servers.sh
git commit -m "fix(midnight-expert:doctor): drop wallet MCP entry from MCP server check"
```

### Task 1.8: Update doctor's fix-table.md

**Files:**
- Modify: `plugins/midnight-expert/skills/doctor/references/fix-table.md`

- [ ] **Step 1: Locate the wallet row**

```bash
grep -n "midnight-wallet not configured" plugins/midnight-expert/skills/doctor/references/fix-table.md
```

- [ ] **Step 2: Remove the row**

Delete the table row whose left column starts with `midnight-wallet not configured`. Preserve all other rows and the table header.

- [ ] **Step 3: Confirm the table is still valid markdown**

```bash
grep -E "^\|" plugins/midnight-expert/skills/doctor/references/fix-table.md | head -5
```

Inspect the output to confirm the table header and at least the next two surviving rows render as a coherent table.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-expert/skills/doctor/references/fix-table.md
git commit -m "fix(midnight-expert:doctor): drop wallet MCP fix-table row"
```

---

## Phase 2 — Add `genesis-seed.md` to `midnight-tooling:devnet`

### Task 2.1: Create the reference

**Files:**
- Create: `plugins/midnight-tooling/skills/devnet/references/genesis-seed.md`

- [ ] **Step 1: Write the file with the exact content from the spec**

`plugins/midnight-tooling/skills/devnet/references/genesis-seed.md`:
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

- [ ] **Step 2: Verify the seed value still grants funded access**

You already verified this in Task 0.6 — confirm `check-genesis.ts` ran and reported a positive balance. If you have not run it yet, do so now.

- [ ] **Step 3: Optionally cross-link from the devnet SKILL.md (only if the existing SKILL.md has a "References" or "See also" section)**

```bash
grep -n "## References\|## See also\|## Resources" plugins/midnight-tooling/skills/devnet/SKILL.md
```

If a section exists, add a link to `references/genesis-seed.md` there. If not, skip — the reference is discoverable by listing the directory.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-tooling/skills/devnet/references/genesis-seed.md plugins/midnight-tooling/skills/devnet/SKILL.md 2>/dev/null
git commit -m "docs(midnight-tooling:devnet): add genesis-seed reference"
```

---

## Phase 3 — Build the `sdk-regression-check` skill

### Task 3.1: Create the skill directory and `versions.lock.json`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/versions.lock.json`

- [ ] **Step 1: Make the skill directory tree**

```bash
mkdir -p plugins/midnight-wallet/skills/sdk-regression-check/{references,scripts/fixtures}
```

- [ ] **Step 2: Build `versions.lock.json` from Phase 0 resolved versions**

Read the resolved versions captured in `/tmp/wallet-sdk-verify/notes/resolved-versions.json`. Strip leading `^` from each value. Write:

```json
{
  "verified": "<today YYYY-MM-DD>",
  "packages": {
    "@midnight-ntwrk/wallet-sdk": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-facade": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-hd": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-shielded": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-unshielded-wallet": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-dust-wallet": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-capabilities": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-abstractions": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-address-format": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-runtime": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-utilities": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-indexer-client": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-node-client": "<resolved>",
    "@midnight-ntwrk/wallet-sdk-prover-client": "<resolved>"
  }
}
```

- [ ] **Step 3: Validate JSON**

```bash
jq . plugins/midnight-wallet/skills/sdk-regression-check/versions.lock.json
```

Expected: pretty-printed valid JSON.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/versions.lock.json
git commit -m "feat(midnight-wallet:sdk-regression-check): add versions.lock.json"
```

### Task 3.2: Implement `drift-check.sh`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Compare each package version pinned in versions.lock.json with the
# latest version on npm. Print a drift table; exit 0 if all none/patch,
# 1 if any minor/major drift detected.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${SCRIPT_DIR}/../versions.lock.json"

if [[ ! -f "$LOCK" ]]; then
  echo "ERROR: versions.lock.json not found at $LOCK" >&2
  exit 2
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required" >&2
  exit 2
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "ERROR: npm is required" >&2
  exit 2
fi

VERIFIED="$(jq -r '.verified' "$LOCK")"
PACKAGES_JSON="$(jq -c '.packages' "$LOCK")"

drift_class() {
  local pinned="$1" latest="$2"
  if [[ "$pinned" == "$latest" ]]; then echo "none"; return; fi
  local pm; pm="$(echo "$pinned" | cut -d. -f1)"
  local lm; lm="$(echo "$latest" | cut -d. -f1)"
  if [[ "$pm" != "$lm" ]]; then echo "MAJOR"; return; fi
  local pn; pn="$(echo "$pinned" | cut -d. -f2)"
  local ln; ln="$(echo "$latest" | cut -d. -f2)"
  if [[ "$pn" != "$ln" ]]; then echo "minor"; return; fi
  echo "patch"
}

echo "Verified: $VERIFIED"
echo
printf '%-50s %-12s %-12s %s\n' "PACKAGE" "PINNED" "LATEST" "DRIFT"
printf '%-50s %-12s %-12s %s\n' "-------" "------" "------" "-----"

drift_total=0
while IFS= read -r line; do
  pkg="$(echo "$line" | jq -r '.key')"
  pinned="$(echo "$line" | jq -r '.value')"
  latest="$(npm view "$pkg" version 2>/dev/null || echo "ERR")"
  if [[ "$latest" == "ERR" ]]; then
    printf '%-50s %-12s %-12s %s\n' "$pkg" "$pinned" "?" "npm-error"
    continue
  fi
  d="$(drift_class "$pinned" "$latest")"
  printf '%-50s %-12s %-12s %s\n' "$pkg" "$pinned" "$latest" "$d"
  if [[ "$d" == "minor" || "$d" == "MAJOR" ]]; then
    drift_total=$((drift_total + 1))
  fi
done < <(echo "$PACKAGES_JSON" | jq -c 'to_entries[]')

echo
if [[ $drift_total -gt 0 ]]; then
  echo "Drift detected in $drift_total package(s). Run smoke-test.sh to verify whether the documented patterns still work."
  exit 1
fi
echo "No drift."
exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh
```

- [ ] **Step 3: Run it**

```bash
plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh
```

Expected: prints a table; exits 0 (since the lock was just freshly built).

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh
git commit -m "feat(midnight-wallet:sdk-regression-check): add drift-check.sh"
```

### Task 3.3: Implement the smoke-test fixture

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/scripts/fixtures/smoke-test.ts`

- [ ] **Step 1: Write the fixture**

The fixture is a hardened version of `/tmp/wallet-sdk-verify/check-genesis.ts`, with structured error output identifying which step failed.

```typescript
// Smoke test for the wallet SDK construction pattern.
// Steps: HD derivation → key conversion → facade init → start → wait for sync → balance assertion.
// Each step has a tag so failures point to a precise location.

import WebSocket from "ws";
(globalThis as any).WebSocket = WebSocket;

import { Buffer } from "buffer";
import { HDWallet, Roles } from "@midnight-ntwrk/wallet-sdk-hd";
import {
  WalletFacade,
  WalletEntrySchema,
  type DefaultConfiguration,
} from "@midnight-ntwrk/wallet-sdk-facade";
import { ShieldedWallet } from "@midnight-ntwrk/wallet-sdk-shielded";
import {
  UnshieldedWallet,
  createKeystore,
  PublicKey,
} from "@midnight-ntwrk/wallet-sdk-unshielded-wallet";
import { DustWallet } from "@midnight-ntwrk/wallet-sdk-dust-wallet";
import { InMemoryTransactionHistoryStorage } from "@midnight-ntwrk/wallet-sdk-abstractions";
import * as ledger from "@midnight-ntwrk/ledger-v8";

const GENESIS_SEED_HEX =
  "0000000000000000000000000000000000000000000000000000000000000001";

type Step =
  | "hd-derive"
  | "key-convert"
  | "facade-init"
  | "wallet-start"
  | "wait-sync"
  | "balance-read";

function fail(step: Step, err: unknown): never {
  console.error(JSON.stringify({ ok: false, step, error: String(err) }));
  process.exit(1);
}

async function main() {
  let derivedKeys: Record<number, Uint8Array>;
  try {
    const seed = Buffer.from(GENESIS_SEED_HEX, "hex");
    const hd = HDWallet.fromSeed(seed);
    if (hd.type !== "seedOk") throw new Error(`HDWallet.fromSeed: ${hd.type}`);
    const derived = hd.hdWallet
      .selectAccount(0)
      .selectRoles([Roles.Zswap, Roles.NightExternal, Roles.Dust] as const)
      .deriveKeysAt(0);
    if (derived.type !== "keysDerived")
      throw new Error(`deriveKeysAt: ${derived.type}`);
    hd.hdWallet.clear();
    derivedKeys = derived.keys as Record<number, Uint8Array>;
  } catch (e) {
    fail("hd-derive", e);
  }

  let shieldedSecretKeys: ledger.ZswapSecretKeys;
  let dustSecretKey: ledger.DustSecretKey;
  let unshieldedKeystore: ReturnType<typeof createKeystore>;
  try {
    shieldedSecretKeys = ledger.ZswapSecretKeys.fromSeed(
      derivedKeys![Roles.Zswap]
    );
    dustSecretKey = ledger.DustSecretKey.fromSeed(derivedKeys![Roles.Dust]);
    unshieldedKeystore = createKeystore(
      derivedKeys![Roles.NightExternal],
      "undeployed"
    );
  } catch (e) {
    fail("key-convert", e);
  }

  const configuration: DefaultConfiguration = {
    networkId: "undeployed",
    costParameters: { feeBlocksMargin: 5 },
    relayURL: new URL("ws://localhost:9944"),
    provingServerUrl: new URL("http://localhost:6300"),
    indexerClientConnection: {
      indexerHttpUrl: "http://localhost:8088/api/v3/graphql",
      indexerWsUrl: "ws://localhost:8088/api/v3/graphql/ws",
    },
    txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
  };

  let wallet: WalletFacade;
  try {
    wallet = await WalletFacade.init({
      configuration,
      shielded: (cfg) =>
        ShieldedWallet(cfg).startWithSecretKeys(shieldedSecretKeys!),
      unshielded: (cfg) =>
        UnshieldedWallet(cfg).startWithPublicKey(
          PublicKey.fromKeyStore(unshieldedKeystore!)
        ),
      dust: (cfg) =>
        DustWallet(cfg).startWithSecretKey(
          dustSecretKey!,
          ledger.LedgerParameters.initialParameters().dust
        ),
    });
  } catch (e) {
    fail("facade-init", e);
  }

  try {
    await wallet!.start(shieldedSecretKeys!, dustSecretKey!);
  } catch (e) {
    fail("wallet-start", e);
  }

  let state: Awaited<ReturnType<WalletFacade["waitForSyncedState"]>>;
  try {
    state = await wallet!.waitForSyncedState();
  } catch (e) {
    fail("wait-sync", e);
  }

  try {
    const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;
    const night = state!.unshielded.balances[NIGHT_TOKEN_TYPE] ?? 0n;
    if (night <= 0n) {
      throw new Error(`Expected NIGHT > 0, got ${night}`);
    }
    console.log(JSON.stringify({ ok: true, night: night.toString() }));
  } catch (e) {
    fail("balance-read", e);
  }

  await wallet!.stop();
  process.exit(0);
}

main().catch((e) => fail("balance-read", e));
```

- [ ] **Step 2: Verify it runs in `/tmp/wallet-sdk-verify` first**

Copy the file there and run it:

```bash
cp plugins/midnight-wallet/skills/sdk-regression-check/scripts/fixtures/smoke-test.ts /tmp/wallet-sdk-verify/smoke-test.ts
cd /tmp/wallet-sdk-verify && npx tsx smoke-test.ts
```

Expected: prints `{"ok":true,"night":"<positive>"}` and exits 0.

If any step fails, the JSON output names the failing step. Reconcile against the source before proceeding.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/scripts/fixtures/smoke-test.ts
git commit -m "feat(midnight-wallet:sdk-regression-check): add smoke-test fixture"
```

### Task 3.4: Implement `smoke-test.sh`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Spin up a temp project with the LATEST published @midnight-ntwrk/wallet-sdk-*
# packages, then run the smoke-test fixture against the local devnet.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="${SCRIPT_DIR}/fixtures/smoke-test.ts"

if [[ ! -f "$FIXTURE" ]]; then
  echo "ERROR: smoke-test fixture missing at $FIXTURE" >&2
  exit 2
fi

if ! curl -fsS http://localhost:9944/health >/dev/null 2>&1; then
  echo "ERROR: local devnet node not reachable at http://localhost:9944/health" >&2
  echo "       Start the devnet with /midnight-tooling:devnet start" >&2
  exit 2
fi

WORKDIR="$(mktemp -d -t midnight-smoke-XXXXXX)"
trap 'rm -rf "$WORKDIR"' EXIT
echo "Working in $WORKDIR"

cd "$WORKDIR"
npm init -y >/dev/null
npm pkg set type=module

PACKAGES=(
  "@midnight-ntwrk/wallet-sdk"
  "@midnight-ntwrk/wallet-sdk-facade"
  "@midnight-ntwrk/wallet-sdk-hd"
  "@midnight-ntwrk/wallet-sdk-shielded"
  "@midnight-ntwrk/wallet-sdk-unshielded-wallet"
  "@midnight-ntwrk/wallet-sdk-dust-wallet"
  "@midnight-ntwrk/wallet-sdk-capabilities"
  "@midnight-ntwrk/wallet-sdk-abstractions"
  "@midnight-ntwrk/wallet-sdk-address-format"
  "@midnight-ntwrk/wallet-sdk-runtime"
  "@midnight-ntwrk/wallet-sdk-utilities"
  "@midnight-ntwrk/wallet-sdk-indexer-client"
  "@midnight-ntwrk/wallet-sdk-node-client"
  "@midnight-ntwrk/wallet-sdk-prover-client"
  "@midnight-ntwrk/ledger-v8"
  "ws"
  "rxjs"
)
echo "Installing latest packages…"
npm install --silent "${PACKAGES[@]}"
npm install --silent -D tsx typescript @types/node @types/ws

cp "$FIXTURE" "$WORKDIR/smoke-test.ts"

echo "Running smoke fixture…"
START=$(date +%s)
if npx tsx "$WORKDIR/smoke-test.ts"; then
  END=$(date +%s)
  echo "PASS — smoke test completed in $((END-START))s"
  exit 0
else
  END=$(date +%s)
  echo "FAIL — smoke test failed after $((END-START))s"
  exit 1
fi
```

- [ ] **Step 2: Make executable**

```bash
chmod +x plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh
```

- [ ] **Step 3: Run it against the live devnet**

```bash
plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh
```

Expected: ends with `PASS — smoke test completed in <N>s`. The full run typically takes 60-180 seconds.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh
git commit -m "feat(midnight-wallet:sdk-regression-check): add smoke-test.sh"
```

### Task 3.5: Write `references/interpreting-output.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/references/interpreting-output.md`

- [ ] **Step 1: Write the reference**

The full content is the drift-table reading guide from the spec. Reproduce it here as a standalone reference, with the lock-file policy at the top.

```markdown
# Interpreting drift-check.sh output

## Lock-file policy (read first)

`versions.lock.json` is owned by plugin maintainers. Claude must NOT
edit it as part of running the regression-check skill. When drift is
detected, Claude reports findings to the user and stops. Updates to the
lock file happen when the plugin is released, not when this skill runs.

## The output table

`drift-check.sh` prints one row per package with PINNED, LATEST, DRIFT
columns. DRIFT is one of `none`, `patch`, `minor`, `MAJOR`, or
`npm-error`.

## What to do per drift level

| Drift level | Meaning | What to do |
|-------------|---------|------------|
| `none` | No change since pin date | Trust the patterns |
| `patch` | Patch bump (no API change by SemVer) | Trust the patterns; mention the patch in the report so the user can decide whether to file a plugin-maintenance issue |
| `minor` | New features, no removed APIs | Read release notes for the affected package(s); spot-check the relevant example; report findings to the user — do not edit the lock |
| `MAJOR` | Breaking changes possible | Run `smoke-test.sh`. If smoke passes, the patterns still work; surface release-note highlights. If smoke fails, follow the drift workflow in `using-release-notes.md` |
| `npm-error` | npm could not resolve the package | Check network; check whether the package was renamed or deprecated; do not change the lock |

## When `smoke-test.sh` fails with no drift detected

The failure is environmental, not SDK drift. Check:

1. Is the devnet reachable? Run `curl -f http://localhost:9944/health`.
2. Is the proof server reachable? Run `curl -f http://localhost:6300`.
3. Is the indexer reachable? Run `curl -f http://localhost:8088/api/v3/graphql`.

Use `midnight-tooling:devnet health` for a structured check.

If the environment is fine but smoke still fails, the cause is most
likely a devnet image-version mismatch — the dev preset's pre-mint
contract may have changed across image versions. Report this to the
user; do not change the SDK skill content.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/references/interpreting-output.md
git commit -m "docs(midnight-wallet:sdk-regression-check): add interpreting-output reference"
```

### Task 3.6: Write `references/using-release-notes.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/references/using-release-notes.md`

- [ ] **Step 1: Write the reference**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/references/using-release-notes.md
git commit -m "docs(midnight-wallet:sdk-regression-check): add using-release-notes reference"
```

### Task 3.7: Write `references/temp-project-setup.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/references/temp-project-setup.md`

- [ ] **Step 1: Write the reference**

This documents the exact commands the user can run if they want to drive the smoke test manually (e.g., when `smoke-test.sh` fails for environmental reasons and they want to isolate the cause).

```markdown
# Manual temp-project setup

`smoke-test.sh` automates these steps. Use this manual flow only when
the script fails for environmental reasons and you want to drive each
step yourself.

## Prerequisites

- Node 20+
- A running local devnet — see `midnight-tooling:devnet`
- npm

## Steps

```bash
cd "$(mktemp -d)"
npm init -y
npm install \
  @midnight-ntwrk/wallet-sdk \
  @midnight-ntwrk/wallet-sdk-facade \
  @midnight-ntwrk/wallet-sdk-hd \
  @midnight-ntwrk/wallet-sdk-shielded \
  @midnight-ntwrk/wallet-sdk-unshielded-wallet \
  @midnight-ntwrk/wallet-sdk-dust-wallet \
  @midnight-ntwrk/wallet-sdk-capabilities \
  @midnight-ntwrk/wallet-sdk-abstractions \
  @midnight-ntwrk/wallet-sdk-address-format \
  @midnight-ntwrk/wallet-sdk-runtime \
  @midnight-ntwrk/wallet-sdk-utilities \
  @midnight-ntwrk/wallet-sdk-indexer-client \
  @midnight-ntwrk/wallet-sdk-node-client \
  @midnight-ntwrk/wallet-sdk-prover-client \
  @midnight-ntwrk/ledger-v8 \
  ws \
  rxjs
npm install -D tsx typescript @types/node @types/ws

# Copy the fixture from the skill into this temp dir
cp <plugin>/sdk-regression-check/scripts/fixtures/smoke-test.ts ./smoke-test.ts

# Run it
npx tsx ./smoke-test.ts
```

## Expected output

On success, `smoke-test.ts` prints a single line of JSON like
`{"ok":true,"night":"<positive>"}` and exits 0.

On failure, it prints `{"ok":false,"step":"<step>","error":"<message>"}`
and exits 1. The `step` value tells you where to look:

| step | What it means |
|------|--------------|
| `hd-derive` | `HDWallet.fromSeed` or `deriveKeysAt` failed |
| `key-convert` | `ZswapSecretKeys.fromSeed`, `DustSecretKey.fromSeed`, or `createKeystore` failed |
| `facade-init` | `WalletFacade.init` failed (factory function or configuration issue) |
| `wallet-start` | `wallet.start()` failed |
| `wait-sync` | `wallet.waitForSyncedState()` failed (devnet, indexer, or proof-server unreachable) |
| `balance-read` | Wallet synced but unshielded NIGHT balance was 0 — usually a `dev`-preset or genesis-seed issue |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/references/temp-project-setup.md
git commit -m "docs(midnight-wallet:sdk-regression-check): add temp-project-setup reference"
```

### Task 3.8: Write `references/smoke-test-anatomy.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/references/smoke-test-anatomy.md`

- [ ] **Step 1: Write the reference**

```markdown
# Smoke test anatomy

The smoke fixture executes the wallet construction pattern this plugin
documents and asserts that the local-devnet `dev` preset still pre-mints
NIGHT to the genesis seed.

## Steps the fixture performs

1. **HD derivation (`hd-derive`).** Build an HD wallet from the local-devnet
   genesis seed (`0x000…001`). Select account 0 and roles `Zswap`,
   `NightExternal`, `Dust`. Derive keys at index 0. Clear the HD wallet
   from memory.

2. **Key conversion (`key-convert`).** Convert the three derived byte
   arrays into typed keys:
   - `ZswapSecretKeys.fromSeed(...)` for shielded
   - `createKeystore(...)` for unshielded
   - `DustSecretKey.fromSeed(...)` for dust

3. **Facade init (`facade-init`).** Call `WalletFacade.init({ ... })`
   with a `DefaultConfiguration` pointing at the local devnet
   (`ws://localhost:9944`, `http://localhost:8088/api/v3/graphql`,
   `http://localhost:6300`) and factory functions for each sub-wallet.

4. **Wallet start (`wallet-start`).** Call `wallet.start(shieldedSecretKeys, dustSecretKey)`.

5. **Wait for sync (`wait-sync`).** Call `wallet.waitForSyncedState()`.

6. **Balance assertion (`balance-read`).** Read
   `state.unshielded.balances[ledger.nativeToken().raw]` and assert it is greater than `0n`.

## What success means

If all six steps pass, the construction pattern in this plugin still
works end-to-end against the live devnet. The patterns documented in
`midnight-wallet:wallet-sdk` and `midnight-wallet:managing-test-wallets`
are validated.

## What failure means

A failure at any step is structured: the fixture prints
`{"ok":false,"step":"<step>","error":"<message>"}`. The step name
points at the layer to investigate first. See `temp-project-setup.md`
for the per-step interpretation.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/references/smoke-test-anatomy.md
git commit -m "docs(midnight-wallet:sdk-regression-check): add smoke-test-anatomy reference"
```

### Task 3.9: Write the skill's `SKILL.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/sdk-regression-check/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`**

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/sdk-regression-check/SKILL.md
git commit -m "feat(midnight-wallet:sdk-regression-check): add SKILL.md"
```

### Task 3.10: End-to-end verify the regression-check skill

- [ ] **Step 1: Run drift-check from a fresh shell**

```bash
plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh
```

Expected: exits 0, prints a clean table.

- [ ] **Step 2: Run smoke-test against the live devnet**

```bash
plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh
```

Expected: exits 0, prints `PASS — smoke test completed in <N>s`.

- [ ] **Step 3: Force-fail the smoke test to confirm error output is clean**

Temporarily edit the fixture in `/tmp/wallet-sdk-verify/smoke-test.ts` to use a wrong seed:
```typescript
const GENESIS_SEED_HEX = "ffff...ffff";
```
Run `npx tsx smoke-test.ts`. Expected: `{"ok":false,"step":"balance-read","error":"Expected NIGHT > 0, got 0"}` and exit 1. Revert the change.

- [ ] **Step 4:** No commit needed; this is verification.

---

## Phase 4 — Build the `managing-test-wallets` skill

Each example script is built and verified before the corresponding reference is written. This forces every reference to be grounded in observed runtime behavior, not in inferred API.

### Task 4.1: Create the skill directory tree

**Files:**
- Create: directory `plugins/midnight-wallet/skills/managing-test-wallets/{references,examples}`

- [ ] **Step 1: Make the dirs**

```bash
mkdir -p plugins/midnight-wallet/skills/managing-test-wallets/{references,examples}
```

- [ ] **Step 2:** No commit; the dirs are created when the first file in each is committed.

### Task 4.2: Build and verify `examples/create-wallet.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/create-wallet.ts`

- [ ] **Step 1: Write the script**

The script takes either no args (random seed), `--seed <64 hex chars>`, or `--mnemonic "<24 words>"`. It builds a `WalletFacade`, prints the unshielded, shielded, and dust addresses, then exits.

The header opens with the verified-against block:
```typescript
// Verified against the package versions pinned in
// midnight-wallet:sdk-regression-check/versions.lock.json on <today>.
// If your installed @midnight-ntwrk/wallet-sdk-* versions differ,
// run scripts/drift-check.sh in that skill before trusting this template.
```

The body imports from `@midnight-ntwrk/wallet-sdk-hd` (`HDWallet`, `Roles`, `generateRandomSeed`, `mnemonicToWords`, `validateMnemonic`), from `@scure/bip39` (`mnemonicToSeedSync`), and constructs the wallet via `WalletFacade.init` exactly as in the smoke-test fixture. After `waitForSyncedState`, it logs:

```
Unshielded: <bech32 address>
Shielded:   <bech32 address>
Dust:       <bech32 address>
```

Then calls `wallet.stop()` and exits 0.

Implementation note: the implementor lifts the construction skeleton from the smoke-test fixture and adds CLI argument parsing. The implementor must verify the public API for the address fields against the SDK source: `state.unshielded.address`, `state.shielded.address`, `state.dust.address`. If the SDK exposes them as Bech32m objects, call `.asString()` (verify the method name from `address-format/src/`).

- [ ] **Step 2: Place a copy in `/tmp/wallet-sdk-verify/` and run all three modes**

```bash
cp plugins/midnight-wallet/skills/managing-test-wallets/examples/create-wallet.ts /tmp/wallet-sdk-verify/
cd /tmp/wallet-sdk-verify
npx tsx create-wallet.ts
npx tsx create-wallet.ts --seed 0000000000000000000000000000000000000000000000000000000000000001
MNEMONIC="$(node -e 'const {generateMnemonicWords, joinMnemonicWords} = require("@midnight-ntwrk/wallet-sdk-hd"); console.log(joinMnemonicWords(generateMnemonicWords()))')"
npx tsx create-wallet.ts --mnemonic "$MNEMONIC"
```

Expected: each invocation prints three address lines starting with `mn_addr_undeployed1`, `mn_shield-addr_undeployed1`, and `mn_dust_undeployed1` (or whatever the verified prefixes are — confirm against `address-format`'s source).

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/create-wallet.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add create-wallet example"
```

### Task 4.3: Build and verify `examples/fund-wallet-undeployed.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-undeployed.ts`

- [ ] **Step 1: Write the script**

The script takes a recipient unshielded address as the first positional arg. It:
1. Builds a sender `WalletFacade` from the local-devnet genesis seed (constant `0x000…001`, with a comment cross-referencing `midnight-tooling:devnet#genesis-seed`).
2. Awaits `waitForSyncedState()`.
3. Builds an unshielded NIGHT transfer recipe via `wallet.transferTransaction` with output:
   ```ts
   { type: 'unshielded', outputs: [{ type: 'NIGHT', receiverAddress: <recipient>, amount: 5_000_000n }] }
   ```
4. Signs, finalizes, submits.
5. Polls until the recipient address shows non-zero NIGHT (build a second `WalletFacade` only with the recipient's address for monitoring — or document a polling pattern via the indexer if simpler; verify the SDK exposes a "watch this address from outside" API or fall back to building a recipient facade if the user holds the keys).

The implementor must verify against the SDK: how `transferTransaction`'s `secretKeys` parameter is shaped (what the smoke-test confirmed for facade init), the exact shape of the output object, and how to decode the recipient's bech32 string into a `UnshieldedAddress` for the `receiverAddress` field. The `transactions.md` reference in `wallet-sdk` already documents this — the implementor reads it and adapts.

- [ ] **Step 2: Run end-to-end against devnet**

```bash
# Generate a recipient first
cd /tmp/wallet-sdk-verify && npx tsx create-wallet.ts > /tmp/recipient.txt
RECIPIENT_UNSHIELDED="$(grep '^Unshielded:' /tmp/recipient.txt | awk '{print $2}')"
# Run the funding script
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-undeployed.ts ./
npx tsx fund-wallet-undeployed.ts "$RECIPIENT_UNSHIELDED"
```

Expected: prints a transaction identifier; the script polls and eventually prints something like `Recipient unshielded balance: 5000000` and exits 0. End-to-end runtime is typically 30-90 seconds.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-undeployed.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add fund-wallet-undeployed example"
```

### Task 4.4: Build and verify `examples/register-dust.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/register-dust.ts`

- [ ] **Step 1: Write the script**

The script takes a wallet seed (hex) as the first arg, builds a `WalletFacade` for that wallet, awaits sync, gets `state.unshielded.availableCoins` (verify field name from source), calls `wallet.estimateRegistration(nightUtxos)` and prints the fee preview, then calls `wallet.registerNightUtxosForDustGeneration(...)` (verify the exact signature from `transactions.md` and from source). Sign, finalize, submit. Poll until `state.dust.balance(new Date()) > 0n` or a timeout fires.

- [ ] **Step 2: Run end-to-end**

Use the wallet you funded in Task 4.3 (its seed is `RECIPIENT_SEED`, which `create-wallet.ts` should print or which the implementor captures by running create-wallet with `--seed <known>` from the start).

```bash
cd /tmp/wallet-sdk-verify
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/register-dust.ts ./
npx tsx register-dust.ts "$RECIPIENT_SEED_HEX"
```

Expected: prints fee estimate, transaction id, then `DUST balance: <positive>` and exits 0.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/register-dust.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add register-dust example"
```

### Task 4.5: Build and verify `examples/monitor-wallet.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/monitor-wallet.ts`

- [ ] **Step 1: Write the script**

The script takes a seed and prints a live ticker. On every `wallet.state()` emission (RxJS `subscribe`), print:

```
[<ISO timestamp>] sync=<bool> NIGHT=<bigint> SHIELDED={<token>: <amount>...} DUST=<bigint>
```

Add a SIGINT handler that calls `wallet.stop()` and exits 0.

- [ ] **Step 2: Run end-to-end**

```bash
cd /tmp/wallet-sdk-verify
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/monitor-wallet.ts ./
timeout 30 npx tsx monitor-wallet.ts "$RECIPIENT_SEED_HEX" || true
```

Expected: at least 2-3 ticker lines emitted in 30 seconds; sync transitions from `false` to `true`; balances appear once synced.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/monitor-wallet.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add monitor-wallet example"
```

### Task 4.6: Build and verify `examples/transfer-night.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-night.ts`

- [ ] **Step 1: Write the script**

Args: `<sender-seed-hex> <recipient-unshielded-address> <amount-bigint>`.

Build a sender facade, await sync, build a transfer recipe via `wallet.transferTransaction`, sign, finalize, submit, print the transaction identifier, exit 0.

- [ ] **Step 2: Run end-to-end**

Create a second recipient first:
```bash
cd /tmp/wallet-sdk-verify
npx tsx create-wallet.ts --seed 0000000000000000000000000000000000000000000000000000000000000002 > /tmp/recipient2.txt
RECIPIENT2_UNSHIELDED="$(grep '^Unshielded:' /tmp/recipient2.txt | awk '{print $2}')"
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-night.ts ./
npx tsx transfer-night.ts "$RECIPIENT_SEED_HEX" "$RECIPIENT2_UNSHIELDED" 1000000
```

Expected: prints a transaction identifier, exits 0. Optionally use `monitor-wallet.ts` against `RECIPIENT2_SEED` to confirm balance arrives.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-night.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add transfer-night example"
```

### Task 4.7: Build and verify `examples/transfer-shielded.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-shielded.ts`

- [ ] **Step 1: Write the script**

Same shape as `transfer-night.ts` but the output uses `type: 'shielded'` and the recipient address is a `ShieldedAddress` (decoded from the recipient's `Shielded:` line printed by `create-wallet.ts`).

- [ ] **Step 2: Verify shielded transfer feasibility on devnet**

Shielded transfers require the sender to hold shielded tokens. The genesis pre-mint is unshielded NIGHT. To test a shielded transfer end-to-end, the implementor needs to either:

(a) First convert some unshielded NIGHT into shielded NIGHT (a swap intent — see SDK source for `initSwap`), then transfer the shielded; or
(b) Document the example as one that requires shielded balance and exit cleanly with a helpful message if `state.shielded.balances` is empty.

Pick (b) for the example: if the sender has no shielded balance, print
```
Sender has no shielded tokens. To use this example you need shielded balance.
See SDK reference for `wallet.initSwap` to convert unshielded to shielded.
```
and exit 0.

This keeps the example runnable without requiring a more complex multi-step setup.

- [ ] **Step 3: Run the script with a sender who has no shielded balance**

```bash
cd /tmp/wallet-sdk-verify
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-shielded.ts ./
npx tsx transfer-shielded.ts "$RECIPIENT_SEED_HEX" "$RECIPIENT2_SHIELDED" 100000
```

Expected: prints the helpful message about needing shielded balance and exits 0. (If the implementor chooses path (a), expected is a transaction id and exit 0.)

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/transfer-shielded.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add transfer-shielded example"
```

### Task 4.8: Build and verify `examples/fund-wallet-public-faucet.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-public-faucet.ts`

- [ ] **Step 1: Write the script**

Args: `<recipient-unshielded-address> <network: preprod|preview>`.

The script:
1. Validates the network arg.
2. Prints:
   ```
   To fund this wallet, paste the address into the <network> faucet:
     Address: <recipient>
     Faucet:  https://faucet.<network>.midnight.network/
   Watching for incoming NIGHT...
   ```
3. Builds a `WalletFacade` configured for the chosen network (the implementor consults `network-config.md` — but this reference doesn't exist yet, so for now the implementor reads the SDK source and the existing `wallet-sdk:infrastructure-clients.md` for the right RPC/indexer URLs per network). Note: the recipient must be the wallet whose seed is being driven by the script — i.e., the user is monitoring their own wallet.
4. Subscribes to wallet state, polls until balance is non-zero or 5-minute timeout fires.

If the script's only role is to PRINT THE URL AND WATCH, it doesn't need to be the recipient — it can subscribe to the indexer for the recipient address directly. Verify whether the SDK exposes a watch-by-address API; if not, the script needs the seed (rename arg accordingly) and builds a facade for that seed.

- [ ] **Step 2: Manual verification**

End-to-end runtime verification of this script requires using a real faucet, which involves a human pasting the address. Document this verification step and execute it manually:

1. Run: `npx tsx fund-wallet-public-faucet.ts "$RECIPIENT_UNSHIELDED" preprod`
2. Manually paste `$RECIPIENT_UNSHIELDED` into the preprod faucet web page
3. Wait. Confirm the script prints "Balance arrived: <bigint>" within the timeout.

If a real preprod faucet visit is not feasible during implementation, instead run a partial verification: confirm the script prints the correct URL and address, then SIGINT the process and confirm clean exit. Record this in the commit message ("verified URL output; full faucet round-trip not exercised").

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/fund-wallet-public-faucet.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add fund-wallet-public-faucet example"
```

### Task 4.9: Build and verify `examples/full-test-wallet-setup.ts`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/examples/full-test-wallet-setup.ts`

- [ ] **Step 1: Write the script**

Args: `<network: undeployed|preprod|preview>` (default `undeployed`).

The script orchestrates the simpler examples in sequence. It does not import them — it inlines the steps so the script is self-contained:

1. Generate a fresh wallet (random seed), print all three addresses.
2. If network is `undeployed`: build a sender from the genesis seed, transfer 5 NIGHT to the new wallet's unshielded address, wait for the new wallet to observe the balance.
3. If network is `preprod`/`preview`: print the faucet URL, wait for incoming balance.
4. Once funded, register DUST.
5. Print a final summary: addresses, NIGHT balance, DUST balance.

- [ ] **Step 2: Run end-to-end on undeployed**

```bash
cd /tmp/wallet-sdk-verify
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/full-test-wallet-setup.ts ./
npx tsx full-test-wallet-setup.ts undeployed
```

Expected: prints addresses, then progress lines for funding and DUST registration, then a final summary with positive NIGHT and DUST balances. Exits 0. Total runtime typically 90-180 seconds.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/examples/full-test-wallet-setup.ts
git commit -m "feat(midnight-wallet:managing-test-wallets): add full-test-wallet-setup example"
```

### Task 4.10: Write `references/addresses-and-tokens.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/addresses-and-tokens.md`

- [ ] **Step 1: Write the reference**

```markdown
# Addresses and tokens

A `WalletFacade` owns three sub-wallets, each with its own address type
and balance shape.

| Sub-wallet | Address kind | What it holds |
|------------|--------------|---------------|
| `UnshieldedWallet` | `UnshieldedAddress` (`mn_addr_*`) | NIGHT (the native unshielded token) |
| `ShieldedWallet`   | `ShieldedAddress`   | Shielded tokens (privacy-preserving, ZK) |
| `DustWallet`       | `DustAddress`       | DUST (fee resource, time-generated from registered NIGHT UTXOs) |

## Which address goes where

| Operation | Address |
|-----------|---------|
| Faucet (preprod, preview) | UNSHIELDED only |
| Local-devnet genesis-seed airdrop | UNSHIELDED only |
| Receiving a shielded transfer | SHIELDED |
| DUST receive (rare — DUST is normally generated, not transferred) | DUST |

## The most common mistake

Pasting a shielded address into a faucet. Faucets fund NIGHT, which lives
in the unshielded wallet. The unshielded address starts with `mn_addr_*`
followed by the network identifier. Always use that one for funding.

## Balances

- **Unshielded:** `state.unshielded.balances[ledger.nativeToken().raw]` — NIGHT balance as a `bigint`. The key is the native token's raw bytes (64 hex zeros), NOT the empty string. 6 decimal places: `1_000_000n` = 1 NIGHT.
- **Shielded:** `state.shielded.balances[token]` — bigint per token kind.
- **DUST:** `state.dust.balance(new Date())` — function call (DUST has expiry).

See `wallet-sdk:references/state-and-balances.md` for the full balance API.
```

- [ ] **Step 2: Verify each claim**

Spot-check by running `monitor-wallet.ts` and observing actual values for each balance shape. Confirm `mn_addr_*` is what `create-wallet.ts` prints. If the prefix differs from the verified output, update the reference.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/addresses-and-tokens.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add addresses-and-tokens reference"
```

### Task 4.11: Write `references/wallet-creation.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/wallet-creation.md`

- [ ] **Step 1: Write the reference**

The reference describes:
1. Three seed sources: random (`generateRandomSeed`), BIP-39 mnemonic (`generateMnemonicWords` + `mnemonicToSeedSync`), hex string (`Buffer.from(hex, 'hex')`).
2. HD derivation: `HDWallet.fromSeed → selectAccount(0) → selectRoles([Zswap, NightExternal, Dust]) → deriveKeysAt(0)`.
3. Key conversion: `ZswapSecretKeys.fromSeed`, `createKeystore`, `DustSecretKey.fromSeed`.
4. `WalletFacade.init` with the three factory functions.
5. `wallet.start(shieldedSecretKeys, dustSecretKey)`.
6. `wallet.waitForSyncedState()`.
7. Memory hygiene: `hdWallet.clear()`.

Cross-link to `examples/create-wallet.ts` for runnable code, and to `wallet-sdk:references/wallet-construction.md` for the exhaustive API reference.

- [ ] **Step 2: Verify by running create-wallet.ts**

```bash
cd /tmp/wallet-sdk-verify
npx tsx create-wallet.ts
```

Confirm the script's flow matches the reference's described order. If not, fix the reference.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/wallet-creation.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add wallet-creation reference"
```

### Task 4.12: Write `references/funding.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/funding.md`

- [ ] **Step 1: Write the reference**

```markdown
# Funding test wallets

Funding strategy depends on the active network.

## Local devnet (`undeployed`)

The `dev` preset pre-mints NIGHT to the wallet derived from the genesis
seed. To fund a new wallet:

1. Build a sender `WalletFacade` from the genesis seed (see
   `midnight-tooling:devnet#genesis-seed` for the seed value and why it
   works).
2. Wait for the sender to sync.
3. Submit an unshielded NIGHT transfer to the recipient's UNSHIELDED
   address.
4. Wait for the recipient to observe the incoming balance.

See `examples/fund-wallet-undeployed.ts` for the runnable script.

## Public testnets (`preprod`, `preview`)

There is no programmatic faucet API for the public testnets — the user
funds the address manually via the faucet web page.

| Network | Faucet URL |
|---------|------------|
| preprod | https://faucet.preprod.midnight.network/ |
| preview | https://faucet.preview.midnight.network/ |

The funding pattern is "print the address and the URL, watch for the
balance to arrive":

1. Print the recipient's UNSHIELDED address and the faucet URL.
2. Subscribe to wallet state.
3. Poll until the unshielded NIGHT balance becomes non-zero, or a
   timeout fires.

See `examples/fund-wallet-public-faucet.ts` for the runnable script.

## Address rules

Faucets and the genesis-seed airdrop fund the UNSHIELDED address.
Shielded tokens are minted via Zswap (`wallet.initSwap`), not via
faucets. See `addresses-and-tokens.md`.
```

- [ ] **Step 2: Verify URLs are reachable**

```bash
curl -I https://faucet.preprod.midnight.network/ 2>&1 | head -1
curl -I https://faucet.preview.midnight.network/ 2>&1 | head -1
```

Expected: HTTP 200 or 3xx for both. If a 404 or DNS failure, update the reference with the corrected URL.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/funding.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add funding reference"
```

### Task 4.13: Write `references/dust-registration.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/dust-registration.md`

- [ ] **Step 1: Write the reference**

```markdown
# DUST registration

DUST is the fee resource on Midnight. It is generated over time from
NIGHT UTXOs that have been REGISTERED for DUST generation. Without
registered NIGHT, a wallet cannot pay transaction fees.

## When to register

Immediately after the wallet receives its first NIGHT. The UTXOs only
start generating DUST once registered, so the sooner the better.

## How to register

1. Build a `WalletFacade` for the wallet whose UTXOs you are registering.
2. Wait for sync.
3. Get `state.unshielded.availableCoins` (or whatever field name the
   verified SDK exposes — verify against
   `wallet-sdk:references/state-and-balances.md` and the source).
4. (Optional, recommended) Call `wallet.estimateRegistration(nightUtxos)`
   to preview the fee and per-UTXO yield.
5. Call `wallet.registerNightUtxosForDustGeneration(nightUtxos, ...)` —
   verify the full signature in
   `wallet-sdk:references/transactions.md`.
6. Sign, finalize, submit.
7. Wait. DUST appears over time; `state.dust.balance(new Date())` will
   eventually return a non-zero `bigint`.

## DUST has expiry

DUST tokens expire. `state.dust.balance(time)` requires a `Date`
argument because the result depends on which DUST has not yet expired
at the queried time.

See `examples/register-dust.ts` for the runnable script.
```

- [ ] **Step 2: Verify field names by inspecting `state.unshielded` from monitor-wallet.ts output**

If `availableCoins` is not the verified field name, update the reference with the correct field. Same for `wallet.estimateRegistration` and `wallet.registerNightUtxosForDustGeneration` — verify each via Phase 4.4.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/dust-registration.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add dust-registration reference"
```

### Task 4.14: Write `references/balance-monitoring.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/balance-monitoring.md`

- [ ] **Step 1: Write the reference**

```markdown
# Balance monitoring

`wallet.state()` returns an `Observable<FacadeState>`. Every state
change emits a new value.

## Reading balances safely

Do not read balances before the wallet is synced. `FacadeState.isSynced`
is true only when all three sub-wallets report strictly complete sync.

```typescript
const sub = wallet.state().subscribe((state) => {
  if (!state.isSynced) return;
  const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;
  console.log("NIGHT:", state.unshielded.balances[NIGHT_TOKEN_TYPE] ?? 0n);
  console.log("DUST:", state.dust.balance(new Date()));
});
```

For one-shot patterns, prefer `wallet.waitForSyncedState()` which
returns a single `FacadeState` once synced.

## What to watch

| Field | Observe | Why |
|-------|---------|-----|
| `state.isSynced` | Yes — guard balance reads | Until synced, balances are incomplete |
| `state.unshielded.balances[ledger.nativeToken().raw]` | NIGHT balance, `bigint` | The unshielded NIGHT total. The native token key is 64 hex zeros, NOT `""`. |
| `state.shielded.balances[<tokenId>]` | Per-token shielded balance | Shielded tokens are keyed by token kind |
| `state.dust.balance(new Date())` | DUST `bigint` | Time-dependent; pass current time |
| `state.unshielded.progress` | `SyncProgress` | For diagnostics when sync stalls |

## Cleaning up

Always unsubscribe and `wallet.stop()` when monitoring ends:

```typescript
sub.unsubscribe();
await wallet.stop();
```

See `examples/monitor-wallet.ts` for the runnable script. See
`wallet-sdk:references/state-and-balances.md` for the full state API.
```

- [ ] **Step 2: Verify by running monitor-wallet.ts and observing the actual emitted state shape**

Capture a sample emission JSON from `monitor-wallet.ts` (with `JSON.stringify(state)` — beware bigints) and confirm the field names match the reference. If not, update.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/balance-monitoring.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add balance-monitoring reference"
```

### Task 4.15: Write `references/transfers.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/transfers.md`

- [ ] **Step 1: Write the reference**

The reference describes the three transfer kinds and links each to its example. Pulls heavily from `wallet-sdk:references/transactions.md` but stays focused on the practical "how to send tokens" question.

Cover:
- Unshielded NIGHT via `transferTransaction` with `type: 'unshielded'`
- Shielded via `type: 'shielded'`
- Combined (atomic shielded + unshielded) by passing both
- Recipe → sign → finalize → submit lifecycle
- The `payFees` option default and override
- Fee estimation via `estimateTransactionFee`

Cross-link `examples/transfer-night.ts` and `examples/transfer-shielded.ts`.

- [ ] **Step 2: Verify all signatures by running both transfer examples**

The signatures used in the examples (verified end-to-end in Tasks 4.6 and 4.7) are the source of truth. Quote them in the reference.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/transfers.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add transfers reference"
```

### Task 4.16: Write `references/network-config.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/network-config.md`

- [ ] **Step 1: Write the reference**

```markdown
# Network configuration

`DefaultConfiguration` is the configuration object passed to
`WalletFacade.init`. The shape is the same across networks; only the
URLs and the `networkId` change.

## Per-network endpoints

### `undeployed` (local devnet)

```typescript
const configuration: DefaultConfiguration = {
  networkId: 'undeployed',
  costParameters: { feeBlocksMargin: 5 },
  relayURL: new URL('ws://localhost:9944'),
  provingServerUrl: new URL('http://localhost:6300'),
  indexerClientConnection: {
    indexerHttpUrl: 'http://localhost:8088/api/v3/graphql',
    indexerWsUrl: 'ws://localhost:8088/api/v3/graphql/ws',
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
};
```

### `preprod`

```typescript
const configuration: DefaultConfiguration = {
  networkId: 'preprod',
  costParameters: { feeBlocksMargin: 5 },
  relayURL: new URL('wss://rpc.preprod.midnight.network'),
  provingServerUrl: new URL('http://localhost:6300'),  // proof server runs locally
  indexerClientConnection: {
    indexerHttpUrl: 'https://indexer.preprod.midnight.network/api/v3/graphql',
    indexerWsUrl: 'wss://indexer.preprod.midnight.network/api/v3/graphql/ws',
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
};
```

### `preview`

```typescript
const configuration: DefaultConfiguration = {
  networkId: 'preview',
  costParameters: { feeBlocksMargin: 5 },
  relayURL: new URL('wss://rpc.preview.midnight.network'),
  provingServerUrl: new URL('http://localhost:6300'),
  indexerClientConnection: {
    indexerHttpUrl: 'https://indexer.preview.midnight.network/api/v3/graphql',
    indexerWsUrl: 'wss://indexer.preview.midnight.network/api/v3/graphql/ws',
  },
  txHistoryStorage: new InMemoryTransactionHistoryStorage(WalletEntrySchema),
};
```

## Node WebSocket polyfill

Node 20 lacks a global `WebSocket`; the SDK requires one for indexer
subscriptions. Add the polyfill at the top of any Node script:

```typescript
import WebSocket from 'ws';
(globalThis as any).WebSocket = WebSocket;
```

This is unnecessary in browsers.

## Network ID setter (DApp SDK)

If your project also uses `@midnight-ntwrk/midnight-js-network-id`, call
`setNetworkId(networkId)` once at startup so the DApp SDK's helpers know
which network they are operating against.
```

- [ ] **Step 2: Verify each URL responds**

```bash
curl -I https://indexer.preprod.midnight.network/api/v3/graphql 2>&1 | head -1
curl -I https://indexer.preview.midnight.network/api/v3/graphql 2>&1 | head -1
curl -I https://rpc.preprod.midnight.network 2>&1 | head -1
curl -I https://rpc.preview.midnight.network 2>&1 | head -1
```

Expected: HTTP 200 or upgrade-required for the websocket-style URLs. If a 404, the URL is wrong — fix the reference. (Note: the local devnet URLs were verified in Phase 0.)

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/network-config.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add network-config reference"
```

### Task 4.17: Write `references/troubleshooting.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/references/troubleshooting.md`

- [ ] **Step 1: Write the reference**

```markdown
# Troubleshooting

| Symptom | Likely cause | First fix |
|---------|--------------|-----------|
| `STALE_UTXO` error on transfer | Concurrent spend used the same UTXO | Wait a few seconds, retry |
| `DUST_REQUIRED` error | Wallet has no DUST to pay fees | Run `examples/register-dust.ts`, wait for DUST to accrue |
| Sync never completes | Indexer or node unreachable | `midnight-tooling:devnet health`; check container status |
| `WebSocket is not defined` (Node) | Missing `ws` polyfill | Add the polyfill at the top of the script (see `network-config.md`) |
| `0` balance after faucet visit | Pasted shielded address into faucet | Use the UNSHIELDED address (`mn_addr_*`) |
| `WalletFacade.init` throws | Configuration shape mismatch or service unreachable | Verify each URL with `curl`; verify config matches `network-config.md` |
| Transaction submission rejected | Major SDK version drift, or ledger/protocol mismatch | Run `midnight-wallet:sdk-regression-check` (smoke test); see release notes |
| Type errors after `npm install` | Major SDK version bump | Run `midnight-wallet:sdk-regression-check` (drift check) |
| Recipient never observes incoming NIGHT | Wrong recipient address; or wallet still syncing | Confirm address is unshielded; allow 30-90 seconds on devnet |

## When in doubt

Run `midnight-wallet:sdk-regression-check` first. It distinguishes
between "the SDK changed" and "your environment is broken" in under a
minute.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/references/troubleshooting.md
git commit -m "docs(midnight-wallet:managing-test-wallets): add troubleshooting reference"
```

### Task 4.18: Write the skill's `SKILL.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/managing-test-wallets/SKILL.md`

- [ ] **Step 1: Write `SKILL.md`**

```markdown
---
name: midnight-wallet:managing-test-wallets
description: >-
  This skill should be used when the user asks to create a test wallet,
  fund a wallet, get tNight from a faucet, register DUST, monitor wallet
  balance, transfer NIGHT or shielded tokens, derive a wallet from a seed
  or BIP-39 mnemonic, set up wallets for tests, watch an address for
  incoming funds, generate dust, fund their DApp's test fixtures, or run
  end-to-end test scenarios that need real wallets on the local devnet
  or a public testnet.
---

# Managing Test Wallets

SDK-driven patterns for creating, funding, and managing Midnight test
wallets. Network-aware (`undeployed` / `preprod` / `preview`).

## Critical caveat — verify SDK is current

Every pattern here was verified against the package versions pinned in
`midnight-wallet:sdk-regression-check/versions.lock.json`. The Midnight
Network ecosystem moves quickly, and there may be breaking changes
between SDK versions.

Before using any pattern from this skill, run
`midnight-wallet:sdk-regression-check` (drift check). If a major
version has shifted, run the smoke test before trusting the patterns.

## Scope — browser wallets are out of scope

Browser wallets (Lace and other extensions) are out of scope for this
skill. This skill teaches programmatic wallet patterns where the script
owns the keys directly. If the user is integrating their DApp with a
browser extension wallet, load `midnight-dapp-dev:dapp-connector`
instead. The two skills are complementary: a DApp typically uses the
extension wallet in production and uses the patterns in this skill for
development and test wallets.

## When to use this skill

| Scenario | Pattern |
|----------|---------|
| Wiring wallet setup into an example DApp's startup or tests | Lift the relevant `examples/*.ts` block, adapt to the host project's config and pin SDK versions in its `package.json` |
| One-off: user asks for a funded test wallet, balance check, transfer, etc. | Write a throwaway script in `/tmp/` or the project's `scripts/`, run with `npx tsx`, report results |

## Read this first — three-address model

A `WalletFacade` owns three sub-wallets, each with its own address and
balance. Faucets and the genesis-seed airdrop fund the UNSHIELDED
address only. See `references/addresses-and-tokens.md`.

## Decision tree

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

## References

| Reference | Topic |
|-----------|-------|
| `references/addresses-and-tokens.md` | Three-address model |
| `references/wallet-creation.md` | Seed sources, HD derivation, construction |
| `references/funding.md` | Per-network funding strategy |
| `references/dust-registration.md` | DUST mechanics + registration |
| `references/balance-monitoring.md` | State subscription patterns |
| `references/transfers.md` | Three transfer kinds |
| `references/network-config.md` | DefaultConfiguration per network |
| `references/troubleshooting.md` | Common symptoms |

## Examples

| Example | Demonstrates |
|---------|--------------|
| `examples/create-wallet.ts` | Wallet construction (random, mnemonic, hex seed) |
| `examples/fund-wallet-undeployed.ts` | Genesis-seed airdrop on local devnet |
| `examples/fund-wallet-public-faucet.ts` | Print-and-wait pattern for testnets |
| `examples/register-dust.ts` | DUST registration |
| `examples/monitor-wallet.ts` | Live balance ticker |
| `examples/transfer-night.ts` | Unshielded NIGHT transfer |
| `examples/transfer-shielded.ts` | Shielded transfer |
| `examples/full-test-wallet-setup.ts` | End-to-end |

## Related skills

| Need | Skill |
|------|-------|
| Wallet SDK package reference | `midnight-wallet:wallet-sdk` |
| SDK drift detection / smoke test | `midnight-wallet:sdk-regression-check` |
| Local devnet management | `midnight-tooling:devnet` |
| Genesis seed for local devnet | `midnight-tooling:devnet#genesis-seed` |
| Browser wallet (Lace) integration | `midnight-dapp-dev:dapp-connector` |
| DApp SDK provider wiring | `midnight-dapp-dev:midnight-sdk` |
| Testing wallet SDK code | `midnight-cq:wallet-testing` |
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/managing-test-wallets/SKILL.md
git commit -m "feat(midnight-wallet:managing-test-wallets): add SKILL.md"
```

### Task 4.19: End-to-end re-verification of all examples

After all examples and references exist, re-run the full happy path against a clean devnet to confirm everything still works as a coherent unit (no example accidentally broke another).

- [ ] **Step 1: Restart devnet to a clean state**

```bash
/midnight-tooling:devnet restart
/midnight-tooling:devnet health
```

- [ ] **Step 2: Run full-test-wallet-setup against undeployed**

```bash
cd /tmp/wallet-sdk-verify
cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/full-test-wallet-setup.ts ./
npx tsx full-test-wallet-setup.ts undeployed
```

Expected: prints addresses, funding progress, DUST progress, and a final summary with positive NIGHT and DUST balances. Exits 0.

- [ ] **Step 3:** No commit; this is verification.

---

## Phase 5 — Update the `wallet-sdk` skill (audit-driven)

### Task 5.1: Reconcile Phase 0 findings into the wallet-sdk skill

**Files:**
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md`
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md`
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md`

Phase 0 surfaced three documented claims that disagree with source/runtime:

1. `TransactionHistoryStorage.getAll()` — current skill says `AsyncIterableIterator<T>`; source says `Promise<readonly T[]>` (verified in `/tmp/wallet-sdk-verify/notes/transaction-history-storage.md`).
2. `wallet.getAllFromTxHistory()` — current skill says `AsyncIterableIterator<WalletEntry>`; source says `Promise<WalletEntry[]>`. The `for await` example needs to become a plain `for...of`.
3. The native NIGHT token key — current skill says `state.unshielded.balances[""]`; runtime confirms the correct key is `ledger.nativeToken().raw` (a 64-zero hex string). The `""` claim returns `undefined` and is wrong. Verified in `/tmp/wallet-sdk-verify/check-genesis.ts` runtime output.

- [ ] **Step 1: Read the verified signatures and runtime findings from Phase 0**

```bash
cat /tmp/wallet-sdk-verify/notes/transaction-history-storage.md
cat /tmp/wallet-sdk-verify/notes/devnet-facts.txt
```

- [ ] **Step 2: Compare to the current text**

```bash
grep -A 5 "TransactionHistoryStorage" plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md
grep -B 2 -A 4 "getAllFromTxHistory\|getAll" plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md
grep -B 1 -A 3 'balances\[""\]\|empty string' plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md
```

- [ ] **Step 3: Apply the three corrections**

  a. In `wallet-construction.md`, change `getAll(): AsyncIterableIterator<T>;` to `getAll(): Promise<readonly T[]>;` in the `TransactionHistoryStorage` interface block.

  b. In `transactions.md`, update the documented return type of `wallet.getAllFromTxHistory()` from `AsyncIterableIterator<WalletEntry>` to `Promise<WalletEntry[]>` and replace the `for await (const entry of wallet.getAllFromTxHistory())` example with a plain `for (const entry of await wallet.getAllFromTxHistory())` loop.

  c. In `state-and-balances.md`, find every occurrence of `balances[""]` and the prose claiming the empty string key represents the native NIGHT token. Replace with `balances[ledger.nativeToken().raw]` (or `balances[NIGHT_TOKEN_TYPE]` after a `const NIGHT_TOKEN_TYPE = ledger.nativeToken().raw;` line) and update the prose to say the native token is keyed by its raw bytes (64 hex zeros), accessible via `ledger.nativeToken().raw`.

- [ ] **Step 4: Verify runtime by reading from the live wallet**

Add a small fixture to `/tmp/wallet-sdk-verify/check-balance-key.ts` that builds a wallet, syncs, and prints `Object.keys(state.unshielded.balances)`. Run it:

```bash
cd /tmp/wallet-sdk-verify && npx tsx check-balance-key.ts
```

Confirm the printed key list contains the 64-zero hex string and does NOT contain the empty string. Capture the actual key as proof.

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/wallet-construction.md \
        plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md \
        plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md
git commit -m "docs(midnight-wallet:wallet-sdk): reconcile TransactionHistoryStorage signatures and native NIGHT key with verified source/runtime"
```

### Task 5.2: Add `references/variants-and-runtime.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/variants-and-runtime.md`

- [ ] **Step 1: Verify the runtime/variant API by reading source**

The runtime/variant pattern is unlikely to be exercisable in a small fixture; verify by reading source instead.

```bash
ls /tmp/midnight-wallet/packages/runtime/src/
cat /tmp/midnight-wallet/packages/runtime/src/index.ts
grep -rn "WalletBuilder\|WalletRuntime\|RuntimeVariant\|WalletBase" /tmp/midnight-wallet/packages/runtime/src/ | head -30
```

Capture exact symbol names, type signatures, and which file each lives in. Notes go in `/tmp/wallet-sdk-verify/notes/runtime-api.md`.

- [ ] **Step 2: Write the reference grounded in those notes**

The reference describes:
- The variant pattern: each wallet has a `.v1` export
- `WalletBuilder<TWalletFamily>` (with the verified signature)
- `WalletRuntime<TWalletFamily>` (with the verified signature)
- `RuntimeVariant` interface (verified members: tag, startSync, migrateFromPrevious — confirm these names)
- The visitor-style dispatch on `Runtime.WalletBase`
- A "When to touch this directly" section: most users don't; the facade dispatches automatically

Quote actual symbol names from source. Do not paraphrase.

- [ ] **Step 3: Optional — write a tiny TypeScript check that the imports compile**

```typescript
// /tmp/wallet-sdk-verify/check-runtime-imports.ts
import {
  // exact symbols from source
} from "@midnight-ntwrk/wallet-sdk-runtime";
console.log("imports OK");
```

```bash
cd /tmp/wallet-sdk-verify && npx tsx check-runtime-imports.ts
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/variants-and-runtime.md
git commit -m "docs(midnight-wallet:wallet-sdk): add variants-and-runtime reference"
```

### Task 5.3: Add `references/effect-and-promise-apis.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/effect-and-promise-apis.md`

- [ ] **Step 1: Verify the dual-API pattern by reading source**

```bash
grep -rn "Effect\|TaggedError\|Data\." /tmp/midnight-wallet/packages/node-client/src/index.ts /tmp/midnight-wallet/packages/indexer-client/src/index.ts /tmp/midnight-wallet/packages/prover-client/src/index.ts | head -30
ls /tmp/midnight-wallet/packages/node-client/src/effect/
ls /tmp/midnight-wallet/packages/indexer-client/src/effect/
ls /tmp/midnight-wallet/packages/prover-client/src/effect/
```

Capture which packages expose an `effect` sub-export, what the Promise-vs-Effect distinction looks like, and whether errors extend `Data.TaggedError`.

- [ ] **Step 2: Write the reference**

The reference describes:
- Most services have both flavors (Promise and Effect)
- Promise is the default for most consumers
- Effect provides composable lazy operations with typed errors via `Data.TaggedError`
- The `*/effect` sub-exports per package (verified list from Step 1)
- When to reach for Effect (advanced typed-error handling)

- [ ] **Step 3: Verify imports**

```typescript
// /tmp/wallet-sdk-verify/check-effect-imports.ts
import "@midnight-ntwrk/wallet-sdk-node-client/effect";
import "@midnight-ntwrk/wallet-sdk-indexer-client/effect";
import "@midnight-ntwrk/wallet-sdk-prover-client/effect";
console.log("effect sub-exports resolve");
```

```bash
cd /tmp/wallet-sdk-verify && npx tsx check-effect-imports.ts
```

If any sub-export fails to resolve, remove that bullet from the reference.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/effect-and-promise-apis.md
git commit -m "docs(midnight-wallet:wallet-sdk): add effect-and-promise-apis reference"
```

### Task 5.4: Add `references/capabilities-deep-dive.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/capabilities-deep-dive.md`

- [ ] **Step 1: Verify the capabilities sub-exports by reading source**

```bash
ls /tmp/midnight-wallet/packages/capabilities/src/
ls /tmp/midnight-wallet/packages/capabilities/src/balancer/
ls /tmp/midnight-wallet/packages/capabilities/src/submission/
ls /tmp/midnight-wallet/packages/capabilities/src/proving/
ls /tmp/midnight-wallet/packages/capabilities/src/pendingTransactions/
ls /tmp/midnight-wallet/packages/capabilities/src/simulation/
grep -rn "^export" /tmp/midnight-wallet/packages/capabilities/src/balancer/index.ts /tmp/midnight-wallet/packages/capabilities/src/submission/index.ts /tmp/midnight-wallet/packages/capabilities/src/proving/index.ts /tmp/midnight-wallet/packages/capabilities/src/pendingTransactions/index.ts /tmp/midnight-wallet/packages/capabilities/src/simulation/index.ts | head -50
```

- [ ] **Step 2: Write the reference**

For each sub-export, list:
- The path (e.g. `@midnight-ntwrk/wallet-sdk-capabilities/balancer`)
- The public symbols
- A one-line description of each
- When a user would override the default service (during `WalletFacade.init`)

Cross-link to `wallet-construction.md`'s "Optional Service Overrides" section.

- [ ] **Step 3: Verify imports**

```typescript
// /tmp/wallet-sdk-verify/check-capabilities-imports.ts
import * as balancer from "@midnight-ntwrk/wallet-sdk-capabilities/balancer";
import * as submission from "@midnight-ntwrk/wallet-sdk-capabilities/submission";
import * as proving from "@midnight-ntwrk/wallet-sdk-capabilities/proving";
import * as pending from "@midnight-ntwrk/wallet-sdk-capabilities/pendingTransactions";
import * as simulation from "@midnight-ntwrk/wallet-sdk-capabilities/simulation";
console.log({ balancer: !!balancer, submission: !!submission, proving: !!proving, pending: !!pending, simulation: !!simulation });
```

```bash
cd /tmp/wallet-sdk-verify && npx tsx check-capabilities-imports.ts
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/capabilities-deep-dive.md
git commit -m "docs(midnight-wallet:wallet-sdk): add capabilities-deep-dive reference"
```

### Task 5.5: Add `references/errors-and-troubleshooting.md`

**Files:**
- Create: `plugins/midnight-wallet/skills/wallet-sdk/references/errors-and-troubleshooting.md`

- [ ] **Step 1: Verify error types by reading source**

```bash
grep -rn "WalletError\|WalletRuntimeError\|TaggedError\|class.*Error" /tmp/midnight-wallet/packages/shielded-wallet/src/v1/ /tmp/midnight-wallet/packages/unshielded-wallet/src/v1/ /tmp/midnight-wallet/packages/dust-wallet/src/v1/ /tmp/midnight-wallet/packages/runtime/src/ /tmp/midnight-wallet/packages/utilities/src/networking/ /tmp/midnight-wallet/packages/node-client/src/ | head -50
```

- [ ] **Step 2: Write the reference**

List the error types per package; describe the `Data.TaggedError` discriminator pattern; provide a small symptom→error-type table for the common runtime failures (sync stuck, key derivation, submission rejection, network unreachable).

Cross-link `managing-test-wallets:references/troubleshooting.md` for the user-facing symptom table.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/errors-and-troubleshooting.md
git commit -m "docs(midnight-wallet:wallet-sdk): add errors-and-troubleshooting reference"
```

### Task 5.6: Update `references/quick-reference.md`

**Files:**
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md`

- [ ] **Step 1: Add the meta-package row to the Package Map table**

Insert a row for `@midnight-ntwrk/wallet-sdk` (verify version from `/tmp/wallet-sdk-verify/notes/resolved-versions.json`). Sub-paths: verify against `/tmp/midnight-wallet/packages/wallet-sdk/package.json` `exports` field and list each one.

```bash
jq '.exports' /tmp/midnight-wallet/packages/wallet-sdk/package.json
```

- [ ] **Step 2: Add sub-export columns or notes for packages with sub-exports**

For each of: `node-client`, `indexer-client`, `prover-client`, `runtime`, `utilities`, `capabilities`, list the verified sub-exports (`./effect`, `./testing`, `./networking`, `./balancer`, etc.).

```bash
for pkg in node-client indexer-client prover-client runtime utilities capabilities shielded-wallet unshielded-wallet dust-wallet; do
  echo "=== $pkg ==="
  jq '.exports' /tmp/midnight-wallet/packages/${pkg}/package.json 2>/dev/null
done
```

- [ ] **Step 3: Expand the `wallet-sdk-utilities` row**

List the verified utilities: `ArrayOps`, `BlobOps`, `DateOps`, `EitherOps`, `RecordOps`, `LedgerOps`, `SafeBigInt`, `ObservableOps`, the networking sub-module (`HttpURL`, `WsURL`), and the type-level utilities (`hlist`, `polyFunction`, `Fluent`).

Verify each by:
```bash
grep -E "^export" /tmp/midnight-wallet/packages/utilities/src/index.ts | head -30
```

- [ ] **Step 4: Add `Clock`, `Simulator`, `SimulatorState`, `TermsAndConditions` to the Common Type Lookups table**

Verify each from source:
```bash
grep -rn "export.*Clock\|export.*Simulator\|export.*SimulatorState\|export.*TermsAndConditions\|fetchTermsAndConditions" /tmp/midnight-wallet/packages/facade/src/ /tmp/midnight-wallet/packages/capabilities/src/simulation/ | head -20
```

- [ ] **Step 5: Verify quick-reference imports compile**

```typescript
// /tmp/wallet-sdk-verify/check-qr-imports.ts
import {
  WalletFacade,
  // Clock, Simulator, etc — only if they exist as top-level exports per Step 4
} from "@midnight-ntwrk/wallet-sdk-facade";
import * as utilities from "@midnight-ntwrk/wallet-sdk-utilities";
console.log("OK", !!utilities);
```

```bash
cd /tmp/wallet-sdk-verify && npx tsx check-qr-imports.ts
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/quick-reference.md
git commit -m "docs(midnight-wallet:wallet-sdk): expand quick-reference with sub-exports, meta-package, and missing types"
```

### Task 5.7: Update `references/infrastructure-clients.md`

**Files:**
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md`

- [ ] **Step 1: Add a section pointing to capabilities-deep-dive**

After the existing prover-client section, add:

```markdown
## Customizing the wallet's services

`WalletFacade.init` accepts factory functions for `submissionService`,
`pendingTransactionsService`, and `provingService`. The default
implementations come from `@midnight-ntwrk/wallet-sdk-capabilities`.

To customize a service (e.g. swap the HTTP prover for the WASM prover,
add metrics to submission, or use a custom pending-transactions store),
see `capabilities-deep-dive.md` for the full sub-export list and
factory signatures.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/infrastructure-clients.md
git commit -m "docs(midnight-wallet:wallet-sdk): cross-link capabilities-deep-dive from infrastructure-clients"
```

### Task 5.8: Update `references/transactions.md`

**Files:**
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md`

- [ ] **Step 1: Add a cross-link to errors-and-troubleshooting in the "Reverting Transactions" section**

After the existing reverting paragraph, add:

```markdown
> **See also:** `errors-and-troubleshooting.md` for the per-wallet
> error types thrown when finalize or submit fails.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/transactions.md
git commit -m "docs(midnight-wallet:wallet-sdk): cross-link errors-and-troubleshooting from transactions"
```

### Task 5.9: Update `references/state-and-balances.md`

**Files:**
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md`

- [ ] **Step 1: Verify `Clock` is a top-level export of `wallet-sdk-facade`**

```bash
grep -n "export.*Clock\|Clock.*=" /tmp/midnight-wallet/packages/facade/src/index.ts
```

- [ ] **Step 2: Add a one-paragraph note about `Clock` near the `state.dust.balance(time)` discussion**

```markdown
### Clock injection

Tests can inject a custom `Clock` (`{ readonly now: () => Date }`)
into the wallet so that `state.dust.balance(time)` and other
time-sensitive operations use a deterministic time source. The clock
is configured during `WalletFacade.init` (see `wallet-construction.md`).
```

If `Clock` is NOT a top-level export, omit this section and note in the commit message.

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/references/state-and-balances.md
git commit -m "docs(midnight-wallet:wallet-sdk): add Clock injection note"
```

### Task 5.10: Update `wallet-sdk/SKILL.md`

**Files:**
- Modify: `plugins/midnight-wallet/skills/wallet-sdk/SKILL.md`

- [ ] **Step 1: Replace the `wallet-cli` related-skills row with the two new skills**

Find the row referencing `midnight-wallet:wallet-cli` and remove it. Add rows for `midnight-wallet:managing-test-wallets` and `midnight-wallet:sdk-regression-check`.

- [ ] **Step 2: Add the disambiguation block at the top**

Insert before the existing "Quick Start" section:

```markdown
## Critical caveat — verify SDK is current

Patterns in this skill were verified against the package versions pinned
in `midnight-wallet:sdk-regression-check/versions.lock.json`. The
Midnight Network ecosystem moves quickly, and there may be breaking
changes between SDK versions. Run `midnight-wallet:sdk-regression-check`
before trusting any pattern here.

## Scope — browser wallets are out of scope

This skill is the package-level reference for the wallet SDK
(`@midnight-ntwrk/wallet-sdk-*`), used in programmatic contexts where
the script owns the keys directly. If the user is integrating their
DApp with a browser extension wallet (Lace or other), load
`midnight-dapp-dev:dapp-connector` instead.
```

- [ ] **Step 3: Expand the deep-dive references table**

Add four rows:
| Look up the variant/runtime pattern (advanced) | `references/variants-and-runtime.md` |
| Choose between Promise and Effect APIs | `references/effect-and-promise-apis.md` |
| Customize wallet services (balancer, prover, etc.) | `references/capabilities-deep-dive.md` |
| Resolve runtime errors and exceptions | `references/errors-and-troubleshooting.md` |

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-wallet/skills/wallet-sdk/SKILL.md
git commit -m "docs(midnight-wallet:wallet-sdk): expand SKILL.md with disambiguation, caveat, and new references"
```

---

## Phase 6 — Plugin metadata + README

### Task 6.1: Update `plugin.json`

**Files:**
- Modify: `plugins/midnight-wallet/.claude-plugin/plugin.json`

- [ ] **Step 1: Replace the description**

Set:
```json
"description": "Wallet SDK reference, test-wallet management patterns, and SDK regression checking for Midnight Network development."
```

- [ ] **Step 2: Update keywords**

Drop `mcp` and `wallet-cli`. Add `shielded`, `unshielded`, `sdk-regression`. Final list:
```json
"keywords": [
  "midnight",
  "wallet",
  "wallet-sdk",
  "night-tokens",
  "dust-tokens",
  "transfer",
  "airdrop",
  "balance",
  "test-wallets",
  "devnet",
  "funding",
  "bip39",
  "mnemonic",
  "wallet-facade",
  "hd-wallet",
  "shielded",
  "unshielded",
  "sdk-regression"
]
```

- [ ] **Step 3: Bump the version**

```json
"version": "0.4.0"
```

- [ ] **Step 4: Validate the JSON**

```bash
jq . plugins/midnight-wallet/.claude-plugin/plugin.json
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-wallet/.claude-plugin/plugin.json
git commit -m "feat(midnight-wallet): bump to 0.4.0; rewrite description; refresh keywords"
```

### Task 6.2: Rewrite README.md

**Files:**
- Modify: `plugins/midnight-wallet/README.md`

- [ ] **Step 1: Write the new README**

```markdown
# midnight-wallet

<p align="center">
  <img src="assets/mascot.png" alt="midnight-wallet mascot" width="200" />
</p>

Wallet SDK reference, test-wallet management patterns, and SDK regression
checking for Midnight Network development. Programmatic SDK usage only —
browser extension wallets (Lace and others) are handled by
`midnight-dapp-dev:dapp-connector`.

## Skills

### midnight-wallet:wallet-sdk

Package-level reference for `@midnight-ntwrk/wallet-sdk-*` covering
construction (`WalletFacade.init`), HD key derivation, the three
sub-wallets (shielded, unshielded, dust), state and balances,
transactions, infrastructure clients, the variant/runtime pattern, the
Effect/Promise dual-API pattern, capability sub-exports, and runtime
errors.

### midnight-wallet:managing-test-wallets

Procedural skill for creating, funding, monitoring, and transferring
with test wallets. Eight runnable example scripts cover the common
scenarios on local devnet (`undeployed`) and the public testnets
(`preprod`, `preview`).

### midnight-wallet:sdk-regression-check

Drift detection and live smoke testing for the documented patterns. Two
modes: a fast no-network drift check, and a slow live-devnet smoke test.
Reports findings to the user; never edits documented patterns or the
lock file as part of running.

## Related plugins

| Need | Plugin / Skill |
|------|----------------|
| Local devnet management | `midnight-tooling:devnet` |
| Browser wallet (Lace) integration | `midnight-dapp-dev:dapp-connector` |
| DApp SDK provider wiring | `midnight-dapp-dev:midnight-sdk` |
| Testing wallet SDK code | `midnight-cq:wallet-testing` |
| Compact contract development | `compact-core` |

## Versioning

This plugin pins the wallet SDK package versions it has been verified
against in
`skills/sdk-regression-check/versions.lock.json`. The lock is updated
when the plugin is released, not when the regression-check skill is
run. To check current drift, invoke
`midnight-wallet:sdk-regression-check` and read its output.
```

- [ ] **Step 2: Confirm no MCP/CLI references remain**

```bash
grep -E "MCP|CLI|wallet-cli|mcp" plugins/midnight-wallet/README.md || echo "clean"
```

Expected: `clean` (or only the negative-form mention "extension wallets ... are handled by ...").

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-wallet/README.md
git commit -m "docs(midnight-wallet): rewrite README around three-skill structure"
```

---

## Phase 7 — Final verification + acceptance criteria

### Task 7.1: Run the full acceptance suite

- [ ] **Step 1: Confirm no traces of CLI/MCP remain in the plugin tree**

```bash
grep -rE "wallet-cli|midnight-wallet-cli|midnight-wallet-mcp|mcp__midnight-wallet" plugins/midnight-wallet/ || echo "clean"
```

Expected: `clean`.

- [ ] **Step 2: Confirm the plugin contains exactly the three expected skills**

```bash
ls plugins/midnight-wallet/skills/
```

Expected:
```
managing-test-wallets
sdk-regression-check
wallet-sdk
```

- [ ] **Step 3: Confirm no commands/, hooks/, or .mcp.json**

```bash
test ! -d plugins/midnight-wallet/commands && echo "OK: no commands"
test ! -d plugins/midnight-wallet/hooks && echo "OK: no hooks"
test ! -f plugins/midnight-wallet/.mcp.json && echo "OK: no .mcp.json"
```

Expected: three `OK:` lines.

- [ ] **Step 4: Confirm the devnet template is unchanged**

```bash
git log --since="<start of this work>" --name-only -- plugins/midnight-tooling/skills/devnet/templates/devnet.yml
```

Expected: no commits touching the template (the genesis-seed change was a new reference file, not a template edit).

- [ ] **Step 5: Confirm `genesis-seed.md` exists with the expected content**

```bash
test -f plugins/midnight-tooling/skills/devnet/references/genesis-seed.md && echo "OK"
grep -q "0000000000000000000000000000000000000000000000000000000000000001" plugins/midnight-tooling/skills/devnet/references/genesis-seed.md && echo "OK seed value"
```

- [ ] **Step 6: Confirm doctor no longer mentions the wallet MCP**

```bash
grep -E "wallet-cli|midnight-wallet-cli|midnight-wallet-mcp" plugins/midnight-expert/skills/doctor/ -r || echo "clean"
```

Expected: `clean`.

- [ ] **Step 7: Re-run drift-check**

```bash
plugins/midnight-wallet/skills/sdk-regression-check/scripts/drift-check.sh
```

Expected: exit 0 (lock just bumped at end of Phase 0).

- [ ] **Step 8: Re-run smoke test**

```bash
plugins/midnight-wallet/skills/sdk-regression-check/scripts/smoke-test.sh
```

Expected: `PASS — smoke test completed in <N>s`.

- [ ] **Step 9: Re-run full-test-wallet-setup**

```bash
cd /tmp/wallet-sdk-verify && cp ../plugins/midnight-wallet/skills/managing-test-wallets/examples/full-test-wallet-setup.ts ./ && npx tsx full-test-wallet-setup.ts undeployed
```

Expected: exit 0 with positive NIGHT and DUST balances in the summary.

- [ ] **Step 10: Confirm plugin.json version is 0.4.0**

```bash
jq -r '.version' plugins/midnight-wallet/.claude-plugin/plugin.json
```

Expected: `0.4.0`.

- [ ] **Step 11: Confirm README has no MCP/CLI references**

```bash
grep -E "MCP|CLI|wallet-cli|mcp" plugins/midnight-wallet/README.md || echo "clean"
```

Expected: `clean` (or only the disambiguation phrasing about extension wallets, which uses the word "extension" not MCP/CLI).

### Task 7.2: Smoke-check existing skill descriptions render

- [ ] **Step 1: Confirm `/reload-plugins` succeeds**

```bash
# Inside Claude Code:
/reload-plugins
```

Expected: a count of plugins/skills/agents/hooks loaded; no errors.

- [ ] **Step 2: Confirm the three new skills register**

```bash
# Inside Claude Code, listing skills:
# Look for entries:
#   midnight-wallet:wallet-sdk
#   midnight-wallet:managing-test-wallets
#   midnight-wallet:sdk-regression-check
```

If any are missing from the listing, debug the SKILL.md frontmatter (`name` field, missing required keys).

### Task 7.3: Push the branch

- [ ] **Step 1: Confirm the branch is up to date**

```bash
git status
git log --oneline -20
```

- [ ] **Step 2: Push**

```bash
git push -u origin fix-wallet-plugin
```

- [ ] **Step 3: Open a PR (separately, manual or via gh)**

The PR description should reference the spec file at
`docs/superpowers/specs/2026-04-26-midnight-wallet-cli-removal-design.md`.

---

## Self-review summary

The plan covers:

- **Phase 0** verifies the audit-flagged discrepancies and stands up `/tmp/wallet-sdk-verify/` as the single SDK-consumer harness reused throughout.
- **Phase 1** removes everything tied to the unofficial CLI/MCP, including the cross-plugin doctor entries.
- **Phase 2** adds the single `genesis-seed.md` to `midnight-tooling:devnet`.
- **Phase 3** builds `sdk-regression-check` end-to-end (versions.lock, drift-check, smoke-test, fixture, and four references) with explicit "report only — never edit the lock" policy in the SKILL.md and the `interpreting-output.md` reference.
- **Phase 4** builds `managing-test-wallets` with all eight examples verified against the live devnet before their references are written, ensuring references are grounded in observed behavior.
- **Phase 5** updates `wallet-sdk` per the audit findings: four new references (variants-and-runtime, effect-and-promise-apis, capabilities-deep-dive, errors-and-troubleshooting), expanded quick-reference, cross-links between existing references, the disambiguation block, and the caveat block.
- **Phase 6** updates plugin.json (version, description, keywords) and rewrites the README around the three-skill structure.
- **Phase 7** runs the full acceptance suite from the spec.

Verification is folded into each phase: every example script is executed end-to-end before its commit; every reference's claims are either verified by running a script or by reading source in `/tmp/midnight-wallet`; the audit-flagged signature discrepancies are reconciled in Phase 0 against actual source code, and Phase 5 acts on those findings.
