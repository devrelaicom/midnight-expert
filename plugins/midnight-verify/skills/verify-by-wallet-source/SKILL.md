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
- Whether devnet E2E testing might resolve it (the orchestrator decides whether to dispatch)
