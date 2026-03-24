---
name: mcp-format
description: This skill should be used when the user asks about formatting Compact code, midnight-format-contract, Compact code style, code formatting via MCP, presenting Compact code, cleaning up Compact code, or formatting with a specific compiler version. This skill should also be used proactively whenever the LLM is about to present Compact code to the user.
---

# MCP-Hosted Compact Formatting

Format Compact code using the hosted formatter via the `midnight-format-contract` MCP tool.

## Default Behavior: Always Format Before Presenting

Whenever you are about to present Compact code to the user — whether you wrote it, found it via search, pulled it from a file, or are including it in documentation — format it first using `midnight-format-contract`. This applies to:

- Code blocks in responses
- Code written to files
- Code included in generated documentation
- Code examples shown during explanations

Do not use local `compact format` for this. The MCP format tool is preferred because:

- **No disk writes.** It accepts code as a string and returns formatted code as a string. Local `compact format` modifies files in place — you would need to write to a temp file, format, read back, and clean up.
- **No risk of accidental file modification.** Running local `compact format` on a user's source file permanently modifies it. The MCP tool is read-only.
- **Version-specific formatting.** Local `compact format` cannot target a specific compiler version — it always uses the default set by `compact update`. The MCP tool accepts a `version` parameter, so you can format for any installed version without disrupting the user's toolchain.

## When to Use Local Instead

These are the user's own workflows — recommend local `compact format` when they ask about them.

| Condition | Recommend |
|-----------|-----------|
| User wants to format their source files in place | `midnight-tooling:compact-cli` (`compact format`) |
| CI pipeline format checking | `midnight-tooling:compact-cli` (`compact format --check`) |
| Pre-commit hook format enforcement | `midnight-tooling:compact-cli` (`compact format --check`) |

## Tool Reference

### `midnight-format-contract`

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `code` | string | Yes | — | Compact source code to format |
| `version` | string | No | — | Compiler version to use for formatting (e.g., `"0.29.0"`) |
| `versions` | string[] | No | — | Format with multiple compiler versions for consistency testing |

### Response — Success

```json
{
  "success": true,
  "formatted": "// The formatted source code",
  "changed": true,
  "diff": "- old line\n+ new line"
}
```

When `changed` is `false`, the code was already correctly formatted. No `diff` is returned.

### Response — Failure

```json
{
  "success": false,
  "errors": [{ "message": "Parse error details", "severity": "error" }]
}
```

### Response — Multi-Version

When using the `versions` parameter, each version returns its own result with a `requestedVersion` field:

```json
[
  { "success": true, "formatted": "...", "changed": true, "diff": "...", "requestedVersion": "0.29.0" },
  { "success": true, "formatted": "...", "changed": false, "requestedVersion": "0.28.0" }
]
```

## Usage Patterns

**Format generated code before presenting:**
Call `midnight-format-contract` with the code. Use the `formatted` field in your response. If `changed: false`, the code was already well-formatted.

**Format code from a file for display:**
Read the file, pass its content to `midnight-format-contract`. Present the `formatted` result. Do NOT run local `compact format` on the file — that would modify it.

**Format for style review:**
Call format, show the `diff` to the user. This highlights style issues without modifying any files.

**Version-specific formatting:**
Set `version` to the target compiler version. Use this when the project targets a specific Compact version and you want formatting consistent with that version's rules.

**Multi-version consistency check:**
Use `versions` array to format with multiple compiler versions. Compare the `formatted` output across versions to check for formatting differences between versions.

## Error Handling

**Parse failure:** The formatter must parse the code before formatting. If the code has syntax errors, formatting will fail.

- If you compiled the code first and it passed → format it (guaranteed to parse)
- If the code is from a known-good source (user file, search result) → try formatting
  - Success → present formatted
  - Parse error → present unformatted, note the syntax issues
- If the code failed compilation → do not attempt formatting. Fix the code first via `mcp-compile`, then format.

**Version not available:** The requested compiler version is not installed on the playground. Fall back to omitting the `version` parameter (uses default/latest version) or inform the user.

**429 rate limit:** Present the code unformatted. Do not retry immediately. The format tool shares the 20 requests per 60 seconds limit.

**5xx / service unavailable:** Present the code unformatted. Do not fall back to local `compact format` — the risk of accidental file modification outweighs the formatting benefit.

**Timeout:** The formatter has a 10-second timeout. Extremely large inputs could hit this. Present unformatted.

**General principle:** Formatted code is better than unformatted code, but unformatted code is better than no code. Never block a response because formatting failed.

## Guidance

- **Formatting is deterministic.** Call once per code block, reuse the result. Do not re-format the same code.
- **Format does not affect compilation.** Whitespace and style are irrelevant to the compiler. Do not format code as a troubleshooting step for compilation errors.
- **Format after final edits.** If you are iterating on code (write → compile → fix → compile), format once at the end when the code is finalized, not on every iteration.
- **Respect `changed: false`.** If the code is already correctly formatted, do not mention formatting in your response — just present the code.

## Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Local formatting (in-place, CI, pre-commit) | `midnight-tooling:compact-cli` |
| MCP-hosted compilation | `mcp-compile` |
| Analysis, visualization, diffing | `mcp-analyze` |
| Tool routing and category overview | `mcp-overview` |
