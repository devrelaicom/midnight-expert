# Wallet SDK Verification and Testing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add wallet SDK verification to the midnight-verify plugin and wallet-testing + dapp-connector-testing skills to the midnight-cq plugin.

**Architecture:** Two new skill files in midnight-verify (domain routing + wallet-specific source investigation method). Seven new files in midnight-cq (two skills with reference dirs). Eleven modifications to existing agents and skills to support wallet SDK mode-switching. No new agents.

**Tech Stack:** Markdown skill/agent files following existing midnight-verify and midnight-cq patterns. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-31-wallet-sdk-verification-and-testing-design.md`

---

## File Map

### midnight-verify plugin (`plugins/midnight-verify/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/verify-wallet-sdk/SKILL.md` | Domain skill — claim classification and routing table for wallet SDK claims |
| Create | `skills/verify-by-wallet-source/SKILL.md` | Method skill — wallet-specific source investigation guidance, repo routing, evidence rules |
| Modify | `agents/verifier.md` | Add wallet SDK domain to description, dispatch rules, and examples |
| Modify | `skills/verify-correctness/SKILL.md` | Add Wallet SDK row to domain classification, verdict qualifiers, pre-flight-only rule |
| Modify | `agents/type-checker.md` | Add wallet-sdk-workspace mode to description |
| Modify | `skills/verify-by-type-check/SKILL.md` | Add wallet-sdk-workspace setup, package list, mode switching |
| Modify | `agents/source-investigator.md` | Add wallet SDK to description, load verify-by-wallet-source for wallet claims |
| Modify | `agents/sdk-tester.md` | Add wallet-devnet fallback mode to description |
| Modify | `skills/verify-by-devnet/SKILL.md` | Add wallet-devnet mode, Docker health checks, fallback-only note |

### midnight-cq plugin (`plugins/midnight-cq/`)

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `skills/wallet-testing/SKILL.md` | Testing custom wallet implementations built on SDK packages |
| Create | `skills/wallet-testing/references/effect-boundary-patterns.md` | Unwrapping Effect/Either in tests, mock Layers |
| Create | `skills/wallet-testing/references/wallet-builder-setup.md` | WalletBuilder wiring, initial state, test doubles |
| Create | `skills/wallet-testing/references/observable-testing.md` | Observable state testing, subscription cleanup |
| Create | `skills/dapp-connector-testing/SKILL.md` | Testing DApp Connector API integration |
| Create | `skills/dapp-connector-testing/references/connector-stub-patterns.md` | ConnectedAPI test doubles, factory functions |
| Create | `skills/dapp-connector-testing/references/error-handling-patterns.md` | Error code test patterns, progressive enhancement |
| Modify | `.claude-plugin/plugin.json` | Add keywords for new skills |
| Modify | `README.md` | Document new skills |
| Modify | `agents/cq-runner.md` | Recognize wallet SDK test projects |
| Modify | `agents/cq-reviewer.md` | Recognize wallet SDK test projects in audit |

---

## Important Context for Implementers

### Plugin paths

All midnight-verify files are relative to `plugins/midnight-verify/`.
All midnight-cq files are relative to `plugins/midnight-cq/`.

### Existing pattern to follow

**Skill files** use YAML frontmatter (`name`, `description`, `version`) then markdown body. See any existing `SKILL.md` for the pattern.

**Agent files** use YAML frontmatter (`name`, `description`, `skills`, `model`, `color`) then markdown body with instructions. See `agents/verifier.md` for the orchestrator pattern or `agents/contract-writer.md` for a sub-agent pattern.

**Reference files** are plain markdown (no frontmatter) under `skills/<skill-name>/references/`.

### Wallet SDK package names

The npm packages are `@midnight-ntwrk/wallet-sdk-<name>`:
- `wallet-sdk-facade`, `wallet-sdk-shielded`, `wallet-sdk-unshielded-wallet`, `wallet-sdk-dust-wallet`
- `wallet-sdk-runtime`, `wallet-sdk-abstractions`, `wallet-sdk-capabilities`
- `wallet-sdk-hd`, `wallet-sdk-address-format`, `wallet-sdk-utilities`
- `wallet-sdk-indexer-client`, `wallet-sdk-node-client`, `wallet-sdk-prover-client`
- Also: `@midnight-ntwrk/dapp-connector-api`

### Source repos

- Wallet SDK: `midnightntwrk/midnight-wallet` (primary)
- DApp Connector API: `midnightntwrk/midnight-dapp-connector-api`
- Wallet Spec: `midnightntwrk/midnight-architecture` at `components/WalletEngine/Specification.md`
- Ledger Spec: `midnightntwrk/midnight-ledger` at `spec/`

### Clone protocol

Always use SSH (`git@github.com:`) not HTTPS for cloning repos.

---

## Task 1: Create verify-wallet-sdk domain skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-wallet-sdk
```

- [ ] **Step 2: Write the domain skill file**

Create `plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md` with this exact content:

```markdown
---
name: midnight-verify:verify-wallet-sdk
description: >-
  Wallet SDK claim classification and method routing. Determines what kind of
  wallet SDK claim is being verified and which verification methods apply:
  type-checking (pre-flight only), source investigation (primary), or devnet
  E2E (fallback). Handles claims about @midnight-ntwrk/wallet-sdk-* packages,
  WalletFacade, WalletBuilder, the DApp Connector API, HD derivation, Bech32m
  addresses, branded types, and the three-wallet architecture. Loaded by the
  verifier agent alongside the hub skill.
version: 0.1.0
---

# Wallet SDK Claim Classification

This skill classifies wallet SDK claims and determines which verification method to use. The verifier (orchestrator) agent loads this alongside the hub skill (`verify-correctness`).

## Verification Flow

Every wallet SDK claim follows the same three-step flow:

1. **Type-check (pre-flight)** — dispatch type-checker in wallet-sdk-workspace mode. Fails fast if the claim is fundamentally broken. Type-checking alone NEVER produces a verdict for wallet SDK claims.
2. **Source investigation (primary)** — always runs. Dispatch source-investigator, which loads `verify-by-wallet-source`. This is the primary evidence source for all wallet SDK verdicts.
3. **Devnet E2E (fallback)** — dispatch sdk-tester in wallet-devnet mode ONLY if source investigation returns Inconclusive.

## Claim Type → Method Routing

When you receive a wallet SDK claim, classify it using this table:

### Claims About SDK Package API

| Claim Type | Example | Pre-flight | Primary | Fallback |
|---|---|---|---|---|
| Package/type existence | "WalletFacade exports balanceFinalizedTransaction" | type-checker | source-investigator | — |
| Function signature | "submitTransaction returns Observable\<SubmissionEvent\>" | type-checker | source-investigator | — |
| Interface shape | "ShieldedAddress has coinPublicKey and encryptionPublicKey" | type-checker | source-investigator | — |
| Branded type structure | "ProtocolVersion is a branded bigint" | type-checker | source-investigator | — |
| Transaction lifecycle | "SubmissionEvent goes Submitted → InBlock → Finalized" | type-checker | source-investigator | — |

### Claims About Wallet Architecture

| Claim Type | Example | Pre-flight | Primary | Fallback |
|---|---|---|---|---|
| HD derivation paths | "Role 2 is Dust, path m/44'/2400'/0'/2/0" | — | source-investigator | — |
| Address encoding | "Bech32m prefix for shielded is mn_shield-addr" | — | source-investigator | — |
| Three-token architecture | "Dust balance is time-dependent" | — | source-investigator | — |
| Variant/runtime behavior | "WalletRuntime migrates state between protocol versions" | — | source-investigator | sdk-tester |
| Indexer/node integration | "IndexerClient retries 3 times on 502-504" | — | source-investigator | — |

### Claims About DApp Connector API

| Claim Type | Example | Pre-flight | Primary | Fallback |
|---|---|---|---|---|
| Connector API methods | "ConnectedAPI.makeTransfer creates a shielded transfer" | type-checker | source-investigator | sdk-tester |
| Connector error handling | "PermissionRejected is permanent per session" | — | source-investigator | — |
| Connector types | "DesiredOutput has kind, type, value, recipient fields" | type-checker | source-investigator | — |

### Claims About Behavioral Outcomes

| Claim Type | Example | Pre-flight | Primary | Fallback |
|---|---|---|---|---|
| Facade lifecycle | "WalletFacade.init syncs all three wallets" | — | source-investigator | sdk-tester |
| Proving behavior | "WasmProver uses web-worker for background proving" | — | source-investigator | — |
| Submission behavior | "PolkadotNodeClient auto-disconnects after metadata fetch" | — | source-investigator | — |

### Routing Rules

**When in doubt:**
- API surface (types, exports, signatures) → type-checker pre-flight + source-investigator
- Architecture or protocol design → source-investigator only
- Runtime behavior → source-investigator, with sdk-tester fallback if Inconclusive

**Type-checking is NEVER sufficient alone.** It is a fast pre-flight gate. Every wallet SDK claim must be resolved by source investigation (or devnet E2E as a last resort).

## Hints from Existing Skills

The verifier or sub-agents may consult these skills for context. They are **hints only** — never cite them as evidence in the verdict.

- `dapp-development:midnight-sdk` — provider setup, SDK component overview
- `dapp-development:dapp-connector` — wallet integration patterns
- `compact-core:compact-witness-ts` — witness implementation patterns (if claim spans wallet + witness)

Load only what's relevant to the specific claim.
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md
```

Expected: the YAML frontmatter opening with `---` and `name: midnight-verify:verify-wallet-sdk`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md
git commit -m "feat(midnight-verify): add verify-wallet-sdk domain skill

