---
name: midnight-status-codes:status-codes
description: >-
  Use when an agent encounters a Midnight error code, error message, or
  error type and needs to identify what it means, what component produced
  it, and how to fix it. Routes to the correct reference file based on
  error source and characteristics. Covers numeric node error codes
  (0-255), TypeScript SDK error classes, Effect tagged wallet errors,
  Compact compiler diagnostics, ZK proof errors, ledger validation
  errors, proof server HTTP errors, indexer GraphQL errors, and DApp
  Connector API errors.
---

# Midnight Error Code Routing

When you encounter a Midnight error, use this decision tree to find the right reference file.

## Quick Lookup

For the fastest path, use the lookup command instead of reading reference files:

```
/midnight-status-codes:lookup <code-or-search-term>
```

## Decision Tree

### 1. Numeric code (0-255) from a node or transaction submission

Read `references/node-errors.md`

These are `LedgerApiError` codes that surface via Substrate's `InvalidTransaction::Custom(u8)` in Substrate transaction validation. The reference file has the complete code table organized by range.

**Recognise by:** A bare number in an error message from the Midnight node, transaction pool rejection, or `DispatchError::Module` output.

### 2. TypeScript error class from `@midnight-ntwrk/midnight-js-*`

Read `references/sdk-errors.md`

**Recognise by:** Error class names like `TxFailedError`, `DeployTxFailedError`, `CallTxFailedError`, `ContractTypeError`, `InvalidProtocolSchemeError`, `PrivateStateImportError`, `IndexerFormattedError`. These are standard JavaScript `Error` subclasses thrown by the midnight-js SDK packages.

### 3. Effect tagged error with `_tag` like `Wallet.*`

Read `references/wallet-errors.md`

**Recognise by:** Error objects with a `_tag` field matching patterns like `Wallet.Other`, `Wallet.InsufficientFunds`, `Wallet.Transacting`, `SubmissionError`, `ConnectionError`, `TransactionInvalidError`. These are Effect `Data.TaggedError` instances from the wallet SDK.

### 4. Effect typed error from `@midnight-ntwrk/compact-js`

Read `references/sdk-errors.md`

**Recognise by:** Error type names `ContractRuntimeError`, `ContractConfigurationError`, `ZKConfigurationReadError`, `ConfigError`, `ConfigCompilationError`, `ParseError`. These use `Symbol.for()` TypeIds and are part of the compact-js Effect error system.

### 5. Compact compiler message with source location

Read `references/compiler-errors.md`

**Recognise by:** Error messages with file path, line number, and character position (e.g., `/path/to/file.compact line 42 char 5:`). Also compiler exit codes (0, 1, 254, 255) and messages like "unbound identifier", "parse error: found X looking for Y", "potential witness-value disclosure".

### 6. Runtime error from compiled contract execution

Read `references/runtime-errors.md`

**Recognise by:** `CompactError` class name in the stack frame, or message prefixes `"failed assert:"`, `"type error:"`, `"range error at"`, `"expected ..."`, `"Version mismatch:"`, `"Maximum field mismatch:"`, `"State map ..."`, `"State ... cannot be cast to"`, or `"Expected 32-byte string"`. Notably *no* file/line/char source location — these come from `@midnight-ntwrk/compact-runtime`, not the compiler.

### 7. ZK proof error mentioning PLONK, circuit, ZKIR, or verification

Read `references/zk-errors.md`

**Recognise by:** Error messages containing "Synthesis error", "constraint system", "NotEnoughRowsAvailable", "wrong arity", PLONK-related terms, or proof verification failures.

### 8. Transaction validation or malformed transaction error (Rust-level)

Read `references/ledger-errors.md`

**Recognise by:** Rust error names like `MalformedTransaction`, `TransactionInvalid`, `OnchainProgramError`, `TranscriptRejected`, `MalformedOffer`, or messages about binding commitments, sequencing checks, effects mismatches.

### 9. HTTP status code from the proof server

Read `references/proof-server-errors.md`

**Recognise by:** HTTP status codes (400, 428, 429, 500, 503) from requests to port 6300 or a proof server URL. Also job status messages like "job queue full" or "bad input".

### 10. GraphQL error or HTTP status from the indexer

Read `references/indexer-errors.md`

**Recognise by:** GraphQL error responses from port 8088 or an indexer URL. Messages like "invalid block hash", "invalid viewing key", "indexer has not yet caught up with the node". HTTP status codes 400, 413, 503 from the indexer API.

### 11. DApp Connector `APIError`

Read `references/dapp-connector-errors.md`

**Recognise by:** Error objects with `type: 'DAppConnectorAPIError'` and a `code` field matching `Disconnected`, `InternalError`, `InvalidRequest`, `PermissionRejected`, or `Rejected`.

### 12. Not sure which source

If the error doesn't clearly match any category above:

1. Try the lookup command: `/midnight-status-codes:lookup <error-text-or-code>`
2. Search by keyword: `/midnight-status-codes:lookup --search "<key-phrase>"`
3. If still not found, the error may be from a dependency (Substrate, Effect, Polkadot.js) rather than Midnight-specific code.
