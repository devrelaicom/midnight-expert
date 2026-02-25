---
name: midnight-plugin-utils:dependency-checker
description: This skill should be used when the user asks to "check dependencies", "verify plugin requirements", "what plugins am I missing", "validate plugin dependencies", "missing plugin dependencies", "unmet requirements", "are my dependencies satisfied", "which dependencies are broken", or invokes /midnight-plugin-utils:dependency-checker. Validates declared dependencies in extends-plugin.json files against installed and enabled plugins.
version: 0.1.0
---

# Dependency Checker

Validate dependencies declared in `extends-plugin.json` files against the current environment. Check whether required plugins are installed and enabled, whether system tools are available, and whether version constraints are satisfied.

The checker reads each plugin's `.claude-plugin/extends-plugin.json`, cross-references it against installed plugins and system tools, then outputs structured JSON results. Companion scripts render ASCII tables and generate resolution steps for any unsatisfied dependencies.

## When to Use

- After installing or updating plugins, to confirm all requirements are met
- Before using a plugin that may depend on other plugins or CLI tools
- Debugging "skill not found" or "command not found" errors that may indicate missing dependencies
- Validating that a plugin's `extends-plugin.json` is correct and complete
- Checking whether optional dependencies are available for enhanced functionality
- After system updates that may have changed available CLI tool versions
- Verifying a development plugin's dependency declarations before publishing

## Prerequisites

- Python 3 available in `$PATH`
- The `find-claude-plugin-root` skill (used in Step 2 to generate `/tmp/cpr.py`)
- At least one plugin with an `extends-plugin.json` file (plugins without one are silently skipped)

## Usage

- `/midnight-plugin-utils:dependency-checker` - Check all enabled plugins
- `/midnight-plugin-utils:dependency-checker --installed` - Check all installed plugins
- `/midnight-plugin-utils:dependency-checker --all` - Check all plugins in all known marketplaces
- `/midnight-plugin-utils:dependency-checker --plugin <name>` - Check a specific plugin

## Flags

| Flag | Argument | Description |
|------|----------|-------------|
| *(none)* | - | Check only enabled plugins from `~/.claude/settings.json` |
| `--installed` | - | Check all installed plugins regardless of enabled state |
| `--all` | - | Check all plugins found in known marketplaces |
| `--plugin` | `NAME` | Check a specific plugin by name or `name@marketplace` |
| `--pretty` | - | Pretty-print the JSON output with indentation |

The scope flags (`--installed`, `--all`, `--plugin`) are mutually exclusive. Provide at most one. The default (no flags) checks enabled plugins only.

## Workflow

### Step 1: Determine Flags

Parse the user's request to choose the appropriate checker flags:

| User Request | Flags |
|-------------|-------|
| "check my plugins" or no specific target | *(none)* - checks enabled only |
| "check installed plugins" | `--installed` |
| "check all plugins" or "check everything" | `--all` |
| "check the devs plugin" | `--plugin devs` |
| "check devs from my-marketplace" | `--plugin devs@my-marketplace` |

### Step 2: Generate the CPR Resolver

> Invoke the `midnight-plugin-utils:find-claude-plugin-root` skill to create `/tmp/cpr.py`.

This writes a Python resolver script to `/tmp/cpr.py` that locates plugin installation directories by reading `~/.claude/plugins/installed_plugins.json`.

### Step 3: Execute the Scripts

Run all three scripts in sequence. The checker script produces JSON, the table renderer formats it as ASCII tables, and the resolution script generates actionable fix steps.

```bash
PLUGIN_ROOT=$(python3 /tmp/cpr.py utils)

# Run the dependency checker - outputs JSON to file
python3 "$PLUGIN_ROOT/skills/dependency-checker/scripts/dependency-checker.py" [FLAGS] > /tmp/dependency-check.json

# Render ASCII tables from the JSON results
python3 "$PLUGIN_ROOT/skills/dependency-checker/scripts/table-renderer.py" /tmp/dependency-check.json

# Generate numbered resolution steps for unsatisfied dependencies
python3 "$PLUGIN_ROOT/skills/dependency-checker/scripts/resolution-steps.py" /tmp/dependency-check.json
```