Routing table for wallet SDK claim classification. Routes all claims
through source investigation as the primary method, with type-checking
as a fast pre-flight and devnet E2E as an Inconclusive fallback.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 2: Create verify-by-wallet-source method skill

**Files:**
- Create: `plugins/midnight-verify/skills/verify-by-wallet-source/SKILL.md`

- [ ] **Step 1: Create the skill directory**

```bash
mkdir -p plugins/midnight-verify/skills/verify-by-wallet-source
```

- [ ] **Step 2: Write the method skill file**

Create `plugins/midnight-verify/skills/verify-by-wallet-source/SKILL.md` with this exact content:

```markdown
---
name: midnight-verify:verify-by-wallet-source
description: >-
  Verification by source code inspection of the Midnight Wallet SDK repositories.
  Searches and reads the actual wallet SDK source code to verify claims about
  wallet packages, the DApp Connector API, HD derivation, address encoding,
  and the three-wallet architecture. Uses octocode-mcp for quick lookups, falls
  back to local cloning for deep investigation. Loaded by the source-investigator
  agent when the claim domain is wallet SDK.
version: 0.1.0
---

# Verify by Wallet Source Code Inspection

You are verifying a claim about the Midnight Wallet SDK by reading the actual source code. Follow these steps in order.

## Critical Rule

**Source code is evidence. Everything else is a hint.**

| Source | Role | Rule |
|---|---|---|
| Source code definitions (function signatures, type exports, implementation) | Primary evidence | Always the target. Verdicts must cite source code. |
| Test files | Navigation aid | Follow test imports to find the right source code to inspect. Do not cite tests as evidence. Running tests (clone to /tmp, execute) is a last resort — realistically never needed. |
| docs-snippets, spec documents (Wallet Spec, DApp Connector Spec, Ledger Spec) | Hints only | Useful for orienting where to look. Never evidence on their own. Any claim derived from these must be corroborated by source code inspection. |
| ADRs, Design.md | Hints only | Can support "why" claims, but the "what" they describe must be verified via source. |

## Step 1: Determine Where to Look

**Repository routing — match the claim to the right repo and path:**

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
| Common utilities (EitherOps, ObservableOps) | `midnightntwrk/midnight-wallet` | `packages/utilities/src/` |
| GraphQL indexer sync | `midnightntwrk/midnight-wallet` | `packages/indexer-client/src/` |
| Polkadot RPC submission | `midnightntwrk/midnight-wallet` | `packages/node-client/src/` |
| ZK proof generation client | `midnightntwrk/midnight-wallet` | `packages/prover-client/src/` |
| DApp Connector API types and spec | `midnightntwrk/midnight-dapp-connector-api` | `src/api.ts` |

**Package hierarchy context:**

The wallet SDK is a monorepo with this dependency structure:

```
facade              ← Unified API combining all wallet types
   ├── shielded-wallet
   ├── unshielded-wallet
   └── dust-wallet
          ↓
runtime             ← Wallet lifecycle/variant orchestration
   ├── abstractions ← Interfaces that variants must implement
   └── capabilities ← Shared implementations (coin selection, balancing)
          ↓
utilities           ← Common types and operations
```

External communication packages: `indexer-client`, `node-client`, `prover-client`.
Key management: `hd` (BIP32/BIP39), `address-format` (Bech32m).

## Step 2: Search with octocode-mcp

Start with targeted lookups using the `octocode-mcp` tools:

1. **`githubSearchCode`** — search for specific function names, type names, export definitions in `midnightntwrk/midnight-wallet`
2. **`githubGetFileContent`** — read a specific file once you know the path
3. **`githubViewRepoStructure`** — understand the package layout if you're not sure where to look

**Search strategy:**

- For API surface claims: check the package's `src/index.ts` exports first, then trace to the implementation file
- For DApp Connector claims: search `midnightntwrk/midnight-dapp-connector-api` source directly
- Start narrow (exact term), broaden if no results
- Verify you're on the default branch and looking at current code

## Step 3: Clone Locally if Needed

If octocode-mcp results are insufficient — tracing cross-package dependencies, counting exports, or following complex call chains across the monorepo — clone locally:

```bash
CLONE_DIR=$(mktemp -d)
git clone --depth 1 git@github.com:midnightntwrk/midnight-wallet.git "$CLONE_DIR/midnight-wallet"
```

For DApp Connector API claims:

```bash
git clone --depth 1 git@github.com:midnightntwrk/midnight-dapp-connector-api.git "$CLONE_DIR/midnight-dapp-connector-api"
```

Always use SSH protocol (`git@github.com:`), not HTTPS.

After investigation, clean up:

```bash
rm -rf "$CLONE_DIR"
```

## Step 4: Read and Interpret Source

**What counts as evidence (ordered by strength):**

1. **Function/type/export definitions in source code** — strong evidence. If the source defines a function with signature X, that's definitive.
2. **Test files as navigation aids** — follow test imports to pinpoint the source code to inspect. The test itself is not evidence; the source it points to is. In rare cases where no other verification path exists, you may clone the repo to /tmp and run the test to confirm it passes — but this is a last resort.
3. **Generated docs, spec documents, ADRs** — hints for where to look and understanding "why". Any claim based on these must be corroborated by source code inspection.

**Watch for:**

- The wallet SDK uses Effect library extensively. Types like `Effect<A, E, R>`, `Either<A, E>`, `Stream.Stream<A, E, R>` appear throughout. Understand that `Effect` describes side-effectful computation and `Either` describes pure synchronous results.
- Branded types (via `Brand.nominal<T>()`) are used for ProtocolVersion, WalletSeed, WalletState. These are compile-time distinctions — the runtime value is the underlying primitive.
- The variant pattern means wallet implementations live in versioned directories (e.g., `src/v1/`). Claims about behavior must be checked against the correct version.
- `Observable` from RxJS is used at the facade API boundary. Internal code uses Effect `Stream`.

## Step 5: Report

**Your report must include:**

1. **The claim as received** — verbatim
2. **Where you looked** — repo name, file path(s), line numbers
3. **What the source shows** — quote or summarize the relevant code
4. **GitHub links** — full URLs to exact files/lines
5. **Your interpretation** — does the source confirm, refute, or leave the claim inconclusive?

**Report format:**

```
### Source Investigation Report

**Claim:** [verbatim]

**Searched:** [repo(s) and method — octocode-mcp search / local clone]

**Found:**
- File: [repo/path/to/file.ext:line-range]
- Link: [full GitHub URL]
- Content: [relevant code snippet or summary]

**Interpretation:** [Confirmed / Refuted / Inconclusive] — [explanation of what the source shows and how it relates to the claim]
```

If inconclusive, explain:
- What you searched and why it wasn't definitive
- Whether devnet E2E testing might resolve it (the verifier orchestrator decides whether to dispatch)
```

- [ ] **Step 3: Verify the file was created correctly**

```bash
head -5 plugins/midnight-verify/skills/verify-by-wallet-source/SKILL.md
```

Expected: the YAML frontmatter opening with `---` and `name: midnight-verify:verify-by-wallet-source`.

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/skills/verify-by-wallet-source/SKILL.md
git commit -m "feat(midnight-verify): add verify-by-wallet-source method skill

Wallet-specific source investigation guidance for the source-investigator
agent. Contains repo routing table, package hierarchy, search strategy,
strict evidence rules (source code only), and report format.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 3: Update verifier orchestrator agent

**Files:**
- Modify: `plugins/midnight-verify/agents/verifier.md`

- [ ] **Step 1: Add wallet SDK example to the description block**

In the `description` field of the YAML frontmatter, after the existing Example 7 (witness verification), add:

```yaml
  Example 8: User runs /verify "WalletFacade exports balanceFinalizedTransaction"
  — the orchestrator classifies this as a wallet SDK API claim, dispatches
  the type-checker (pre-flight) and source-investigator (primary) concurrently,
  and reports the verdict based on source evidence.

  Example 9: User runs /verify "Dust balance is time-dependent" — the
  orchestrator classifies this as a wallet SDK architecture claim, dispatches
  the source-investigator only (no pre-flight needed), and reports.
```

- [ ] **Step 2: Add verify-wallet-sdk to the skills list**

In the frontmatter `skills:` field, append `, midnight-verify:verify-wallet-sdk` to the existing comma-separated list.

The line currently reads:
```
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk, midnight-verify:verify-zkir, midnight-verify:verify-witness
```

Change it to:
```
skills: midnight-verify:verify-correctness, midnight-verify:verify-compact, midnight-verify:verify-sdk, midnight-verify:verify-zkir, midnight-verify:verify-witness, midnight-verify:verify-wallet-sdk
```

- [ ] **Step 3: Add wallet SDK dispatch rules to the body**

After the existing "**Witness verification:**" dispatch section and before "**When multiple methods are needed...**", add:

```markdown
**Wallet SDK verification:**
- Pre-flight type-check → dispatch `midnight-verify:type-checker` with `domain: 'wallet-sdk'` context
- Source investigation (primary) → dispatch `midnight-verify:source-investigator` with instruction to load `midnight-verify:verify-by-wallet-source`
- Devnet E2E (fallback) → dispatch `midnight-verify:sdk-tester` with `domain: 'wallet-sdk'` context, ONLY if source investigation returns Inconclusive

**For wallet SDK claims, dispatch type-checker and source-investigator concurrently** (they are independent). Wait for source-investigator's verdict. Only dispatch sdk-tester if source-investigator returned Inconclusive.
```

- [ ] **Step 4: Add wallet SDK domain to the "Based on the claim domain" section**

