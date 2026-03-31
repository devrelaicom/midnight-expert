---
name: midnight-verify:verify-sdk
description: >-
  SDK/TypeScript claim classification and method routing. Determines what
  kind of SDK claim is being verified and which verification method applies:
  type-checking (tsc --noEmit), devnet E2E testing, source inspection, or
  package checks. Handles both claims about the SDK API itself and
  verification of user code that uses the SDK. Loaded by the /verify command
  alongside the hub skill.
version: 0.4.0
---

# SDK Claim Classification

This skill classifies SDK/TypeScript claims and determines which verification method to use. The /verify command loads this alongside the `midnight-verify:verify-correctness` hub skill.

## Claim Type → Method Routing

When you receive an SDK-related claim, classify it using this table to determine which agent(s) to dispatch:

### Claims About the SDK API

| Claim Type | Example | Dispatch |
|---|---|---|
| API function exists | "deployContract is exported from contracts" | @"midnight-verify:type-checker (agent)" |
| Function signature / return type | "deployContract returns DeployedContract" | @"midnight-verify:type-checker (agent)" |
| Type/interface shape | "MidnightProviders has a walletProvider field" | @"midnight-verify:type-checker (agent)" |
| Import path correctness | "import { deployContract } from '@midnight-ntwrk/midnight-js-contracts'" | @"midnight-verify:type-checker (agent)" |
| Error class hierarchy | "CallTxFailedError extends TxFailedError" | @"midnight-verify:type-checker (agent)" |
| Package exists / version | "@midnight-ntwrk/midnight-js-contracts is at version 4.0.2" | @"devs:deps-maintenance (agent)" (fallback: run `npm view` directly) |
| Export count / package structure | "contracts package exports 91 symbols" | @"midnight-verify:source-investigator (agent)" |
| Implementation details | "httpClientProofProvider retries 3 times with exponential backoff" | @"midnight-verify:source-investigator (agent)" |
| Provider internal behavior | "LevelDB provider encrypts with AES-256-GCM" | @"midnight-verify:source-investigator (agent)" |
| Deploy/call lifecycle behavior | "deployContract deploys and returns a contract address" | @"midnight-verify:sdk-tester (agent)" |
| Transaction pipeline behavior | "submitCallTx proves, balances, submits, and waits" | @"midnight-verify:sdk-tester (agent)" |
| State query behavior | "getPublicStates returns on-chain ledger state" | @"midnight-verify:sdk-tester (agent)" |

### Claims About User Code That Uses the SDK

| Claim Type | Example | Dispatch |
|---|---|---|
| DApp code type-correctness | "This provider setup code is valid" | @"midnight-verify:type-checker (agent)" |
| Witness implementation | "This witness correctly implements the contract interface" | @"midnight-verify:witness-verifier (agent)" |
| Provider configuration | "This provider config connects to devnet correctly" | @"midnight-verify:type-checker (agent)" + @"midnight-verify:sdk-tester (agent)" |
| Import usage patterns | "This file's SDK imports are correct" | @"midnight-verify:type-checker (agent)" |
| Transaction handling code | "This error handling catches CallTxFailedError" | @"midnight-verify:type-checker (agent)" |
| E2E integration | "This deploy+call flow works against devnet" | @"midnight-verify:sdk-tester (agent)" |
| File verification (`.ts` with SDK imports) | `/verify app.ts` | @"midnight-verify:type-checker (agent)" (types) + @"midnight-verify:sdk-tester (agent)" (behavior, if devnet available) |
| Cross-domain (types + behavior) | "calling increment changes counter from 0 to 1" | @"midnight-verify:type-checker (agent)" + @"midnight-verify:sdk-tester (agent)" (concurrent) |

### Routing Rules

**When in doubt:**
- Types, signatures, imports, interfaces → @"midnight-verify:type-checker (agent)"
- Runtime behavior, what happens when you call something → @"midnight-verify:sdk-tester (agent)"
- Internal implementation, how something works under the hood → @"midnight-verify:source-investigator (agent)"
- Package versions, existence → @"devs:deps-maintenance (agent)" (or `npm view` fallback)

**When multiple methods apply, dispatch concurrently.** Type-checking and devnet testing are independent and can run in parallel.

## Hints from Existing Skills

Sub-agents may load these skills for context. They are **hints only** — never cite skill content as evidence in the verdict.

- `dapp-development:midnight-sdk` skill — provider setup, component overview
- `dapp-development:dapp-connector` skill — wallet integration patterns
- `compact-core:compact-witness-ts` skill — witness implementation patterns
- `compact-core:compact-deployment` skill — deployment patterns

Load only what's relevant to the specific claim.
