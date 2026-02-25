---
name: midnight-plugin-utils:dependency-scanner
description: This skill should be used when the user asks to "scan for dependencies", "find plugin dependencies", "generate extends-plugin.json", "discover plugin requirements", "audit dependencies", "check what this plugin depends on", "list system tool dependencies", "create dependency manifest", or invokes /midnight-plugin-utils:dependency-scanner. Scans plugin files for patterns indicating dependencies on other plugins or system tools.
version: 0.1.0
---

# Dependency Scanner

Scan plugin files for patterns that indicate dependencies on other plugins or system tools, then build an `extends-plugin.json` manifest through interactive confirmation.

The scanner uses regex pattern matching to find references to skills, agents, system commands, tools, and other plugins. It outputs raw matches as JSON. The LLM then interprets, groups, and filters those matches before presenting them to the user for confirmation.

## When to Use

- A plugin needs an `extends-plugin.json` file created from scratch
- An existing `extends-plugin.json` may be out of date after adding new skills or modifying workflows
- Auditing what external skills, plugins, or CLI tools a plugin references
- Investigating whether a plugin has undeclared dependencies that cause runtime failures
- Preparing a plugin for distribution by documenting all of its requirements
- Comparing two plugins to understand their shared dependencies
- Verifying that a refactored plugin still has the correct dependency declarations

## Prerequisites

- Python 3 available in `$PATH`
- The `find-claude-plugin-root` skill (used in Step 1 to generate `/tmp/cpr.py`)
- At least one plugin installed or a local plugin directory to scan

## Usage

- `/midnight-plugin-utils:dependency-scanner` - Scan all enabled plugins
- `/midnight-plugin-utils:dependency-scanner --plugin <name>` - Scan a specific installed plugin
- `/midnight-plugin-utils:dependency-scanner --marketplace <name>` - Scan all plugins from a marketplace
- `/midnight-plugin-utils:dependency-scanner --plugin-dir <path>` - Scan a local plugin directory
- `/midnight-plugin-utils:dependency-scanner --marketplace-dir <path>` - Scan a local marketplace directory

## Flags

| Flag | Argument | Description |
|------|----------|-------------|
| *(none)* | - | Scan all enabled plugins from `~/.claude/settings.json` |
| `--plugin` | `NAME` | Scan a specific installed plugin by name or `name@marketplace` |
| `--marketplace` | `NAME` | Scan every plugin in a named marketplace |
| `--plugin-dir` | `PATH` | Scan a local plugin directory (not necessarily installed) |
| `--marketplace-dir` | `PATH` | Scan a local marketplace directory |
| `--type` | `TYPE` | Filter results to a single pattern type (e.g., `skillReference`) |
| `--pretty` | - | Pretty-print the JSON output with indentation |

The scope flags (`--plugin`, `--marketplace`, `--plugin-dir`, `--marketplace-dir`) are mutually exclusive. Provide at most one.

## Workflow

### Step 1: Generate the CPR Resolver

> Invoke the `midnight-plugin-utils:find-claude-plugin-root` skill to create `/tmp/cpr.py`.

This writes a Python resolver script to `/tmp/cpr.py` that locates plugin installation directories by reading `~/.claude/plugins/installed_plugins.json`.

### Step 2: Determine Flags

Parse the user's request to choose the appropriate scanner flags:

| User Request | Flags |
|-------------|-------|
| "scan my plugins" or no specific target | *(none)* - scans all enabled |
| "scan the devs plugin" | `--plugin devs` |
| "scan devs from my-marketplace" | `--plugin devs@my-marketplace` |
| "scan all plugins in my-marketplace" | `--marketplace my-marketplace` |
| "scan this plugin directory" + path | `--plugin-dir /path/to/plugin` |
| "scan this marketplace" + path | `--marketplace-dir /path/to/marketplace` |

### Step 3: Run the Scanner Script

```bash
PLUGIN_ROOT=$(python3 /tmp/cpr.py utils)
python3 "$PLUGIN_ROOT/skills/dependency-scanner/scripts/dependency-scanner.py" [FLAGS] > /tmp/dependency-scan.json
```

The script outputs a JSON array of matches to stdout. Each match contains six fields:

- `scannedPlugin` - name of the plugin that was scanned
- `scannedMarketplace` - marketplace the scanned plugin belongs to
- `location` - file path with line and column (`/path/to/file.md:42:17`)
- `matched` - the exact text that matched a pattern
- `context` - approximately 30 characters of surrounding text on each side
- `type` - one of `skillReference`, `agentReference`, `systemCommand`, `toolReference`, or `pluginReference`

See `references/scanner-output-format.md` for the full schema and example output.

### Step 4: Read and Interpret Matches

Read `/tmp/dependency-scan.json`. Analyze the raw pattern matches as follows:

1. **Filter internal references**: If Skill A in plugin X references Skill B also in plugin X, that is NOT a dependency. Remove these matches. Check the `scannedPlugin` field against the plugin prefix in the `matched` text to detect self-references.
2. **Filter false positives**: Remove matches that reference standard library imports (`import json`, `import sys`), generic documentation phrases ("the Read tool is used to..."), and version strings that coincidentally resemble commands.
3. **Group by source**: Combine `/foo:spam`, `/foo:ham`, `/foo:eggs` into one "foo" dependency group. Use the plugin prefix before the colon as the grouping key.
4. **Identify the providing plugin**: For each group, determine which plugin or marketplace provides it by searching installed plugins and known marketplaces.
5. **Classify each group**: Label it as a plugin dependency (if it references skills, commands, or plugins) or a system dependency (if it references CLI tools or executables).