In the body section starting "Based on the claim domain:", after the existing bullet for "Cross-domain", add:

```markdown
   - Wallet SDK claims → load `midnight-verify:verify-wallet-sdk`
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/agents/verifier.md
git commit -m "feat(midnight-verify): add wallet SDK domain to verifier orchestrator

Add wallet SDK dispatch rules, examples, and skill reference to the
verifier agent. Wallet SDK claims dispatch type-checker (pre-flight)
and source-investigator (primary) concurrently.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 4: Update verify-correctness hub skill

**Files:**
- Modify: `plugins/midnight-verify/skills/verify-correctness/SKILL.md`

- [ ] **Step 1: Add Wallet SDK to the domain classification table**

In the "### 1. Classify the Domain" section, add a new row to the table after the "Cross-domain" row:

```markdown
| **Wallet SDK** | @midnight-ntwrk/wallet-sdk-* packages, WalletFacade, WalletBuilder, WalletRuntime, RuntimeVariant, DApp Connector API (ConnectedAPI, InitialAPI, window.midnight), HD derivation, Bech32m addresses, branded types (ProtocolVersion, WalletSeed), three-wallet architecture, capabilities (Balancer, ProvingService, SubmissionService) | Load `midnight-verify:verify-wallet-sdk` |
```

- [ ] **Step 2: Add wallet SDK dispatch rules to section 3**

In "### 3. Dispatch Sub-Agents", after the "Witness + ZKIR verification" bullets and before "**When multiple methods needed**", add:

```markdown
**Wallet SDK verification:**
- Pre-flight type-check → dispatch `midnight-verify:type-checker` agent with `domain: 'wallet-sdk'` context
- Source investigation (primary, always runs) → dispatch `midnight-verify:source-investigator` agent with instruction to load `midnight-verify:verify-by-wallet-source`
- Devnet E2E (fallback, only if source is Inconclusive) → dispatch `midnight-verify:sdk-tester` agent with `domain: 'wallet-sdk'` context

**For wallet SDK claims, dispatch type-checker and source-investigator concurrently.** Wait for source-investigator. Only dispatch sdk-tester if source returned Inconclusive.
```

- [ ] **Step 3: Add wallet SDK verdict qualifiers to section 4**

In "### 4. Synthesize the Verdict", add these rows to the verdict options table after the witness-verified rows:

```markdown
| **Confirmed** | (source-verified) | Source investigation found definitive wallet SDK source evidence (wallet SDK domain) |
| **Confirmed** | (source-verified + tested) | Source confirmed and devnet E2E also passed (wallet SDK domain) |
| **Refuted** | (source-verified) | Source contradicts the wallet SDK claim |
| **Refuted** | (type-checked + source-verified) | Type-check failed and source confirms it's wrong (wallet SDK domain) |
| **Inconclusive** | (source insufficient, devnet unavailable) | Couldn't confirm via source, devnet not running (wallet SDK domain) |
```

- [ ] **Step 4: Add pre-flight-only rule**

After the verdict options table, add:

```markdown
**Critical rule for wallet SDK claims:** Type-checking is a fast pre-flight only. It NEVER produces a standalone verdict for wallet SDK claims. Every wallet SDK verdict must come from source investigation (or devnet E2E as a fallback). There is no `Confirmed (type-checked)` for wallet SDK claims.
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-verify/skills/verify-correctness/SKILL.md
git commit -m "feat(midnight-verify): add wallet SDK domain to verify-correctness hub

Add Wallet SDK to domain classification table, dispatch rules, verdict
qualifiers, and pre-flight-only rule for type-checking.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 5: Update type-checker agent and verify-by-type-check skill

**Files:**
- Modify: `plugins/midnight-verify/agents/type-checker.md`
- Modify: `plugins/midnight-verify/skills/verify-by-type-check/SKILL.md`

- [ ] **Step 1: Update type-checker agent description**

In `agents/type-checker.md`, add to the end of the `description` field, before the closing of the YAML frontmatter:

```yaml

  Example 5: Wallet SDK claim "WalletFacade exports balanceFinalizedTransaction"
  — writes a .ts file importing from @midnight-ntwrk/wallet-sdk-facade, runs tsc,
  confirms the export exists. Uses the wallet-sdk-workspace (separate from the
  DApp SDK workspace).
```

- [ ] **Step 2: Add wallet-sdk-workspace setup to verify-by-type-check skill**

In `skills/verify-by-type-check/SKILL.md`, after the existing "## Step 1: Set Up the Workspace" section's "**Subsequent times (workspace exists):**" subsection and the "**Create the job directory:**" subsection, add a new section:

```markdown
## Wallet SDK Workspace Mode

When the verifier passes `domain: 'wallet-sdk'` context, use a separate workspace at `.midnight-expert/verify/wallet-sdk-workspace/` instead of the SDK workspace. This workspace has different packages installed.

**First time (workspace does not exist):**

\`\`\`bash
mkdir -p .midnight-expert/verify/wallet-sdk-workspace
cd .midnight-expert/verify/wallet-sdk-workspace

# Initialize Node project
npm init -y

# Install all Wallet SDK packages + DApp Connector API + TypeScript
npm install \
  @midnight-ntwrk/wallet-sdk-facade \
  @midnight-ntwrk/wallet-sdk-shielded \
  @midnight-ntwrk/wallet-sdk-unshielded-wallet \
  @midnight-ntwrk/wallet-sdk-dust-wallet \
  @midnight-ntwrk/wallet-sdk-runtime \
  @midnight-ntwrk/wallet-sdk-abstractions \
  @midnight-ntwrk/wallet-sdk-capabilities \
  @midnight-ntwrk/wallet-sdk-hd \
  @midnight-ntwrk/wallet-sdk-address-format \
  @midnight-ntwrk/wallet-sdk-utilities \
  @midnight-ntwrk/wallet-sdk-indexer-client \
  @midnight-ntwrk/wallet-sdk-node-client \
  @midnight-ntwrk/wallet-sdk-prover-client \
  @midnight-ntwrk/dapp-connector-api \
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
\`\`\`

**Subsequent times (workspace exists):**

\`\`\`bash
cd .midnight-expert/verify/wallet-sdk-workspace
npm ls typescript
\`\`\`

If `npm ls` reports errors, run `npm install` to repair.

**Job directory, type assertion writing, tsc execution, interpretation, and cleanup follow the same steps as the standard SDK workspace.** The only difference is the workspace path and the installed packages.

**Mode selection:** When you receive a claim from the verifier, check the domain context:
- `domain: 'wallet-sdk'` → use `.midnight-expert/verify/wallet-sdk-workspace/`
- Otherwise → use `.midnight-expert/verify/sdk-workspace/` (existing behavior)
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/type-checker.md plugins/midnight-verify/skills/verify-by-type-check/SKILL.md
git commit -m "feat(midnight-verify): add wallet-sdk-workspace mode to type-checker

Separate workspace with @midnight-ntwrk/wallet-sdk-* packages for
wallet SDK type verification. Mode selected by domain context from
the verifier orchestrator.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 6: Update source-investigator agent

**Files:**
- Modify: `plugins/midnight-verify/agents/source-investigator.md`

- [ ] **Step 1: Add wallet SDK to the description**

In `agents/source-investigator.md`, add to the end of the `description` field, before the closing of the YAML frontmatter:

```yaml

  Example 4: Claim "ProtocolVersion is a branded bigint" — searches
  midnightntwrk/midnight-wallet for the ProtocolVersion type definition
  in packages/abstractions/src/. Uses verify-by-wallet-source for
  wallet-specific repo routing and evidence rules.
```

- [ ] **Step 2: Add verify-by-wallet-source to the skills list**

In the frontmatter `skills:` field, append `, midnight-verify:verify-by-wallet-source`:

The line currently reads:
```
skills: midnight-verify:verify-by-source
```

Change it to:
```
skills: midnight-verify:verify-by-source, midnight-verify:verify-by-wallet-source
```

- [ ] **Step 3: Add wallet SDK routing to the body**

In the body, after the existing instruction "Load the `midnight-verify:verify-by-source` skill and follow it step by step.", add:

```markdown
**When the claim domain is wallet SDK**, load `midnight-verify:verify-by-wallet-source` instead of `midnight-verify:verify-by-source`. The wallet source skill provides wallet-specific repo routing, package hierarchy context, and strict evidence rules. The general verify-by-source skill is for Compact compiler, ledger, and DApp SDK source — not wallet SDK.
```

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-verify/agents/source-investigator.md
git commit -m "feat(midnight-verify): add wallet SDK to source-investigator agent

Load verify-by-wallet-source for wallet SDK claims instead of the
general verify-by-source skill. Adds example and skill reference.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 7: Update sdk-tester agent and verify-by-devnet skill

**Files:**
- Modify: `plugins/midnight-verify/agents/sdk-tester.md`
- Modify: `plugins/midnight-verify/skills/verify-by-devnet/SKILL.md`

- [ ] **Step 1: Add wallet-devnet mode to sdk-tester description**

In `agents/sdk-tester.md`, add to the end of the `description` field:

```yaml

  Example 4: Wallet SDK behavioral claim "WalletFacade.init syncs all three
  wallets" — only reached as a fallback when source investigation was
  Inconclusive. Checks Docker container health (midnight-node, midnight-indexer,
  proof-server), then writes a test script using the wallet SDK packages.
```

- [ ] **Step 2: Add wallet-devnet mode section to verify-by-devnet**

In `skills/verify-by-devnet/SKILL.md`, after the existing "## Step 7: Clean Up" section, add:

```markdown
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
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-verify/agents/sdk-tester.md plugins/midnight-verify/skills/verify-by-devnet/SKILL.md
git commit -m "feat(midnight-verify): add wallet-devnet fallback mode to sdk-tester

