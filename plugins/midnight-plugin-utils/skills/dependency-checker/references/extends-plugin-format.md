# extends-plugin.json Input Format

The dependency checker reads `extends-plugin.json` files to determine what each plugin requires. This document describes the format from a validation perspective.

## File Location

The checker looks for this file at:

```
<plugin-install-path>/.claude-plugin/extends-plugin.json
```

## Schema

```json
{
  "dependencies": { "<plugin-name>": "<version-constraint>" },
  "optionalDependencies": { "<plugin-name>": "<version-constraint>" },
  "systemDependencies": { "<command>": "<version-constraint>" },
  "optionalSystemDependencies": { "<command>": "<version-constraint>" }
}
```

All four sections are optional. Missing sections are treated as empty.

## Configuration Sources

The checker cross-references dependencies against three configuration files:

| File | Location | Purpose |
|------|----------|---------|
| `installed_plugins.json` | `~/.claude/plugins/installed_plugins.json` | Maps plugin keys to install paths and versions |
| `settings.json` | `~/.claude/settings.json` | Contains `enabledPlugins` map (plugin key to boolean) |
| `known_marketplaces.json` | `~/.claude/plugins/known_marketplaces.json` | Lists marketplaces and their install locations |

## Validation Rules

### Plugin Dependencies (`dependencies`, `optionalDependencies`)

For each entry, the checker:

1. Searches `installed_plugins.json` for the plugin by name (and optionally marketplace)
2. Checks the `enabledPlugins` map in `settings.json` to confirm it is enabled
3. Compares the installed version against the version constraint
4. Sets `valid: true` only when installed, enabled, and version-compatible

### System Dependencies (`systemDependencies`, `optionalSystemDependencies`)

For each entry, the checker:

1. Runs `which <command>` to confirm the command exists in `$PATH`
2. Attempts `<command> --version` (and fallback flags) to detect the installed version
3. Compares the detected version against the version constraint
4. Sets `valid: true` only when the command exists and the version is compatible

### Required vs Optional

| Section | Exit Code Impact | Report Behavior |
|---------|------------------|-----------------|
| `dependencies` | Exit 1 if any entry has `valid: false` | Always reported |
| `optionalDependencies` | No exit code impact | Reported as informational |
| `systemDependencies` | Exit 1 if any entry has `valid: false` | Always reported |
| `optionalSystemDependencies` | No exit code impact | Reported as informational |

## Version Constraint Syntax

| Format | Example | Meaning |
|--------|---------|---------|
| Exact | `"1.0.0"` | Must be exactly 1.0.0 |
| Caret | `"^1.2.0"` | >= 1.2.0 and < 2.0.0 |
| Tilde | `"~1.2.0"` | >= 1.2.0 and < 1.3.0 |
| Range (>=) | `">=1.0.0"` | 1.0.0 or higher |
| Range (<) | `"<2.0.0"` | Below 2.0.0 |
| Wildcard | `"*"` | Any version accepted |
