# Service Error Examples

## When This Error Occurs

The compilation request failed due to infrastructure issues — rate limiting, timeouts, or service outages. These are not code errors. The compiler did not evaluate the Compact code.

## Examples

### 429 Rate Limit

**Error:**
`HTTP 429: Rate limit exceeded`

**Context:**
Too many compile calls within the 60-second window. Limits: 20 requests/60s for `midnight-compile-contract`, 10 requests/60s for `midnight-compile-archive`.

**Recovery:**
1. Wait for the rate limit window to reset (up to 60 seconds)
2. Batch all code fixes before recompiling — do not recompile after every single-line fix
3. If consistently hitting limits, consider switching to local compilation for the session

**Before (wasteful pattern):**
```
Compile → 1 error → fix line 5 → Compile → 1 error → fix line 12 → Compile → ...
(3+ calls for what could be 1)
```

**After (efficient pattern):**
```
Compile → 3 errors on lines 5, 12, 20 → fix all three → Compile once
(2 calls total)
```

### Compilation timeout

**Error:**
`Compilation did not complete within the timeout window`

**Context:**
Complex contracts with many circuits or full ZK compilation on large contracts can exceed the server-side timeout.

**Recovery:**
1. Use `skipZk: true` if you don't need ZK artifacts — syntax-only validation is much faster
2. For very large contracts, use local compilation where there is no server-side timeout
3. If `skipZk: true` also times out, the contract may be too complex for the hosted service — fall back to local compilation

**Before (timeout-prone):**
```
midnight-compile-contract({ code: "<large contract>", fullCompile: true })
→ Timeout after 60s
```

**After (adjusted approach):**
```
midnight-compile-contract({ code: "<large contract>", skipZk: true })
→ Syntax validation in 2s

For full ZK compilation of large contracts, use local compilation:
compactc build contract.compact
```

### Service unavailable (5xx)

**Error:**
`HTTP 500`, `HTTP 502`, or `HTTP 503`

**Context:**
The playground service may be sleeping (Fly.io cold start) or experiencing an outage. This is an infrastructure issue, not a code problem.

**Recovery:**
1. Wait 5 seconds and retry once
2. If the error persists, fall back to local compilation
3. Do not modify the code — the code was never evaluated

**Before (wrong response):**
```
Compile → HTTP 502 → "There might be a syntax error" → modify code → Compile
(Code was never the problem)
```

**After (correct response):**
```
Compile → HTTP 502 → wait 5 seconds → Compile (same code)
→ If still failing: switch to local compilation
```

## Anti-Patterns

### Rapid-fire recompilation when rate limited

**Wrong:** Immediately retrying compilation when receiving a 429 error.
**Problem:** Each retry counts against the rate limit window. Rapid retries keep you rate-limited longer and waste the entire window. The rate limit resets after 60 seconds of reduced usage.
**Instead:** Fix all errors first, then submit one compile call. If rate limited, wait for the window to reset before retrying.

### Assuming service errors mean the code is wrong

**Wrong:** Modifying the Compact code after receiving a 429, timeout, or 5xx error.
**Problem:** Service errors are infrastructure issues. The code was not evaluated by the compiler — there is no feedback about code correctness in a service error. Changing the code in response to a service error introduces unnecessary modifications.
**Instead:** Retry the same code after the issue resolves. Only modify code in response to `CompilerError` messages with `severity: "error"`.