Wallet SDK devnet mode uses Docker containers instead of standalone
devnet. Only reached as fallback when source investigation is Inconclusive.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 8: Create wallet-testing skill and references (midnight-cq)

**Files:**
- Create: `plugins/midnight-cq/skills/wallet-testing/SKILL.md`
- Create: `plugins/midnight-cq/skills/wallet-testing/references/effect-boundary-patterns.md`
- Create: `plugins/midnight-cq/skills/wallet-testing/references/wallet-builder-setup.md`
- Create: `plugins/midnight-cq/skills/wallet-testing/references/observable-testing.md`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p plugins/midnight-cq/skills/wallet-testing/references
```

- [ ] **Step 2: Write the main skill file**

Create `plugins/midnight-cq/skills/wallet-testing/SKILL.md` with this exact content:

```markdown
---
name: wallet-testing
description: >-
  This skill should be used when the user asks to write wallet tests, test my
  wallet variant, test my capability, test my wallet service, test WalletBuilder,
  write wallet SDK tests, test Effect code, test Observable state, mock wallet
  services, or test wallet state management. Also triggered by requests to write
  tests for custom wallet implementations, extend wallet capabilities, implement
  custom wallet services, or compose wallets with WalletBuilder.
version: 0.1.0
---

# Wallet SDK Testing

Write tests for custom wallet implementations and extensions built on the
Midnight Wallet SDK packages (`@midnight-ntwrk/wallet-sdk-*`).

## When to Use This Skill

| Question | Skill |
|----------|-------|
| Am I building a custom wallet variant or capability? | **wallet-testing** (this skill) |
| Am I integrating with the wallet via the DApp Connector API? | `dapp-connector-testing` |
| Am I testing Compact contract logic? | `compact-testing` |
| Am I testing DApp UI flows? | `dapp-testing` |

## What This Skill Covers

You are testing code that uses the wallet SDK packages directly:

- Custom wallet variants for new protocol versions
- Extended capabilities (custom coin selection, custom balancing strategies)
- Custom services (alternative proving backends, custom indexer sync)
- Wallet composition via WalletBuilder
- Code that interacts with the three wallet types (shielded, unshielded, dust) at the SDK level

## What This Skill Does NOT Cover

- Testing DApp code that integrates via the DApp Connector API (use `dapp-connector-testing`)
- Testing Compact contracts (use `compact-testing`)
- Testing DApp UI end-to-end (use `dapp-testing`)
- Enforcing the wallet SDK's internal coding standards — those are the SDK team's concern, not the user's

## The Boundary Problem

Users write their own code in whatever style they choose. But at the interface
boundary, they must interact with SDK types. These boundary interactions are
where testing gets tricky:

### 1. Unwrapping Effect/Either Results

SDK methods return `Effect<A, E>` and `Either<A, E>`. Your test code needs to
unwrap these to make assertions.

```typescript
import { Effect, Exit, Either } from 'effect';

// Happy path — unwrap Effect to get the value
it('should fetch wallet state', async () => {
  const result = await Effect.runPromise(myService.getState());
  expect(result.version).toBe(expectedVersion);
});

// Failure path — check that an Effect fails with the right error
it('should fail for invalid seed', async () => {
  const exit = await Effect.runPromiseExit(myService.init(invalidSeed));
  expect(Exit.isFailure(exit)).toBe(true);
});

// Pure capability — unwrap Either
it('should balance the transaction', () => {
  const result = myCapability.balance(state, tx);
  expect(Either.isRight(result)).toBe(true);
  if (Either.isRight(result)) {
    expect(result.right[0].inputs.length).toBeGreaterThan(0);
  }
});
```

See `references/effect-boundary-patterns.md` for complete patterns.

### 2. Asserting on Observable State

WalletFacade exposes `state(): Observable<FacadeState>`. Tests need to
subscribe, wait for specific conditions, and assert on emitted values.

```typescript
import { firstValueFrom, filter } from 'rxjs';

it('should sync all three wallets', async () => {
  const syncedState = await firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.shielded.progress.isCompleteWithin() &&
                    s.unshielded.progress.isCompleteWithin() &&
                    s.dust.progress.isCompleteWithin())
    )
  );
  expect(syncedState.shielded.availableBalances).toBeDefined();
});
```

See `references/observable-testing.md` for complete patterns.

### 3. Constructing Branded Type Fixtures

ProtocolVersion, WalletSeed, WalletState, and NetworkId are branded types.
Use the SDK's constructors — never cast raw values.

```typescript
import { ProtocolVersion } from '@midnight-ntwrk/wallet-sdk-abstractions';

const version = ProtocolVersion(8n); // Use the brand constructor
```

See `references/wallet-builder-setup.md` for all fixture patterns.

### 4. Test Doubles for SDK Interfaces

When providing custom capabilities or services to WalletBuilder, your test
double must satisfy the interface. A partial implementation will pass TypeScript
but crash at runtime.

```typescript
// Providing a test double for ProvingService
const testProvingService: ProvingServiceEffect<MyTransaction> = {
  proveTransaction: (tx) => Effect.succeed(provenTx),
};
```

See `references/wallet-builder-setup.md` for interface patterns.

### 5. WalletBuilder Test Setup

Wire up WalletBuilder with test variants and initial state:

```typescript
const TestWallet = WalletBuilder
  .init()
  .withVariant(ProtocolVersion(8n), myV8Builder)
  .build();

let wallet: InstanceType<typeof TestWallet>;

beforeEach(async () => {
  wallet = await TestWallet.startFirst(TestWallet, initialState);
});

afterEach(async () => {
  await wallet.close();
});
```

See `references/wallet-builder-setup.md` for complete setup patterns.

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Fix |
|---|---|---|
| Unwrapping Effect with try/catch | Loses typed error information; can't distinguish Effect failure from thrown exception | Use `Effect.runPromiseExit` + `Exit.isFailure` |
| Asserting on Observable without waiting | Test races the async emission; passes sometimes, fails sometimes | Use `firstValueFrom` with `filter` and a timeout |
| Constructing branded types with `as` casts | Bypasses validation; creates values the SDK would reject | Use the SDK's brand constructors (e.g., `ProtocolVersion(8n)`) |
| Partial interface implementations | Passes tsc but crashes at runtime when unimplemented method is called | Implement every method in the interface, even if some return dummy values |
| Sharing wallet instances across tests | State bleeds between tests; order-dependent failures | Create fresh wallet in `beforeEach`, close in `afterEach` |
| Not cleaning up subscriptions | Observable subscriptions leak; tests hang or interfere with each other | Unsubscribe in `afterEach` or use `firstValueFrom` (auto-completes) |

## Reference Files

| Topic | Reference |
|-------|-----------|
| Unwrapping Effect/Either, mock Layers, testing Streams | `references/effect-boundary-patterns.md` |
| WalletBuilder wiring, initial state, branded type fixtures, test doubles | `references/wallet-builder-setup.md` |
| Observable state testing, subscription cleanup, state transition assertions | `references/observable-testing.md` |
```

- [ ] **Step 3: Write effect-boundary-patterns.md reference**

Create `plugins/midnight-cq/skills/wallet-testing/references/effect-boundary-patterns.md` with this exact content:

```markdown
# Effect Boundary Patterns for Wallet SDK Tests

How to unwrap and assert on Effect/Either results from the wallet SDK in
Vitest tests.

## Effect Happy Path

Use `Effect.runPromise` to unwrap an Effect that should succeed:

```typescript
import { Effect } from 'effect';

it('should return wallet state', async () => {
  const state = await Effect.runPromise(walletService.getState());
  expect(state.version).toBe(expectedVersion);
});
```

## Effect Failure Path

Use `Effect.runPromiseExit` + `Exit.isFailure` to test expected failures:

```typescript
import { Effect, Exit } from 'effect';

it('should fail with WalletError for invalid input', async () => {
  const exit = await Effect.runPromiseExit(walletService.init(badInput));
  expect(Exit.isFailure(exit)).toBe(true);
});
```

To assert on the specific error:

```typescript
import { Effect, Exit, Cause } from 'effect';

it('should fail with InsufficientFundsError', async () => {
  const exit = await Effect.runPromiseExit(
    capability.selectCoins(emptyState, largeAmount)
  );
  expect(Exit.isFailure(exit)).toBe(true);
  if (Exit.isFailure(exit)) {
    const error = Cause.failureOption(exit.cause);
    expect(error._tag).toBe('Some');
    expect(error.value._tag).toBe('InsufficientFunds');
  }
});
```

## Effect Synchronous

Use `Effect.runSync` when the Effect has no async dependencies:

```typescript
import { Effect } from 'effect';

it('should compute balance synchronously', () => {
  const balance = Effect.runSync(pureCapability.computeBalance(state));
  expect(balance).toBe(expectedBalance);
});
```

## Either (Pure Capabilities)

Capabilities return `Either<A, E>` for pure synchronous operations:

```typescript
import { Either } from 'effect';

it('should balance transaction successfully', () => {
  const result = capability.balanceTransaction(state, tx);
  expect(Either.isRight(result)).toBe(true);
  if (Either.isRight(result)) {
    const [balancingResult, newState] = result.right;
    expect(balancingResult.inputs.length).toBeGreaterThan(0);
  }
});

it('should fail for insufficient funds', () => {
  const result = capability.balanceTransaction(emptyState, largeTx);
  expect(Either.isLeft(result)).toBe(true);
  if (Either.isLeft(result)) {
    expect(result.left._tag).toBe('InsufficientFunds');
  }
});
```

