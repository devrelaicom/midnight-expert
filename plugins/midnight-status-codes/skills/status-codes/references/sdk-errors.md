# Midnight SDK Error Reference

> **Last verified:** 2026-05-04 — class-based family against `midnightntwrk/midnight-js@main` (`@midnight-ntwrk/midnight-js` and friends, all v4.0.4); Effect-based family against published npm tarballs of `@midnight-ntwrk/compact-js@2.5.0`, `@midnight-ntwrk/compact-js-command@2.5.0`, `@midnight-ntwrk/platform-js@2.2.4`, `@midnight-ntwrk/compact-runtime@0.16.0` (sourced from private repo `midnight-ntwrk/artifacts`).

## Overview

This reference covers errors from two SDK families:

- **compact-js family** — Effect-based errors using `@effect/io` patterns. These appear as typed failures in Effect pipelines and are discriminated via TypeId tags and guard functions.
- **midnight-js family** — Class-based errors that extend `Error` or `TypeError`. These are thrown directly and caught with `instanceof` checks or `.catch()` handlers.

---

## compact-js SDK Errors

Package: `@midnight-ntwrk/compact-js`

These errors surface as the failure channel of Effect programs. The top-level union type for contract execution is `ContractExecutionError`.

### ContractConfigurationError

TypeId: `compact-js/effect/ContractConfigurationError`

Raised when contract configuration fails before execution begins — missing keys, missing verifier keys, or undefined circuits.

Guard function: `isConfigurationError(e)`

Fields:
- `message: string`
- `cause?: unknown`
- `contractState?: unknown`

| Known Message | Cause | Fix |
|---|---|---|
| `"Failed to configure constructor context with coin public key"` | No coin public key available in wallet/provider | Ensure the wallet is unlocked and a coin public key can be derived |
| `"Failed to find a verifier key for circuit '${id}'"` | Verifier key not found for the named circuit | Verify ZK assets are correctly published and the circuit ID matches |
| `"Circuit '${id}' is undefined for the given contract state"` | Circuit name does not exist in the compiled contract | Check contract ABI and circuit name spelling |
| `"Signing key required to authorize contract maintenance update"` | No signing key provided for a maintenance operation | Supply a signing key when calling maintenance operations |

---

### ContractRuntimeError

TypeId: `compact-js/effect/ContractRuntimeError`

General runtime error during contract execution. Wraps unexpected failures and errors from circuit execution.

Guard function: `isRuntimeError(e)`

Fields:
- `message: string`
- `cause?: unknown`

| Known Message | Cause | Fix |
|---|---|---|
| `"Failed to initialize contract"` | Contract could not be instantiated | Check contract address, network connectivity, and provider state |
| `"Error executing circuit '${id}'"` | Circuit execution threw or returned an error | Inspect `cause` for the underlying error; check circuit inputs |
| `String(err)` (stringified inner error) | Lazy `getContract()` instantiation failed; the message is just the inner error stringified | Inspect `cause` for the underlying error |

> The previous reference listed three additional messages — `"Unexpected error converting runtime contract state"`, `"Failed to apply maintenance operation"`, `"Invalid number of arguments"` — that are **not present in `compact-js@2.5.0`**. They may have been retired or never existed in this exact form. Removed pending source confirmation.

---

### ZKConfigurationReadError

TypeId: `compact-js/effect/ZKConfigurationReadError`

Raised when a ZK asset (verifier key, ZKIR, or prover key) cannot be read from the asset provider.

Guard function: `isReadError(e)`

Fields:
- `message: string` — auto-generated: `` `Failed to read ${assetType.replaceAll('-', ' ')} for ${contractTag}#${provableCircuitId}` ``. Note dashes in `assetType` are replaced with spaces, so the rendered message reads e.g. `"Failed to read verifier key for ..."` (not `"verifier-key"`).
- `cause?: unknown`
- `contractTag: string`
- `provableCircuitId: string`
- `assetType: 'verifier-key' | 'ZKIR' | 'prover-key'`

| Asset Type | Meaning | Fix |
|---|---|---|
| `'verifier-key'` | On-chain verifier key could not be read | Check that verifier keys are published for this contract version |
| `'ZKIR'` | ZK intermediate representation could not be read | Verify the ZK asset bundle is accessible |
| `'prover-key'` | Prover key could not be fetched | Check prover key source URL and network access |

---

### ContractExecutionError (union)

`ContractExecutionError = ContractRuntimeError | ContractConfigurationError | ZKConfigurationReadError`

This is the failure channel type of `ContractExecutable`. When handling errors from contract calls, narrow to the specific type using the guard functions before acting.

