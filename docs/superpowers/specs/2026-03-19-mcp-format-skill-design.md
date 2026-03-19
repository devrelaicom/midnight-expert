# MCP Format Skill — Design Specification

**Date:** 2026-03-19
**Plugin:** `midnight-mcp`
**Skill:** `mcp-format` (new, extracted from `mcp-analyze`)
**Status:** Draft

## Problem

The `midnight-format-contract` tool is buried inside the `mcp-analyze` skill alongside 6 other tools. Its documentation is minimal (16 lines), lists the wrong parameter name (`source` instead of `code`), and provides no guidance on when or how the LLM should use it. More importantly, the LLM has no instruction to format Compact code as a default behavior — it currently presents raw, unformatted code to users.

## Goals

1. Extract MCP-hosted formatting into its own dedicated skill with accurate documentation
2. Position the MCP format tool as the LLM's **primary** formatter — used by default whenever presenting Compact code
3. Make the case strongly for MCP over local formatting for LLM workflows
4. Cover error handling so the LLM degrades gracefully when formatting fails
5. Update `mcp-analyze` to remove the format tool and cross-reference the new skill

## Non-Goals

- Redesigning `mcp-analyze` beyond removing the format tool
- Adding a slash command
- Documenting local `compact format` (owned by `midnight-tooling:compact-cli`)

## Architecture

Single-file skill — `SKILL.md` only, no reference files or example files. The format tool is simple enough (1 tool, 3 parameters, 1 response shape, small error space) that everything fits inline without progressive disclosure.

The key design work is in the **positioning**: instructing the LLM to reach for this tool as a default behavior, not just when asked.

### Consumer

The LLM, operating autonomously. The skill instructs the LLM to format Compact code before presenting it, similar to how a developer would run Prettier before committing.

### Boundary with Other Skills

- `mcp-format` owns: MCP-hosted formatting, when to format, how to interpret results, error handling
- `midnight-tooling:compact-cli` owns: local `compact format` for in-place file formatting, CI `--check` mode, pre-commit hooks
- `mcp-compile` owns: compilation (formatting does not affect compilation)

## Why MCP Format Over Local

The LLM should prefer `midnight-format-contract` over local `compact format` for three reasons:

1. **No disk writes required.** Local `compact format` modifies files in place. The LLM would need to write code to a temporary file, format it, read it back, then clean up. The MCP tool accepts a string and returns a string — no filesystem side effects.

2. **No risk of accidental file modification.** If the LLM runs local `compact format` on existing source files to display them formatted, it permanently modifies those files. The MCP tool is read-only — it cannot modify user files.

3. **Version-specific formatting without toolchain disruption.** Local `compact format` cannot target a specific compiler version — it always uses the default set by `compact update`. To format with a different version locally, the user would need to change their toolchain default (and change it back). The MCP tool accepts a `version` parameter.

## MCP Tool Parameters

Source: `/Users/aaronbassett/Projects/midnight/midnight-mcp/src/tools/format/schemas.ts`

### `midnight-format-contract`

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `code` | string | Yes | — | Compact source code to format |
| `version` | string | No | — | Compiler version to use for formatting (e.g., `"0.29.0"`) |
| `versions` | string[] | No | — | Format with multiple compiler versions for consistency testing |

### Response Structure

```
{
  success: boolean,          // Whether formatting succeeded
  formatted: string,         // The formatted source code
  changed: boolean,          // Whether the code was changed by formatting
  diff: string               // Line-by-line diff showing changes (only if changed)
}
```

When `changed: false`, the code was already correctly formatted. No `diff` is returned.

## SKILL.md Structure

### 1. Positioning Statement (top of file, before everything else)

Strong instruction to the LLM:

> Whenever you are about to present Compact code to the user — whether you wrote it, found it via search, pulled it from a file, or are including it in documentation — format it first using `midnight-format-contract`. This applies to code blocks in responses, code written to files, and code included in generated documentation.
>
> Do not use local `compact format` for this. The MCP tool:
> - Accepts code as a string and returns formatted code as a string — no disk writes
> - Cannot accidentally modify user files (local `compact format` modifies files in place)
> - Supports version-specific formatting without changing the user's toolchain default