## Mock Services via Layer

When testing code that depends on SDK services, provide test doubles via
`Layer.succeed`:

```typescript
import { Effect, Layer } from 'effect';
import { ProvingService } from '@midnight-ntwrk/wallet-sdk-capabilities';

const MockProvingService = Layer.succeed(ProvingService, {
  proveTransaction: (tx) => Effect.succeed(mockProvenTx),
});

it('should use mock proving service', async () => {
  const result = await Effect.runPromise(
    myWorkflow.pipe(Effect.provide(MockProvingService))
  );
  expect(result).toBeDefined();
});
```

## Testing Effect Streams

Collect emissions from an Effect Stream:

```typescript
import { Effect, Stream } from 'effect';

it('should emit sync updates', async () => {
  const updates = await Effect.runPromise(
    syncService.updates(state).pipe(
      Stream.take(3),
      Stream.runCollect
    )
  );
  expect(updates.length).toBe(3);
});
```
```

- [ ] **Step 4: Write wallet-builder-setup.md reference**

Create `plugins/midnight-cq/skills/wallet-testing/references/wallet-builder-setup.md` with this exact content:

```markdown
# WalletBuilder Test Setup Patterns

How to wire WalletBuilder, construct initial state, provide test doubles,
and manage branded type fixtures in Vitest tests.

## Constructing Branded Types

The wallet SDK uses branded types for compile-time safety. Always use the
SDK's constructors — never cast raw values.

```typescript
import { ProtocolVersion, NetworkId } from '@midnight-ntwrk/wallet-sdk-abstractions';

// Protocol version (branded bigint)
const v8 = ProtocolVersion(8n);

// Network ID
const networkId: NetworkId = 'undeployed'; // string literal for test networks
```

For `WalletSeed`, use the HD wallet utilities:

```typescript
import { generateMnemonicWords, mnemonicToSeed } from '@midnight-ntwrk/wallet-sdk-hd';

const mnemonic = generateMnemonicWords();
const seed = mnemonicToSeed(mnemonic);
```

## WalletBuilder Composition

Set up a wallet with a test variant:

```typescript
import { WalletBuilder } from '@midnight-ntwrk/wallet-sdk-runtime';
import { ProtocolVersion } from '@midnight-ntwrk/wallet-sdk-abstractions';

const TestWallet = WalletBuilder
  .init()
  .withVariant(ProtocolVersion(8n), myVariantBuilder)
  .build();
```

## Test Lifecycle

Create a fresh wallet per test, clean up after:

```typescript
let wallet: InstanceType<typeof TestWallet>;

beforeEach(async () => {
  wallet = await TestWallet.startFirst(TestWallet, initialState);
});

afterEach(async () => {
  await wallet.close();
});
```

Never share wallet instances across tests — state bleeds cause
order-dependent failures.

## Test Doubles for Capabilities

Capabilities are pure functions returning Either. Provide a complete
implementation:

```typescript
import { Either } from 'effect';

const testBalancer = {
  balance: (state, tx) => Either.right([
    { inputs: [mockInput], outputs: [mockOutput] },
    updatedState,
  ]),
};
```

Every method in the interface must be implemented. A partial implementation
passes TypeScript but crashes at runtime when the missing method is called.

## Test Doubles for Services

Services are async (Effect-based). Provide a complete implementation:

```typescript
import { Effect } from 'effect';

const testSubmissionService = {
  submitTransaction: (tx) => Effect.succeed({
    _tag: 'Submitted',
    tx,
    txHash: 'mock-hash',
  }),
};

const testProvingService = {
  proveTransaction: (tx) => Effect.succeed(mockProvenTx),
};

const testSyncService = {
  updates: (state) => Stream.make(mockUpdate1, mockUpdate2),
};
```

## Initial State Construction

Each wallet type needs different initial state:

```typescript
// Shielded wallet — needs ZswapLocalState
const shieldedInitialState = {
  state: initialZswapLocalState,
  publicKeys: { coinPublicKey, encryptionPublicKey },
  protocolVersion: ProtocolVersion(8n),
  progress: SyncProgress.empty(),
  networkId: 'undeployed',
  coinHashes: new Map(),
};

// Unshielded wallet — needs UnshieldedState
const unshieldedInitialState = {
  state: { availableUtxos: HashMap.empty(), pendingUtxos: HashMap.empty() },
  publicKey: { publicKey: verifyingKey, addressHex: '0x...' },
  protocolVersion: ProtocolVersion(8n),
  progress: { appliedId: 0n, highestTransactionId: 0n },
  networkId: 'undeployed',
};

// Dust wallet — needs DustLocalState
const dustInitialState = {
  state: initialDustLocalState,
  publicKey: { publicKey: dustPublicKey },
  protocolVersion: ProtocolVersion(8n),
  progress: SyncProgress.empty(),
  networkId: 'undeployed',
  pendingDust: [],
};
```

Consult the wallet SDK source for the exact shape of each state type. These
examples show the general structure — field names and types come from the SDK.
```

- [ ] **Step 5: Write observable-testing.md reference**

Create `plugins/midnight-cq/skills/wallet-testing/references/observable-testing.md` with this exact content:

```markdown
# Observable Testing Patterns for Wallet SDK

How to test RxJS Observable state exposed by the wallet facade in Vitest tests.

## Subscribing and Waiting for State

Use `firstValueFrom` with `filter` to wait for a specific state condition:

```typescript
import { firstValueFrom, filter } from 'rxjs';

it('should reach synced state', async () => {
  const syncedState = await firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.shielded.progress.isCompleteWithin() &&
                    s.unshielded.progress.isCompleteWithin() &&
                    s.dust.progress.isCompleteWithin())
    )
  );
  expect(syncedState.shielded.availableBalances).toBeDefined();
}, 30_000); // timeout for slow sync
```

`firstValueFrom` auto-completes the subscription after the first matching
emission — no manual cleanup needed.

## Asserting on FacadeState Shape

The `FacadeState` combines state from all three wallets:

```typescript
it('should expose shielded balances', async () => {
  const state = await firstValueFrom(wallet.state());
  // Shielded balances are a Record<TokenType, bigint>
  expect(state.shielded.availableBalances).toBeDefined();
  expect(state.shielded.pendingBalances).toBeDefined();
});

it('should expose unshielded balances', async () => {
  const state = await firstValueFrom(wallet.state());
  expect(state.unshielded.availableUtxos).toBeDefined();
});

it('should expose dust balance', async () => {
  const state = await firstValueFrom(wallet.state());
  // Dust balance is time-dependent
  expect(state.dust.balance).toBeDefined();
});
```

## Testing State Transitions

To observe a state change after an action, subscribe before acting:

```typescript
it('should transition to pending after submit', async () => {
  // Set up the expectation before acting
  const pendingState = firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.pendingTransactions.length > 0)
    )
  );

  // Act
  await wallet.submitTransaction(tx);

  // Assert
  const state = await pendingState;
  expect(state.pendingTransactions.length).toBe(1);
});
```

## Manual Subscription Cleanup

When you need multiple emissions (not just the first match), subscribe
manually and clean up:

```typescript
import { Subscription } from 'rxjs';

let subscription: Subscription;

afterEach(() => {
  subscription?.unsubscribe();
});

it('should emit multiple state updates', async () => {
  const states: FacadeState[] = [];

  await new Promise<void>((resolve) => {
    subscription = wallet.state().subscribe((s) => {
      states.push(s);
      if (states.length >= 3) resolve();
    });
  });

  expect(states.length).toBeGreaterThanOrEqual(3);
});
```

Always unsubscribe in `afterEach` to prevent:
- Test hangs (subscription keeps the event loop alive)
- State bleed (emissions from one test leak into the next)
- Memory leaks (subscriptions accumulate across tests)

## Timeout Handling

Wallet operations (sync, proving, submission) can be slow. Use Vitest's
per-test timeout:

```typescript
it('should sync within 30 seconds', async () => {
  const synced = await firstValueFrom(
    wallet.state().pipe(
      filter((s) => s.shielded.progress.isCompleteWithin())
    )
  );
  expect(synced).toBeDefined();
}, 30_000);
```

If a test consistently times out, the wallet infrastructure may not be
running — check that the indexer, node, and proof server are available.
```

- [ ] **Step 6: Commit**

```bash
git add plugins/midnight-cq/skills/wallet-testing/
git commit -m "feat(midnight-cq): add wallet-testing skill with references

Testing guide for custom wallet implementations built on the wallet SDK
packages. Covers Effect/Either unwrapping, Observable state assertions,
branded type fixtures, WalletBuilder setup, and test double patterns.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 9: Create dapp-connector-testing skill and references (midnight-cq)

**Files:**
- Create: `plugins/midnight-cq/skills/dapp-connector-testing/SKILL.md`
- Create: `plugins/midnight-cq/skills/dapp-connector-testing/references/connector-stub-patterns.md`
- Create: `plugins/midnight-cq/skills/dapp-connector-testing/references/error-handling-patterns.md`

- [ ] **Step 1: Create the directories**

```bash
mkdir -p plugins/midnight-cq/skills/dapp-connector-testing/references
```

- [ ] **Step 2: Write the main skill file**

Create `plugins/midnight-cq/skills/dapp-connector-testing/SKILL.md` with this exact content:

