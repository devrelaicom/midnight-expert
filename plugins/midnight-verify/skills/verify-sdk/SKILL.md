---
name: midnight-verify:verify-sdk
description: >-
  SDK/TypeScript claim classification and method routing. Determines what
  kind of SDK claim is being verified and which verification method applies:
  type-checking (tsc --noEmit), devnet E2E testing, source inspection, or
  package checks. Handles both claims about the SDK API itself and
  verification of user code that uses the SDK. Loaded by the verifier
  agent alongside the hub skill.
version: 0.4.0
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
| Witness implementation | "This witness correctly implements the contract interface" | **witness-verifier** |
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
