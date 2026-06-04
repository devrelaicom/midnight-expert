<!--
  ============================================================================
  Custom_Devin-Desktop_Functionality.md  (midnight-expert)
  ============================================================================
  PURPOSE
    `midnight-expert` is a marketplace of **Claude Code** plugins (skills,
    slash-commands, agents). This file explains how to get value from the same
    material inside **Devin Desktop** (the IDE formerly known as **Windsurf**),
    which does NOT load Claude Code plugins natively.

  WHO WROTE THIS
    Contributed by a community user (bytewizard42i) who is a *novice* developer.
    >>> Please double-check every command, path, and template below. <<<
        These were validated on Ubuntu/WSL2 but not across all platforms.

  TERMINOLOGY NOTE
    "Devin Desktop" == "Windsurf" (Codeium rebranded Windsurf to Devin Desktop).
    Older docs/config may still say "Windsurf"; same product. On-disk paths
    still use `~/.codeium/windsurf/` and project-level config lives under a
    `.devin/` (or legacy `.windsurf/`) directory.
  ============================================================================
-->

# Using `midnight-expert` with Devin Desktop (formerly Windsurf)

Devin Desktop cannot install Claude Code plugins, but almost everything here is
still useful in two forms:

1. **Reference documentation** — the ~37k lines across `plugins/*/skills/**/SKILL.md`
   and `references/*.md` are plain Markdown. Point the assistant at the relevant
   file; it reads them like any doc.
2. **Portable scripts** — a few bundled scripts are pure `bash`/`jq` with no
   Claude runtime dependency, so they run anywhere.

> **Novice disclaimer:** written by a learning developer. Verify each step in
> your own environment before depending on it.

## Portable pieces that "just work"

### Error / status code lookup (`bash` + `jq`)

```bash
# Self-contained: finds its own codes.json via $SCRIPT_DIR. Needs `jq`.
#   sudo apt install -y jq        # Debian/Ubuntu
#   brew install jq               # macOS
LOOKUP="plugins/midnight-status-codes/skills/status-codes-lookup/scripts/lookup.sh"

bash "$LOOKUP" --sources            # list all error sources
bash "$LOOKUP" --code 166           # exact code/name/alias
bash "$LOOKUP" --search 'ledger'    # regex across all fields
```

### Toolchain doctor (`bash`)

```bash
# These doctor scripts contain NO Claude/plugin-runtime references; invoke them
# directly by absolute path. Each emits "CHECK_NAME | STATUS | DETAIL" lines.
D="plugins/midnight-tooling/scripts/doctor"
bash "$D/compact-cli.sh"   # Compact CLI + compiler versions
bash "$D/env.sh"           # PATH / COMPACT_DIRECTORY config
bash "$D/plugin-deps.sh"   # optional tool availability

# Devnet container + HTTP health (needs Docker; curl for health):
H="plugins/midnight-tooling/skills/devnet-health/scripts"
bash "$H/status.sh"        # <service>\t<status>\t<container>
bash "$H/health.sh"        # <service>\t<healthy|unhealthy>\t<ms>\t<httpCode>
```

## Adapting Claude slash-commands to Devin Desktop "workflows"

Devin Desktop supports project **workflows** — Markdown files in
`.devin/workflows/<name>.md` with a small YAML front-matter
(`description:`) that the user invokes as `/<name>`. This maps closely to a
Claude Code slash-command, with two differences to handle when porting:

| Claude Code construct | Devin Desktop equivalent |
|-----------------------|--------------------------|
| `Agent` / `Task` subagents (e.g. 10 parallel reviewers) | the built-in code-search subagent, or run the checklist sequentially |
| `Skill` tool / `${CLAUDE_SKILL_DIR}` paths | read the `SKILL.md` / `references/*.md` file directly by path |
| plugin-root resolver (`cpr.py`) | hard-code the absolute path to the bundled script |
| octocode MCP doc lookups | the `fetch` MCP or `midnight-manual` MCP |

### Minimal workflow template

```markdown
---
description: <one-line summary the user sees in the slash-command menu>
---

# <Title>

<what this does, and when to run it>

## Steps
1. <step>
// turbo          <-- optional: marks the next command block as auto-runnable
\`\`\`
<shell command, or an MCP tool call>
\`\`\`
```

Commands we ported this way (see the consuming project's `.devin/workflows/`):

- `/midnight-status-lookup`  ← `midnight-status-codes:lookup` (wraps `lookup.sh`)
- `/midnight-doctor`         ← `midnight-tooling:doctor` (wraps the doctor `*.sh`)
- `/midnight-review-compact` ← `compact-core:review-compact` (reads the 10
  `compact-review/references/*.md` checklists; compiles via the local
  `compact` CLI or an MCP, then writes a consolidated report — privacy first)

## Using the skills as a knowledge index

Because the skills are plain Markdown, the simplest integration is an *index*
that maps a topic to its reference path, e.g. "Compact tokens" →
`plugins/compact-core/skills/compact-tokens/SKILL.md`. The assistant reads the
specific file on demand rather than ingesting all ~37k lines. Pair this with
the `midnight-manual` MCP (semantic search over the live corpus) for "how does
X actually work" questions.

<!--
  ---------------------------------------------------------------------------
  MAINTAINERS: this file is documentation only — no code, no behavior change,
  nothing under plugins/ is modified. If you would rather host Devin Desktop
  guidance somewhere else (README section, docs/ page) or not at all, just say
  so on the PR and we will adjust or withdraw it. We are new to contributing.
  ---------------------------------------------------------------------------
-->
