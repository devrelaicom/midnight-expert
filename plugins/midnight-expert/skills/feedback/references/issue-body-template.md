# Issue Body Template — Composition Rules

Use this guide when composing the issue body in Issue Flow step 7. The template file is `${CLAUDE_SKILL_DIR}/templates/issue-body.md.tmpl`.

## How to render

There is no template engine. Read the template, substitute placeholders with the appropriate values, and emit the result as the final issue body. Keep the section ordering exactly as the template specifies.

## Title rule

Format: `<verb> in <plugin-slug>: <one-line symptom>`

Examples:

- `Compile fails with "command not found" in midnight-tooling`
- `Witness type mismatch in compact-core counter example`

Bound to ~80 characters. If the natural title exceeds 80, hard-truncate at 80 and append `…`. Do not regenerate.

## Severity rule

Pick exactly one based on the failure signature and prose:

- **blocker** — error stops the user from completing the task; nothing they did got past it.
- **annoyance** — observed workaround OR non-fatal incorrect behavior.
- **curiosity** — surprising but no clear failure (rare for issues; more common for enhancement-leaning bug reports).

Justification is one short sentence. Cite the failure signature when possible: *"compile exited 127, no successful invocation followed."*

## Skill's analysis section

This is the most important rule on the page. **Include the `## Skill's analysis` block ONLY IF** your analysis prose cites at least one specific evidence card by its caption.

Confidence values:

- **high** — analysis cites multiple cards and the causal link is direct (e.g., the error message names the failing component).
- **medium** — analysis cites at least one card and the causal link is plausible but not airtight.

If you cannot meet the citation bar, **omit the entire `## Skill's analysis` block**. Do not emit a `low` confidence section. Do not emit a section that says "I couldn't determine the cause." Just leave it out.

The handlebars `{{#if analysis_grounded}}` in the template guards this — set `analysis_grounded` to `true` only when both:

1. You will cite at least one evidence card by caption.
2. Your confidence is `high` or `medium`.

## Toolchain section

Set `toolchain_relevant` to `true` when the failing event involves codegen or SDK execution: the failing tool is `compact compile`, a Midnight SDK call, or an `npm`/`tsc` invocation in a Compact-related package. Otherwise `false` — and the toolchain line is omitted.

## Variable list

| Variable | Source |
|---|---|
| `title` | model-generated, see Title rule |
| `skill_version` | from `plugin.json` of `midnight-expert` |
| `session_short` | first 8 chars of `sessionId` |
| `tldr` | model-generated, 1–2 sentences |
| `severity`, `severity_justification` | model-generated, see Severity rule |
| `plugin_slug`, `plugin_version` | from inference + environment |
| `marketplace_version`, `cc_version`, `model`, `effort`, `os` | environment / session metadata |
| `compact_version`, `sdk_version` | from environment |
| `toolchain_relevant` | model-decided per rule above |
| `intent_anchor`, `expected_anchor` | user-confirmed (Issue Flow step 2) |
| `evidence_cards` | from evidence-extraction |
| `analysis_grounded`, `analysis_confidence`, `analysis_prose` | model-decided per rule above |