Display the table renderer output and resolution steps output directly to the user. Both scripts read the same JSON file and produce complementary views of the results.

### Step 4: Interpret and Summarize Results

After displaying the tables and resolution steps, read `/tmp/dependency-check.json` and provide a summary including:

- Total number of dependencies checked across all four categories (dependencies, optionalDependencies, systemDependencies, optionalSystemDependencies)
- Count of satisfied vs unsatisfied dependencies in each category
- Priority order for fixes: resolve required dependencies first, then required system dependencies, then optional ones
- For each unsatisfied dependency, include the specific resolution command from the `help` field
- If the checker exit code was 0, confirm that all required dependencies are satisfied
- If optional dependencies are missing, note which features may be unavailable

## Interpreting the JSON Data

The checker outputs a JSON object with `checkedScope`, `checkedPlugin`, and four dependency arrays. See `references/checker-output-schema.md` for the full schema.

### Plugin dependency entries

Each entry in `dependencies` and `optionalDependencies` contains:

| Field | Meaning |
|-------|---------|
| `plugin` | Required plugin name |
| `marketplace` | Source marketplace (or `null`) |
| `dependent` | Plugin that declared this requirement |
| `requiredVersion` | Version constraint string |
| `installed` | Whether the plugin is installed |
| `enabled` | Whether it is enabled |
| `installedVersion` | Detected version (or `null`) |
| `valid` | `true` only when installed, enabled, and version-compatible |
| `help` | Guidance text when `valid` is `false` |

### System dependency entries

Each entry in `systemDependencies` and `optionalSystemDependencies` contains:

| Field | Meaning |
|-------|---------|
| `command` | CLI command name (e.g., `gh`, `git`, `docker`) |
| `dependent` | Plugin that declared this requirement |
| `requiredVersion` | Version constraint string |
| `installed` | Whether the command exists in `$PATH` |
| `enabled` | Mirrors `installed` (system commands have no enable/disable) |
| `installedVersion` | Detected version string (or `null` if detection failed) |
| `valid` | `true` only when installed and version-compatible |
| `help` | Guidance text when `valid` is `false` |

Note: System entries use `command` instead of `plugin` and never include `marketplace`.

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | All required dependencies satisfied |
| 1 | One or more required dependencies unsatisfied |

Optional dependency failures do not affect the exit code.

## Example Output

### ASCII Table (from table-renderer.py)

```
Dependency check scope: enabled

Required Plugin Dependencies

┌──────────────────────┬─────────────────────────┬──────────────────────────┬─────────┬───────────┬─────────┬─────────┬───────┬────────────────┐
│ plugin               │ marketplace             │ dependent                │ version │ installed │ enabled │ version │ valid │ notes          │
├──────────────────────┼─────────────────────────┼──────────────────────────┼─────────┼───────────┼─────────┼─────────┼───────┼────────────────┤
│ midnight-plugin-utils│ aaronbassett-marketplace│ my-plugin@aaronbassett…  │ ^0.1.0  │ ✓         │ ✓       │ 0.1.0   │ ✓     │                │
│ missing-plugin       │                         │ my-plugin@aaronbassett…  │ >=1.0.0 │ ✗         │ ✗       │         │ ✗     │ not installed  │
└──────────────────────┴─────────────────────────┴──────────────────────────┴─────────┴───────────┴─────────┴─────────┴───────┴────────────────┘

Required System Dependencies

┌─────────┬──────────────────────────┬─────────┬───────────┬─────────┬───────┬───────┐
│ command │ dependent                │ version │ installed │ version │ valid │ notes │
├─────────┼──────────────────────────┼─────────┼───────────┼─────────┼───────┼───────┤
│ gh      │ my-plugin@aaronbassett…  │ >=2.0.0 │ ✓         │ 2.45.0  │ ✓     │       │
└─────────┴──────────────────────────┴─────────┴───────────┴─────────┴───────┴───────┘
```

