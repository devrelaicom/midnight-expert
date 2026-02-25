# Scanner Output Format

The `dependency-scanner.py` script outputs a JSON array of pattern matches found during scanning.

## Output Schema

Each element in the JSON array contains:

| Field | Type | Description |
|-------|------|-------------|
| `scannedPlugin` | string | Name of the plugin that was scanned |
| `scannedMarketplace` | string | Marketplace the scanned plugin belongs to (empty string for local scans) |
| `location` | string | File path with line and column: `/path/to/file.md:42:17` |
| `matched` | string | The exact text that matched a pattern |
| `context` | string | ~30 characters of surrounding text on each side of the match, collapsed to single line |
| `type` | string | One of the five pattern type values listed below |

## Pattern Types

| Type | What It Detects |
|------|-----------------|
| `skillReference` | Slash commands (`/plugin:skill`), `Skill()` tool calls, skill mentions in prose |
| `agentReference` | `@agent` mentions, subagent patterns, `Task` tool usage, `AGENT.md` references |
| `systemCommand` | Backticked CLI tools (`git`, `gh`, `npm`), shebangs, `import`/`require` statements, package install commands |
| `toolReference` | Tool invocations (`Read tool`, `Bash tool`), hook references (`PreToolUse`), MCP tool patterns |
| `pluginReference` | Plugin mentions, `depends on` phrases, `extends-plugin.json` declarations, `install` commands |

## Example Output

```json
[
  {
    "scannedPlugin": "my-plugin",
    "scannedMarketplace": "my-marketplace",
    "location": "/path/to/my-plugin/skills/example/SKILL.md:12:5",
    "matched": "/utils:find-claude-plugin-root",
    "context": "...First, invoke /utils:find-claude-plugin-root to generate the...",
    "type": "skillReference"
  },
  {
    "scannedPlugin": "my-plugin",
    "scannedMarketplace": "my-marketplace",
    "location": "/path/to/my-plugin/skills/example/SKILL.md:30:1",
    "matched": "`gh` command",
    "context": "...Ensure the `gh` command is installed before...",
    "type": "systemCommand"
  },
  {
    "scannedPlugin": "my-plugin",
    "scannedMarketplace": "my-marketplace",
    "location": "/path/to/my-plugin/.claude-plugin/plugin.json:8:3",
    "matched": "\"dependencies\": {",
    "context": "...\"keywords\": [], \"dependencies\": { \"other-plugin\": \"^1.0.0\"...",
    "type": "pluginReference"
  }
]
```

## Empty Results

An empty JSON array (`[]`) means no dependency patterns were found. This can happen when:

- The plugin has no external dependencies
- The plugin only references its own internal skills
- The scanned files contain no recognized patterns

## False Positives

The scanner uses regex pattern matching, not semantic analysis. Common false positives include:

- Internal skill references (Skill A in plugin X referencing Skill B in the same plugin X)
- Generic phrases like "the Read tool" in documentation that describe behavior rather than declare dependencies
- Import statements for standard library modules (`import json`, `import sys`)
- Version strings that look like commands

The LLM analysis step in the scanner workflow filters these out. Prefer false positives over missed dependencies.