```markdown
---
name: dapp-connector-testing
description: >-
  This skill should be used when the user asks to test DApp Connector API
  integration, test wallet connection, test makeTransfer, test
  balanceTransaction, test submitTransaction, mock ConnectedAPI, stub wallet
  for tests, test wallet errors, test PermissionRejected, test Disconnected
  handling, test progressive enhancement, write wallet integration tests, or
  test DApp Connector error codes.
version: 0.1.0
---

# DApp Connector API Testing

Write tests for DApp code that integrates with the wallet through the
DApp Connector API — the `window.midnight` injection, `InitialAPI.connect()`,
and the `ConnectedAPI` methods.

## When to Use This Skill

| Question | Skill |
|----------|-------|
| Am I testing my DApp's wallet integration code? | **dapp-connector-testing** (this skill) |
| Am I building a custom wallet variant or capability? | `wallet-testing` |
| Am I testing Compact contract logic? | `compact-testing` |
| Am I testing DApp UI flows end-to-end? | `dapp-testing` |

**Relationship to `dapp-testing`:** This skill covers the API contract between
your DApp and the wallet. `dapp-testing` covers Playwright E2E and UI flows.
They complement each other — use both.

## What You're Testing

### Connection Lifecycle

- Wallet discovery via `window.midnight`
- `apiVersion` validation (semver)
- `connect(networkId)` success and failure
- Disconnection and reconnection

### ConnectedAPI Methods

| Category | Methods |
|----------|---------|
| Balance queries | `getShieldedBalances`, `getUnshieldedBalances`, `getDustBalance` |
| Address queries | `getShieldedAddresses`, `getUnshieldedAddress`, `getDustAddress` |
| Transaction creation | `makeTransfer`, `makeIntent` |
| Transaction balancing | `balanceUnsealedTransaction`, `balanceSealedTransaction` |
| Transaction submission | `submitTransaction` |
| Data signing | `signData` |
| Configuration | `getConfiguration`, `getConnectionStatus` |
| Proving delegation | `getProvingProvider` |
| Permissions | `hintUsage` |

### Error Handling

The DApp Connector API defines 5 error codes. Your DApp must handle each correctly:

| Error Code | Meaning | DApp Behavior |
|---|---|---|
| `InternalError` | Wallet can't process request | Show error to user |
| `InvalidRequest` | Malformed request from DApp | Fix request, don't retry |
| `Rejected` | User rejected this specific action (transient) | Allow retry |
| `PermissionRejected` | Permission denied for method (permanent per session) | Don't retry, degrade gracefully |
| `Disconnected` | Connection lost | Attempt reconnection |

The critical distinction: `Rejected` is transient (user said "no" to one
transaction), `PermissionRejected` is permanent (user doesn't want this DApp
using that method at all). Your tests must verify your DApp handles both
correctly.

## Wallet Stub Pattern

Build a configurable test double that implements `InitialAPI` and `ConnectedAPI`:

```typescript
function createWalletStub(config?: Partial<StubConfig>): InitialAPI {
  const cfg = { ...defaultConfig, ...config };

  return {
    rdns: 'com.test.wallet',
    name: 'Test Wallet',
    icon: 'data:image/png;base64,...',
    apiVersion: '1.0.0',
    connect: async (networkId) => {
      if (cfg.connectError) throw createAPIError(cfg.connectError);
      return createConnectedStub(cfg);
    },
  };
}

function createConnectedStub(cfg: StubConfig): ConnectedAPI {
  return {
    getShieldedBalances: async () => {
      if (cfg.errors?.getShieldedBalances) throw createAPIError(cfg.errors.getShieldedBalances);
      return cfg.shieldedBalances ?? {};
    },
    getUnshieldedBalances: async () => cfg.unshieldedBalances ?? {},
    getDustBalance: async () => cfg.dustBalance ?? { cap: 0n, balance: 0n },
    // ... all other ConnectedAPI methods
    submitTransaction: async (tx) => {
      if (cfg.errors?.submitTransaction) throw createAPIError(cfg.errors.submitTransaction);
    },
  };
}
```

See `references/connector-stub-patterns.md` for complete implementations.

## Testing Error Handling

```typescript
it('should retry after Rejected', async () => {
  let callCount = 0;
  const stub = createWalletStub({
    errors: {
      submitTransaction: callCount++ === 0 ? 'Rejected' : undefined,
    },
  });
  // First call → Rejected, DApp shows "try again"
  // Second call → success
});

it('should not retry after PermissionRejected', async () => {
  const stub = createWalletStub({
    errors: { getShieldedBalances: 'PermissionRejected' },
  });
  // DApp should hide shielded balance UI, not keep calling
});

it('should attempt reconnection after Disconnected', async () => {
  const stub = createWalletStub({
    connectError: 'Disconnected',
  });
  // DApp should show reconnecting state
});
```

See `references/error-handling-patterns.md` for complete patterns.

## Progressive Enhancement Testing

Test that your DApp degrades gracefully when the wallet doesn't support
certain methods:

```typescript
it('should work without getProvingProvider', async () => {
  const stub = createWalletStub({
    errors: { getProvingProvider: 'PermissionRejected' },
  });
  // DApp should fall back to client-side proving
});

it('should work without hintUsage', async () => {
  const stub = createWalletStub({
    errors: { hintUsage: 'PermissionRejected' },
  });
  // DApp should still function, just without pre-prompted permissions
});
```

## Security Testing

The DApp Connector spec requires DApps to sanitize wallet-provided data:

```typescript
it('should sanitize wallet name to prevent XSS', () => {
  const stub = createWalletStub();
  stub.name = '<script>alert("xss")</script>';
  // Render wallet selector UI
  // Assert no script execution, name displayed as text
});

it('should render wallet icon in img tag only', () => {
  const stub = createWalletStub();
  stub.icon = 'data:image/svg+xml,...'; // SVG can contain scripts
  // Assert icon is rendered as <img src="...">, not inline SVG
});
```

## Anti-Patterns

| Anti-Pattern | Why It's Wrong | Fix |
|---|---|---|
| Not testing PermissionRejected separately from Rejected | They require different DApp responses | Write separate tests for each |
| Hard-coding balance values in assertions | Brittle; values change with stub config | Assert on structure and relationships |
| Not testing Disconnected recovery | Users will lose connection | Test reconnection flow |
| Testing only happy-path connect | Real wallets reject connections | Test connect with every error code |
| Skipping hintUsage testing | Wallet may prompt user based on hints | Test that DApp sends hints before method calls |
| Using wallet stub for contract logic testing | Wrong tool; contract logic needs the simulator | Use `compact-testing` for contract logic |

## Reference Files

| Topic | Reference |
|-------|-----------|
| Complete ConnectedAPI stub, factory functions, scenario configurations | `references/connector-stub-patterns.md` |
| Error code test patterns, progressive enhancement, XSS prevention | `references/error-handling-patterns.md` |
```

- [ ] **Step 3: Write connector-stub-patterns.md reference**

Create `plugins/midnight-cq/skills/dapp-connector-testing/references/connector-stub-patterns.md` with this exact content:

```markdown
# DApp Connector Stub Patterns

Complete test double implementations for `InitialAPI` and `ConnectedAPI`.

## API Error Factory

```typescript
type ErrorCode = 'InternalError' | 'Rejected' | 'InvalidRequest' | 'PermissionRejected' | 'Disconnected';

function createAPIError(code: ErrorCode, reason?: string): Error & { type: string; code: ErrorCode; reason: string } {
  const error = new Error(reason ?? code) as Error & { type: string; code: ErrorCode; reason: string };
  error.type = 'DAppConnectorAPIError';
  error.code = code;
  error.reason = reason ?? code;
  return error;
}
```

## Stub Configuration

```typescript
interface StubConfig {
  // Balance data
  shieldedBalances: Record<string, bigint>;
  unshieldedBalances: Record<string, bigint>;
  dustBalance: { cap: bigint; balance: bigint };

  // Address data
  shieldedAddresses: {
    shieldedAddress: string;
    shieldedCoinPublicKey: string;
    shieldedEncryptionPublicKey: string;
  };
  unshieldedAddress: { unshieldedAddress: string };
  dustAddress: { dustAddress: string };

  // Configuration
  configuration: {
    indexerUri: string;
    indexerWsUri: string;
    substrateNodeUri: string;
    networkId: string;
  };
  connectionStatus: { status: 'connected'; networkId: string } | { status: 'disconnected' };

  // Error injection (per method)
  connectError?: ErrorCode;
  errors?: Partial<Record<keyof ConnectedAPI, ErrorCode>>;

  // Transaction behavior
  onSubmit?: (tx: string) => void;
}