### Step 5: Determine Dependency Sources

**For plugin dependencies:**

1. Read `~/.claude/plugins/installed_plugins.json` to get the full list of installed plugins, their versions, and install paths.
2. If the matched skill is `/foo:bar`, look for an installed plugin named "foo". The prefix before the colon identifies the plugin.
3. If the matched skill is `/bar` (no plugin prefix), search all installed plugins for a skill named "bar" by scanning their `skills/` directories.
4. If the plugin is not found in installed plugins, check marketplace directories listed in `~/.claude/plugins/known_marketplaces.json`.
5. Record the plugin name, marketplace, and installed version for the confirmation step.

**For system dependencies:**

1. Run `which <command>` to check whether the command is available in `$PATH`.
2. Run `<command> --version` to detect the installed version string.
3. If the command is not found, note it as missing. The user can still add it as an optional dependency.
4. For common tools like `git`, `gh`, `node`, `python3`, or `docker`, suggest standard version constraints based on widely-used minimum versions.

### Step 6: Batch Confirmations with User

For EACH dependency group, use `AskUserQuestion` to confirm. Batch similar findings from the same plugin together:

```
Found 3 skills (spam, ham, eggs) from foo@bar-marketplace.
Current installed version: 1.2.3

Add to dependencies?
- Yes, require ^1.2.0 (Recommended)
- Yes, require ^1.0.0
- Yes, as optional dependency
- No, skip this
```

For system dependencies:

```
Found system command: gh (used 5 times)
Currently installed: 2.45.0

Add to systemDependencies?
- Yes, require >=2.0.0 (Recommended)
- Yes, require >=2.45.0 (exact current)
- Yes, as optional system dependency
- No, skip this
```

### Step 7: Build and Write extends-plugin.json

After all confirmations, assemble the final JSON structure. Place each confirmed dependency into the appropriate section based on user choices (required vs optional, plugin vs system):

```json
{
  "dependencies": {
    "foo": "^1.2.0"
  },
  "optionalDependencies": {},
  "systemDependencies": {
    "gh": ">=2.0.0"
  },
  "optionalSystemDependencies": {}
}
```

Show the final `extends-plugin.json` to the user and ask for confirmation before writing. If the file already exists, show a diff of the changes.

Write to: `<plugin-path>/.claude-plugin/extends-plugin.json`

If the `.claude-plugin` directory does not exist, create it first. Omit empty sections from the output (e.g., if there are no optional dependencies, exclude `optionalDependencies` entirely).

See `references/extends-plugin-schema.md` for the full schema documentation including version constraint syntax.

## How Pattern Matching Works

The scanner script searches these file types within a plugin directory:

- `**/*.md` - Markdown files (SKILL.md, AGENT.md, README.md, etc.)
- `**/*.json` - JSON configuration files
- `**/*.py` - Python scripts
- `**/*.sh`, `**/*.bash` - Shell scripts

It skips common non-source directories (`.git`, `node_modules`, `__pycache__`, `venv`, `dist`, `build`).

Five categories of patterns are matched:

| Category | Examples |
|----------|----------|
| `skillReference` | `/plugin:skill`, `Skill(skill="name")`, "invoke the skill" |
| `agentReference` | `@agent`, `subagent_type`, `AGENT.md`, "launch an agent" |
| `systemCommand` | `` `git commit` ``, `#!/usr/bin/env python3`, `import requests`, `pip install foo` |
| `toolReference` | "use the Read tool", `PreToolUse`, `mcp__server__tool` |
| `pluginReference` | "requires the foo plugin", `"dependencies": {`, `plugin install bar` |

Each match is recorded with its file location, matched text, surrounding context, and pattern type. The script does not interpret the matches - it reports all potential references for the LLM to analyze.

## Error Handling

### Script not found

If `dependency-scanner.py` is not at the expected path:

```bash
ls "$PLUGIN_ROOT/skills/dependency-scanner/scripts/dependency-scanner.py"
```

Verify that `$PLUGIN_ROOT` resolved correctly. Re-run the `find-claude-plugin-root` skill if `/tmp/cpr.py` is missing or stale.

### CPR resolver missing

If `/tmp/cpr.py` does not exist (cleared on reboot), re-invoke the `find-claude-plugin-root` skill to regenerate it.

### Empty scan results

An empty JSON array (`[]`) means no dependency patterns were found. This is normal for plugins with no external references. Confirm with the user whether to write an empty `extends-plugin.json` or skip.

### Python not available

If `python3` is not in `$PATH`, inform the user that Python 3 is required and provide installation guidance for their platform.

### Invalid JSON from script

If the scanner script writes to stderr, those are warnings (e.g., unreadable files). Only stdout contains the JSON output. Check stderr for diagnostic messages if the JSON parse fails.

## Key Principles

- **Script does pattern matching only** - returns raw potential matches, not analyzed dependencies
- **LLM interprets** - groups matches, filters false positives, identifies providing plugins
- **User confirms everything** - never auto-write `extends-plugin.json`
- **Batch similar findings** - do not ask three separate questions for skills from the same plugin
- **False positives are acceptable** - better to surface a questionable match than miss a real dependency

## Additional Resources

### Scripts
- `$PLUGIN_ROOT/skills/dependency-scanner/scripts/dependency-scanner.py` - Pattern matching scanner

### References
- `references/scanner-output-format.md` - JSON output schema, pattern types, and example output
- `references/extends-plugin-schema.md` - Full `extends-plugin.json` schema and version constraint syntax