### 2. When to Use Local Instead

| Condition | Use Instead |
|-----------|-------------|
| User wants to format their source files in place | `midnight-tooling:compact-cli` (`compact format`) |
| CI pipeline format checking (`--check` mode) | `midnight-tooling:compact-cli` (`compact format --check`) |
| Pre-commit hook format enforcement | `midnight-tooling:compact-cli` (`compact format --check`) |

### 3. Tool Reference

Parameter table and response structure as documented above.

### 4. Usage Patterns

**Format generated code before presenting:**
Call `midnight-format-contract` with the generated code. Use the `formatted` field in your response. If `changed: false`, the code was already well-formatted.

**Format code from a file for display:**
Read the file, pass its content to `midnight-format-contract`. Present the `formatted` result. Do NOT run local `compact format` on the file — that would modify it.

**Format for style review:**
Call format, show the `diff` to the user. This highlights style issues without modifying any files.

**Version-specific formatting:**
Set `version` to the target compiler version. Use this when the project targets a specific Compact version and you want formatting consistent with that version's rules.

**Multi-version consistency check:**
Use `versions` array to format with multiple compiler versions. Compare the `formatted` output across versions to check for formatting differences.

### 5. Error Handling

**Parse failure:** The formatter must parse the code before formatting. If the code has syntax errors, formatting will fail with an error. Decision tree:

- If you compiled the code first and it passed → format it (guaranteed to parse)
- If the code is from a known-good source (user file, search result) → try formatting
  - Success → present formatted
  - Parse error → present unformatted, note the syntax issues
- If the code failed compilation → do not attempt formatting (it will also fail). Fix the code first via `mcp-compile`, then format.

**Version not available:** If the requested `version` is not installed on the playground, the response will include an error. Fall back to omitting the `version` parameter (uses the default/latest version) or inform the user.

**429 rate limit:** Present the code unformatted. Do not retry immediately. The format tool shares the 20 requests per 60 seconds limit.

**5xx / service unavailable:** Present the code unformatted. Do not fall back to local `compact format` — the risk of accidental file modification outweighs the formatting benefit.

**Timeout:** The formatter has a 10-second timeout. Extremely large inputs could hit this. Present unformatted.

**General principle:** Formatted code is better than unformatted code, but unformatted code is better than no code. Never block a response because formatting failed.

### 6. Guidance

- **Formatting is deterministic.** Call once per code block, reuse the result. Do not re-format the same code.
- **Format does not affect compilation.** Whitespace and style are irrelevant to the compiler. Do not format code as a troubleshooting step for compilation errors.
- **Format after final edits.** If you're iterating on code (write → compile → fix → compile), format once at the end when the code is finalized, not on every iteration.
- **Respect `changed: false`.** If the code is already correctly formatted, don't mention formatting in your response — just present the code.

### 7. Cross-References

| Topic | Skill / Plugin |
|-------|----------------|
| Local formatting (in-place, CI, pre-commit) | `midnight-tooling:compact-cli` |
| MCP-hosted compilation | `mcp-compile` |
| Analysis, visualization, diffing | `mcp-analyze` |
| Tool routing and category overview | `mcp-overview` |

## Changes to `mcp-analyze`

Remove the `midnight-format-contract` section from the SKILL.md. Update:
- Frontmatter description: remove "formatting a contract", "midnight-format-contract"
- Title/intro: update tool count (from 5 to 4, accounting for the `mcp-compile` extraction already reducing it from 7 to 5)
- Call frequency table: remove `midnight-format-contract` row
- Cross-references: add row pointing to `mcp-format`

Note: the `mcp-compile` plan already reduces `mcp-analyze` from 7 tools to 5. This plan further reduces it to 4. The `mcp-analyze` modification in this plan must be applied AFTER the `mcp-compile` plan's modification to avoid conflicts. The implementation plan should specify this ordering.

## File Inventory

### New Files (1)

- `plugins/midnight-mcp/skills/mcp-format/SKILL.md`

### Modified Files (1)

- `plugins/midnight-mcp/skills/mcp-analyze/SKILL.md` — Remove `midnight-format-contract` section, update frontmatter, update tool count, add cross-reference to `mcp-format`

### External Artifacts

None.
