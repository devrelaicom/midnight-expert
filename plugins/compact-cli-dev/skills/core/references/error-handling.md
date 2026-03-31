# Error Handling Reference

Covers error classification, the ErrorCode enum, formatting, BaseCommand integration, and patterns for adding new error types.

---

## Error Classification

The `classifyError()` function inspects an error's message and returns a structured `ClassifiedError`:

```typescript
interface ClassifiedError {
  code: ErrorCode;
  message: string;
  action: string;
}

export function classifyError(err: unknown): ClassifiedError {
  const message = err instanceof Error ? err.message : String(err);
  const lower = message.toLowerCase();

  if (lower.includes("dust") || lower.includes("no dust") || lower.includes("insufficient fee")) {
    return {
      code: ErrorCode.DUST_REQUIRED,
      message,
      action: `Run \`${CLI_NAME} dust:register <wallet>\` to generate DUST tokens.`,
    };
  }

  // ... more patterns ...

  return {
    code: ErrorCode.UNKNOWN,
    message,
    action: "Check the devnet logs for more details.",
  };
}
```

Classification works by substring matching on the lowercased error message. The first matching pattern wins.

---

## ErrorCode Enum

| Code | Triggers When | Suggested Action |
|------|--------------|-----------------|
| `DUST_REQUIRED` | Message contains "dust", "no dust", or "insufficient fee" | Run `dust:register <wallet>` |
| `SERVICE_DOWN` | Connection refused to port 6300 (proof server) | Run `devnet:start` |
| `SERVICE_DOWN` | Connection refused to port 8088 (indexer) or 9944 (node) | Run `devnet:status` to check services |
| `CONTRACT_NOT_FOUND` | Message contains "contract" and "not found" | Verify contract address and devnet status |
| `SYNC_TIMEOUT` | Message contains "timeout" or "timed out" | Wait for devnet to start, then retry |
| `WALLET_NOT_FOUND` | Thrown by `getWallet()` when name not in store | Run `wallet:create <name>` |
| `INVALID_SEED` | Thrown by `deriveKeys()` on bad seed length | Check seed is exactly 64 hex characters |
| `STALE_UTXO` | Transaction fails due to spent inputs | Retry — wallet state is stale |
| `UNKNOWN` | No pattern matches | Check devnet logs |

```typescript
export enum ErrorCode {
  DUST_REQUIRED = "DUST_REQUIRED",
  SERVICE_DOWN = "SERVICE_DOWN",
  CONTRACT_NOT_FOUND = "CONTRACT_NOT_FOUND",
  WALLET_NOT_FOUND = "WALLET_NOT_FOUND",
  STALE_UTXO = "STALE_UTXO",
  SYNC_TIMEOUT = "SYNC_TIMEOUT",
  INVALID_SEED = "INVALID_SEED",
  UNKNOWN = "UNKNOWN",
}
```

---

## `formatError()`

Produces a single-line error message with an action hint:

```typescript
export function formatError(classified: ClassifiedError): string {
  return `Error [${classified.code}]: ${classified.message}\n  → ${classified.action}`;
}
```

Example output:

```
Error [DUST_REQUIRED]: No dust available for fee payment
  → Run `my-cli dust:register default` to generate DUST tokens.
```

---

## How BaseCommand Uses Classification

`BaseCommand.catch()` is the Oclif error handler. It classifies every error and outputs the result in the appropriate format:

```typescript
async catch(err: unknown): Promise<void> {
  const classified = classifyError(err);
  if (this.jsonEnabled) {
    this.log(
      JSON.stringify(
        { error: classified.code, message: classified.message, action: classified.action },
        null, "\t",
      ),
    );
  } else {
    this.error(formatError(classified));
  }
}
```

In JSON mode, errors are structured objects:

```json
{
  "error": "SERVICE_DOWN",
  "message": "Proof server is not reachable at localhost:6300.",
  "action": "Run `my-cli devnet:start` to start all services."
}
```

In normal mode, the `this.error()` call prints the formatted string and exits with a non-zero code.

---

## Error-to-Action Mapping

| Error Code | CLI Action |
|------------|-----------|
| `DUST_REQUIRED` | `dust:register <wallet>` |
| `SERVICE_DOWN` (proof server) | `devnet:start` |
| `SERVICE_DOWN` (indexer/node) | `devnet:status` |
| `CONTRACT_NOT_FOUND` | Verify address, check `devnet:status` |
| `SYNC_TIMEOUT` | Wait and retry |
| `WALLET_NOT_FOUND` | `wallet:create <name>` |
| `INVALID_SEED` | Fix seed input (64 hex chars) |
| `STALE_UTXO` | Retry the operation |
| `UNKNOWN` | Check devnet logs |

---

## Adding New Error Classifications

To classify a new error type:

1. Add a new value to the `ErrorCode` enum
2. Add a detection block in `classifyError()` before the `UNKNOWN` fallback
3. Include a helpful `action` string that tells the user what to do

```typescript
// In errors.ts:

export enum ErrorCode {
  // ... existing codes ...
  PROOF_TIMEOUT = "PROOF_TIMEOUT",
  UNKNOWN = "UNKNOWN",
}

export function classifyError(err: unknown): ClassifiedError {
  const message = err instanceof Error ? err.message : String(err);
  const lower = message.toLowerCase();

  // ... existing patterns ...

  // Add new pattern before the UNKNOWN fallback:
  if (lower.includes("proof") && lower.includes("timeout")) {
    return {
      code: ErrorCode.PROOF_TIMEOUT,
      message,
      action: "The proof server may be overloaded. Check `devnet:status` and retry.",
    };
  }

  return {
    code: ErrorCode.UNKNOWN,
    message,
    action: "Check the devnet logs for more details.",
  };
}
```

Pattern matching tips:
- Use `lower.includes()` for substring matching (case-insensitive via the lowercased message)
- Combine multiple conditions with `&&` for specificity (e.g., port number + "econnrefused")
- Place more specific patterns before broader ones — first match wins
