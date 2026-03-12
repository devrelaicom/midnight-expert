---
description: Systematic debugging for Compact smart contracts — analyzes errors, investigates root causes, and guides fixes
allowed-tools: Bash, Read, Task, AskUserQuestion, Skill
argument-hint: [<file.compact> | "<error message>" | --interactive]
---

Systematic debugging for Compact smart contracts. Analyzes contract files, investigates root causes, and guides fixes using the compact-debugging methodology.

## Step 1 — Parse Arguments

Analyze `$ARGUMENTS` to determine invocation mode:

| Input | Mode | Next Step |
|-------|------|-----------|
| Path ending in `.compact` | File analysis | Step 2 |
| Quoted string or multiline text | Error text | Step 4 (pass error text as context) |
| Nothing or `--interactive` | Interactive | Step 4 (skill starts triage) |
| Unrecognized input | Clarification | Ask user to provide a `.compact` file path or error text |

If no arguments provided and not `--interactive`, jump to Step 4. If a file path is provided, verify it exists before proceeding to Step 2. If not found, use AskUserQuestion to clarify the path.

## Step 2 — Concurrent Analysis

Only when file path is provided. Dispatch two Task agents in parallel in a single message:

### Agent A — Static Analysis

Prompt the Task agent:

> You are analyzing a Compact smart contract for potential issues. Read the contract file at `<FILE_PATH>` and check against these known mistake patterns:
>
> **Syntax patterns:**
> - Deprecated `ledger { }` block syntax (should be individual `export ledger` declarations)
> - `Void` return type (should be `[]`)
> - `Enum::variant` double-colon syntax (should be `Enum.variant` dot notation)
> - Witness declarations with body `{ }` (should end with `;`, implementation in TypeScript)
> - `pure function` keyword (should be `pure circuit`)
> - `Cell<T>` wrapper (removed in v0.15, use type directly)
> - Pragma with patch version like `0.14.0` (should be `>= 0.16 && <= 0.18` format)
>
> **Hallucinated stdlib functions** (these do NOT exist in Compact):
> `public_key()`, `verify_signature()`, `random()`, `hash()`, `encrypt()`, `decrypt()`, `sign()`, `verify()`, `to_string()`, `from_string()`, `concat()`, `slice()`, `length()`, `push()`, `pop()`, `map()`, `filter()`, `reduce()`, `sort()`, `reverse()`, `contains()`, `indexOf()`, `toString()`
>
> **Disclosure patterns:**
> - Witness return values or circuit parameters flowing to ledger writes without `disclose()`
> - Witness-derived values used in `if` conditions without `disclose()`
> - Witness-derived values returned from exported circuits without `disclose()`
>
> **Type cast issues:**
> - Direct `Uint` to `Bytes` cast (needs `Field` intermediary)
> - Direct `Boolean` to `Field` cast (needs `Uint<0..1>` intermediary)
> - Arithmetic results not cast back to target type (e.g., `(a + b) as Uint<64>`)
>
> Return ONLY structured lines in this exact format, one per finding:
> `LOCATION | CATEGORY | DESCRIPTION | SEVERITY`
>
> Where SEVERITY is: `error` (will fail compilation), `warning` (likely issue), `info` (style/best practice)
>
> If no issues found, return: `NONE | info | No issues detected by static analysis | info`

### Agent B — Compilation

Prompt the Task agent:

> You are compiling a Compact smart contract to check for errors.
>
> Try these approaches in order:
> 1. Check if the MCP tool `midnight-compile-contract` is available. If so, call it with the file path and `skipZk=true`. (Note: MCP tool name is tentative — it may not exist yet.)
> 2. If MCP unavailable, try CLI: `compact compile <FILE_PATH> /tmp/compact-debug-out --skip-zk`
> 3. If `compact` CLI is not installed, return: `COMPILATION_UNAVAILABLE | info | Compact compiler not available — verify manually | info`
>
> If compilation succeeds, return: `NONE | info | Compilation successful (skipZk) | info`
>
> If compilation fails, parse each error and return structured lines:
> `LOCATION | CATEGORY | DESCRIPTION | SEVERITY`
>
> Where LOCATION is `line N` from the error, CATEGORY is one of: `parse`, `type`, `disclosure`, `unbound`, `runtime`, `other`, and SEVERITY is `error`.

## Step 3 — Present Consolidated Findings

Parse the structured lines returned from both agents. Merge into a single report:

```
## Contract Analysis: <filename>

### Errors Found
| # | Location | Category | Description |
|---|----------|----------|-------------|
| 1 | line 12  | disclosure | Witness value flows to ledger without disclose() |
| 2 | line 25  | type | Uint<64> to Bytes<32> requires intermediate Field cast |

### Warnings
| # | Location | Category | Description |
|---|----------|----------|-------------|
| 1 | line 3   | pragma | Version range may not match installed compiler |

### Compilation
[Compiler output or "Compilation tools unavailable — verify manually"]
```

Then use AskUserQuestion to ask:

> "Are there other errors you're seeing, or additional context you'd like to provide before we investigate?"

## Step 4 — Hand Off to Skill

Use the Skill tool to invoke `compact-core:compact-debugging`. Pass context based on mode:
- **File analysis mode:** Include the consolidated findings from Step 3 and any user-provided additional context
- **Error text mode:** Include the error text from `$ARGUMENTS`
- **Interactive mode:** The skill will start its own symptom-driven triage

State to the user: "Now entering systematic investigation using the compact-debugging methodology."