```typescript
Effect.catchAll(error => {
  if (isConfigurationError(error)) { /* ... */ }
  if (isRuntimeError(error))       { /* ... */ }
  if (isReadError(error))          { /* ... */ }
})
```

---

## compact-js-command Errors

Package: `@midnight-ntwrk/compact-js-command`

These errors arise in CLI and build tooling that processes Compact configuration files.

### ConfigError

TypeId: `compact-js-command/effect/ConfigError`

Raised when a configuration file cannot be read or processed.

| Known Message | Cause | Fix |
|---|---|---|
| `"Unexpected error while compiling TypeScript configuration"` | Unhandled exception during TS compilation of config | Check config file syntax; inspect `cause` for details |
| `"Error loading configuration '${filePath}'"` | Config file at path could not be loaded | Verify the file exists and is valid JS/TS |

---

### ConfigCompilationError

TypeId: `compact-js-command/effect/ConfigCompilationError`

Raised when the TypeScript compiler reports diagnostics while compiling a config file.

Fields:
- `message: string` — `"Failed to compile TypeScript configuration"`
- `diagnostics: ts.Diagnostic[]`

Fix: Inspect `diagnostics` for the specific TypeScript errors. Common causes are type mismatches in configuration objects or missing required fields.

---

## platform-js Errors

Package: `@midnight-ntwrk/platform-js`

### ParseError

TypeId: `platform-js/effect/ParseError`

Raised when a hex string fails to parse.

Guard function: `isParseError(e)`

Fields:
- `message: string`
- `source: string`
- `meta?: unknown`
- `cause?: unknown`

| Known Message | Cause | Fix |
|---|---|---|
| `"Source string must have non-zero length"` | Empty string passed | Ensure input is non-empty before parsing |
| `"Source string '${s}' is not a valid hex-string"` | String contains non-hex characters | Validate input is a hex-encoded string |
| `"Last byte of source string '${s}' is incomplete"` | Odd-length hex string | Hex strings must have an even number of characters |
| `"Invalid hex-digit '${c}' found in source string at index ${pos}"` | A non-hex character at a specific position (verbatim from `platform-js/dist/esm/effect/internal/hex.js`) | Inspect character at `pos` in the source string |

---

## midnight-js-contracts Errors

Package: `@midnight-ntwrk/midnight-js-contracts`

Class-based errors thrown during contract deployment and transaction submission. Use `instanceof` to distinguish them.

### TxFailedError (base)

Extends: `Error`

Base class for all transaction-not-applied errors. A transaction was submitted and processed, but consensus did not apply it.

Fields:
- `finalizedTxData` — finalized transaction data from the node
- `circuitId?: AnyProvableCircuitId | AnyProvableCircuitId[]` — present on subclasses that carry circuit context. Note this is **not** a plain `string` — it can be a single id or an array of ids.

> **Message format:** `super('Transaction failed')` is called, but the constructor immediately overwrites `this.message` with `JSON.stringify({ circuitId?, ...finalizedTxData })`. So `error.message` is a JSON-stringified payload, not the literal string `"Transaction failed"`.

Subclasses:

| Class | Extends | Description |
|---|---|---|
| `DeployTxFailedError` | `TxFailedError` | Deploy transaction was not applied |
| `CallTxFailedError` | `TxFailedError` | Contract call transaction was not applied; carries `circuitId` |
| `ReplaceMaintenanceAuthorityTxFailedError` | `TxFailedError` | Replace maintenance authority tx failed |
| `RemoveVerifierKeyTxFailedError` | `TxFailedError` | Remove verifier key tx failed |
| `InsertVerifierKeyTxFailedError` | `TxFailedError` | Insert verifier key tx failed |

Fix: Inspect `finalizedTxData` for the transaction result and segment statuses. Check the `TxStatus` and `SegmentStatus` values (see enums below) to understand which segment failed and why.

---

### ScopedTransactionIdentityMismatchError

**Added in `@midnight-ntwrk/midnight-js-contracts` v3.2.0.**

Extends: `Error`

Raised when cached states from one contract are used for a different contract or with a different `privateStateId`. Scoped transactions must target the same contract address and private-state identity throughout their lifecycle.

Fields:
- `cached: { contractAddress: string; privateStateId?: PrivateStateId }`
- `requested: { contractAddress: string; privateStateId?: PrivateStateId }`

Message: `Cannot use cached states from contract '${cached.contractAddress}' (privateStateId: '${cached.privateStateId}') for contract '${requested.contractAddress}' (privateStateId: '${requested.privateStateId}'). Scoped transactions must target the same contract and private state identity.`