const defaultConfig: StubConfig = {
  shieldedBalances: {},
  unshieldedBalances: {},
  dustBalance: { cap: 5000000000000000n, balance: 1000000000000000n },
  shieldedAddresses: {
    shieldedAddress: 'mn_shield-addr1...',
    shieldedCoinPublicKey: 'mn_shield-cpk1...',
    shieldedEncryptionPublicKey: 'mn_shield-epk1...',
  },
  unshieldedAddress: { unshieldedAddress: 'mn_addr1...' },
  dustAddress: { dustAddress: 'mn_dust1...' },
  configuration: {
    indexerUri: 'http://localhost:6300/api/v3/graphql',
    indexerWsUri: 'ws://localhost:6300/api/v3/graphql/ws',
    substrateNodeUri: 'ws://localhost:9944',
    networkId: 'undeployed',
  },
  connectionStatus: { status: 'connected', networkId: 'undeployed' },
};
```

## InitialAPI Stub

```typescript
function createWalletStub(config?: Partial<StubConfig>): InitialAPI {
  const cfg: StubConfig = { ...defaultConfig, ...config };

  return Object.freeze({
    rdns: 'com.test.wallet',
    name: 'Test Wallet',
    icon: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
    apiVersion: '1.0.0',
    connect: async (networkId: string) => {
      if (cfg.connectError) throw createAPIError(cfg.connectError);
      return createConnectedStub(cfg);
    },
  });
}
```

## ConnectedAPI Stub

```typescript
function createConnectedStub(cfg: StubConfig): ConnectedAPI {
  const maybeThrow = (method: keyof ConnectedAPI) => {
    const code = cfg.errors?.[method];
    if (code) throw createAPIError(code);
  };

  return {
    getShieldedBalances: async () => { maybeThrow('getShieldedBalances'); return cfg.shieldedBalances; },
    getUnshieldedBalances: async () => { maybeThrow('getUnshieldedBalances'); return cfg.unshieldedBalances; },
    getDustBalance: async () => { maybeThrow('getDustBalance'); return cfg.dustBalance; },

    getShieldedAddresses: async () => { maybeThrow('getShieldedAddresses'); return cfg.shieldedAddresses; },
    getUnshieldedAddress: async () => { maybeThrow('getUnshieldedAddress'); return cfg.unshieldedAddress; },
    getDustAddress: async () => { maybeThrow('getDustAddress'); return cfg.dustAddress; },

    getTxHistory: async (pageNumber: number, pageSize: number) => {
      maybeThrow('getTxHistory');
      return [];
    },

    makeTransfer: async (desiredOutputs, options) => {
      maybeThrow('makeTransfer');
      return { tx: 'mock-transfer-tx' };
    },
    makeIntent: async (desiredInputs, desiredOutputs, options) => {
      maybeThrow('makeIntent');
      return { tx: 'mock-intent-tx' };
    },

    balanceUnsealedTransaction: async (tx, options) => {
      maybeThrow('balanceUnsealedTransaction');
      return { tx: 'mock-balanced-tx' };
    },
    balanceSealedTransaction: async (tx, options) => {
      maybeThrow('balanceSealedTransaction');
      return { tx: 'mock-balanced-sealed-tx' };
    },

    submitTransaction: async (tx) => {
      maybeThrow('submitTransaction');
      cfg.onSubmit?.(tx);
    },

    signData: async (data, options) => {
      maybeThrow('signData');
      return { data, signature: 'mock-signature', verifyingKey: 'mock-key' };
    },

    getConfiguration: async () => { maybeThrow('getConfiguration'); return cfg.configuration; },
    getConnectionStatus: async () => { maybeThrow('getConnectionStatus'); return cfg.connectionStatus; },

    getProvingProvider: async (keyMaterialProvider) => {
      maybeThrow('getProvingProvider');
      return {
        check: async (serializedPreimage, keyLocation) => [0n],
        prove: async (serializedPreimage, keyLocation) => new Uint8Array([0]),
      };
    },

    hintUsage: async (methodNames) => { maybeThrow('hintUsage'); },
  };
}
```

## Factory Functions for Common Scenarios

```typescript
/** Wallet with funded balances */
function createFundedWallet(overrides?: Partial<StubConfig>) {
  return createWalletStub({
    shieldedBalances: { '0x00': 1000n },
    unshieldedBalances: { '0x00': 500n },
    dustBalance: { cap: 5000000000000000n, balance: 3000000000000000n },
    ...overrides,
  });
}

/** Wallet with zero balances */
function createEmptyWallet(overrides?: Partial<StubConfig>) {
  return createWalletStub({
    shieldedBalances: {},
    unshieldedBalances: {},
    dustBalance: { cap: 0n, balance: 0n },
    ...overrides,
  });
}

/** Wallet that disconnects immediately */
function createDisconnectedWallet() {
  return createWalletStub({ connectError: 'Disconnected' });
}

/** Wallet that rejects all permissions */
function createRestrictedWallet(methods: (keyof ConnectedAPI)[]) {
  const errors: Partial<Record<keyof ConnectedAPI, ErrorCode>> = {};
  for (const method of methods) {
    errors[method] = 'PermissionRejected';
  }
  return createWalletStub({ errors });
}
```

## Injecting Stubs

### Unit/Integration Tests (direct import)

```typescript
import { createFundedWallet } from '../stubs/wallet-stub';

let wallet: ConnectedAPI;

beforeEach(async () => {
  const stub = createFundedWallet();
  wallet = await stub.connect('undeployed');
});
```

### E2E Tests (Playwright addInitScript)

```typescript
test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    const stub = {
      rdns: 'com.test.wallet',
      name: 'Test Wallet',
      icon: 'data:image/png;base64,...',
      apiVersion: '1.0.0',
      connect: async () => ({
        getShieldedBalances: async () => ({ '0x00': 1000n }),
        getUnshieldedBalances: async () => ({}),
        getDustBalance: async () => ({ cap: 0n, balance: 0n }),
        // ... minimal stub for E2E scenario
        submitTransaction: async () => {},
      }),
    };
    Object.defineProperty(window, 'midnight', {
      value: { [crypto.randomUUID()]: Object.freeze(stub) },
      writable: false,
      configurable: false,
    });
  });
});
```
```

- [ ] **Step 4: Write error-handling-patterns.md reference**

Create `plugins/midnight-cq/skills/dapp-connector-testing/references/error-handling-patterns.md` with this exact content:

```markdown
# DApp Connector Error Handling Test Patterns

Test patterns for each of the 5 DApp Connector API error codes.

## Error Code Taxonomy

| Code | Transient? | DApp Response | Test Strategy |
|---|---|---|---|
| `InternalError` | Maybe | Show error, allow retry | Inject error, assert UI shows message |
| `InvalidRequest` | No | Fix request, don't retry | Should not happen with correct code; test guards |
| `Rejected` | Yes | Allow user to retry | Inject on first call, succeed on second |
| `PermissionRejected` | No (per session) | Degrade gracefully | Inject error, assert feature is hidden/disabled |
| `Disconnected` | Yes | Reconnect | Inject error, assert reconnection attempt |

## Testing Rejected vs PermissionRejected

This is the most important distinction. `Rejected` means "not this time",
`PermissionRejected` means "not ever (this session)".

```typescript
describe('submitTransaction error handling', () => {
  it('should allow retry after Rejected', async () => {
    let attempts = 0;
    const stub = createWalletStub({
      errors: {
        // Only reject the first attempt
        submitTransaction: 'Rejected',
      },
    });

    const wallet = await stub.connect('undeployed');

    // First attempt — rejected
    await expect(wallet.submitTransaction('tx')).rejects.toMatchObject({
      code: 'Rejected',
    });

    // DApp should show "try again" UI, not disable the button
    // (assert on your DApp's state/UI here)
  });

  it('should disable feature after PermissionRejected', async () => {
    const stub = createWalletStub({
      errors: { submitTransaction: 'PermissionRejected' },
    });

    const wallet = await stub.connect('undeployed');

    await expect(wallet.submitTransaction('tx')).rejects.toMatchObject({
      code: 'PermissionRejected',
    });

    // DApp should disable submit button for this session
    // DApp should NOT retry
    // (assert on your DApp's state/UI here)
  });
});
```

## Testing Disconnected Recovery

```typescript
describe('disconnection handling', () => {
  it('should detect disconnection and attempt reconnect', async () => {
    const stub = createWalletStub({
      connectionStatus: { status: 'disconnected' },
    });

    const wallet = await stub.connect('undeployed');
    const status = await wallet.getConnectionStatus();

    expect(status.status).toBe('disconnected');
    // DApp should show "reconnecting..." state
    // DApp should call connect() again
  });

  it('should handle Disconnected error during operation', async () => {
    const stub = createWalletStub({
      errors: { getShieldedBalances: 'Disconnected' },
    });

    const wallet = await stub.connect('undeployed');

    await expect(wallet.getShieldedBalances()).rejects.toMatchObject({
      code: 'Disconnected',
    });

    // DApp should show reconnection UI
    // DApp should retry after reconnection
  });
});
```

## Testing Progressive Enhancement

Test that your DApp works with reduced API surface:

```typescript
describe('progressive enhancement', () => {
  it('should work without proving delegation', async () => {
    const stub = createWalletStub({
      errors: { getProvingProvider: 'PermissionRejected' },
    });

    const wallet = await stub.connect('undeployed');

    // DApp should fall back to client-side proving
    // DApp should NOT show an error
    // Core functionality (transfers, balances) should still work
  });

  it('should work without hintUsage', async () => {
    const stub = createWalletStub({
      errors: { hintUsage: 'PermissionRejected' },
    });

    const wallet = await stub.connect('undeployed');

    // DApp should still function
    // Permission prompts may appear per-method instead of upfront
  });

  it('should work with all balance methods rejected', async () => {
    const stub = createRestrictedWallet([
      'getShieldedBalances',
      'getUnshieldedBalances',
      'getDustBalance',
    ]);

    const wallet = await stub.connect('undeployed');

    // DApp should hide balance display
    // Transfer functionality may be limited
    // DApp should NOT crash
  });
});
```

## Testing XSS Prevention

The spec requires DApps to sanitize wallet-provided name and icon:

```typescript
describe('wallet name/icon sanitization', () => {
  it('should render wallet name as text, not HTML', () => {
    const stub = createWalletStub();
    // Override name with XSS payload
    (stub as any).name = '<img src=x onerror=alert(1)>';

    // Render your wallet selector component with this stub
    // Assert: the name appears as literal text, no tag interpretation
    // Assert: no script execution occurred
  });

  it('should render wallet icon in img tag only', () => {
    const stub = createWalletStub();
    // Override with SVG that could contain scripts
    (stub as any).icon = 'data:image/svg+xml,<svg onload="alert(1)"/>';

    // Render your wallet selector component with this stub
    // Assert: icon is rendered as <img src="...">, not inline <svg>
  });
});
```

## Testing apiVersion Validation

```typescript
describe('wallet version validation', () => {
  it('should reject incompatible wallet version', () => {
    const stub = createWalletStub();
    (stub as any).apiVersion = '0.1.0'; // too old

    // DApp should check semver compatibility before calling connect()
    // Assert: DApp shows "wallet version not supported" message
  });

  it('should accept compatible wallet version', () => {
    const stub = createWalletStub();
    stub.apiVersion = '1.2.0'; // compatible with ^1.0.0

    // DApp should proceed with connection
  });
});
```

## Testing Duplicate Wallet Detection

```typescript
describe('duplicate wallet detection', () => {
  it('should warn if multiple wallets share the same rdns', () => {
    const stub1 = createWalletStub();
    const stub2 = createWalletStub();
    // Both have rdns: 'com.test.wallet'

    // Inject both into window.midnight with different UUIDs
    // DApp should detect the duplicate rdns and warn the user
  });
});
```
```

