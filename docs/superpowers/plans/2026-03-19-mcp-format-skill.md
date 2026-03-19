# MCP Format Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract MCP-hosted formatting into a dedicated `mcp-format` skill that positions the format tool as the LLM's primary Compact code formatter.

**Architecture:** Single-file skill (SKILL.md only) with strong positioning instruction, inline usage patterns, error handling, and guidance. Surgical edit to `mcp-analyze` to remove the format tool.

**Tech Stack:** Markdown content files within the Claude Code plugin system. No runtime code.

**Spec:** `docs/superpowers/specs/2026-03-19-mcp-format-skill-design.md`

**Ordering dependency:** This plan MUST be executed AFTER the `mcp-compile` plan (`docs/superpowers/plans/2026-03-19-mcp-compile-skill.md`), because Task 2 of this plan modifies `mcp-analyze/SKILL.md` which will already have been modified by the compile plan (7 tools → 5 tools → 4 tools after this plan).

---

## Dependency Graph

```
Task 1 (SKILL.md) ──┐
                     ├── Task 3 (Integration)
Task 2 (mcp-analyze) ┘
```

Tasks 1 and 2 are independent and CAN run in parallel.
Task 3 depends on both.

---

### Task 1: Create mcp-format SKILL.md

**Files:**
- Create: `plugins/midnight-mcp/skills/mcp-format/SKILL.md`

- [ ] **Step 1: Create directory**

```bash
mkdir -p plugins/midnight-mcp/skills/mcp-format
```

- [ ] **Step 2: Write the SKILL.md**

```markdown
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
```

- [ ] **Step 3: Verify the SKILL.md**

Read back the file and confirm:
- Frontmatter has `name: mcp-format` and `description` with format-related trigger words including "proactively"
- Positioning statement is the first content section after the title
- "When to Use Local Instead" table has 3 rows
- Tool reference has correct parameters (`code`, `version`, `versions`)
- Response structures cover success, failure, and multi-version
- 5 usage patterns are documented
- Error handling covers parse failure, version not available, 429, 5xx, timeout
- General principle about graceful degradation is present
- Guidance section has 4 bullet points
- Cross-references link to `compact-cli`, `mcp-compile`, `mcp-analyze`, `mcp-overview`

- [ ] **Step 4: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-format/SKILL.md
git commit -m "feat(mcp-format): create skill positioning MCP format as LLM's primary Compact formatter"
```

---

### Task 2: Update mcp-analyze SKILL.md

**Files:**
- Modify: `plugins/midnight-mcp/skills/mcp-analyze/SKILL.md`

**IMPORTANT:** This task assumes the `mcp-compile` plan has already been executed. After that plan, `mcp-analyze` has 5 tools: `midnight-analyze-contract`, `midnight-visualize-contract`, `midnight-prove-contract`, `midnight-format-contract`, `midnight-diff-contracts`. This task removes the format tool, leaving 4.

- [ ] **Step 1: Read the current mcp-analyze SKILL.md**

Read `plugins/midnight-mcp/skills/mcp-analyze/SKILL.md` to confirm its current state (post-compile-extraction).

Expected state after `mcp-compile` plan execution:
- Title: "Midnight MCP Analysis Tools"
- Intro says "Five tools"
- Contains sections for: analyze, visualize, prove, format, diff
- Cross-references include `mcp-compile`

If the file still has the original 7-tool structure, STOP — the `mcp-compile` plan has not been executed yet. That plan must run first.

- [ ] **Step 2: Update the frontmatter**

Remove format-related trigger words from the description. The exact edit depends on what the `mcp-compile` plan left, but the target is to remove: "formatting a contract", "midnight-format-contract".

- [ ] **Step 3: Update the title and intro**

Change "Five tools" to "Four tools". Change the tool list from "analyzing, visualizing, formatting, proving, and diffing" to "analyzing, visualizing, proving, and diffing".

Add a cross-reference line for formatting:

```markdown
For formatting tools (`midnight-format-contract`), see the `mcp-format` skill.
```

This should appear alongside the existing cross-reference to `mcp-compile` that the compile plan added.

- [ ] **Step 4: Remove the format tool section**

Remove the entire `## midnight-format-contract` section (the one with parameter table, output includes, and usage guidance).

- [ ] **Step 5: Update the Call Frequency table**

Remove the `midnight-format-contract` row. The table should have 4 rows after this edit:

```markdown
| Tool | Calls per Contract |
|------|--------------------|
| `midnight-analyze-contract` | 1 |
| `midnight-visualize-contract` | 1 |
| `midnight-prove-contract` | 1 |
| `midnight-diff-contracts` | 1 per version pair |
```

- [ ] **Step 6: Update the Cross-References table**

Add a row for the `mcp-format` skill:

```markdown
| MCP-hosted formatting and code style | `mcp-format` |
```

- [ ] **Step 7: Verify the changes**

Read back the modified file. Confirm:
- Frontmatter description no longer mentions formatting, format, or midnight-format-contract
- Title/intro says "Four tools"
- Cross-reference lines exist for both `mcp-compile` and `mcp-format`
- The `midnight-format-contract` section is gone
- Call frequency table has 4 rows
- The remaining 4 tool sections are unchanged
- Cross-references table includes both `mcp-compile` and `mcp-format`

- [ ] **Step 8: Commit**

```bash
git add plugins/midnight-mcp/skills/mcp-analyze/SKILL.md
git commit -m "refactor(mcp-analyze): remove format tool, add cross-reference to mcp-format skill"
```

---

### Task 3: Integration Verification

**Depends on:** Tasks 1 and 2

- [ ] **Step 1: Verify new file exists**

```bash
test -f plugins/midnight-mcp/skills/mcp-format/SKILL.md && echo "OK: mcp-format/SKILL.md" || echo "MISSING: mcp-format/SKILL.md"
```

- [ ] **Step 2: Verify SKILL.md structure**

```bash
file="plugins/midnight-mcp/skills/mcp-format/SKILL.md"

# Must have frontmatter
grep -c '^name: mcp-format' "$file"
# Expected: 1

# Must have positioning statement
grep -c 'format it first using' "$file"
# Expected: 1

# Must have error handling section
grep -c '## Error Handling' "$file"
# Expected: 1

# Must have the general principle
grep -c 'Never block a response because formatting failed' "$file"
# Expected: 1
```

- [ ] **Step 3: Verify mcp-analyze was updated correctly**

```bash
file="plugins/midnight-mcp/skills/mcp-analyze/SKILL.md"

# Should NOT contain format tool section
grep -c 'midnight-format-contract' "$file"
# Expected: 0 or very small (only in cross-reference mentions)

# Should say "Four tools"
grep -c 'Four tools' "$file"
# Expected: 1

# Should have cross-references to both extracted skills
grep -c 'mcp-compile' "$file"
# Expected: >= 1

grep -c 'mcp-format' "$file"
# Expected: >= 1
```

- [ ] **Step 4: Final commit if any fixes were made**

If any verification steps revealed issues that were fixed:

```bash
git add -A plugins/midnight-mcp/
git commit -m "fix(mcp-format): address integration verification findings"
```

- [ ] **Step 5: Summary**

Report:
- Files created (1 — `mcp-format/SKILL.md`)
- Files modified (1 — `mcp-analyze/SKILL.md`)
- `mcp-analyze` now has 4 tools: analyze, visualize, prove, diff
- Any issues found and fixed during verification