Fix: Either re-fetch state for the requested contract or restart the scoped transaction flow.

---

### isEffectContractError (interop predicate)

`@midnight-ntwrk/midnight-js-contracts` exports an interop predicate that lets class-based callers detect Effect-thrown errors that have leaked into the class-based world:

```ts
interface EffectContractError {
  readonly _tag: string;
  readonly cause: { readonly name: string; readonly message: string };
}
export const isEffectContractError = (error: unknown): error is EffectContractError => ...
```

Use it as a bridge between the Effect-based `compact-js` family and the class-based `midnight-js` family.

---

### ContractTypeError

Extends: `TypeError`

Raised when one or more operations are undefined or have mismatched verifier keys for the deployed contract state.

Fields:
- `contractState: ContractState`
- `circuitIds: AnyProvableCircuitId[]` — the circuits that did not resolve

Message format: `` `Following operations: ${circuitIds.join(', ')}, are undefined or have mismatched verifier keys for contract state ${contractState.toString(false)}` ``

Fix: Verify the contract address corresponds to the contract type being used. The actual trigger is verifier-key mismatch on operation lookup — re-deploy if the contract was replaced, or check that you're calling the right operations for this contract version.

---

### IncompleteCallTxPrivateStateConfig

Extends: `Error`

Raised when `privateStateId` is set in a call transaction config but `privateStateProvider` is not provided.

Message: `"'privateStateId' was defined for call transaction while 'privateStateProvider' was undefined"`

Fix: Either provide both `privateStateId` and `privateStateProvider`, or omit `privateStateId` entirely.

---

### IncompleteFindContractPrivateStateConfig

Extends: `Error`

Raised when `initialPrivateState` is set in a find-contract config but `privateStateId` is not provided.

Message: `"'initialPrivateState' was defined for contract find while 'privateStateId' was undefined"`

Fix: Provide `privateStateId` when supplying `initialPrivateState`, so the state can be stored and retrieved consistently.

---

## midnight-js-types Errors

Package: `@midnight-ntwrk/midnight-js-types`

### InvalidProtocolSchemeError

Extends: `Error`

Raised when a URL is provided with an unexpected protocol scheme.

Fields:
- `invalidScheme: string` — the scheme that was found
- `allowableSchemes: string[]` — the schemes that are accepted

Message format: `` `Invalid protocol scheme: '${invalidScheme}'. Allowable schemes are one of: ${allowableSchemes.join(',')}` ``

Fix: Update the URL to use one of the `allowableSchemes`. Common cases: using `http://` where `https://` is required, or `ws://` where `wss://` is required.

---

### PrivateStateImportError (base)

Extends: `Error`

Base class for private state import failures.

Fields:
- `cause?: PrivateStateImportErrorCause` — **optional** in current source, with type `'decryption_failed' | 'invalid_format' | 'conflict' | 'unknown'`

Subclasses:

| Class | Cause Value | Description | Fix |
|---|---|---|---|
| `ExportDecryptionError` | `'decryption_failed'` | Decryption failed — wrong password or corrupt export | Verify the password used during export matches the one used for import |
| `InvalidExportFormatError` | `'invalid_format'` | Export data has an unrecognized format | Ensure the export file has not been modified or truncated |
| `ImportConflictError` | `'conflict'` | Import data conflicts with existing private state; carries `conflictCount` | Resolve or clear the conflicting state before importing, or use a merge strategy |
| (base only) | `'unknown'` or absent | Catch-all when the cause cannot be determined | Inspect the underlying error for context |

---

### PrivateStateExportError

Extends: `Error`

Raised when exporting private state fails. Inspect the error message for details.

Fix: Check that the private state provider is accessible and the state is not corrupted.

---

### SigningKeyExportError

Extends: `Error`

Raised when exporting a signing key fails.

Fix: Ensure the key exists and the wallet is in a state that permits key export.

---

## midnight-js-utils Inline Throws

Package: `@midnight-ntwrk/midnight-js-utils` (v4.0.4)

These utility helpers raise plain `Error` and `TypeError` instances inline — no `_tag`, no class hierarchy beyond the JS built-ins. Catch with `try/catch` and match by message substring.