### Resolution Steps (from resolution-steps.py)

```
## Resolution Steps (1 issue)

1. [Required] missing-plugin (required by my-plugin@aaronbassett-marketplace)
   /plugin install missing-plugin
```

When all dependencies are satisfied:

```
All dependencies satisfied.
```

## Error Handling

### Script not found

If any of the three scripts are not at the expected path:

```bash
ls "$PLUGIN_ROOT/skills/dependency-checker/scripts/"
```

Verify that `$PLUGIN_ROOT` resolved correctly. Re-run the `find-claude-plugin-root` skill if `/tmp/cpr.py` is missing or stale.

### CPR resolver missing

If `/tmp/cpr.py` does not exist (cleared on reboot), re-invoke the `find-claude-plugin-root` skill to regenerate it.

### No extends-plugin.json found

Plugins without `extends-plugin.json` are silently skipped. If the checker reports no dependencies for a plugin that should have them, verify the file exists:

```bash
ls <plugin-path>/.claude-plugin/extends-plugin.json
```

Run the `dependency-scanner` skill to generate the file if it is missing.

### Invalid JSON in extends-plugin.json

If a plugin's `extends-plugin.json` contains malformed JSON, the checker skips it silently. Validate the file manually:

```bash
python3 -m json.tool <plugin-path>/.claude-plugin/extends-plugin.json
```

### Python not available

If `python3` is not in `$PATH`, inform the user that Python 3 is required and provide installation guidance for their platform.

### System command version detection fails

Some commands do not support `--version`. The checker tries multiple flags (`--version`, `-version`, `-v`, `version`) and falls back to treating the command as available with unknown version. In this case `installedVersion` is `null` and version constraints evaluate as satisfied.

## How Validation Works

The checker reads three configuration files to build its picture of the environment:

1. **`~/.claude/plugins/installed_plugins.json`** - maps plugin keys (format `name@marketplace`) to installation info including `installPath` and `version`
2. **`~/.claude/settings.json`** - contains `enabledPlugins` map where keys are plugin identifiers and values are booleans
3. **`~/.claude/plugins/known_marketplaces.json`** - lists known marketplaces with their install locations (used by `--all` scope)

For each plugin in scope, the checker loads `<installPath>/.claude-plugin/extends-plugin.json` and validates every declared dependency against these configuration sources and the system `$PATH`.

A plugin dependency is `valid` only when all three conditions are met: installed, enabled, and version-compatible. A system dependency is `valid` only when the command exists in `$PATH` and the detected version satisfies the constraint.

## Key Principles

- **Declarative validation** - reads `extends-plugin.json` and checks against the environment, never modifies files
- **Required before optional** - always prioritize required dependency failures over optional ones
- **Actionable output** - every unsatisfied dependency includes a resolution command or guidance
- **Non-destructive** - the checker only reads configuration files and runs version checks, never installs or modifies anything
- **Permissive on unknowns** - if a version cannot be parsed (e.g., git commit SHA), treat the dependency as satisfied rather than blocking

## Additional Resources

### Scripts
- `$PLUGIN_ROOT/skills/dependency-checker/scripts/dependency-checker.py` - Core validation logic
- `$PLUGIN_ROOT/skills/dependency-checker/scripts/table-renderer.py` - ASCII table formatting
- `$PLUGIN_ROOT/skills/dependency-checker/scripts/resolution-steps.py` - Resolution guidance generator

### References
- `references/checker-output-schema.md` - Full JSON output schema with field descriptions and examples
- `references/extends-plugin-format.md` - Input format documentation and validation rules
