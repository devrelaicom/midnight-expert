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