| File | Throw Type | Message | Fix |
|------|------------|---------|-----|
| `assertion-utils.ts` | `Error` | `"Expected value to be defined"` (default; `assertDefined` accepts an override) | Ensure the value is non-null before calling, or pass a descriptive custom message. |
| `assertion-utils.ts` | `Error` | `"Expected value to be null or undefined"` (default; `assertUndefined` accepts an override) | Ensure the value is null/undefined before calling, or pass a descriptive custom message. |
| `hex-utils.ts` | `TypeError` | `"Input string must have non-zero length."` | Pass a non-empty string to `assertIsHex`; validate input upstream so empty values do not reach the assertion. |
| `hex-utils.ts` | `Error` | `"Expected byte length must be greater than zero."` | Pass a positive integer for `byteLen`, or omit it to allow any length. |
| `hex-utils.ts` | `TypeError` | `` `The last byte of input string '${source}' is incomplete.` `` | Pad the hex string so its byte portion has an even number of characters, or fix the upstream encoder. |
| `hex-utils.ts` | `TypeError` | `` `Invalid hex-digit '${char}' found in input string at index ${pos}.` `` | Sanitise the input to contain only `[0-9A-Fa-f]` characters (with optional `0x` prefix); the message identifies the position. |
| `hex-utils.ts` | `TypeError` | `` `Input string '${source}' is not a valid hex-string.` `` | Provide a hex string that contains at least one whole byte (two hex characters) of content. |
| `hex-utils.ts` | `TypeError` | `` `Expected an input string with byte length of ${byteLen}, got ${actualByteLen}.` `` | Ensure the hex input represents exactly `byteLen` bytes (`byteLen * 2` hex characters), or pass the correct expected length. |
| `type-utils.ts` | `TypeError` | `` `Unexpected '0x' prefix in contract address '${contractAddress}'` `` | Strip the leading `0x` from the contract address before passing it to `assertIsContractAddress` or any API expecting a `ContractAddress`. |

Source paths are relative to `packages/utils/src/` in `midnightntwrk/midnight-js`. All entries are catalogued in `codes.json` under the `JsUtils.*` code namespace and grouped as `"midnight-js-utils inline throws"`.

---

## midnight-js-indexer-public-data-provider Errors

Package: `@midnight-ntwrk/midnight-js-indexer-public-data-provider`

### IndexerFormattedError

Extends: `Error`

Wraps one or more GraphQL errors returned by the indexer.

Fields:
- `cause: readonly GraphQLFormattedError[]`

Fix: Inspect each entry in `cause` for the specific GraphQL error messages. Common causes: invalid queries, indexer not synced, requested data not yet indexed. Check indexer logs if the error persists.

---

## compact-runtime Errors

Package: `@midnight-ntwrk/compact-runtime` (generated Compact contract JS)

These errors are thrown from compiled Compact code at runtime, not from SDK infrastructure.

### CompactError

Extends: `Error`

Raised by compiled Compact code when a runtime invariant is violated.

---

### assert

```typescript
assert(b: boolean, s: string): void
```

Throws with message: `"failed assert: ${s}"` when `b` is `false`.

This appears in generated Compact JS for `assert` statements in Compact source. The message `s` is the string argument from the Compact `assert` expression.

Fix: The assertion in the contract code evaluated to false. This is a contract-level invariant violation — review the contract logic and the inputs that triggered the circuit.

---

### typeError

```typescript
typeError(who: string, what: string, where: string, type: string, x: unknown): never
```

Throws a type error in generated JS. Arguments describe: the component (`who`), what was expected (`what`), where the check occurred (`where`), the expected type (`type`), and the actual value (`x`).

Fix: This indicates a type invariant was violated in generated Compact JS. Typically caused by an SDK version mismatch or corrupt contract state data.

---

## Transaction Status Enums

### TxStatus

Applied to a transaction as a whole.

| Value | Meaning |
|---|---|
| `'FailEntirely'` | The entire transaction was rejected — no segments were applied |
| `'FailFallible'` | The fallible segment failed, but the infallible segment was applied (fees consumed) |
| `'SucceedEntirely'` | All segments were applied successfully |

---

### SegmentStatus

Applied to individual segments within a transaction.

| Value | Meaning |
|---|---|
| `'SegmentSuccess'` | This segment was applied successfully |
| `'SegmentFail'` | This segment failed |

---

### TransactionResultStatus (GraphQL / Indexer)

Returned by the indexer in GraphQL responses.

| Value | Meaning |
|---|---|
| `'FAILURE'` | Transaction failed entirely |
| `'PARTIAL_SUCCESS'` | Transaction partially applied (fallible segment failed, infallible segment applied) |
| `'SUCCESS'` | Transaction fully applied |

These map approximately to `TxStatus` as: `FAILURE` → `FailEntirely`, `PARTIAL_SUCCESS` → `FailFallible`, `SUCCESS` → `SucceedEntirely`.