- [ ] **Step 5: Commit**

```bash
git add plugins/midnight-cq/skills/dapp-connector-testing/
git commit -m "feat(midnight-cq): add dapp-connector-testing skill with references

Testing guide for DApp Connector API integration. Covers connection
lifecycle, all ConnectedAPI methods, configurable wallet stubs, error
code handling (Rejected vs PermissionRejected), progressive enhancement,
and XSS prevention testing.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 10: Update midnight-cq plugin metadata and documentation

**Files:**
- Modify: `plugins/midnight-cq/.claude-plugin/plugin.json`
- Modify: `plugins/midnight-cq/README.md`

- [ ] **Step 1: Update plugin.json keywords**

In `plugins/midnight-cq/.claude-plugin/plugin.json`, add these keywords to the `keywords` array:

```json
"wallet-sdk",
"wallet-testing",
"dapp-connector",
"effect",
"observable",
"WalletBuilder",
"WalletFacade"
```

The full keywords array after the change:

```json
"keywords": [
  "midnight",
  "compact",
  "biome",
  "vitest",
  "playwright",
  "testing",
  "linting",
  "formatting",
  "ci",
  "github-actions",
  "husky",
  "code-quality",
  "wallet-sdk",
  "wallet-testing",
  "dapp-connector",
  "effect",
  "observable",
  "WalletBuilder",
  "WalletFacade"
]
```

- [ ] **Step 2: Update README.md**

In `plugins/midnight-cq/README.md`, after the existing `### dapp-testing` section, add:

```markdown
### wallet-testing

Write tests for custom wallet implementations and extensions built on the Midnight Wallet SDK packages (`@midnight-ntwrk/wallet-sdk-*`). Covers Effect/Either unwrapping at the SDK boundary, Observable state assertions, branded type fixture construction, WalletBuilder test setup, and test double patterns for capabilities and services.

**Triggers on**: write wallet tests, test my wallet variant, test my capability, test my wallet service, test WalletBuilder, write wallet SDK tests, test Effect code, test Observable state, mock wallet services, test wallet state management

### dapp-connector-testing

Write tests for DApp Connector API integration — the `window.midnight` injection, `InitialAPI.connect()`, and `ConnectedAPI` methods. Covers configurable wallet stubs implementing the full ConnectedAPI, error code handling (Rejected vs PermissionRejected), progressive enhancement testing, and XSS prevention.

**Triggers on**: test DApp Connector API, test wallet connection, test makeTransfer, test balanceTransaction, mock ConnectedAPI, stub wallet for tests, test wallet errors, test PermissionRejected, test progressive enhancement
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/.claude-plugin/plugin.json plugins/midnight-cq/README.md
git commit -m "docs(midnight-cq): add wallet-testing and dapp-connector-testing to metadata

Update plugin.json keywords and README documentation for the two new
testing skills.

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 11: Update midnight-cq agents to recognize wallet SDK projects

**Files:**
- Modify: `plugins/midnight-cq/agents/cq-runner.md`
- Modify: `plugins/midnight-cq/agents/cq-reviewer.md`

- [ ] **Step 1: Update cq-runner agent**

In `plugins/midnight-cq/agents/cq-runner.md`, in the body's "### Step 1: Detect Project Type" section, add these rows to the detection table:

```markdown
| `@midnight-ntwrk/wallet-sdk-*` in `package.json` deps | Wallet SDK project — check for Effect/Either test patterns |
| `@midnight-ntwrk/dapp-connector-api` in `package.json` deps | DApp Connector integration — check for connector stub tests |
```

- [ ] **Step 2: Update cq-reviewer agent**

In `plugins/midnight-cq/agents/cq-reviewer.md`, in the body's "### Step 1 — Load Skills" section, add to the list of skills to load:

```markdown
- `midnight-cq:wallet-testing` — defines correct Effect boundary patterns, WalletBuilder setup, Observable testing for wallet SDK projects
- `midnight-cq:dapp-connector-testing` — defines correct ConnectedAPI stub patterns, error handling, progressive enhancement for DApp Connector projects
```

In the "### Step 2 — Scan Tooling Presence" section, add these rows to the tooling inventory checklist:

```markdown
| Wallet SDK deps | `Grep @midnight-ntwrk/wallet-sdk in package.json` | Determines if Wallet SDK project |
| DApp Connector deps | `Grep @midnight-ntwrk/dapp-connector-api in package.json` | Determines if DApp Connector project |
| Wallet test doubles | `Glob **/test/**/wallet-stub*.ts` | If wallet SDK or connector project |
| Effect test patterns | `Grep Effect.runPromise in **/*.test.ts` | If wallet SDK project |
```

In the "### Step 5 — Assess Test Quality" section, add after the existing DApp test quality checks:

```markdown
**Wallet SDK test quality checks (if wallet SDK project):**

| Check | Good Pattern | Bad Pattern | Severity |
|-------|-------------|------------|---------|
| Effect results unwrapped correctly | `Effect.runPromise()` / `Effect.runPromiseExit()` | `try/catch` around Effect | Warning |
| Observable subscriptions cleaned up | `afterEach` with unsubscribe or `firstValueFrom` used | Subscriptions never cleaned up | Critical |
| Branded types constructed correctly | SDK constructors like `ProtocolVersion(8n)` | Raw casts like `8n as ProtocolVersion` | Warning |
| Fresh wallet per test | `beforeEach` creates new wallet, `afterEach` closes | Shared wallet instance across tests | Critical |

**DApp Connector test quality checks (if DApp Connector project):**

| Check | Good Pattern | Bad Pattern | Severity |
|-------|-------------|------------|---------|
| All 5 error codes tested | Separate tests for Rejected and PermissionRejected | Only happy-path tests | Warning |
| Progressive enhancement tested | Tests with PermissionRejected for optional methods | No degradation tests | Suggestion |
| Wallet name/icon sanitized | XSS prevention tests for name and icon | No sanitization tests | Warning |
| apiVersion validated | Semver check before connect | No version validation | Warning |
```

- [ ] **Step 3: Commit**

```bash
git add plugins/midnight-cq/agents/cq-runner.md plugins/midnight-cq/agents/cq-reviewer.md
git commit -m "feat(midnight-cq): update agents to recognize wallet SDK projects

cq-runner detects wallet SDK and DApp Connector dependencies.
cq-reviewer loads new skills and audits wallet-specific test quality
patterns (Effect unwrapping, Observable cleanup, branded types, error codes).

Co-Authored-By: Claude Code <noreply@anthropic.com>"
```

---

## Task 12: Final verification

- [ ] **Step 1: Verify all new files exist**

```bash
echo "=== midnight-verify new files ==="
ls -la plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md
ls -la plugins/midnight-verify/skills/verify-by-wallet-source/SKILL.md

echo "=== midnight-cq wallet-testing ==="
ls -la plugins/midnight-cq/skills/wallet-testing/SKILL.md
ls -la plugins/midnight-cq/skills/wallet-testing/references/effect-boundary-patterns.md
ls -la plugins/midnight-cq/skills/wallet-testing/references/wallet-builder-setup.md
ls -la plugins/midnight-cq/skills/wallet-testing/references/observable-testing.md

echo "=== midnight-cq dapp-connector-testing ==="
ls -la plugins/midnight-cq/skills/dapp-connector-testing/SKILL.md
ls -la plugins/midnight-cq/skills/dapp-connector-testing/references/connector-stub-patterns.md
ls -la plugins/midnight-cq/skills/dapp-connector-testing/references/error-handling-patterns.md
```

Expected: all 9 files exist.

- [ ] **Step 2: Verify all YAML frontmatter is valid**

```bash
for f in \
  plugins/midnight-verify/skills/verify-wallet-sdk/SKILL.md \
  plugins/midnight-verify/skills/verify-by-wallet-source/SKILL.md \
  plugins/midnight-cq/skills/wallet-testing/SKILL.md \
  plugins/midnight-cq/skills/dapp-connector-testing/SKILL.md; do
  echo "--- $f ---"
  head -3 "$f"
  echo ""
done
```

Expected: each file starts with `---` on line 1 and has a `name:` field on line 2.

- [ ] **Step 3: Count total commits**

```bash
git log --oneline HEAD~11..HEAD
```

Expected: 11 commits (1 design spec + 10 implementation commits from Tasks 1-11).

- [ ] **Step 4: Verify git status is clean**

```bash
git status
```

Expected: clean working tree, nothing to commit.
